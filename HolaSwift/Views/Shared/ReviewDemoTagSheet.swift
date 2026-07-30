import SwiftUI
import UIKit

struct ReviewDemoTagSheet: View {
    let prompt: ReviewDemoTagPrompt
    let onCompleted: () -> Void
    let onCancelled: () -> Void

    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false

    var body: some View {
        ZStack {
            RituoPalette.deepOceanBlue
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Capsule()
                    .fill(RituoPalette.white.opacity(0.20))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)

                Spacer(minLength: 8)

                VStack(spacing: 12) {
                    Text("CUENTA DE DEMOSTRACIÓN")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(RituoPalette.lightBlue)

                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(RituoPalette.white)
                        .frame(width: 92, height: 92)
                        .background(RituoPalette.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    Text(prompt.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(RituoPalette.white)
                        .multilineTextAlignment(.center)

                    Text(prompt.message)
                        .font(.system(size: 16))
                        .foregroundStyle(RituoPalette.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 14)
                }

                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Capsule()
                            .fill(RituoPalette.white)

                        GeometryReader { proxy in
                            Capsule()
                                .fill(RituoPalette.lightBlue.opacity(0.38))
                                .frame(
                                    width: proxy.size.width * holdProgress,
                                    height: proxy.size.height
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 10) {
                            Image(systemName: isHolding ? "hand.tap.fill" : "hand.tap")
                            Text(isHolding ? "Seguí presionando…" : "Mantené presionado")
                        }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(RituoPalette.deepOceanBlue)
                    }
                    .frame(height: 60)
                    .contentShape(Capsule())
                    .onLongPressGesture(
                        minimumDuration: 2.0,
                        maximumDistance: 44,
                        pressing: updateHoldingState
                    ) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onCompleted()
                    }

                    Button("Cancelar", action: onCancelled)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RituoPalette.white.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
    }

    private func updateHoldingState(_ pressing: Bool) {
        isHolding = pressing

        if pressing {
            holdProgress = 0
            withAnimation(.linear(duration: 2.0)) {
                holdProgress = 1
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                holdProgress = 0
            }
        }
    }
}
