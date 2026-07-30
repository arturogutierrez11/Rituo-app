import Foundation

enum LegalDocumentType: String, Codable {
    case terms
    case privacy

    var displayName: String {
        switch self {
        case .terms:
            return "Términos y Condiciones"
        case .privacy:
            return "Política de Privacidad"
        }
    }
}

struct LegalDocumentResponse: Codable, Identifiable, Equatable {
    let id: String
    let type: LegalDocumentType
    let version: String
    let title: String
    let content: String
    let contentHash: String
    let sourceUrl: String?
    let effectiveAt: String
    let publishedAt: String
    let isActive: Bool
    let createdAt: String
    let acceptedAt: String?
}

struct LegalRequirementsResponse: Codable, Equatable {
    let requiresAcceptance: Bool
    let documents: [LegalDocumentResponse]
}

struct AcceptLegalDocumentsRequest: Encodable {
    let documentIds: [String]
    let platform: String
    let appVersion: String?
    let locale: String?
}
