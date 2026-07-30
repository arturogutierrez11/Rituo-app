import Foundation

final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    private let appGroupIdentifier = "group.io.rituo.app"

    func beginRequest(with context: NSExtensionContext) {
        do {
            let rulesURL = try makeRulesFile()
            let attachment = NSItemProvider(contentsOf: rulesURL)
            let item = NSExtensionItem()
            item.attachments = attachment.map { [$0] } ?? []
            context.completeRequest(returningItems: [item])
        } catch {
            context.cancelRequest(withError: error)
        }
    }

    private func makeRulesFile() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw ContentBlockerError.missingAppGroupContainer
        }

        let isEnabled = UserDefaults(suiteName: appGroupIdentifier)?
            .bool(forKey: SafariContentBlockerController.enabledDefaultsKey) ?? false
        let rules = isEnabled ? blockingRules : []
        let data = try JSONSerialization.data(withJSONObject: rules)
        let rulesURL = containerURL.appendingPathComponent(
            "rituo-safari-content-blocker.json",
            isDirectory: false
        )
        try data.write(to: rulesURL, options: .atomic)
        print(
            "Safari content blocker supplied",
            rules.count,
            "rule(s). Blocking enabled:",
            isEnabled
        )
        return rulesURL
    }

    private var blockingRules: [[String: Any]] {
        [
            [
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": SensitiveWebDomainCatalog.safariContentBlockerDomainPatterns
                ],
                "action": [
                    "type": "block"
                ]
            ]
        ]
    }
}

private enum ContentBlockerError: LocalizedError {
    case missingAppGroupContainer

    var errorDescription: String? {
        "No se pudo acceder al App Group del bloqueador de Safari."
    }
}
