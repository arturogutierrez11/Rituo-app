import SwiftUI

struct RituoFloatingTabBar: View {
    @Binding var selectedTab: RootTab
    @Namespace private var activeNamespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    RituoFloatingTabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: activeNamespace
                    )
                }
                .buttonStyle(RituoTabButtonStyle())
            }
        }
        .padding(8)
        .background(RituoTabBarBackground())
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            RituoPalette.white.opacity(0.54),
                            RituoPalette.mistBlue.opacity(0.22),
                            RituoPalette.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            RituoPalette.white.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 22)
                .padding(.horizontal, 16)
                .blur(radius: 5)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 13)
        .shadow(color: RituoPalette.lightBlue.opacity(0.18), radius: 20, x: 0, y: -5)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

private struct RituoTabBarBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.35, blue: 0.52).opacity(0.70),
                    Color(red: 0.12, green: 0.17, blue: 0.30).opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    RituoPalette.white.opacity(0.18),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

struct RituoFloatingTabBarItem: View {
    let tab: RootTab
    let isSelected: Bool
    let namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: tab.symbolName)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                .frame(height: 23)

            Text(tab.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .foregroundStyle(
            isSelected
            ? RituoPalette.white
            : RituoPalette.white.opacity(0.86)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RituoPalette.white.opacity(0.20),
                                RituoPalette.mistBlue.opacity(0.10),
                                RituoPalette.deepOceanBlue.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .matchedGeometryEffect(id: "active-tab", in: namespace)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        RituoPalette.white.opacity(0.26),
                                        RituoPalette.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(isSelected ? 1 : 0.92)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
    }
}

private struct RituoTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
