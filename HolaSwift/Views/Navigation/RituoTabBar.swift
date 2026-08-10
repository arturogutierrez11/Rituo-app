import SwiftUI

struct RituoFloatingTabBar: View {
    @Binding var selectedTab: RootTab
    @Namespace private var ns

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(RootTab.allCases, id: \.self) { tab in
                    RituoTabItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: ns
                    )
                    .frame(width: geo.size.width / CGFloat(RootTab.allCases.count))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .background {
                Capsule(style: .continuous)
                    .fill(Color(red: 0.11, green: 0.14, blue: 0.24))
                    .shadow(color: .black.opacity(0.48), radius: 24, x: 0, y: 8)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(RituoPalette.white.opacity(0.09), lineWidth: 1)
            }
        }
        .frame(height: 66)
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
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
    let namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 5) {
            // Icon
            ZStack {
                // Glow behind selected icon
                if isSelected {
                    Circle()
                        .fill(RituoPalette.white.opacity(0.10))
                        .blur(radius: 8)
                        .frame(width: 36, height: 36)
                        .matchedGeometryEffect(id: "glow", in: namespace)
                }

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
