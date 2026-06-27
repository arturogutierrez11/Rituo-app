import Combine
import FamilyControls
import Foundation
import SwiftUI

@MainActor
final class BlockSetupViewModel: ObservableObject {
    private enum BlockSource {
        case manual
        case scheduled(UUID)
    }

    @Published var registeredTagIdentifier: String?
    @Published var selection = FamilyActivitySelection()
    @Published var selectedDuration: BlockDuration = .thirtyMinutes
    @Published var schedulers: [RitualScheduler]
    @Published var selectedSchedulerID: RitualScheduler.ID?
    @Published var isPickerPresented = false
    @Published var isAuthorizing = false
    @Published var isBlocking = false
    @Published var isReadingTag = false
    @Published var authorizationMessage: String?
    @Published var blockMessage: String?
    @Published var schedulerMessage: String?
    @Published var tagMessage: String?
    @Published var coreSyncMessage: String?
    @Published var deviceActivityDebugEvents: [String] = []
    @Published var isSyncingRituals = false
    @Published var blockedUntil: Date?
    @Published var remainingBlockTimeText: String?
    @Published var activeCoreSession: RitualSessionResponse?
    @Published var ritualSessionSummary: RitualSessionSummaryResponse?
    @Published var ritualSessionsByRitualId: [String: [RitualSessionResponse]] = [:]
    @Published var nfcTagClaims: [NfcTagClaimResponse] = []
    @Published var isLoadingNfcTags = false
    @Published var isLoadingSessionSummary = false
    @Published var isLoadingSessionHistories = false

    private let authorizer = FamilyControlsAuthorizer()
    private let blocker = AppBlocker()
    private let deviceActivityScheduler = DeviceActivityScheduler()
    private let deviceActivityDebugStore = DeviceActivityDebugStore()
    private let activityEventStore = SharedRitualActivityEventStore()
    private let notificationService = RitualNotificationService()
    private let nfcReader = NFCTagReader()
    private let coreApi: CoreApiService
    private let schedulerStore: SchedulerStore
    private let defaults: UserDefaults
    private var unblockTask: Task<Void, Never>?
    private var countdownTimer: Timer?
    private var scheduleStateTimer: Timer?
    private var activeBlockSource: BlockSource?
    private var suppressedScheduledBlocks: [UUID: Date] = [:]
    private var pendingRitualPasswords: [UUID: String] = [:]
    private let registeredTagKey = "rituo.registeredTagIdentifier"
    private let scheduledSuppressionsKey = "rituo.scheduledBlockSuppressions"
    private var activeAccessToken: String?
    private static let earlyMonitorEndGraceSeconds: TimeInterval = 60

    init(
        schedulerStore: SchedulerStore? = nil,
        coreApi: CoreApiService? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.schedulerStore = schedulerStore ?? SchedulerStore(defaults: defaults)
        self.coreApi = coreApi ?? .shared
        self.defaults = defaults
        self.schedulers = self.schedulerStore.load()
        self.registeredTagIdentifier = defaults.string(forKey: registeredTagKey)
        self.suppressedScheduledBlocks = Self.loadScheduledSuppressions(
            defaults: defaults,
            key: scheduledSuppressionsKey
        )
        notificationService.requestAuthorization()
        rescheduleDeviceActivities()
        restorePersistedScheduledSuppressions()
        startScheduleStateTimer()
        refreshDeviceActivityDebugEvents()
    }


    func updateAccessToken(_ accessToken: String?) {
        activeAccessToken = accessToken
    }

    func clearAuthenticatedState() {
        activeAccessToken = nil
        activeCoreSession = nil
        ritualSessionSummary = nil
        ritualSessionsByRitualId = [:]
        coreSyncMessage = nil
        tagMessage = nil
        applyNfcClaims([])
    }

    func syncPendingDeviceActivityEvents(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        let events = activityEventStore.loadEvents().sorted { $0.occurredAt < $1.occurredAt }
        guard !events.isEmpty else { return }

        var processedIds = Set<UUID>()
        let groupedEvents = Dictionary(grouping: events) { event in
            [
                event.activityName,
                event.coreRitualId ?? "missing-core-id",
                event.plannedEndAt.map { String(Int($0.timeIntervalSince1970)) } ?? "missing-planned-end"
            ].joined(separator: "|")
        }

        for groupEvents in groupedEvents.values {
            guard let sampleEvent = groupEvents.first else { continue }
            guard let coreRitualId = sampleEvent.coreRitualId else {
                deviceActivityDebugStore.log("Evento sin coreRitualId: \(sampleEvent.title).")
                continue
            }

            let startedEvents = groupEvents.filter { $0.eventType == "started" }
            let endedEvents = groupEvents.filter { $0.eventType == "ended" }
            guard let startedEvent = startedEvents.min(by: { $0.occurredAt < $1.occurredAt }) else {
                continue
            }
            guard let endedEvent = endedEvents.filter({ $0.occurredAt >= startedEvent.occurredAt }).max(by: { $0.occurredAt < $1.occurredAt }) else {
                continue
            }

            if Self.isEarlyMonitorEnd(endedEvent, plannedEndAt: startedEvent.plannedEndAt) {
                groupEvents.forEach { processedIds.insert($0.id) }
                deviceActivityDebugStore.log(
                    "Evento monitor ignorado: \(startedEvent.title) termino antes del fin planificado."
                )
                continue
            }

            do {
                let session = try await coreApi.recordRitualSession(
                    accessToken: accessToken,
                    body: RecordRitualSessionRequest(
                        ritualId: coreRitualId,
                        startedAt: Self.isoDateString(from: startedEvent.occurredAt),
                        plannedEndAt: startedEvent.plannedEndAt.map(Self.isoDateString),
                        endedAt: Self.isoDateString(from: endedEvent.occurredAt),
                        status: "completed",
                        startSource: "schedule",
                        endSource: "schedule"
                    )
                )
                groupEvents.forEach { processedIds.insert($0.id) }
                deviceActivityDebugStore.log("Sesión sincronizada desde monitor: \(startedEvent.title) \(session.id).")
            } catch {
                if Self.isMissingRitualError(error) {
                    groupEvents.forEach { processedIds.insert($0.id) }
                    deviceActivityDebugStore.log(
                        "Evento descartado: \(startedEvent.title) ya no existe en core-api."
                    )
                } else {
                    coreSyncMessage = error.localizedDescription
                    deviceActivityDebugStore.log("Error sync evento monitor \(startedEvent.title): \(error.localizedDescription)")
                    print("DeviceActivity event sync error:", error)
                }
            }
        }

        activityEventStore.removeEvents(ids: processedIds)

        if !processedIds.isEmpty {
            await loadRitualSessionSummary(accessToken: accessToken)
            await loadRitualSessionHistories(accessToken: accessToken)
        }
    }

    private static func isMissingRitualError(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, message) = error else {
            return false
        }

        return statusCode == 404 && message.localizedCaseInsensitiveContains("ritual not found")
    }

    private static func isNfcClaimNotFoundError(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, message) = error else {
            return false
        }

        return statusCode == 404 && message.localizedCaseInsensitiveContains("NFC tag claim not found")
    }

    private func applyNfcClaims(_ claims: [NfcTagClaimResponse]) {
        nfcTagClaims = claims

        if claims.isEmpty {
            registeredTagIdentifier = nil
            defaults.removeObject(forKey: registeredTagKey)
        }
    }

    private func applyRenamedNfcClaim(_ claim: NfcTagClaimResponse) {
        nfcTagClaims = nfcTagClaims.map { currentClaim in
            currentClaim.id == claim.id ? claim : currentClaim
        }
    }

    private func refreshNfcClaimsAndConfirmLabel(
        _ label: String,
        accessToken: String
    ) async -> Bool {
        do {
            let claims = try await coreApi.listNfcTagClaims(accessToken: accessToken)
            applyNfcClaims(claims)

            return claims.contains { claim in
                claim.label?.trimmingCharacters(in: .whitespacesAndNewlines) == label
            }
        } catch {
            print("Core nfc rename refresh error:", error)
            return false
        }
    }

    private func reloadNfcClaimsAfterStaleClaim(accessToken: String) async {
        do {
            let claims = try await coreApi.listNfcTagClaims(accessToken: accessToken)
            applyNfcClaims(claims)
        } catch {
            print("Core nfc stale reload error:", error)
        }
    }

    private func updateCurrentNfcClaim(
        preferredClaim: NfcTagClaimResponse,
        label: String,
        accessToken: String
    ) async throws -> NfcTagClaimResponse {
        do {
            return try await coreApi.updateNfcTagClaim(
                accessToken: accessToken,
                claimId: preferredClaim.id,
                body: UpdateNfcTagClaimRequest(label: label)
            )
        } catch {
            guard Self.isNfcClaimNotFoundError(error) else {
                throw error
            }

            let claims = try await coreApi.listNfcTagClaims(accessToken: accessToken)
            applyNfcClaims(claims)

            guard let currentClaim = claims.first else {
                throw error
            }

            return try await coreApi.updateNfcTagClaim(
                accessToken: accessToken,
                claimId: currentClaim.id,
                body: UpdateNfcTagClaimRequest(label: label)
            )
        }
    }

    func loadActiveRitualSession(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        do {
            activeCoreSession = try await coreApi.getActiveRitualSession(accessToken: accessToken)
            if let activeCoreSession {
                coreSyncMessage = "Sesión activa en core-api: \(activeCoreSession.id)."
            }
        } catch {
            activeCoreSession = nil
            print("Core active ritual session error:", error)
        }
    }

    func loadRitualSessionSummary(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        isLoadingSessionSummary = true
        defer { isLoadingSessionSummary = false }

        do {
            ritualSessionSummary = try await coreApi.getRitualSessionSummary(accessToken: accessToken)
        } catch {
            print("Core ritual session summary error:", error)
        }
    }

    func loadRitualSessionHistories(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        let ritualIds = schedulers.compactMap(\.coreRitualId)
        guard !ritualIds.isEmpty else { return }

        isLoadingSessionHistories = true
        defer { isLoadingSessionHistories = false }

        var nextSessionsByRitualId: [String: [RitualSessionResponse]] = [:]

        for ritualId in ritualIds {
            do {
                nextSessionsByRitualId[ritualId] = try await coreApi.listRitualSessionsByRitual(
                    accessToken: accessToken,
                    ritualId: ritualId
                )
            } catch {
                print("Core ritual session history error:", ritualId, error)
            }
        }

        ritualSessionsByRitualId = nextSessionsByRitualId
    }

    func sessions(for scheduler: RitualScheduler) -> [RitualSessionResponse] {
        guard let coreRitualId = scheduler.coreRitualId else { return [] }
        return ritualSessionsByRitualId[coreRitualId] ?? []
    }

    func isRunningInCore(_ scheduler: RitualScheduler) -> Bool {
        guard let coreRitualId = scheduler.coreRitualId,
              let activeCoreSession else {
            return false
        }

        return activeCoreSession.ritualId == coreRitualId && activeCoreSession.status == "active"
    }

    func refreshRitualSessionState(accessToken: String) async {
        await loadActiveRitualSession(accessToken: accessToken)
        await loadRitualSessionSummary(accessToken: accessToken)
        await loadRitualSessionHistories(accessToken: accessToken)
    }

    var isAuthorized: Bool {
        authorizer.status == .approved
    }

    var authorizationStatusText: String {
        authorizer.statusText
    }

    var canStartBlock: Bool {
        isAuthorized && !selectionIsEmpty && !isBlocking
    }

    var canStartBlockWithTag: Bool {
        canStartBlock && registeredTagIdentifier != nil && !isReadingTag
    }

    var canEndBlockWithTag: Bool {
        hasActiveBlockingContext && hasClaimedNfcTag && !isReadingTag
    }

    var hasClaimedNfcTag: Bool {
        !nfcTagClaims.isEmpty || registeredTagIdentifier != nil
    }

    var nfcTagStatusText: String {
        if isLoadingNfcTags {
            return "Cargando"
        }

        if !nfcTagClaims.isEmpty {
            return nfcTagClaims.count == 1 ? "1 tag vinculado" : "\(nfcTagClaims.count) tags vinculados"
        }

        return registeredTagIdentifier == nil ? "Sin vincular" : "Vinculado local"
    }

    var appCount: Int {
        selection.applicationTokens.count
    }

    var categoryCount: Int {
        selection.categoryTokens.count
    }

    var domainCount: Int {
        selection.webDomainTokens.count
    }

    var selectedItemCount: Int {
        appCount + categoryCount + domainCount
    }

    var selectedScheduler: RitualScheduler? {
        schedulers.first(where: { $0.id == selectedSchedulerID })
    }

    var activeScheduler: RitualScheduler? {
        schedulers.first { scheduler in
            scheduler.isActive() && !isSchedulerSuppressed(scheduler)
        }
    }

    var activeSchedulerSummary: String {
        if let activeScheduler {
            return "\(activeScheduler.title) activo ahora"
        }

        return "No hay schedulers corriendo ahora"
    }

    var currentBlockingScheduler: RitualScheduler? {
        activeSchedulerForCurrentBlock()
    }

    private var hasActiveBlockingContext: Bool {
        isBlocking || activeCoreSession != nil || activeScheduler != nil
    }

    var selectionSummary: String {
        if appCount == 0 && categoryCount == 0 && domainCount == 0 {
            return "Todavia no elegiste apps, categorias ni sitios."
        }

        return "Seleccion actual: \(appCount) apps, \(categoryCount) categorias, \(domainCount) sitios web."
    }


    func openActivityPicker() async {
        if !isAuthorized {
            await requestAuthorization()
        }

        guard isAuthorized else {
            authorizationMessage = "Para ver y seleccionar apps tenés que autorizar Screen Time."
            return
        }

        isPickerPresented = true
    }

    func requestAuthorization() async {
        isAuthorizing = true
        defer { isAuthorizing = false }

        do {
            try await authorizer.requestAuthorization()
            authorizationMessage = "La app ya puede pedir y aplicar restricciones de Screen Time."
        } catch {
            authorizationMessage = "No se pudo autorizar: \(error.localizedDescription)"
        }
    }

    func loadNfcTagClaims(accessToken: String) async {
        guard !accessToken.isEmpty else {
            nfcTagClaims = []
            registeredTagIdentifier = nil
            defaults.removeObject(forKey: registeredTagKey)
            return
        }

        isLoadingNfcTags = true
        defer { isLoadingNfcTags = false }

        do {
            let claims = try await coreApi.listNfcTagClaims(accessToken: accessToken)
            applyNfcClaims(claims)
        } catch {
            print("Core nfc tags error:", error)
        }
    }

    func startTimedBlock() {
        unblockTask?.cancel()
        countdownTimer?.invalidate()

        let plannedEnd = Calendar.current.date(
            byAdding: .minute,
            value: selectedDuration.minutes,
            to: .now
        )

        blocker.applyShield(using: selection)
        isBlocking = true
        activeBlockSource = .manual
        blockedUntil = plannedEnd
        startCoreRitualSessionIfPossible(startSource: "manual", plannedEndAt: plannedEnd)
        updateRemainingTime()
        startCountdownTimer()

        blockMessage = "Bloqueo activo por \(selectedDuration.title.lowercased()). Cuando termine el tiempo, rituo. va a liberar el acceso."

        unblockTask = Task { [weak self] in
            guard let self, let blockedUntil else { return }
            let delay = max(0, blockedUntil.timeIntervalSinceNow)

            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self.finishTimedBlock()
        }
    }

    func registerTag() {
        isReadingTag = true
        tagMessage = "Esperando tu tag para vincularlo a esta cuenta."

        nfcReader.beginScanning(alertMessage: "Acerca el iPhone al tag NFC para registrarlo en rituo.") { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isReadingTag = false

                switch result {
                case .success(let scanResult):
                    self.registeredTagIdentifier = scanResult.identifier
                    self.defaults.set(scanResult.identifier, forKey: self.registeredTagKey)
                    self.tagMessage = "Tag registrado: \(scanResult.identifier)."
                case .failure(let error):
                    self.tagMessage = error.localizedDescription
                }
            }
        }
    }

    func claimTag(accessToken: String) {
        guard !accessToken.isEmpty else {
            tagMessage = "Necesitas iniciar sesion para vincular un tag."
            return
        }

        isReadingTag = true
        tagMessage = "Esperando tu tag para vincularlo a core-api."

        nfcReader.beginScanning(alertMessage: "Acerca el iPhone al tag NFC para vincularlo a tu cuenta.") { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isReadingTag = false

                switch result {
                case .success(let scanResult):
                    do {
                        let claim = try await self.coreApi.claimNfcTag(
                            accessToken: accessToken,
                            body: ClaimNfcTagRequest(
                                tagIdentifier: scanResult.identifier,
                                label: "Tag principal"
                            )
                        )

                        self.registeredTagIdentifier = scanResult.identifier
                        self.defaults.set(scanResult.identifier, forKey: self.registeredTagKey)
                        let claims = try await self.coreApi.listNfcTagClaims(accessToken: accessToken)
                        self.applyNfcClaims(claims)
                        self.tagMessage = "Tag vinculado: \(claim.label ?? "Tag principal")."
                    } catch {
                        self.tagMessage = error.localizedDescription
                    }
                case .failure(let error):
                    self.tagMessage = error.localizedDescription
                }
            }
        }
    }

    func revokeTagClaim(_ claim: NfcTagClaimResponse, accessToken: String) async {
        guard !accessToken.isEmpty else {
            tagMessage = "Necesitas iniciar sesion para desvincular un tag."
            return
        }

        do {
            try await coreApi.revokeNfcTagClaim(
                accessToken: accessToken,
                claimId: claim.id
            )

            let claims = try await coreApi.listNfcTagClaims(accessToken: accessToken)
            applyNfcClaims(claims)
            tagMessage = "Tag desvinculado de tu cuenta."
        } catch {
            if Self.isNfcClaimNotFoundError(error) {
                await reloadNfcClaimsAfterStaleClaim(accessToken: accessToken)
                tagMessage = nfcTagClaims.isEmpty
                    ? "Tag desvinculado de tu cuenta."
                    : "Actualicé tu tag activo. Intentá desvincularlo otra vez si hace falta."
                return
            }

            tagMessage = error.localizedDescription
        }
    }

    func renameTagClaim(
        _ claim: NfcTagClaimResponse,
        label: String,
        accessToken: String
    ) async {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !accessToken.isEmpty else {
            tagMessage = "Necesitas iniciar sesion para renombrar un tag."
            return
        }

        guard !cleanLabel.isEmpty else {
            tagMessage = "El nombre del tag no puede estar vacio."
            return
        }

        guard cleanLabel.count <= 60 else {
            tagMessage = "El nombre del tag puede tener hasta 60 caracteres."
            return
        }

        do {
            let updatedClaim = try await updateCurrentNfcClaim(
                preferredClaim: claim,
                label: cleanLabel,
                accessToken: accessToken
            )

            applyRenamedNfcClaim(updatedClaim)
            _ = await refreshNfcClaimsAndConfirmLabel(cleanLabel, accessToken: accessToken)

            tagMessage = "Tag renombrado como \(updatedClaim.label ?? cleanLabel)."
        } catch {
            if await refreshNfcClaimsAndConfirmLabel(cleanLabel, accessToken: accessToken) {
                tagMessage = "Tag renombrado como \(cleanLabel)."
                return
            }

            tagMessage = error.localizedDescription
        }
    }

    func startBlockWithTag() {
        guard let registeredTagIdentifier else {
            tagMessage = "Primero registra un tag en esta app."
            return
        }

        isReadingTag = true
        tagMessage = "Acerca el iPhone al tag registrado para iniciar el bloqueo."

        nfcReader.beginScanning(alertMessage: "Acerca el iPhone al tag NFC para activar el ritual.") { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isReadingTag = false

                switch result {
                case .success(let scanResult):
                    guard scanResult.identifier == registeredTagIdentifier else {
                        self.tagMessage = "Ese tag no coincide con el registrado para esta cuenta."
                        return
                    }

                    self.tagMessage = "Tag validado. Activando bloqueo."
                    self.startTimedBlock()
                case .failure(let error):
                    self.tagMessage = error.localizedDescription
                }
            }
        }
    }

    func endBlockWithTag() {
        guard let registeredTagIdentifier else {
            tagMessage = "Primero registra un tag en esta app."
            return
        }

        guard hasActiveBlockingContext else {
            tagMessage = "No hay ningun bloqueo activo para terminar."
            deviceActivityDebugStore.log("NFC local cancelado: sin contexto activo.")
            return
        }

        isReadingTag = true
        tagMessage = "Acerca el iPhone al tag registrado para terminar el ritual."

        nfcReader.beginScanning(alertMessage: "Acerca el iPhone al tag NFC para terminar el ritual.") { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isReadingTag = false

                switch result {
                case .success(let scanResult):
                    guard scanResult.identifier == registeredTagIdentifier else {
                        self.tagMessage = "Ese tag no coincide con el registrado para esta cuenta."
                        return
                    }

                    self.tagMessage = "Tag validado. Terminando bloqueo."
                    self.endBlock(endSource: "nfc")
                case .failure(let error):
                    self.tagMessage = error.localizedDescription
                }
            }
        }
    }

    func endBlockWithVerifiedTag(accessToken: String?) {
        guard hasActiveBlockingContext else {
            tagMessage = "No hay ningun bloqueo activo para terminar."
            deviceActivityDebugStore.log("NFC verify cancelado: sin contexto activo.")
            return
        }

        guard let accessToken, !accessToken.isEmpty else {
            endBlockWithTag()
            return
        }

        activeAccessToken = accessToken

        guard hasClaimedNfcTag else {
            tagMessage = "Primero vincula un tag NFC desde Perfil."
            return
        }

        isReadingTag = true
        tagMessage = "Acerca el iPhone al tag vinculado para terminar el ritual."

        nfcReader.beginScanning(alertMessage: "Acerca el iPhone al tag NFC vinculado para detener el ritual.") { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isReadingTag = false

                switch result {
                case .success(let scanResult):
                    do {
                        let verification = try await self.coreApi.verifyNfcTag(
                            accessToken: accessToken,
                            body: VerifyNfcTagRequest(tagIdentifier: scanResult.identifier)
                        )

                        guard verification.valid else {
                            self.tagMessage = "Ese tag no esta vinculado a esta cuenta."
                            self.deviceActivityDebugStore.log("NFC verify rechazado por core-api.")
                            return
                        }

                        self.tagMessage = "Tag verificado. Terminando ritual."
                        self.deviceActivityDebugStore.log("NFC verify OK. Terminando ritual.")
                        self.endBlock(endSource: "nfc")
                        self.nfcTagClaims = try await self.coreApi.listNfcTagClaims(accessToken: accessToken)
                    } catch {
                        self.tagMessage = error.localizedDescription
                        self.deviceActivityDebugStore.log("Error verify NFC: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    self.tagMessage = error.localizedDescription
                }
            }
        }
    }

    func clearRegisteredTag() {
        registeredTagIdentifier = nil
        defaults.removeObject(forKey: registeredTagKey)
        tagMessage = "Se desvinculo el tag de esta cuenta."
    }

    func clearBlock() {
        endBlock(endSource: "manual")
    }

    private func endBlock(endSource: String) {
        let source = activeBlockSource
        let scheduler = activeSchedulerForCurrentBlock()

        unblockTask?.cancel()
        countdownTimer?.invalidate()

        if shouldSuppressScheduledBlock(source: source, endSource: endSource, scheduler: scheduler) {
            suppressCurrentScheduledBlockIfNeeded(scheduler: scheduler)
        } else if scheduler == nil {
            deviceActivityDebugStore.log("Terminando bloqueo sin scheduler asociado.")
        }

        deviceActivityDebugStore.log("Terminando bloqueo endSource=\(endSource) scheduler=\(scheduler?.title ?? "sin scheduler").")
        finishCoreRitualSessionIfPossible(status: "cancelled", endSource: endSource)
        clearActiveShield()
        notificationService.sendRitualStoppedNotification(for: scheduler, endSource: endSource)
        isBlocking = false
        activeBlockSource = nil
        blockedUntil = nil
        remainingBlockTimeText = nil
        blockMessage = "Se quitaron las restricciones activas."
    }

    private func shouldSuppressScheduledBlock(
        source: BlockSource?,
        endSource: String,
        scheduler: RitualScheduler?
    ) -> Bool {
        guard endSource == "manual" || endSource == "nfc" else { return false }

        if case .scheduled = source {
            return true
        }

        guard let scheduler else { return false }
        return scheduler.isActive()
    }

    func selectScheduler(_ scheduler: RitualScheduler) {
        selectedSchedulerID = scheduler.id
        selection = scheduler.selection
        selectedDuration = .closest(to: scheduler.durationMinutes)
        blockMessage = "Scheduler listo: \(scheduler.title) con foco en \(scheduler.focusTarget)."
    }

    func saveScheduler(
        title: String,
        focusTarget: String,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        weekdays: [Int],
        isProtected: Bool = false,
        password: String? = nil
    ) -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFocusTarget = focusTarget.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            schedulerMessage = "Ponle un nombre al scheduler antes de guardarlo."
            return false
        }

        guard !selectionIsEmpty else {
            schedulerMessage = "Primero elige apps, categorias o sitios para este scheduler."
            return false
        }

        guard !weekdays.isEmpty else {
            schedulerMessage = "Elige al menos un dia para activar el scheduler."
            return false
        }

        let startTotal = startHour * 60 + startMinute
        let endTotal = endHour * 60 + endMinute

        guard endTotal > startTotal else {
            schedulerMessage = "La hora de fin tiene que ser posterior a la de inicio."
            return false
        }

        let cleanPassword = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isProtected && !(4 ... 72).contains(cleanPassword.count) {
            schedulerMessage = "La contraseña debe tener entre 4 y 72 caracteres."
            return false
        }

        let scheduler = RitualScheduler(
            title: cleanTitle,
            detail: "Ritual guardado con \(RitualScheduler.selectionDigest(for: selection)).",
            focusTarget: cleanFocusTarget.isEmpty ? RitualScheduler.selectionDigest(for: selection) : cleanFocusTarget,
            symbolName: "calendar",
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            weekdays: weekdays.sorted(),
            selection: selection,
            isProtected: isProtected,
            nfcUnlockEnabled: isProtected
        )

        if isProtected {
            pendingRitualPasswords[scheduler.id] = cleanPassword
        }

        schedulers.insert(scheduler, at: 0)
        schedulerStore.save(schedulers)
        rescheduleDeviceActivities()
        refreshScheduledRitualState()
        schedulerMessage = "Guardaste \(scheduler.title) con \(scheduler.selectionDigest)."
        return true
    }

    func loadCoreRituals(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        isSyncingRituals = true
        coreSyncMessage = nil
        defer { isSyncingRituals = false }

        do {
            let rituals = try await coreApi.listRituals(accessToken: accessToken)
            mergeCoreRituals(rituals)
            await syncPendingSchedulersToCore(accessToken: accessToken)
            await loadRitualSessionHistories(accessToken: accessToken)
            coreSyncMessage = schedulers.isEmpty ? "Todavia no hay rituales sincronizados." : "Rituales sincronizados."
        } catch {
            coreSyncMessage = error.localizedDescription
            print("Core rituals list error:", error)
        }
    }

    func syncLatestSchedulerToCore(accessToken: String) async {
        guard !accessToken.isEmpty else { return }
        guard let scheduler = schedulers.first else { return }
        guard scheduler.coreRitualId == nil else { return }

        isSyncingRituals = true
        coreSyncMessage = nil
        defer { isSyncingRituals = false }

        do {
            try await syncSchedulerToCore(
                scheduler,
                accessToken: accessToken,
                password: pendingRitualPasswords[scheduler.id]
            )
            coreSyncMessage = "Ritual sincronizado con core-api."
        } catch {
            coreSyncMessage = error.localizedDescription
            print("Core ritual create error:", error)
        }
    }

    private func syncPendingSchedulersToCore(accessToken: String) async {
        let pendingSchedulers = schedulers.filter { scheduler in
            scheduler.coreRitualId == nil &&
            scheduler.selectedItemCount > 0 &&
            !scheduler.isLegacyDemoScheduler &&
            (!scheduler.isProtected || pendingRitualPasswords[scheduler.id] != nil)
        }

        guard !pendingSchedulers.isEmpty else { return }

        for scheduler in pendingSchedulers {
            do {
                try await syncSchedulerToCore(
                    scheduler,
                    accessToken: accessToken,
                    password: pendingRitualPasswords[scheduler.id]
                )
            } catch {
                coreSyncMessage = "No se pudo sincronizar \(scheduler.title): \(error.localizedDescription)"
                print("Core pending ritual sync error:", scheduler.title, error)
            }
        }
    }

    private func syncSchedulerToCore(
        _ scheduler: RitualScheduler,
        accessToken: String,
        password: String? = nil
    ) async throws {
        guard scheduler.coreRitualId == nil else { return }

        let response = try await coreApi.createRitual(
            accessToken: accessToken,
            body: scheduler.createRitualRequest(password: password)
        )

        let blockedItems = try await coreApi.replaceRitualBlockedItems(
            accessToken: accessToken,
            ritualId: response.id,
            body: scheduler.blockedItemsRequest
        )
        print("Core blocked items synced:", blockedItems.count)

        guard let index = schedulers.firstIndex(where: { $0.id == scheduler.id }) else { return }

        schedulers[index] = RitualScheduler(
            id: scheduler.id,
            coreRitualId: response.id,
            title: scheduler.title,
            detail: scheduler.detail,
            focusTarget: scheduler.focusTarget,
            symbolName: scheduler.symbolName,
            startHour: scheduler.startHour,
            startMinute: scheduler.startMinute,
            endHour: scheduler.endHour,
            endMinute: scheduler.endMinute,
            weekdays: scheduler.weekdays,
            selection: scheduler.selection,
            isProtected: response.isProtected,
            nfcUnlockEnabled: response.nfcUnlockEnabled
        )
        pendingRitualPasswords.removeValue(forKey: scheduler.id)
        schedulerStore.save(schedulers)
        rescheduleDeviceActivities()
        refreshScheduledRitualState()
    }

    func deleteScheduler(
        _ scheduler: RitualScheduler,
        accessToken: String?,
        password: String? = nil
    ) async {
        isSyncingRituals = true
        coreSyncMessage = nil
        defer { isSyncingRituals = false }

        do {
            if let coreRitualId = scheduler.coreRitualId,
               let accessToken,
               !accessToken.isEmpty {
                try await coreApi.deleteRitual(
                    accessToken: accessToken,
                    ritualId: coreRitualId,
                    password: password
                )
            }

            if let coreRitualId = scheduler.coreRitualId {
                ritualSessionsByRitualId.removeValue(forKey: coreRitualId)
            }

            schedulers.removeAll { $0.id == scheduler.id }

            if selectedSchedulerID == scheduler.id {
                selectedSchedulerID = nil
                selection = FamilyActivitySelection()
            }

            if isBlocking,
               case .scheduled(let schedulerID) = activeBlockSource,
               schedulerID == scheduler.id {
                clearBlock()
            }

            schedulerStore.save(schedulers)
            rescheduleDeviceActivities()
            refreshScheduledRitualState()
            coreSyncMessage = "Ritual eliminado."
        } catch {
            coreSyncMessage = error.localizedDescription
            print("Core ritual delete error:", error)
        }
    }


    private var selectionIsEmpty: Bool {
        selection.applicationTokens.isEmpty &&
        selection.categoryTokens.isEmpty &&
        selection.webDomainTokens.isEmpty
    }

    private func mergeCoreRituals(_ rituals: [RitualResponse]) {
        for ritual in rituals {
            if let index = schedulers.firstIndex(where: { $0.coreRitualId == ritual.id }) {
                let localSelection = schedulers[index].selection
                let localId = schedulers[index].id
                schedulers[index] = RitualScheduler(
                    id: localId,
                    coreRitualId: ritual.id,
                    title: ritual.title,
                    detail: ritual.description ?? schedulers[index].detail,
                    focusTarget: ritual.selectionDigest ?? schedulers[index].focusTarget,
                    symbolName: RitualScheduler(response: ritual).symbolName,
                    startHour: RitualScheduler(response: ritual).startHour,
                    startMinute: RitualScheduler(response: ritual).startMinute,
                    endHour: RitualScheduler(response: ritual).endHour,
                    endMinute: RitualScheduler(response: ritual).endMinute,
                    weekdays: ritual.weekdays.sorted(),
                    selection: localSelection,
                    isProtected: ritual.isProtected,
                    nfcUnlockEnabled: ritual.nfcUnlockEnabled
                )
            } else if let index = schedulers.firstIndex(where: { scheduler in
                scheduler.coreRitualId == nil &&
                schedulerMatchesCoreRitual(scheduler, ritual)
            }) {
                let localSelection = schedulers[index].selection
                let localId = schedulers[index].id
                let syncedScheduler = RitualScheduler(response: ritual, preserving: localSelection)
                schedulers[index] = RitualScheduler(
                    id: localId,
                    coreRitualId: ritual.id,
                    title: syncedScheduler.title,
                    detail: syncedScheduler.detail,
                    focusTarget: syncedScheduler.focusTarget,
                    symbolName: syncedScheduler.symbolName,
                    startHour: syncedScheduler.startHour,
                    startMinute: syncedScheduler.startMinute,
                    endHour: syncedScheduler.endHour,
                    endMinute: syncedScheduler.endMinute,
                    weekdays: syncedScheduler.weekdays,
                    selection: localSelection,
                    isProtected: syncedScheduler.isProtected,
                    nfcUnlockEnabled: syncedScheduler.nfcUnlockEnabled
                )
            } else {
                schedulers.append(RitualScheduler(response: ritual))
            }
        }

        schedulers = deduplicatedSchedulers(schedulers)
        schedulerStore.save(schedulers)
        rescheduleDeviceActivities()
        refreshScheduledRitualState()
    }

    private func schedulerMatchesCoreRitual(
        _ scheduler: RitualScheduler,
        _ ritual: RitualResponse
    ) -> Bool {
        let responseScheduler = RitualScheduler(response: ritual)
        return scheduler.title == responseScheduler.title &&
            scheduler.startHour == responseScheduler.startHour &&
            scheduler.startMinute == responseScheduler.startMinute &&
            scheduler.endHour == responseScheduler.endHour &&
            scheduler.endMinute == responseScheduler.endMinute &&
            scheduler.weekdays.sorted() == responseScheduler.weekdays.sorted()
    }

    private func deduplicatedSchedulers(_ schedulers: [RitualScheduler]) -> [RitualScheduler] {
        var seenCoreIds = Set<String>()
        var seenLocalKeys = Set<String>()
        var result: [RitualScheduler] = []

        for scheduler in schedulers {
            if let coreRitualId = scheduler.coreRitualId {
                guard seenCoreIds.insert(coreRitualId).inserted else { continue }
            } else {
                let key = [
                    scheduler.title,
                    "\(scheduler.startHour):\(scheduler.startMinute)",
                    "\(scheduler.endHour):\(scheduler.endMinute)",
                    scheduler.weekdays.sorted().map(String.init).joined(separator: ",")
                ].joined(separator: "|")
                guard seenLocalKeys.insert(key).inserted else { continue }
            }

            result.append(scheduler)
        }

        return result
    }

    private func rescheduleDeviceActivities() {
        do {
            try deviceActivityScheduler.reschedule(schedulers)
            notificationService.rescheduleNotifications(for: schedulers)
        } catch {
            schedulerMessage = "No se pudieron programar los rituales automaticos: \(error.localizedDescription)"
            deviceActivityDebugStore.log("Error startMonitoring: \(error.localizedDescription)")
            print("Device activity scheduling error:", error)
        }
        refreshDeviceActivityDebugEvents()
    }

    func refreshScheduledRitualState() {
        refreshDeviceActivityDebugEvents()
        removeExpiredScheduledSuppressions()
        guard isAuthorized else { return }

        let currentScheduler = schedulers.first { scheduler in
            scheduler.selectedItemCount > 0 && scheduler.isActive() && !isSchedulerSuppressed(scheduler)
        }

        if let scheduler = currentScheduler {
            if isBlocking,
               case .scheduled(let schedulerID) = activeBlockSource,
               schedulerID == scheduler.id {
                if blockedUntil == nil {
                    blockedUntil = scheduler.endDate()
                }
                updateRemainingTime()
                return
            }

            selectScheduler(scheduler)
            blocker.applyShield(using: scheduler.selection)
            deviceActivityDebugStore.log("Fallback app activo \(scheduler.title) items=\(scheduler.selectedItemCount).")
            isBlocking = true
            activeBlockSource = .scheduled(scheduler.id)
            blockedUntil = scheduler.endDate()
            startCoreRitualSessionIfPossible(startSource: "schedule", plannedEndAt: blockedUntil)
            updateRemainingTime()
            startCountdownTimer()
            blockMessage = "\(scheduler.title) se activo por horario. Apps bloqueadas hasta \(scheduler.timeRangeText)."
            return
        }

        if case .scheduled = activeBlockSource {
            finishTimedBlock()
        }
    }

    private func finishTimedBlock() {
        let scheduler = activeSchedulerForCurrentBlock()
        let source = activeBlockSource
        finishCoreRitualSessionIfPossible(status: "completed", endSource: "timer")
        clearActiveShield()
        if case .scheduled = source {
            // The scheduled notification already announces the end of the ritual.
        } else {
            notificationService.sendRitualStoppedNotification(for: scheduler, endSource: "timer")
        }
        isBlocking = false
        activeBlockSource = nil
        blockedUntil = nil
        remainingBlockTimeText = nil
        countdownTimer?.invalidate()
        blockMessage = "El temporizador termino y rituo. libero el acceso a las apps."
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateRemainingTime()
            }
        }
    }

    private func startScheduleStateTimer() {
        scheduleStateTimer?.invalidate()
        scheduleStateTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshScheduledRitualState()
            }
        }
    }

    func refreshDeviceActivityDebugEvents() {
        deviceActivityDebugEvents = deviceActivityDebugStore.latestEvents()
    }

    func clearDeviceActivityDebugEvents() {
        deviceActivityDebugStore.clear()
        refreshDeviceActivityDebugEvents()
    }

    private func activeSchedulerForCurrentBlock() -> RitualScheduler? {
        switch activeBlockSource {
        case .manual:
            return selectedScheduler
        case .scheduled(let schedulerID):
            return schedulers.first { $0.id == schedulerID }
        case nil:
            if let ritualId = activeCoreSession?.ritualId,
               let scheduler = schedulers.first(where: { $0.coreRitualId == ritualId }) {
                return scheduler
            }
            return selectedScheduler ?? activeScheduler
        }
    }

    private func suppressCurrentScheduledBlockIfNeeded(scheduler: RitualScheduler?) {
        guard let scheduler else { return }
        let suppressionEnd = scheduler.endDate() ?? blockedUntil ?? Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now
        suppressedScheduledBlocks[scheduler.id] = suppressionEnd
        saveScheduledSuppressions()
        deviceActivityScheduler.stopMonitoringCurrentInterval(for: scheduler)
        deviceActivityDebugStore.log("Scheduler \(scheduler.title) suprimido hasta \(suppressionEnd).")

        Task { [weak self] in
            let delay = max(0, suppressionEnd.timeIntervalSinceNow) + 1
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.removeExpiredScheduledSuppressions()
                self?.refreshScheduledRitualState()
            }
        }
    }

    private func removeExpiredScheduledSuppressions(now: Date = .now) {
        let expiredIds = suppressedScheduledBlocks.filter { $0.value <= now }.map(\.key)
        guard !expiredIds.isEmpty else { return }
        expiredIds.forEach { suppressedScheduledBlocks.removeValue(forKey: $0) }
        saveScheduledSuppressions()
        rescheduleDeviceActivities()
    }

    private func isSchedulerSuppressed(_ scheduler: RitualScheduler, now: Date = .now) -> Bool {
        guard let suppressedUntil = suppressedScheduledBlocks[scheduler.id] else { return false }
        return suppressedUntil > now
    }

    private func restorePersistedScheduledSuppressions(now: Date = .now) {
        let activeSuppressions = schedulers.filter { scheduler in
            guard let suppressedUntil = suppressedScheduledBlocks[scheduler.id] else {
                return false
            }

            return suppressedUntil > now && scheduler.isActive(on: now)
        }

        guard !activeSuppressions.isEmpty else { return }

        for scheduler in activeSuppressions {
            deviceActivityScheduler.stopMonitoringCurrentInterval(for: scheduler, on: now)
            deviceActivityDebugStore.log(
                "Supresión restaurada para \(scheduler.title) hasta \(suppressedScheduledBlocks[scheduler.id] ?? now)."
            )
        }

        clearActiveShield()
        isBlocking = false
        activeBlockSource = nil
        blockedUntil = nil
        remainingBlockTimeText = nil
        blockMessage = "Este ritual fue detenido con NFC y seguira pausado hasta su hora de fin."
    }

    private func saveScheduledSuppressions() {
        let storedValues = Dictionary(
            uniqueKeysWithValues: suppressedScheduledBlocks.map { schedulerId, endDate in
                (schedulerId.uuidString, endDate.timeIntervalSince1970)
            }
        )

        defaults.set(storedValues, forKey: scheduledSuppressionsKey)
    }

    private static func loadScheduledSuppressions(
        defaults: UserDefaults,
        key: String,
        now: Date = .now
    ) -> [UUID: Date] {
        guard let storedValues = defaults.dictionary(forKey: key) else {
            return [:]
        }

        let suppressions = storedValues.reduce(into: [UUID: Date]()) { result, entry in
            guard let schedulerId = UUID(uuidString: entry.key),
                  let timestamp = entry.value as? TimeInterval else {
                return
            }

            let endDate = Date(timeIntervalSince1970: timestamp)
            guard endDate > now else { return }
            result[schedulerId] = endDate
        }

        let normalizedValues = Dictionary(
            uniqueKeysWithValues: suppressions.map { schedulerId, endDate in
                (schedulerId.uuidString, endDate.timeIntervalSince1970)
            }
        )
        defaults.set(normalizedValues, forKey: key)

        return suppressions
    }

    private func startCoreRitualSessionIfPossible(startSource: String, plannedEndAt: Date?) {
        guard activeCoreSession == nil,
              let accessToken = activeAccessToken,
              !accessToken.isEmpty,
              let ritualId = selectedScheduler?.coreRitualId else {
            return
        }

        Task { [weak self] in
            guard let self else { return }

            do {
                let session = try await self.coreApi.startRitualSession(
                    accessToken: accessToken,
                    body: StartRitualSessionRequest(
                        ritualId: ritualId,
                        plannedEndAt: plannedEndAt.map(Self.isoDateString),
                        startSource: startSource
                    )
                )

                self.activeCoreSession = session
                self.coreSyncMessage = "Sesión de ritual iniciada."
                await self.loadRitualSessionSummary(accessToken: accessToken)
                await self.loadRitualSessionHistories(accessToken: accessToken)
                print("Core ritual session started:", session.id)
            } catch {
                self.coreSyncMessage = error.localizedDescription
                print("Core ritual session start error:", error)
            }
        }
    }

    private func clearActiveShield() {
        deviceActivityDebugStore.log("Liberando ManagedSettings.")
        blocker.clearShield()

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.blocker.clearShield()
            }
        }

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.blocker.clearShield()
            }
        }

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.blocker.clearShield()
            }
        }
    }

    private func finishCoreRitualSessionIfPossible(status: String, endSource: String) {
        guard let accessToken = activeAccessToken,
              !accessToken.isEmpty else {
            return
        }

        let knownSession = activeCoreSession
        activeCoreSession = nil

        Task { [weak self] in
            guard let self else { return }

            do {
                let session: RitualSessionResponse

                if let knownSession {
                    session = knownSession
                } else if let activeSession = try await self.coreApi.getActiveRitualSession(accessToken: accessToken) {
                    session = activeSession
                } else {
                self.coreSyncMessage = "No habia sesión activa en core-api para finalizar."
                    await self.refreshRitualSessionState(accessToken: accessToken)
                    return
                }

                let finishedSession = try await self.coreApi.finishRitualSession(
                    accessToken: accessToken,
                    sessionId: session.id,
                    body: FinishRitualSessionRequest(status: status, endSource: endSource)
                )

                self.coreSyncMessage = "Sesión de ritual finalizada."
                self.activeCoreSession = nil
                await self.refreshRitualSessionState(accessToken: accessToken)
                print("Core ritual session finished:", finishedSession.id)
            } catch {
                self.coreSyncMessage = error.localizedDescription
                print("Core ritual session finish error:", error)
            }
        }
    }

    private static func isoDateString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func isEarlyMonitorEnd(
        _ endedEvent: SharedRitualActivityEvent,
        plannedEndAt: Date?
    ) -> Bool {
        guard let plannedEndAt else { return false }
        return endedEvent.occurredAt < plannedEndAt.addingTimeInterval(-earlyMonitorEndGraceSeconds)
    }

    private func updateRemainingTime() {
        guard let blockedUntil else {
            remainingBlockTimeText = nil
            return
        }

        let remaining = max(0, Int(blockedUntil.timeIntervalSinceNow))
        let minutes = remaining / 60
        let seconds = remaining % 60
        remainingBlockTimeText = String(format: "%02d:%02d", minutes, seconds)
    }
}
