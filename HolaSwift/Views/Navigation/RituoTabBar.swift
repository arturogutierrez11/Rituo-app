import SwiftUI

struct RituoFloatingTabBar: View {
    @Binding var selectedTab: RootTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                Button {
                    AppDiagnostics.shared.event("navigation.tap from=\(selectedTab) to=\(tab)")
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                        selectedTab = tab
                    }
                } label: {
                    RituoTabItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
                    .background {
                        if selectedTab == tab {
                            selectionGlass
                                .padding(.horizontal, 4)
                                .padding(.vertical, 6)
                                .matchedGeometryEffect(id: "selectionGlass", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                .accessibilityIdentifier("tab.\(tab)")
            }
        }
        .background {
            ZStack {
                // Frosted glass: blurs whatever scrolls underneath the bar.
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // Rituo blue tint so the glass stays on-brand instead of going grey.
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RituoPalette.darkCanteen.opacity(0.62),
                                RituoPalette.deepOceanBlue.opacity(0.58)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Soft light falling from the top edge.
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RituoPalette.mistBlue.opacity(0.22),
                                RituoPalette.lightBlue.opacity(0.04),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: RituoPalette.deepOceanBlue.opacity(0.55), radius: 24, x: 0, y: 10)
        }
        .overlay {
            // Specular rim: bright at the top, fading toward the bottom.
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            RituoPalette.mistBlue.opacity(0.50),
                            RituoPalette.lightBlue.opacity(0.12),
                            RituoPalette.lightBlue.opacity(0.26)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 22)
    }

    /// Glass pill that marks the current tab and slides between tabs.
    private var selectionGlass: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            RituoPalette.lightBlue.opacity(0.46),
                            RituoPalette.darkCanteen.opacity(0.26)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            RituoPalette.mistBlue.opacity(0.70),
                            RituoPalette.lightBlue.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: RituoPalette.lightBlue.opacity(0.35), radius: 12, y: 0)
        .allowsHitTesting(false)
    }
}

// MARK: - Rituo symbol icon (ø)

struct RituoSymbolIcon: View {
    let size: CGFloat
    let color: Color
    let opacity: Double

    init(
        size: CGFloat,
        color: Color = RituoPalette.white,
        opacity: Double = 1
    ) {
        self.size = size
        self.color = color
        self.opacity = opacity
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(color.opacity(opacity), lineWidth: size * 0.13)
                .frame(width: size, height: size)
            Rectangle()
                .fill(color.opacity(opacity))
                .frame(width: size * 1.18, height: size * 0.13)
                .clipShape(Capsule())
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Tab item

private struct RituoTabItem: View {
    let tab: RootTab
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            // Icon
            ZStack {
                if tab == .home {
                    RituoSymbolIcon(size: 20, opacity: isSelected ? 1.0 : 0.30)
                } else {
                    Image(systemName: isSelected ? tab.selectedSymbolName : tab.symbolName)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isSelected ? RituoPalette.white : RituoPalette.white.opacity(0.30))
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                }
            }
            .frame(width: 28, height: 28)

            // Label
            Text(tab.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? RituoPalette.white : RituoPalette.white.opacity(0.30))

            // Active dot
            Circle()
                .fill(RituoPalette.white)
                .frame(width: 3, height: 3)
                .opacity(isSelected ? 1 : 0)
                .scaleEffect(isSelected ? 1 : 0.3)
                .shadow(color: RituoPalette.white.opacity(0.80), radius: 4)
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.72), value: isSelected)
    }
}
