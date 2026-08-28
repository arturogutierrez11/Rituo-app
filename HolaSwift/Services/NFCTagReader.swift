import CoreNFC
import Foundation

enum NFCTagReaderError: LocalizedError {
    case unsupported
    case userCanceled
    case invalidated
    case timedOut
    case systemBusy
    case terminatedUnexpectedly
    case unknownTag
    case unexpectedTag

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "No se pudo abrir el lector NFC. Reiniciá el iPhone e intentá de nuevo — a veces el lector queda bloqueado hasta que se reinicia el equipo."
        case .userCanceled:
            return "Cancelaste la lectura NFC."
        case .invalidated:
            return "La lectura NFC fue interrumpida."
        case .timedOut:
            return "Se agotó el tiempo de espera. Acercá el tag e intentá de nuevo."
        case .systemBusy:
            return "El lector NFC está ocupado o bloqueado por otra app (por ejemplo, una tarjeta de transporte o de pago en Wallet). Cerrá esas apps o desactivá el modo Express e intentá de nuevo."
        case .terminatedUnexpectedly:
            return "La lectura NFC se interrumpió inesperadamente. Intentá de nuevo. Si el problema sigue, reiniciá el iPhone."
        case .unknownTag:
            return "No se pudo identificar este tag NFC."
        case .unexpectedTag:
            return "Ese tag no está vinculado a esta cuenta."
        }
    }

    /// Whether this failure is worth interrupting the user with a modal, versus a quiet inline status update.
    var shouldPresentAlert: Bool {
        switch self {
        case .userCanceled:
            return false
        case .unsupported, .invalidated, .timedOut, .systemBusy, .terminatedUnexpectedly, .unknownTag, .unexpectedTag:
            return true
        }
    }
}

struct NFCTagScanResult: Equatable {
    let identifier: String
}

final class NFCTagReader: NSObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    private var onResult: ((Result<NFCTagScanResult, Error>) -> Void)?
    private var expectedIdentifier: String?
    private var unexpectedTagMessage: String?

    func beginScanning(
        alertMessage: String,
        expectedIdentifier: String? = nil,
        unexpectedTagMessage: String? = nil,
        onResult: @escaping (Result<NFCTagScanResult, Error>) -> Void
    ) {
        guard NFCTagReaderSession.readingAvailable else {
            onResult(.failure(NFCTagReaderError.unsupported))
            return
        }

        // iOS only allows one active NFCTagReaderSession at a time. If a previous
        // session was never cleanly invalidated (e.g. the app was backgrounded
        // mid-scan), starting a new one here fails instantly with
        // "Session invalidated unexpectedly" and the reader sheet never appears.
        session?.invalidate()
        session = nil

        self.onResult = onResult
        self.expectedIdentifier = expectedIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        self.unexpectedTagMessage = unexpectedTagMessage
        session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693],
            delegate: self,
            queue: nil
        )
        session?.alertMessage = alertMessage
        session?.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NFCReaderError.errorDomain,
           let code = NFCReaderError.Code(rawValue: nsError.code) {
            switch code {
            case .readerSessionInvalidationErrorFirstNDEFTagRead:
                onResult?(.failure(NFCTagReaderError.invalidated))
            case .readerSessionInvalidationErrorUserCanceled:
                onResult?(.failure(NFCTagReaderError.userCanceled))
            case .readerSessionInvalidationErrorSessionTimeout:
                onResult?(.failure(NFCTagReaderError.timedOut))
            case .readerSessionInvalidationErrorSystemIsBusy:
                onResult?(.failure(NFCTagReaderError.systemBusy))
            case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
                onResult?(.failure(NFCTagReaderError.terminatedUnexpectedly))
            default:
                onResult?(.failure(NFCTagReaderError.invalidated))
            }
            cleanup()
            return
        }

        onResult?(.failure(NFCTagReaderError.invalidated))
        cleanup()
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let firstTag = tags.first else {
            onResult?(.failure(NFCTagReaderError.unknownTag))
            cleanup()
            return
        }

        session.connect(to: firstTag) { [weak self] error in
            guard let self else { return }

            if let error {
                self.onResult?(.failure(error))
                self.cleanup()
                return
            }

            let identifier: Data?

            switch firstTag {
            case .miFare(let tag):
                identifier = tag.identifier
            case .iso7816(let tag):
                identifier = tag.identifier
            case .iso15693(let tag):
                identifier = tag.identifier
            case .feliCa(let tag):
                identifier = tag.currentIDm
            @unknown default:
                identifier = nil
            }

            guard let identifier, !identifier.isEmpty else {
                self.onResult?(.failure(NFCTagReaderError.unknownTag))
                self.cleanup()
                return
            }

            let scannedIdentifier = identifier.map { String(format: "%02X", $0) }.joined()
            if let expectedIdentifier = self.expectedIdentifier,
               !expectedIdentifier.isEmpty,
               scannedIdentifier != expectedIdentifier {
                session.invalidate(errorMessage: self.unexpectedTagMessage ?? "Ese tag no está vinculado a esta cuenta.")
                self.onResult?(.failure(NFCTagReaderError.unexpectedTag))
                self.cleanup()
                return
            }

            let scanResult = NFCTagScanResult(identifier: scannedIdentifier)
            session.alertMessage = "Tag detectado."
            self.onResult?(.success(scanResult))
            session.invalidate()
            self.cleanup()
        }
    }

    private func cleanup() {
        onResult = nil
        expectedIdentifier = nil
        unexpectedTagMessage = nil
        session = nil
    }
}
