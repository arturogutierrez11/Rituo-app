import Combine
import SwiftUI

// MARK: - View model

@MainActor
final class RankingViewModel: ObservableObject {
    enum LoadState {
        case idle
        case loading
        case loaded(RankingResponse)
        case failed(String)
    }

    @Published private(set) var state: LoadState
    @Published private(set) var refreshError: String?
    @Published private(set) var isRefreshing = false

    private var loadRevision = UUID()

    init(state: LoadState = .idle) {
        self.state = state
    }

    private let coreApi = CoreApiService.shared

    var ranking: RankingResponse? {
        if case let .loaded(ranking) = state { return ranking }
        return nil
    }

    /// Carga el ranking. Si ya hay datos los conserva mientras refresca
    /// y avisa si el refresco falla. Solo la última carga puede publicar cambios.
    func load(accessToken: String) async {
        guard !Task.isCancelled else { return }
        let revision = UUID()
        loadRevision = revision
        isRefreshing = true
        refreshError = nil
        if ranking == nil { state = .loading }
        defer {
            if loadRevision == revision { isRefreshing = false }
        }

        do {
            let result = try await coreApi.getRanking(accessToken: accessToken)
            try Task.checkCancellation()
            guard loadRevision == revision else { return }
            state = .loaded(result)
        } catch is CancellationError {
            guard loadRevision == revision else { return }
            restoreAfterCancellation()
        } catch CoreAPIError.cancelled {
            guard loadRevision == revision else { return }
            restoreAfterCancellation()
        } catch {
            guard loadRevision == revision else { return }
            guard !Task.isCancelled else {
                restoreAfterCancellation()
                return
            }
            AppDiagnostics.shared.event("ranking.load.failed error=\(error.localizedDescription)")
            if ranking == nil {
                state = .failed(error.localizedDescription)
            } else {
                refreshError = "No pudimos actualizar el ranking."
            }
        }
    }

    /// Una tarea cancelada (cambio de pestaña, refresh nuevo) no es un error:
    /// si no había datos, volvemos a `idle` para que la próxima carga arranque limpia.
    private func restoreAfterCancellation() {
        if case .loading = state { state = .idle }
    }
}

// MARK: - Page

struct RankingPage: View {
    let accessToken: String?

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: RankingViewModel
    @State private var appeared = false
    @State private var shareSnapshot: RankingShareSnapshot?
    @State private var sharingFailed = false

    @MainActor
    init(accessToken: String?, viewModel: RankingViewModel? = nil) {
        self.accessToken = accessToken
        _viewModel = StateObject(wrappedValue: viewModel ?? RankingViewModel())
    }

    private let gold = Color(red: 0.99, green: 0.80, blue: 0.30)
    private let silver = Color(red: 0.80, green: 0.85, blue: 0.92)
    private let bronze = Color(red: 0.88, green: 0.58, blue: 0.38)

    private struct LoadTrigger: Equatable {
        let accessToken: String?
        let isActive: Bool
    }

    var body: some View {
        ZStack {
            RituoAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pageHeader

                    switch viewModel.state {
                    case .idle, .loading:
                        loadingContent
                    case let .failed(message):
                        errorCard(message: message)
                    case let .loaded(ranking):
                        loadedContent(ranking)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 62)
                .padding(.bottom, 140)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            }
            .refreshable { await reload() }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.40).delay(0.05)) { appeared = true }
        }
        .task(id: LoadTrigger(accessToken: accessToken, isActive: scenePhase == .active)) {
            guard scenePhase == .active else { return }
            await reload()
        }
        .sheet(item: $shareSnapshot) { snapshot in
            RankingSharePreview(snapshot: snapshot)
        }
        .alert("No pudimos preparar la imagen", isPresented: $sharingFailed) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text("Intentá compartir el ranking nuevamente.")
        }
    }

    private func reload() async {
        guard let accessToken, !accessToken.isEmpty else { return }
        await viewModel.load(accessToken: accessToken)
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ranking")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(RituoPalette.white)
                Text(headerSubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(RituoPalette.white.opacity(0.42))
            }
            Spacer(minLength: 0)
            Button {
                guard let ranking = viewModel.ranking else { return }
                shareSnapshot = RankingShareRenderer.snapshot(for: ranking, month: monthTitle(for: ranking))
                sharingFailed = shareSnapshot == nil
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(RituoPalette.white)
                    .frame(width: 46, height: 46)
                    .background(RituoGlassCapsule(tint: .blue))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.ranking == nil)
            .opacity(viewModel.ranking == nil ? 0.35 : 1)
            .accessibilityLabel("Compartir ranking")
            .accessibilityHint("Prepara una imagen para compartir tu posición y tiempo de foco")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSubtitle: String {
        guard let ranking = viewModel.ranking else { return "Quién enfoca más este mes" }
        let users = ranking.totalUsers == 1 ? "1 usuario usa la app" : "\(ranking.totalUsers) usuarios usan la app"
        return users
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ ranking: RankingResponse) -> some View {
        if viewModel.isRefreshing {
            HStack(spacing: 8) {
                ProgressView().tint(RituoPalette.lightBlue)
                Text("Actualizando ranking…")
                    .font(.system(size: 13))
                    .foregroundStyle(RituoPalette.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let message = viewModel.refreshError {
            refreshErrorCard(message: message)
        }

        myPositionCard(ranking)

        if ranking.entries.isEmpty {
            emptyCard
        } else {
            listCard(ranking)
        }
    }

    private func myPositionCard(_ ranking: RankingResponse) -> some View {
        let me = ranking.me

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TU POSICIÓN · \(monthTitle(for: ranking).uppercased())")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(RituoPalette.white.opacity(0.40))

                    if let position = me.position {
                        Text("#\(position)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    } else {
                        Text("Sin posición")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(RituoPalette.white)
                    }
                }

                Spacer(minLength: 12)

                let isPodium = (me.position ?? .max) <= 3
                Image(systemName: me.position == nil ? "trophy" : "trophy.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isPodium ? gold : RituoPalette.lightBlue)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(RituoPalette.white.opacity(0.08)))
            }

            Rectangle()
                .fill(RituoPalette.white.opacity(0.06))
                .frame(height: 1)

            if me.position == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Todavía no estás en el ranking")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RituoPalette.white)
                    Text("Completá una sesión de foco este mes para entrar.")
                        .font(.system(size: 13))
                        .foregroundStyle(RituoPalette.white.opacity(0.50))
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    heroMetric(title: "Tu foco", value: Self.duration(minutes: me.totalFocusMinutes))
                    Rectangle()
                        .fill(RituoPalette.white.opacity(0.08))
                        .frame(width: 1, height: 34)
                        .padding(.horizontal, 16)
                    heroMetric(title: "Compitiendo", value: "\(ranking.participants)")
                }
            }
        }
        .padding(20)
        .background(
            ZStack(alignment: .topTrailing) {
                cardBackground
                RadialGradient(
                    colors: [RituoPalette.lightBlue.opacity(0.20), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: 220
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(false)
            }
        )
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(RituoPalette.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RituoPalette.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - List

    private func listCard(_ ranking: RankingResponse) -> some View {
        let entries = ranking.entries
        // Si el usuario quedó fuera del top 100, su fila viene al final: la separamos visualmente.
        let isMeOutsideTop = entries.count > 100 && entries.last?.isMe == true

        return VStack(spacing: 0) {
            HStack {
                Text("TOP DEL MES")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(RituoPalette.white.opacity(0.40))
                Spacer()
                Text("\(ranking.participants) con foco")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RituoPalette.white.opacity(0.36))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if isMeOutsideTop, index == entries.count - 1 {
                    Text("• • •")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RituoPalette.white.opacity(0.30))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }

                rankingRow(entry)

                if index < entries.count - 1, !(isMeOutsideTop && index == entries.count - 2) {
                    Rectangle()
                        .fill(RituoPalette.white.opacity(0.05))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
            }

            Color.clear.frame(height: 8)
        }
        .background(cardBackground)
    }

    private func rankingRow(_ entry: RankingEntry) -> some View {
        HStack(spacing: 14) {
            positionBadge(entry.position)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label)
                    .font(.system(size: 15, weight: entry.isMe ? .bold : .medium))
                    .foregroundStyle(RituoPalette.white.opacity(entry.isMe ? 1 : 0.86))
                    .lineLimit(1)
                if entry.isMe {
                    Text("Vos")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RituoPalette.mistBlue)
                }
            }

            Spacer(minLength: 8)

            Text(Self.duration(minutes: entry.totalFocusMinutes))
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(RituoPalette.white.opacity(entry.isMe ? 1 : 0.70))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            if entry.isMe {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RituoPalette.lightBlue.opacity(0.30),
                                RituoPalette.darkCanteen.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(RituoPalette.mistBlue.opacity(0.35), lineWidth: 1)
                    }
                    .padding(.horizontal, 8)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func positionBadge(_ position: Int) -> some View {
        let color: Color? = switch position {
        case 1: gold
        case 2: silver
        case 3: bronze
        default: nil
        }

        if let color {
            ZStack {
                Circle().fill(color.opacity(0.18))
                Circle().strokeBorder(color.opacity(0.65), lineWidth: 1)
                Text("\(position)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 32, height: 32)
        } else {
            Text("\(position)")
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(RituoPalette.white.opacity(0.50))
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - States

    private func refreshErrorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "wifi.exclamationmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RituoPalette.white)
            Text("Seguís viendo los últimos datos cargados.")
                .font(.system(size: 13))
                .foregroundStyle(RituoPalette.white.opacity(0.65))
            Button {
                Task { await reload() }
            } label: {
                Text("Reintentar")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RituoPalette.white)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(RituoGlassCapsule(tint: .blue))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRefreshing)
            .accessibilityLabel("Reintentar actualización del ranking")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(RituoPalette.lightBlue)
            Text("El mes recién empieza")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RituoPalette.white)
            Text("Todavía nadie tiene foco registrado. Sé el primero en entrar al ranking.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(RituoPalette.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(cardBackground)
    }

    private var loadingContent: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 16) {
                RituoLoadingBar(width: 120, height: 12)
                RituoLoadingBar(width: 110, height: 44)
                RituoLoadingBar(height: 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(cardBackground)

            VStack(spacing: 18) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 14) {
                        RituoLoadingBar(width: 32, height: 32)
                        RituoLoadingBar(width: 140, height: 14)
                        Spacer()
                        RituoLoadingBar(width: 60, height: 14)
                    }
                }
            }
            .padding(20)
            .background(cardBackground)
        }
        .accessibilityLabel("Cargando ranking")
    }

    private func errorCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(RituoPalette.lightBlue)
            Text("No pudimos cargar el ranking")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RituoPalette.white)
            Text(message)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(RituoPalette.white.opacity(0.50))
                .lineLimit(3)

            Button {
                Task { await reload() }
            } label: {
                Text("Reintentar")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RituoPalette.deepOceanBlue)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(RituoGlassCapsule(tint: .white))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .background(cardBackground)
    }

    // MARK: - Shared

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(RituoPalette.white.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    /// Nombre del mes ("Noviembre") según `periodStart`, en la zona horaria del servidor.
    private func monthTitle(for ranking: RankingResponse) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackParser = ISO8601DateFormatter()

        guard let start = parser.date(from: ranking.periodStart) ?? fallbackParser.date(from: ranking.periodStart) else {
            return "Este mes"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.timeZone = TimeZone(identifier: ranking.timeZone) ?? .current
        formatter.dateFormat = "LLLL"
        return formatter.string(from: start).capitalized(with: formatter.locale)
    }

    private static func duration(minutes: Int) -> String {
        FocusSetupPage.compactDuration(minutes: minutes)
    }
}
