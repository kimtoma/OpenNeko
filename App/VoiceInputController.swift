import AVFoundation
import Foundation
import Speech
import OpenNekoKit

/// Push-to-talk speech recognition for the chat field. Recognition is forced
/// on device (`requiresOnDeviceRecognition`); if the Mac can't do that for
/// the language, voice input fails instead of sending audio to a server.
/// Decisions (permission order, locale, merging) live in `VoiceInputPolicy`.
final class VoiceInputController: ObservableObject {
    static let shared = VoiceInputController()

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var failure: VoiceInputFailure?

    var languageCode: () -> String = { AppLanguage.resolved(nil) }

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var limitTimer: Timer?
    /// True between press and release; a permission prompt answered after
    /// release must not start recording.
    private var wantsToListen = false

    func press() {
        wantsToListen = true
        failure = nil
        transcript = ""
        proceed()
    }

    func release() {
        wantsToListen = false
        stop()
    }

    private func proceed() {
        guard wantsToListen, !isListening else { return }
        let locale = Locale(identifier: VoiceInputPolicy.localeIdentifier(languageCode: languageCode()))
        let recognizer = SFSpeechRecognizer(locale: locale)
        self.recognizer = recognizer
        let step = VoiceInputPolicy.nextStep(
            microphone: Self.microphonePermission(),
            speech: Self.speechPermission(),
            onDeviceSupported: recognizer?.supportsOnDeviceRecognition ?? false
        )
        switch step {
        case .requestMicrophone:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.proceed()
                    } else {
                        self?.failure = .microphoneDenied
                    }
                }
            }
        case .requestSpeechRecognition:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self?.proceed()
                    } else {
                        self?.failure = .speechDenied
                    }
                }
            }
        case let .fail(reason):
            failure = reason
        case .start:
            start(with: recognizer)
        }
    }

    private func start(with recognizer: SFSpeechRecognizer?) {
        guard let recognizer, recognizer.isAvailable else {
            failure = .onDeviceUnavailable
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            failure = .audioUnavailable
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            failure = .audioUnavailable
            return
        }

        isListening = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.finish()
                }
            }
        }
        limitTimer = Timer.scheduledTimer(withTimeInterval: VoiceInputPolicy.maxDuration, repeats: false) { [weak self] _ in
            self?.release()
        }
    }

    /// Stops recording; the recognizer then delivers its final result.
    private func stop() {
        limitTimer?.invalidate()
        limitTimer = nil
        guard engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
    }

    private func finish() {
        stop()
        task = nil
        request = nil
        if isListening, transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failure = .nothingHeard
        }
        isListening = false
    }

    private static func microphonePermission() -> VoicePermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private static func speechPermission() -> VoicePermission {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}
