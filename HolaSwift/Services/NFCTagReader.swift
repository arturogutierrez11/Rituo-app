import CoreNFC
import Foundation

enum NFCTagReaderError: LocalizedError {
    case unsupported
    case invalidated
    case unknownTag

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Este dispositivo no soporta lectura NFC."
        case .invalidated:
            return "La lectura NFC fue cancelada o interrumpida."
        case .unknownTag:
            return "No se pudo identificar este tag NFC."
        }
    }
}

struct NFCTagScanResult: Equatable {
    let identifier: String
}

final class NFCTagReader: NSObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    private var onResult: ((Result<NFCTagScanResult, Error>) -> Void)?

    func beginScanning(alertMessage: String, onResult: @escaping (Result<NFCTagScanResult, Error>) -> Void) {
        guard NFCTagReaderSession.readingAvailable else {
            onResult(.failure(NFCTagReaderError.unsupported))
            return
        }

        self.onResult = onResult
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
        if nsError.domain == NFCReaderError.errorDomain &&
            (nsError.code == NFCReaderError.readerSessionInvalidationErrorFirstNDEFTagRead.rawValue ||
             nsError.code == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue) {
            onResult?(.failure(NFCTagReaderError.invalidated))
            cleanup()
            return
        }

        onResult?(.failure(error))
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

            let scanResult = NFCTagScanResult(identifier: identifier.map { String(format: "%02X", $0) }.joined())
            session.alertMessage = "Tag detectado."
            self.onResult?(.success(scanResult))
            session.invalidate()
            self.cleanup()
        }
    }

    private func cleanup() {
        onResult = nil
        session = nil
    }
}
