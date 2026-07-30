import Foundation
import SwiftData

enum SyncOperationType: String {
    case finishMode
    case finishRitual
    case recordScheduledRitual
    case syncModeConfiguration
    case createRitualConfiguration
    case deleteRitual
}

enum SyncOperationStatus: String {
    case pending
    case syncing
    case failed
}

@Model
final class PendingSyncOperation {
    @Attribute(.unique) var id: UUID
    var userID: String
    var typeRawValue: String
    var payload: Data
    var statusRawValue: String
    var attempts: Int
    var createdAt: Date
    var nextRetryAt: Date
    var lastError: String?
    var idempotencyKey: String

    init(
        id: UUID,
        userID: String,
        type: SyncOperationType,
        payload: Data,
        idempotencyKey: String
    ) {
        self.id = id
        self.userID = userID
        self.typeRawValue = type.rawValue
        self.payload = payload
        self.statusRawValue = SyncOperationStatus.pending.rawValue
        self.attempts = 0
        self.createdAt = .now
        self.nextRetryAt = .now
        self.lastError = nil
        self.idempotencyKey = idempotencyKey
    }
}
