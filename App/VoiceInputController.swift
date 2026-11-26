import AVFoundation
import Foundation
import Speech
import OpenNekoKit

/// Tap-to-talk dictation for the chat field (tap to start, tap again or
/// pause to finish, Esc to cancel). Recognition is forced
/// on device (`requiresOnDeviceRecognition`); if the Mac can't do that for
/// the language, voice input fails instead of sending audio to a server.
/// Decisions (permission order, locale, merging) live in `VoiceInputPolicy`.
final class VoiceInputController: ObservableObject {
    static let shared = VoiceInputController()

    @Published private(set) var isListening = false
    /// True from the tap until listening ends, including while a permission
    /// prompt is up, so the button can show a stop state right away.
    @Published private(set) var isActive = false
    @Published private(set) var transcript = ""
    @Published private(set) var failure: VoiceInputFailure?

    var languageCode: () -> String = { AppLanguage.resolved(nil) }

    /// Recreated for every dictation: an engine made before the mic
    /// permission was granted, or before the input device changed, keeps a
    /// stale format and `installTap` then raises an exception.
    private var engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var finalResultTimer: Timer?
    private var sessions = VoiceDictationSessions()
    private var configurationObserver: NSObjectProtocol?
    private var engineRestarts = 0
    private var startedAt: TimeInterval = 0
    private var lastChangeAt: TimeInterval?
    /// False once the person stopped or cancelled; a permission prompt
    /// answered after that must not start recording.
    private var wantsToListen = false

    /// Mic button: starts dictation, or finishes it when already active.
    func toggle() {
        if isActive {
            finishListening()
        } else {
            begin()
        }
    }

    /// Ends dictation and keeps what was recognized.
    func finishListening() {
        wantsToListen = false
        if isListening {
            stop()
        } else {
            isActive = false
        }
    }

    /// Ends dictation and throws the transcript away (Esc).
    func cancel() {
        wantsToListen = false
        transcript = ""
        sessions.next()
        task?.cancel()
        stopRecording()
        finalResultTimer?.invalidate()
        finalResultTimer = nil
        task = nil
        request = nil
        isListening = false
        isActive = false
    }

    private func begin() {
        wantsToListen = true
        isActive = true
        failure = nil
        transcript = ""
        proceed()
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
                        self?.isActive = false
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
                        self?.isActive = false
                    }
                }
            }
        case let .fail(reason):
            failure = reason
            isActive = false
        case .start:
            start(with: recognizer)
        }
    }

    private func start(with recognizer: SFSpeechRecognizer?) {
        guard let recognizer, recognizer.isAvailable else {
            failure = .onDeviceUnavailable
            isActive = false
            return
        }
        // A previous dictation that never delivered its final result must
        // not keep running or end this one.
        task?.cancel()
        task = nil
        finalResultTimer?.invalidate()
        finalResultTimer = nil
        let session = sessions.next()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request

        engine = AVAudioEngine()
        engineRestarts = 0
        guard startEngine(feeding: request) else {
            failure = .audioUnavailable
            isActive = false
            return
        }
        observeConfigurationChanges(session: session)

        isListening = true
        startedAt = ProcessInfo.processInfo.systemUptime
        lastChangeAt = nil
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.sessions.isCurrent(session) else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if text != self.transcript {
                        self.transcript = text
                        self.lastChangeAt = ProcessInfo.processInfo.systemUptime
                    }
                }
                if error != nil || result?.isFinal == true {
                    self.finish()
                }
            }
        }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, self.isListening else { return }
            if VoiceInputPolicy.shouldAutoStop(
                startedAt: self.startedAt,
                lastChangeAt: self.lastChangeAt,
                now: ProcessInfo.processInfo.systemUptime
            ) {
                self.finishListening()
            }
        }
    }

    /// Installs the mic tap with the input's current format and starts the
    /// engine.
    private func startEngine(feeding request: SFSpeechAudioBufferRecognitionRequest) -> Bool {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return false }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
            return true
        } catch {
            input.removeTap(onBus: 0)
            return false
        }
    }

    /// macOS stops the engine on its own when the audio devices change
    /// (e.g. a Bluetooth headset switching profiles as the mic opens). Start
    /// it again with the new format, or end the dictation if that fails, so
    /// it never sits in "listening" with no audio coming in.
    private func observeConfigurationChanges(session: Int) {
        removeConfigurationObserver()
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.sessions.isCurrent(session), self.isListening, let request = self.request else { return }
            switch VoiceInputPolicy.afterConfigurationChange(
                engineRunning: self.engine.isRunning,
                restartsSoFar: self.engineRestarts
            ) {
            case .keepGoing:
                break
            case .restart:
                self.engineRestarts += 1
                if !self.startEngine(feeding: request) {
                    self.finishListening()
                }
            case .finish:
                self.finishListening()
            }
        }
    }

    private func removeConfigurationObserver() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
    }

    /// Stops recording; the recognizer then delivers its final result. If it
    /// doesn't within `finalResultTimeout`, the dictation finishes anyway so
    /// the mic can be used again.
    private func stop() {
        stopRecording()
        guard isListening, finalResultTimer == nil else { return }
        let session = sessions.current
        finalResultTimer = Timer.scheduledTimer(withTimeInterval: VoiceInputPolicy.finalResultTimeout, repeats: false) { [weak self] _ in
            guard let self, self.sessions.isCurrent(session), self.isListening else { return }
            self.task?.cancel()
            self.finish()
        }
    }

    /// Also runs when macOS already stopped the engine: the tap still has
    /// to go and the request still needs `endAudio()` to deliver a result.
    private func stopRecording() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        removeConfigurationObserver()
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
    }

    private func finish() {
        stopRecording()
        finalResultTimer?.invalidate()
        finalResultTimer = nil
        task = nil
        request = nil
        if isListening, transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failure = .nothingHeard
        }
        isListening = false
        isActive = false
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
