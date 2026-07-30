import Foundation

struct RitualResponse: Decodable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let icon: String
    let durationMinutes: Int
    let weekdays: [Int]
    let startTime: String?
    let endTime: String?
    let appCount: Int
    let categoryCount: Int
    let domainCount: Int
    let selectionDigest: String?
    let isProtected: Bool
    let nfcUnlockEnabled: Bool
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct CreateRitualRequest: Codable {
    let title: String
    let description: String?
    let icon: String
    let durationMinutes: Int
    let weekdays: [Int]
    let startTime: String?
    let endTime: String?
    let appCount: Int
    let categoryCount: Int
    let domainCount: Int
    let selectionDigest: String?
    let isProtected: Bool
    let nfcUnlockEnabled: Bool
    let password: String?
}

struct DeleteRitualRequest: Encodable {
    let password: String?
}

struct RitualBlockedItemResponse: Decodable, Identifiable {
    let id: String
    let ritualId: String
    let platform: String?
    let type: String
    let identifier: String
    let displayName: String?
    let applicationIdentifier: String?
    let bundleIdentifier: String?
    let createdAt: String
}

struct ReplaceRitualBlockedItemsRequest: Codable {
    let platform: String
    let items: [RitualBlockedItemRequest]

    init(platform: String = "ios", items: [RitualBlockedItemRequest]) {
        self.platform = platform
        self.items = items
    }
}

struct RitualBlockedItemRequest: Codable {
    let platform: String
    let type: String
    let identifier: String
    let displayName: String?
    let applicationIdentifier: String?
    let bundleIdentifier: String?

    init(
        platform: String = "ios",
        type: String,
        identifier: String,
        displayName: String?,
        applicationIdentifier: String? = nil,
        bundleIdentifier: String?
    ) {
        self.platform = platform
        self.type = type
        self.identifier = identifier
        self.displayName = displayName
        self.applicationIdentifier = applicationIdentifier ?? bundleIdentifier
        self.bundleIdentifier = bundleIdentifier
    }
}

struct ModeResponse: Decodable, Identifiable {
    let id: String
    let userId: String
    let templateKey: String
    let title: String
    let icon: String
    let appCount: Int
    let categoryCount: Int
    let domainCount: Int
    let selectionDigest: String?
    let isProtected: Bool
    let nfcUnlockEnabled: Bool
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct UpdateModeRequest: Codable {
    let title: String
    let icon: String
    let appCount: Int
    let categoryCount: Int
    let domainCount: Int
    let selectionDigest: String?
    let isProtected: Bool
    let nfcUnlockEnabled: Bool
    let password: String?
}

struct RenameModeRequest: Codable {
    let title: String
}

struct ModeBlockedItemResponse: Decodable, Identifiable {
    let id: String
    let modeId: String
    let platform: String?
    let type: String
    let identifier: String
    let displayName: String?
    let applicationIdentifier: String?
    let bundleIdentifier: String?
    let createdAt: String
}

struct ReplaceModeBlockedItemsRequest: Codable {
    let platform: String
    let items: [RitualBlockedItemRequest]

    init(platform: String = "ios", items: [RitualBlockedItemRequest]) {
        self.platform = platform
        self.items = items
    }
}


struct RitualSessionResponse: Decodable, Identifiable {
    let id: String
    let userId: String
    let ritualId: String
    let startedAt: String
    let plannedEndAt: String?
    let endedAt: String?
    let status: String
    let startSource: String
    let endSource: String?
    let durationSeconds: Int?
    let createdAt: String
    let updatedAt: String
}

struct StartRitualSessionRequest: Encodable {
    let ritualId: String
    let plannedEndAt: String?
    let startSource: String
}

struct FinishRitualSessionRequest: Encodable {
    let status: String?
    let endSource: String
    let tagIdentifier: String?
}


struct RitualSessionSummaryResponse: Decodable {
    let totalSessions: Int
    let completedSessions: Int
    let cancelledSessions: Int
    let activeSessions: Int
    let totalFocusSeconds: Int
    let totalFocusMinutes: Int
    let currentStreakDays: Int
    let lastSessionAt: String?
}

struct RecordRitualSessionRequest: Codable {
    let ritualId: String
    let startedAt: String
    let plannedEndAt: String?
    let endedAt: String?
    let status: String
    let startSource: String
    let endSource: String
}

struct ModeSessionResponse: Decodable, Identifiable {
    let id: String
    let userId: String
    let modeId: String
    let startedAt: String
    let endedAt: String?
    let status: String
    let startSource: String
    let endSource: String?
    let durationSeconds: Int?
    let createdAt: String
    let updatedAt: String
}

struct ActiveFocusSessionResponse: Decodable {
    let type: String
    let ritualSession: RitualSessionResponse?
    let modeSession: ModeSessionResponse?
}

enum EmergencyUnlockReason: String, Codable {
    case forgotTag = "forgot_tag"
    case lostTag = "lost_tag"
}

struct EmergencyUnlockStatusResponse: Decodable {
    let available: Bool
    let cooldownDays: Int
    let lastUsedAt: String?
    let nextAvailableAt: String?
}

struct UseEmergencyUnlockRequest: Encodable {
    let reason: EmergencyUnlockReason
}

struct EmergencyUnlockResponse: Decodable {
    let id: String
    let sessionType: String
    let sessionId: String
    let reason: EmergencyUnlockReason
    let tagMarkedLost: Bool
    let usedAt: String
    let nextAvailableAt: String
}

struct StartModeSessionRequest: Encodable {
    let modeId: String
    let startSource: String
}

struct FinishModeSessionRequest: Encodable {
    let status: String?
    let endSource: String
    let tagIdentifier: String?
}

struct ModeSessionSummaryResponse: Decodable {
    let totalSessions: Int
    let completedSessions: Int
    let cancelledSessions: Int
    let activeSessions: Int
    let totalFocusSeconds: Int
    let totalFocusMinutes: Int
    let currentStreakDays: Int
    let lastSessionAt: String?
}

struct FocusMetricDayResponse: Decodable {
    let date: String
    let totalFocusSeconds: Int
    let totalFocusMinutes: Int
}

struct FocusMetricsSummaryResponse: Decodable {
    let totalSessions: Int
    let completedSessions: Int
    let cancelledSessions: Int
    let activeSessions: Int
    let ritualSessions: Int
    let modeSessions: Int
    let totalFocusSeconds: Int
    let totalFocusMinutes: Int
    let focusDays: Int
    let currentStreakDays: Int
    let lastSessionAt: String?
    let weeklyFocus: [FocusMetricDayResponse]
}


struct NfcTagClaimResponse: Decodable, Identifiable {
    let id: String
    let tagId: String
    let userId: String
    let label: String?
    let status: String
    let claimedAt: String
    let lastSeenAt: String?
    let createdAt: String
    let updatedAt: String
}

struct ClaimNfcTagRequest: Encodable {
    let tagIdentifier: String
    let label: String?
}

struct UpdateNfcTagClaimRequest: Encodable {
    let label: String
}

struct VerifyNfcTagRequest: Encodable {
    let tagIdentifier: String
}

struct VerifyNfcTagResponse: Decodable {
    let valid: Bool
    let claim: NfcTagClaimResponse?
}

struct ReviewDemoTagResponse: Decodable {
    let enabled: Bool
    let tagIdentifier: String
    let claim: NfcTagClaimResponse
}
