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

    init(viewModel: BlockSetupViewModel, selectedTab: Binding<RootTab>, accessToken: String? = nil) {
        self.viewModel = viewModel
        self._selectedTab = selectedTab
        self.accessToken = accessToken
    }

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    BrandScreenHeader(
                        eyebrow: "Rituales",
                        quote: "No cambias tu vida en un día. Cambias tus días y ahí cambia tu vida."
                    )

                    RitualsOverviewPanel(
                        ritualCount: viewModel.schedulers.count,
                        completedSessions: completedSessionCount,
                        focusMinutes: totalFocusMinutes,
                        isLoading: viewModel.isSyncingRituals || viewModel.isLoadingSessionHistories
                    )

                    syncStatus

                    VStack(spacing: 14) {
                        if viewModel.schedulers.isEmpty {
                            RitualsEmptyState()
                        }

                        if viewModel.isSyncingRituals && viewModel.schedulers.isEmpty {
                            RituoLoadingPanel(title: "Cargando rituales")
                        }

                        ForEach(viewModel.schedulers) { scheduler in
                            RitualListRow(
                                scheduler: scheduler,
                                sessions: viewModel.sessions(for: scheduler),
                                isLoadingMetrics: viewModel.isLoadingSessionHistories,
                                editApps: {
                                    viewModel.selectScheduler(scheduler)
                                    Task {
                                        await viewModel.openActivityPicker()
                                    }
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
                        }
                    }

                    Button {
                        isCreateSheetPresented = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))

                            Text("Crear un ritual")
                                .font(.custom("Helvetica", size: 17).weight(.bold))
                        }
                            .foregroundStyle(RituoPalette.deepOceanBlue)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(.ultraThinMaterial)
                            .background(RituoPalette.white.opacity(0.74))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(RituoPalette.white.opacity(0.82), lineWidth: 1)
                            }
                            .shadow(color: RituoPalette.mistBlue.opacity(0.24), radius: 18, y: 8)
                    }
                    .buttonStyle(LoginPressButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 76)
                .padding(.bottom, 20)
            }
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
        .confirmationDialog(
            "Eliminar ritual",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                guard let scheduler = schedulerPendingDeletion else { return }
                schedulerPendingDeletion = nil
                Task {
                    await viewModel.deleteScheduler(scheduler, accessToken: accessToken)
                }
            }

            Button("Cancelar", role: .cancel) {
                schedulerPendingDeletion = nil
            }
        }
        .alert("Ritual protegido", isPresented: $isProtectedDeletePresented) {
            SecureField("Contraseña", text: $deletionPassword)
                .textContentType(.password)

            Button("Eliminar", role: .destructive) {
                guard let scheduler = schedulerPendingDeletion else { return }
                let password = deletionPassword
                schedulerPendingDeletion = nil
                deletionPassword = ""

                Task {
                    await viewModel.deleteScheduler(
                        scheduler,
                        accessToken: accessToken,
                        password: password
                    )
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

    @ViewBuilder
    private var syncStatus: some View {
        if viewModel.isSyncingRituals || viewModel.isLoadingSessionHistories {
            HStack(spacing: 9) {
                ProgressView()
                    .tint(RituoPalette.mistBlue)
                    .scaleEffect(0.78)

                Text(viewModel.isSyncingRituals ? "Sincronizando rituales" : "Actualizando métricas")
            }
            .font(.custom("Helvetica", size: 12).weight(.bold))
            .foregroundStyle(RituoPalette.white.opacity(0.70))
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let message = viewModel.coreSyncMessage {
            Label(message, systemImage: "checkmark.circle")
                .font(.custom("Helvetica", size: 12).weight(.bold))
                .foregroundStyle(RituoPalette.mistBlue.opacity(0.76))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var allSessions: [RitualSessionResponse] {
        viewModel.schedulers.flatMap { viewModel.sessions(for: $0) }
    }

    private var completedSessionCount: Int {
        allSessions.filter { $0.status == "completed" }.count
    }

    private var totalFocusMinutes: Int {
        allSessions.reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) }
    }
}

struct RitualListRow: View {
    let scheduler: RitualScheduler
    let sessions: [RitualSessionResponse]
    let isLoadingMetrics: Bool
    let editApps: () -> Void
    let deleteRitual: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(RituoPalette.white.opacity(0.09))

                    Image(systemName: iconName)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(RituoPalette.mistBlue)
                }
                .frame(width: 54, height: 54)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.12), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(scheduler.title)
                            .font(.custom("Helvetica", size: 22).weight(.bold))
                            .foregroundStyle(RituoPalette.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        if scheduler.isProtected {
                            Image(systemName: "lock")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(RituoPalette.mistBlue.opacity(0.88))
                                .accessibilityLabel("Ritual protegido")
                        }
                    }

                    Label("\(scheduler.weekdayText) · \(scheduler.timeRangeText)", systemImage: "clock")
                        .font(.custom("Helvetica", size: 12).weight(.semibold))
                        .foregroundStyle(RituoPalette.white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(max(scheduler.selectedItemCount, 0))")
                        .font(.custom("Helvetica", size: 18).weight(.bold))
                        .foregroundStyle(RituoPalette.white)

                    Text("BLOQUEOS")
                        .font(.custom("Helvetica", size: 8).weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(RituoPalette.white.opacity(0.46))
                }
            }

            HStack(spacing: 8) {
                if isLoadingMetrics && sessions.isEmpty {
                    RitualMetricLoadingChip(label: "sesiones")
                    RitualMetricLoadingChip(label: "foco")
                    RitualMetricLoadingChip(label: "última")
                } else {
                    RitualMetricChip(value: "\(completedSessions)", label: "sesiones")
                    RitualMetricChip(value: "\(focusMinutes)m", label: "foco")
                    RitualMetricChip(value: lastSessionText, label: "última")
                }
            }

            HStack(spacing: 8) {
                Button(action: editApps) {
                    Label("Apps", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(RitualGlassActionButtonStyle())

                Button(action: deleteRitual) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(RituoPalette.danger)
                        .frame(width: 46, height: 44)
                }
                .buttonStyle(RitualGlassActionButtonStyle())
            }
            .font(.custom("Helvetica", size: 13).weight(.bold))
            .foregroundStyle(RituoPalette.lightBlue)
        }
        .padding(16)
        .background(RitualGlassCardBackground(isSelected: false))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    RituoPalette.white.opacity(0.10),
                    lineWidth: 1
                )
        }
    }

    private var completedSessions: Int {
        sessions.filter { $0.status == "completed" }.count
    }

    private var focusMinutes: Int {
        sessions.reduce(0) { total, session in
            total + ((session.durationSeconds ?? 0) / 60)
        }
    }

    private var lastSessionText: String {
        let finishedSessions = sessions.filter { $0.status != "active" }
        guard let last = finishedSessions.sorted(by: { $0.startedAt > $1.startedAt }).first else {
            return "-"
        }

        return Self.shortDateText(from: last.startedAt)
    }

    private static func shortDateText(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: isoString) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: isoString)
        }()
        guard let date else { return "-" }

        let output = DateFormatter()
        output.locale = Locale(identifier: "es_AR")
        output.dateFormat = "d MMM"
        return output.string(from: date).lowercased()
    }

    private var iconName: String {
        let title = scheduler.title.lowercased()
        if title.contains("gym") || title.contains("entren") { return "dumbbell" }
        if title.contains("lect") || title.contains("read") { return "book.closed.fill" }
        return scheduler.symbolName
    }
}


struct RitualMetricChip: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.custom("Helvetica", size: 15).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.custom("Helvetica", size: 9).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(0.52))
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RituoPalette.white.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.07), lineWidth: 1)
                }
        )
    }
}

struct RitualMetricLoadingChip: View {
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            RituoLoadingBar(width: 34, height: 11)

            Text(label)
                .font(.custom("Helvetica", size: 9).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(0.42))
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RituoPalette.white.opacity(0.08))
        )
    }
}

private struct RitualsOverviewPanel: View {
    let ritualCount: Int
    let completedSessions: Int
    let focusMinutes: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 10) {
            overviewItem(value: "\(ritualCount)", label: "rituales", symbol: "sparkles")
            overviewItem(value: "\(completedSessions)", label: "hechas", symbol: "checkmark")
            overviewItem(value: "\(focusMinutes)m", label: "foco", symbol: "timer")
        }
        .padding(10)
        .background(RitualGlassCardBackground(isSelected: false))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.11), lineWidth: 1)
        }
        .opacity(isLoading ? 0.74 : 1)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    private func overviewItem(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RituoPalette.mistBlue.opacity(0.88))

            Text(value)
                .font(.custom("Helvetica", size: 18).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label.uppercased())
                .font(.custom("Helvetica", size: 8).weight(.bold))
                .tracking(0.7)
                .foregroundStyle(RituoPalette.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RituoPalette.white.opacity(0.055))
        )
    }
}

private struct RitualsEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(RituoPalette.mistBlue)
                .frame(width: 58, height: 58)
                .background(Circle().fill(RituoPalette.white.opacity(0.08)))

            Text("Tu primer ritual empieza acá")
                .font(.custom("Helvetica", size: 20).weight(.bold))
                .foregroundStyle(RituoPalette.white)

            Text("Elegí un horario y las apps que querés dejar afuera mientras te enfocás.")
                .font(.custom("Helvetica", size: 13).weight(.medium))
                .foregroundStyle(RituoPalette.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(RitualGlassCardBackground(isSelected: false))
    }
}

private struct RitualGlassCardBackground: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RituoPalette.glassBlue.opacity(isSelected ? 0.86 : 0.74),
                                RituoPalette.inkBlue.opacity(isSelected ? 0.93 : 0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Color.black.opacity(0.20), radius: 18, y: 10)
            .shadow(color: isSelected ? RituoPalette.mistBlue.opacity(0.12) : .clear, radius: 18)
    }
}

private struct RitualGlassActionButtonStyle: ButtonStyle {
    var isEmphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEmphasized ? RituoPalette.white : RituoPalette.mistBlue)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        isEmphasized
                        ? RituoPalette.darkCanteen.opacity(0.70)
                        : RituoPalette.white.opacity(0.055)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(RituoPalette.white.opacity(isEmphasized ? 0.14 : 0.06), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.76), value: configuration.isPressed)
    }
}
