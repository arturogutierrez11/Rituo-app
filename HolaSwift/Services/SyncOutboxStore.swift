import Foundation
import SwiftData

@MainActor
final class SyncOutboxStore {
    static let shared = SyncOutboxStore()
    private static let maximumAutomaticAttempts = 8

    let container: ModelContainer
    private let context: ModelContext

    private init() {
        do {
            container = try ModelContainer(for: PendingSyncOperation.self)
            context = ModelContext(container)
        } catch {
            fatalError("No se pudo abrir SyncOutbox en SwiftData: \(error)")
        }
    }

    func upsert(
        id: UUID,
        userID: String,
        type: SyncOperationType,
        payload: Data
    ) throws {
        if let existing = operation(userID: userID, type: type) {
            context.delete(existing)
        }

        context.insert(
            PendingSyncOperation(
                id: id,
                userID: userID,
                type: type,
                payload: payload,
                idempotencyKey: id.uuidString
            )
        )
        try context.save()
    }

    func enqueue(
        id: UUID,
        userID: String,
        type: SyncOperationType,
        payload: Data
    ) throws {
        guard operation(id: id) == nil else { return }

        context.insert(
            PendingSyncOperation(
                id: id,
                userID: userID,
                type: type,
                payload: payload,
                idempotencyKey: id.uuidString
            )
        )
        try context.save()
    }

    func upsertScoped(
        id: UUID,
        userID: String,
        type: SyncOperationType,
        payload: Data
    ) throws {
        if let existing = operation(id: id) {
            existing.userID = userID
            existing.typeRawValue = type.rawValue
            existing.payload = payload
            existing.statusRawValue = SyncOperationStatus.pending.rawValue
            existing.attempts = 0
            existing.nextRetryAt = .now
            existing.lastError = nil
            existing.idempotencyKey = UUID().uuidString
        } else {
            context.insert(
                PendingSyncOperation(
                    id: id,
                    userID: userID,
                    type: type,
                    payload: payload,
                    idempotencyKey: UUID().uuidString
                )
            )
        }
        try context.save()
    }

    func operations(
        userID: String,
        type: SyncOperationType
    ) -> [PendingSyncOperation] {
        allOperations()
            .filter { $0.userID == userID && $0.typeRawValue == type.rawValue }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func payload(userID: String, type: SyncOperationType) -> Data? {
        operation(userID: userID, type: type)?.payload
    }

    func operationID(userID: String, type: SyncOperationType) -> UUID? {
        operation(userID: userID, type: type)?.id
    }

    func isDue(userID: String, type: SyncOperationType, now: Date = .now) -> Bool {
        guard let operation = operation(userID: userID, type: type) else {
            return true
        }
        return operation.statusRawValue != SyncOperationStatus.failed.rawValue
            && operation.nextRetryAt <= now
    }

    func nextRetryDate(userID: String, type: SyncOperationType) -> Date? {
        operations(userID: userID, type: type)
            .filter { $0.statusRawValue != SyncOperationStatus.failed.rawValue }
            .map(\.nextRetryAt)
            .min()
    }

    func makeDue(userID: String) {
        let operations = allOperations().filter {
            $0.userID == userID
                && $0.statusRawValue != SyncOperationStatus.failed.rawValue
        }
        guard !operations.isEmpty else { return }

        for operation in operations {
            operation.statusRawValue = SyncOperationStatus.pending.rawValue
            operation.nextRetryAt = .now
        }
        try? context.save()
    }

    func markSyncing(userID: String, type: SyncOperationType) {
        guard let operation = operation(userID: userID, type: type) else { return }
        operation.statusRawValue = SyncOperationStatus.syncing.rawValue
        try? context.save()
    }

    func markFailure(userID: String, type: SyncOperationType, error: Error) {
        guard let operation = operation(userID: userID, type: type) else { return }
        applyFailure(to: operation, error: error)
    }

    func remove(userID: String, type: SyncOperationType) {
        guard let operation = operation(userID: userID, type: type) else { return }
        context.delete(operation)
        try? context.save()
    }

    func isDue(id: UUID, now: Date = .now) -> Bool {
        guard let operation = operation(id: id) else { return false }
        return operation.statusRawValue != SyncOperationStatus.failed.rawValue
            && operation.nextRetryAt <= now
    }

    func markSyncing(id: UUID) {
        guard let operation = operation(id: id) else { return }
        operation.statusRawValue = SyncOperationStatus.syncing.rawValue
        try? context.save()
    }

    func markFailure(id: UUID, error: Error) {
        guard let operation = operation(id: id) else { return }
        applyFailure(to: operation, error: error)
    }

    func remove(id: UUID) {
        guard let operation = operation(id: id) else { return }
        context.delete(operation)
        try? context.save()
    }

    func updatePayload(id: UUID, payload: Data) throws {
        guard let operation = operation(id: id) else { return }
        operation.payload = payload
        try context.save()
    }

    func counts(userID: String) -> (pending: Int, failed: Int) {
        let operations = allOperations().filter { $0.userID == userID }
        let failed = operations.filter {
            $0.statusRawValue == SyncOperationStatus.failed.rawValue
        }.count
        return (operations.count - failed, failed)
    }

    func retryFailed(userID: String) {
        let operations = allOperations().filter {
            $0.userID == userID
                && $0.statusRawValue == SyncOperationStatus.failed.rawValue
        }
        guard !operations.isEmpty else { return }

        for operation in operations {
            operation.statusRawValue = SyncOperationStatus.pending.rawValue
            operation.attempts = 0
            operation.nextRetryAt = .now
            operation.lastError = nil
        }
        try? context.save()
    }

    func removeAll(userID: String) -> [UUID] {
        let operations = allOperations().filter { $0.userID == userID }
        let operationIDs = operations.map(\.id)
        operations.forEach(context.delete)
        try? context.save()
        return operationIDs
    }

    private func operation(
        userID: String,
        type: SyncOperationType
    ) -> PendingSyncOperation? {
        allOperations()
            .filter { $0.userID == userID && $0.typeRawValue == type.rawValue }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private func operation(id: UUID) -> PendingSyncOperation? {
        allOperations().first { $0.id == id }
    }

    private func applyFailure(
        to operation: PendingSyncOperation,
        error: Error
    ) {
        operation.attempts += 1
        operation.lastError = error.localizedDescription

        if operation.attempts >= Self.maximumAutomaticAttempts {
            operation.statusRawValue = SyncOperationStatus.failed.rawValue
        } else {
            operation.statusRawValue = SyncOperationStatus.pending.rawValue
            let delay = min(
                300,
                5 * pow(2, Double(max(0, operation.attempts - 1)))
            )
            operation.nextRetryAt = Date().addingTimeInterval(delay)
        }
        try? context.save()
    }

    private func allOperations() -> [PendingSyncOperation] {
        (try? context.fetch(FetchDescriptor<PendingSyncOperation>())) ?? []
    }
}
