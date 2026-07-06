import Foundation
import AVFoundation
import Speech

/// Streams microphone audio into SFSpeechRecognizer and reports
/// partial transcripts, audio levels, and the final transcript.
final class TranscriptionService: NSObject {

    var onPartial: ((String) -> Void)?
    var onLevel: ((Float) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var latestTranscript: String = ""
    private var finishCompletion: ((String) -> Void)?
    private var finishTimeout: DispatchWorkItem?
    private(set) var isRunning = false

    func start(locale: Locale, preferOnDevice: Bool, contextualStrings: [String]) throws {
        guard !isRunning else { return }

        let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "VoxType", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available for this language."])
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        if preferOnDevice && recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.contextualStrings = contextualStrings
        self.request = request

        latestTranscript = ""

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let result {
                    self.latestTranscript = result.bestTranscription.formattedString
                    self.onPartial?(self.latestTranscript)
                    if result.isFinal {
                        self.deliverFinal()
                    }
                }
                if error != nil {
                    self.deliverFinal()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw NSError(domain: "VoxType", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No microphone input is available."])
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.request?.append(buffer)
            let level = Self.rmsLevel(buffer: buffer)
            DispatchQueue.main.async {
                self.onLevel?(level)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
    }

    /// Stop capturing audio and wait (briefly) for the recognizer's final result.
    func stop(completion: @escaping (String) -> Void) {
        guard isRunning else {
            completion(latestTranscript)
            return
        }
        stopAudio()
        finishCompletion = completion
        request?.endAudio()

        // Fallback: if the recognizer never sends a final result, use the
        // best transcript we have after a short grace period.
        let timeout = DispatchWorkItem { [weak self] in
            self?.deliverFinal()
        }
        finishTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: timeout)
    }

    /// Abort and discard everything.
    func cancel() {
        stopAudio()
        finishCompletion = nil
        finishTimeout?.cancel()
        finishTimeout = nil
        task?.cancel()
        task = nil
        request = nil
        latestTranscript = ""
    }

    private func stopAudio() {
        guard isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRunning = false
    }

    private func deliverFinal() {
        finishTimeout?.cancel()
        finishTimeout = nil
        guard let completion = finishCompletion else { return }
        finishCompletion = nil
        task?.cancel()
        task = nil
        request = nil
        completion(latestTranscript)
    }

    private static func rmsLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frames))
        // Map to a 0...1 range that looks lively in the HUD.
        let db = 20 * log10(max(rms, 0.000_01))
        let normalized = (db + 50) / 50
        return min(max(normalized, 0), 1)
    }
}
