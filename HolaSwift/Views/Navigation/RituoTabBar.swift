import SwiftUI

// Reemplazo directo de Views/Navigation/RituoTabBar.swift
// Solo cambia el aspecto visual. La API (RituoFloatingTabBar(selectedTab:)) y
// el uso de RootTab / RituoPalette quedan idénticos.

struct RituoFloatingTabBar: View {
    @Binding var selectedTab: RootTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                RituoTabItem(tab: tab, isSelected: selectedTab == tab, namespace: ns)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                            selectedTab = tab
                        }
                    }
            }
        }
        .padding(8)
        .background {
            ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.14, blue: 0.26).opacity(0.78),
                            Color(red: 0.05, green: 0.07, blue: 0.16).opacity(0.86)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                Capsule(style: .continuous).fill(
                    LinearGradient(
                        colors: [RituoPalette.white.opacity(0.12), .clear],
                        startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)
                    )
                )
            }
        }
        .overlay {
            Capsule(style: .continuous).stroke(
                LinearGradient(
                    colors: [RituoPalette.white.opacity(0.30), RituoPalette.white.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.46), radius: 30, x: 0, y: 16)
        .shadow(color: RituoPalette.lightBlue.opacity(0.10), radius: 18, x: 0, y: -2)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

// MARK: - Tab item

private struct RituoTabItem: View {
    let tab: RootTab
    let isSelected: Bool
    let namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [RituoPalette.white.opacity(0.24), RituoPalette.lightBlue.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(id: "pill", in: namespace)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(RituoPalette.white.opacity(0.26), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.20), radius: 8, y: 3)
                        .frame(height: 38)
                        .padding(.horizontal, 6)
                }

                Image(systemName: isSelected ? tab.selectedSymbolName : tab.symbolName)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isSelected ? RituoPalette.white : RituoPalette.white.opacity(0.34))
                    .scaleEffect(isSelected ? 1.04 : 1)
            }
            .frame(height: 38)

            Text(tab.title)
                .font(.custom("Helvetica", size: 10).weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? RituoPalette.white : RituoPalette.white.opacity(0.34))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.30, dampingFraction: 0.76), value: isSelected)
    }
}
