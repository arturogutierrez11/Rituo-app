import AuthenticationServices
import FamilyControls
import ManagedSettings
import SwiftUI

enum RituoPalette {
    static let white = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let lightBlue = Color(red: 0.61, green: 0.70, blue: 0.78) // #9CB2C6
    static let darkCanteen = Color(red: 0.29, green: 0.36, blue: 0.47) // #495C78
    static let deepOceanBlue = Color(red: 0.13, green: 0.15, blue: 0.29) // #212749
    static let inkBlue = Color(red: 0.08, green: 0.12, blue: 0.18)
    static let mistBlue = Color(red: 0.74, green: 0.82, blue: 0.89)
    static let glassBlue = Color(red: 0.19, green: 0.26, blue: 0.35)

    static let background = white
    static let panel = white
    static let softPanel = Color(red: 0.95, green: 0.97, blue: 0.98)
    static let stroke = deepOceanBlue.opacity(0.12)
    static let text = Color.black
    static let subtext = darkCanteen
    static let dimText = darkCanteen.opacity(0.72)
    static let glow = deepOceanBlue
    static let accent = lightBlue
    static let success = Color(red: 0.05, green: 0.48, blue: 0.17)
    static let danger = Color(red: 0.78, green: 0.12, blue: 0.13)
}

struct RituoBackground: View {
    var body: some View {
        RituoPalette.background
    }
}

struct GoogleIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)

            Text("G")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.52, blue: 0.96),
                            Color(red: 0.92, green: 0.26, blue: 0.21),
                            Color(red: 0.98, green: 0.74, blue: 0.02),
                            Color(red: 0.20, green: 0.66, blue: 0.32)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
