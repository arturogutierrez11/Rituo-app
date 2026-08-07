import Combine
import CryptoKit
import FamilyControls
import Foundation
import SwiftUI

struct ReviewDemoTagPrompt: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class BlockSetupViewModel: ObservableObject {
    private struct PendingCoreSessionFinish: Codable {
        let operationID: UUID?
        let sessionId: String?
        let ritualId: String?
        let status: String
        let endSource: String
        let tagIdentifier: String?
        let createdAt: Date
    }

    private struct PendingCoreModeSessionFinish: Codable {
        let operationID: UUID?
        let sessionId: String?
        let modeId: String?
        let status: String
        let endSource: String
        let tagIdentifier: String?
        let createdAt: Date
    }

    private struct PendingScheduledRitualRecord: Codable {
        let title: String
        let request: RecordRitualSessionRequest
    }

    private struct PendingModeConfiguration: Codable {
        let localModeID: String
        let coreModeID: String?
        let updateRequest: UpdateModeRequest
        let blockedItemsRequest: ReplaceModeBlockedItemsRequest
    }

    private struct PendingRitualConfiguration: Codable {
        let localSchedulerID: UUID
        let coreRitualID: String?
        let createRequest: CreateRitualRequest
        let blockedItemsRequest: ReplaceRitualBlockedItemsRequest
    }

    private struct PendingRitualDeletion: Codable {
        let scheduler: RitualScheduler
        let coreRitualID: String
    }

    private enum BlockSource {
        case manual
        case scheduled(UUID)
        case mode(FocusMode.ID)
    }

    @Published var registeredTagIdentifier: String?
    @Published var selection = FamilyActivitySelection()
    @Published var selectedDuration: BlockDuration = .thirtyMinutes
    @Published var schedulers: [RitualScheduler]
    @Published var modes: [FocusMode]
    @Published var selectedSchedulerID: RitualScheduler.ID?
    @Published var isPickerPresented = false
    @Published private(set) var isStartingMode = false
    @Published private(set) var startingModeTitle: String?
    @Published var modeActivityPickerTarget: FocusMode?
    @Published var isAuthorizing = false
    @Published var isBlocking = false
    @Published var isReadingTag = false
    @Published var authorizationMessage: String?
    @Published var blockMessage: String?
    @Published var schedulerMessage: String?
    @Published var modeMessage: String?
    @Published var tagMessage: String?
    @Published var coreSyncMessage: String?
    @Published var isFocusSessionConflictPresented = false
    @Published var focusSessionConflictTitle = "Ya hay una sesión activa"
    @Published var focusSessionConflictMessage = "Finalizá la sesión actual antes de comenzar otra."
    @Published var deviceActivityDebugEvents: [String] = []
    @Published var isSyncingRituals = false
    @Published var blockedUntil: Date?
    @Published var remainingBlockTimeText: String?
    @Published var modeBreakUntil: Date?
    @Published var modeBreakRemainingText: String?
    @Published var hasUsedModeBreakInCurrentSession = false
    @Published var activeCoreSession: RitualSessionResponse?
    @Published var activeCoreModeSession: ModeSessionResponse?
    @Published var ritualSessionSummary: RitualSessionSummaryResponse?
    @Published var modeSessionSummary: ModeSessionSummaryResponse?
    @Published var focusMetricsSummary: FocusMetricsSummaryResponse?
    @Published var ritualSessionsByRitualId: [String: [RitualSessionResponse]] = [:]
    @Published var modeSessionsByModeId: [String: [ModeSessionResponse]] = [:]
    @Published var nfcTagClaims: [NfcTagClaimResponse] = []
    @Published var emergencyUnlockStatus: EmergencyUnlockStatusResponse?
    @Published var emergencyUnlockMessage: String?
    @Published private(set) var nfcTagSetupRequestID: UUID?
    @Published var isLoadingNfcTags = false
    @Published var isRevokingNfcTag = false
    @Published var isLoadingEmergencyUnlock = false
    @Published var isLoadingSessionSummary = false
    @Published var isLoadingFocusMetrics = false
    @Published var isLoadingSessionHistories = false
    @Published private(set) var pendingSyncCount = 0
    @Published private(set) var failedSyncCount = 0
    @Published private(set) var isStrictModeEnabled = false
    @Published private(set) var isAppInstallationBlockingEnabled = false
    @Published private(set) var isSensitiveWebContentBlockingEnabled = false
    @Published private(set) var isAppReviewAccount = false
    @Published private(set) var reviewDemoTagPrompt: ReviewDemoTagPrompt?

    private let authorizer = FamilyControlsAuthorizer()
    private let blocker = AppBlocker()
    private let deviceActivityScheduler = DeviceActivityScheduler()
    private let modeBreakActivityScheduler = ModeBreakActivityScheduler()
    private let modeEndActivityScheduler = ModeEndActivityScheduler()
    private let deviceActivityDebugStore = DeviceActivityDebugStore()
    private let activityEventStore = SharedRitualActivityEventStore()
    private let sharedSuppressionStore = SharedRitualSuppressionStore()
    private let activeModeSnapshotStore = SharedActiveModeSnapshotStore()
    private let sharedStrictModeStore = SharedStrictModeStore()
    private let sharedAppInstallationBlockStore = SharedAppInstallationBlockStore()
    private let sharedSensitiveWebContentBlockStore = SharedSensitiveWebContentBlockStore()
    private let notificationService = RitualNotificationService()
    private let nfcReader = NFCTagReader()
    private let connectivityMonitor = NetworkConnectivityMonitor()
    private let coreApi: CoreApiService
    private let syncOutbox: SyncOutboxStore
    private let keychainStore = KeychainTokenStore.shared
    private let schedulerStore: SchedulerStore
    private let modeStore: ModeStore
    private let defaults: UserDefaults
    private var unblockTask: Task<Void, Never>?
    private var modeBreakTask: Task<Void, Never>?
    private var delayedShieldClearTasks: [Task<Void, Never>] = []
    private var delayedModeShieldClearTasks: [Task<Void, Never>] = []
    private var countdownTimer: Timer?
    private var scheduleStateTimer: Timer?
    private var ritualOutboxRetryTask: Task<Void, Never>?
    private var modeOutboxRetryTask: Task<Void, Never>?
    private var scheduledRitualOutboxRetryTask: Task<Void, Never>?
    private var configurationOutboxRetryTask: Task<Void, Never>?
    private var activeBlockSource: BlockSource?
    private var suppressedScheduledBlocks: [UUID: Date] = [:]
    private var pendingCoreSessionFinish: PendingCoreSessionFinish?
    private var pendingCoreModeSessionFinish: PendingCoreModeSessionFinish?
    private var isStartingCoreSession = false
    private var isFinishingCoreSession = false
    private var isStartingCoreModeSession = false
    private var isFinishingCoreModeSession = false
    private var didResolveActiveRitualSession = false
    private var didResolveActiveModeSession = false
    private var pendingRitualPasswords: [UUID: String] = [:]
    private var pendingModePasswords: [FocusMode.ID: String] = [:]
    private var activeAccountID: String?
    private var activeModeAccountID: String?
    private let registeredTagKey = "rituo.registeredTagIdentifier"
    private let scheduledSuppressionsKey = "rituo.scheduledBlockSuppressions"
    private let pendingCoreSessionFinishKey = "rituo.pendingCoreSessionFinish"
    private let pendingCoreModeSessionFinishKey = "rituo.pendingCoreModeSessionFinish"
    private let modeBreakUntilKey = "rituo.modeBreakUntil"
    private let modeBreakUsedModeIDKey = "rituo.modeBreakUsedModeID"
    private var activeAccessToken: String?
    private var reviewDemoTagCompletion: ((Result<NFCTagScanResult, Error>) -> Void)?
    private static let earlyMonitorEndGraceSeconds: TimeInterval = 60

    init(
        schedulerStore: SchedulerStore? = nil,
        modeStore: ModeStore? = nil,
        coreApi: CoreApiService? = nil,
        syncOutbox: SyncOutboxStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.schedulerStore = schedulerStore ?? SchedulerStore(defaults: defaults)
        self.modeStore = modeStore ?? ModeStore(defaults: defaults)
        self.coreApi = coreApi ?? .shared
        self.syncOutbox = syncOutbox ?? .shared
        self.defaults = defaults
        self.schedulers = []
        self.modes = FocusMode.defaults
        self.registeredTagIdentifier = defaults.string(forKey: registeredTagKey)
        self.suppressedScheduledBlocks = Self.loadScheduledSuppressions(
            defaults: defaults,
            key: scheduledSuppressionsKey
        )
        if let pendingData = defaults.data(forKey: pendingCoreSessionFinishKey) {
            self.pendingCoreSessionFinish = try? JSONDecoder().decode(
                PendingCoreSessionFinish.self,
                from: pendingData
            )
        }
        if let pendingModeData = defaults.data(forKey: pendingCoreModeSessionFinishKey) {
            self.pendingCoreModeSessionFinish = try? JSONDecoder().decode(
                PendingCoreModeSessionFinish.self,
                from: pendingModeData
            )
        }
        if let savedModeBreakUntil = defaults.object(forKey: modeBreakUntilKey) as? Date,
           savedModeBreakUntil > .now {
            self.modeBreakUntil = savedModeBreakUntil
            self.modeBreakRemainingText = Self.formattedModeBreakRemaining(until: savedModeBreakUntil)
        } else {
            defaults.removeObject(forKey: modeBreakUntilKey)
        }
        self.sharedSuppressionStore.replaceSuppressions(self.suppressedScheduledBlocks)
        rescheduleDeviceActivities()
        restorePersistedScheduledSuppressions()
        startScheduleStateTimer()
        refreshDeviceActivityDebugEvents()
        connectivityMonitor.start { [weak self] in
            Task { @MainActor [weak self] in
                await self?.retryPendingSyncAfterConnectivityRestored()
            }
        }
    }


    func updateAccessToken(_ accessToken: String?) {
        activeAccessToken = accessToken
    }

    func configureAppReviewAccount(email: String?) {
        isAppReviewAccount =
            email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
            "hello@rituo.io"

        if !isAppReviewAccount {
            cancelReviewDemoTagInteraction()
        }
    }

    private func persistSchedulers() {
        guard let accountID = activeAccountID, !accountID.isEmpty else {
            return
        }
        schedulerStore.save(schedulers, accountID: accountID)
    }

    func updateAuthenticatedUserID(_ userID: String?) {
        guard activeAccountID != userID else { return }

        let previousAccountID = activeAccountID
        ritualOutboxRetryTask?.cancel()
        modeOutboxRetryTask?.cancel()
        scheduledRitualOutboxRetryTask?.cancel()
        configurationOutboxRetryTask?.cancel()
        if previousAccountID != nil {
            pendingCoreSessionFinish = nil
            pendingCoreModeSessionFinish = nil
        }
        activeAccountID = userID
        modeActivityPickerTarget = nil

        guard let userID, !userID.isEmpty else {
            schedulers = []
            modes = FocusMode.defaults
            isStrictModeEnabled = false
            isAppInstallationBlockingEnabled = false
            isSensitiveWebContentBlockingEnabled = false
            if !hasActiveBlockingContext {
                blocker.setInteractiveStrictModeActive(false)
            }
            blocker.clearAppInstallationBlocking()
            blocker.clearSensitiveWebContentBlocking()
            rescheduleDeviceActivities()
            reconcileSafariContentBlocking()
            return
        }

        schedulers = schedulerStore.load(accountID: userID)
        isStrictModeEnabled = sharedStrictModeStore.isEnabled(userID: userID)
        isAppInstallationBlockingEnabled = sharedAppInstallationBlockStore.isEnabled(userID: userID)
        isSensitiveWebContentBlockingEnabled = sharedSensitiveWebContentBlockStore.isEnabled(userID: userID)
        blocker.setAppInstallationBlockingActive(isAppInstallationBlockingEnabled)
        blocker.setSensitiveWebContentBlockingActive(isSensitiveWebContentBlockingEnabled)
        modes = modeStore.load(accountID: userID)
        applyRitualDeletionTombstones(userID: userID)
        rescheduleDeviceActivities()
        importDeviceActivityEvents(userID: userID)
        restorePendingSyncOperations(userID: userID)
        restoreActiveModeIfNeeded(accountID: userID)
        reconcileInteractiveStrictModeRestriction()
        reconcileSafariContentBlocking()
        refreshSyncOutboxStatus()

        if let accessToken = activeAccessToken, !accessToken.isEmpty {
            Task { [weak self] in
                await self?.syncPendingDeviceActivityEvents(accessToken: accessToken)
            }
        }
    }

    func clearAuthenticatedState() {
        ritualOutboxRetryTask?.cancel()
        modeOutboxRetryTask?.cancel()
        scheduledRitualOutboxRetryTask?.cancel()
        configurationOutboxRetryTask?.cancel()
        unblockTask?.cancel()
        unblockTask = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        modeBreakTask?.cancel()
        modeBreakTask = nil
        delayedShieldClearTasks.forEach { $0.cancel() }
        delayedShieldClearTasks.removeAll()
        delayedModeShieldClearTasks.forEach { $0.cancel() }
        delayedModeShieldClearTasks.removeAll()

        // Signing out ends every local blocking context. Keep the account's
        // saved rituals and modes, but stop their system monitors and remove
        // every restriction before the authentication state disappears.
        deviceActivityScheduler.clearAll()
        modeBreakActivityScheduler.cancelCurrent()
        modeEndActivityScheduler.cancelCurrent()
        notificationService.clearAll()
        blocker.clearAllShields()
        blocker.clearAllStrictModeRestrictions()
        blocker.clearAppInstallationBlocking()
        blocker.clearSensitiveWebContentBlocking()
        blocker.refreshSafariContentBlocking(isEnabled: false)
        sharedSuppressionStore.setModeActive(false)
        sharedSuppressionStore.replaceSuppressions([:])
        activeModeSnapshotStore.clear()

        defaults.removeObject(forKey: scheduledSuppressionsKey)
        defaults.removeObject(forKey: pendingCoreSessionFinishKey)
        defaults.removeObject(forKey: pendingCoreModeSessionFinishKey)
        defaults.removeObject(forKey: modeBreakUntilKey)
        defaults.removeObject(forKey: modeBreakUsedModeIDKey)

        activeAccessToken = nil
        activeAccountID = nil
        activeModeAccountID = nil
        activeCoreSession = nil
        activeCoreModeSession = nil
        activeBlockSource = nil
        didResolveActiveRitualSession = false
        didResolveActiveModeSession = false
        schedulers = []
        modes = FocusMode.defaults
        selection = FamilyActivitySelection()
        selectedSchedulerID = nil
        suppressedScheduledBlocks = [:]
        pendingCoreSessionFinish = nil
        pendingCoreModeSessionFinish = nil
        pendingRitualPasswords = [:]
        pendingModePasswords = [:]
        isBlocking = false
        isStrictModeEnabled = false
        isAppInstallationBlockingEnabled = false
        isSensitiveWebContentBlockingEnabled = false
        blockedUntil = nil
        remainingBlockTimeText = nil
        modeBreakUntil = nil
        modeBreakRemainingText = nil
        hasUsedModeBreakInCurrentSession = false
        ritualSessionSummary = nil
        modeSessionSummary = nil
        focusMetricsSummary = nil
        ritualSessionsByRitualId = [:]
        modeSessionsByModeId = [:]
        coreSyncMessage = nil
        modeMessage = nil
        tagMessage = nil
        emergencyUnlockStatus = nil
        emergencyUnlockMessage = nil
        isAppReviewAccount = false
        cancelReviewDemoTagInteraction()
        pendingSyncCount = 0
        failedSyncCount = 0
        applyNfcClaims([])
    }

    func deleteLocalAccountData(userID: String) {
        clearLocalConfiguration(
            userID: userID,
            preserveAuthentication: false,
            preserveTag: false
        )
    }

    func applyRemoteSupportReset(userID: String, preserveTag: Bool) {
        clearLocalConfiguration(
            userID: userID,
            preserveAuthentication: true,
            preserveTag: preserveTag
        )
    }

    private func clearLocalConfiguration(
        userID: String,
        preserveAuthentication: Bool,
        preserveTag: Bool
    ) {
        let savedAccessToken = activeAccessToken
        let savedTagIdentifier = registeredTagIdentifier
        ritualOutboxRetryTask?.cancel()
        modeOutboxRetryTask?.cancel()
        scheduledRitualOutboxRetryTask?.cancel()
        configurationOutboxRetryTask?.cancel()
        unblockTask?.cancel()
        countdownTimer?.invalidate()
        modeBreakTask?.cancel()
        modeBreakActivityScheduler.cancelCurrent()

        deviceActivityScheduler.clearAll()
        notificationService.clearAll()
        blocker.clearAllShields()
        blocker.clearAllStrictModeRestrictions()
        blocker.clearAppInstallationBlocking()
        blocker.clearSensitiveWebContentBlocking()
        sharedSuppressionStore.setModeActive(false)
        activeModeSnapshotStore.clear()
        sharedSuppressionStore.replaceSuppressions([:])
        sharedStrictModeStore.remove(userID: userID)
        sharedAppInstallationBlockStore.remove(userID: userID)
        sharedSensitiveWebContentBlockStore.remove(userID: userID)

        let operationIDs = syncOutbox.removeAll(userID: userID)
        operationIDs.forEach {
            keychainStore.deleteSyncSecret(operationID: $0)
        }
        keychainStore.clearSyncSecrets()

        schedulerStore.clear(accountID: userID)
        modeStore.clear(accountID: userID)
        if !preserveTag {
            defaults.removeObject(forKey: registeredTagKey)
        }
        defaults.removeObject(forKey: scheduledSuppressionsKey)
        defaults.removeObject(forKey: pendingCoreSessionFinishKey)
        defaults.removeObject(forKey: pendingCoreModeSessionFinishKey)
        defaults.removeObject(forKey: modeBreakUntilKey)
        defaults.removeObject(forKey: modeBreakUsedModeIDKey)

        let appGroupIdentifier = "group.io.rituo.app"
        UserDefaults(suiteName: appGroupIdentifier)?
            .removePersistentDomain(forName: appGroupIdentifier)

        schedulers = []
        modes = FocusMode.defaults
        selection = FamilyActivitySelection()
        selectedSchedulerID = nil
        registeredTagIdentifier = preserveTag ? savedTagIdentifier : nil
        suppressedScheduledBlocks = [:]
        pendingCoreSessionFinish = nil
        pendingCoreModeSessionFinish = nil
        pendingRitualPasswords = [:]
        pendingModePasswords = [:]
        activeBlockSource = nil
        activeModeAccountID = nil
        isBlocking = false
        isStrictModeEnabled = false
        isAppInstallationBlockingEnabled = false
        isSensitiveWebContentBlockingEnabled = false
        blockedUntil = nil
        remainingBlockTimeText = nil
        modeBreakUntil = nil
        modeBreakRemainingText = nil
        hasUsedModeBreakInCurrentSession = false

        activeAccountID = nil
        if preserveAuthentication {
            activeAccessToken = savedAccessToken
            updateAuthenticatedUserID(userID)
        } else {
            updateAuthenticatedUserID(nil)
            clearAuthenticatedState()
        }
    }

    func syncPendingDeviceActivityEvents(accessToken: String) async {
        guard !accessToken.isEmpty,
              let userID = activeAccountID else {
            return
        }

        importDeviceActivityEvents(userID: userID)
        await syncPendingCoreModeSessionFinish(accessToken: accessToken)

        let operations = syncOutbox.operations(
            userID: userID,
            type: .recordScheduledRitual
        )
        var synchronizedAny = false

        for operation in operations where syncOutbox.isDue(id: operation.id) {
            guard let pending = try? JSONDecoder().decode(
                PendingScheduledRitualRecord.self,
                from: operation.payload
            ) else {
                syncOutbox.remove(id: operation.id)
                deviceActivityDebugStore.log(
                    "Registro scheduler inválido descartado: \(operation.id.uuidString)."
                )
                continue
            }

            syncOutbox.markSyncing(id: operation.id)

            do {
                let session = try await coreApi.recordRitualSession(
                    accessToken: accessToken,
                    body: pending.request,
                    idempotencyKey: operation.idempotencyKey
                )
                syncOutbox.remove(id: operation.id)
                synchronizedAny = true
                deviceActivityDebugStore.log(
                    "Sesión sincronizada desde monitor: \(pending.title) \(session.id)."
                )
            } catch {
                if Self.isMissingRitualError(error) {
                    syncOutbox.remove(id: operation.id)
                    deviceActivityDebugStore.log(
                        "Evento descartado: \(pending.title) ya no existe en core-api."
                    )
                } else {
                    syncOutbox.markFailure(id: operation.id, error: error)
                    coreSyncMessage = error.localizedDescription
                    deviceActivityDebugStore.log(
                        "Error sync evento monitor \(pending.title): \(error.localizedDescription)"
                    )
                    print("DeviceActivity event sync error:", error)
                }
            }
        }

        scheduleScheduledRitualOutboxRetry(
            userID: userID,
            accessToken: accessToken
        )
        refreshSyncOutboxStatus()

        if synchronizedAny {
            await loadRitualSessionSummary(accessToken: accessToken)
            await loadRitualSessionHistories(accessToken: accessToken)
            await loadFocusMetricsSummary(accessToken: accessToken)
        }
    }

    private func retryPendingSyncAfterConnectivityRestored() async {
        guard let userID = activeAccountID,
              let accessToken = activeAccessToken,
              !accessToken.isEmpty else {
            return
        }

        syncOutbox.makeDue(userID: userID)
        refreshSyncOutboxStatus()
        deviceActivityDebugStore.log(
            "Conexión recuperada. Reintentando sincronizaciones pendientes."
        )
        await syncPendingCoreSessionFinish(accessToken: accessToken)
        await syncPendingCoreModeSessionFinish(accessToken: accessToken)
        await syncPendingDeviceActivityEvents(accessToken: accessToken)
        await syncPendingConfigurationOperations(accessToken: accessToken)
    }

    func retryFailedSyncOperations() {
        guard let userID = activeAccountID,
              let accessToken = activeAccessToken,
              !accessToken.isEmpty else {
            return
        }

        syncOutbox.retryFailed(userID: userID)
        refreshSyncOutboxStatus()

        Task { [weak self] in
            guard let self else { return }
            await self.syncPendingCoreSessionFinish(accessToken: accessToken)
            await self.syncPendingCoreModeSessionFinish(accessToken: accessToken)
            await self.syncPendingDeviceActivityEvents(accessToken: accessToken)
            await self.syncPendingConfigurationOperations(accessToken: accessToken)
        }
    }

    private func queueModeConfiguration(
        _ mode: FocusMode,
        password: String? = nil
    ) throws {
        guard let userID = activeAccountID else { return }
        let operationID = Self.scopedSyncOperationID(
            userID: userID,
            type: .syncModeConfiguration,
            scope: mode.id
        )
        let payload = PendingModeConfiguration(
            localModeID: mode.id,
            coreModeID: mode.coreModeId,
            updateRequest: mode.updateModeRequest(),
            blockedItemsRequest: mode.blockedItemsRequest
        )

        if let password, !password.isEmpty {
            try keychainStore.saveSyncSecret(password, operationID: operationID)
        } else if !mode.isProtected {
            keychainStore.deleteSyncSecret(operationID: operationID)
        }

        try syncOutbox.upsertScoped(
            id: operationID,
            userID: userID,
            type: .syncModeConfiguration,
            payload: JSONEncoder().encode(payload)
        )
        refreshSyncOutboxStatus()
    }

    private func queueRitualConfiguration(
        _ scheduler: RitualScheduler,
        password: String? = nil
    ) throws {
        guard let userID = activeAccountID else { return }
        let operationID = Self.scopedSyncOperationID(
            userID: userID,
            type: .createRitualConfiguration,
            scope: scheduler.id.uuidString
        )
        let payload = PendingRitualConfiguration(
            localSchedulerID: scheduler.id,
            coreRitualID: scheduler.coreRitualId,
            createRequest: scheduler.createRitualRequest(),
            blockedItemsRequest: scheduler.blockedItemsRequest
        )

        if let password, !password.isEmpty {
            try keychainStore.saveSyncSecret(password, operationID: operationID)
        }

        try syncOutbox.upsertScoped(
            id: operationID,
            userID: userID,
            type: .createRitualConfiguration,
            payload: JSONEncoder().encode(payload)
        )
        refreshSyncOutboxStatus()
    }

    private func removeQueuedRitualConfiguration(
        _ scheduler: RitualScheduler
    ) {
        guard let userID = activeAccountID else { return }
        let operationID = Self.scopedSyncOperationID(
            userID: userID,
            type: .createRitualConfiguration,
            scope: scheduler.id.uuidString
        )
        keychainStore.deleteSyncSecret(operationID: operationID)
        syncOutbox.remove(id: operationID)
        pendingRitualPasswords.removeValue(forKey: scheduler.id)
        refreshSyncOutboxStatus()
    }

    private func queueRitualDeletion(
        _ scheduler: RitualScheduler,
        coreRitualID: String,
        password: String?
    ) throws {
        guard let userID = activeAccountID else { return }
        let operationID = Self.scopedSyncOperationID(
            userID: userID,
            type: .deleteRitual,
            scope: scheduler.id.uuidString
        )
        let payload = PendingRitualDeletion(
            scheduler: scheduler,
            coreRitualID: coreRitualID
        )

        if let password, !password.isEmpty {
            try keychainStore.saveSyncSecret(password, operationID: operationID)
        }
        try syncOutbox.upsertScoped(
            id: operationID,
            userID: userID,
            type: .deleteRitual,
            payload: JSONEncoder().encode(payload)
        )
        refreshSyncOutboxStatus()
    }

    private func applyRitualDeletionTombstones(userID: String) {
        let deletedSchedulerIDs = Set(
            syncOutbox.operations(userID: userID, type: .deleteRitual)
                .compactMap {
                    try? JSONDecoder().decode(
                        PendingRitualDeletion.self,
                        from: $0.payload
                    ).scheduler.id
                }
        )
        guard !deletedSchedulerIDs.isEmpty else { return }
        schedulers.removeAll { deletedSchedulerIDs.contains($0.id) }
        persistSchedulers()
        rescheduleDeviceActivities()
    }

    private func syncPendingConfigurationOperations(accessToken: String) async {
        guard let userID = activeAccountID, !accessToken.isEmpty else { return }

        await syncPendingModeConfigurations(
            userID: userID,
            accessToken: accessToken
        )
        await syncPendingRitualConfigurations(
            userID: userID,
            accessToken: accessToken
        )
        await syncPendingRitualDeletions(
            userID: userID,
            accessToken: accessToken
        )
        scheduleConfigurationOutboxRetry(
            userID: userID,
            accessToken: accessToken
        )
        refreshSyncOutboxStatus()
    }

    private func syncPendingModeConfigurations(
        userID: String,
        accessToken: String
    ) async {
        let operations = syncOutbox.operations(
            userID: userID,
            type: .syncModeConfiguration
        )

        for operation in operations where syncOutbox.isDue(id: operation.id) {
            guard let pending = try? JSONDecoder().decode(
                PendingModeConfiguration.self,
                from: operation.payload
            ) else {
                clearConfigurationOperation(operation)
                continue
            }

            syncOutbox.markSyncing(id: operation.id)
            do {
                let coreModeID: String
                if let storedID = pending.coreModeID
                    ?? modes.first(where: { $0.id == pending.localModeID })?.coreModeId {
                    coreModeID = storedID
                } else {
                    let coreModes = try await coreApi.listModes(accessToken: accessToken)
                    mergeCoreModes(coreModes)
                    guard let resolvedID = modes.first(
                        where: { $0.id == pending.localModeID }
                    )?.coreModeId else {
                        throw CoreAPIError.invalidResponse
                    }
                    coreModeID = resolvedID
                }

                let password = keychainStore.loadSyncSecret(
                    operationID: operation.id
                )
                let response = try await coreApi.updateMode(
                    accessToken: accessToken,
                    modeId: coreModeID,
                    body: pending.updateRequest.withPassword(password),
                    idempotencyKey: "\(operation.idempotencyKey):config"
                )
                _ = try await coreApi.replaceModeBlockedItems(
                    accessToken: accessToken,
                    modeId: coreModeID,
                    body: pending.blockedItemsRequest,
                    idempotencyKey: "\(operation.idempotencyKey):items"
                )

                if let index = modes.firstIndex(
                    where: { $0.id == pending.localModeID }
                ) {
                    let localSelection = modes[index].selection
                    let localStrictModeEnabled = modes[index].strictModeEnabled
                    let localBlockAppInstallation = modes[index].blockAppInstallation
                    let localBlockAdultContent = modes[index].blockAdultContent
                    modes[index] = FocusMode(
                        response: response,
                        preserving: localSelection
                    )
                    modes[index].strictModeEnabled = localStrictModeEnabled
                    modes[index].blockAppInstallation = localBlockAppInstallation
                    modes[index].blockAdultContent = localBlockAdultContent
                    modeStore.save(modes, accountID: userID)
                }
                pendingModePasswords.removeValue(forKey: pending.localModeID)
                clearConfigurationOperation(operation)
            } catch {
                syncOutbox.markFailure(id: operation.id, error: error)
                modeMessage = "El modo quedó pendiente de sincronización."
            }
        }
    }

    private func syncPendingRitualConfigurations(
        userID: String,
        accessToken: String
    ) async {
        let operations = syncOutbox.operations(
            userID: userID,
            type: .createRitualConfiguration
        )

        for operation in operations where syncOutbox.isDue(id: operation.id) {
            guard var pending = try? JSONDecoder().decode(
                PendingRitualConfiguration.self,
                from: operation.payload
            ) else {
                clearConfigurationOperation(operation)
                continue
            }

            syncOutbox.markSyncing(id: operation.id)
            do {
                let response: RitualResponse
                if let coreRitualID = pending.coreRitualID {
                    response = try await coreApi.getRitual(
                        accessToken: accessToken,
                        ritualId: coreRitualID
                    )
                } else {
                    let password = keychainStore.loadSyncSecret(
                        operationID: operation.id
                    )
                    response = try await coreApi.createRitual(
                        accessToken: accessToken,
                        body: pending.createRequest.withPassword(password),
                        idempotencyKey: "\(operation.idempotencyKey):config"
                    )
                    pending = PendingRitualConfiguration(
                        localSchedulerID: pending.localSchedulerID,
                        coreRitualID: response.id,
                        createRequest: pending.createRequest,
                        blockedItemsRequest: pending.blockedItemsRequest
                    )
                    try syncOutbox.updatePayload(
                        id: operation.id,
                        payload: JSONEncoder().encode(pending)
                    )
                    applyCoreRitualResponse(
                        response,
                        localSchedulerID: pending.localSchedulerID
                    )
                }

                _ = try await coreApi.replaceRitualBlockedItems(
                    accessToken: accessToken,
                    ritualId: response.id,
                    body: pending.blockedItemsRequest,
                    idempotencyKey: "\(operation.idempotencyKey):items"
                )
                applyCoreRitualResponse(
                    response,
                    localSchedulerID: pending.localSchedulerID
                )
                pendingRitualPasswords.removeValue(
                    forKey: pending.localSchedulerID
                )
                clearConfigurationOperation(operation)
            } catch {
                syncOutbox.markFailure(id: operation.id, error: error)
                coreSyncMessage = "El ritual quedó pendiente de sincronización."
            }
        }
    }

    private func clearConfigurationOperation(
        _ operation: PendingSyncOperation
    ) {
        keychainStore.deleteSyncSecret(operationID: operation.id)
        syncOutbox.remove(id: operation.id)
    }

    private func syncPendingRitualDeletions(
        userID: String,
        accessToken: String
    ) async {
        let operations = syncOutbox.operations(
            userID: userID,
            type: .deleteRitual
        )

        for operation in operations where syncOutbox.isDue(id: operation.id) {
            guard let pending = try? JSONDecoder().decode(
                PendingRitualDeletion.self,
                from: operation.payload
            ) else {
                clearConfigurationOperation(operation)
                continue
            }

            syncOutbox.markSyncing(id: operation.id)
            do {
                try await coreApi.deleteRitual(
                    accessToken: accessToken,
                    ritualId: pending.coreRitualID,
                    password: keychainStore.loadSyncSecret(
                        operationID: operation.id
                    ),
                    idempotencyKey: operation.idempotencyKey
                )
                ritualSessionsByRitualId.removeValue(
                    forKey: pending.coreRitualID
                )
                clearConfigurationOperation(operation)
            } catch {
                if Self.isRitualNotFoundError(error) {
                    clearConfigurationOperation(operation)
                } else if Self.isForbiddenError(error) {
                    restoreSchedulerAfterFailedDeletion(pending.scheduler)
                    clearConfigurationOperation(operation)
                    coreSyncMessage = error.localizedDescription
                } else {
                    syncOutbox.markFailure(id: operation.id, error: error)
                    coreSyncMessage = "La eliminación quedó pendiente de sincronización."
                }
            }
        }
    }

    private func restoreSchedulerAfterFailedDeletion(
        _ scheduler: RitualScheduler
    ) {
        guard !schedulers.contains(where: { $0.id == scheduler.id }) else {
            return
        }
        schedulers.insert(scheduler, at: 0)
        persistSchedulers()
        rescheduleDeviceActivities()
        refreshScheduledRitualState()
    }

    private func scheduleConfigurationOutboxRetry(
        userID: String,
        accessToken: String
    ) {
        configurationOutboxRetryTask?.cancel()
        let retryDates = [
            syncOutbox.nextRetryDate(
                userID: userID,
                type: .syncModeConfiguration
            ),
            syncOutbox.nextRetryDate(
                userID: userID,
                type: .createRitualConfiguration
            ),
            syncOutbox.nextRetryDate(
                userID: userID,
                type: .deleteRitual
            )
        ].compactMap { $0 }
        guard let retryDate = retryDates.min() else { return }

        configurationOutboxRetryTask = Task { [weak self] in
            let delay = max(0, retryDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled,
                  let self,
                  self.activeAccountID == userID else {
                return
            }
            await self.syncPendingConfigurationOperations(
                accessToken: accessToken
            )
        }
    }

    private static func scopedSyncOperationID(
        userID: String,
        type: SyncOperationType,
        scope: String
    ) -> UUID {
        let digest = SHA256.hash(
            data: Data("\(userID)|\(type.rawValue)|\(scope)".utf8)
        )
        let hex = digest.prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
        let first = String(hex.prefix(8))
        let second = String(hex.dropFirst(8).prefix(4))
        let third = String(hex.dropFirst(12).prefix(4))
        let fourth = String(hex.dropFirst(16).prefix(4))
        let fifth = String(hex.dropFirst(20).prefix(12))
        let uuidString = "\(first)-\(second)-\(third)-\(fourth)-\(fifth)"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func refreshSyncOutboxStatus() {
        guard let userID = activeAccountID else {
            pendingSyncCount = 0
            failedSyncCount = 0
            return
        }

        let counts = syncOutbox.counts(userID: userID)
        pendingSyncCount = counts.pending
        failedSyncCount = counts.failed
    }

    private func importDeviceActivityEvents(userID: String) {
        let events = activityEventStore.loadEvents()
            .filter { $0.userID == nil || $0.userID == userID }
            .sorted { $0.occurredAt < $1.occurredAt }
        guard !events.isEmpty else { return }

        var importedIDs = Set<UUID>()
        let timedModeEndEvents = events.filter {
            $0.eventType == "mode_timed_out"
        }
        if let latestTimedModeEnd = timedModeEndEvents.last {
            let matchingSessionID = activeCoreModeSession?.modeId == latestTimedModeEnd.coreRitualId
                ? activeCoreModeSession?.id
                : nil
            pendingCoreModeSessionFinish = PendingCoreModeSessionFinish(
                operationID: latestTimedModeEnd.id,
                sessionId: matchingSessionID,
                modeId: latestTimedModeEnd.coreRitualId,
                status: "completed",
                endSource: "timer",
                tagIdentifier: nil,
                createdAt: latestTimedModeEnd.occurredAt
            )
            savePendingCoreModeSessionFinish()
            activeCoreModeSession = nil
            sharedSuppressionStore.setModeActive(false)
            activeModeSnapshotStore.clear()
            modeStore.clearActiveMode()
            modeEndActivityScheduler.cancelCurrent()
            activeModeAccountID = nil

            if case .mode = activeBlockSource {
                clearActiveModeShield()
                isBlocking = false
                activeBlockSource = nil
                blockedUntil = nil
                remainingBlockTimeText = nil
                countdownTimer?.invalidate()
                blockMessage = "El límite del modo terminó y se quitaron sus restricciones."
            }

            importedIDs.formUnion(timedModeEndEvents.map(\.id))
            deviceActivityDebugStore.log(
                "Fin automático de modo importado para \(latestTimedModeEnd.title)."
            )
        }

        let modePreemptionEvents = events.filter {
            $0.eventType == "mode_preempted"
        }
        if let latestPreemption = modePreemptionEvents.last {
            let scheduler = UUID(uuidString: latestPreemption.schedulerId)
                .flatMap { schedulerID in
                    schedulers.first { $0.id == schedulerID }
                }
                ?? latestPreemption.coreRitualId.flatMap { coreRitualID in
                    schedulers.first { $0.coreRitualId == coreRitualID }
                }

            preemptActiveModeForScheduledRitual(
                scheduler,
                detectedByExtension: true
            )
            importedIDs.formUnion(modePreemptionEvents.map(\.id))
        }

        let groupedEvents = Dictionary(grouping: events) { event in
            [
                event.activityName,
                event.coreRitualId ?? "missing-core-id",
                event.plannedEndAt.map { String(Int($0.timeIntervalSince1970)) }
                    ?? "missing-planned-end"
            ].joined(separator: "|")
        }

        for groupEvents in groupedEvents.values {
            var unmatchedStarts: [SharedRitualActivityEvent] = []

            for event in groupEvents.sorted(by: { $0.occurredAt < $1.occurredAt }) {
                if event.eventType == "started" {
                    unmatchedStarts.append(event)
                    continue
                }

                guard event.eventType == "ended",
                      let startIndex = unmatchedStarts.firstIndex(
                        where: { $0.occurredAt <= event.occurredAt }
                      ) else {
                    continue
                }

                let startedEvent = unmatchedStarts.remove(at: startIndex)
                guard let coreRitualId = startedEvent.coreRitualId else {
                    deviceActivityDebugStore.log(
                        "Evento sin coreRitualId: \(startedEvent.title)."
                    )
                    continue
                }

                if Self.isEarlyMonitorEnd(
                    event,
                    plannedEndAt: startedEvent.plannedEndAt
                ) {
                    importedIDs.formUnion([startedEvent.id, event.id])
                    deviceActivityDebugStore.log(
                        "Evento monitor ignorado: \(startedEvent.title) termino antes del fin planificado."
                    )
                    continue
                }

                let pending = PendingScheduledRitualRecord(
                    title: startedEvent.title,
                    request: RecordRitualSessionRequest(
                        ritualId: coreRitualId,
                        startedAt: Self.isoDateString(from: startedEvent.occurredAt),
                        plannedEndAt: startedEvent.plannedEndAt.map(Self.isoDateString),
                        endedAt: Self.isoDateString(from: event.occurredAt),
                        status: "completed",
                        startSource: "schedule",
                        endSource: "schedule"
                    )
                )

                do {
                    let payload = try JSONEncoder().encode(pending)
                    try syncOutbox.enqueue(
                        id: startedEvent.id,
                        userID: userID,
                        type: .recordScheduledRitual,
                        payload: payload
                    )
                    importedIDs.formUnion([startedEvent.id, event.id])
                } catch {
                    coreSyncMessage = "No se pudo guardar una sesión programada pendiente: \(error.localizedDescription)"
                    deviceActivityDebugStore.log(
                        "Error importando evento scheduler: \(error.localizedDescription)"
                    )
                }
            }
        }

        activityEventStore.removeEvents(ids: importedIDs)
        refreshSyncOutboxStatus()
    }

    private func scheduleScheduledRitualOutboxRetry(
        userID: String,
        accessToken: String
    ) {
        scheduledRitualOutboxRetryTask?.cancel()
        guard let retryDate = syncOutbox.nextRetryDate(
            userID: userID,
            type: .recordScheduledRitual
        ) else {
            return
        }

        scheduledRitualOutboxRetryTask = Task { [weak self] in
            let delay = max(0, retryDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled,
                  let self,
                  self.activeAccountID == userID else {
                return
            }
            await self.syncPendingDeviceActivityEvents(accessToken: accessToken)
        }
    }

    private static func isMissingRitualError(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, message, _) = error else {
            return false
        }

        return statusCode == 404 && message.localizedCaseInsensitiveContains("ritual not found")
    }

    private static func isNfcClaimNotFoundError(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, message, _) = error else {
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
            didResolveActiveRitualSession = true
            if let activeCoreSession {
                coreSyncMessage = "Sesión activa en core-api: \(activeCoreSession.id)."
            }
        } catch {
            activeCoreSession = nil
            didResolveActiveRitualSession = false
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

    func loadRitualSessionHistoriesIfNeeded(accessToken: String) async {
        let ritualIds = Set(schedulers.compactMap(\.coreRitualId))
        guard !ritualIds.isSubset(of: Set(ritualSessionsByRitualId.keys)) else {
            return
        }

        await loadRitualSessionHistories(accessToken: accessToken)
    }

    func loadActiveModeSession(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        do {
            activeCoreModeSession = try await coreApi.getActiveModeSession(accessToken: accessToken)
            didResolveActiveModeSession = true
        } catch {
            activeCoreModeSession = nil
            didResolveActiveModeSession = false
            print("Core active mode session error:", error)
        }
    }

    func loadActiveFocusSession(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        do {
            let active = try await coreApi.getActiveFocusSession(accessToken: accessToken)
            activeCoreSession = active?.ritualSession
            activeCoreModeSession = active?.modeSession
            didResolveActiveRitualSession = true
            didResolveActiveModeSession = true

            if let active {
                coreSyncMessage = "Sesión de foco activa en core-api: \(active.type)."
            }
        } catch {
            activeCoreSession = nil
            activeCoreModeSession = nil
            didResolveActiveRitualSession = false
            didResolveActiveModeSession = false
            print("Core active focus session error:", error)
        }
    }

    func loadModeSessionSummary(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        do {
            modeSessionSummary = try await coreApi.getModeSessionSummary(accessToken: accessToken)
        } catch {
            print("Core mode session summary error:", error)
        }
    }

    func loadFocusMetricsSummary(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        isLoadingFocusMetrics = true
        defer { isLoadingFocusMetrics = false }

        do {
            focusMetricsSummary = try await coreApi.getFocusMetricsSummary(accessToken: accessToken)
        } catch {
            print("Core focus metrics summary error:", error)
        }
    }

    func loadModeSessionHistories(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        let modeIds = modes.compactMap(\.coreModeId)
        guard !modeIds.isEmpty else { return }

        var nextSessionsByModeId: [String: [ModeSessionResponse]] = [:]

        for modeId in modeIds {
            do {
                nextSessionsByModeId[modeId] = try await coreApi.listModeSessionsByMode(
                    accessToken: accessToken,
                    modeId: modeId
                )
            } catch {
                print("Core mode session history error:", modeId, error)
            }
        }

        modeSessionsByModeId = nextSessionsByModeId
    }

    func loadModeSessionHistoriesIfNeeded(accessToken: String) async {
        let modeIds = Set(modes.compactMap(\.coreModeId))
        guard !modeIds.isSubset(of: Set(modeSessionsByModeId.keys)) else {
            return
        }

        await loadModeSessionHistories(accessToken: accessToken)
    }

    func loadFocusHistoriesIfNeeded(accessToken: String) async {
        await loadRitualSessionHistoriesIfNeeded(accessToken: accessToken)
        await loadModeSessionHistoriesIfNeeded(accessToken: accessToken)
    }

    func sessions(for scheduler: RitualScheduler) -> [RitualSessionResponse] {
        guard let coreRitualId = scheduler.coreRitualId else { return [] }
        return ritualSessionsByRitualId[coreRitualId] ?? []
    }

    func sessions(for mode: FocusMode) -> [ModeSessionResponse] {
        guard let coreModeId = mode.coreModeId else { return [] }
        return modeSessionsByModeId[coreModeId] ?? []
    }

    func isRunningInCore(_ scheduler: RitualScheduler) -> Bool {
        guard let coreRitualId = scheduler.coreRitualId,
              let activeCoreSession else {
            return false
        }

        return activeCoreSession.ritualId == coreRitualId && activeCoreSession.status == "active"
    }

    func refreshRitualSessionState(accessToken: String) async {
        await syncPendingCoreSessionFinish(accessToken: accessToken)
        await loadActiveRitualSession(accessToken: accessToken)
        await loadRitualSessionSummary(accessToken: accessToken)
        await loadRitualSessionHistories(accessToken: accessToken)
    }

    func refreshModeSessionState(accessToken: String) async {
        await syncPendingCoreModeSessionFinish(accessToken: accessToken)
        await loadActiveModeSession(accessToken: accessToken)
        await loadModeSessionSummary(accessToken: accessToken)
        await loadModeSessionHistories(accessToken: accessToken)
    }

    func refreshFocusSessionState(accessToken: String) async {
        await syncPendingCoreSessionFinish(accessToken: accessToken)
        await syncPendingCoreModeSessionFinish(accessToken: accessToken)
        await loadActiveFocusSession(accessToken: accessToken)
    }

    func reconcileActiveFocusSession() {
        guard didResolveActiveRitualSession,
              didResolveActiveModeSession else {
            return
        }

        if let activeCoreSession {
            restoreCoreRitualSession(activeCoreSession)
            return
        }

        if let activeCoreModeSession {
            if let activeScheduler {
                preemptActiveModeForScheduledRitual(activeScheduler)
                refreshScheduledRitualState()
            } else {
                restoreCoreModeSession(activeCoreModeSession)
            }
            return
        }

        clearStaleServerBackedLocalState()
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

    var primaryNfcTagClaim: NfcTagClaimResponse? {
        nfcTagClaims.first
    }

    var hasActiveFocusSession: Bool {
        hasActiveBlockingContext
    }

    func setStrictModeEnabled(_ isEnabled: Bool) async {
        guard let userID = activeAccountID, !userID.isEmpty else {
            blockMessage = "Iniciá sesión para configurar el modo estricto."
            return
        }

        if !isEnabled && hasActiveBlockingContext {
            blockMessage = "El modo estricto no se puede desactivar durante una sesión."
            return
        }

        if isEnabled && !isAuthorized {
            await requestAuthorization()
            guard isAuthorized else {
                blockMessage = "Autorizá Screen Time para usar el modo estricto."
                return
            }
        }

        sharedStrictModeStore.setEnabled(isEnabled, userID: userID)
        isStrictModeEnabled = isEnabled

        if isEnabled {
            reconcileInteractiveStrictModeRestriction()
        } else {
            blocker.clearAllStrictModeRestrictions()
        }
    }

    func setAppInstallationBlockingEnabled(_ isEnabled: Bool) async {
        guard let userID = activeAccountID, !userID.isEmpty else {
            blockMessage = "Iniciá sesión para configurar el bloqueo de descargas."
            return
        }

        if isEnabled && !isAuthorized {
            await requestAuthorization()
            guard isAuthorized else {
                blockMessage = "Autorizá Screen Time para bloquear descargas de apps."
                return
            }
        }

        sharedAppInstallationBlockStore.setEnabled(isEnabled, userID: userID)
        isAppInstallationBlockingEnabled = isEnabled
        blocker.setAppInstallationBlockingActive(isEnabled)
        deviceActivityDebugStore.log(
            "Bloqueo global de instalaciones aplicado=\(isEnabled) user=\(userID)."
        )
    }

    func setSensitiveWebContentBlockingEnabled(_ isEnabled: Bool) async {
        guard let userID = activeAccountID, !userID.isEmpty else {
            blockMessage = "Iniciá sesión para configurar el contenido sensible."
            return
        }

        if isEnabled && !isAuthorized {
            await requestAuthorization()
            guard isAuthorized else {
                blockMessage = "Autorizá Screen Time para bloquear contenido sensible."
                return
            }
        }

        sharedSensitiveWebContentBlockStore.setEnabled(isEnabled, userID: userID)
        isSensitiveWebContentBlockingEnabled = isEnabled
        blocker.setSensitiveWebContentBlockingActive(isEnabled)
        reconcileSafariContentBlocking()
        deviceActivityDebugStore.log(
            "Bloqueo global de contenido sensible aplicado=\(isEnabled) user=\(userID)."
        )
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

    var isModeBreakActive: Bool {
        guard let modeBreakUntil else { return false }
        return modeBreakUntil > .now
    }

    func startModeBreak(minutes: Int = 5) {
        guard let mode = currentBlockingMode else {
            modeMessage = "No hay un modo activo para pausar."
            return
        }

        guard !isModeBreakActive else {
            modeMessage = "Ya tenés un recreo activo."
            return
        }

        guard !hasUsedModeBreakInCurrentSession else {
            modeMessage = "Ya usaste el recreo de este modo. Para tener otro, terminá el modo y volvé a iniciarlo."
            return
        }

        let breakUntil = Calendar.current.date(
            byAdding: .minute,
            value: minutes,
            to: .now
        ) ?? Date().addingTimeInterval(TimeInterval(minutes * 60))

        markModeBreakUsed(for: mode)
        modeBreakUntil = breakUntil
        modeBreakRemainingText = Self.formattedModeBreakRemaining(until: breakUntil)
        defaults.set(breakUntil, forKey: modeBreakUntilKey)
        blocker.clearModeShield()
        reconcileSafariContentBlocking()
        notificationService.sendModeBreakStartedNotification(for: mode, minutes: minutes)
        do {
            try modeBreakActivityScheduler.scheduleBreakEnd(
                for: mode,
                accountID: activeAccountID,
                until: breakUntil
            )
        } catch {
            deviceActivityDebugStore.log("No se pudo programar DeviceActivity para fin de recreo: \(error.localizedDescription).")
        }
        blockMessage = "Recreo activo en \(mode.title). Las restricciones vuelven en \(minutes) minutos."
        modeMessage = "Recreo de \(minutes) minutos iniciado."
        deviceActivityDebugStore.log("Recreo de modo iniciado para \(mode.title) hasta \(breakUntil).")
        scheduleModeBreakEnd(for: mode, until: breakUntil)
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

    var currentBlockingMode: FocusMode? {
        if activeModeAccountID == activeAccountID,
           case .mode(let modeID) = activeBlockSource {
            return modes.first { $0.id == modeID }
        }

        guard let activeCoreModeSession else { return nil }
        return modes.first { $0.coreModeId == activeCoreModeSession.modeId }
    }

    var isModeBlocking: Bool {
        currentBlockingMode != nil
    }

    func refreshSafariContentBlockingState() {
        reconcileSafariContentBlocking()
    }

    private var hasActiveBlockingContext: Bool {
        isBlocking || activeCoreSession != nil || activeCoreModeSession != nil || activeScheduler != nil
    }

    private var hasActiveRitualContext: Bool {
        if activeCoreSession != nil || activeScheduler != nil {
            return true
        }

        guard isBlocking else { return false }
        if case .mode = activeBlockSource {
            return false
        }
        return true
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

    func openModeActivityPicker(_ mode: FocusMode) async {
        selectedSchedulerID = nil
        modeMessage = nil

        if !isAuthorized {
            await requestAuthorization()
        }

        guard isAuthorized else {
            authorizationMessage = "Para ver y seleccionar apps tenés que autorizar Screen Time."
            return
        }

        modeActivityPickerTarget = modes.first(where: { $0.id == mode.id }) ?? mode
    }

    func saveModeActivityPickerSelection(
        for modeID: FocusMode.ID,
        selection draftSelection: FamilyActivitySelection
    ) -> Bool {
        guard let accountID = activeAccountID,
              let index = modes.firstIndex(where: { $0.id == modeID }) else {
            modeMessage = "No encontré el modo que estabas configurando."
            return false
        }

        modes[index].selection = draftSelection
        modeStore.save(modes, accountID: accountID)

        if case .mode(let activeModeID) = activeBlockSource,
           activeModeID == modeID {
            saveActiveModeSnapshot(modes[index], accountID: accountID)
            applyModeShield(
                using: draftSelection,
                blockAppInstallation: modes[index].blockAppInstallation,
                blockAdultContent: modes[index].blockAdultContent
            )
        }

        let mode = modes[index]
        do {
            try queueModeConfiguration(
                mode,
                password: pendingModePasswords[mode.id]
            )
        } catch {
            modeMessage = "No se pudo guardar el cambio pendiente: \(error.localizedDescription)"
            return false
        }

        modeMessage = "Apps guardadas en \(mode.title)."
        modeActivityPickerTarget = nil

        if let accessToken = activeAccessToken, !accessToken.isEmpty {
            Task { [weak self] in
                guard let self else { return }
                await self.syncPendingConfigurationOperations(accessToken: accessToken)
                await self.loadModeSessionHistories(accessToken: accessToken)
                self.modeMessage = self.pendingSyncCount > 0
                    ? "Apps guardadas. Sincronización pendiente."
                    : "Guardaste las apps de \(mode.title)."
            }
        } else {
            modeMessage = "Apps guardadas. Sincronización pendiente."
        }

        return true
    }

    func cancelModeActivityPickerSelection() {
        modeActivityPickerTarget = nil
    }

    func requestNfcTagSetup() {
        tagMessage = "Vinculá un tag NFC para poder iniciar un ritual o modo."
        nfcTagSetupRequestID = UUID()
    }

    func consumeNfcTagSetupRequest() {
        nfcTagSetupRequestID = nil
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
            if isAppReviewAccount {
                let demoTag = try await coreApi.prepareReviewDemoTag(
                    accessToken: accessToken
                )
                registeredTagIdentifier = demoTag.tagIdentifier
                defaults.set(demoTag.tagIdentifier, forKey: registeredTagKey)
            }

            let claims = try await coreApi.listNfcTagClaims(accessToken: accessToken)
            applyNfcClaims(claims)
        } catch {
            if isAppReviewAccount {
                tagMessage = "No pudimos preparar la tarjeta virtual de demostración."
            }
            print("Core nfc tags error:", error)
        }
    }

    func loadEmergencyUnlockStatus(accessToken: String) async {
        guard !accessToken.isEmpty else {
            emergencyUnlockStatus = nil
            return
        }

        do {
            emergencyUnlockStatus = try await coreApi.getEmergencyUnlockStatus(
                accessToken: accessToken
            )
        } catch {
            emergencyUnlockMessage = error.localizedDescription
        }
    }

    func useEmergencyUnlock(
        reason: EmergencyUnlockReason,
        accessToken: String
    ) async -> Bool {
        guard !accessToken.isEmpty else {
            emergencyUnlockMessage = "Iniciá sesión para usar el desbloqueo de emergencia."
            return false
        }

        guard hasActiveFocusSession else {
            emergencyUnlockMessage = "No hay una sesión activa para desbloquear."
            return false
        }

        isLoadingEmergencyUnlock = true
        emergencyUnlockMessage = nil
        defer { isLoadingEmergencyUnlock = false }

        do {
            let result = try await coreApi.useEmergencyUnlock(
                accessToken: accessToken,
                reason: reason
            )
            applyEmergencyUnlock(result)
            emergencyUnlockStatus = EmergencyUnlockStatusResponse(
                available: false,
                cooldownDays: 30,
                lastUsedAt: result.usedAt,
                nextAvailableAt: result.nextAvailableAt
            )
            emergencyUnlockMessage = result.tagMarkedLost
                ? "Sesión finalizada. El tag perdido quedó inhabilitado."
                : "Sesión finalizada con el desbloqueo de emergencia."

            await loadFocusMetricsSummary(accessToken: accessToken)
            await loadEmergencyUnlockStatus(accessToken: accessToken)
            return true
        } catch {
            emergencyUnlockMessage = error.localizedDescription
            await loadEmergencyUnlockStatus(accessToken: accessToken)
            return false
        }
    }

    var emergencyUnlockAvailabilityText: String {
        if isLoadingEmergencyUnlock {
            return "Procesando"
        }

        guard let status = emergencyUnlockStatus else {
            return "Consultando disponibilidad"
        }

        if status.available {
            return hasActiveFocusSession
                ? "Disponible ahora"
                : "Disponible al iniciar una sesión"
        }

        guard let rawDate = status.nextAvailableAt,
              let date = emergencyUnlockDate(from: rawDate) else {
            return "No disponible temporalmente"
        }

        return "Disponible nuevamente el \(date.formatted(date: .long, time: .omitted))"
    }

    var canUseEmergencyUnlock: Bool {
        hasActiveFocusSession
            && emergencyUnlockStatus?.available == true
            && !isLoadingEmergencyUnlock
    }

    private func emergencyUnlockDate(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    func startTimedBlock() async {
        guard !hasActiveBlockingContext else {
            presentFocusSessionConflict()
            return
        }

        let hasRemoteSession = await hasRemoteActiveFocusSession()
        guard !hasRemoteSession else { return }

        unblockTask?.cancel()
        countdownTimer?.invalidate()

        let plannedEnd = Calendar.current.date(
            byAdding: .minute,
            value: selectedDuration.minutes,
            to: .now
        )

        guard await confirmManualRitualSessionIfNeeded(plannedEndAt: plannedEnd) else {
            return
        }

        applyShield(
            using: selection,
            blockAppInstallation: selectedScheduler?.blockAppInstallation ?? false,
            blockAdultContent: selectedScheduler?.blockAdultContent ?? false
        )
        isBlocking = true
        activeBlockSource = .manual
        reconcileInteractiveStrictModeRestriction()
        blockedUntil = plannedEnd
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

    func startMode(
        _ mode: FocusMode,
        durationMinutes: Int? = nil
    ) async -> Bool {
        guard !isStartingMode else { return false }
        isStartingMode = true
        startingModeTitle = mode.title
        defer {
            isStartingMode = false
            startingModeTitle = nil
        }
        await Task.yield()

        if !isAuthorized {
            await requestAuthorization()
        }

        guard isAuthorized else {
            modeMessage = "Necesitas autorizar Screen Time para iniciar un modo."
            return false
        }

        guard !hasActiveRitualContext else {
            presentRitualPriorityConflict()
            return false
        }

        guard !hasActiveBlockingContext else {
            presentFocusSessionConflict()
            return false
        }

        let hasRemoteSession = await hasRemoteActiveFocusSession()
        guard !hasRemoteSession else { return false }

        var modeToStart = mode
        if modeToStart.coreModeId == nil,
           let accessToken = activeAccessToken,
           !accessToken.isEmpty {
            do {
                try queueModeConfiguration(
                    modeToStart,
                    password: pendingModePasswords[modeToStart.id]
                )
                await syncPendingConfigurationOperations(
                    accessToken: accessToken
                )
                if let syncedMode = modes.first(where: { $0.id == mode.id }) {
                    modeToStart = syncedMode
                }
            } catch {
                modeMessage = "No se pudo sincronizar \(mode.title): \(error.localizedDescription)"
                return false
            }
        }

        guard modeToStart.hasBlockingConfiguration else {
            modeMessage = "Primero configura al menos un bloqueo para \(modeToStart.title)."
            return false
        }

        guard hasClaimedNfcTag else {
            modeMessage = "Primero vincula un tag NFC desde Perfil."
            requestNfcTagSetup()
            return false
        }

        guard let accountID = activeAccountID else {
            modeMessage = "Necesitas iniciar sesion para usar tus modos."
            return false
        }

        guard await confirmManualModeSession(modeToStart) else {
            return false
        }

        let modeEndDate = durationMinutes.flatMap {
            Calendar.current.date(byAdding: .minute, value: $0, to: .now)
        }
        if let modeEndDate {
            do {
                try await modeEndActivityScheduler.scheduleModeEnd(
                    for: modeToStart,
                    accountID: accountID,
                    at: modeEndDate
                )
            } catch {
                queueCoreModeSessionFinish(
                    status: "cancelled",
                    endSource: "timer_setup_failed",
                    mode: modeToStart
                )
                modeMessage = "No se pudo programar el apagado automático: \(error.localizedDescription)"
                return false
            }
        } else {
            modeEndActivityScheduler.cancelCurrent()
        }

        unblockTask?.cancel()
        countdownTimer?.invalidate()
        selectedSchedulerID = nil
        selection = modeToStart.selection
        sharedSuppressionStore.setModeActive(true)
        saveActiveModeSnapshot(modeToStart, accountID: accountID)
        applyModeShield(
            using: modeToStart.selection,
            blockAppInstallation: modeToStart.blockAppInstallation,
            blockAdultContent: modeToStart.blockAdultContent
        )
        isBlocking = true
        activeBlockSource = .mode(modeToStart.id)
        activeModeAccountID = accountID
        reconcileInteractiveStrictModeRestriction()
        blockedUntil = modeEndDate
        updateRemainingTime()
        if let modeEndDate {
            startCountdownTimer()
            scheduleLocalModeEnd(for: modeToStart, at: modeEndDate)
        }
        modeStore.saveActiveMode(modeToStart.id, accountID: accountID)
        resetModeBreakUsage()
        clearModeBreakState()
        if let durationMinutes {
            blockMessage = "Modo \(modeToStart.title) activo por \(Self.formattedModeDuration(minutes: durationMinutes))."
        } else {
            blockMessage = "Modo \(modeToStart.title) activo. Las restricciones se liberan con tu tag NFC."
        }
        modeMessage = nil
        deviceActivityDebugStore.log("Modo manual \(modeToStart.title) iniciado con \(modeToStart.selectedItemCount) bloqueos.")
        return true
    }

    func registerTag() {
        isReadingTag = true
        tagMessage = "Esperando tu tag para vincularlo a esta cuenta."

        beginTagInteraction(
            alertMessage: "Acerca el iPhone al tag NFC para registrarlo en rituo.",
            demoTitle: "Vincular tarjeta virtual",
            demoMessage: "Mantené presionado para simular que acercás la tarjeta rituo."
        ) { [weak self] result in
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

    func claimTag(
        accessToken: String,
        preferredLabel: String? = nil,
        isReplacement: Bool = false
    ) {
        guard !accessToken.isEmpty else {
            tagMessage = "Necesitas iniciar sesion para vincular un tag."
            return
        }

        isReadingTag = true
        let cleanLabel = preferredLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = cleanLabel?.isEmpty == false ? cleanLabel : "Tag principal"
        tagMessage = isReplacement
            ? "Esperando la nueva tarjeta para reemplazar la actual."
            : "Esperando tu tag para vincularlo a core-api."

        beginTagInteraction(
            alertMessage: "Acerca el iPhone al tag NFC para vincularlo a tu cuenta.",
            demoTitle: "Vincular tarjeta virtual",
            demoMessage: "Mantené presionado para vincular la tarjeta de demostración."
        ) { [weak self] result in
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
                                label: label
                            )
                        )

                        self.registeredTagIdentifier = scanResult.identifier
                        self.defaults.set(scanResult.identifier, forKey: self.registeredTagKey)
                        let claims = try await self.coreApi.listNfcTagClaims(accessToken: accessToken)
                        self.applyNfcClaims(claims)
                        self.tagMessage = isReplacement
                            ? "Tag reemplazado: \(claim.label ?? label ?? "Tag principal")."
                            : "Tag vinculado: \(claim.label ?? label ?? "Tag principal")."
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

        guard !isRevokingNfcTag else { return }

        isRevokingNfcTag = true
        tagMessage = "Desvinculando tag..."
        defer { isRevokingNfcTag = false }

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
            requestNfcTagSetup()
            return
        }

        isReadingTag = true
        tagMessage = "Acerca el iPhone al tag registrado para iniciar el bloqueo."

        beginTagInteraction(
            alertMessage: "Acerca el iPhone al tag NFC para activar el ritual.",
            expectedIdentifier: registeredTagIdentifier,
            unexpectedTagMessage: "Esta no es la tarjeta vinculada a tu cuenta.",
            demoTitle: "Activar ritual",
            demoMessage: "Mantené presionado para simular que apoyás tu tarjeta rituo."
        ) { [weak self] result in
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
                    await self.startTimedBlock()
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

        beginTagInteraction(
            alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para terminar el ritual.",
            expectedIdentifier: registeredTagIdentifier,
            unexpectedTagMessage: "Esta no es la tarjeta vinculada a tu cuenta.",
            demoTitle: "Terminar ritual",
            demoMessage: "Mantené presionado para simular que apoyás tu tarjeta rituo."
        ) { [weak self] result in
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
                    self.endBlock(
                        endSource: "nfc",
                        tagIdentifier: scanResult.identifier
                    )
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

        beginTagInteraction(
            alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para terminar el ritual.",
            expectedIdentifier: registeredTagIdentifier,
            unexpectedTagMessage: "Esta no es la tarjeta vinculada a tu cuenta.",
            demoTitle: "Confirmar con tarjeta",
            demoMessage: "Mantené presionado para simular que apoyás tu tarjeta rituo."
        ) { [weak self] result in
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
                        self.endBlock(
                            endSource: "nfc",
                            tagIdentifier: scanResult.identifier
                        )
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

    func validateTagForSensitiveAction(
        accessToken: String?,
        actionDescription: String,
        alertMessage: String,
        onVerified: @escaping () -> Void
    ) {
        guard let accessToken, !accessToken.isEmpty else {
            tagMessage = "Necesitás iniciar sesión para \(actionDescription)."
            return
        }

        activeAccessToken = accessToken

        guard hasClaimedNfcTag else {
            tagMessage = "Primero vinculá un tag NFC desde Perfil para \(actionDescription)."
            requestNfcTagSetup()
            return
        }

        isReadingTag = true
        tagMessage = "Acercá tu tag vinculado para \(actionDescription)."

        beginTagInteraction(
            alertMessage: alertMessage,
            expectedIdentifier: registeredTagIdentifier,
            unexpectedTagMessage: "Esta no es la tarjeta vinculada a tu cuenta.",
            demoTitle: "Confirmar acción",
            demoMessage: "Mantené presionado para confirmar con la tarjeta de demostración."
        ) { [weak self] result in
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
                            self.tagMessage = "Ese tag no está vinculado a esta cuenta."
                            self.deviceActivityDebugStore.log("NFC sensitive action rechazado por core-api: \(actionDescription).")
                            return
                        }

                        self.tagMessage = "Tag verificado."
                        self.deviceActivityDebugStore.log("NFC sensitive action OK: \(actionDescription).")
                        onVerified()
                    } catch {
                        self.tagMessage = error.localizedDescription
                        self.deviceActivityDebugStore.log("Error verify NFC sensitive action: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    self.tagMessage = error.localizedDescription
                }
            }
        }
    }

    private func beginTagInteraction(
        alertMessage: String,
        expectedIdentifier: String? = nil,
        unexpectedTagMessage: String = "Este no es el tag esperado.",
        demoTitle: String,
        demoMessage: String,
        onResult: @escaping (Result<NFCTagScanResult, Error>) -> Void
    ) {
        if isAppReviewAccount {
            guard let registeredTagIdentifier, !registeredTagIdentifier.isEmpty else {
                isReadingTag = false
                tagMessage = "La tarjeta virtual todavía no está lista. Cerrá y volvé a abrir la app."
                return
            }

            reviewDemoTagCompletion = onResult
            reviewDemoTagPrompt = ReviewDemoTagPrompt(
                title: demoTitle,
                message: demoMessage
            )
            return
        }

        nfcReader.beginScanning(
            alertMessage: alertMessage,
            expectedIdentifier: expectedIdentifier,
            unexpectedTagMessage: unexpectedTagMessage,
            onResult: onResult
        )
    }

    func completeReviewDemoTagInteraction() {
        guard isAppReviewAccount,
              let registeredTagIdentifier,
              let completion = reviewDemoTagCompletion else {
            cancelReviewDemoTagInteraction()
            return
        }

        reviewDemoTagPrompt = nil
        reviewDemoTagCompletion = nil
        completion(.success(NFCTagScanResult(identifier: registeredTagIdentifier)))
    }

    func cancelReviewDemoTagInteraction() {
        reviewDemoTagPrompt = nil
        reviewDemoTagCompletion = nil
        isReadingTag = false
    }

    func clearRegisteredTag() {
        registeredTagIdentifier = nil
        defaults.removeObject(forKey: registeredTagKey)
        tagMessage = "Se desvinculo el tag de esta cuenta."
    }

    func clearBlock() {
        endBlock(endSource: "manual")
    }

    private func applyEmergencyUnlock(_ result: EmergencyUnlockResponse) {
        let source = activeBlockSource
        let scheduler = activeSchedulerForCurrentBlock()

        unblockTask?.cancel()
        countdownTimer?.invalidate()

        if shouldSuppressEmergencyScheduledBlock(source: source, scheduler: scheduler) {
            suppressCurrentScheduledBlockIfNeeded(
                scheduler: scheduler,
                endSource: "emergency"
            )
        } else {
            deviceActivityDebugStore.log(
                "Emergencia sin supresión de scheduler source=\(String(describing: source)) scheduler=\(scheduler?.title ?? "sin scheduler")."
            )
        }

        pendingCoreSessionFinish?.operationID.map {
            keychainStore.deleteSyncSecret(operationID: $0)
        }
        pendingCoreModeSessionFinish?.operationID.map {
            keychainStore.deleteSyncSecret(operationID: $0)
        }
        pendingCoreSessionFinish = nil
        pendingCoreModeSessionFinish = nil
        defaults.removeObject(forKey: pendingCoreSessionFinishKey)
        defaults.removeObject(forKey: pendingCoreModeSessionFinishKey)

        blocker.clearAllShields()
        blocker.clearAllStrictModeRestrictions()
        modeEndActivityScheduler.cancelCurrent()
        sharedSuppressionStore.setModeActive(false)
        activeModeSnapshotStore.clear()
        modeStore.clearActiveMode()
        activeModeAccountID = nil
        activeCoreSession = nil
        activeCoreModeSession = nil
        activeBlockSource = nil
        isBlocking = false
        blockedUntil = nil
        remainingBlockTimeText = nil

        if result.tagMarkedLost {
            applyNfcClaims([])
            tagMessage = "El tag perdido quedó inhabilitado. Vinculá uno nuevo antes de iniciar otra sesión."
        }

        notificationService.sendRitualStoppedNotification(
            for: scheduler,
            endSource: "emergency"
        )
        blockMessage = "La sesión terminó con el desbloqueo de emergencia."
        reconcileInteractiveStrictModeRestriction()
        refreshScheduledRitualState()
    }

    private func shouldSuppressEmergencyScheduledBlock(
        source: BlockSource?,
        scheduler: RitualScheduler?
    ) -> Bool {
        guard let scheduler else { return false }

        if case .scheduled = source {
            return true
        }

        if activeCoreSession?.startSource == "schedule",
           activeCoreSession?.ritualId == scheduler.coreRitualId {
            return true
        }

        return scheduler.isActive()
    }

    private func endBlock(endSource: String, tagIdentifier: String? = nil) {
        let source = activeBlockSource
        let scheduler = activeSchedulerForCurrentBlock()
        let mode = currentBlockingMode

        unblockTask?.cancel()
        countdownTimer?.invalidate()

        if shouldSuppressScheduledBlock(source: source, endSource: endSource, scheduler: scheduler) {
            suppressCurrentScheduledBlockIfNeeded(scheduler: scheduler, endSource: endSource)
        } else if scheduler == nil {
            deviceActivityDebugStore.log("Terminando bloqueo sin scheduler asociado.")
        }

        deviceActivityDebugStore.log("Terminando bloqueo endSource=\(endSource) scheduler=\(scheduler?.title ?? "sin scheduler").")

        if mode == nil, scheduler != nil || activeCoreSession != nil {
            queueCoreSessionFinish(
                status: "cancelled",
                endSource: endSource,
                tagIdentifier: tagIdentifier,
                scheduler: scheduler
            )
        }

        if let mode {
            modeEndActivityScheduler.cancelCurrent()
            queueCoreModeSessionFinish(
                status: "completed",
                endSource: endSource,
                tagIdentifier: tagIdentifier,
                mode: mode
            )
            sharedSuppressionStore.setModeActive(false)
            activeModeSnapshotStore.clear()
            clearActiveModeShield()
            modeStore.clearActiveMode()
            clearModeBreakState()
            resetModeBreakUsage()
            activeModeAccountID = nil
            modeMessage = "Modo \(mode.title) finalizado."
            deviceActivityDebugStore.log("Modo manual \(mode.title) finalizado con \(endSource).")
        } else {
            clearActiveShield()
            notificationService.sendRitualStoppedNotification(for: scheduler, endSource: endSource)
        }

        isBlocking = false
        activeBlockSource = nil
        reconcileInteractiveStrictModeRestriction()
        blockedUntil = nil
        remainingBlockTimeText = nil
        blockMessage = mode == nil
            ? "Se quitaron las restricciones activas."
            : "Modo finalizado. Se quitaron las restricciones activas."

        if mode != nil {
            refreshScheduledRitualState()
        }
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
        nfcUnlockEnabled: Bool = false,
        strictModeEnabled: Bool = false,
        blockAppInstallation: Bool = false,
        blockAdultContent: Bool = false,
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

        guard activeAccountID != nil else {
            schedulerMessage = "Inicia sesión nuevamente antes de guardar el ritual."
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
            nfcUnlockEnabled: nfcUnlockEnabled,
            strictModeEnabled: strictModeEnabled,
            blockAppInstallation: blockAppInstallation,
            blockAdultContent: blockAdultContent
        )

        if isProtected {
            pendingRitualPasswords[scheduler.id] = cleanPassword
        }

        do {
            try queueRitualConfiguration(
                scheduler,
                password: isProtected ? cleanPassword : nil
            )
        } catch {
            removeQueuedRitualConfiguration(scheduler)
            schedulerMessage = "No se pudo guardar el ritual pendiente: \(error.localizedDescription)"
            return false
        }
        schedulers.insert(scheduler, at: 0)
        persistSchedulers()
        rescheduleDeviceActivities()
        refreshScheduledRitualState()
        schedulerMessage = "Guardaste \(scheduler.title) con \(scheduler.selectionDigest)."
        return true
    }

    func updateSchedulerProtection(
        _ scheduler: RitualScheduler,
        strictModeEnabled: Bool? = nil,
        blockAppInstallation: Bool? = nil,
        blockAdultContent: Bool? = nil
    ) {
        guard let index = schedulers.firstIndex(where: { $0.id == scheduler.id }) else {
            schedulerMessage = "No encontré ese ritual."
            return
        }

        if strictModeEnabled == false,
           schedulers[index].strictModeEnabled,
           activeSchedulerForCurrentBlock()?.id == scheduler.id,
           hasActiveBlockingContext {
            schedulerMessage = "El modo estricto no se puede desactivar durante un ritual activo."
            return
        }

        let updatedScheduler = schedulers[index].withProtection(
            strictModeEnabled: strictModeEnabled ?? schedulers[index].strictModeEnabled,
            blockAppInstallation: blockAppInstallation ?? schedulers[index].blockAppInstallation,
            blockAdultContent: blockAdultContent ?? schedulers[index].blockAdultContent
        )
        schedulers[index] = updatedScheduler
        persistSchedulers()
        rescheduleDeviceActivities()

        if activeSchedulerForCurrentBlock()?.id == updatedScheduler.id,
           hasActiveBlockingContext {
            applyShield(
                using: updatedScheduler.selection,
                blockAppInstallation: updatedScheduler.blockAppInstallation,
                blockAdultContent: updatedScheduler.blockAdultContent
            )
            reconcileInteractiveStrictModeRestriction()
        }

        schedulerMessage = "Protección de \(updatedScheduler.title) actualizada."
    }

    func loadCoreRituals(accessToken: String) async {
        guard !accessToken.isEmpty,
              let accountID = activeAccountID else {
            return
        }

        isSyncingRituals = true
        coreSyncMessage = nil
        defer { isSyncingRituals = false }

        do {
            let rituals = try await coreApi.listRituals(accessToken: accessToken)
            guard activeAccountID == accountID else {
                return
            }
            mergeCoreRituals(rituals)
            applyRitualDeletionTombstones(userID: accountID)
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
        isSyncingRituals = true
        coreSyncMessage = nil
        defer { isSyncingRituals = false }

        do {
            try queueRitualConfiguration(
                scheduler,
                password: pendingRitualPasswords[scheduler.id]
            )
        } catch {
            coreSyncMessage = error.localizedDescription
            return
        }
        await syncPendingConfigurationOperations(accessToken: accessToken)
        coreSyncMessage = failedSyncCount > 0
            ? "El ritual quedó pendiente de sincronización."
            : "Ritual sincronizado con core-api."
    }

    private func syncPendingSchedulersToCore(accessToken: String) async {
        let pendingSchedulers = schedulers.filter { scheduler in
            scheduler.coreRitualId == nil &&
            scheduler.selectedItemCount > 0 &&
            !scheduler.isLegacyDemoScheduler &&
            (!scheduler.isProtected || pendingRitualPasswords[scheduler.id] != nil)
        }

        for scheduler in pendingSchedulers {
            do {
                try queueRitualConfiguration(
                    scheduler,
                    password: pendingRitualPasswords[scheduler.id]
                )
            } catch {
                coreSyncMessage = "No se pudo sincronizar \(scheduler.title): \(error.localizedDescription)"
                print("Core pending ritual sync error:", scheduler.title, error)
            }
        }
        await syncPendingConfigurationOperations(accessToken: accessToken)
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
            if let coreRitualID = scheduler.coreRitualId {
                try queueRitualDeletion(
                    scheduler,
                    coreRitualID: coreRitualID,
                    password: password
                )
                removeQueuedRitualConfiguration(scheduler)
            } else {
                removeQueuedRitualConfiguration(scheduler)
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

            persistSchedulers()
            rescheduleDeviceActivities()
            refreshScheduledRitualState()

            if scheduler.coreRitualId == nil {
                coreSyncMessage = "Ritual eliminado."
            } else if let accessToken, !accessToken.isEmpty {
                await syncPendingConfigurationOperations(
                    accessToken: accessToken
                )
                if !schedulers.contains(where: { $0.id == scheduler.id }) {
                    coreSyncMessage = pendingSyncCount > 0
                        ? "Ritual eliminado. Sincronización pendiente."
                        : "Ritual eliminado."
                }
            } else {
                coreSyncMessage = "Ritual eliminado. Sincronización pendiente."
            }
        } catch {
            coreSyncMessage = error.localizedDescription
            print("Core ritual delete error:", error)
        }
    }

    func loadCoreModes(accessToken: String) async {
        guard !accessToken.isEmpty else { return }

        do {
            let coreModes = try await coreApi.listModes(accessToken: accessToken)
            mergeCoreModes(coreModes)
            await syncPendingModesToCore(accessToken: accessToken)
            await loadModeSessionHistories(accessToken: accessToken)
            modeMessage = modes.isEmpty ? "Todavia no hay modos sincronizados." : "Modos sincronizados."
        } catch {
            modeMessage = error.localizedDescription
            print("Core modes list error:", error)
        }
    }

    func saveModeConfiguration(
        _ mode: FocusMode,
        title: String,
        isProtected: Bool,
        password: String?,
        accessToken: String?
    ) async -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !cleanTitle.isEmpty else {
            modeMessage = "Ponle un nombre al modo antes de guardarlo."
            return false
        }

        guard mode.hasBlockingConfiguration else {
            modeMessage = "Primero configura apps, categorías, sitios o contenido sensible para este modo."
            return false
        }

        if isProtected && cleanPassword.isEmpty && !mode.isProtected {
            modeMessage = "La contraseña debe tener entre 4 y 72 caracteres."
            return false
        }

        if isProtected && !cleanPassword.isEmpty && !(4 ... 72).contains(cleanPassword.count) {
            modeMessage = "La contraseña debe tener entre 4 y 72 caracteres."
            return false
        }

        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else {
            modeMessage = "No encontré ese modo."
            return false
        }

        modes[index].title = cleanTitle
        modes[index].isProtected = isProtected
        modes[index].nfcUnlockEnabled = isProtected

        if isProtected && !cleanPassword.isEmpty {
            pendingModePasswords[mode.id] = cleanPassword
        } else if !isProtected {
            pendingModePasswords.removeValue(forKey: mode.id)
        }

        if let accountID = activeAccountID {
            modeStore.save(modes, accountID: accountID)
        }

        if let accessToken, !accessToken.isEmpty, let coreModeId = modes[index].coreModeId {
            do {
                let response = try await coreApi.renameMode(
                    accessToken: accessToken,
                    modeId: coreModeId,
                    body: RenameModeRequest(title: cleanTitle)
                )
                let localSelection = modes[index].selection
                let localStrictModeEnabled = modes[index].strictModeEnabled
                let localBlockAppInstallation = modes[index].blockAppInstallation
                let localBlockAdultContent = modes[index].blockAdultContent
                modes[index] = FocusMode(
                    response: response,
                    preserving: localSelection
                )
                modes[index].strictModeEnabled = localStrictModeEnabled
                modes[index].blockAppInstallation = localBlockAppInstallation
                modes[index].blockAdultContent = localBlockAdultContent
                if let accountID = activeAccountID {
                    modeStore.save(modes, accountID: accountID)
                }
                modeMessage = "Modo \(modes[index].title) sincronizado."
                return true
            } catch {
                modeMessage = "Nombre guardado. Sincronización pendiente."
            }
        }

        do {
            try queueModeConfiguration(
                modes[index],
                password: pendingModePasswords[mode.id]
            )
        } catch {
            modeMessage = "No se pudo guardar el modo pendiente: \(error.localizedDescription)"
            return false
        }

        guard let accessToken, !accessToken.isEmpty else {
            modeMessage = "Modo guardado. Sincronización pendiente."
            return true
        }

        await syncPendingConfigurationOperations(accessToken: accessToken)
        modeMessage = failedSyncCount > 0 || pendingSyncCount > 0
            ? "Modo guardado. Sincronización pendiente."
            : "Modo \(modes[index].title) sincronizado."
        return true
    }

    func updateModeStrictMode(
        _ isEnabled: Bool,
        for mode: FocusMode
    ) {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else {
            return
        }

        modes[index].strictModeEnabled = isEnabled

        if let accountID = activeAccountID {
            modeStore.save(modes, accountID: accountID)
        }

        if case .mode(let activeModeID) = activeBlockSource,
           activeModeID == mode.id {
            if let accountID = activeAccountID {
                saveActiveModeSnapshot(modes[index], accountID: accountID)
            }
            reconcileInteractiveStrictModeRestriction()
        }
    }

    func updateModeActivationOptions(_ configuredMode: FocusMode) {
        guard let index = modes.firstIndex(where: {
            $0.id == configuredMode.id
        }) else {
            return
        }

        modes[index].strictModeEnabled = configuredMode.strictModeEnabled
        modes[index].blockAppInstallation = configuredMode.blockAppInstallation
        modes[index].blockAdultContent = configuredMode.blockAdultContent

        if let accountID = activeAccountID {
            modeStore.save(modes, accountID: accountID)
        }
    }

    func updateModeAppInstallationBlocking(
        _ isEnabled: Bool,
        for mode: FocusMode
    ) {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else {
            return
        }

        modes[index].blockAppInstallation = isEnabled

        if let accountID = activeAccountID {
            modeStore.save(modes, accountID: accountID)
        }

        if case .mode(let activeModeID) = activeBlockSource,
           activeModeID == mode.id {
            if let accountID = activeAccountID {
                saveActiveModeSnapshot(modes[index], accountID: accountID)
            }
            applyModeShield(
                using: modes[index].selection,
                blockAppInstallation: isEnabled,
                blockAdultContent: modes[index].blockAdultContent
            )
        }
    }

    func updateModeAdultContentBlocking(
        _ isEnabled: Bool,
        for mode: FocusMode
    ) {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else {
            return
        }

        modes[index].blockAdultContent = isEnabled

        if let accountID = activeAccountID {
            modeStore.save(modes, accountID: accountID)
        }

        if case .mode(let activeModeID) = activeBlockSource,
           activeModeID == mode.id {
            if let accountID = activeAccountID {
                saveActiveModeSnapshot(modes[index], accountID: accountID)
            }
            applyModeShield(
                using: modes[index].selection,
                blockAppInstallation: modes[index].blockAppInstallation,
                blockAdultContent: isEnabled
            )
        }
    }

    func renameMode(
        _ mode: FocusMode,
        title: String,
        accessToken: String?
    ) async -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            modeMessage = "Ponle un nombre al modo antes de guardarlo."
            return false
        }

        guard cleanTitle.count <= 40 else {
            modeMessage = "El nombre del modo puede tener hasta 40 caracteres."
            return false
        }

        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else {
            modeMessage = "No encontré ese modo."
            return false
        }

        modes[index].title = cleanTitle

        if let accountID = activeAccountID {
            modeStore.save(modes, accountID: accountID)
        }

        do {
            try queueModeConfiguration(
                modes[index],
                password: pendingModePasswords[mode.id]
            )
        } catch {
            modeMessage = "No se pudo guardar el cambio pendiente: \(error.localizedDescription)"
            return false
        }

        guard let accessToken, !accessToken.isEmpty else {
            modeMessage = "Nombre guardado. Sincronización pendiente."
            return true
        }

        await syncPendingConfigurationOperations(accessToken: accessToken)
        modeMessage = failedSyncCount > 0 || pendingSyncCount > 0
            ? "Nombre guardado. Sincronización pendiente."
            : "Modo \(modes[index].title) sincronizado."
        return true
    }

    private func syncPendingModesToCore(accessToken: String) async {
        let pendingModes = modes.filter { mode in
            mode.coreModeId != nil &&
            mode.hasBlockingConfiguration
        }

        for mode in pendingModes {
            do {
                try queueModeConfiguration(
                    mode,
                    password: pendingModePasswords[mode.id]
                )
            } catch {
                modeMessage = "No se pudo sincronizar \(mode.title): \(error.localizedDescription)"
                print("Core pending mode sync error:", mode.title, error)
            }
        }
        await syncPendingConfigurationOperations(accessToken: accessToken)
    }

    private func mergeCoreModes(_ coreModes: [ModeResponse]) {
        var nextModes: [FocusMode] = []

        for response in coreModes {
            let localMode = modes.first { local in
                local.coreModeId == response.id || local.id == response.templateKey
            }
            let localSelection = localMode?.selection ?? FamilyActivitySelection()

            if let localMode,
               localMode.coreModeId == nil,
               localMode.hasBlockingConfiguration {
                nextModes.append(
                    FocusMode(
                        id: response.templateKey,
                        coreModeId: response.id,
                        title: localMode.title,
                        symbolName: response.icon,
                        selection: localSelection,
                        isProtected: localMode.isProtected,
                        nfcUnlockEnabled: localMode.nfcUnlockEnabled,
                        strictModeEnabled: localMode.strictModeEnabled,
                        blockAppInstallation: localMode.blockAppInstallation,
                        blockAdultContent: localMode.blockAdultContent
                    )
                )
            } else {
                var mergedMode = FocusMode(response: response, preserving: localSelection)
                mergedMode.strictModeEnabled = localMode?.strictModeEnabled ?? false
                mergedMode.blockAppInstallation = localMode?.blockAppInstallation ?? false
                mergedMode.blockAdultContent = localMode?.blockAdultContent ?? false
                nextModes.append(mergedMode)
            }
        }

        for defaultMode in FocusMode.defaults where !nextModes.contains(where: { $0.id == defaultMode.id }) {
            if let localMode = modes.first(where: { $0.id == defaultMode.id }) {
                nextModes.append(localMode)
            } else {
                nextModes.append(defaultMode)
            }
        }

        let order = Dictionary(uniqueKeysWithValues: FocusMode.defaults.enumerated().map { ($0.element.id, $0.offset) })
        modes = nextModes.sorted { lhs, rhs in
            (order[lhs.id] ?? Int.max) < (order[rhs.id] ?? Int.max)
        }

        if let accountID = activeAccountID {
            modeStore.save(modes, accountID: accountID)
        }
    }


    private var selectionIsEmpty: Bool {
        selection.applicationTokens.isEmpty &&
        selection.categoryTokens.isEmpty &&
        selection.webDomainTokens.isEmpty
    }

    private func mergeCoreRituals(_ rituals: [RitualResponse]) {
        let remoteRitualIDs = Set(rituals.map(\.id))
        let pendingLocalSchedulerIDs: Set<UUID>
        if let userID = activeAccountID {
            pendingLocalSchedulerIDs = Set(
                syncOutbox.operations(
                    userID: userID,
                    type: .createRitualConfiguration
                ).compactMap {
                    try? JSONDecoder().decode(
                        PendingRitualConfiguration.self,
                        from: $0.payload
                    ).localSchedulerID
                }
            )
        } else {
            pendingLocalSchedulerIDs = []
        }

        schedulers.removeAll { scheduler in
            guard let coreRitualID = scheduler.coreRitualId else {
                return false
            }
            return !remoteRitualIDs.contains(coreRitualID)
                && !pendingLocalSchedulerIDs.contains(scheduler.id)
        }

        if let selectedSchedulerID,
           !schedulers.contains(where: { $0.id == selectedSchedulerID }) {
            self.selectedSchedulerID = nil
            selection = FamilyActivitySelection()
        }

        for ritual in rituals {
            if let index = schedulers.firstIndex(where: { $0.coreRitualId == ritual.id }) {
                let localScheduler = schedulers[index]
                let localSelection = localScheduler.selection
                let localId = localScheduler.id
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
                    nfcUnlockEnabled: ritual.nfcUnlockEnabled,
                    strictModeEnabled: localScheduler.strictModeEnabled,
                    blockAppInstallation: localScheduler.blockAppInstallation,
                    blockAdultContent: localScheduler.blockAdultContent
                )
            } else if let index = schedulers.firstIndex(where: { scheduler in
                scheduler.coreRitualId == nil &&
                schedulerMatchesCoreRitual(scheduler, ritual)
            }) {
                let localScheduler = schedulers[index]
                let localSelection = localScheduler.selection
                let localId = localScheduler.id
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
                    nfcUnlockEnabled: syncedScheduler.nfcUnlockEnabled,
                    strictModeEnabled: localScheduler.strictModeEnabled,
                    blockAppInstallation: localScheduler.blockAppInstallation,
                    blockAdultContent: localScheduler.blockAdultContent
                )
            } else {
                schedulers.append(RitualScheduler(response: ritual))
            }
        }

        schedulers = deduplicatedSchedulers(schedulers)
        persistSchedulers()
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
            let monitorableSchedulers = schedulers.filter { !isSchedulerSuppressed($0) }
            try deviceActivityScheduler.reschedule(
                monitorableSchedulers,
                userID: activeAccountID
            )
            notificationService.rescheduleNotifications(for: monitorableSchedulers)
        } catch {
            schedulerMessage = "No se pudieron programar los rituales automaticos: \(error.localizedDescription)"
            deviceActivityDebugStore.log("Error startMonitoring: \(error.localizedDescription)")
            print("Device activity scheduling error:", error)
        }
        refreshDeviceActivityDebugEvents()
    }

    private func preemptActiveModeForScheduledRitual(
        _ scheduler: RitualScheduler?,
        detectedByExtension: Bool = false
    ) {
        let storedMode: FocusMode?
        if let record = modeStore.loadActiveMode(),
           record.accountID == activeAccountID {
            storedMode = modes.first { $0.id == record.modeID }
        } else {
            storedMode = nil
        }
        let mode = currentBlockingMode ?? storedMode
        let hasLocalModeSource: Bool = {
            if case .mode = activeBlockSource {
                return true
            }
            return false
        }()
        let hasModeContext =
            activeCoreModeSession != nil ||
            mode != nil ||
            hasLocalModeSource ||
            sharedSuppressionStore.isModeActive()

        guard hasModeContext else { return }

        activeCoreModeSession = nil
        sharedSuppressionStore.setModeActive(false)
        clearActiveModeShield()
        clearModeBreakState(cancelNotificationsFor: mode)
        resetModeBreakUsage()

        if hasLocalModeSource {
            activeBlockSource = nil
            isBlocking = false
            blockedUntil = nil
            remainingBlockTimeText = nil
        }

        reconcileInteractiveStrictModeRestriction()
        reconcileSafariContentBlocking()

        let ritualTitle = scheduler?.title ?? "el ritual programado"
        modeMessage = "El modo quedó en pausa porque comenzó \(ritualTitle)."
        schedulerMessage = "\(ritualTitle) tomó prioridad sobre el modo activo."
        deviceActivityDebugStore.log(
            "Modo pausado por \(ritualTitle) origen=\(detectedByExtension ? "extension" : "app")."
        )
    }

    func refreshScheduledRitualState() {
        refreshDeviceActivityDebugEvents()
        removeExpiredScheduledSuppressions()
        guard isAuthorized else { return }

        let currentScheduler = schedulers.first { scheduler in
            scheduler.selectedItemCount > 0 && scheduler.isActive() && !isSchedulerSuppressed(scheduler)
        }
        let hasActiveMode = activeCoreModeSession != nil || {
            if isBlocking, case .mode = activeBlockSource { return true }
            return false
        }()

        if hasActiveMode, let currentScheduler {
            preemptActiveModeForScheduledRitual(currentScheduler)
        } else if hasActiveMode {
            return
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
            applyShield(
                using: scheduler.selection,
                blockAppInstallation: scheduler.blockAppInstallation,
                blockAdultContent: scheduler.blockAdultContent
            )
            deviceActivityDebugStore.log("Fallback app activo \(scheduler.title) items=\(scheduler.selectedItemCount).")
            isBlocking = true
            activeBlockSource = .scheduled(scheduler.id)
            reconcileInteractiveStrictModeRestriction()
            blockedUntil = scheduler.endDate()
            startCoreRitualSessionIfPossible(startSource: "schedule", plannedEndAt: blockedUntil)
            updateRemainingTime()
            startCountdownTimer()
            if scheduler.durationMinutes < 15 {
                notificationService.sendRitualStartedNotification(for: scheduler)
            }
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
        queueCoreSessionFinish(status: "completed", endSource: "timer", scheduler: scheduler)
        clearActiveShield()
        if case .scheduled = source {
            // The scheduled notification already announces the end of the ritual.
        } else {
            notificationService.sendRitualStoppedNotification(for: scheduler, endSource: "timer")
        }
        isBlocking = false
        activeBlockSource = nil
        reconcileInteractiveStrictModeRestriction()
        blockedUntil = nil
        remainingBlockTimeText = nil
        countdownTimer?.invalidate()
        blockMessage = "El temporizador termino y rituo. libero el acceso a las apps."

        if case .scheduled = source,
           let accountID = activeAccountID {
            restoreActiveModeIfNeeded(accountID: accountID)
        }
    }

    private func scheduleLocalModeEnd(for mode: FocusMode, at endDate: Date) {
        unblockTask?.cancel()
        unblockTask = Task { [weak self] in
            let delay = max(0, endDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.finishTimedMode(mode)
            }
        }
    }

    private func restoreModeEndTimerIfNeeded(for mode: FocusMode) {
        guard let endDate = modeEndActivityScheduler.scheduledEndDate else {
            blockedUntil = nil
            remainingBlockTimeText = nil
            return
        }

        blockedUntil = endDate
        updateRemainingTime()
        startCountdownTimer()
        scheduleLocalModeEnd(for: mode, at: endDate)
    }

    private func finishTimedMode(_ mode: FocusMode) {
        let isVisibleMode: Bool = {
            guard case .mode(let modeID) = activeBlockSource else {
                return false
            }
            return modeID == mode.id
        }()

        if isVisibleMode {
            endBlock(endSource: "timer")
            return
        }

        modeEndActivityScheduler.cancelCurrent()
        queueCoreModeSessionFinish(
            status: "completed",
            endSource: "timer",
            mode: mode
        )
        sharedSuppressionStore.setModeActive(false)
        activeModeSnapshotStore.clear()
        modeStore.clearActiveMode()
        activeModeAccountID = nil
        modeMessage = "Modo \(mode.title) finalizado al alcanzar su límite."
        deviceActivityDebugStore.log(
            "Modo pausado \(mode.title) finalizado por temporizador."
        )
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
        case .mode:
            return nil
        case nil:
            if let ritualId = activeCoreSession?.ritualId,
               let scheduler = schedulers.first(where: { $0.coreRitualId == ritualId }) {
                return scheduler
            }
            return selectedScheduler ?? activeScheduler
        }
    }

    private func restoreActiveModeIfNeeded(accountID: String) {
        guard let record = modeStore.loadActiveMode(),
              record.accountID == accountID,
              let mode = modes.first(where: { $0.id == record.modeID }),
              mode.hasBlockingConfiguration else {
            return
        }

        if let scheduledEndDate = modeEndActivityScheduler.scheduledEndDate,
           scheduledEndDate <= .now {
            finishTimedMode(mode)
            return
        }

        unblockTask?.cancel()
        countdownTimer?.invalidate()
        selectedSchedulerID = nil
        selection = mode.selection
        sharedSuppressionStore.setModeActive(true)
        saveActiveModeSnapshot(mode, accountID: accountID)
        restoreModeBreakUsage(for: mode)
        if isModeBreakActive, let modeBreakUntil {
            blocker.clearModeShield()
            scheduleModeBreakEnd(for: mode, until: modeBreakUntil)
        } else {
            clearModeBreakState()
            applyModeShield(
                using: mode.selection,
                blockAppInstallation: mode.blockAppInstallation,
                blockAdultContent: mode.blockAdultContent
            )
        }
        isBlocking = true
        activeBlockSource = .mode(mode.id)
        activeModeAccountID = accountID
        reconcileInteractiveStrictModeRestriction()
        restoreModeEndTimerIfNeeded(for: mode)
        blockMessage = modeEndActivityScheduler.scheduledEndDate == nil
            ? "Modo \(mode.title) activo. Las restricciones se liberan con tu tag NFC."
            : "Modo \(mode.title) activo con apagado automático."
        deviceActivityDebugStore.log("Modo manual \(mode.title) restaurado.")
    }

    private func restoreCoreModeSession(_ session: ModeSessionResponse) {
        guard let accountID = activeAccountID,
              let mode = modes.first(where: { $0.coreModeId == session.modeId }),
              mode.hasBlockingConfiguration else {
            blockMessage = "Hay un modo activo, pero sus apps no están disponibles en este dispositivo."
            return
        }

        if let scheduledEndDate = modeEndActivityScheduler.scheduledEndDate,
           scheduledEndDate <= .now {
            finishTimedMode(mode)
            return
        }

        unblockTask?.cancel()
        countdownTimer?.invalidate()
        blocker.clearShield()
        selectedSchedulerID = nil
        selection = mode.selection
        sharedSuppressionStore.setModeActive(true)
        saveActiveModeSnapshot(mode, accountID: accountID)
        restoreModeBreakUsage(for: mode)
        if isModeBreakActive, let modeBreakUntil {
            blocker.clearModeShield()
            scheduleModeBreakEnd(for: mode, until: modeBreakUntil)
        } else {
            clearModeBreakState()
            applyModeShield(
                using: mode.selection,
                blockAppInstallation: mode.blockAppInstallation,
                blockAdultContent: mode.blockAdultContent
            )
        }
        isBlocking = true
        activeBlockSource = .mode(mode.id)
        activeModeAccountID = accountID
        reconcileInteractiveStrictModeRestriction()
        restoreModeEndTimerIfNeeded(for: mode)
        modeStore.saveActiveMode(mode.id, accountID: accountID)
        blockMessage = modeEndActivityScheduler.scheduledEndDate == nil
            ? "Modo \(mode.title) restaurado. Las restricciones se liberan con tu tag NFC."
            : "Modo \(mode.title) restaurado con apagado automático."
        deviceActivityDebugStore.log("Modo \(mode.title) restaurado desde sesión core \(session.id).")
    }

    private func restoreCoreRitualSession(_ session: RitualSessionResponse) {
        guard let scheduler = schedulers.first(where: { $0.coreRitualId == session.ritualId }),
              scheduler.selectedItemCount > 0 else {
            blockMessage = "Hay un ritual activo, pero sus apps no están disponibles en este dispositivo."
            return
        }

        unblockTask?.cancel()
        countdownTimer?.invalidate()
        blocker.clearModeShield()
        sharedSuppressionStore.setModeActive(false)
        if activeModeSnapshotStore.load() == nil {
            modeStore.clearActiveMode()
            activeModeAccountID = nil
        }
        selectedSchedulerID = scheduler.id
        selection = scheduler.selection
        applyShield(
            using: scheduler.selection,
            blockAppInstallation: scheduler.blockAppInstallation,
            blockAdultContent: scheduler.blockAdultContent
        )
        isBlocking = true
        activeBlockSource = session.startSource == "schedule"
            ? .scheduled(scheduler.id)
            : .manual
        reconcileInteractiveStrictModeRestriction()
        blockedUntil = Self.parseISODate(session.plannedEndAt)
        updateRemainingTime()

        if let blockedUntil, blockedUntil > .now {
            startCountdownTimer()
        }

        blockMessage = "Ritual \(scheduler.title) restaurado desde tu sesión activa."
        deviceActivityDebugStore.log("Ritual \(scheduler.title) restaurado desde sesión core \(session.id).")
    }

    private func clearStaleServerBackedLocalState() {
        if case .mode = activeBlockSource {
            modeEndActivityScheduler.cancelCurrent()
            clearActiveModeShield()
            sharedSuppressionStore.setModeActive(false)
            activeModeSnapshotStore.clear()
            modeStore.clearActiveMode()
            activeModeAccountID = nil
            resetReconciledBlockingState(message: "El modo ya no está activo.")
            return
        }

        if case .manual = activeBlockSource,
           selectedScheduler?.coreRitualId != nil {
            clearActiveShield()
            resetReconciledBlockingState(message: "El ritual ya no está activo.")
            return
        }

        modeStore.clearActiveMode()
        sharedSuppressionStore.setModeActive(false)
        activeModeSnapshotStore.clear()
        blocker.clearModeShield()
        reconcileInteractiveStrictModeRestriction()
    }

    private func resetReconciledBlockingState(message: String) {
        unblockTask?.cancel()
        countdownTimer?.invalidate()
        isBlocking = false
        activeBlockSource = nil
        reconcileInteractiveStrictModeRestriction()
        blockedUntil = nil
        remainingBlockTimeText = nil
        blockMessage = message
    }

    private func suppressCurrentScheduledBlockIfNeeded(
        scheduler: RitualScheduler?,
        endSource: String
    ) {
        guard let scheduler else { return }
        let suppressionEnd = scheduler.endDate() ?? blockedUntil ?? Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now
        suppressedScheduledBlocks[scheduler.id] = suppressionEnd
        saveScheduledSuppressions()
        deviceActivityScheduler.stopMonitoringCurrentInterval(for: scheduler)
        rescheduleDeviceActivities()
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
        reconcileInteractiveStrictModeRestriction()
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
        sharedSuppressionStore.replaceSuppressions(suppressedScheduledBlocks)
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
        guard !isStartingCoreSession,
              activeCoreSession == nil,
              let accessToken = activeAccessToken,
              !accessToken.isEmpty,
              let ritualId = selectedScheduler?.coreRitualId else {
            return
        }

        isStartingCoreSession = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isStartingCoreSession = false }

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

                if self.pendingCoreSessionFinish?.ritualId == session.ritualId {
                    await self.syncPendingCoreSessionFinish(accessToken: accessToken)
                }

                await self.loadRitualSessionSummary(accessToken: accessToken)
                await self.loadRitualSessionHistories(accessToken: accessToken)
                await self.loadFocusMetricsSummary(accessToken: accessToken)
                print("Core ritual session started:", session.id)
            } catch {
                self.coreSyncMessage = error.localizedDescription
                if self.isFocusSessionConflict(error) {
                    self.presentFocusSessionConflict()
                }
                await self.loadActiveRitualSession(accessToken: accessToken)
                print("Core ritual session start error:", error)
            }
        }
    }

    private func confirmManualRitualSessionIfNeeded(plannedEndAt: Date?) async -> Bool {
        guard let ritualId = selectedScheduler?.coreRitualId else {
            return true
        }

        guard !isStartingCoreSession,
              activeCoreSession == nil,
              let accessToken = activeAccessToken,
              !accessToken.isEmpty else {
            coreSyncMessage = "No se pudo confirmar el inicio del ritual."
            return false
        }

        isStartingCoreSession = true
        defer { isStartingCoreSession = false }

        do {
            let session = try await coreApi.startRitualSession(
                accessToken: accessToken,
                body: StartRitualSessionRequest(
                    ritualId: ritualId,
                    plannedEndAt: plannedEndAt.map(Self.isoDateString),
                    startSource: "manual"
                )
            )

            activeCoreSession = session
            coreSyncMessage = "Sesión de ritual iniciada."
            refreshMetricsAfterConfirmedRitualStart(accessToken: accessToken)
            return true
        } catch {
            coreSyncMessage = error.localizedDescription
            handleManualStartError(error)
            await loadActiveRitualSession(accessToken: accessToken)
            return false
        }
    }

    private func confirmManualModeSession(_ mode: FocusMode) async -> Bool {
        guard !isStartingCoreModeSession,
              activeCoreModeSession == nil,
              let accessToken = activeAccessToken,
              !accessToken.isEmpty,
              let modeId = mode.coreModeId else {
            modeMessage = "No se pudo confirmar el inicio del modo."
            return false
        }

        isStartingCoreModeSession = true
        defer { isStartingCoreModeSession = false }

        do {
            let session = try await coreApi.startModeSession(
                accessToken: accessToken,
                body: StartModeSessionRequest(
                    modeId: modeId,
                    startSource: "manual"
                )
            )

            activeCoreModeSession = session
            coreSyncMessage = "Sesión de modo iniciada."
            refreshMetricsAfterConfirmedModeStart(accessToken: accessToken)
            return true
        } catch {
            coreSyncMessage = error.localizedDescription
            modeMessage = error.localizedDescription
            handleManualStartError(error)
            await loadActiveModeSession(accessToken: accessToken)
            return false
        }
    }

    private func handleManualStartError(_ error: Error) {
        if isFocusSessionConflict(error) {
            presentFocusSessionConflict()
            return
        }

        guard case let CoreAPIError.serverError(_, _, code) = error else { return }
        if code == "NFC_TAG_REQUIRED" {
            requestNfcTagSetup()
        }
    }

    private func refreshMetricsAfterConfirmedRitualStart(accessToken: String) {
        Task { [weak self] in
            guard let self else { return }
            await self.loadRitualSessionSummary(accessToken: accessToken)
            await self.loadRitualSessionHistories(accessToken: accessToken)
            await self.loadFocusMetricsSummary(accessToken: accessToken)
        }
    }

    private func refreshMetricsAfterConfirmedModeStart(accessToken: String) {
        Task { [weak self] in
            guard let self else { return }
            await self.loadModeSessionSummary(accessToken: accessToken)
            await self.loadModeSessionHistories(accessToken: accessToken)
            await self.loadFocusMetricsSummary(accessToken: accessToken)
        }
    }

    private func hasRemoteActiveFocusSession() async -> Bool {
        guard let accessToken = activeAccessToken, !accessToken.isEmpty else {
            return false
        }

        do {
            let active = try await coreApi.getActiveFocusSession(accessToken: accessToken)
            activeCoreSession = active?.ritualSession
            activeCoreModeSession = active?.modeSession
            didResolveActiveRitualSession = true
            didResolveActiveModeSession = true

            guard let active else { return false }
            if active.ritualSession != nil {
                presentRitualPriorityConflict()
            } else {
                presentFocusSessionConflict()
            }
            return true
        } catch {
            coreSyncMessage = error.localizedDescription
            return false
        }
    }

    private func presentFocusSessionConflict() {
        focusSessionConflictTitle = "Ya hay una sesión activa"
        focusSessionConflictMessage = "No podés iniciar dos sesiones de foco al mismo tiempo. Finalizá la sesión actual antes de comenzar otra."
        modeMessage = "Ya tenés una sesión de foco activa."
        isFocusSessionConflictPresented = true
    }

    private func presentRitualPriorityConflict() {
        focusSessionConflictTitle = "Hay un ritual activo"
        focusSessionConflictMessage = "Los rituales tienen prioridad. Para iniciar un modo, primero pausá el ritual con tu tag NFC."
        modeMessage = "Pausá el ritual con tu tag NFC antes de iniciar un modo."
        isFocusSessionConflictPresented = true
    }

    private func isFocusSessionConflict(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, _, code) = error else {
            return false
        }

        return code == "ACTIVE_FOCUS_SESSION_EXISTS" || (code == nil && statusCode == 409)
    }

    private func reconcileInteractiveStrictModeRestriction() {
        let activeRitualRequiresStrictMode =
            activeSchedulerForCurrentBlock()?.strictModeEnabled == true
        let activeModeRequiresStrictMode =
            currentBlockingMode?.strictModeEnabled == true
        let shouldPreventAppRemoval =
            isStrictModeEnabled ||
            (
                hasActiveBlockingContext &&
                (
                    activeRitualRequiresStrictMode ||
                    activeModeRequiresStrictMode
                )
            )
        blocker.setInteractiveStrictModeActive(
            shouldPreventAppRemoval
        )
        deviceActivityDebugStore.log(
            "Modo estricto reconciliado global=\(isStrictModeEnabled) ritual=\(activeRitualRequiresStrictMode) modo=\(activeModeRequiresStrictMode) sesión=\(hasActiveBlockingContext) aplicado=\(shouldPreventAppRemoval)."
        )
        reconcileSafariContentBlocking()
    }

    private func reconcileSafariContentBlocking() {
        let modeRequiresBlocking =
            currentBlockingMode?.blockAdultContent == true &&
            !isModeBreakActive
        let ritualRequiresBlocking =
            hasActiveBlockingContext &&
            currentBlockingScheduler?.blockAdultContent == true
        let shouldBlockSensitiveWebContent =
            isSensitiveWebContentBlockingEnabled ||
            modeRequiresBlocking ||
            ritualRequiresBlocking

        blocker.refreshSafariContentBlocking(
            isEnabled: shouldBlockSensitiveWebContent
        )
        deviceActivityDebugStore.log(
            "Contenido sensible reconciliado global=\(isSensitiveWebContentBlockingEnabled) modo=\(modeRequiresBlocking) ritual=\(ritualRequiresBlocking) aplicado=\(shouldBlockSensitiveWebContent)."
        )
    }

    private func clearActiveShield() {
        deviceActivityDebugStore.log("Liberando ManagedSettings.")
        delayedShieldClearTasks.forEach { $0.cancel() }
        blocker.clearShield()

        delayedShieldClearTasks = [350, 1_000, 2_000].map { delay in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled else { return }
                self?.blocker.clearShield()
            }
        }
    }

    private func clearActiveModeShield() {
        deviceActivityDebugStore.log("Liberando ManagedSettings del modo manual.")
        delayedModeShieldClearTasks.forEach { $0.cancel() }
        blocker.clearModeShield()

        delayedModeShieldClearTasks = [350, 1_000, 2_000].map { delay in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled else { return }
                self?.blocker.clearModeShield()
            }
        }
    }

    private func applyShield(
        using selection: FamilyActivitySelection,
        blockAppInstallation: Bool = false,
        blockAdultContent: Bool = false
    ) {
        delayedShieldClearTasks.forEach { $0.cancel() }
        delayedShieldClearTasks.removeAll()
        blocker.applyShield(
            using: selection,
            blockAppInstallation: blockAppInstallation,
            blockAdultContent: blockAdultContent
        )
        reconcileSafariContentBlocking()
    }

    private func applyModeShield(
        using selection: FamilyActivitySelection,
        blockAppInstallation: Bool,
        blockAdultContent: Bool
    ) {
        delayedModeShieldClearTasks.forEach { $0.cancel() }
        delayedModeShieldClearTasks.removeAll()
        blocker.applyModeShield(
            using: selection,
            blockAppInstallation: blockAppInstallation,
            blockAdultContent: blockAdultContent
        )
        reconcileSafariContentBlocking()
    }

    private func saveActiveModeSnapshot(
        _ mode: FocusMode,
        accountID: String
    ) {
        do {
            try activeModeSnapshotStore.save(
                SharedActiveModeSnapshot(
                    userID: accountID,
                    modeID: mode.id,
                    coreModeID: mode.coreModeId,
                    title: mode.title,
                    selection: mode.selection,
                    strictModeEnabled: mode.strictModeEnabled,
                    blockAppInstallation: mode.blockAppInstallation,
                    blockAdultContent: mode.blockAdultContent
                )
            )
        } catch {
            deviceActivityDebugStore.log(
                "No se pudo guardar snapshot del modo \(mode.title): \(error.localizedDescription)."
            )
        }
    }

    private func scheduleModeBreakEnd(for mode: FocusMode, until breakUntil: Date) {
        modeBreakTask?.cancel()
        updateModeBreakRemainingText(until: breakUntil)

        modeBreakTask = Task { [weak self] in
            while !Task.isCancelled {
                let remaining = breakUntil.timeIntervalSinceNow
                if remaining <= 0 { break }

                await MainActor.run {
                    self?.updateModeBreakRemainingText(until: breakUntil)
                }

                try? await Task.sleep(for: .seconds(1))
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.finishModeBreak(for: mode)
            }
        }
    }

    private func finishModeBreak(for mode: FocusMode) {
        guard currentBlockingMode?.id == mode.id else {
            clearModeBreakState(cancelNotificationsFor: mode)
            return
        }

        clearModeBreakState(cancelNotificationsFor: nil, cancelActivity: false)
        applyModeShield(
            using: mode.selection,
            blockAppInstallation: mode.blockAppInstallation,
            blockAdultContent: mode.blockAdultContent
        )
        blockMessage = "Recreo terminado. Modo \(mode.title) activo otra vez."
        modeMessage = nil
        deviceActivityDebugStore.log("Recreo de modo terminado para \(mode.title).")
    }

    private func clearModeBreakState() {
        clearModeBreakState(cancelNotificationsFor: currentBlockingMode)
    }

    private func clearModeBreakState(
        cancelNotificationsFor mode: FocusMode?,
        cancelActivity: Bool = true
    ) {
        modeBreakTask?.cancel()
        modeBreakTask = nil
        if cancelActivity {
            modeBreakActivityScheduler.cancelCurrent()
        }
        if let mode {
            notificationService.cancelModeBreakNotifications(for: mode)
        }
        modeBreakUntil = nil
        modeBreakRemainingText = nil
        defaults.removeObject(forKey: modeBreakUntilKey)
    }

    private func markModeBreakUsed(for mode: FocusMode) {
        hasUsedModeBreakInCurrentSession = true
        defaults.set(mode.id, forKey: modeBreakUsedModeIDKey)
    }

    private func resetModeBreakUsage() {
        hasUsedModeBreakInCurrentSession = false
        defaults.removeObject(forKey: modeBreakUsedModeIDKey)
    }

    private func restoreModeBreakUsage(for mode: FocusMode) {
        let usedModeID = defaults.string(forKey: modeBreakUsedModeIDKey)
        if usedModeID == mode.id || isModeBreakActive {
            markModeBreakUsed(for: mode)
        } else {
            hasUsedModeBreakInCurrentSession = false
        }
    }

    private func updateModeBreakRemainingText(until breakUntil: Date) {
        modeBreakRemainingText = Self.formattedModeBreakRemaining(until: breakUntil)
    }

    private static func formattedModeBreakRemaining(until breakUntil: Date) -> String {
        let remaining = max(0, Int(ceil(breakUntil.timeIntervalSinceNow)))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func queueCoreSessionFinish(
        status: String,
        endSource: String,
        tagIdentifier: String? = nil,
        scheduler: RitualScheduler?
    ) {
        pendingCoreSessionFinish = PendingCoreSessionFinish(
            operationID: UUID(),
            sessionId: activeCoreSession?.id,
            ritualId: scheduler?.coreRitualId ?? activeCoreSession?.ritualId,
            status: status,
            endSource: endSource,
            tagIdentifier: tagIdentifier,
            createdAt: .now
        )
        savePendingCoreSessionFinish()
        activeCoreSession = nil

        guard let accessToken = activeAccessToken, !accessToken.isEmpty else {
            coreSyncMessage = "La finalización quedó pendiente hasta recuperar conexión."
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await self.refreshRitualSessionState(accessToken: accessToken)
            await self.loadFocusMetricsSummary(accessToken: accessToken)
        }
    }

    private func queueCoreModeSessionFinish(
        status: String,
        endSource: String,
        tagIdentifier: String? = nil,
        mode: FocusMode?
    ) {
        pendingCoreModeSessionFinish = PendingCoreModeSessionFinish(
            operationID: UUID(),
            sessionId: activeCoreModeSession?.id,
            modeId: mode?.coreModeId ?? activeCoreModeSession?.modeId,
            status: status,
            endSource: endSource,
            tagIdentifier: tagIdentifier,
            createdAt: .now
        )
        savePendingCoreModeSessionFinish()
        activeCoreModeSession = nil

        guard let accessToken = activeAccessToken, !accessToken.isEmpty else {
            coreSyncMessage = "La finalización del modo quedó pendiente hasta recuperar conexión."
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await self.refreshModeSessionState(accessToken: accessToken)
            await self.loadFocusMetricsSummary(accessToken: accessToken)
        }
    }

    private func syncPendingCoreSessionFinish(accessToken: String) async {
        guard !isFinishingCoreSession,
              let pending = pendingCoreSessionFinish,
              let userID = activeAccountID,
              syncOutbox.isDue(userID: userID, type: .finishRitual),
              !accessToken.isEmpty else {
            return
        }

        isFinishingCoreSession = true
        syncOutbox.markSyncing(userID: userID, type: .finishRitual)
        defer { isFinishingCoreSession = false }

        do {
            let sessionId: String

            if let pendingSessionId = pending.sessionId {
                sessionId = pendingSessionId
            } else {
                guard let activeSession = try await coreApi.getActiveRitualSession(accessToken: accessToken) else {
                    clearPendingCoreSessionFinish()
                    activeCoreSession = nil
                    coreSyncMessage = "La sesión ya estaba finalizada en core-api."
                    return
                }

                if let ritualId = pending.ritualId,
                   activeSession.ritualId != ritualId {
                    clearPendingCoreSessionFinish()
                    coreSyncMessage = "Se descartó una finalización pendiente de otro ritual."
                    return
                }

                sessionId = activeSession.id
            }

            _ = try await coreApi.finishRitualSession(
                accessToken: accessToken,
                sessionId: sessionId,
                body: FinishRitualSessionRequest(
                    status: pending.status,
                    endSource: pending.endSource,
                    tagIdentifier: pending.tagIdentifier
                ),
                idempotencyKey: pending.operationID?.uuidString
            )

            clearPendingCoreSessionFinish()
            activeCoreSession = nil
            coreSyncMessage = "Sesión de ritual finalizada."
            deviceActivityDebugStore.log("Finalización confirmada por core-api.")
        } catch {
            if Self.isActiveSessionNotFoundError(error) {
                clearPendingCoreSessionFinish()
                activeCoreSession = nil
                coreSyncMessage = "La sesión ya estaba finalizada en core-api."
                return
            }

            syncOutbox.markFailure(userID: userID, type: .finishRitual, error: error)
            refreshSyncOutboxStatus()
            scheduleRitualOutboxRetry(userID: userID, accessToken: accessToken)
            coreSyncMessage = "Finalización pendiente: \(error.localizedDescription)"
            deviceActivityDebugStore.log("Finalización core pendiente: \(error.localizedDescription)")
            print("Core ritual session finish error:", error)
        }
    }

    private func syncPendingCoreModeSessionFinish(accessToken: String) async {
        guard !isFinishingCoreModeSession,
              let pending = pendingCoreModeSessionFinish,
              let userID = activeAccountID,
              syncOutbox.isDue(userID: userID, type: .finishMode),
              !accessToken.isEmpty else {
            return
        }

        isFinishingCoreModeSession = true
        syncOutbox.markSyncing(userID: userID, type: .finishMode)
        defer { isFinishingCoreModeSession = false }

        do {
            let sessionId: String

            if let pendingSessionId = pending.sessionId {
                sessionId = pendingSessionId
            } else {
                guard let activeSession = try await coreApi.getActiveModeSession(accessToken: accessToken) else {
                    clearPendingCoreModeSessionFinish()
                    activeCoreModeSession = nil
                    coreSyncMessage = "La sesión de modo ya estaba finalizada en core-api."
                    return
                }

                if let modeId = pending.modeId,
                   activeSession.modeId != modeId {
                    clearPendingCoreModeSessionFinish()
                    coreSyncMessage = "Se descartó una finalización pendiente de otro modo."
                    return
                }

                sessionId = activeSession.id
            }

            _ = try await coreApi.finishModeSession(
                accessToken: accessToken,
                sessionId: sessionId,
                body: FinishModeSessionRequest(
                    status: pending.status,
                    endSource: pending.endSource,
                    tagIdentifier: pending.tagIdentifier
                ),
                idempotencyKey: pending.operationID?.uuidString
            )

            clearPendingCoreModeSessionFinish()
            activeCoreModeSession = nil
            coreSyncMessage = "Sesión de modo finalizada."
            deviceActivityDebugStore.log("Finalización de modo confirmada por core-api.")
        } catch {
            if Self.isActiveModeSessionNotFoundError(error) {
                clearPendingCoreModeSessionFinish()
                activeCoreModeSession = nil
                coreSyncMessage = "La sesión de modo ya estaba finalizada en core-api."
                return
            }

            syncOutbox.markFailure(userID: userID, type: .finishMode, error: error)
            refreshSyncOutboxStatus()
            scheduleModeOutboxRetry(userID: userID, accessToken: accessToken)
            coreSyncMessage = "Finalización de modo pendiente: \(error.localizedDescription)"
            deviceActivityDebugStore.log("Finalización core de modo pendiente: \(error.localizedDescription)")
            print("Core mode session finish error:", error)
        }
    }

    private func savePendingCoreSessionFinish() {
        guard let pendingCoreSessionFinish,
              let userID = activeAccountID else {
            saveLegacyPendingCoreSessionFinish()
            return
        }

        let operationID = pendingCoreSessionFinish.operationID ?? UUID()
        let persisted = PendingCoreSessionFinish(
            operationID: operationID,
            sessionId: pendingCoreSessionFinish.sessionId,
            ritualId: pendingCoreSessionFinish.ritualId,
            status: pendingCoreSessionFinish.status,
            endSource: pendingCoreSessionFinish.endSource,
            tagIdentifier: nil,
            createdAt: pendingCoreSessionFinish.createdAt
        )

        guard let data = try? JSONEncoder().encode(persisted) else {
            defaults.removeObject(forKey: pendingCoreSessionFinishKey)
            return
        }

        do {
            if let tagIdentifier = pendingCoreSessionFinish.tagIdentifier {
                try keychainStore.saveSyncSecret(tagIdentifier, operationID: operationID)
            }
            try syncOutbox.upsert(
                id: operationID,
                userID: userID,
                type: .finishRitual,
                payload: data
            )
            self.pendingCoreSessionFinish = PendingCoreSessionFinish(
                operationID: operationID,
                sessionId: pendingCoreSessionFinish.sessionId,
                ritualId: pendingCoreSessionFinish.ritualId,
                status: pendingCoreSessionFinish.status,
                endSource: pendingCoreSessionFinish.endSource,
                tagIdentifier: pendingCoreSessionFinish.tagIdentifier,
                createdAt: pendingCoreSessionFinish.createdAt
            )
            defaults.removeObject(forKey: pendingCoreSessionFinishKey)
            refreshSyncOutboxStatus()
        } catch {
            keychainStore.deleteSyncSecret(operationID: operationID)
            coreSyncMessage = "No se pudo guardar la finalización pendiente: \(error.localizedDescription)"
        }
    }

    private func clearPendingCoreSessionFinish() {
        ritualOutboxRetryTask?.cancel()
        if let operationID = pendingCoreSessionFinish?.operationID {
            keychainStore.deleteSyncSecret(operationID: operationID)
        }
        if let userID = activeAccountID {
            syncOutbox.remove(userID: userID, type: .finishRitual)
        }
        pendingCoreSessionFinish = nil
        defaults.removeObject(forKey: pendingCoreSessionFinishKey)
        refreshSyncOutboxStatus()
    }

    private func savePendingCoreModeSessionFinish() {
        guard let pendingCoreModeSessionFinish,
              let userID = activeAccountID else {
            saveLegacyPendingCoreModeSessionFinish()
            return
        }

        let operationID = pendingCoreModeSessionFinish.operationID ?? UUID()
        let persisted = PendingCoreModeSessionFinish(
            operationID: operationID,
            sessionId: pendingCoreModeSessionFinish.sessionId,
            modeId: pendingCoreModeSessionFinish.modeId,
            status: pendingCoreModeSessionFinish.status,
            endSource: pendingCoreModeSessionFinish.endSource,
            tagIdentifier: nil,
            createdAt: pendingCoreModeSessionFinish.createdAt
        )

        guard let data = try? JSONEncoder().encode(persisted) else {
            defaults.removeObject(forKey: pendingCoreModeSessionFinishKey)
            return
        }

        do {
            if let tagIdentifier = pendingCoreModeSessionFinish.tagIdentifier {
                try keychainStore.saveSyncSecret(tagIdentifier, operationID: operationID)
            }
            try syncOutbox.upsert(
                id: operationID,
                userID: userID,
                type: .finishMode,
                payload: data
            )
            self.pendingCoreModeSessionFinish = PendingCoreModeSessionFinish(
                operationID: operationID,
                sessionId: pendingCoreModeSessionFinish.sessionId,
                modeId: pendingCoreModeSessionFinish.modeId,
                status: pendingCoreModeSessionFinish.status,
                endSource: pendingCoreModeSessionFinish.endSource,
                tagIdentifier: pendingCoreModeSessionFinish.tagIdentifier,
                createdAt: pendingCoreModeSessionFinish.createdAt
            )
            defaults.removeObject(forKey: pendingCoreModeSessionFinishKey)
            refreshSyncOutboxStatus()
        } catch {
            keychainStore.deleteSyncSecret(operationID: operationID)
            coreSyncMessage = "No se pudo guardar la finalización del modo: \(error.localizedDescription)"
        }
    }

    private func clearPendingCoreModeSessionFinish() {
        modeOutboxRetryTask?.cancel()
        if let operationID = pendingCoreModeSessionFinish?.operationID {
            keychainStore.deleteSyncSecret(operationID: operationID)
        }
        if let userID = activeAccountID {
            syncOutbox.remove(userID: userID, type: .finishMode)
        }
        pendingCoreModeSessionFinish = nil
        defaults.removeObject(forKey: pendingCoreModeSessionFinishKey)
        refreshSyncOutboxStatus()
    }

    private func saveLegacyPendingCoreSessionFinish() {
        guard let pendingCoreSessionFinish,
              let data = try? JSONEncoder().encode(pendingCoreSessionFinish) else {
            defaults.removeObject(forKey: pendingCoreSessionFinishKey)
            return
        }
        defaults.set(data, forKey: pendingCoreSessionFinishKey)
    }

    private func saveLegacyPendingCoreModeSessionFinish() {
        guard let pendingCoreModeSessionFinish,
              let data = try? JSONEncoder().encode(pendingCoreModeSessionFinish) else {
            defaults.removeObject(forKey: pendingCoreModeSessionFinishKey)
            return
        }
        defaults.set(data, forKey: pendingCoreModeSessionFinishKey)
    }

    private func restorePendingSyncOperations(userID: String) {
        if pendingCoreSessionFinish != nil,
           syncOutbox.payload(userID: userID, type: .finishRitual) == nil {
            savePendingCoreSessionFinish()
        }
        if pendingCoreModeSessionFinish != nil,
           syncOutbox.payload(userID: userID, type: .finishMode) == nil {
            savePendingCoreModeSessionFinish()
        }

        pendingCoreSessionFinish = restoredRitualFinish(userID: userID)
        pendingCoreModeSessionFinish = restoredModeFinish(userID: userID)
        defaults.removeObject(forKey: pendingCoreSessionFinishKey)
        defaults.removeObject(forKey: pendingCoreModeSessionFinishKey)

        if let accessToken = activeAccessToken, !accessToken.isEmpty {
            Task { [weak self] in
                guard let self else { return }
                await self.syncPendingCoreSessionFinish(accessToken: accessToken)
                await self.syncPendingCoreModeSessionFinish(accessToken: accessToken)
                if self.pendingCoreSessionFinish != nil {
                    self.scheduleRitualOutboxRetry(userID: userID, accessToken: accessToken)
                }
                if self.pendingCoreModeSessionFinish != nil {
                    self.scheduleModeOutboxRetry(userID: userID, accessToken: accessToken)
                }
            }
        }
    }

    private func scheduleRitualOutboxRetry(userID: String, accessToken: String) {
        ritualOutboxRetryTask?.cancel()
        guard let retryDate = syncOutbox.nextRetryDate(userID: userID, type: .finishRitual) else {
            return
        }

        ritualOutboxRetryTask = Task { [weak self] in
            let delay = max(0, retryDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled,
                  let self,
                  self.activeAccountID == userID else {
                return
            }
            await self.syncPendingCoreSessionFinish(accessToken: accessToken)
        }
    }

    private func scheduleModeOutboxRetry(userID: String, accessToken: String) {
        modeOutboxRetryTask?.cancel()
        guard let retryDate = syncOutbox.nextRetryDate(userID: userID, type: .finishMode) else {
            return
        }

        modeOutboxRetryTask = Task { [weak self] in
            let delay = max(0, retryDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled,
                  let self,
                  self.activeAccountID == userID else {
                return
            }
            await self.syncPendingCoreModeSessionFinish(accessToken: accessToken)
        }
    }

    private func restoredRitualFinish(userID: String) -> PendingCoreSessionFinish? {
        guard let data = syncOutbox.payload(userID: userID, type: .finishRitual),
              let stored = try? JSONDecoder().decode(PendingCoreSessionFinish.self, from: data) else {
            return nil
        }
        let operationID = stored.operationID ?? syncOutbox.operationID(userID: userID, type: .finishRitual)
        return PendingCoreSessionFinish(
            operationID: operationID,
            sessionId: stored.sessionId,
            ritualId: stored.ritualId,
            status: stored.status,
            endSource: stored.endSource,
            tagIdentifier: operationID.flatMap(keychainStore.loadSyncSecret),
            createdAt: stored.createdAt
        )
    }

    private func restoredModeFinish(userID: String) -> PendingCoreModeSessionFinish? {
        guard let data = syncOutbox.payload(userID: userID, type: .finishMode),
              let stored = try? JSONDecoder().decode(PendingCoreModeSessionFinish.self, from: data) else {
            return nil
        }
        let operationID = stored.operationID ?? syncOutbox.operationID(userID: userID, type: .finishMode)
        return PendingCoreModeSessionFinish(
            operationID: operationID,
            sessionId: stored.sessionId,
            modeId: stored.modeId,
            status: stored.status,
            endSource: stored.endSource,
            tagIdentifier: operationID.flatMap(keychainStore.loadSyncSecret),
            createdAt: stored.createdAt
        )
    }

    private static func isActiveSessionNotFoundError(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, message, _) = error else {
            return false
        }

        return statusCode == 404 && message.localizedCaseInsensitiveContains("active ritual session not found")
    }

    private static func isActiveModeSessionNotFoundError(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, message, _) = error else {
            return false
        }

        return statusCode == 404 && message.localizedCaseInsensitiveContains("active mode session not found")
    }

    private static func isRitualNotFoundError(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, _, _) = error else {
            return false
        }
        return statusCode == 404
    }

    private static func isForbiddenError(_ error: Error) -> Bool {
        guard case let CoreAPIError.serverError(statusCode, _, _) = error else {
            return false
        }
        return statusCode == 403
    }

    private static func isoDateString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func parseISODate(_ value: String?) -> Date? {
        guard let value else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        return ISO8601DateFormatter().date(from: value)
    }

    private static func isEarlyMonitorEnd(
        _ endedEvent: SharedRitualActivityEvent,
        plannedEndAt: Date?
    ) -> Bool {
        guard let plannedEndAt else { return false }
        return endedEvent.occurredAt < plannedEndAt.addingTimeInterval(-earlyMonitorEndGraceSeconds)
    }

    private func applyCoreRitualResponse(
        _ response: RitualResponse,
        localSchedulerID: UUID
    ) {
        guard let index = schedulers.firstIndex(
            where: { $0.id == localSchedulerID }
        ) else {
            return
        }

        let scheduler = schedulers[index]
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
            nfcUnlockEnabled: response.nfcUnlockEnabled,
            strictModeEnabled: scheduler.strictModeEnabled,
            blockAppInstallation: scheduler.blockAppInstallation,
            blockAdultContent: scheduler.blockAdultContent
        )
        persistSchedulers()
        rescheduleDeviceActivities()
        refreshScheduledRitualState()
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

    private static func formattedModeDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(remainingMinutes) min"
        }
        if remainingMinutes == 0 {
            return hours == 1 ? "1 hora" : "\(hours) horas"
        }
        return "\(hours) h \(remainingMinutes) min"
    }
}

private extension UpdateModeRequest {
    func withPassword(_ password: String?) -> UpdateModeRequest {
        UpdateModeRequest(
            title: title,
            icon: icon,
            appCount: appCount,
            categoryCount: categoryCount,
            domainCount: domainCount,
            selectionDigest: selectionDigest,
            isProtected: isProtected,
            nfcUnlockEnabled: nfcUnlockEnabled,
            password: isProtected ? password : nil
        )
    }
}

private extension CreateRitualRequest {
    func withPassword(_ password: String?) -> CreateRitualRequest {
        CreateRitualRequest(
            title: title,
            description: description,
            icon: icon,
            durationMinutes: durationMinutes,
            weekdays: weekdays,
            startTime: startTime,
            endTime: endTime,
            appCount: appCount,
            categoryCount: categoryCount,
            domainCount: domainCount,
            selectionDigest: selectionDigest,
            isProtected: isProtected,
            nfcUnlockEnabled: nfcUnlockEnabled,
            password: isProtected ? password : nil
        )
    }
}
