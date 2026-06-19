import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct RituoAnimatedBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Image("RituoAppBackground")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }
}

struct RituoPulseMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(RituoPalette.lightBlue, lineWidth: 4)
                .frame(width: 38, height: 38)

            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(RituoPalette.lightBlue)
                    .frame(width: 4, height: CGFloat(11 + index * 5))
                    .offset(x: CGFloat(index - 1) * 7)
            }
        }
    }
}

struct ProfileIdentityRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.custom("Helvetica", size: 12).weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(RituoPalette.dimText)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.custom("Helvetica", size: 15).weight(.semibold))
                .foregroundStyle(RituoPalette.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RituoPalette.softPanel)
        )
    }
}

struct ProfileStateTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.custom("Helvetica", size: 16).weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Helvetica", size: 11).weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(RituoPalette.dimText)
                    .lineLimit(1)

                Text(value)
                    .font(.custom("Helvetica", size: 15).weight(.semibold))
                    .foregroundStyle(RituoPalette.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RituoPalette.softPanel)
        )
    }
}

struct FuturisticCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RituoPalette.panel)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(RituoPalette.stroke, lineWidth: 1)
        }

    }
}

struct PanelEyebrow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.custom("Helvetica", size: 11).weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(RituoPalette.dimText)
    }
}

struct StatusOrb: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(RituoPalette.glow)
                .frame(width: 10, height: 10)
                .shadow(color: RituoPalette.glow.opacity(0.7), radius: 8)

            Text(title)
                .font(.custom("Helvetica", size: 14).weight(.bold))
            Text(subtitle)
                .font(.custom("Helvetica", size: 10).weight(.medium))
                .foregroundStyle(RituoPalette.dimText)
        }
        .foregroundStyle(RituoPalette.text)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RituoPalette.softPanel)
        )
    }
}

struct MiniOrb: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill((isOn ? RituoPalette.success : RituoPalette.dimText).opacity(0.18))
                .frame(width: 44, height: 44)

            Circle()
                .fill(isOn ? RituoPalette.success : RituoPalette.dimText)
                .frame(width: 12, height: 12)
        }
    }
}

struct MetricCapsule: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.custom("Helvetica", size: 19).weight(.bold))
                .foregroundStyle(RituoPalette.text)
            Text(label)
                .font(.custom("Helvetica", size: 11).weight(.semibold))
                .foregroundStyle(RituoPalette.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RituoPalette.softPanel)
        )
    }
}

struct InfoPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Helvetica", size: 16).weight(.bold))
                .foregroundStyle(RituoPalette.text)
                .multilineTextAlignment(.center)
            Text(label)
                .font(.custom("Helvetica", size: 11).weight(.semibold))
                .foregroundStyle(RituoPalette.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RituoPalette.softPanel)
        )
    }
}

struct MessageStrip: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.custom("Helvetica", size: 13).weight(.medium))
                .foregroundStyle(RituoPalette.subtext)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.09))
        )
    }
}

struct ActionTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: symbol)
                            .font(.custom("Helvetica", size: 18).weight(.semibold))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.custom("Helvetica", size: 14).weight(.bold))
                        .foregroundStyle(RituoPalette.dimText)
                }

                Text(title)
                    .font(.custom("Helvetica", size: 18).weight(.semibold))
                    .foregroundStyle(RituoPalette.text)

                Text(subtitle)
                    .font(.custom("Helvetica", size: 12).weight(.medium))
                    .foregroundStyle(RituoPalette.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 162, alignment: .topLeading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(RituoPalette.panel)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(RituoPalette.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.5 : 1)
        .disabled(isDisabled)
    }
}

struct SchedulerMiniStrip: View {
    let scheduler: RitualScheduler
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(RituoPalette.accent.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: scheduler.symbolName)
                    .font(.custom("Helvetica", size: 17).weight(.semibold))
                    .foregroundStyle(RituoPalette.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(scheduler.title)
                        .font(.custom("Helvetica", size: 17).weight(.semibold))
                        .foregroundStyle(RituoPalette.text)

                    if isSelected {
                        InlineBadge(text: "Preparado", tint: RituoPalette.glow)
                    }
                }
                Text("\(scheduler.weekdayText) · \(scheduler.timeRangeText)")
                    .font(.custom("Helvetica", size: 12).weight(.medium))
                    .foregroundStyle(RituoPalette.subtext)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RituoPalette.softPanel)
        )
    }
}

struct SchedulerHighlightCard: View {
    let scheduler: RitualScheduler
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(RituoPalette.accent.opacity(0.14))
                        .frame(width: 48, height: 48)

                    Image(systemName: scheduler.symbolName)
                        .font(.custom("Helvetica", size: 18).weight(.semibold))
                        .foregroundStyle(RituoPalette.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(scheduler.title)
                            .font(.custom("Helvetica", size: 22).weight(.semibold))
                            .foregroundStyle(RituoPalette.text)

                        if scheduler.isActive() {
                            InlineBadge(text: "Activo ahora", tint: RituoPalette.success)
                        } else if isSelected {
                            InlineBadge(text: "Seleccionado", tint: RituoPalette.glow)
                        }
                    }

                    Text(scheduler.detail)
                        .font(.custom("Helvetica", size: 13).weight(.medium))
                        .foregroundStyle(RituoPalette.subtext)
                }
            }

            HStack(spacing: 12) {
                InfoPill(value: scheduler.weekdayText, label: "Dias")
                InfoPill(value: scheduler.timeRangeText, label: "Horario")
            }

            HStack(spacing: 12) {
                InfoPill(value: "\(scheduler.appCount)", label: "Apps")
                InfoPill(value: "\(scheduler.categoryCount)", label: "Categorias")
                InfoPill(value: "\(scheduler.domainCount)", label: "Web")
            }

            ProfileRow(label: "Bloquea", value: scheduler.focusTarget)
            ProfileRow(label: "Seleccion", value: scheduler.selectionDigest)
            AppSelectionPreview(selection: scheduler.selection)
        }
    }
}

struct AppSelectionPreview: View {
    let selection: FamilyActivitySelection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if applicationTokens.isEmpty && categoryTokens.isEmpty && domainTokens.isEmpty {
                Text("Todavia no hay items seleccionados para mostrar.")
                    .font(.custom("Helvetica", size: 13).weight(.medium))
                    .foregroundStyle(RituoPalette.subtext)
            } else {
                if !applicationTokens.isEmpty {
                    previewSection(title: "Apps") {
                        ForEach(applicationTokens, id: \.self) { token in
                            Label(token)
                        }
                    }
                }

                if !categoryTokens.isEmpty {
                    previewSection(title: "Categorias") {
                        ForEach(categoryTokens, id: \.self) { token in
                            Label(token)
                        }
                    }
                }

                if !domainTokens.isEmpty {
                    previewSection(title: "Web") {
                        ForEach(domainTokens, id: \.self) { token in
                            Label(token)
                        }
                    }
                }
            }
        }
    }

    private var applicationTokens: [ApplicationToken] {
        Array(selection.applicationTokens.prefix(4))
    }

    private var categoryTokens: [ActivityCategoryToken] {
        Array(selection.categoryTokens.prefix(3))
    }

    private var domainTokens: [WebDomainToken] {
        Array(selection.webDomainTokens.prefix(3))
    }

    @ViewBuilder
    private func previewSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Helvetica", size: 11).weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(RituoPalette.dimText)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .font(.custom("Helvetica", size: 13).weight(.medium))
            .foregroundStyle(RituoPalette.text)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RituoPalette.softPanel)
        )
    }
}

struct InlineBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.custom("Helvetica", size: 11).weight(.bold))
            .foregroundStyle(RituoPalette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint))
    }
}

struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.custom("Helvetica", size: 13).weight(.semibold))
                .foregroundStyle(RituoPalette.dimText)

            Spacer()

            Text(value)
                .font(.custom("Helvetica", size: 13).weight(.semibold))
                .foregroundStyle(RituoPalette.text)
        }
    }
}

struct PrimaryGlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Helvetica", size: 16).weight(.semibold))
            .foregroundStyle(RituoPalette.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(RituoPalette.glow.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct SecondaryGlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Helvetica", size: 15).weight(.semibold))
            .foregroundStyle(RituoPalette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(RituoPalette.softPanel.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(RituoPalette.stroke, lineWidth: 1)
            }
    }
}
