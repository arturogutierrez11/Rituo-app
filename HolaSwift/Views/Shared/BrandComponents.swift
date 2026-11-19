import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

struct BrandScreenHeader: View {
    let eyebrow: String
    let quote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center) {
                Image("RituoLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112)
                Spacer()
                Text(eyebrow.uppercased())
                    .font(.custom("Helvetica", size: 9).weight(.bold))
                    .tracking(3.0)
                    .foregroundStyle(RituoPalette.mistBlue.opacity(0.72))
            }

            Text("\u{201C}\(quote)\u{201D}")
                .font(.custom("Helvetica", size: 14).weight(.medium))
                .foregroundStyle(RituoPalette.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
        }
    }
}

struct BrandPanel<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RituoPalette.glassBlue.opacity(0.88),
                                RituoPalette.inkBlue.opacity(0.93)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                RituoPalette.mistBlue.opacity(0.26),
                                RituoPalette.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: RituoPalette.inkBlue.opacity(0.20), radius: 18, x: 0, y: 10)
    }
}

struct RituoLoadingBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    @State private var breathes = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        RituoPalette.white.opacity(breathes ? 0.08 : 0.16),
                        RituoPalette.lightBlue.opacity(breathes ? 0.22 : 0.10),
                        RituoPalette.white.opacity(breathes ? 0.08 : 0.16)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: breathes)
            .onAppear { breathes = true }
    }
}

struct RituoLoadingPanel: View {
    let title: String

    var body: some View {
        BrandPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title)
                        .font(.custom("Helvetica", size: 14).weight(.bold))
                        .foregroundStyle(RituoPalette.white.opacity(0.70))
                    Spacer()
                    ProgressView()
                        .tint(RituoPalette.lightBlue)
                }

                RituoLoadingBar(width: 170, height: 12)
                RituoLoadingBar(height: 54)
                RituoLoadingBar(height: 54)
            }
        }
    }
}

struct BrandMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.custom("Helvetica", size: 11).weight(.bold))
                .tracking(1.2)
                .foregroundStyle(RituoPalette.white.opacity(0.70))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(.custom("Helvetica", size: 20).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RituoPalette.white.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RituoPalette.mistBlue.opacity(0.12), lineWidth: 1)
        }
    }
}

struct SystemStatusRow: View {
    let title: String
    let value: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isOn ? RituoPalette.lightBlue : RituoPalette.white.opacity(0.28))
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Helvetica", size: 13).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                Text(value)
                    .font(.custom("Helvetica", size: 11).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.64))
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}

struct SchedulerCompactRow: View {
    let scheduler: RitualScheduler
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: scheduler.symbolName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RituoPalette.deepOceanBlue)
                .frame(width: 34, height: 34)
                .background(RituoPalette.white.opacity(0.92))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(scheduler.title)
                    .font(.custom("Helvetica", size: 14).weight(.bold))
                    .foregroundStyle(RituoPalette.white)
                Text("\(scheduler.weekdayText) · \(scheduler.timeRangeText)")
                    .font(.custom("Helvetica", size: 11).weight(.medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.64))
            }

            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(RituoPalette.white.opacity(0.08)))
    }
}

struct SchedulerHomeTile: View {
    let scheduler: RitualScheduler
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: tileSymbol)
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Color.black)

                Spacer()

                if isSelected {
                    Circle()
                        .fill(RituoPalette.white)
                        .frame(width: 9, height: 9)
                }
            }

            Spacer(minLength: 0)

            Text(scheduler.title)
                .font(.custom("Helvetica", size: 16).weight(.bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1)

            Text(scheduler.timeRangeText)
                .font(.custom("Helvetica", size: 11).weight(.medium))
                .foregroundStyle(RituoPalette.white.opacity(0.62))
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.27, green: 0.35, blue: 0.45),
                            Color(red: 0.08, green: 0.10, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? RituoPalette.white.opacity(0.70) : RituoPalette.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityLabel(scheduler.title)
    }

    private var tileSymbol: String {
        let title = scheduler.title.lowercased()

        if title.contains("lect") || title.contains("read") || title.contains("book") {
            return "book.closed.fill"
        }

        if title.contains("work") || title.contains("gym") || title.contains("entren") || title.contains("focus") {
            return "dumbbell.fill"
        }

        if title.contains("med") || title.contains("sleep") || title.contains("calma") {
            return "figure.mind.and.body"
        }

        return scheduler.symbolName
    }
}

struct AddSchedulerHomeTile: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.system(size: 43, weight: .black))
                .foregroundStyle(Color.black)

            Text("Nuevo")
                .font(.custom("Helvetica", size: 16).weight(.bold))
                .foregroundStyle(RituoPalette.white)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.27, green: 0.35, blue: 0.45),
                            Color(red: 0.08, green: 0.10, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RituoPalette.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityLabel("Crear scheduler")
    }
}

struct DemoAppIcon: View {
    enum Kind {
        case instagram
        case tiktok
    }

    let kind: Kind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(background)
                .frame(width: 44, height: 44)

            Text(label)
                .font(.system(size: kind == .instagram ? 24 : 27, weight: .black, design: .rounded))
                .foregroundStyle(RituoPalette.white)
        }
    }

    private var label: String {
        switch kind {
        case .instagram: return "◎"
        case .tiktok: return "♪"
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .instagram:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.pink, .orange, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .tiktok:
            return AnyShapeStyle(Color.black)
        }
    }
}


/// Frosted glass in a capsule, matching the floating tab bar:
/// blur + tint + light from the top edge + a specular rim.
struct RituoGlassCapsule: View {
    enum Tint {
        /// Rituo-blue glass, for use over light text.
        case blue
        /// Milky white glass, for use under dark text.
        case white
    }

    var tint: Tint = .blue

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, tint == .white ? .light : .dark)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: tintColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            RituoPalette.white.opacity(tint == .white ? 0.55 : 0.26),
                            RituoPalette.white.opacity(0.04),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: rimColors,
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: shadowColor, radius: 22, x: 0, y: 10)
        .shadow(color: glowColor, radius: 18, x: 0, y: 0)
        .allowsHitTesting(false)
    }

    private var tintColors: [Color] {
        switch tint {
        case .blue:
            return [
                RituoPalette.lightBlue.opacity(0.42),
                RituoPalette.darkCanteen.opacity(0.52),
                RituoPalette.deepOceanBlue.opacity(0.50)
            ]
        case .white:
            return [
                RituoPalette.white.opacity(0.88),
                RituoPalette.white.opacity(0.74)
            ]
        }
    }

    private var rimColors: [Color] {
        switch tint {
        case .blue:
            return [
                RituoPalette.mistBlue.opacity(0.65),
                RituoPalette.lightBlue.opacity(0.14),
                RituoPalette.lightBlue.opacity(0.30)
            ]
        case .white:
            return [
                RituoPalette.white.opacity(0.95),
                RituoPalette.white.opacity(0.35),
                RituoPalette.white.opacity(0.60)
            ]
        }
    }

    private var shadowColor: Color {
        tint == .white
            ? Color.black.opacity(0.18)
            : RituoPalette.deepOceanBlue.opacity(0.55)
    }

    private var glowColor: Color {
        tint == .white
            ? RituoPalette.white.opacity(0.28)
            : RituoPalette.lightBlue.opacity(0.18)
    }
}
