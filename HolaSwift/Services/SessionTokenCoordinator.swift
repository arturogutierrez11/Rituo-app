import Foundation

/// One refresh per installed session, shared by auth restoration and core-api.
/// An old account's request must never be retried with a new account's token.
@MainActor
final class SessionTokenCoordinator {
    struct Snapshot: Equatable {
        let revision: UUID
        let accessToken: String
        let refreshToken: String
    }

    static let shared = SessionTokenCoordinator(
        load: {
            let store = KeychainTokenStore.shared
            guard let access = store.loadAccessToken(), let refresh = store.loadRefreshToken() else { return nil }
            return Snapshot(revision: store.sessionRevision, accessToken: access, refreshToken: refresh)
        },
        save: { tokens in
            try KeychainTokenStore.shared.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        },
        renew: { refresh in try await AuthAPIClient.shared.refreshTokens(refreshToken: refresh) }
    )

    private let load: () -> Snapshot?
    private let save: (TokenResponse) throws -> Void
    private let renew: (String) async throws -> TokenResponse
    private var inFlight: (id: UUID, snapshot: Snapshot, task: Task<TokenResponse, Error>)?
    private var aliases: [String: UUID] = [:]

    init(load: @escaping () -> Snapshot?, save: @escaping (TokenResponse) throws -> Void,
         renew: @escaping (String) async throws -> TokenResponse) {
        self.load = load
        self.save = save
        self.renew = renew
    }

    func accessToken(for suppliedToken: String) throws -> String {
        guard let current = load() else { throw CancellationError() }
        aliases = aliases.filter { $0.value == current.revision }
        guard suppliedToken == current.accessToken || aliases[suppliedToken] == current.revision else {
            throw CancellationError()
        }
        return current.accessToken
    }

    func refresh(accessToken suppliedToken: String) async throws -> TokenResponse {
        let resolved = try accessToken(for: suppliedToken)
        guard let snapshot = load() else { throw CancellationError() }
        if resolved != suppliedToken {
            return TokenResponse(accessToken: snapshot.accessToken, refreshToken: snapshot.refreshToken)
        }
        if let running = inFlight, running.snapshot == snapshot {
            let tokens = try await running.task.value
            guard load()?.revision == snapshot.revision else { throw CancellationError() }
            return tokens
        }

        let id = UUID()
        let task = Task { [self] in
            let tokens = try await renew(snapshot.refreshToken)
            guard load() == snapshot else { throw CancellationError() }
            try save(tokens)
            aliases[snapshot.accessToken] = snapshot.revision
            return tokens
        }
        inFlight = (id, snapshot, task)
        defer { if inFlight?.id == id { inFlight = nil } }
        let tokens = try await task.value
        guard load()?.revision == snapshot.revision else { throw CancellationError() }
        return tokens
    }
}
