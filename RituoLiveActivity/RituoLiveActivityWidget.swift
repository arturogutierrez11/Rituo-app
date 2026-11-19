import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RituoLiveActivityBundle: WidgetBundle {
    var body: some Widget { RituoLiveActivityWidget() }
}

struct RituoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RituoFocusActivityAttributes.self) { context in
            FocusActivityCard(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color(red: 0.06, green: 0.09, blue: 0.18))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.breakEndsAt == nil ? "moon.stars.fill" : "cup.and.saucer.fill")
                        .foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusActivityTimer(state: context.state, isStale: context.isStale)
                        .frame(maxWidth: 100)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.title).font(.headline).lineLimit(1)
                        Text(context.isStale ? "Abrí Rituo para actualizar" : context.state.breakEndsAt == nil ? "Tu tiempo de foco" : "Tiempo de recreo")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.isStale ? "clock.badge.questionmark" : context.state.breakEndsAt == nil ? "moon.stars.fill" : "cup.and.saucer.fill")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                FocusActivityTimer(state: context.state, isStale: context.isStale)
                    .font(.caption2).frame(maxWidth: 62)
            } minimal: {
                Image(systemName: context.isStale ? "clock" : "moon.stars.fill")
            }
            .keylineTint(.cyan)
        }
    }
}

private struct FocusActivityCard: View {
    let state: RituoFocusActivityAttributes.ContentState
    let isStale: Bool
    private var start: Date { state.breakStartedAt ?? state.startedAt }
    private var end: Date? { state.breakEndsAt ?? state.endsAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("rituo", systemImage: "moon.stars.fill").font(.caption.bold())
                Spacer()
                Text(isStale ? "Por actualizar" : state.breakEndsAt != nil ? "Recreo" : state.scheduled ? "Horario del ritual" : "Tiempo de foco")
                    .font(.caption).foregroundStyle(.white.opacity(0.75))
            }
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(state.title).font(.headline).lineLimit(2)
                Spacer(minLength: 0)
                FocusActivityTimer(state: state, isStale: isStale)
                    .font(.title2.bold()).frame(maxWidth: 125)
            }
            if isStale {
                Text("Hora prevista alcanzada. Abrí Rituo para actualizar el estado.")
                    .font(.caption).foregroundStyle(.white.opacity(0.75))
            } else if let end, end > start {
                ProgressView(timerInterval: start...end, countsDown: false)
                    .tint(.cyan).labelsHidden().accessibilityLabel("Progreso del tiempo programado")
                HStack {
                    Text(state.breakEndsAt == nil ? "Fin previsto" : "Fin del recreo")
                    Spacer()
                    Text(end, style: .time)
                }.font(.caption).foregroundStyle(.white.opacity(0.75))
            } else {
                Text("Sin hora de fin · Abrí Rituo para ver tu sesión")
                    .font(.caption).foregroundStyle(.white.opacity(0.75))
            }
        }
        .foregroundStyle(.white)
        .padding(20)
    }
}

private struct FocusActivityTimer: View {
    let state: RituoFocusActivityAttributes.ContentState
    let isStale: Bool
    var body: some View {
        if isStale {
            Image(systemName: "clock.badge.questionmark").accessibilityLabel("Estado por actualizar")
        } else if let end = state.breakEndsAt ?? state.endsAt {
            Text(timerInterval: min(state.breakStartedAt ?? state.startedAt, end)...end, countsDown: true)
                .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
        } else {
            Image(systemName: "infinity").accessibilityLabel("Sin hora de fin")
        }
    }
}
