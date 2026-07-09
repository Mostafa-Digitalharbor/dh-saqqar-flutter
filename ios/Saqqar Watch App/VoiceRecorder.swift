import AVFoundation
import Foundation

/// Records a short voice note straight to disk so `PhoneSession` can hand
/// the raw bytes to the phone over `WCSession` — the watch has no speech
/// or network stack of its own, so all it owns is capture.
final class VoiceRecorder: NSObject, ObservableObject {
  @Published private(set) var isRecording = false
  @Published private(set) var elapsed: TimeInterval = 0
  @Published var lastError: String?

  /// Hard stop so a forgotten recording never grows into a multi-minute
  /// upload over an interactive `WCSession` message.
  static let maxDuration: TimeInterval = 20

  private var recorder: AVAudioRecorder?
  private var timer: Timer?
  private var startDate: Date?

  func requestPermissionAndStart(completion: @escaping (Bool) -> Void) {
    AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
      DispatchQueue.main.async {
        guard let self else { return }
        guard granted else {
          self.lastError = "Microphone access is required."
          completion(false)
          return
        }
        completion(self.start())
      }
    }
  }

  @discardableResult
  private func start() -> Bool {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default)
      try session.setActive(true)
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
      ]
      let recorder = try AVAudioRecorder(url: Self.newRecordingURL(), settings: settings)
      recorder.delegate = self
      recorder.record(forDuration: Self.maxDuration)
      self.recorder = recorder
      startDate = Date()
      elapsed = 0
      isRecording = true
      timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        guard let self, let startDate = self.startDate else { return }
        self.elapsed = Date().timeIntervalSince(startDate)
      }
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  /// Stops the active recording and returns its file URL, or `nil` if
  /// nothing was captured.
  @discardableResult
  func stop() -> URL? {
    guard let recorder else { return nil }
    let url = recorder.url
    recorder.stop()
    self.recorder = nil
    stopTimer()
    isRecording = false
    return url
  }

  /// Stops and discards the in-progress recording without handing back a
  /// file — used for the watch's "Cancel" affordance.
  func cancel() {
    guard let recorder else { return }
    recorder.stop()
    recorder.deleteRecording()
    self.recorder = nil
    stopTimer()
    isRecording = false
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  private static func newRecordingURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("saqqar-voice-\(UUID().uuidString).m4a")
  }
}

extension VoiceRecorder: AVAudioRecorderDelegate {
  /// Fires when `maxDuration` is hit without an explicit `stop()` call —
  /// the recorder itself is authoritative here, so just mirror its state.
  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.isRecording = false
      self?.stopTimer()
    }
  }
}
