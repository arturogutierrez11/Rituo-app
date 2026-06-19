import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct SchedulerComposerSheet: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let accessToken: String?
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var focusTarget = ""
    @State private var startDate = Self.defaultDate(hour: 17, minute: 0)
    @State private var endDate = Self.defaultDate(hour: 18, minute: 0)
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var isProtected = false
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var protectionMessage: String?

    init(viewModel: BlockSetupViewModel, accessToken: String? = nil) {
        self.viewModel = viewModel
        self.accessToken = accessToken
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RituoPalette.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        FuturisticCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nuevo ritual")
                                    .font(.custom("Helvetica", size: 32).weight(.semibold))
                                    .foregroundStyle(RituoPalette.text)
                                Text("Elegí horario, dias y las apps que querés bloquear durante este ritual.")
                                    .font(.custom("Helvetica", size: 14).weight(.medium))
                                    .foregroundStyle(RituoPalette.subtext)
                            }
                        }

                        SchedulerFormCard(title: "Nombre") {
                            TextField("Ej: Lectura tarde", text: $title)
                                .textInputAutocapitalization(.words)
                        }

                        SchedulerFormCard(title: "Objetivo") {
                            TextField("Ej: Solo Instagram", text: $focusTarget)
                        }

                        SchedulerFormCard(title: "Horario") {
                            DatePicker("Empieza", selection: $startDate, displayedComponents: .hourAndMinute)
                            DatePicker("Termina", selection: $endDate, displayedComponents: .hourAndMinute)
                        }

                        SchedulerFormCard(title: "Dias") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(weekdayOptions, id: \.id) { option in
                                    Button {
                                        if selectedWeekdays.contains(option.id) {
                                            selectedWeekdays.remove(option.id)
                                        } else {
                                            selectedWeekdays.insert(option.id)
                                        }
                                    } label: {
                                        Text(option.title)
                                            .font(.custom("Helvetica", size: 14).weight(.semibold))
                                            .foregroundStyle(selectedWeekdays.contains(option.id) ? RituoPalette.background : RituoPalette.text)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(selectedWeekdays.contains(option.id) ? RituoPalette.glow : RituoPalette.softPanel)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        SchedulerFormCard(title: "Protección familiar") {
                            VStack(alignment: .leading, spacing: 14) {
                                Toggle(isOn: $isProtected.animation(.easeInOut(duration: 0.2))) {
                                    Label {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Proteger este ritual")
                                                .font(.custom("Helvetica", size: 16).weight(.bold))
                                            Text("Solo se podrá eliminar usando la contraseña.")
                                                .font(.custom("Helvetica", size: 12).weight(.medium))
                                                .foregroundStyle(RituoPalette.subtext)
                                        }
                                    } icon: {
                                        Image(systemName: "lock.shield.fill")
                                            .foregroundStyle(RituoPalette.lightBlue)
                                    }
                                }
                                .tint(RituoPalette.glow)

                                if isProtected {
                                    VStack(spacing: 10) {
                                        SecureField("Contraseña", text: $password)
                                            .textContentType(.newPassword)
                                            .padding(14)
                                            .background(protectionFieldBackground)

                                        SecureField("Repetir contraseña", text: $passwordConfirmation)
                                            .textContentType(.newPassword)
                                            .padding(14)
                                            .background(protectionFieldBackground)
                                    }
                                    .transition(.move(edge: .top).combined(with: .opacity))

                                    Label(
                                        "Durante el horario, las apps se liberan únicamente con tu tag NFC vinculado.",
                                        systemImage: "wave.3.right.circle.fill"
                                    )
                                    .font(.custom("Helvetica", size: 12).weight(.semibold))
                                    .foregroundStyle(RituoPalette.lightBlue)

                                    if let protectionMessage {
                                        Text(protectionMessage)
                                            .font(.custom("Helvetica", size: 12).weight(.semibold))
                                            .foregroundStyle(RituoPalette.danger)
                                    }
                                }
                            }
                        }

                        SchedulerFormCard(title: "Apps guardadas") {
                            Button {
                                Task {
                                    await viewModel.openActivityPicker()
                                }
                            } label: {
                                Label("Seleccionar apps para este ritual", systemImage: "square.grid.2x2")
                                    .font(.custom("Helvetica", size: 16).weight(.bold))
                                    .foregroundStyle(RituoPalette.background)
                                    .frame(maxWidth: .infinity, minHeight: 54)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(RituoPalette.glow)
                                    )
                            }
                            .buttonStyle(LoginPressButtonStyle())

                            HStack(spacing: 12) {
                                InfoPill(value: "\(viewModel.appCount)", label: "Apps")
                                InfoPill(value: "\(viewModel.categoryCount)", label: "Categorias")
                                InfoPill(value: "\(viewModel.domainCount)", label: "Web")
                            }

                            Text(viewModel.selectionSummary)
                                .font(.custom("Helvetica", size: 13).weight(.medium))
                                .foregroundStyle(RituoPalette.subtext)

                            AppSelectionPreview(selection: viewModel.selection)
                        }

                        if let message = viewModel.coreSyncMessage {
                            MessageStrip(text: message, tint: message.contains("core-api") || message.contains("sincroniz") ? RituoPalette.success : RituoPalette.danger)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        if isProtected {
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
                        let calendar = Calendar.current
                        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
                        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)

                        let didSave = viewModel.saveScheduler(
                            title: title,
                            focusTarget: focusTarget,
                            startHour: startComponents.hour ?? 0,
                            startMinute: startComponents.minute ?? 0,
                            endHour: endComponents.hour ?? 0,
                            endMinute: endComponents.minute ?? 0,
                            weekdays: Array(selectedWeekdays),
                            isProtected: isProtected,
                            password: isProtected ? password : nil
                        )

                        if didSave {
                            if let accessToken {
                                Task {
                                    await viewModel.syncLatestSchedulerToCore(accessToken: accessToken)
                                }
                            }
                            dismiss()
                        }
                    }
                    .font(.custom("Helvetica", size: 16).weight(.semibold))
                }
            }
        }
        .familyActivityPicker(
            isPresented: $viewModel.isPickerPresented,
            selection: $viewModel.selection
        )
    }

    private var weekdayOptions: [(id: Int, title: String)] {
        [(2, "Lun"), (3, "Mar"), (4, "Mie"), (5, "Jue"), (6, "Vie"), (7, "Sab"), (1, "Dom")]
    }

    private var protectionFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(RituoPalette.softPanel)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RituoPalette.lightBlue.opacity(0.22), lineWidth: 1)
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
}

struct SchedulerFormCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        FuturisticCard {
            VStack(alignment: .leading, spacing: 14) {
                PanelEyebrow(title)
                content
                    .font(.custom("Helvetica", size: 16).weight(.medium))
                    .foregroundStyle(RituoPalette.text)
                    .tint(RituoPalette.glow)
            }
        }
    }
}
