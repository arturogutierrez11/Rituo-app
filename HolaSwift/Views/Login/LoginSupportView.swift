import SwiftUI

struct LoginSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar

                Rectangle()
                    .fill(RituoPalette.white.opacity(0.06))
                    .frame(height: 1)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Image(systemName: "questionmark.bubble.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(RituoPalette.lightBlue)
                                .frame(width: 76, height: 76)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(RituoPalette.lightBlue.opacity(0.11))
                                )

                            Text("¿Necesitás ayuda?")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(RituoPalette.white)

                            Text("Contactanos si tenés problemas para ingresar o si alguna restricción quedó activa.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(RituoPalette.white.opacity(0.48))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                        SupportSettingsView()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
        }
    }

    private var navigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RituoPalette.white.opacity(0.48))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(RituoPalette.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar soporte")

            Spacer()

            Text("Soporte")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RituoPalette.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }
}
