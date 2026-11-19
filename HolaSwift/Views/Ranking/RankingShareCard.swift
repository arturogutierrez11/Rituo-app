import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Static artwork: does not capture the navigation bar, alerts or loading UI.
struct RankingShareCard: View {
    let ranking: RankingResponse
    let month: String

    private let accent = Color(red: 0.65, green: 0.80, blue: 1)
    private let gold = Color(red: 0.99, green: 0.80, blue: 0.30)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.23, blue: 0.40),
                                    Color(red: 0.04, green: 0.07, blue: 0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.22), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 340)

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    HStack(spacing: 6) {
                        RituoSymbolIcon(size: 21)
                        Text("rituo")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Text("RANKING DEL MES")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Menos distracciones.\nMás tiempo para mí.")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(month.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(accent)
                }

                positionCard

                if !ranking.entries.isEmpty {
                    podium
                }

                Spacer(minLength: 0)

                HStack {
                    Text("Cada minuto cuenta.")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("@rituo.io")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 48)
        }
        .foregroundStyle(.white)
        .frame(width: 360, height: 640)
    }

    private var positionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MI POSICIÓN")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(accent)
                    Text(ranking.me.position.map { "#\($0)" } ?? "Mi primer paso")
                        .font(.system(size: ranking.me.position == nil ? 27 : 58, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: 8)
                Image(systemName: ranking.me.position == nil ? "sparkles" : "trophy.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(gold)
                    .padding(12)
                    .background(Circle().fill(gold.opacity(0.12)))
            }

            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)

            HStack(alignment: .top, spacing: 16) {
                metric(title: "de foco este mes", value: FocusSetupPage.compactDuration(minutes: ranking.me.totalFocusMinutes))
                Spacer(minLength: 0)
                metric(title: ranking.participants == 1 ? "persona enfocándose" : "personas enfocándose",
                       value: "\(ranking.participants)")
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(accent.opacity(0.22), lineWidth: 1))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var podium: some View {
        VStack(spacing: 10) {
            ForEach(Array(ranking.entries.prefix(3))) { entry in
                HStack(spacing: 10) {
                    Text("\(entry.position)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(entry.position == 1 ? gold : accent)
                        .frame(width: 22)
                    Text(entry.isMe ? "Vos" : entry.label)
                        .font(.system(size: 12, weight: entry.isMe ? .bold : .medium))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(FocusSetupPage.compactDuration(minutes: entry.totalFocusMinutes))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .padding(.horizontal, 6)
    }
}

struct RankingShareSnapshot: Identifiable {
    let id = UUID()
    let image: UIImage
    let pngData: Data
}

@MainActor
enum RankingShareRenderer {
    static func snapshot(for ranking: RankingResponse, month: String) -> RankingShareSnapshot? {
        let content = RankingShareCard(ranking: ranking, month: month)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, .medium)
            .environment(\.locale, Locale(identifier: "es_AR"))
        let renderer = ImageRenderer(content: content)
        // 9:16 artwork at 1080 × 1920 pixels, regardless of the device's scale.
        renderer.scale = 3
        renderer.isOpaque = true
        guard let image = renderer.uiImage, let pngData = image.pngData() else { return nil }
        return RankingShareSnapshot(image: image, pngData: pngData)
    }
}

private struct RankingSharePNG: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName("rituo-ranking.png")
    }
}

struct RankingSharePreview: View {
    let snapshot: RankingShareSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(uiImage: snapshot.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel("Imagen con tu posición y tiempo de foco del mes")
                    .frame(maxHeight: .infinity)

                Text("Lista para tus historias. Compartila o guardala para subirla a Instagram.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ShareLink(item: RankingSharePNG(data: snapshot.pngData),
                          preview: SharePreview("Mi ranking en Rituo", image: Image(uiImage: snapshot.image))) {
                    Label("Compartir imagen", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(RituoPalette.lightBlue)
            }
            .padding(20)
            .navigationTitle("Compartir ranking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
