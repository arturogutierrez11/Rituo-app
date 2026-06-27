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
        ZStack {
            RituoAnimatedBackground()

            VStack(spacing: 0) {
                pageHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        overviewStrip
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)

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
                                editApps: {
                                    viewModel.selectScheduler(scheduler)
                                    Task { await viewModel.openActivityPicker() }
                                },
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
                            .offset(y: appeared ? 0 : 16)
                            .animation(
                                .spring(response: 0.50, dampingFraction: 0.84)
                                    .delay(0.06 + Double(index) * 0.06),
                                value: appeared
                            )
                        }

                        createButton
                            .opacity(appeared ? 1 : 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
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
                await viewModel.loadRitualSessionHistories(accessToken: accessToken)
            }
        }
        .confirmationDialog("Eliminar ritual", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                guard let scheduler = schedulerPendingDeletion else { return }
                schedulerPendingDeletion = nil
                Task { await viewModel.deleteScheduler(scheduler, accessToken: accessToken) }
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
                Task { await viewModel.deleteScheduler(scheduler, accessToken: accessToken, password: password) }
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("RITUALES")
                    .font(.custom("Helvetica", size: 10).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(RituoPalette.mistBlue.opacity(0.68))
                Text("Mis rituales")
                    .font(.custom("Helvetica", size: 28).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
            }
            Spacer()
            if !viewModel.schedulers.isEmpty {
                Text("\(viewModel.schedulers.count)")
                    .font(.custom("Helvetica", size: 14).weight(.bold))
                    .foregroundStyle(RituoPalette.white.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(RituoPalette.white.opacity(0.10)))
                    .overlay(Circle().stroke(RituoPalette.white.opacity(0.10), lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 62)
        .padding(.bottom, 16)
    }

    // MARK: - Overview strip

    private var overviewStrip: some View {
        HStack(spacing: 0) {
            RitualStatCell(value: "\(completedSessionCount)", label: "Completadas", symbol: "checkmark.circle.fill", tint: Color.green)
            Rectangle().fill(RituoPalette.white.opacity(0.08)).frame(width: 1, height: 28)
            RitualStatCell(value: focusTotalText, label: "Foco total", symbol: "timer", tint: RituoPalette.lightBlue)
            Rectangle().fill(RituoPalette.white.opacity(0.08)).frame(width: 1, height: 28)
            RitualStatCell(value: "\(viewModel.schedulers.count)", label: "Rituales", symbol: "bolt.fill", tint: Color.orange)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.18, green: 0.24, blue: 0.38), Color(red: 0.10, green: 0.13, blue: 0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.20), radius: 14, y: 6)
    }

    // MARK: - Sync status

    @ViewBuilder
    private var syncStatusView: some View {
        if viewModel.isSyncingRituals || viewModel.isLoadingSessionHistories {
            HStack(spacing: 8) {
                ProgressView().tint(RituoPalette.mistBlue).scaleEffect(0.74)
                Text(viewModel.isSyncingRituals ? "Sincronizando rituales…" : "Actualizando métricas…")
                    .font(.custom("Helvetica", size: 12).weight(.semibold))
                    .foregroundStyle(RituoPalette.white.opacity(0.50))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
        } else if let message = viewModel.coreSyncMessage {
            Label(message, systemImage: "checkmark.circle")
                .font(.custom("Helvetica", size: 12).weight(.semibold))
                .foregroundStyle(RituoPalette.mistBlue.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.20, green: 0.28, blue: 0.42), Color(red: 0.12, green: 0.16, blue: 0.28)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 96, height: 96)
                Circle()
                    .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Image(systemName: "bolt")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(RituoPalette.lightBlue.opacity(0.80))
            }

            VStack(spacing: 8) {
                Text("Tu primer ritual empieza acá")
                    .font(.custom("Helvetica", size: 22).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .multilineTextAlignment(.center)

                Text("Creá un ritual con horario y apps bloqueadas\npara entrenar tu foco.")
                    .font(.custom("Helvetica", size: 14).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.18, green: 0.24, blue: 0.38), Color(red: 0.10, green: 0.13, blue: 0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.09), lineWidth: 1)
        }
    }

    // MARK: - Create button

    private var createButton: some View {
        Button { isCreateSheetPresented = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(RituoPalette.deepOceanBlue.opacity(0.14)).frame(width: 30, height: 30)
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(RituoPalette.deepOceanBlue)
                }
                Text("Crear un ritual")
                    .font(.custom("Helvetica", size: 17).weight(.bold))
                    .foregroundStyle(RituoPalette.deepOceanBlue)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RituoPalette.white)
            .clipShape(Capsule())
            .shadow(color: RituoPalette.white.opacity(0.22), radius: 20, x: 0, y: 8)
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

// MARK: - Stat cell

private struct RitualStatCell: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.custom("Helvetica", size: 18).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label.uppercased())
                .font(.custom("Helvetica", size: 8).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(RituoPalette.white.opacity(0.38))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ritual card

struct RitualCard: View {
    let scheduler: RitualScheduler
    let sessions: [RitualSessionResponse]
    let isCurrentlyRunning: Bool
    let isLoadingMetrics: Bool
    let editApps: () -> Void
    let deleteRitual: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(spacing: 0) {
                    // Top section: icon + info + time
                    HStack(spacing: 14) {
                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accentColor.opacity(0.20))
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(accentColor.opacity(0.32), lineWidth: 1)
                            Image(systemName: iconName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                        .frame(width: 54, height: 54)

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                Text(scheduler.title)
                                    .font(.custom("Helvetica", size: 18).weight(.bold))
                                    .foregroundStyle(RituoPalette.white)
                                    .lineLimit(1)

                                if scheduler.isProtected {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(RituoPalette.mistBlue.opacity(0.70))
                                }

                                if isCurrentlyRunning {
                                    ActiveNowBadge()
                                }
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(RituoPalette.white.opacity(0.38))
                                Text(scheduler.timeRangeText)
                                    .font(.custom("Helvetica", size: 12).weight(.semibold))
                                    .foregroundStyle(RituoPalette.white.opacity(0.50))
                            }
                        }

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 5) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(RituoPalette.white.opacity(0.28))

                            Text("\(scheduler.durationMinutes)m")
                                .font(.custom("Helvetica", size: 12).weight(.bold))
                                .foregroundStyle(accentColor.opacity(0.80))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                    // Divider
                    Rectangle()
                        .fill(RituoPalette.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 18)

                    // Bottom section: days + stats
                    HStack(spacing: 0) {
                        // Day pills
                        HStack(spacing: 4) {
                            ForEach(Array(zip(weekdayKeys, weekdayLabels)), id: \.0) { (key, label) in
                                let isActive = scheduler.weekdays.contains(key)
                                Text(label)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isActive ? accentColor : RituoPalette.white.opacity(0.22))
                                    .frame(width: 26, height: 26)
                                    .background(
                                        Circle()
                                            .fill(isActive ? accentColor.opacity(0.18) : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(isActive ? accentColor.opacity(0.30) : RituoPalette.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                        }

                        Spacer()

                        // Metrics
                        if isLoadingMetrics && sessions.isEmpty {
                            RituoLoadingBar(width: 80, height: 12)
                        } else {
                            HStack(spacing: 12) {
                                CardStat(value: "\(completedSessions)", symbol: "checkmark.circle.fill", tint: Color.green)
                                CardStat(value: focusText, symbol: "timer", tint: RituoPalette.lightBlue)
                                CardStat(value: "\(scheduler.selectedItemCount)", symbol: "xmark.app.fill", tint: RituoPalette.mistBlue)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
            .buttonStyle(.plain)

            // Expanded actions
            if isExpanded {
                Rectangle()
                    .fill(RituoPalette.white.opacity(0.06))
                    .frame(height: 1)

                HStack(spacing: 10) {
                    Button(action: editApps) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 13, weight: .bold))
                            Text("Editar apps")
                                .font(.custom("Helvetica", size: 14).weight(.bold))
                        }
                        .foregroundStyle(RituoPalette.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RituoPalette.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(LoginPressButtonStyle())

                    Button(action: deleteRitual) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .bold))
                            Text("Eliminar")
                                .font(.custom("Helvetica", size: 14).weight(.bold))
                        }
                        .foregroundStyle(RituoPalette.danger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RituoPalette.danger.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(LoginPressButtonStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(cardBorder)
        .shadow(color: Color.black.opacity(0.20), radius: 16, y: 6)
        .shadow(color: isCurrentlyRunning ? accentColor.opacity(0.16) : .clear, radius: 20)
    }

    private let weekdayKeys = [2, 3, 4, 5, 6, 7, 1]
    private let weekdayLabels = ["L", "M", "M", "J", "V", "S", "D"]

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.18, green: 0.24, blue: 0.38), Color(red: 0.10, green: 0.13, blue: 0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            if isCurrentlyRunning {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(RadialGradient(
                        colors: [accentColor.opacity(0.16), Color.clear],
                        center: .topLeading, startRadius: 0, endRadius: 180
                    ))
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                isCurrentlyRunning ? accentColor.opacity(0.44) : RituoPalette.white.opacity(0.09),
                lineWidth: isCurrentlyRunning ? 1.5 : 1
            )
    }

    private var accentColor: Color {
        let t = scheduler.title.lowercased()
        if t.contains("lect") || t.contains("read") || t.contains("libro") { return RituoPalette.lightBlue }
        if t.contains("gym") || t.contains("entren") || t.contains("ejerc") { return Color(red: 0.30, green: 0.82, blue: 0.46) }
        if t.contains("med") || t.contains("calma") || t.contains("sleep") || t.contains("noche") { return Color(red: 0.62, green: 0.48, blue: 0.90) }
        if t.contains("work") || t.contains("estud") || t.contains("focus") { return Color(red: 0.96, green: 0.72, blue: 0.32) }
        return RituoPalette.mistBlue
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

// MARK: - Card stat (inline icon + value)

private struct CardStat: View {
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.custom("Helvetica", size: 12).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(0.72))
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

// MARK: - Active now badge

private struct ActiveNowBadge: View {
    @State private var pulses = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(red: 0.30, green: 0.90, blue: 0.50))
                .frame(width: 6, height: 6)
                .scaleEffect(pulses ? 1.3 : 0.9)
                .shadow(color: Color.green.opacity(0.60), radius: pulses ? 4 : 2)
            Text("En curso")
                .font(.custom("Helvetica", size: 10).weight(.bold))
                .foregroundStyle(Color(red: 0.30, green: 0.90, blue: 0.50))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.green.opacity(0.14)))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulses = true }
        }
    }
}

// MARK: - Metric pill (kept for compatibility)

private struct MetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.custom("Helvetica", size: 15).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.custom("Helvetica", size: 8).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(RituoPalette.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(RituoPalette.white.opacity(0.07)))
    }
}

// MARK: - Overview chip (kept for compatibility)

private struct RitualOverviewChip: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint.opacity(0.82))
            Text(value).font(.custom("Helvetica", size: 17).weight(.bold)).foregroundStyle(RituoPalette.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased()).font(.custom("Helvetica", size: 8).weight(.bold)).tracking(0.6).foregroundStyle(RituoPalette.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(RituoPalette.white.opacity(0.08)))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(RituoPalette.white.opacity(0.08), lineWidth: 1) }
    }
}
