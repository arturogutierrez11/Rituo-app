import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

// MARK: - Intro / loading screen

struct IntroRitualView: View {
    @State private var animates = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RituoPalette.background, RituoPalette.panel, Color.black],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(RituoPalette.glow.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .scaleEffect(animates ? 1.12 : 0.86)

            VStack(spacing: 26) {
                ZStack {
                    Circle().strokeBorder(RituoPalette.stroke.opacity(0.65), lineWidth: 1).frame(width: 150, height: 150)
                    Circle().fill(RituoPalette.glow.opacity(0.12)).frame(width: 118, height: 118)
                    Image("RituoLogoWhite").resizable().scaledToFit().frame(width: 78)
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
        .onAppear { animates = true }
    }
}

// MARK: - Dashboard

struct RitualDashboardPage: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let accessToken: String?
    @State private var isModePickerPresented = false
    @State private var showStopModeConfirm = false
    @State private var pendingStartMode: FocusMode?

    init(viewModel: BlockSetupViewModel, accessToken: String? = nil) {
        self.viewModel = viewModel
        self.accessToken = accessToken
    }

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            VStack(spacing: 0) {
                if viewModel.isBlocking {
                    activeRitualView
                } else {
                    inactiveRitualView
                }
            }
        }
        .sheet(isPresented: $isModePickerPresented) {
            ModeStartSheet(viewModel: viewModel, accessToken: accessToken, onStartMode: { mode in
                isModePickerPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    pendingStartMode = mode
                }
            })
        }
        .sheet(item: $pendingStartMode) { mode in
            ModeConfirmStartSheet(mode: mode) { configuredMode in
                viewModel.updateModeStrictMode(
                    configuredMode.strictModeEnabled,
                    for: configuredMode
                )
                viewModel.updateModeAppInstallationBlocking(
                    configuredMode.blockAppInstallation,
                    for: configuredMode
                )
                viewModel.updateModeAdultContentBlocking(
                    configuredMode.blockAdultContent,
                    for: configuredMode
                )
                Task { _ = await viewModel.startMode(configuredMode) }
                pendingStartMode = nil
            } onCancel: {
                pendingStartMode = nil
            }
        }
        .sheet(isPresented: $showStopModeConfirm) {
            ModeConfirmStopSheet(
                mode: viewModel.currentBlockingMode,
                onConfirm: {
                    showStopModeConfirm = false
                    viewModel.endBlockWithVerifiedTag(accessToken: accessToken)
                },
                onCancel: { showStopModeConfirm = false }
            )
        }
    }

    // MARK: - Inactive state

    private var inactiveRitualView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            HomeInactiveStatusCard()

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                if let next = nextRitual {
                    NextRitualBanner(scheduler: next)
                        .padding(.horizontal, 24)
                }

                Button {
                    if viewModel.hasClaimedNfcTag {
                        isModePickerPresented = true
                    } else {
                        viewModel.requestNfcTagSetup()
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(RituoPalette.deepOceanBlue.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(RituoPalette.deepOceanBlue)
                                .offset(x: 1)
                        }
                        Text("Iniciar un modo")
                            .font(.custom("Helvetica", size: 17).weight(.bold))
                            .foregroundStyle(RituoPalette.deepOceanBlue)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(RituoPalette.white)
                    .clipShape(Capsule())
                    .shadow(color: RituoPalette.white.opacity(0.28), radius: 20, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(LoginPressButtonStyle())
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 120)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Active state

    @ViewBuilder
    private var activeRitualView: some View {
        let scheduler = viewModel.currentBlockingScheduler ?? viewModel.activeScheduler
        let mode = viewModel.currentBlockingMode

        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Group {
                if let mode {
                    ActiveModeStatusCard(
                        mode: mode,
                        isBreakActive: viewModel.isModeBreakActive,
                        breakRemainingText: viewModel.modeBreakRemainingText
                    )
                } else {
                    ActiveRitualTimerCard(
                        progress: activeProgress(for: scheduler),
                        remainingMinutes: activeRemainingMinutes,
                        title: scheduler?.title ?? "Ritual activo",
                        timeRange: scheduler?.timeRangeText ?? "En curso"
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            if mode != nil {
                Button {
                    viewModel.startModeBreak(minutes: 5)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: modeBreakButtonIcon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(modeBreakButtonTitle)
                            .font(.custom("Helvetica", size: 15).weight(.bold))
                        if let remaining = viewModel.modeBreakRemainingText,
                           viewModel.isModeBreakActive {
                            Text(remaining)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .opacity(0.64)
                        }
                    }
                    .foregroundStyle(RituoPalette.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        Capsule()
                            .fill(RituoPalette.white.opacity(0.10))
                            .overlay {
                                Capsule()
                                    .stroke(RituoPalette.white.opacity(0.12), lineWidth: 1)
                            }
                    )
                }
                .buttonStyle(LoginPressButtonStyle())
                .disabled(viewModel.isModeBreakActive || viewModel.hasUsedModeBreakInCurrentSession)
                .opacity(viewModel.hasUsedModeBreakInCurrentSession && !viewModel.isModeBreakActive ? 0.58 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            }

            Button {
                if mode != nil {
                    showStopModeConfirm = true
                } else {
                    viewModel.endBlockWithVerifiedTag(accessToken: accessToken)
                }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isReadingTag {
                        ProgressView().tint(RituoPalette.deepOceanBlue).scaleEffect(0.84)
                        Text("Leyendo tag…")
                            .font(.custom("Helvetica", size: 16).weight(.bold))
                            .foregroundStyle(RituoPalette.deepOceanBlue)
                    } else {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RituoPalette.deepOceanBlue)
                        Text(mode == nil ? "Finalizar ritual" : "Finalizar modo")
                            .font(.custom("Helvetica", size: 16).weight(.bold))
                            .foregroundStyle(RituoPalette.deepOceanBlue)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(RituoPalette.white)
                .clipShape(Capsule())
                .shadow(color: RituoPalette.white.opacity(0.30), radius: 18, x: 0, y: 6)
            }
            .buttonStyle(LoginPressButtonStyle())
            .disabled(viewModel.isReadingTag)
            .padding(.horizontal, 24)
            .padding(.bottom, 120)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Computed

    private var nextRitual: RitualScheduler? {
        viewModel.schedulers.first { !$0.isActive() }
    }

    private var activeRemainingMinutes: Int {
        guard let blockedUntil = viewModel.blockedUntil else { return 0 }
        return max(0, Int(ceil(blockedUntil.timeIntervalSinceNow / 60)))
    }

    private var activeElapsedMinutes: Int {
        guard viewModel.isBlocking,
              let scheduler = viewModel.currentBlockingScheduler ?? viewModel.activeScheduler
        else { return 0 }
        return max(0, scheduler.durationMinutes - activeRemainingMinutes)
    }

    private var modeBreakButtonTitle: String {
        if viewModel.isModeBreakActive {
            return "Recreo activo"
        }

        if viewModel.hasUsedModeBreakInCurrentSession {
            return "Recreo usado"
        }

        return "Recreo 5 min"
    }

    private var modeBreakButtonIcon: String {
        if viewModel.isModeBreakActive {
            return "pause.circle.fill"
        }

        if viewModel.hasUsedModeBreakInCurrentSession {
            return "checkmark.circle.fill"
        }

        return "cup.and.saucer.fill"
    }

    private func activeProgress(for scheduler: RitualScheduler?) -> Double {
        guard let scheduler, scheduler.durationMinutes > 0 else { return 0 }
        return min(1, max(0, Double(activeRemainingMinutes) / Double(scheduler.durationMinutes)))
    }
}

// MARK: - Stat cell

private struct HomeStatCell: View {
    let value: String
    let label: String
    let symbol: String
    var tint: Color = RituoPalette.lightBlue
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)

            if isLoading {
                RituoLoadingBar(width: 36, height: 14)
            } else {
                Text(value)
                    .font(.custom("Helvetica", size: 20).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(label.uppercased())
                .font(.custom("Helvetica", size: 9).weight(.bold))
                .tracking(0.6)
                .foregroundStyle(RituoPalette.white.opacity(0.38))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Next ritual banner

private struct NextRitualBanner: View {
    let scheduler: RitualScheduler

    var body: some View {
        HStack(spacing: 14) {
            ritualIcon

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(RituoPalette.lightBlue)
                        .frame(width: 5, height: 5)
                        .shadow(color: RituoPalette.lightBlue.opacity(0.75), radius: 5)

                    Text("PRÓXIMO RITUAL")
                        .font(.custom("Helvetica", size: 9).weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(RituoPalette.white.opacity(0.46))
                }

                Text(scheduler.title)
                    .font(.custom("Helvetica", size: 18).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text(scheduler.timeRangeText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("·")
                        .foregroundStyle(RituoPalette.white.opacity(0.22))
                    Text(scheduler.weekdayText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(.custom("Helvetica", size: 12).weight(.bold))
                .foregroundStyle(RituoPalette.white.opacity(0.48))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(bannerBackground)
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RituoPalette.white.opacity(0.14))
                .frame(width: 92, height: 1)
                .padding(.leading, 22)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            RituoPalette.white.opacity(0.22),
                            RituoPalette.lightBlue.opacity(0.16),
                            RituoPalette.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
    }

    private var ritualIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            RituoPalette.lightBlue.opacity(0.28),
                            RituoPalette.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)

            Circle()
                .stroke(RituoPalette.white.opacity(0.12), lineWidth: 1)
                .frame(width: 32, height: 32)

            Image(systemName: schedulerIcon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.82))
        }
    }

    private var bannerBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.25, blue: 0.39).opacity(0.94),
                        Color(red: 0.10, green: 0.13, blue: 0.25).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var schedulerIcon: String {
        let title = scheduler.title.lowercased()
        if title.contains("gym") || title.contains("gimnas") || title.contains("entren") { return "dumbbell.fill" }
        if title.contains("lect") || title.contains("read") { return "book.closed.fill" }
        if title.contains("trab") || title.contains("work") { return "laptopcomputer" }
        if title.contains("dorm") || title.contains("sleep") { return "moon.stars.fill" }
        return scheduler.symbolName
    }
}

// MARK: - Inactive orb card

struct HomeInactiveStatusCard: View {
    var body: some View {
        VStack(spacing: 12) {
            RituoEmptyOrb()

            VStack(spacing: 4) {
                Text("Listo para enfocarte")
                    .font(.custom("Helvetica", size: 22).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .multilineTextAlignment(.center)

                Text("Elegí un ritual para empezar tu sesión\nde foco.")
                    .font(.custom("Helvetica", size: 13).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.44))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

// MARK: - Empty orb

struct RituoEmptyOrb: View {
    @State private var breathes = false
    @State private var rotates = false
    @State private var orbitAngle: Double = 0

    private let ring: CGFloat = 116

    var body: some View {
        ZStack {
            // Pulsing background glow
            Circle()
                .fill(RadialGradient(
                    colors: [RituoPalette.lightBlue.opacity(0.32), RituoPalette.deepOceanBlue.opacity(0.10), Color.clear],
                    center: .center, startRadius: 0, endRadius: ring * 0.7
                ))
                .frame(width: ring * 1.6, height: ring * 1.6)
                .blur(radius: 20)
                .scaleEffect(breathes ? 1.14 : 0.88)

            // Static base ring (subtle)
            Circle()
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
                .frame(width: ring + 22, height: ring + 22)

            // Main ring
            Circle()
                .stroke(RituoPalette.white.opacity(0.14), lineWidth: 1.5)
                .frame(width: ring, height: ring)

            // Rotating shimmer arc
            Circle()
                .trim(from: 0, to: 0.22)
                .stroke(
                    LinearGradient(
                        colors: [.clear, RituoPalette.white.opacity(0.90), RituoPalette.lightBlue.opacity(0.60), .clear],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: ring, height: ring)
                .rotationEffect(.degrees(rotates ? 360 : 0))
                .shadow(color: RituoPalette.white.opacity(0.70), radius: 8)
                .shadow(color: RituoPalette.lightBlue.opacity(0.80), radius: 14)

            // Second slower counter-arc
            Circle()
                .trim(from: 0.55, to: 0.68)
                .stroke(RituoPalette.lightBlue.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: ring + 22, height: ring + 22)
                .rotationEffect(.degrees(rotates ? -360 : 0))

            // Orbiting light dot
            Circle()
                .fill(RituoPalette.white)
                .frame(width: 5, height: 5)
                .shadow(color: RituoPalette.white, radius: 5)
                .shadow(color: RituoPalette.lightBlue, radius: 10)
                .offset(y: -(ring / 2))
                .rotationEffect(.degrees(rotates ? 360 : 0))

            // Logo
            Image("RituoLogoWhite")
                .resizable()
                .scaledToFit()
                .frame(width: 42)
                .opacity(breathes ? 0.80 : 0.55)
                .scaleEffect(breathes ? 1.04 : 0.97)
        }
        .frame(width: 188, height: 188)
        .onAppear { breathes = true; rotates = true }
        .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: breathes)
        .animation(.linear(duration: 7).repeatForever(autoreverses: false), value: rotates)
    }
}

// MARK: - Active ritual timer card

struct ActiveRitualTimerCard: View {
    let progress: Double
    let remainingMinutes: Int
    let title: String
    let timeRange: String
    @State private var breathes = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(RituoPalette.lightBlue.opacity(breathes ? 0.15 : 0.08))
                    .frame(width: 210, height: 210)
                    .blur(radius: 24)
                    .scaleEffect(breathes ? 1.04 : 0.96)

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(RituoPalette.mistBlue.opacity(0.15 - Double(index) * 0.025), lineWidth: 1)
                        .frame(width: CGFloat(158 + index * 10), height: CGFloat(158 + index * 10))
                }

                Circle()
                    .stroke(RituoPalette.white.opacity(0.14), lineWidth: 2.5)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: max(progress, 0.012))
                    .stroke(
                        LinearGradient(
                            colors: [RituoPalette.white, RituoPalette.lightBlue, RituoPalette.white.opacity(0.72)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: RituoPalette.white.opacity(0.58), radius: 6)
                    .shadow(color: RituoPalette.lightBlue.opacity(0.64), radius: 14)

                VStack(spacing: 4) {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.custom("Helvetica", size: 36).weight(.bold))
                        .foregroundStyle(RituoPalette.white)
                        .monospacedDigit()

                    Text("\(remainingMinutes) min restantes")
                        .font(.custom("Helvetica", size: 11).weight(.semibold))
                        .foregroundStyle(RituoPalette.white.opacity(0.58))
                }
            }
            .frame(height: 210)

            VStack(spacing: 5) {
                Text(title)
                    .font(.custom("Helvetica", size: 24).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                        .shadow(color: Color.green.opacity(0.60), radius: 4)
                    Text("En curso · \(timeRange)")
                        .font(.custom("Helvetica", size: 13).weight(.medium))
                        .foregroundStyle(RituoPalette.white.opacity(0.62))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { breathes = true }
        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: breathes)
        .animation(.easeInOut(duration: 0.7), value: progress)
    }
}

// MARK: - Unchanged components kept for compatibility

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
                    RituoPulseMark().scaleEffect(0.70)
                }
            }
            .foregroundStyle(RituoPalette.deepOceanBlue)
            .frame(maxWidth: .infinity, minHeight: showsMark ? 64 : 60)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.94, green: 0.91, blue: 0.89), Color(red: 0.84, green: 0.78, blue: 0.76)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay { Capsule().stroke(RituoPalette.white.opacity(0.62), lineWidth: 1) }
            .shadow(color: RituoPalette.deepOceanBlue.opacity(0.18), radius: 22, x: 0, y: 12)
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
        VStack(spacing: 5) {
            Text(value)
                .font(.custom("Helvetica", size: 20).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .monospacedDigit()

            Text(label.uppercased())
                .font(.custom("Helvetica", size: 9).weight(.bold))
                .tracking(0.6)
                .foregroundStyle(RituoPalette.white.opacity(0.46))
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(HomeDarkCardBackground(cornerRadius: 18))
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

struct HomeDarkCardBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [RituoPalette.glassBlue.opacity(0.88), RituoPalette.inkBlue.opacity(0.94)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [RituoPalette.mistBlue.opacity(0.22), RituoPalette.white.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: RituoPalette.inkBlue.opacity(0.18), radius: 14, y: 7)
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
                        .lineLimit(2).minimumScaleFactor(0.72)

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

struct ActiveRitualMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.custom("Helvetica", size: 15).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1).minimumScaleFactor(0.68)

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
                    .lineLimit(1).minimumScaleFactor(0.72)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(blockedRows) { row in ActiveBlockedItemTile(row: row) }
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.shield").font(.system(size: 12, weight: .bold))
                Text("Selección privada de Screen Time").font(.custom("Helvetica", size: 12).weight(.bold))
            }
            .foregroundStyle(RituoPalette.mistBlue.opacity(0.68))
        }
        .padding(18)
        .background(HomeDarkCardBackground(cornerRadius: 20))
    }

    private var blockedRows: [ActiveBlockedItemRow] {
        var rows: [ActiveBlockedItemRow] = []
        rows += (0..<scheduler.appCount).map { i in ActiveBlockedItemRow(title: "App \(i+1)", subtitle: "Aplicación", symbol: "app.badge", tint: RituoPalette.lightBlue) }
        rows += (0..<scheduler.categoryCount).map { i in ActiveBlockedItemRow(title: "Categoría \(i+1)", subtitle: "Categoría", symbol: "square.grid.2x2", tint: RituoPalette.glow) }
        rows += (0..<scheduler.domainCount).map { i in ActiveBlockedItemRow(title: "Web \(i+1)", subtitle: "Dominio", symbol: "globe", tint: RituoPalette.success) }
        if rows.isEmpty { rows.append(ActiveBlockedItemRow(title: "Sin detalle", subtitle: "Sin selección local", symbol: "slash.circle", tint: RituoPalette.white.opacity(0.54))) }
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
                Text(row.title).font(.custom("Helvetica", size: 12).weight(.bold)).foregroundStyle(RituoPalette.white).lineLimit(1).minimumScaleFactor(0.72)
                Text(row.subtitle).font(.custom("Helvetica", size: 9).weight(.bold)).foregroundStyle(RituoPalette.white.opacity(0.50)).textCase(.uppercase)
            }
            Spacer(minLength: 0)
        }
        .padding(10).frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(RituoPalette.white.opacity(0.07)))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RituoPalette.white.opacity(0.08), lineWidth: 1) }
    }
}

struct ActiveBlockedCountBadge: View {
    let count: Int
    var body: some View {
        Text("+\(count)")
            .font(.custom("Helvetica", size: 18).weight(.bold))
            .foregroundStyle(RituoPalette.white)
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(RituoPalette.white.opacity(0.10)))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RituoPalette.white.opacity(0.12), lineWidth: 1) }
    }
}

struct BlockedAppIcon: View {
    enum Kind { case instagram, tiktok, youtube, x, spotify }
    let kind: Kind
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.20, style: .continuous).fill(background).frame(width: size, height: size)
            Text(label).font(.system(size: size * 0.50, weight: .black, design: .rounded)).foregroundStyle(RituoPalette.white)
        }
        .padding(size * 0.16)
        .background(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(Color.black.opacity(0.20)))
    }

    private var label: String {
        switch kind { case .instagram: "◎"; case .tiktok: "♪"; case .youtube: "▶"; case .x: "𝕏"; case .spotify: "≋" }
    }
    private var background: AnyShapeStyle {
        switch kind {
        case .instagram: AnyShapeStyle(LinearGradient(colors: [.pink, .orange, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .tiktok, .x: AnyShapeStyle(Color.black)
        case .youtube: AnyShapeStyle(Color.red)
        case .spotify: AnyShapeStyle(Color.green)
        }
    }
}

struct HomeActiveSchedulerCard: View {
    let scheduler: RitualScheduler
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "book").font(.system(size: 26, weight: .medium)).foregroundStyle(RituoPalette.lightBlue)
                .frame(width: 64, height: 64).background(Circle().fill(RituoPalette.lightBlue.opacity(0.12)))
                .overlay { Circle().stroke(RituoPalette.lightBlue.opacity(0.26), lineWidth: 1) }
            VStack(alignment: .leading, spacing: 6) {
                Text(scheduler.title).font(.custom("Helvetica", size: 19).weight(.bold)).foregroundStyle(RituoPalette.white)
                Text("\(scheduler.weekdayText) · \(scheduler.timeRangeText)").font(.custom("Helvetica", size: 13).weight(.medium)).foregroundStyle(RituoPalette.white.opacity(0.62))
                Text("Apps bloqueadas: \(max(scheduler.selectedItemCount, 5))").font(.custom("Helvetica", size: 13).weight(.bold)).foregroundStyle(RituoPalette.lightBlue)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 18, weight: .medium)).foregroundStyle(RituoPalette.white.opacity(0.86))
        }
        .padding(16).background(HomeDarkCardBackground(cornerRadius: 18))
    }
}

struct HomeStopRitualCard: View {
    let isReadingTag: Bool
    var body: some View {
        HStack(spacing: 16) {
            RituoPulseMark().scaleEffect(0.68).frame(width: 50, height: 50)
                .background(Circle().fill(RituoPalette.lightBlue.opacity(0.10)))
                .overlay { Circle().stroke(RituoPalette.lightBlue.opacity(0.30), lineWidth: 1) }
            VStack(alignment: .leading, spacing: 6) {
                Text(isReadingTag ? "leyendo tag..." : "detener con NFC").font(.custom("Helvetica", size: 15).weight(.bold)).foregroundStyle(RituoPalette.white)
                Text("Acercá tu tag para liberar las apps.").font(.custom("Helvetica", size: 12).weight(.medium)).foregroundStyle(RituoPalette.white.opacity(0.58)).lineSpacing(2).lineLimit(2)
            }
            Spacer()
            if isReadingTag { ProgressView().tint(RituoPalette.mistBlue) }
            else { Image(systemName: "lock").font(.system(size: 18, weight: .medium)).foregroundStyle(RituoPalette.mistBlue.opacity(0.70)) }
        }
        .padding(14).background(HomeDarkCardBackground(cornerRadius: 22))
    }
}

private struct ActiveModeStatusCard: View {
    let mode: FocusMode
    let isBreakActive: Bool
    let breakRemainingText: String?
    @State private var breathes = false
    @State private var rotates = false

    private let ring: CGFloat = 140

    var body: some View {
        VStack(spacing: 32) {
            // Orb animado con icono del modo
            ZStack {
                // Glow exterior
                Circle()
                    .fill(RadialGradient(
                        colors: [mode.accentColor.opacity(0.28), Color.clear],
                        center: .center, startRadius: 0, endRadius: ring * 1.1
                    ))
                    .frame(width: ring * 2.2, height: ring * 2.2)
                    .blur(radius: 32)
                    .scaleEffect(breathes ? 1.18 : 0.82)

                // Anillo exterior sutil
                Circle()
                    .stroke(mode.accentColor.opacity(0.08), lineWidth: 1)
                    .frame(width: ring + 32, height: ring + 32)

                // Anillo principal
                Circle()
                    .stroke(RituoPalette.white.opacity(0.12), lineWidth: 1.5)
                    .frame(width: ring, height: ring)

                // Arco giratorio del color del modo
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(
                        LinearGradient(
                            colors: [.clear, mode.accentColor.opacity(0.90), .clear],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: ring, height: ring)
                    .rotationEffect(.degrees(rotates ? 360 : 0))
                    .shadow(color: mode.accentColor.opacity(0.80), radius: 10)

                // Punto orbital
                Circle()
                    .fill(mode.accentColor)
                    .frame(width: 5, height: 5)
                    .shadow(color: mode.accentColor, radius: 6)
                    .offset(y: -(ring / 2))
                    .rotationEffect(.degrees(rotates ? 360 : 0))

                // Icono central
                Image(systemName: mode.displaySymbolName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(mode.accentColor.opacity(breathes ? 1.0 : 0.65))
                    .scaleEffect(breathes ? 1.04 : 0.96)
            }
            .frame(width: ring * 2.2, height: ring * 2.2)

            // Texto
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(mode.accentColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: mode.accentColor.opacity(0.90), radius: 5)
                        .scaleEffect(breathes ? 1.3 : 0.8)
                    Text(isBreakActive ? "RECREO ACTIVO" : "MODO ACTIVO")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.2)
                        .foregroundStyle(mode.accentColor)
                }

                Text(mode.title)
                    .font(.custom("Helvetica", size: 36).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 16) {
                    Label(
                        isBreakActive ? (breakRemainingText ?? "5:00") : "Sin límite",
                        systemImage: isBreakActive ? "pause.circle.fill" : "infinity"
                    )
                    Rectangle()
                        .fill(RituoPalette.white.opacity(0.12))
                        .frame(width: 1, height: 12)
                    Label(
                        isBreakActive ? "acceso libre" : "\(mode.blockingRuleCount) bloqueos",
                        systemImage: isBreakActive ? "lock.open.fill" : "lock.fill"
                    )
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RituoPalette.white.opacity(0.38))
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { breathes = true }
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) { rotates = true }
        }
    }
}

// MARK: - Confirm start sheet

private struct ModeConfirmStartSheet: View {
    let mode: FocusMode
    let onConfirm: (FocusMode) -> Void
    let onCancel: () -> Void
    @State private var strictModeEnabled: Bool
    @State private var blockAppInstallation: Bool
    @State private var blockAdultContent: Bool

    init(
        mode: FocusMode,
        onConfirm: @escaping (FocusMode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _strictModeEnabled = State(initialValue: mode.strictModeEnabled)
        _blockAppInstallation = State(initialValue: mode.blockAppInstallation)
        _blockAdultContent = State(initialValue: mode.blockAdultContent)
    }

    private var blockingRuleCount: Int {
        mode.selectedItemCount
            + (strictModeEnabled ? 1 : 0)
            + (blockAppInstallation ? 1 : 0)
            + (blockAdultContent ? 1 : 0)
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(RituoPalette.white.opacity(0.16))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 28)

                // Header con icono inline
                HStack(spacing: 14) {
                    Image(systemName: mode.displaySymbolName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(mode.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(mode.accentColor.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Activar modo")
                            .font(.system(size: 13))
                            .foregroundStyle(RituoPalette.white.opacity(0.36))
                        Text(mode.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Info strip
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(RituoPalette.white.opacity(0.35))
                        Text("\(blockingRuleCount)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                        Text("bloqueos")
                            .font(.system(size: 11))
                            .foregroundStyle(RituoPalette.white.opacity(0.30))
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(RituoPalette.white.opacity(0.07))
                        .frame(width: 1, height: 44)

                    VStack(spacing: 4) {
                        Image(systemName: "infinity")
                            .font(.system(size: 14))
                            .foregroundStyle(RituoPalette.white.opacity(0.35))
                        Text("∞")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                        Text("sin límite")
                            .font(.system(size: 11))
                            .foregroundStyle(RituoPalette.white.opacity(0.30))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
                        }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

                VStack(spacing: 10) {
                    ModeStartOptionToggle(
                        title: "Modo estricto",
                        subtitle: "Impide eliminar rituo mientras este modo esté activo.",
                        iconName: "lock.shield.fill",
                        accentColor: mode.accentColor,
                        isOn: $strictModeEnabled
                    )

                    ModeStartOptionToggle(
                        title: "Bloquear descargas de apps",
                        subtitle: "Impide instalar nuevas apps mientras este modo esté activo.",
                        iconName: "arrow.down.app.fill",
                        accentColor: mode.accentColor,
                        isOn: $blockAppInstallation
                    )

                    ModeStartOptionToggle(
                        title: "Bloquear contenido sensible en la web",
                        subtitle: "Filtra contenido adulto y, con la extensión de Safari habilitada, bloquea redes sociales y apuestas.",
                        iconName: "shield.lefthalf.filled",
                        accentColor: mode.accentColor,
                        isOn: $blockAdultContent
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)

                // Botones
                VStack(spacing: 10) {
                    Button {
                        var configuredMode = mode
                        configuredMode.strictModeEnabled = strictModeEnabled
                        configuredMode.blockAppInstallation = blockAppInstallation
                        configuredMode.blockAdultContent = blockAdultContent
                        onConfirm(configuredMode)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Activar \(mode.title)")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(RituoPalette.deepOceanBlue)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RituoPalette.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(LoginPressButtonStyle())

                    Button(action: onCancel) {
                        Text("Cancelar")
                            .font(.system(size: 15))
                            .foregroundStyle(RituoPalette.white.opacity(0.32))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(LoginPressButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .presentationDetents([.height(550)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}

private struct ModeStartOptionToggle: View {
    let title: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn ? accentColor : RituoPalette.white.opacity(0.34))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(isOn ? accentColor.opacity(0.12) : RituoPalette.white.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RituoPalette.white.opacity(0.34))
                        .lineLimit(2)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: accentColor))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
                }
        )
    }
}

// MARK: - Confirm stop sheet

private struct ModeConfirmStopSheet: View {
    let mode: FocusMode?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(RituoPalette.white.opacity(0.16))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 28)

                // Header con icono inline
                HStack(spacing: 14) {
                    if let mode {
                        Image(systemName: mode.displaySymbolName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(mode.accentColor)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(mode.accentColor.opacity(0.12))
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode != nil ? mode!.title : "Modo activo")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                        Text("Finalizar ahora")
                            .font(.system(size: 13))
                            .foregroundStyle(RituoPalette.white.opacity(0.36))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Aviso
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(RituoPalette.danger.opacity(0.70))
                    Text("Las apps bloqueadas quedarán libres de inmediato.")
                        .font(.system(size: 13))
                        .foregroundStyle(RituoPalette.white.opacity(0.38))
                        .lineSpacing(2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(RituoPalette.danger.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(RituoPalette.danger.opacity(0.14), lineWidth: 1)
                        }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // Botones
                VStack(spacing: 10) {
                    Button(action: onConfirm) {
                        Text("Finalizar modo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(RituoPalette.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(RituoPalette.danger.opacity(0.85))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(LoginPressButtonStyle())

                    Button(action: onCancel) {
                        Text("Cancelar")
                            .font(.system(size: 15))
                            .foregroundStyle(RituoPalette.white.opacity(0.32))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(LoginPressButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}

// MARK: - Mode start sheet

struct ModeStartSheet: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let accessToken: String?
    var onStartMode: ((FocusMode) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var modePendingRename: FocusMode?

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(RituoPalette.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 28)

                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modos de foco")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                        Text("Toca uno para activarlo ahora")
                            .font(.system(size: 14))
                            .foregroundStyle(RituoPalette.white.opacity(0.32))
                    }

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RituoPalette.white.opacity(0.40))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(RituoPalette.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // List
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(viewModel.modes) { mode in
                            ModeStartRow(
                                mode: mode,
                                onPlay: {
                                    if let onStartMode {
                                        onStartMode(mode)
                                    } else {
                                        Task { if await viewModel.startMode(mode) { dismiss() } }
                                    }
                                },
                                onConfigure: {
                                    Task { await viewModel.openModeActivityPicker(mode) }
                                },
                                onRename: {
                                    modePendingRename = mode
                                }
                            )
                        }

                        if let modeMessage = viewModel.modeMessage {
                            Text(modeMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RituoPalette.mistBlue.opacity(0.70))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(item: $viewModel.modeActivityPickerTarget) { mode in
            ModeActivityPickerSheet(viewModel: viewModel, mode: mode)
        }
        .sheet(item: $modePendingRename) { mode in
            ModeRenameSheet(
                mode: mode,
                viewModel: viewModel,
                accessToken: accessToken
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

private struct ModeStartRow: View {
    let mode: FocusMode
    let onPlay: () -> Void
    let onConfigure: () -> Void
    let onRename: () -> Void

    private var isConfigured: Bool { mode.hasBlockingConfiguration }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: mode.displaySymbolName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(mode.accentColor.opacity(0.85))
                .frame(width: 28, height: 28)

            Rectangle()
                .fill(RituoPalette.white.opacity(0.07))
                .frame(width: 1, height: 36)

            // Text
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(mode.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                    if mode.isProtected {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(RituoPalette.white.opacity(0.25))
                    }
                }
                Text(isConfigured ? "\(mode.blockingRuleCount) bloqueos" : "Sin configurar")
                    .font(.system(size: 12))
                    .foregroundStyle(RituoPalette.white.opacity(0.28))
            }

            Spacer()

            // Botones independientes
            HStack(spacing: 8) {
                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RituoPalette.white.opacity(0.30))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(RituoPalette.white.opacity(0.06)))
                }
                .buttonStyle(LoginPressButtonStyle())

                Button(action: onConfigure) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RituoPalette.white.opacity(0.30))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(RituoPalette.white.opacity(0.06)))
                }
                .buttonStyle(LoginPressButtonStyle())

                if isConfigured {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(mode.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(mode.accentColor.opacity(0.12)))
                    }
                    .buttonStyle(LoginPressButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.25))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
                }
        )
    }
}

private struct ModeRenameSheet: View {
    let mode: FocusMode
    @ObservedObject var viewModel: BlockSetupViewModel
    let accessToken: String?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String

    init(
        mode: FocusMode,
        viewModel: BlockSetupViewModel,
        accessToken: String?
    ) {
        self.mode = mode
        self.viewModel = viewModel
        self.accessToken = accessToken
        _title = State(initialValue: mode.title)
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(RituoPalette.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 26)

                HStack(spacing: 14) {
                    Image(systemName: mode.displaySymbolName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(mode.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(mode.accentColor.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Editar modo")
                            .font(.system(size: 13))
                            .foregroundStyle(RituoPalette.white.opacity(0.36))
                        Text(mode.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Nombre")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(RituoPalette.white.opacity(0.36))

                    TextField("Nombre del modo", text: $title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                        .tint(mode.accentColor)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(RituoPalette.white.opacity(0.06))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
                        }

                    Text("Este nombre se va a usar en Home, Foco y al iniciar el modo.")
                        .font(.system(size: 12))
                        .foregroundStyle(RituoPalette.white.opacity(0.34))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 22)

                VStack(spacing: 10) {
                    Button {
                        Task {
                            if await viewModel.renameMode(mode, title: title, accessToken: accessToken) {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Guardar nombre")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(RituoPalette.deepOceanBlue)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(RituoPalette.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(LoginPressButtonStyle())

                    Button("Cancelar") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RituoPalette.white.opacity(0.48))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}

struct RitualStartSheet: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let createRitual: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RituoAnimatedBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(RituoPalette.white.opacity(0.24))
                    .frame(width: 40, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 24)

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MIS RITUALES")
                            .font(.custom("Helvetica", size: 10).weight(.bold))
                            .tracking(3)
                            .foregroundStyle(RituoPalette.mistBlue.opacity(0.68))
                        Text(viewModel.schedulers.isEmpty ? "Comenzá creando uno" : "Elegí un ritual")
                            .font(.custom("Helvetica", size: 26).weight(.bold))
                            .foregroundStyle(RituoPalette.white)
                    }
                    Spacer()
                    if !viewModel.schedulers.isEmpty {
                        Text("\(viewModel.schedulers.count)")
                            .font(.custom("Helvetica", size: 13).weight(.bold))
                            .foregroundStyle(RituoPalette.white.opacity(0.46))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(RituoPalette.white.opacity(0.10)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                if viewModel.schedulers.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Spacer()
                        ZStack {
                            Circle().fill(RituoPalette.white.opacity(0.06)).frame(width: 100, height: 100)
                            Circle().stroke(RituoPalette.white.opacity(0.08), lineWidth: 1).frame(width: 100, height: 100)
                            Image(systemName: "bolt")
                                .font(.system(size: 38, weight: .light))
                                .foregroundStyle(RituoPalette.lightBlue.opacity(0.70))
                        }
                        VStack(spacing: 8) {
                            Text("Todavía no tenés rituales")
                                .font(.custom("Helvetica", size: 20).weight(.bold))
                                .foregroundStyle(RituoPalette.white)
                            Text("Creá tu primer ritual para empezar\na bloquear distracciones.")
                                .font(.custom("Helvetica", size: 14).weight(.medium))
                                .foregroundStyle(RituoPalette.white.opacity(0.50))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(viewModel.schedulers) { scheduler in
                                StartSheetRitualRow(scheduler: scheduler)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                }

                Spacer(minLength: 0)

                // Bottom action
                VStack(spacing: 10) {
                    if !viewModel.schedulers.isEmpty {
                        Button { Task { await viewModel.openActivityPicker() } } label: {
                            Label("Editar apps bloqueadas", systemImage: "square.grid.2x2")
                                .font(.custom("Helvetica", size: 15).weight(.bold))
                                .foregroundStyle(RituoPalette.lightBlue)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(RituoPalette.white.opacity(0.08))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
                                        }
                                )
                        }
                        .buttonStyle(LoginPressButtonStyle())
                    }

                    Button(action: createRitual) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(RituoPalette.deepOceanBlue.opacity(0.14)).frame(width: 30, height: 30)
                                Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(RituoPalette.deepOceanBlue)
                            }
                            Text("Crear un ritual")
                                .font(.custom("Helvetica", size: 17).weight(.bold))
                                .foregroundStyle(RituoPalette.deepOceanBlue)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(RituoPalette.white)
                        .clipShape(Capsule())
                        .shadow(color: RituoPalette.white.opacity(0.22), radius: 18, x: 0, y: 6)
                    }
                    .buttonStyle(LoginPressButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

private struct StartSheetRitualRow: View {
    let scheduler: RitualScheduler

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accentColor.opacity(0.16))
                    .frame(width: 48, height: 48)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accentColor.opacity(0.28), lineWidth: 1)
                    .frame(width: 48, height: 48)
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(scheduler.title)
                        .font(.custom("Helvetica", size: 16).weight(.bold))
                        .foregroundStyle(RituoPalette.white)
                        .lineLimit(1)
                    if scheduler.isActive() {
                        Text("En curso")
                            .font(.custom("Helvetica", size: 9).weight(.bold))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.14)))
                    }
                }
                Text("\(scheduler.weekdayText) · \(scheduler.timeRangeText)")
                    .font(.custom("Helvetica", size: 12).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.50))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(scheduler.selectedItemCount)")
                    .font(.custom("Helvetica", size: 16).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                Text("apps")
                    .font(.custom("Helvetica", size: 9).weight(.bold))
                    .foregroundStyle(RituoPalette.white.opacity(0.38))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.26))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.27, blue: 0.40),
                            Color(red: 0.11, green: 0.15, blue: 0.26)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    scheduler.isActive() ? accentColor.opacity(0.44) : RituoPalette.white.opacity(0.08),
                    lineWidth: scheduler.isActive() ? 1.5 : 1
                )
        }
    }

    private var accentColor: Color {
        let t = scheduler.title.lowercased()
        if t.contains("lect") || t.contains("libro") { return RituoPalette.lightBlue }
        if t.contains("gym") || t.contains("entren") { return Color(red: 0.28, green: 0.82, blue: 0.44) }
        if t.contains("med") || t.contains("noche") { return Color(red: 0.60, green: 0.46, blue: 0.90) }
        if t.contains("work") || t.contains("estud") { return Color(red: 0.96, green: 0.72, blue: 0.32) }
        return RituoPalette.mistBlue
    }

    private var iconName: String {
        let t = scheduler.title.lowercased()
        if t.contains("gym") || t.contains("entren") { return "dumbbell.fill" }
        if t.contains("lect") || t.contains("libro") { return "book.closed.fill" }
        if t.contains("med") || t.contains("calma") { return "figure.mind.and.body" }
        if t.contains("noche") || t.contains("sleep") { return "moon.stars.fill" }
        if t.contains("work") || t.contains("estud") { return "laptopcomputer" }
        return scheduler.symbolName
    }
}

struct RituoCrystalLamp: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle().fill(RituoPalette.lightBlue.opacity(0.28)).frame(width: 190, height: 190).blur(radius: 30).offset(y: -8)
            Image(systemName: "diamond.fill")
                .font(.system(size: 120, weight: .light))
                .foregroundStyle(LinearGradient(colors: [RituoPalette.lightBlue, .cyan, .yellow.opacity(0.72), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: RituoPalette.lightBlue.opacity(0.8), radius: 26)
                .offset(y: -18)
            Capsule().fill(Color.black.opacity(0.78)).frame(width: 70, height: 22)
        }
        .frame(width: 210, height: 210)
    }
}
