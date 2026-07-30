import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct SchedulerListPage: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    @Binding var selectedTab: RootTab
    let accessToken: String?
    @State private var isCreateSheetPresented = false
    @State private var schedulerPendingDeletion: RitualScheduler?
    @State private var isDeleteConfirmationPresented = false
    @State private var isProtectedDeletePresented = false
    @State private var deletionPassword = ""
    @State private var appeared = false

    init(viewModel: BlockSetupViewModel, selectedTab: Binding<RootTab>, accessToken: String? = nil) {
        self.viewModel = viewModel
        self._selectedTab = selectedTab
        self.accessToken = accessToken
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RituoAnimatedBackground()

            VStack(spacing: 0) {
                pageHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        syncStatusView

                        if viewModel.schedulers.isEmpty && !viewModel.isSyncingRituals {
                            emptyState
                                .opacity(appeared ? 1 : 0)
                        }

                        if viewModel.isSyncingRituals && viewModel.schedulers.isEmpty {
                            RituoLoadingPanel(title: "Cargando rituales")
                        }

                        ForEach(Array(viewModel.schedulers.enumerated()), id: \.element.id) { index, scheduler in
                            RitualCard(
                                scheduler: scheduler,
                                sessions: viewModel.sessions(for: scheduler),
                                isCurrentlyRunning: viewModel.isRunningInCore(scheduler),
                                isLoadingMetrics: viewModel.isLoadingSessionHistories,
                                deleteRitual: {
                                    schedulerPendingDeletion = scheduler
                                    deletionPassword = ""
                                    if scheduler.isProtected {
                                        isProtectedDeletePresented = true
                                    } else {
                                        isDeleteConfirmationPresented = true
                                    }
                                }
                            )
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.48, dampingFraction: 0.82)
                                    .delay(0.06 + Double(index) * 0.07),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 150)
                }
            }

            createButton
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(0.10)) { appeared = true }
        }
        .sheet(isPresented: $isCreateSheetPresented) {
            SchedulerComposerSheet(viewModel: viewModel, accessToken: accessToken)
        }
        .task(id: accessToken) {
            if let accessToken {
                await viewModel.loadCoreRituals(accessToken: accessToken)
                await viewModel.loadRitualSessionHistoriesIfNeeded(accessToken: accessToken)
            }
        }
        .confirmationDialog("Eliminar ritual", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                guard let scheduler = schedulerPendingDeletion else { return }
                schedulerPendingDeletion = nil
                viewModel.validateTagForSensitiveAction(
                    accessToken: accessToken,
                    actionDescription: "eliminar el ritual",
                    alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para eliminar el ritual."
                ) {
                    Task { await viewModel.deleteScheduler(scheduler, accessToken: accessToken) }
                }
            }
            Button("Cancelar", role: .cancel) { schedulerPendingDeletion = nil }
        }
        .alert("Ritual protegido", isPresented: $isProtectedDeletePresented) {
            SecureField("Contraseña", text: $deletionPassword).textContentType(.password)
            Button("Eliminar", role: .destructive) {
                guard let scheduler = schedulerPendingDeletion else { return }
                let password = deletionPassword
                schedulerPendingDeletion = nil
                deletionPassword = ""
                viewModel.validateTagForSensitiveAction(
                    accessToken: accessToken,
                    actionDescription: "eliminar el ritual",
                    alertMessage: "Acerca la tarjeta rituo (apoya el chip, a la altura de la cámara frontal) para eliminar el ritual."
                ) {
                    Task { await viewModel.deleteScheduler(scheduler, accessToken: accessToken, password: password) }
                }
            }
            Button("Cancelar", role: .cancel) {
                schedulerPendingDeletion = nil
                deletionPassword = ""
            }
        } message: {
            Text("Ingresá la contraseña definida al crear el ritual.")
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Rituales")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(RituoPalette.white)

                HStack(spacing: 14) {
                    miniStat(value: focusTotalText, label: "foco")
                    dot()
                    miniStat(value: "\(completedSessionCount)", label: "sesiones")
                    dot()
                    miniStat(value: "\(viewModel.schedulers.count)", label: "rituales")
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 62)
        .padding(.bottom, 22)
    }

    private func miniStat(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RituoPalette.white)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(RituoPalette.white.opacity(0.38))
        }
    }

    private func dot() -> some View {
        Circle()
            .fill(RituoPalette.white.opacity(0.16))
            .frame(width: 3, height: 3)
    }

    // MARK: - Sync status

    @ViewBuilder
    private var syncStatusView: some View {
        if viewModel.isSyncingRituals || viewModel.isLoadingSessionHistories {
            HStack(spacing: 8) {
                ProgressView().tint(RituoPalette.mistBlue).scaleEffect(0.70)
                Text(viewModel.isSyncingRituals ? "Sincronizando…" : "Actualizando métricas…")
                    .font(.system(size: 12))
                    .foregroundStyle(RituoPalette.white.opacity(0.38))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("Sin rituales aún")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.55))

            Text("Creá tu primer ritual para entrenar\ntu foco cada día.")
                .font(.system(size: 13))
                .foregroundStyle(RituoPalette.white.opacity(0.28))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RituoPalette.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
                }
        )
    }

    // MARK: - Create button

    private var createButton: some View {
        Button { isCreateSheetPresented = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Crear un ritual")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(RituoPalette.deepOceanBlue)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RituoPalette.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(LoginPressButtonStyle())
    }

    // MARK: - Computed

    private var allSessions: [RitualSessionResponse] {
        viewModel.schedulers.flatMap { viewModel.sessions(for: $0) }
    }

    private var completedSessionCount: Int {
        allSessions.filter { $0.status == "completed" }.count
    }

    private var focusTotalText: String {
        let mins = allSessions.reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) }
        let h = mins / 60; let m = mins % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(mins)m"
    }
}

// MARK: - Ritual card

struct RitualCard: View {
    let scheduler: RitualScheduler
    let sessions: [RitualSessionResponse]
    let isCurrentlyRunning: Bool
    let isLoadingMetrics: Bool
    let deleteRitual: () -> Void

    @State private var isExpanded = false

    private let weekdayKeys   = [2, 3, 4, 5, 6, 7, 1]
    private let weekdayLabels = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(accentColor.opacity(0.13))
                            Image(systemName: iconName)
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(accentColor)
                        }
                        .frame(width: 46, height: 46)

                        // Title + time
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(scheduler.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(RituoPalette.white)
                                    .lineLimit(1)
                                if scheduler.isProtected {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(RituoPalette.white.opacity(0.28))
                                }
                                if isCurrentlyRunning { ActiveNowBadge() }
                            }
                            Text(scheduler.timeRangeText)
                                .font(.system(size: 12))
                                .foregroundStyle(RituoPalette.white.opacity(0.35))
                        }

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 4) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundStyle(RituoPalette.white.opacity(0.20))
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                .animation(.spring(response: 0.30), value: isExpanded)
                            Text("\(scheduler.durationMinutes)m")
                                .font(.system(size: 12))
                                .foregroundStyle(RituoPalette.white.opacity(0.30))
                        }
                    }

                    Rectangle()
                        .fill(RituoPalette.white.opacity(0.05))
                        .frame(height: 1)

                    // Days + metrics
                    HStack {
                        HStack(spacing: 3) {
                            ForEach(Array(zip(weekdayKeys, weekdayLabels)), id: \.0) { (key, label) in
                                let active = scheduler.weekdays.contains(key)
                                Text(label)
                                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                                    .foregroundStyle(active ? accentColor : RituoPalette.white.opacity(0.16))
                                    .frame(width: 23, height: 23)
                                    .background(active ? accentColor.opacity(0.12) : Color.clear, in: Circle())
                            }
                        }

                        Spacer()

                        if isLoadingMetrics && sessions.isEmpty {
                            RituoLoadingBar(width: 60, height: 9)
                        } else {
                            HStack(spacing: 10) {
                                cardMetric("\(completedSessions)", "checkmark.circle.fill", Color(red: 0.30, green: 0.88, blue: 0.50))
                                cardMetric(focusText, "timer", RituoPalette.lightBlue)
                                cardMetric("\(scheduler.selectedItemCount)", "xmark.app.fill", RituoPalette.white.opacity(0.40))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle()
                    .fill(RituoPalette.white.opacity(0.05))
                    .frame(height: 1)

                VStack(spacing: 0) {
                    ritualConfigurationRow(
                        title: "Apps y sitios bloqueados",
                        status: blockedItemsStatus,
                        systemImage: "square.grid.2x2",
                        isEnabled: scheduler.selectedItemCount > 0
                    )

                    configurationDivider

                    ritualConfigurationRow(
                        title: "Modo estricto",
                        status: scheduler.strictModeEnabled ? "Activado" : "Desactivado",
                        systemImage: "lock.shield.fill",
                        isEnabled: scheduler.strictModeEnabled
                    )

                    configurationDivider

                    ritualConfigurationRow(
                        title: "Bloquear descargas de apps",
                        status: scheduler.blockAppInstallation ? "Activado" : "Desactivado",
                        systemImage: "arrow.down.app.fill",
                        isEnabled: scheduler.blockAppInstallation
                    )

                    configurationDivider

                    ritualConfigurationRow(
                        title: "Bloquear contenido sensible",
                        status: scheduler.blockAdultContent ? "Activado" : "Desactivado",
                        systemImage: "shield.lefthalf.filled",
                        isEnabled: scheduler.blockAdultContent
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

                Rectangle()
                    .fill(RituoPalette.white.opacity(0.05))
                    .frame(height: 1)

                Button(action: deleteRitual) {
                    Label("Eliminar ritual", systemImage: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RituoPalette.danger)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(RituoPalette.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(LoginPressButtonStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isCurrentlyRunning ? accentColor.opacity(0.35) : RituoPalette.white.opacity(0.06),
                            lineWidth: isCurrentlyRunning ? 1.5 : 1
                        )
                }
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .shadow(color: isCurrentlyRunning ? accentColor.opacity(0.16) : .clear, radius: 20)
    }

    private func cardMetric(_ value: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RituoPalette.white.opacity(0.50))
                .monospacedDigit()
        }
    }

    private func ritualConfigurationRow(
        title: String,
        status: String,
        systemImage: String,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(
                    isEnabled
                        ? RituoPalette.lightBlue
                        : RituoPalette.white.opacity(0.24)
                )
                .frame(width: 22)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.82))

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "minus.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text(status)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(
                isEnabled
                    ? RituoPalette.lightBlue
                    : RituoPalette.white.opacity(0.28)
            )
        }
        .padding(.vertical, 10)
    }

    private var configurationDivider: some View {
        Rectangle()
            .fill(RituoPalette.white.opacity(0.05))
            .frame(height: 1)
            .padding(.leading, 42)
    }

    private var blockedItemsStatus: String {
        let count = scheduler.selectedItemCount
        return count == 1 ? "1 elemento" : "\(count) elementos"
    }

    private var accentColor: Color {
        let t = scheduler.title.lowercased()
        if t.contains("lect") || t.contains("read") || t.contains("libro") { return RituoPalette.lightBlue }
        if t.contains("gym") || t.contains("entren") || t.contains("ejerc") { return Color(red: 0.30, green: 0.82, blue: 0.46) }
        if t.contains("med") || t.contains("calma") || t.contains("sleep") || t.contains("noche") { return Color(red: 0.65, green: 0.50, blue: 0.92) }
        if t.contains("work") || t.contains("estud") || t.contains("focus") { return Color(red: 0.96, green: 0.72, blue: 0.32) }
        return Color(red: 0.50, green: 0.70, blue: 1.00)
    }

    private var iconName: String {
        let t = scheduler.title.lowercased()
        if t.contains("gym") || t.contains("entren") || t.contains("ejerc") { return "dumbbell.fill" }
        if t.contains("lect") || t.contains("read") || t.contains("libro") { return "book.closed.fill" }
        if t.contains("med") || t.contains("calma") { return "figure.mind.and.body" }
        if t.contains("sleep") || t.contains("noche") { return "moon.stars.fill" }
        if t.contains("work") || t.contains("estud") { return "laptopcomputer" }
        return scheduler.symbolName
    }

    private var completedSessions: Int { sessions.filter { $0.status == "completed" }.count }

    private var focusText: String {
        let mins = sessions.reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) }
        let h = mins / 60; let m = mins % 60
        if h > 0 { return "\(h)h\(m > 0 ? " \(m)m" : "")" }
        return "\(mins)m"
    }
}

// MARK: - Active now badge

private struct ActiveNowBadge: View {
    @State private var pulses = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(red: 0.30, green: 0.90, blue: 0.52))
                .frame(width: 5, height: 5)
                .scaleEffect(pulses ? 1.35 : 0.85)
            Text("En curso")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(red: 0.30, green: 0.90, blue: 0.52))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.green.opacity(0.11)))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulses = true }
        }
    }
}
