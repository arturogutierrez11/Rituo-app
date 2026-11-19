import Foundation
import OSLog
import FirebaseCore
import FirebaseCrashlytics

/// Only pass static phase names. Never pass request bodies, headers, tokens or user data.
nonisolated final class AppDiagnostics: @unchecked Sendable {
    static let shared = AppDiagnostics()
    private let queue = DispatchQueue(label: "io.rituo.diagnostics", qos: .utility)
    private let logger = Logger(subsystem: "io.rituo.app", category: "Diagnostics")
    private let session = UUID().uuidString
    private var reports = 0
    private var stallReports = 0
    private var recoveryEvents = 0
    private var slowPhaseReports = 0
    private var latencyReports = 0
    private var timer: DispatchSourceTimer?
    // All mutable state below is confined to queue.
    private var active = false
    private var pendingPing: (id: UUID, start: TimeInterval)?
    private var reportedPing = false
    private var lastPhase = "launch"
    private let directory: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Diagnostics", isDirectory: true)) {
        self.directory = directory
    }

    @discardableResult
    func begin(_ phase: String) -> (String, TimeInterval) {
        let id = UUID().uuidString
        event("begin phase=\(phase) id=\(id)")
        queue.async { self.lastPhase = phase }
        return (id, ProcessInfo.processInfo.systemUptime)
    }

    func end(_ phase: String, _ span: (String, TimeInterval)) {
        let milliseconds = Int((ProcessInfo.processInfo.systemUptime - span.1) * 1000)
        #if DEBUG
        event("end phase=\(phase) id=\(span.0) ms=\(milliseconds)")
        #else
        guard milliseconds >= 500 else { return }
        queue.async {
            guard self.slowPhaseReports < 30 else { return }
            self.slowPhaseReports += 1
            self.append("slow_phase phase=\(phase) ms=\(milliseconds)")
        }
        #endif
    }

    func event(_ message: @autoclosure () -> String) {
        #if DEBUG
        let message = message()
        let recordedAt = Date().timeIntervalSince1970
        queue.async { self.append(message, recordedAt: recordedAt) }
        #endif
    }

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            let bundle = Bundle.main
            self.append("launch version=\(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "?") build=\(bundle.object(forInfoDictionaryKey: "CFBundleVersion") ?? "?") os=\(ProcessInfo.processInfo.operatingSystemVersionString)")
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
            timer.setEventHandler { [weak self] in self?.checkMainThread() }
            self.timer = timer
            // Wait for the scene to be active before monitoring UI responsiveness.
            timer.resume()
        }
    }

    func setActive(_ active: Bool) {
        queue.async {
            self.active = active
            self.pendingPing = nil
            self.reportedPing = false
        }
    }

    private func checkMainThread() {
        guard active else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let ping = pendingPing {
            if now - ping.start >= 5, !reportedPing {
                reportedPing = true
                append("main_unresponsive seconds=\(Int(now - ping.start)) last_phase=\(lastPhase)")
                report(code: 2, label: "main_unresponsive", details: ["last_phase": lastPhase])
            }
            return
        }
        let id = UUID()
        pendingPing = (id, now)
        DispatchQueue.main.async {
            let latency = ProcessInfo.processInfo.systemUptime - now
            self.queue.async {
                guard self.pendingPing?.id == id else { return }
                if latency >= 0.5, self.latencyReports < 20 {
                    self.latencyReports += 1
                    self.append("main_queue_delay ms=\(Int(latency * 1000)) last_phase=\(self.lastPhase)")
                }
                if self.reportedPing { self.append("main_responsive_again") }
                self.pendingPing = nil
                self.reportedPing = false
            }
        }
    }

    // Small production breadcrumb budget, independent of Firebase availability.
    func blockingRecovery(_ reason: String) {
        queue.async {
            guard self.recoveryEvents < 20 else { return }
            self.recoveryEvents += 1
            self.append("blocking_recovery reason=\(reason)")
        }
    }

    func networkIssue(_ label: String, endpoint: String, code: Int) {
        queue.async {
            self.report(code: 1, label: label, details: ["endpoint": endpoint, "status_or_error": code])
        }
    }

    private func report(code: Int, label: String, details: [String: Any]) {
        if code == 2 {
            guard stallReports < 3 else { return }
            stallReports += 1
        } else {
            guard reports < 10 else { return }
            reports += 1
        }
        append("issue label=\(label) details=\(details)")
        guard FirebaseApp.app() != nil else { return }
        var info = details
        info[NSLocalizedDescriptionKey] = label
        info["diagnostic_session"] = session
        // This stack belongs to the diagnostic queue, not the blocked main thread.
        Crashlytics.crashlytics().record(error: NSError(domain: "RituoDiagnostics", code: code, userInfo: info))
    }

    private func append(_ message: String, recordedAt: TimeInterval = Date().timeIntervalSince1970) {
        let line = "\(recordedAt) session=\(session) \(message)\n"
        #if DEBUG
        logger.debug("\(line, privacy: .public)")
        #endif
        if FirebaseApp.app() != nil { Crashlytics.crashlytics().log(line) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let current = directory.appendingPathComponent("current.log")
            let previous = directory.appendingPathComponent("previous.log")
            if let size = try? current.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 512_000 {
                if FileManager.default.fileExists(atPath: previous.path) { try FileManager.default.removeItem(at: previous) }
                try FileManager.default.moveItem(at: current, to: previous)
            }
            if !FileManager.default.fileExists(atPath: current.path) {
                FileManager.default.createFile(atPath: current.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: current)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } catch {
            logger.error("Unable to write diagnostic file")
        }
    }

    func export(deviceActivityEvents: [String] = []) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    var data = Data()
                    for name in ["previous.log", "current.log"] {
                        if let contents = try? Data(contentsOf: self.directory.appendingPathComponent(name)) {
                            data.append(contents)
                        }
                    }
                    data.append(Data(("\nDeviceActivity — eventos locales recientes (pueden incluir nombres de rituales)\n" + deviceActivityEvents.joined(separator: "\n") + "\n").utf8))
                    let destination = FileManager.default.temporaryDirectory.appendingPathComponent("rituo-diagnostics.txt")
                    try data.write(to: destination, options: .atomic)
                    continuation.resume(returning: destination)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}

/// Logs every transport attempt, including token-refresh retries. No URL queries or bodies.
nonisolated enum DiagnosticHTTP {
    @MainActor
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch {
            let model = String(describing: type)
            AppDiagnostics.shared.event("decode_failure model=\(model)")
            AppDiagnostics.shared.networkIssue("decode_failure", endpoint: model, code: 0)
            throw error
        }
    }

    static func endpoint(_ request: URLRequest) -> String {
        let known: Set<String> = ["api.rituo.io", "auth.rituo.io", "core.rituo.io"]
        let host = request.url?.host ?? ""
        let allowed: Set<String> = ["api", "v1", "auth", "users", "me", "login", "logout", "refresh", "register", "rituals", "modes", "sessions", "active", "start", "stop", "finish", "breaks", "summary", "metrics", "focus", "history", "blocked-items", "app-updates", "status", "legal", "requirements", "accept", "nfc", "tags", "claims", "support", "reset", "pending", "acknowledge", "config", "devices", "apple", "google", "email", "password", "verify", "resend"]
        let path = (request.url?.path ?? "").split(separator: "/").map { allowed.contains(String($0)) ? String($0) : ":id" }.joined(separator: "/")
        return "\(request.httpMethod ?? "GET") \(known.contains(host) ? host : "service")/\(path)"
    }

    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let diagnostics = AppDiagnostics.shared
        let endpoint = endpoint(request)
        let span = diagnostics.begin("http \(endpoint)")
        defer { diagnostics.end("http \(endpoint)", span) }
        do {
            let result = try await URLSession.shared.data(for: request)
            let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
            diagnostics.event("http_response id=\(span.0) status=\(status) bytes=\(result.0.count)")
            if status >= 400 { diagnostics.networkIssue("http_failure", endpoint: endpoint, code: status) }
            return result
        } catch {
            let nsError = error as NSError
            let code = nsError.domain == NSURLErrorDomain ? nsError.code : 0
            diagnostics.event("http_error id=\(span.0) code=\(code)")
            if code != NSURLErrorCancelled { diagnostics.networkIssue("transport_failure", endpoint: endpoint, code: code) }
            throw error
        }
    }
}
