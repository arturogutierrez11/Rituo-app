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
    @State private var selectedDayLabel: String?

    private let successGreen = Color(red: 0.30, green: 0.88, blue: 0.50)

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pageHeader
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)

                    heroCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.05), value: appeared)

                    weeklyChartCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.10), value: appeared)

                    sessionsCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.48, dampingFraction: 0.82).delay(0.14), value: appeared)

                    if !activityItems.isEmpty {
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Foco")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(RituoPalette.white)
            Text("Tu progreso de enfoque")
                .font(.system(size: 14))
                .foregroundStyle(RituoPalette.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero (tiempo total)

    private var heroCard: some View {
        let summary = viewModel.focusMetricsSummary
        let streak = summary?.currentStreakDays ?? 0

        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIEMPO TOTAL DE FOCO")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(RituoPalette.white.opacity(0.40))

                    if viewModel.isLoadingFocusMetrics {
                        RituoLoadingBar(width: 150, height: 40)
                    } else {
                        durationText(minutes: summary?.totalFocusMinutes ?? 0, bigSize: 42, smallSize: 22)
                    }
                }

                Spacer(minLength: 12)

                streakBadge(days: streak)
            }

            Rectangle()
                .fill(RituoPalette.white.opacity(0.06))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 0) {
                heroMetric(
                    title: "Promedio diario",
                    value: Self.compactDuration(minutes: dailyAverageMinutes)
                )
                heroMetricDivider
                heroMetric(
                    title: "Mejor día",
                    value: bestDayText
                )
                heroMetricDivider
                heroMetric(
                    title: "Días con foco",
                    value: "\(summary?.focusDays ?? 0)"
                )
            }
            .redacted(reason: viewModel.isLoadingFocusMetrics ? .placeholder : [])
        }
        .padding(20)
        .background(
            ZStack(alignment: .topTrailing) {
                focusCard
                RadialGradient(
                    colors: [RituoPalette.lightBlue.opacity(0.20), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: 220
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(false)
            }
        )
    }

    private func streakBadge(days: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.orange)
            Text(days == 1 ? "1 día" : "\(days) días")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RituoPalette.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.orange.opacity(0.14)))
        .overlay(Capsule().stroke(Color.orange.opacity(0.22), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Racha de \(days) \(days == 1 ? "día" : "días")")
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RituoPalette.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(RituoPalette.white.opacity(0.38))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroMetricDivider: some View {
        Rectangle()
            .fill(RituoPalette.white.opacity(0.06))
            .frame(width: 1, height: 30)
            .padding(.trailing, 14)
    }

    // MARK: - Weekly chart

    private var weeklyChartCard: some View {
        let data = weeklyFocusData
        let weekTotal = data.reduce(0) { $0 + $1.minutes }
        let maxValue = max(data.map(\.minutes).max() ?? 0, 1)
        let elapsedDays = max(data.filter { !$0.isFuture }.count, 1)
        let average = weekTotal / elapsedDays
        let selected = data.first { $0.label == selectedDayLabel }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Esta semana")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                    Text(selected.map { "\($0.fullName)" } ?? "Lunes a domingo")
                        .font(.system(size: 11))
                        .foregroundStyle(RituoPalette.white.opacity(0.38))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Self.compactDuration(minutes: selected?.minutes ?? weekTotal))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                        .monospacedDigit()
                    Text(selected == nil ? "total" : "ese día")
                        .font(.system(size: 11))
                        .foregroundStyle(RituoPalette.white.opacity(0.38))
                }
            }

            if viewModel.isLoadingFocusMetrics {
                RituoLoadingBar(height: 140).frame(height: 140)
            } else {
                Chart {
                    ForEach(data) { day in
                        BarMark(
                            x: .value("Día", day.label),
                            y: .value("Minutos", day.minutes),
                            width: .ratio(0.62)
                        )
                        .foregroundStyle(barStyle(for: day))
                        .cornerRadius(6)
                    }

                    if average > 0 && selected == nil {
                        RuleMark(y: .value("Promedio", average))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(RituoPalette.lightBlue.opacity(0.55))
                            .annotation(position: .top, alignment: .trailing, spacing: 2) {
                                Text("Prom. \(Self.compactDuration(minutes: average))")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(RituoPalette.lightBlue.opacity(0.80))
                            }
                    }
                }
                .chartXSelection(value: $selectedDayLabel)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, Self.niceCeiling(for: maxValue) / 2, Self.niceCeiling(for: maxValue)]) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(v == 0 ? "0" : Self.axisDuration(minutes: v))
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
                                let isToday = data.first { $0.label == label }?.isToday == true
                                Text(label)
                                    .font(.system(size: 11, weight: isToday ? .bold : .medium))
                                    .foregroundStyle(RituoPalette.white.opacity(isToday ? 0.90 : 0.45))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...Self.niceCeiling(for: maxValue))
                .frame(height: 140)
                .overlay {
                    if weekTotal == 0 {
                        Text("Sin foco registrado esta semana")
                            .font(.system(size: 12))
                            .foregroundStyle(RituoPalette.white.opacity(0.40))
                    }
                }
            }
        }
        .padding(20)
        .background(focusCard)
    }

    private func barStyle(for day: DayFocusData) -> AnyShapeStyle {
        if let selectedDayLabel {
            return day.label == selectedDayLabel
                ? AnyShapeStyle(LinearGradient(
                    colors: [RituoPalette.white, RituoPalette.lightBlue],
                    startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(RituoPalette.white.opacity(0.10))
        }
        if day.isToday {
            return AnyShapeStyle(LinearGradient(
                colors: [RituoPalette.white, RituoPalette.lightBlue],
                startPoint: .top, endPoint: .bottom))
        }
        return day.isFuture
            ? AnyShapeStyle(RituoPalette.white.opacity(0.05))
            : AnyShapeStyle(RituoPalette.lightBlue.opacity(0.30))
    }

    // MARK: - Sessions

    private var sessionsCard: some View {
        let summary = viewModel.focusMetricsSummary
        let total = summary?.totalSessions ?? 0
        let completed = summary?.completedSessions ?? 0
        let cancelled = summary?.cancelledSessions ?? 0
        let active = summary?.activeSessions ?? 0
        let rate = total > 0 ? Double(completed) / Double(total) : 0
        let rituals = summary?.ritualSessions ?? 0
        let modes = summary?.modeSessions ?? 0

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Sesiones")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RituoPalette.white)
                Spacer()
                Text(total == 1 ? "1 en total" : "\(total) en total")
                    .font(.system(size: 12))
                    .foregroundStyle(RituoPalette.white.opacity(0.38))
            }

            HStack(spacing: 22) {
                completionRing(rate: rate, hasData: total > 0)

                VStack(spacing: 12) {
                    legendRow(color: successGreen, title: "Completadas", value: completed)
                    legendRow(color: RituoPalette.danger.opacity(0.85), title: "Canceladas", value: cancelled)
                    legendRow(color: RituoPalette.lightBlue, title: "En curso", value: active)
                }
            }
            .redacted(reason: viewModel.isLoadingFocusMetrics ? .placeholder : [])

            if rituals + modes > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geo in
                        let share = Double(rituals) / Double(rituals + modes)
                        let rituralWidth = max(0, geo.size.width * share - 2)
                        HStack(spacing: 4) {
                            Capsule()
                                .fill(RituoPalette.lightBlue)
                                .frame(width: rituals == 0 ? 0 : rituralWidth)
                            Capsule()
                                .fill(RituoPalette.white.opacity(0.35))
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        splitLegend(color: RituoPalette.lightBlue, title: "Rituales", value: rituals)
                        Spacer()
                        splitLegend(color: RituoPalette.white.opacity(0.35), title: "Modos", value: modes)
                    }
                }
            }
        }
        .padding(20)
        .background(focusCard)
    }

    private func completionRing(rate: Double, hasData: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 9)
            Circle()
                .trim(from: 0, to: appeared ? rate : 0)
                .stroke(
                    AngularGradient(
                        colors: [RituoPalette.lightBlue, successGreen],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(rate, 0.01))
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8).delay(0.25), value: appeared)

            VStack(spacing: 1) {
                Text(hasData ? "\(Int((rate * 100).rounded()))%" : "–")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RituoPalette.white)
                    .monospacedDigit()
                Text("completadas")
                    .font(.system(size: 9))
                    .foregroundStyle(RituoPalette.white.opacity(0.38))
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasData ? "\(Int((rate * 100).rounded())) por ciento de sesiones completadas" : "Sin sesiones todavía")
    }

    private func legendRow(color: Color, title: String, value: Int) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(RituoPalette.white.opacity(0.65))
            Spacer()
            Text("\(value)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RituoPalette.white)
                .monospacedDigit()
        }
    }

    private func splitLegend(color: Color, title: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(title) · \(value)")
                .font(.system(size: 11))
                .foregroundStyle(RituoPalette.white.opacity(0.50))
        }
    }

    // MARK: - Activity breakdown

    private var activityBreakdown: some View {
        let items = activityItems
        let maxMinutes = items.map(\.minutes).max() ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Por actividad")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RituoPalette.white)
                Text("Tiempo de foco acumulado")
                    .font(.system(size: 11))
                    .foregroundStyle(RituoPalette.white.opacity(0.38))
            }
            .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    FocusActivityRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        symbol: item.symbol,
                        tint: item.tint,
                        minutes: item.minutes,
                        completed: item.completed,
                        progress: maxMinutes > 0 ? Double(item.minutes) / Double(maxMinutes) : 0,
                        isLoading: viewModel.isLoadingSessionHistories && item.sessionCount == 0,
                        usesRituoSymbol: item.usesRituoSymbol
                    )

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(RituoPalette.white.opacity(0.05))
                            .frame(height: 1)
                            .padding(.horizontal, 18)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(focusCard)
        }
    }

    private var activityItems: [FocusActivityItem] {
        let rituals = viewModel.schedulers.map { scheduler -> FocusActivityItem in
            let sessions = viewModel.sessions(for: scheduler)
            return FocusActivityItem(
                id: "ritual-\(scheduler.id.uuidString)",
                title: scheduler.title,
                subtitle: "\(scheduler.weekdayText) · \(scheduler.timeRangeText)",
                symbol: scheduler.symbolName,
                tint: RituoPalette.lightBlue,
                minutes: sessions.reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) },
                completed: sessions.filter { $0.status == "completed" }.count,
                sessionCount: sessions.count,
                usesRituoSymbol: false
            )
        }
        let modes = viewModel.modes.map { mode -> FocusActivityItem in
            let sessions = viewModel.sessions(for: mode)
            return FocusActivityItem(
                id: "mode-\(mode.id)",
                title: mode.title,
                subtitle: "Modo manual",
                symbol: mode.displaySymbolName,
                tint: mode.accentColor,
                minutes: sessions.reduce(0) { $0 + (($1.durationSeconds ?? 0) / 60) },
                completed: sessions.filter { $0.status == "completed" }.count,
                sessionCount: sessions.count,
                usesRituoSymbol: true
            )
        }
        return (rituals + modes).sorted { $0.minutes > $1.minutes }
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

    private var bestDayText: String {
        guard let best = weeklyFocusData.max(by: { $0.minutes < $1.minutes }),
              best.minutes > 0 else { return "–" }
        return "\(best.label) · \(Self.compactDuration(minutes: best.minutes))"
    }

    /// Monday-to-Sunday of the current week, matching the API's `weeklyFocus` window.
    private var weeklyFocusData: [DayFocusData] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "es_AR")

        var minutesByDay: [String: Int] = [:]
        for day in viewModel.focusMetricsSummary?.weeklyFocus ?? [] {
            minutesByDay[day.date, default: 0] += day.totalFocusMinutes
        }

        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        let labels = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
        let names = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return DayFocusData(
                label: labels[offset],
                fullName: names[offset],
                minutes: minutesByDay[formatter.string(from: date)] ?? 0,
                isToday: calendar.isDate(date, inSameDayAs: now),
                isFuture: date > startOfToday && !calendar.isDate(date, inSameDayAs: now)
            )
        }
    }

    // MARK: - Formatting

    private func durationText(minutes: Int, bigSize: CGFloat, smallSize: CGFloat) -> some View {
        let h = minutes / 60
        let m = minutes % 60
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            if h > 0 {
                Text("\(h)")
                    .font(.system(size: bigSize, weight: .bold))
                    .foregroundStyle(RituoPalette.white)
                Text("h")
                    .font(.system(size: smallSize, weight: .semibold))
                    .foregroundStyle(RituoPalette.white.opacity(0.55))
                    .padding(.trailing, 4)
            }
            if h == 0 || m > 0 {
                Text("\(m)")
                    .font(.system(size: h > 0 ? smallSize + 8 : bigSize, weight: .bold))
                    .foregroundStyle(h > 0 ? RituoPalette.white.opacity(0.85) : RituoPalette.white)
                Text("min")
                    .font(.system(size: smallSize, weight: .semibold))
                    .foregroundStyle(RituoPalette.white.opacity(0.55))
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(h > 0 ? "\(h) horas \(m) minutos" : "\(m) minutos")
    }

    static func compactDuration(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return m == 0 ? "\(h) h" : "\(h) h \(m) min" }
        return "\(m) min"
    }

    static func axisDuration(minutes: Int) -> String {
        if minutes >= 60 {
            let h = Double(minutes) / 60
            return h.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(h)) h" : String(format: "%.1f h", h)
        }
        return "\(minutes) m"
    }

    /// Rounds the chart ceiling up to a tidy value so grid lines land on round numbers.
    static func niceCeiling(for value: Int) -> Int {
        let steps = [20, 40, 60, 120, 180, 240, 360, 480, 720]
        if let step = steps.first(where: { $0 >= value }) { return step }
        return Int((Double(value) / 60).rounded(.up)) * 60
    }
}

// MARK: - Supporting types

struct DayFocusData: Identifiable {
    var id: String { label }
    let label: String
    let fullName: String
    let minutes: Int
    let isToday: Bool
    let isFuture: Bool
}

private struct FocusActivityItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let minutes: Int
    let completed: Int
    let sessionCount: Int
    let usesRituoSymbol: Bool
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
    var usesRituoSymbol = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tint.opacity(0.14))
                    if usesRituoSymbol {
                        RituoSymbolIcon(size: 16, color: tint)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(tint)
                    }
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
                        .lineLimit(1)
                }

                Spacer()

                if isLoading {
                    RituoLoadingBar(width: 40, height: 12)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FocusSetupPage.compactDuration(minutes: minutes))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RituoPalette.white)
                            .monospacedDigit()
                        Text(completed == 1 ? "1 sesión" : "\(completed) sesiones")
                            .font(.system(size: 10))
                            .foregroundStyle(RituoPalette.white.opacity(0.35))
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(RituoPalette.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [tint.opacity(0.70), tint],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: isLoading ? 0 : max(geo.size.width * min(progress, 1), progress > 0 ? 6 : 0))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}
