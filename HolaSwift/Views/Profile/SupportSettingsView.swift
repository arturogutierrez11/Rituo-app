import SwiftUI

struct SupportSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            profileSectionLabel("Soporte")
            VStack(spacing: 0) {
                supportLink(
                    symbol: "envelope",
                    label: "Email",
                    detail: "hello@rituo.io",
                    url: "mailto:hello@rituo.io"
                )

                profileRowDivider

                supportLink(
                    symbol: "phone",
                    label: "WhatsApp",
                    detail: "+54 9 11 5847-9025",
                    url: "https://wa.me/5491158479025"
                )

                profileRowDivider

                supportLink(
                    symbol: "camera",
                    label: "Instagram",
                    detail: "@rituo.io",
                    url: "https://www.instagram.com/rituo.io?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw=="
                )

                profileRowDivider

                supportLink(
                    symbol: "briefcase",
                    label: "LinkedIn",
                    detail: "rituo.io",
                    url: "https://www.linkedin.com/company/rituo-io/"
                )
            }
            .background(profileCardBg)
        }
    }

    @ViewBuilder
    private func supportLink(
        symbol: String,
        label: String,
        detail: String,
        url: String
    ) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                profileLinkRowFn(symbol: symbol, label: label, detail: detail)
            }
            .buttonStyle(.plain)
        } else {
            profileLinkRowFn(symbol: symbol, label: label, detail: detail)
        }
    }
}
