// Combined with production methods by run_sync_regressions.py; no network access.
struct CreationRequest: Codable {
    let value: Int
    func withPassword(_ password: String?) -> Self { self }
}
typealias CreateRitualRequest = CreationRequest
typealias UpdateRitualRequest = CreationRequest
typealias ReplaceRitualBlockedItemsRequest = CreationRequest
typealias RitualScheduler = CreationScheduler
struct RitualResponse { let id: String }
struct CreationScheduler {
    let id: UUID
    var coreRitualId: String?
    var value: Int
    func createRitualRequest() -> CreationRequest { .init(value: value) }
    func updateRitualRequest() -> CreationRequest { .init(value: value) }
    var blockedItemsRequest: CreationRequest { .init(value: value) }
}
@MainActor final class CreationKeychain {
    var values: [UUID: String] = [:]
    func saveSyncSecret(_ value: String, operationID: UUID) throws { values[operationID] = value }
    func loadSyncSecret(operationID: UUID) -> String? { values[operationID] }
    func deleteSyncSecret(operationID: UUID) { values[operationID] = nil }
}
@MainActor final class CreationAPI {
    var creates = 0
    var reads = 0
    var keys: [String] = []
    var items: [Int] = []
    var paused = true
    var failItems = false
    var continuation: CheckedContinuation<Void, Never>?
    func createRitual(accessToken: String, body: CreationRequest, idempotencyKey: String) async throws -> RitualResponse {
        creates += 1; keys.append(idempotencyKey)
        if paused { await withCheckedContinuation { continuation = $0 } }
        return RitualResponse(id: "remote-created")
    }
    func getRitual(accessToken: String, ritualId: String) async throws -> RitualResponse {
        reads += 1; return RitualResponse(id: ritualId)
    }
    func replaceRitualBlockedItems(accessToken: String, ritualId: String, body: CreationRequest, idempotencyKey: String) async throws -> Bool {
        items.append(body.value); keys.append(idempotencyKey)
        if failItems { throw CoreAPIError.timedOut }
        return true
    }
}
@MainActor final class CreationHarness {
    let syncOutbox: SyncOutboxStore
    let keychainStore = CreationKeychain()
    let coreApi = CreationAPI()
    var schedulers: [CreationScheduler] = []
    var activeAccountID: String? = "account"
    var activeAccessToken: String? = "token"
    var pendingRitualPasswords: [UUID: String] = [:]
    var coreSyncMessage: String?
    init() throws {
        syncOutbox = SyncOutboxStore(container: try ModelContainer(for: PendingSyncOperation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }
    func refreshSyncOutboxStatus() {}
    func applyCoreRitualResponse(_ response: RitualResponse, localSchedulerID: UUID, preserveLocalProtection: Bool = false) {
        let index = schedulers.firstIndex { $0.id == localSchedulerID }!
        schedulers[index].coreRitualId = response.id
    }
    func syncRitualBreakConfig(coreRitualID: String, localSchedulerID: UUID, accessToken: String) async {}
    // PRODUCTION_METHODS
}
@MainActor func runCreationTests() async throws {
    let h = try CreationHarness()
    let id = UUID()
    let original = CreationScheduler(id: id, value: 1)
    h.schedulers = [original]
    try h.queueRitualConfiguration(original, password: "original-password")
    let operation = h.syncOutbox.operations(userID: "account", type: .createRitualConfiguration).first!
    let revision = operation.idempotencyKey
    let task = Task { await h.syncPendingRitualConfigurations(userID: "account", accessToken: "token") }
    while h.coreApi.continuation == nil { await Task.yield() }
    let edited = CreationScheduler(id: id, value: 2)
    try h.queueRitualConfiguration(edited, password: "new-password")
    h.schedulers = [edited]
    precondition(operation.idempotencyKey == revision)
    precondition(h.keychainStore.loadSyncSecret(operationID: operation.id) == "original-password")
    h.coreApi.continuation!.resume(); h.coreApi.continuation = nil
    await task.value
    precondition(h.coreApi.creates == 1 && h.schedulers[0].coreRitualId == "remote-created")
    let update = h.syncOutbox.operations(userID: "account", type: .updateRitualConfiguration).first!
    let payload = try JSONDecoder().decode(CreationHarness.PendingRitualUpdate.self, from: update.payload)
    precondition(payload.coreRitualID == "remote-created" && payload.updateRequest.value == 2)
    precondition(h.coreApi.keys == ["\(revision):config", "\(revision):items"])
    let retry = try CreationHarness()
    retry.schedulers = [original]; retry.coreApi.paused = false; retry.coreApi.failItems = true
    try retry.queueRitualConfiguration(original)
    await retry.syncPendingRitualConfigurations(userID: "account", accessToken: "token")
    let saved = retry.syncOutbox.operations(userID: "account", type: .createRitualConfiguration).first!
    let checkpoint = try JSONDecoder().decode(CreationHarness.PendingRitualConfiguration.self, from: saved.payload)
    precondition(checkpoint.coreRitualID == "remote-created")
    saved.nextRetryAt = .distantPast; retry.coreApi.failItems = false
    await retry.syncPendingRitualConfigurations(userID: "account", accessToken: "token")
    precondition(retry.coreApi.creates == 1 && retry.coreApi.reads == 1)
    print("PASS: edit during creation, frozen password/key/body, latest PATCH, checkpoint after partial success")
}
