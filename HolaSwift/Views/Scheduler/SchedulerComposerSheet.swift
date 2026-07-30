import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct SchedulerComposerSheet: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let accessToken: String?
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Self.defaultDate(hour: 17, minute: 0)
    @State private var endDate = Self.defaultDate(hour: 18, minute: 0)
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var isPasswordProtected = false
    @State private var isNfcProtected = false
    @State private var isStrictModeEnabled = false
    @State private var blockAppInstallation = false
    @State private var blockAdultContent = false
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var protectionMessage: String?
    @State private var isSaving = false

    init(viewModel: BlockSetupViewModel, accessToken: String? = nil) {
        self.viewModel = viewModel
        self.accessToken = accessToken
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

                    Text("Nuevo ritual")
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Hero header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nuevo ritual")
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
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Empieza")
                                        .font(.system(size: 15))
                                        .foregroundStyle(RituoPalette.white.opacity(0.70))
                                    Spacer()
                                    DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .environment(\.locale, Self.twentyFourHourLocale)
                                }
                                .padding(.vertical, 4)

                                Rectangle()
                                    .fill(RituoPalette.white.opacity(0.06))
                                    .frame(height: 1)
                                    .padding(.vertical, 4)

                                HStack {
                                    Text("Termina")
                                        .font(.system(size: 15))
                                        .foregroundStyle(RituoPalette.white.opacity(0.70))
                                    Spacer()
                                    DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .environment(\.locale, Self.twentyFourHourLocale)
                                }
                                .padding(.vertical, 4)
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
                                            Text("Impide eliminar rituo mientras este ritual esté activo.")
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

                                if isPasswordProtected {
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
                }
            }
        }
        .familyActivityPicker(
            isPresented: $viewModel.isPickerPresented,
            selection: $viewModel.selection
        )
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

        if isPasswordProtected {
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

        let didSave = viewModel.saveScheduler(
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
            password: isPasswordProtected ? password : nil
        )

        guard didSave else {
            isSaving = false
            return
        }

        if let accessToken {
            Task {
                await viewModel.syncLatestSchedulerToCore(accessToken: accessToken)
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
