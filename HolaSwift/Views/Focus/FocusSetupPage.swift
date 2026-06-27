import Charts
import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct FocusSetupPage: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    @State private var showConfig = false

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    pageHeader
                    dailySummaryCard
                    weeklyChartCard
                    statsGrid
                    if !viewModel.schedulers.isEmpty {
                        ritualsBreakdown
                    }
                    configSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FOCUS".uppercased())
                    .font(.custom("Helvetica", size: 10).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(RituoPalette.mistBlue.opacity(0.72))
                Text("Tu tiempo en pantalla")
                    .font(.custom("Helvetica", size: 26).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
            }
            Spacer()
            Image("RituoLogoWhite")
                .resizable()
                .scaledToFit()
                .frame(width: 72)
        }
    }

    // MARK: - Daily summary

    private var dailySummaryCard: some View {
        BrandPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Promedio diario")
                    .font(.custom("Helvetica", size: 12).weight(.semibold))
                    .foregroundStyle(RituoPalette.white.opacity(0.58))

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    if viewModel.isLoadingSessionSummary {
                        RituoLoadingBar(width: 140, height: 36)
                    } else {
                        let avg = dailyAverageMinutes
                        let h = avg / 60
                        let m = avg % 60
                        Group {
                            if h > 0 {
                                Text("\(h)h ")
                                    .font(.custom("Helvetica", size: 42).weight(.bold))
                                    .foregroundStyle(RituoPalette.white)
                                Text("\(m)min")
                                    .font(.custom("Helvetica", size: 28).weight(.bold))
                                    .foregroundStyle(RituoPalette.white.opacity(0.80))
                            } else {
                                Text("\(m)min")
                                    .font(.custom("Helvetica", size: 42).weight(.bold))
                                    .foregroundStyle(RituoPalette.white)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.orange)
                            Text("\(viewModel.ritualSessionSummary?.currentStreakDays ?? 0)d")
                                .font(.custom("Helvetica", size: 15).weight(.bold))
                                .foregroundStyle(RituoPalette.white)
                        }
                        Text("racha")
                            .font(.custom("Helvetica", size: 10).weight(.semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.46))
                    }
                }

                if !viewModel.isLoadingSessionSummary {
                    Divider()
                        .background(RituoPalette.white.opacity(0.12))

                    HStack(spacing: 0) {
                        Text("Ver toda la actividad")
                            .font(.custom("Helvetica", size: 13).weight(.semibold))
                            .foregroundStyle(RituoPalette.lightBlue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RituoPalette.lightBlue.opacity(0.70))
                    }
                }
            }
        }
    }

    // MARK: - Weekly chart

    private var weeklyChartCard: some View {
        BrandPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Esta semana")
                        .font(.custom("Helvetica", size: 16).weight(.bold))
                        .foregroundStyle(RituoPalette.white)
                    Spacer()
                    Text("\(weeklyTotalMinutes)m total")
                        .font(.custom("Helvetica", size: 12).weight(.semibold))
                        .foregroundStyle(RituoPalette.mistBlue.opacity(0.80))
                }

                if viewModel.isLoadingSessionHistories {
                    RituoLoadingBar(height: 100)
                        .frame(height: 100)
                } else {
                    let data = weeklyFocusData
                    let maxVal = max(data.map(\.minutes).max() ?? 1, 1)
                    let avgVal = weeklyTotalMinutes / 7

                    Chart(data) { day in
                        BarMark(
                            x: .value("Día", day.label),
                            y: .value("Minutos", day.minutes)
                        )
                        .foregroundStyle(
                            day.isToday
                            ? AnyShapeStyle(LinearGradient(
                                colors: [RituoPalette.white, RituoPalette.lightBlue],
                                startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(RituoPalette.mistBlue.opacity(0.38))
                        )
                        .cornerRadius(5)

                        if avgVal > 0 {
                            RuleMark(y: .value("Prom", avgVal))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundStyle(RituoPalette.lightBlue.opacity(0.55))
                                .annotation(position: .trailing, alignment: .leading) {
                                    Text("prom.")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(RituoPalette.lightBlue.opacity(0.72))
                                }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing) { value in
                            AxisValueLabel {
                                if let v = value.as(Int.self) {
                                    Text(v == 0 ? "0" : "\(v)m")
                                        .font(.system(size: 9))
                                        .foregroundStyle(RituoPalette.white.opacity(0.40))
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(RituoPalette.white.opacity(0.08))
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(RituoPalette.white.opacity(0.60))
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...(maxVal + 10))
                    .frame(height: 110)
                }
            }
        }
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            FocusStatTile(
                symbol: "checkmark.circle.fill",
                value: "\(viewModel.ritualSessionSummary?.completedSessions ?? 0)",
                label: "Completadas",
                tint: RituoPalette.lightBlue,
                isLoading: viewModel.isLoadingSessionSummary
            )
            FocusStatTile(
                symbol: "timer",
                value: focusTotalText,
                label: "Tiempo de foco",
                tint: RituoPalette.white,
                isLoading: viewModel.isLoadingSessionSummary
            )
            FocusStatTile(
                symbol: "list.bullet.rectangle",
                value: "\(viewModel.ritualSessionSummary?.totalSessions ?? 0)",
                label: "Sesiones totales",
                tint: RituoPalette.mistBlue,
                isLoading: viewModel.isLoadingSessionSummary
            )
            FocusStatTile(
                symbol: "xmark.circle",
                value: "\(viewModel.ritualSessionSummary?.cancelledSessions ?? 0)",
                label: "Canceladas",
                tint: RituoPalette.danger.opacity(0.80),
                isLoading: viewModel.isLoadingSessionSummary
            )
        }
    }

    // MARK: - Rituals breakdown

    private var ritualsBreakdown: some View {
        BrandPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Por ritual")
                    .font(.custom("Helvetica", size: 16).weight(.bold))
                    .foregroundStyle(RituoPalette.white)

                ForEach(viewModel.schedulers) { scheduler in
                    let sessions = viewModel.sessions(for: scheduler)
                    let minutes = sessions.reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) }
                    let completed = sessions.filter { $0.status == "completed" }.count
                    let maxMinutes = ritualMaxMinutes

                    RitualFocusRow(
                        scheduler: scheduler,
                        minutes: minutes,
                        completed: completed,
                        progress: maxMinutes > 0 ? Double(minutes) / Double(maxMinutes) : 0,
                        isLoading: viewModel.isLoadingSessionHistories && sessions.isEmpty
                    )

                    if scheduler.id != viewModel.schedulers.last?.id {
                        Divider()
                            .background(RituoPalette.white.opacity(0.10))
                    }
                }
            }
        }
    }

    // MARK: - Config section

    private var configSection: some View {
        BrandPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        showConfig.toggle()
                    }
                } label: {
                    HStack {
                        Text("Configuración")
                            .font(.custom("Helvetica", size: 16).weight(.bold))
                            .foregroundStyle(RituoPalette.white)
                        Spacer()
                        Image(systemName: showConfig ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.50))
                    }
                }
                .buttonStyle(.plain)

                if showConfig {
                    VStack(spacing: 12) {
                        SystemStatusRow(title: "Screen Time", value: viewModel.authorizationStatusText, isOn: viewModel.isAuthorized)
                        SystemStatusRow(title: "Selección", value: viewModel.selectionSummary, isOn: viewModel.selectedItemCount > 0)
                        SystemStatusRow(title: "Tag NFC", value: viewModel.registeredTagIdentifier == nil ? "Sin vincular" : "Vinculado", isOn: viewModel.registeredTagIdentifier != nil)

                        Divider().background(RituoPalette.white.opacity(0.10))

                        Button {
                            Task { await viewModel.requestAuthorization() }
                        } label: {
                            Label(viewModel.isAuthorized ? "Screen Time autorizado" : "Autorizar Screen Time", systemImage: "shield")
                                .font(.custom("Helvetica", size: 15).weight(.bold))
                                .foregroundStyle(RituoPalette.deepOceanBlue)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(RituoPalette.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(LoginPressButtonStyle())
                        .disabled(viewModel.isAuthorizing)

                        Button {
                            Task { await viewModel.openActivityPicker() }
                        } label: {
                            Label("Seleccionar aplicaciones", systemImage: "square.grid.2x2")
                                .font(.custom("Helvetica", size: 15).weight(.bold))
                                .foregroundStyle(RituoPalette.lightBlue)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RituoPalette.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
                                }
                        }
                        .buttonStyle(LoginPressButtonStyle())

                        Button {
                            if viewModel.registeredTagIdentifier == nil {
                                viewModel.registerTag()
                            } else if viewModel.isBlocking {
                                viewModel.endBlockWithTag()
                            } else {
                                viewModel.startBlockWithTag()
                            }
                        } label: {
                            Label(viewModel.registeredTagIdentifier == nil ? "Registrar tag NFC" : "Usar tag NFC", systemImage: "tag")
                                .font(.custom("Helvetica", size: 15).weight(.bold))
                                .foregroundStyle(RituoPalette.lightBlue)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RituoPalette.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(RituoPalette.white.opacity(0.10), lineWidth: 1)
                                }
                        }
                        .buttonStyle(LoginPressButtonStyle())

                        if !viewModel.deviceActivityDebugEvents.isEmpty {
                            Divider().background(RituoPalette.white.opacity(0.10))

                            HStack {
                                Text("\(viewModel.deviceActivityDebugEvents.count) eventos de sistema")
                                    .font(.custom("Helvetica", size: 11).weight(.semibold))
                                    .foregroundStyle(RituoPalette.white.opacity(0.46))
                                Spacer()
                                Button {
                                    viewModel.clearDeviceActivityDebugEvents()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(RituoPalette.white.opacity(0.46))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Computed

    private var allSessions: [RitualSessionResponse] {
        viewModel.schedulers.flatMap { viewModel.sessions(for: $0) }
    }

    private var dailyAverageMinutes: Int {
        guard let summary = viewModel.ritualSessionSummary, summary.completedSessions > 0 else { return 0 }
        return summary.totalFocusMinutes / max(summary.currentStreakDays, 1)
    }

    private var weeklyTotalMinutes: Int {
        weeklyFocusData.reduce(0) { $0 + $1.minutes }
    }

    private var focusTotalText: String {
        let mins = viewModel.ritualSessionSummary?.totalFocusMinutes ?? 0
        let h = mins / 60
        let m = mins % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var weeklyFocusData: [DayFocusData] {
        let calendar = Calendar.current
        let now = Date()
        var dayMinutes: [Int: Int] = [:]

        for session in allSessions {
            guard let date = parseISO(session.startedAt),
                  calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear),
                  let duration = session.durationSeconds else { continue }
            let weekday = calendar.component(.weekday, from: date)
            dayMinutes[weekday, default: 0] += duration / 60
        }

        let today = calendar.component(.weekday, from: now)
        let order: [(Int, String)] = [(2,"L"),(3,"M"),(4,"M"),(5,"J"),(6,"V"),(7,"S"),(1,"D")]
        return order.map { (wd, label) in
            DayFocusData(label: label, minutes: dayMinutes[wd] ?? 0, isToday: wd == today)
        }
    }

    private var ritualMaxMinutes: Int {
        viewModel.schedulers
            .map { s in viewModel.sessions(for: s).reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) } }
            .max() ?? 1
    }

    private func parseISO(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }
}

// MARK: - Supporting types

struct DayFocusData: Identifiable {
    let id = UUID()
    let label: String
    let minutes: Int
    let isToday: Bool
}

// MARK: - Sub-views

struct FocusStatTile: View {
    let symbol: String
    let value: String
    let label: String
    let tint: Color
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint)
                }
                Spacer()
            }

            if isLoading {
                RituoLoadingBar(width: 52, height: 18)
            } else {
                Text(value)
                    .font(.custom("Helvetica", size: 22).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                    .monospacedDigit()
            }

            Text(label)
                .font(.custom("Helvetica", size: 11).weight(.semibold))
                .foregroundStyle(RituoPalette.white.opacity(0.50))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [RituoPalette.glassBlue.opacity(0.88), RituoPalette.inkBlue.opacity(0.94)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct RitualFocusRow: View {
    let scheduler: RitualScheduler
    let minutes: Int
    let completed: Int
    let progress: Double
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(RituoPalette.white.opacity(0.09))
                        .frame(width: 40, height: 40)
                    Image(systemName: scheduler.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RituoPalette.mistBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(scheduler.title)
                        .font(.custom("Helvetica", size: 15).weight(.bold))
                        .foregroundStyle(RituoPalette.white)
                        .lineLimit(1)
                    Text("\(scheduler.weekdayText) · \(scheduler.timeRangeText)")
                        .font(.custom("Helvetica", size: 11).weight(.medium))
                        .foregroundStyle(RituoPalette.white.opacity(0.50))
                }

                Spacer()

                if isLoading {
                    RituoLoadingBar(width: 40, height: 14)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(minutesText)
                            .font(.custom("Helvetica", size: 15).weight(.bold))
                            .foregroundStyle(RituoPalette.white)
                        Text("\(completed) sesiones")
                            .font(.custom("Helvetica", size: 10).weight(.semibold))
                            .foregroundStyle(RituoPalette.white.opacity(0.44))
                    }
                }
            }

            if !isLoading && progress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(RituoPalette.white.opacity(0.08))
                            .frame(height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [RituoPalette.white, RituoPalette.lightBlue],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(progress, 1), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private var minutesText: String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
