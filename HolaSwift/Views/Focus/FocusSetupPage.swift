import Charts
import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct FocusSetupPage: View {
    @ObservedObject var viewModel: BlockSetupViewModel
    let accessToken: String?
    @State private var showConfig = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pageHeader
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)

                    heroBanner
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.05), value: appeared)

                    weeklyChartCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.10), value: appeared)

                    statsGrid
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.14), value: appeared)

                    if !viewModel.schedulers.isEmpty || !viewModel.modes.isEmpty {
                        activityBreakdown
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.18), value: appeared)
                    }

                    configSection
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.22), value: appeared)
                }
                .padding(.horizontal, 20)
                .padding(.top, 62)
                .padding(.bottom, 140)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.40).delay(0.08)) { appeared = true }
        }
        .task(id: accessToken) {
            guard let accessToken, !accessToken.isEmpty else { return }
            await viewModel.loadFocusMetricsSummary(accessToken: accessToken)
            await viewModel.loadFocusHistoriesIfNeeded(accessToken: accessToken)
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Foco")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(RituoPalette.white)
                HStack(spacing: 14) {
                    miniStat(value: focusTotalText, label: "foco total")
                    dot()
                    miniStat(value: "\(viewModel.focusMetricsSummary?.completedSessions ?? 0)", label: "sesiones")
                    dot()
                    miniStat(value: "\(viewModel.focusMetricsSummary?.currentStreakDays ?? 0)d", label: "racha")
                }
            }
            Spacer()
        }
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
        Circle().fill(RituoPalette.white.opacity(0.16)).frame(width: 3, height: 3)
    }

    // MARK: - Hero banner (promedio diario)

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Promedio diario")
                .font(.system(size: 12))
                .foregroundStyle(RituoPalette.white.opacity(0.40))
                .padding(.bottom, 10)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if viewModel.isLoadingFocusMetrics {
                    RituoLoadingBar(width: 140, height: 36)
                } else {
                    let avg = dailyAverageMinutes
                    let h = avg / 60
                    let m = avg % 60
                    Group {
                        if h > 0 {
                            Text("\(h)h ")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundStyle(RituoPalette.white)
                            Text("\(m)min")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(RituoPalette.white.opacity(0.70))
                        } else {
                            Text("\(m)min")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundStyle(RituoPalette.white)
                        }
                    }
                }

                Spacer()

                // Racha
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.orange)
                        Text("\(viewModel.focusMetricsSummary?.currentStreakDays ?? 0)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                    }
                    Text("días de racha")
                        .font(.system(size: 11))
                        .foregroundStyle(RituoPalette.white.opacity(0.35))
                }
            }
        }
        .padding(20)
        .background(focusCard)
    }

    // MARK: - Weekly chart

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Esta semana")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RituoPalette.white)
                Spacer()
                Text("\(weeklyTotalMinutes)m total")
                    .font(.system(size: 12))
                    .foregroundStyle(RituoPalette.white.opacity(0.35))
            }

            if viewModel.isLoadingFocusMetrics {
                RituoLoadingBar(height: 100).frame(height: 100)
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
                        : AnyShapeStyle(RituoPalette.white.opacity(0.12))
                    )
                    .cornerRadius(6)

                    if avgVal > 0 {
                        RuleMark(y: .value("Prom", avgVal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(RituoPalette.lightBlue.opacity(0.50))
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("avg")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(RituoPalette.lightBlue.opacity(0.65))
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(v == 0 ? "0" : "\(v)m")
                                    .font(.system(size: 9))
                                    .foregroundStyle(RituoPalette.white.opacity(0.30))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(RituoPalette.white.opacity(0.06))
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(RituoPalette.white.opacity(0.45))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...(maxVal + 10))
                .frame(height: 100)
            }
        }
        .padding(20)
        .background(focusCard)
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            FocusStatTile(
                symbol: "checkmark.circle.fill",
                value: "\(viewModel.focusMetricsSummary?.completedSessions ?? 0)",
                label: "Completadas",
                tint: Color(red: 0.30, green: 0.88, blue: 0.50),
                isLoading: viewModel.isLoadingFocusMetrics
            )
            FocusStatTile(
                symbol: "timer",
                value: focusTotalText,
                label: "Tiempo de foco",
                tint: RituoPalette.lightBlue,
                isLoading: viewModel.isLoadingFocusMetrics
            )
            FocusStatTile(
                symbol: "list.bullet.rectangle",
                value: "\(viewModel.focusMetricsSummary?.totalSessions ?? 0)",
                label: "Sesiones totales",
                tint: RituoPalette.white.opacity(0.70),
                isLoading: viewModel.isLoadingFocusMetrics
            )
            FocusStatTile(
                symbol: "xmark.circle",
                value: "\(viewModel.focusMetricsSummary?.cancelledSessions ?? 0)",
                label: "Canceladas",
                tint: RituoPalette.danger.opacity(0.80),
                isLoading: viewModel.isLoadingFocusMetrics
            )
        }
    }

    // MARK: - Activity breakdown

    private var activityBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Por actividad")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RituoPalette.white)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.schedulers.enumerated()), id: \.element.id) { index, scheduler in
                    let sessions = viewModel.sessions(for: scheduler)
                    let minutes = sessions.reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) }
                    let completed = sessions.filter { $0.status == "completed" }.count

                    FocusActivityRow(
                        title: scheduler.title,
                        subtitle: "\(scheduler.weekdayText) · \(scheduler.timeRangeText)",
                        symbol: scheduler.symbolName,
                        tint: RituoPalette.lightBlue,
                        minutes: minutes,
                        completed: completed,
                        progress: activityMaxMinutes > 0 ? Double(minutes) / Double(activityMaxMinutes) : 0,
                        isLoading: viewModel.isLoadingSessionHistories && sessions.isEmpty
                    )

                    if index < viewModel.schedulers.count + viewModel.modes.count - 1 {
                        Rectangle()
                            .fill(RituoPalette.white.opacity(0.05))
                            .frame(height: 1)
                            .padding(.horizontal, 4)
                    }
                }

                ForEach(Array(viewModel.modes.enumerated()), id: \.element.id) { index, mode in
                    let sessions = viewModel.sessions(for: mode)
                    let minutes = sessions.reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) }
                    let completed = sessions.filter { $0.status == "completed" }.count

                    FocusActivityRow(
                        title: mode.title,
                        subtitle: "Modo manual",
                        symbol: mode.displaySymbolName,
                        tint: mode.accentColor,
                        minutes: minutes,
                        completed: completed,
                        progress: activityMaxMinutes > 0 ? Double(minutes) / Double(activityMaxMinutes) : 0,
                        isLoading: viewModel.isLoadingSessionHistories && sessions.isEmpty
                    )

                    if index < viewModel.modes.count - 1 {
                        Rectangle()
                            .fill(RituoPalette.white.opacity(0.05))
                            .frame(height: 1)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(focusCard)
        }
    }

    // MARK: - Config section

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    showConfig.toggle()
                }
            } label: {
                HStack {
                    Text("Configuración")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(RituoPalette.white.opacity(0.30))
                        .rotationEffect(.degrees(showConfig ? 180 : 0))
                        .animation(.spring(response: 0.30), value: showConfig)
                }
                .padding(18)
            }
            .buttonStyle(.plain)

            if showConfig {
                VStack(spacing: 12) {
                    Rectangle()
                        .fill(RituoPalette.white.opacity(0.05))
                        .frame(height: 1)
                        .padding(.horizontal, 18)

                    VStack(spacing: 8) {
                        SystemStatusRow(title: "Screen Time", value: viewModel.authorizationStatusText, isOn: viewModel.isAuthorized)
                        SystemStatusRow(title: "Selección", value: viewModel.selectionSummary, isOn: viewModel.selectedItemCount > 0)
                        SystemStatusRow(title: "Tag NFC", value: viewModel.registeredTagIdentifier == nil ? "Sin vincular" : "Vinculado", isOn: viewModel.registeredTagIdentifier != nil)
                    }
                    .padding(.horizontal, 18)

                    Rectangle()
                        .fill(RituoPalette.white.opacity(0.05))
                        .frame(height: 1)
                        .padding(.horizontal, 18)

                    VStack(spacing: 8) {
                        Button {
                            Task { await viewModel.requestAuthorization() }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "shield")
                                    .font(.system(size: 13, weight: .medium))
                                Text(viewModel.isAuthorized ? "Screen Time autorizado" : "Autorizar Screen Time")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(RituoPalette.deepOceanBlue)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RituoPalette.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(LoginPressButtonStyle())
                        .disabled(viewModel.isAuthorizing)

                        Button {
                            Task { await viewModel.openActivityPicker() }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Seleccionar aplicaciones")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(RituoPalette.white.opacity(0.65))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(RituoPalette.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .buttonStyle(LoginPressButtonStyle())

                        Button {
                            if !viewModel.hasClaimedNfcTag {
                                viewModel.requestNfcTagSetup()
                            } else if viewModel.isBlocking {
                                viewModel.endBlockWithTag()
                            } else {
                                viewModel.startBlockWithTag()
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "tag")
                                    .font(.system(size: 13, weight: .medium))
                                Text(viewModel.registeredTagIdentifier == nil ? "Registrar tag NFC" : "Usar tag NFC")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(RituoPalette.white.opacity(0.65))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(RituoPalette.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .buttonStyle(LoginPressButtonStyle())
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(focusCard)
    }

    // MARK: - Shared card background

    private var focusCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    // MARK: - Computed

    private var dailyAverageMinutes: Int {
        guard let summary = viewModel.focusMetricsSummary, summary.focusDays > 0 else { return 0 }
        return summary.totalFocusMinutes / summary.focusDays
    }

    private var weeklyTotalMinutes: Int {
        weeklyFocusData.reduce(0) { $0 + $1.minutes }
    }

    private var focusTotalText: String {
        let mins = viewModel.focusMetricsSummary?.totalFocusMinutes ?? 0
        let h = mins / 60; let m = mins % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var weeklyFocusData: [DayFocusData] {
        let calendar = Calendar.current
        var dayMinutes: [Int: Int] = [:]

        for day in viewModel.focusMetricsSummary?.weeklyFocus ?? [] {
            guard let date = parseMetricDay(day.date) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            dayMinutes[weekday, default: 0] += day.totalFocusMinutes
        }

        let now = Date()
        let today = calendar.component(.weekday, from: now)
        let order: [(Int, String)] = [(2,"L"),(3,"M"),(4,"M"),(5,"J"),(6,"V"),(7,"S"),(1,"D")]
        return order.map { (wd, label) in
            DayFocusData(label: label, minutes: dayMinutes[wd] ?? 0, isToday: wd == today)
        }
    }

    private var activityMaxMinutes: Int {
        let ritualMinutes = viewModel.schedulers.map { scheduler in
            viewModel.sessions(for: scheduler).reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) }
        }
        let modeMinutes = viewModel.modes.map { mode in
            viewModel.sessions(for: mode).reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) }
        }
        return (ritualMinutes + modeMinutes).max() ?? 0
    }

    private func parseMetricDay(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

// MARK: - Supporting types

struct DayFocusData: Identifiable {
    let id = UUID()
    let label: String
    let minutes: Int
    let isToday: Bool
}

// MARK: - Focus stat tile

struct FocusStatTile: View {
    let symbol: String
    let value: String
    let label: String
    let tint: Color
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)

            if isLoading {
                RituoLoadingBar(width: 52, height: 18)
            } else {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RituoPalette.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(RituoPalette.white.opacity(0.38))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
                }
        )
        .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
    }
}

// MARK: - Activity focus row

private struct FocusActivityRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let minutes: Int
    let completed: Int
    let progress: Double
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tint.opacity(0.12))
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tint)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(RituoPalette.white.opacity(0.38))
                }

                Spacer()

                if isLoading {
                    RituoLoadingBar(width: 40, height: 12)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(minutesText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RituoPalette.white)
                        Text("\(completed) sesiones")
                            .font(.system(size: 10))
                            .foregroundStyle(RituoPalette.white.opacity(0.35))
                    }
                }
            }

            if !isLoading && progress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(RituoPalette.white.opacity(0.07)).frame(height: 3)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [tint, RituoPalette.white.opacity(0.80)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * min(progress, 1), height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var minutesText: String {
        let h = minutes / 60; let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
