import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct IntroRitualView: View {
    @State private var animates = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    RituoPalette.background,
                    RituoPalette.panel,
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(RituoPalette.glow.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .scaleEffect(animates ? 1.12 : 0.86)

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .strokeBorder(RituoPalette.stroke.opacity(0.65), lineWidth: 1)
                        .frame(width: 150, height: 150)

                    Circle()
                        .fill(RituoPalette.glow.opacity(0.12))
                        .frame(width: 118, height: 118)

                    Image("RituoLogoWhite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78)
                }
                .shadow(color: RituoPalette.glow.opacity(0.28), radius: 28, y: 12)

                Text("Respira. Deja caer el ruido.\nEmpieza el foco.")
                    .font(.custom("Helvetica", size: 18).weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RituoPalette.subtext)

                Capsule()
                    .fill(RituoPalette.glow)
                    .frame(width: animates ? 132 : 42, height: 4)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animates)
            }
            .padding(30)
        }
        .onAppear {
            animates = true
        }
    }
}

struct RitualDashboardPage: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let accessToken: String?
    @State private var isCreateSheetPresented = false
    @State private var isRitualPickerPresented = false

    init(viewModel: BlockSetupViewModel, accessToken: String? = nil) {
        self.viewModel = viewModel
        self.accessToken = accessToken
    }

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    homeHeader
                    HomeMetricsStrip(
                        summary: viewModel.ritualSessionSummary,
                        isLoading: viewModel.isLoadingSessionSummary,
                        currentMinutes: activeElapsedMinutes,
                        isActive: viewModel.isBlocking
                    )
                    .padding(.top, 30)

                    if viewModel.isBlocking {
                        activeRitualView
                    } else {
                        inactiveRitualView
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $isCreateSheetPresented) {
            SchedulerComposerSheet(viewModel: viewModel, accessToken: accessToken)
        }
        .sheet(isPresented: $isRitualPickerPresented) {
            RitualStartSheet(
                viewModel: viewModel,
                createRitual: {
                    isRitualPickerPresented = false
                    isCreateSheetPresented = true
                }
            )
        }
    }

    private var homeHeader: some View {
        Image("RituoLogoWhite")
            .resizable()
            .scaledToFit()
            .frame(width: 142)
            .frame(maxWidth: .infinity)
    }

    private var inactiveRitualView: some View {
        VStack(spacing: 0) {
            HomeInactiveStatusCard()
                .padding(.top, 78)

            HomePrimaryButton(
                title: "selecciona un ritual o una app",
                showsMark: false
            ) {
                isRitualPickerPresented = true
            }
            .padding(.horizontal, 18)
            .padding(.top, 34)
        }
    }

    @ViewBuilder
    private var activeRitualView: some View {
        let scheduler = viewModel.currentBlockingScheduler ?? viewModel.activeScheduler

        VStack(spacing: 0) {
            ActiveRitualTimerCard(
                progress: activeProgress(for: scheduler),
                remainingMinutes: activeRemainingMinutes,
                title: scheduler?.title ?? "Ritual activo",
                timeRange: scheduler?.timeRangeText ?? "En curso"
            )
            .padding(.top, 54)

            Button {
                viewModel.endBlockWithVerifiedTag(accessToken: accessToken)
            } label: {
                Text(viewModel.isReadingTag ? "Leyendo tag..." : "Finalizar ritual")
                    .font(.custom("Helvetica", size: 16).weight(.bold))
                    .foregroundStyle(RituoPalette.deepOceanBlue)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.92, green: 0.90, blue: 0.90))
                    )
                    .overlay {
                        Capsule()
                            .stroke(RituoPalette.white.opacity(0.48), lineWidth: 1)
                    }
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(viewModel.isReadingTag)
            .padding(.horizontal, 18)
            .padding(.top, 34)
        }
    }

    private var activeRemainingMinutes: Int {
        guard let blockedUntil = viewModel.blockedUntil else { return 0 }
        return max(0, Int(ceil(blockedUntil.timeIntervalSinceNow / 60)))
    }

    private var activeElapsedMinutes: Int {
        guard
            viewModel.isBlocking,
            let scheduler = viewModel.currentBlockingScheduler ?? viewModel.activeScheduler
        else {
            return 0
        }

        return max(0, scheduler.durationMinutes - activeRemainingMinutes)
    }

    private func activeProgress(for scheduler: RitualScheduler?) -> Double {
        guard let scheduler, scheduler.durationMinutes > 0 else { return 0 }
        return min(
            1,
            max(0, Double(activeRemainingMinutes) / Double(scheduler.durationMinutes))
        )
    }

}


struct HomeMetricsStrip: View {
    let summary: RitualSessionSummaryResponse?
    let isLoading: Bool
    let currentMinutes: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                HomeMetricLoadingPill(label: "foco")
                HomeMetricLoadingPill(label: "hechas")
                HomeMetricLoadingPill(label: "racha")
            } else {
                HomeMetricPill(value: "\(summary?.totalFocusMinutes ?? 0)m", label: "foco")
                HomeMetricPill(
                    value: isActive ? "\(currentMinutes)m" : "\(summary?.completedSessions ?? 0)",
                    label: isActive ? "actual" : "hechas"
                )
                HomeMetricPill(value: "\(summary?.currentStreakDays ?? 0)d", label: "racha")
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isLoading)
    }
}

struct HomeMetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Helvetica", size: 18).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .monospacedDigit()

            Text(label)
                .font(.custom("Helvetica", size: 10).weight(.semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(HomeDarkCardBackground(cornerRadius: 20))
    }
}

struct HomeMetricLoadingPill: View {
    let label: String

    var body: some View {
        VStack(spacing: 7) {
            RituoLoadingBar(width: 42, height: 14)

            Text(label)
                .font(.custom("Helvetica", size: 10).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(0.48))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(HomeDarkCardBackground(cornerRadius: 14))
    }
}

struct HomeInactiveStatusCard: View {
    var body: some View {
        VStack(spacing: 32) {
            RituoEmptyOrb()

            VStack(spacing: 7) {
                Text("No hay ritual activo")
                    .font(.custom("Helvetica", size: 26).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                Text("Elegí un ritual para empezar a enfocarte")
                    .font(.custom("Helvetica", size: 14).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.58))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct RituoEmptyOrb: View {
    @State private var rotates = false
    @State private var breathes = false
    @State private var sweeps = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            RituoPalette.white.opacity(breathes ? 0.18 : 0.09),
                            RituoPalette.lightBlue.opacity(breathes ? 0.16 : 0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 70,
                        endRadius: 144
                    )
                )
                .frame(width: 278, height: 278)
                .blur(radius: 18)
                .scaleEffect(breathes ? 1.05 : 0.96)

            ForEach(0 ..< 4, id: \.self) { index in
                Circle()
                    .stroke(
                        RituoPalette.mistBlue.opacity(0.12 - Double(index) * 0.018),
                        lineWidth: 1
                    )
                    .frame(
                        width: CGFloat(206 + index * 13),
                        height: CGFloat(206 + index * 13)
                    )
            }

            Circle()
                .stroke(RituoPalette.white.opacity(0.94), lineWidth: 4)
                .frame(width: 202, height: 202)
                .shadow(color: RituoPalette.white.opacity(0.82), radius: breathes ? 18 : 10)
                .shadow(color: RituoPalette.lightBlue.opacity(0.78), radius: breathes ? 34 : 22)

            Circle()
                .trim(from: 0.04, to: 0.24)
                .stroke(
                    LinearGradient(
                        colors: [
                            RituoPalette.white,
                            RituoPalette.mistBlue.opacity(0.88),
                            RituoPalette.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 202, height: 202)
                .rotationEffect(.degrees(rotates ? 360 : 0))
                .shadow(color: RituoPalette.white.opacity(0.92), radius: 15)

            Circle()
                .trim(from: 0.70, to: 0.88)
                .stroke(
                    RituoPalette.lightBlue.opacity(0.55),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 238, height: 238)
                .rotationEffect(.degrees(sweeps ? -360 : 0))

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(RituoPalette.lightBlue.opacity(0.40))
        }
        .frame(height: 276)
        .onAppear {
            rotates = true
            breathes = true
            sweeps = true
        }
        .animation(.linear(duration: 8.5).repeatForever(autoreverses: false), value: rotates)
        .animation(.linear(duration: 13).repeatForever(autoreverses: false), value: sweeps)
        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: breathes)
    }
}

struct HomePrimaryButton: View {
    let title: String
    var showsMark = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.custom("Helvetica", size: showsMark ? 23 : 16).weight(.bold))
                    .tracking(showsMark ? 0 : 0.4)

                if showsMark {
                    RituoPulseMark()
                        .scaleEffect(0.70)
                }
            }
            .foregroundStyle(RituoPalette.deepOceanBlue)
            .frame(maxWidth: .infinity, minHeight: showsMark ? 62 : 58)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.90, blue: 0.88),
                        Color(red: 0.85, green: 0.80, blue: 0.79)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(RituoPalette.white.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: RituoPalette.deepOceanBlue.opacity(0.24), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(LoginPressButtonStyle())
    }
}

struct HomeSchedulerRow: View {
    let scheduler: RitualScheduler
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: schedulerIcon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(RituoPalette.lightBlue)
                .frame(width: 58, height: 58)
                .background(Circle().fill(RituoPalette.lightBlue.opacity(0.12)))
                .overlay { Circle().stroke(RituoPalette.lightBlue.opacity(0.26), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 6) {
                Text(scheduler.title)
                    .font(.custom("Helvetica", size: 19).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                Text("\(scheduler.weekdayText) · \(scheduler.timeRangeText)")
                    .font(.custom("Helvetica", size: 13).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.62))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    BlockedAppIcon(kind: .instagram, size: 24)
                    BlockedAppIcon(kind: .tiktok, size: 24)
                    Text("+\(max(scheduler.selectedItemCount - 2, 0))")
                        .font(.custom("Helvetica", size: 12).weight(.bold))
                        .foregroundStyle(RituoPalette.white.opacity(0.82))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(RituoPalette.white.opacity(0.86))
        }
        .padding(14)
        .background(HomeDarkCardBackground(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? RituoPalette.lightBlue.opacity(0.8) : Color.clear, lineWidth: 1.5)
        }
        .scaleEffect(isSelected ? 1.015 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isSelected)
    }

    private var schedulerIcon: String {
        let title = scheduler.title.lowercased()
        if title.contains("gym") || title.contains("entren") { return "dumbbell" }
        if title.contains("lect") || title.contains("read") { return "book" }
        return scheduler.symbolName
    }
}

struct ActiveRitualTimerCard: View {
    let progress: Double
    let remainingMinutes: Int
    let title: String
    let timeRange: String
    @State private var breathes = false

    var body: some View {
        VStack(spacing: 34) {
            ZStack {
                Circle()
                    .fill(RituoPalette.lightBlue.opacity(breathes ? 0.15 : 0.08))
                    .frame(width: 290, height: 290)
                    .blur(radius: 32)
                    .scaleEffect(breathes ? 1.04 : 0.96)

                ForEach(0 ..< 5, id: \.self) { index in
                    Circle()
                        .stroke(
                            RituoPalette.mistBlue.opacity(0.15 - Double(index) * 0.02),
                            lineWidth: 1
                        )
                        .frame(
                            width: CGFloat(220 + index * 14),
                            height: CGFloat(220 + index * 14)
                        )
                }

                Circle()
                    .stroke(RituoPalette.white.opacity(0.20), lineWidth: 3)
                    .frame(width: 210, height: 210)

                Circle()
                    .trim(from: 0, to: max(progress, 0.012))
                    .stroke(
                        LinearGradient(
                            colors: [
                                RituoPalette.white,
                                RituoPalette.lightBlue,
                                RituoPalette.white.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: RituoPalette.white.opacity(0.58), radius: 8)
                    .shadow(color: RituoPalette.lightBlue.opacity(0.64), radius: 18)

                VStack(spacing: 6) {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.custom("Helvetica", size: 44).weight(.bold))
                        .foregroundStyle(RituoPalette.white)
                        .monospacedDigit()

                    Text("\(remainingMinutes) min")
                        .font(.custom("Helvetica", size: 16).weight(.semibold))
                        .foregroundStyle(RituoPalette.white.opacity(0.66))
                }
            }
            .frame(height: 292)

            VStack(spacing: 7) {
                Text(title)
                    .font(.custom("Helvetica", size: 28).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text("Ritual activo · \(timeRange)")
                    .font(.custom("Helvetica", size: 14).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { breathes = true }
        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: breathes)
        .animation(.easeInOut(duration: 0.7), value: progress)
    }
}

struct ActiveRitualDetailCard: View {
    let scheduler: RitualScheduler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detalle del ritual")
                .font(.custom("Helvetica", size: 13).weight(.bold))
                .tracking(1.1)
                .foregroundStyle(RituoPalette.white.opacity(0.62))

            HStack(spacing: 14) {
                Image(systemName: schedulerIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(RituoPalette.lightBlue)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(RituoPalette.lightBlue.opacity(0.12)))
                    .overlay { Circle().stroke(RituoPalette.lightBlue.opacity(0.28), lineWidth: 1) }

                VStack(alignment: .leading, spacing: 7) {
                    Text(scheduler.title)
                        .font(.custom("Helvetica", size: 20).weight(.bold))
                        .foregroundStyle(RituoPalette.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(scheduler.focusTarget)
                        .font(.custom("Helvetica", size: 14).weight(.semibold))
                        .foregroundStyle(RituoPalette.white.opacity(0.70))
                        .lineLimit(2)

                    Text("\(scheduler.weekdayText) · \(scheduler.timeRangeText)")
                        .font(.custom("Helvetica", size: 12).weight(.bold))
                        .foregroundStyle(RituoPalette.lightBlue)
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                ActiveRitualMetric(value: "\(scheduler.durationMinutes)m", label: "Duración")
                ActiveRitualMetric(value: "\(scheduler.selectedItemCount)", label: "Bloqueos")
                ActiveRitualMetric(value: scheduler.weekdayText, label: "Días")
            }
        }
        .padding(18)
        .background(HomeDarkCardBackground(cornerRadius: 20))
    }

    private var schedulerIcon: String {
        let title = scheduler.title.lowercased()
        if title.contains("gym") || title.contains("entren") { return "dumbbell" }
        if title.contains("lect") || title.contains("read") { return "book.closed" }
        return scheduler.symbolName
    }
}

struct ActiveBlockedAppsCard: View {
    let scheduler: RitualScheduler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Bloqueos activos")
                    .font(.custom("Helvetica", size: 13).weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(RituoPalette.white.opacity(0.62))

                Spacer()

                Text(scheduler.selectionDigest)
                    .font(.custom("Helvetica", size: 12).weight(.bold))
                    .foregroundStyle(RituoPalette.lightBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(blockedRows) { row in
                    ActiveBlockedItemTile(row: row)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12, weight: .bold))
                Text("Selección privada de Screen Time")
                    .font(.custom("Helvetica", size: 12).weight(.bold))
            }
            .foregroundStyle(RituoPalette.mistBlue.opacity(0.68))
        }
        .padding(18)
        .background(HomeDarkCardBackground(cornerRadius: 20))
    }

    private var blockedRows: [ActiveBlockedItemRow] {
        var rows: [ActiveBlockedItemRow] = []

        rows += (0..<scheduler.appCount).map { index in
            ActiveBlockedItemRow(title: "App \(index + 1)", subtitle: "Aplicación", symbol: "app.badge", tint: RituoPalette.lightBlue)
        }

        rows += (0..<scheduler.categoryCount).map { index in
            ActiveBlockedItemRow(title: "Categoría \(index + 1)", subtitle: "Categoría", symbol: "square.grid.2x2", tint: RituoPalette.glow)
        }

        rows += (0..<scheduler.domainCount).map { index in
            ActiveBlockedItemRow(title: "Web \(index + 1)", subtitle: "Dominio", symbol: "globe", tint: RituoPalette.success)
        }

        if rows.isEmpty {
            rows.append(ActiveBlockedItemRow(title: "Sin detalle", subtitle: "Sin selección local", symbol: "slash.circle", tint: RituoPalette.white.opacity(0.54)))
        }

        return rows
    }
}

struct ActiveBlockedItemRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
}

struct ActiveBlockedItemTile: View {
    let row: ActiveBlockedItemRow

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: row.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(row.tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(row.tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.custom("Helvetica", size: 12).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(row.subtitle)
                    .font(.custom("Helvetica", size: 9).weight(.bold))
                    .foregroundStyle(RituoPalette.white.opacity(0.50))
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RituoPalette.white.opacity(0.07))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
        }
    }
}
struct ActiveRitualMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.custom("Helvetica", size: 15).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(label)
                .font(.custom("Helvetica", size: 10).weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(RituoPalette.white.opacity(0.50))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RituoPalette.white.opacity(0.07))
        )
    }
}

struct ActiveBlockedCountBadge: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.custom("Helvetica", size: 18).weight(.bold))
            .foregroundStyle(RituoPalette.white)
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RituoPalette.white.opacity(0.10))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(RituoPalette.white.opacity(0.12), lineWidth: 1)
            }
    }
}

struct HomeActiveSchedulerCard: View {
    let scheduler: RitualScheduler

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "book")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(RituoPalette.lightBlue)
                .frame(width: 64, height: 64)
                .background(Circle().fill(RituoPalette.lightBlue.opacity(0.12)))
                .overlay { Circle().stroke(RituoPalette.lightBlue.opacity(0.26), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 6) {
                Text(scheduler.title)
                    .font(.custom("Helvetica", size: 19).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                Text("\(scheduler.weekdayText) · \(scheduler.timeRangeText)")
                    .font(.custom("Helvetica", size: 13).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.62))

                Text("Apps bloqueadas: \(max(scheduler.selectedItemCount, 5))")
                    .font(.custom("Helvetica", size: 13).weight(.bold))
                    .foregroundStyle(RituoPalette.lightBlue)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(RituoPalette.white.opacity(0.86))
        }
        .padding(16)
        .background(HomeDarkCardBackground(cornerRadius: 18))
    }
}

struct HomeStopRitualCard: View {
    let isReadingTag: Bool

    var body: some View {
        HStack(spacing: 16) {
            RituoPulseMark()
                .scaleEffect(0.68)
                .frame(width: 50, height: 50)
                .background(Circle().fill(RituoPalette.lightBlue.opacity(0.10)))
                .overlay { Circle().stroke(RituoPalette.lightBlue.opacity(0.30), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 6) {
                Text(isReadingTag ? "leyendo tag..." : "detener con NFC")
                    .font(.custom("Helvetica", size: 15).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                Text("Acercá tu tag para liberar las apps.")
                    .font(.custom("Helvetica", size: 12).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.58))
                    .lineSpacing(2)
                    .lineLimit(2)
            }

            Spacer()

            if isReadingTag {
                ProgressView()
                    .tint(RituoPalette.mistBlue)
            } else {
                Image(systemName: "lock")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(RituoPalette.mistBlue.opacity(0.70))
            }
        }
        .padding(14)
        .background(HomeDarkCardBackground(cornerRadius: 22))
    }
}

struct RituoCrystalLamp: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(RituoPalette.lightBlue.opacity(0.28))
                .frame(width: 190, height: 190)
                .blur(radius: 30)
                .offset(y: -8)

            Image(systemName: "diamond.fill")
                .font(.system(size: 120, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [RituoPalette.lightBlue, .cyan, .yellow.opacity(0.72), .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: RituoPalette.lightBlue.opacity(0.8), radius: 26)
                .offset(y: -18)

            Capsule()
                .fill(Color.black.opacity(0.78))
                .frame(width: 70, height: 22)
        }
        .frame(width: 210, height: 210)
    }
}

struct BlockedAppIcon: View {
    enum Kind {
        case instagram
        case tiktok
        case youtube
        case x
        case spotify
    }

    let kind: Kind
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.20, style: .continuous)
                .fill(background)
                .frame(width: size, height: size)

            Text(label)
                .font(.system(size: size * 0.50, weight: .black, design: .rounded))
                .foregroundStyle(RituoPalette.white)
        }
        .padding(size * 0.16)
        .background(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(Color.black.opacity(0.20)))
    }

    private var label: String {
        switch kind {
        case .instagram: return "◎"
        case .tiktok: return "♪"
        case .youtube: return "▶"
        case .x: return "𝕏"
        case .spotify: return "≋"
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .instagram:
            return AnyShapeStyle(LinearGradient(colors: [.pink, .orange, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .tiktok, .x:
            return AnyShapeStyle(Color.black)
        case .youtube:
            return AnyShapeStyle(Color.red)
        case .spotify:
            return AnyShapeStyle(Color.green)
        }
    }
}

struct HomeDarkCardBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                        LinearGradient(
                            colors: [
                        RituoPalette.glassBlue.opacity(0.88),
                        RituoPalette.inkBlue.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                RituoPalette.mistBlue.opacity(0.22),
                                RituoPalette.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: RituoPalette.inkBlue.opacity(0.18), radius: 14, y: 7)
    }
}

struct RitualStartSheet: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let createRitual: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(RituoPalette.white.opacity(0.26))
                    .frame(width: 64, height: 6)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)

                Text("Rituales programados")
                    .font(.custom("Helvetica", size: 28).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                Text("Los rituales se activan solos en su horario. Desde acá podés crear uno nuevo o ajustar la selección de apps.")
                    .font(.custom("Helvetica", size: 14).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.68))
                    .lineSpacing(3)

                Button {
                    Task {
                        await viewModel.openActivityPicker()
                    }
                } label: {
                    Label("Seleccionar aplicaciones", systemImage: "square.grid.2x2")
                        .font(.custom("Helvetica", size: 15).weight(.bold))
                        .foregroundStyle(RituoPalette.lightBlue)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(HomeDarkCardBackground(cornerRadius: 15))
                }
                .buttonStyle(LoginPressButtonStyle())

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.schedulers) { scheduler in
                            HomeSchedulerRow(
                                scheduler: scheduler,
                                isSelected: scheduler.isActive()
                            )
                        }

                        Button(action: createRitual) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus")
                                Text("Crear un ritual")
                                Spacer()
                            }
                            .font(.custom("Helvetica", size: 16).weight(.bold))
                            .foregroundStyle(RituoPalette.lightBlue)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(HomeDarkCardBackground(cornerRadius: 16))
                        }
                        .buttonStyle(LoginPressButtonStyle())
                    }
                    .padding(.vertical, 4)
                }

                HomePrimaryButton(title: "Crear un ritual") {
                    createRitual()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}
