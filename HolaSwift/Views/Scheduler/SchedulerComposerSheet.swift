import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct SchedulerComposerSheet: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let accessToken: String?
    let editingScheduler: RitualScheduler?
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Self.defaultDate(hour: 17, minute: 0)
    @State private var endDate = Self.defaultDate(hour: 18, minute: 0)
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var breakCount = 0
    @State private var breakDurationMinutes = 5
    @State private var isPasswordProtected = false
    @State private var isNfcProtected = false
    @State private var isStrictModeEnabled = false
    @State private var blockAppInstallation = false
    @State private var blockAdultContent = false
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var protectionMessage: String?
    @State private var isSaving = false
    @State private var hasConfiguredInitialState = false

    init(viewModel: BlockSetupViewModel, accessToken: String? = nil, editingScheduler: RitualScheduler? = nil) {
        self.viewModel = viewModel
        self.accessToken = accessToken
        self.editingScheduler = editingScheduler
    }

    /// The edited ritual was already protected before this session started — editing
    /// (including just changing the schedule) requires re-entering that existing
    /// password to authorize the change, per core-api's PATCH /rituals/:id contract.
    private var requiresExistingPasswordToSave: Bool {
        editingScheduler?.isProtected == true
    }

    private let cardBg = Color(red: 0.12, green: 0.16, blue: 0.26)

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom nav bar
                HStack {
                    Button("Cerrar") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RituoPalette.white.opacity(0.45))

                    Spacer()

                    Text(editingScheduler == nil ? "Nuevo ritual" : "Editar ritual")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)

                    Spacer()

                    Button { save() } label: {
                        HStack(spacing: 6) {
                            if isSaving {
                                ProgressView()
                                    .tint(RituoPalette.white)
                                    .scaleEffect(0.70)
                            }
                            Text(isSaving ? "Guardando" : "Guardar")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .opacity(isSaving ? 0.65 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(RituoPalette.white.opacity(0.06))
                    .frame(height: 1)

                // GeometryReader hard-clamps the content to exactly the available width —
                // without it, a child that refuses to compress below its intrinsic size
                // (e.g. a DatePicker chip) can make the content wider than the screen,
                // which makes the "vertical-only" ScrollView draggable sideways too.
                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                        // Hero header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(editingScheduler == nil ? "Nuevo ritual" : "Editar ritual")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(RituoPalette.white)
                            Text("Definí horario, días y las apps a bloquear.")
                                .font(.system(size: 14))
                                .foregroundStyle(RituoPalette.white.opacity(0.38))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                        // Nombre
                        composerCard(label: "NOMBRE") {
                            TextField("Ej: Lectura tarde", text: $title)
                                .font(.system(size: 16))
                                .foregroundStyle(RituoPalette.white)
                                .tint(RituoPalette.lightBlue)
                        }

                        // Horario
                        composerCard(label: "HORARIO") {
                            VStack(spacing: 16) {
                                HStack(spacing: 0) {
                                    Circle()
                                        .fill(RituoPalette.lightBlue)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: RituoPalette.lightBlue.opacity(0.85), radius: 6)

                                    LinearGradient(
                                        colors: [RituoPalette.lightBlue.opacity(0.65), RituoPalette.lightBlue.opacity(0.10)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .frame(height: 2)

                                    Circle()
                                        .fill(RituoPalette.lightBlue.opacity(0.35))
                                        .frame(width: 8, height: 8)
                                }

                                HStack(spacing: 10) {
                                    timeChip(label: "EMPIEZA", selection: $startDate)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(RituoPalette.lightBlue.opacity(0.45))
                                    timeChip(label: "TERMINA", selection: $endDate)
                                }

                                if !durationSummaryText.isEmpty {
                                    Text(durationSummaryText)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(RituoPalette.lightBlue.opacity(0.85))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        // Días
                        composerCard(label: "DÍAS") {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                                spacing: 8
                            ) {
                                ForEach(weekdayOptions, id: \.id) { option in
                                    let active = selectedWeekdays.contains(option.id)
                                    Button {
                                        if active { selectedWeekdays.remove(option.id) }
                                        else { selectedWeekdays.insert(option.id) }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(option.title)
                                                .font(.system(size: 11, weight: active ? .bold : .medium))
                                                .foregroundStyle(active ? RituoPalette.deepOceanBlue : RituoPalette.white.opacity(0.45))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(active ? RituoPalette.white : RituoPalette.white.opacity(0.07))
                                        )
                                    }
                                    .buttonStyle(LoginPressButtonStyle())
                                }
                            }
                        }

                        // Recreos
                        composerCard(label: "RECREOS") {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                RadialGradient(
                                                    colors: [RituoPalette.lightBlue.opacity(0.30), RituoPalette.lightBlue.opacity(0.08)],
                                                    center: .center,
                                                    startRadius: 0,
                                                    endRadius: 22
                                                )
                                            )
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(RituoPalette.lightBlue)
                                            .shadow(color: RituoPalette.lightBlue.opacity(0.6), radius: 4)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(breakSummaryText)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(RituoPalette.white)
                                        Text("Pausa el bloqueo por un rato durante el ritual.")
                                            .font(.system(size: 12))
                                            .foregroundStyle(RituoPalette.white.opacity(0.35))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                breakPillRow(label: "CANTIDAD", values: Array(0 ... 3), suffix: "", selection: $breakCount)

                                BreakDurationRangeSlider(
                                    label: "DURACIÓN POR RECREO",
                                    options: BreakDurationRangeSlider.standardOptions,
                                    selection: $breakDurationMinutes,
                                    tint: RituoPalette.lightBlue
                                )
                                .opacity(breakCount > 0 ? 1 : 0.35)
                                .disabled(breakCount == 0)
                                .animation(.easeInOut(duration: 0.18), value: breakCount)
                            }
                        }

                        // Protección
                        composerCard(label: "PROTECCIÓN") {
                            VStack(alignment: .leading, spacing: 14) {
                                Toggle(isOn: $isPasswordProtected.animation(.easeInOut(duration: 0.22))) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.shield.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(RituoPalette.lightBlue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Proteger este ritual")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(RituoPalette.white)
                                            Text("Solo se puede eliminar con contraseña.")
                                                .font(.system(size: 12))
                                                .foregroundStyle(RituoPalette.white.opacity(0.35))
                                        }
                                    }
                                }
                                .tint(RituoPalette.lightBlue)

                                Toggle(isOn: $isNfcProtected.animation(.easeInOut(duration: 0.22))) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "wave.3.right.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(RituoPalette.lightBlue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Proteger con tag NFC")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(RituoPalette.white)
                                            Text("Para eliminarlo vas a tener que apoyar tu tarjeta rituo.")
                                                .font(.system(size: 12))
                                                .foregroundStyle(RituoPalette.white.opacity(0.35))
                                        }
                                    }
                                }
                                .tint(RituoPalette.lightBlue)

                                Rectangle()
                                    .fill(RituoPalette.white.opacity(0.06))
                                    .frame(height: 1)

                                Toggle(isOn: $isStrictModeEnabled.animation(.easeInOut(duration: 0.22))) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.shield.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(RituoPalette.lightBlue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Modo estricto")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(RituoPalette.white)
                                            Text("Bloquea la eliminación de todas las apps del dispositivo, incluida rituo, mientras este ritual esté activo.")
                                                .font(.system(size: 12))
                                                .foregroundStyle(RituoPalette.white.opacity(0.35))
                                        }
                                    }
                                }
                                .tint(RituoPalette.lightBlue)

                                Toggle(isOn: $blockAppInstallation.animation(.easeInOut(duration: 0.22))) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.down.app.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(RituoPalette.lightBlue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Bloquear descargas de apps")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(RituoPalette.white)
                                            Text("Impide instalar apps mientras este ritual esté activo.")
                                                .font(.system(size: 12))
                                                .foregroundStyle(RituoPalette.white.opacity(0.35))
                                        }
                                    }
                                }
                                .tint(RituoPalette.lightBlue)

                                Toggle(isOn: $blockAdultContent.animation(.easeInOut(duration: 0.22))) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "shield.lefthalf.filled")
                                            .font(.system(size: 16))
                                            .foregroundStyle(RituoPalette.lightBlue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Bloquear contenido sensible en la web")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(RituoPalette.white)
                                            Text("Filtra contenido adulto, redes sociales y apuestas durante el ritual.")
                                                .font(.system(size: 12))
                                                .foregroundStyle(RituoPalette.white.opacity(0.35))
                                        }
                                    }
                                }
                                .tint(RituoPalette.lightBlue)

                                if requiresExistingPasswordToSave {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Este ritual ya está protegido. Ingresá la contraseña actual para guardar cualquier cambio, aunque no sea de protección.")
                                            .font(.system(size: 12))
                                            .foregroundStyle(RituoPalette.white.opacity(0.45))

                                        SecureField("Contraseña actual", text: $password)
                                            .textContentType(.password)
                                            .font(.system(size: 15))
                                            .foregroundStyle(RituoPalette.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(RituoPalette.white.opacity(0.06))
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(RituoPalette.lightBlue.opacity(0.22), lineWidth: 1)
                                                    }
                                            )
                                    }
                                    .transition(.move(edge: .top).combined(with: .opacity))

                                    if let protectionMessage {
                                        Text(protectionMessage)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(RituoPalette.danger)
                                    }
                                } else if isPasswordProtected {
                                    VStack(spacing: 8) {
                                        SecureField("Contraseña", text: $password)
                                            .textContentType(.newPassword)
                                            .font(.system(size: 15))
                                            .foregroundStyle(RituoPalette.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(RituoPalette.white.opacity(0.06))
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(RituoPalette.lightBlue.opacity(0.22), lineWidth: 1)
                                                    }
                                            )

                                        SecureField("Repetir contraseña", text: $passwordConfirmation)
                                            .textContentType(.newPassword)
                                            .font(.system(size: 15))
                                            .foregroundStyle(RituoPalette.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(RituoPalette.white.opacity(0.06))
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(RituoPalette.lightBlue.opacity(0.22), lineWidth: 1)
                                                    }
                                            )
                                    }
                                    .transition(.move(edge: .top).combined(with: .opacity))

                                    if let protectionMessage {
                                        Text(protectionMessage)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(RituoPalette.danger)
                                    }
                                } else if let protectionMessage {
                                    Text(protectionMessage)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(RituoPalette.danger)
                                }
                            }
                        }

                        // Apps
                        composerCard(label: "APPS A BLOQUEAR") {
                            VStack(spacing: 12) {
                                Button {
                                    Task { await viewModel.openActivityPicker() }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.grid.2x2")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Seleccionar apps")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(RituoPalette.deepOceanBlue)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(RituoPalette.white)
                                    .clipShape(Capsule())
                                    .shadow(color: RituoPalette.white.opacity(0.18), radius: 14, x: 0, y: 4)
                                }
                                .buttonStyle(LoginPressButtonStyle())

                                if viewModel.appCount + viewModel.categoryCount + viewModel.domainCount > 0 {
                                    HStack(spacing: 8) {
                                        appCountPill("\(viewModel.appCount)", "Apps")
                                        appCountPill("\(viewModel.categoryCount)", "Categorías")
                                        appCountPill("\(viewModel.domainCount)", "Web")
                                    }

                                    AppSelectionPreview(selection: viewModel.selection)
                                }
                            }
                        }

                        if let message = viewModel.coreSyncMessage {
                            Text(message)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(message.contains("error") ? RituoPalette.danger : RituoPalette.mistBlue.opacity(0.70))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }
                        }
                        .padding(.bottom, 40)
                        .frame(width: geometry.size.width)
                    }
                }
            }
        }
        .familyActivityPicker(
            isPresented: $viewModel.isPickerPresented,
            selection: $viewModel.selection
        )
        .onAppear { configureForEditingIfNeeded() }
    }

    // MARK: - Edit mode

    private func configureForEditingIfNeeded() {
        guard !hasConfiguredInitialState else { return }
        hasConfiguredInitialState = true

        guard let editingScheduler else {
            // Creating a new ritual: don't inherit a selection left over from
            // whatever the app selection picker was last used for.
            viewModel.selection = FamilyActivitySelection()
            return
        }

        title = editingScheduler.title
        startDate = Self.defaultDate(hour: editingScheduler.startHour, minute: editingScheduler.startMinute)
        endDate = Self.defaultDate(hour: editingScheduler.endHour, minute: editingScheduler.endMinute)
        selectedWeekdays = Set(editingScheduler.weekdays)
        breakCount = editingScheduler.breakCount
        breakDurationMinutes = editingScheduler.breakDurationMinutes
        isPasswordProtected = editingScheduler.isProtected
        isNfcProtected = editingScheduler.nfcUnlockEnabled
        isStrictModeEnabled = editingScheduler.strictModeEnabled
        blockAppInstallation = editingScheduler.blockAppInstallation
        blockAdultContent = editingScheduler.blockAdultContent
        viewModel.selection = editingScheduler.selection
    }

    // MARK: - Card helper

    @ViewBuilder
    private func composerCard<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(RituoPalette.white.opacity(0.30))
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBg)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
                }
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func appCountPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RituoPalette.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(RituoPalette.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RituoPalette.white.opacity(0.06))
        )
    }

    // MARK: - Save

    private func save() {
        guard !isSaving else { return }

        if requiresExistingPasswordToSave {
            guard !password.isEmpty else {
                protectionMessage = "Ingresá la contraseña actual del ritual."
                return
            }
        } else if isPasswordProtected {
            guard password.count >= 4 else {
                protectionMessage = "Usá al menos 4 caracteres."
                return
            }
            guard password == passwordConfirmation else {
                protectionMessage = "Las contraseñas no coinciden."
                return
            }
        }

        protectionMessage = nil
        isSaving = true
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        let passwordToSend = (isPasswordProtected || requiresExistingPasswordToSave) ? password : nil

        let didSave: Bool
        if let editingScheduler {
            didSave = viewModel.updateScheduler(
                editingScheduler,
                title: title,
                startHour: startComponents.hour ?? 0,
                startMinute: startComponents.minute ?? 0,
                endHour: endComponents.hour ?? 0,
                endMinute: endComponents.minute ?? 0,
                weekdays: Array(selectedWeekdays),
                isProtected: isPasswordProtected,
                nfcUnlockEnabled: isNfcProtected,
                strictModeEnabled: isStrictModeEnabled,
                blockAppInstallation: blockAppInstallation,
                blockAdultContent: blockAdultContent,
                breakCount: breakCount,
                breakDurationMinutes: breakDurationMinutes,
                password: passwordToSend
            )
        } else {
            didSave = viewModel.saveScheduler(
                title: title,
                focusTarget: "",
                startHour: startComponents.hour ?? 0,
                startMinute: startComponents.minute ?? 0,
                endHour: endComponents.hour ?? 0,
                endMinute: endComponents.minute ?? 0,
                weekdays: Array(selectedWeekdays),
                isProtected: isPasswordProtected,
                nfcUnlockEnabled: isNfcProtected,
                strictModeEnabled: isStrictModeEnabled,
                blockAppInstallation: blockAppInstallation,
                blockAdultContent: blockAdultContent,
                breakCount: breakCount,
                breakDurationMinutes: breakDurationMinutes,
                password: passwordToSend
            )
        }

        guard didSave else {
            isSaving = false
            return
        }

        if let accessToken {
            Task {
                if editingScheduler != nil {
                    await viewModel.syncLatestSchedulerUpdateToCore(accessToken: accessToken)
                } else {
                    await viewModel.syncLatestSchedulerToCore(accessToken: accessToken)
                }
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            }
        } else {
            isSaving = false
            dismiss()
        }
    }

    // MARK: - Helpers

    private var weekdayOptions: [(id: Int, title: String)] {
        [(2, "L"), (3, "M"), (4, "X"), (5, "J"), (6, "V"), (7, "S"), (1, "D")]
    }

    @ViewBuilder
    private func timeChip(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(RituoPalette.white.opacity(0.30))
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
                .environment(\.locale, Self.twentyFourHourLocale)
                .tint(RituoPalette.lightBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RituoPalette.lightBlue.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(RituoPalette.lightBlue.opacity(0.22), lineWidth: 1)
                }
        )
    }

    private var durationSummaryText: String {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        let startTotal = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endTotal = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        guard startTotal != endTotal else { return "" }

        let duration = endTotal < startTotal ? (24 * 60 - startTotal + endTotal) : (endTotal - startTotal)
        let hours = duration / 60
        let minutes = duration % 60
        var text = ""
        if hours > 0 { text += "\(hours)h" }
        if minutes > 0 { text += (text.isEmpty ? "" : " ") + "\(minutes)m" }
        if endTotal <= startTotal { text += " · cruza medianoche" }
        return text
    }

    private var breakSummaryText: String {
        guard breakCount > 0 else { return "Sin recreos" }
        let plural = breakCount == 1 ? "recreo" : "recreos"
        return "\(breakCount) \(plural) de \(breakDurationMinutes) min"
    }

    @ViewBuilder
    private func breakPillRow(
        label: String,
        values: [Int],
        suffix: String,
        selection: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(RituoPalette.white.opacity(0.28))
            HStack(spacing: 6) {
                ForEach(values, id: \.self) { value in
                    let active = selection.wrappedValue == value
                    Button {
                        selection.wrappedValue = value
                    } label: {
                        Text("\(value)\(suffix)")
                            .font(.system(size: 14, weight: active ? .bold : .medium))
                            .foregroundStyle(active ? RituoPalette.white : RituoPalette.white.opacity(0.50))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(
                                        active
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [RituoPalette.lightBlue, RituoPalette.lightBlue.opacity(0.65)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            : AnyShapeStyle(Color.clear)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(RituoPalette.white.opacity(active ? 0 : 0.12), lineWidth: 1)
                                    }
                            )
                            .shadow(color: active ? RituoPalette.lightBlue.opacity(0.5) : .clear, radius: active ? 8 : 0, y: active ? 3 : 0)
                    }
                    .buttonStyle(LoginPressButtonStyle())
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RituoPalette.white.opacity(0.04))
            )
        }
    }

    private static func defaultDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return components.date ?? .now
    }

    private static let twentyFourHourLocale = Locale(identifier: "en_GB")
}

/// Native range input snapped to a fixed set of non-uniform values (e.g.
/// 1/3/5/10/15 minutes) — dragged by index into `options`, not a continuous
/// value, since the gaps between the allowed durations aren't even. Shared
/// between the ritual composer and the mode start sheet.
struct BreakDurationRangeSlider: View {
    static let standardOptions = [1, 3, 5, 10, 15]

    let label: String
    let options: [Int]
    let selection: Binding<Int>
    var tint: Color = RituoPalette.lightBlue
    var labelColor: Color = RituoPalette.white.opacity(0.28)
    var tickColor: Color = RituoPalette.white.opacity(0.30)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(labelColor)
                Spacer()
                Text("\(selection.wrappedValue) min")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(Self.nearestIndex(for: selection.wrappedValue, in: options)) },
                    set: { newValue in
                        let index = min(max(Int(newValue.rounded()), 0), options.count - 1)
                        selection.wrappedValue = options[index]
                    }
                ),
                in: 0 ... Double(options.count - 1),
                step: 1
            )
            .tint(tint)

            HStack {
                ForEach(options, id: \.self) { option in
                    Text("\(option)m")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tickColor)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private static func nearestIndex(for value: Int, in options: [Int]) -> Int {
        var bestIndex = 0
        var bestDiff = Int.max
        for (index, option) in options.enumerated() {
            let diff = abs(option - value)
            if diff < bestDiff {
                bestDiff = diff
                bestIndex = index
            }
        }
        return bestIndex
    }
}

struct SchedulerFormCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(RituoPalette.white.opacity(0.30))
            content
                .font(.system(size: 16))
                .foregroundStyle(RituoPalette.white)
                .tint(RituoPalette.lightBlue)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
                }
        )
    }
}
