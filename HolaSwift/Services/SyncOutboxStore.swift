import Foundation
import OSLog
import SwiftData

enum SyncOutboxStoreError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "No pudimos guardar la operación pendiente en este dispositivo."
    }
}

@MainActor
final class SyncOutboxStore {
    static let shared = SyncOutboxStore()
    private static let maximumAutomaticAttempts = 8
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.rituo.app",
        category: "SyncOutbox"
    )

    private let container: ModelContainer?
    private let context: ModelContext?

    private init() {
        container = Self.makeContainer()
        context = container.map(ModelContext.init)
    }

    func upsert(
        id: UUID,
        userID: String,
        type: SyncOperationType,
        payload: Data
    ) throws {
        let context = try requireContext()

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
        let context = try requireContext()

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
        let context = try requireContext()

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
        guard let context else { return }

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
        guard let context else { return }
        guard let operation = operation(userID: userID, type: type) else { return }
        operation.statusRawValue = SyncOperationStatus.syncing.rawValue
        try? context.save()
    }

    func markFailure(userID: String, type: SyncOperationType, error: Error) {
        guard let operation = operation(userID: userID, type: type) else { return }
        applyFailure(to: operation, error: error)
    }

    func remove(userID: String, type: SyncOperationType) {
        guard let context else { return }
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
        guard let context else { return }
        guard let operation = operation(id: id) else { return }
        operation.statusRawValue = SyncOperationStatus.syncing.rawValue
        try? context.save()
    }

    func markFailure(id: UUID, error: Error) {
        guard let operation = operation(id: id) else { return }
        applyFailure(to: operation, error: error)
    }

    func remove(id: UUID) {
        guard let context else { return }
        guard let operation = operation(id: id) else { return }
        context.delete(operation)
        try? context.save()
    }

    func updatePayload(id: UUID, payload: Data) throws {
        let context = try requireContext()

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
        guard let context else { return }

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
        guard let context else { return [] }

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
        guard let context else { return }

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
        guard let context else { return [] }
        return (try? context.fetch(FetchDescriptor<PendingSyncOperation>())) ?? []
    }

    private func requireContext() throws -> ModelContext {
        guard let context else {
            throw SyncOutboxStoreError.unavailable
        }
        return context
    }

    private static func makeContainer() -> ModelContainer? {
        let configuration = ModelConfiguration(for: PendingSyncOperation.self)

        do {
            return try ModelContainer(
                for: PendingSyncOperation.self,
                configurations: configuration
            )
        } catch {
            logger.error(
                "No se pudo abrir el outbox persistente. Se intentará recuperar: \(error.localizedDescription, privacy: .public)"
            )
        }

        quarantineStore(at: configuration.url)

        do {
            let recoveredContainer = try ModelContainer(
                for: PendingSyncOperation.self,
                configurations: configuration
            )
            logger.notice("El outbox local fue reconstruido correctamente.")
            return recoveredContainer
        } catch {
            logger.fault(
                "No se pudo reconstruir el outbox persistente. Se usará memoria temporal: \(error.localizedDescription, privacy: .public)"
            )
        }

        do {
            let memoryConfiguration = ModelConfiguration(
                for: PendingSyncOperation.self,
                isStoredInMemoryOnly: true
            )
            return try ModelContainer(
                for: PendingSyncOperation.self,
                configurations: memoryConfiguration
            )
        } catch {
            logger.fault(
                "El outbox temporal tampoco está disponible. La app continuará sin cola local: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private static func quarantineStore(at storeURL: URL) {
        let fileManager = FileManager.default
        let candidates = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
        let existingFiles = candidates.filter {
            fileManager.fileExists(atPath: $0.path)
        }

        guard !existingFiles.isEmpty else {
            logger.notice("No se encontraron archivos del outbox para poner en cuarentena.")
            return
        }

        let recoveryDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("SyncOutboxRecovery", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: recoveryDirectory,
                withIntermediateDirectories: true
            )

            for sourceURL in existingFiles {
                let destinationURL = recoveryDirectory
                    .appendingPathComponent(sourceURL.lastPathComponent)
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
            }

            logger.notice(
                "El outbox dañado fue movido a cuarentena: \(recoveryDirectory.lastPathComponent, privacy: .public)"
            )
        } catch {
            logger.error(
                "No se pudo poner en cuarentena el outbox dañado: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
