import AVKit

private let defaultPlaybackRate: Double = 1.0
private let defaultVolume: Double = 1.0
private let defaultLooping: Bool = false

typealias Completer = () -> Void
typealias CompleterError = (Error?) -> Void

class WrappedMediaPlayer {
  private(set) var eventHandler: AudioPlayersStreamHandler
  private(set) var isPlaying: Bool
  var looping: Bool

  private var reference: SwiftAudioplayersDarwinPlugin
  private var player: AVPlayer
  private var playbackRate: Double
  private var volume: Double
  private var url: String?

  private var completionObserver: TimeObserver?
  private var playerItemStatusObservation: NSKeyValueObservation?

  init(
    reference: SwiftAudioplayersDarwinPlugin,
    eventHandler: AudioPlayersStreamHandler,
    player: AVPlayer = AVPlayer.init(),
    playbackRate: Double = defaultPlaybackRate,
    volume: Double = defaultVolume,
    looping: Bool = defaultLooping,
    url: String? = nil
  ) {
    self.reference = reference
    self.eventHandler = eventHandler
    self.player = player
    self.completionObserver = nil
    self.playerItemStatusObservation = nil

    self.isPlaying = false
    self.playbackRate = playbackRate
    self.volume = volume
    self.looping = looping
    self.url = url
  }

  func setSourceUrl(
      url: String,
      isLocal: Bool,
      mimeType: String? = nil,
      completer: Completer? = nil,
      completerError: CompleterError? = nil
  ) {
      let playbackStatus = player.currentItem?.status

      activateAudioSession()  // Ensure audio session is activated
      print("Current playback status: \(String(describing: playbackStatus))")

      if self.url != url || playbackStatus == .failed || playbackStatus == nil {
          print("Resetting player and setting new source URL: \(url)")
          reset()
          self.url = url
          do {
              let playerItem = try createPlayerItem(url: url, isLocal: isLocal, mimeType: mimeType)
              // Need to observe item status immediately after creating:
              setUpPlayerItemStatusObservation(
                  playerItem,
                  completer: completer,
                  completerError: completerError)
              // Replacing the player item triggers completion in setUpPlayerItemStatusObservation
              self.player.replaceCurrentItem(with: playerItem)
              self.setUpSoundCompletedObserver(self.player, playerItem)
              print("Player item set and ready to play.")
          } catch {
              print("Error creating player item: \(error.localizedDescription)")
              completerError?(error)
          }
      } else {
          if playbackStatus == .readyToPlay {
              print("Player item is already ready to play.")
              completer?()
          }
      }
  }

  private func activateAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        print("Audio session activated successfully.")
    } catch {
        print("Failed to activate audio session: \(error.localizedDescription)")
    }
  }

  func getDuration() -> Int? {
    guard let duration = getDurationCMTime() else {
      return nil
    }
    return fromCMTime(time: duration)
  }

  func getCurrentPosition() -> Int? {
    guard let time = getCurrentCMTime() else {
      return nil
    }
    return fromCMTime(time: time)
  }

  func pause() {
    isPlaying = false
    player.pause()
  }

  func resume() {
    isPlaying = true
    configParameters(player: player)
    if #available(iOS 10.0, tvOS 10.0, *) {
      player.playImmediately(atRate: Float(playbackRate))
    } else {
      player.play()
    }
    updateDuration()
  }

  func setVolume(volume: Double) {
    self.volume = volume
    player.volume = Float(volume)
  }

  func setPlaybackRate(playbackRate: Double) {
    self.playbackRate = playbackRate
    if isPlaying {
      // Setting the rate causes the player to resume playing. So setting it only, when already playing.
      player.rate = Float(playbackRate)
    }
  }

  func seek(time: CMTime, completer: Completer? = nil) {
    guard let currentItem = player.currentItem else {
      completer?()
      return
    }
    currentItem.seek(to: time) { finished in
      if !self.isPlaying {
        self.player.pause()
      }
      self.eventHandler.onSeekComplete()
      if finished {
        completer?()
      }
    }
  }

  func stop(completer: Completer? = nil) {
    pause()
    seek(time: toCMTime(millis: 0), completer: completer)
  }

  func release(completer: Completer? = nil) {
    stop {
      self.reset()
      self.url = nil
      completer?()
    }
  }

  func dispose(completer: Completer? = nil) {
    release {
      completer?()
    }
  }

  private func getDurationCMTime() -> CMTime? {
    return player.currentItem?.asset.duration
  }

  private func getCurrentCMTime() -> CMTime? {
    return player.currentItem?.currentTime()
  }

  private func createPlayerItem(url: String, isLocal: Bool, mimeType: String?) throws -> AVPlayerItem {
      let asset: AVAsset
      if isLocal {
          let fileURL = URL(fileURLWithPath: url)
          asset = AVAsset(url: fileURL)
      } else {
          guard let fileURL = URL(string: url) else {
              throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
          }
          asset = AVAsset(url: fileURL)
      }

      let playerItem = AVPlayerItem(asset: asset)
      asset.loadValuesAsynchronously(forKeys: ["playable"]) {
          var error: NSError? = nil
          let status = asset.statusOfValue(forKey: "playable", error: &error)
          switch status {
          case .loaded:
              print("Asset loaded and playable.")
          case .failed:
              print("Asset failed to load: \(error?.localizedDescription ?? "Unknown error")")
          default:
              print("Asset loading status: \(status.rawValue)")
          }
      }
      return playerItem
  }

  private func setUpPlayerItemStatusObservation(
      _ playerItem: AVPlayerItem,
      completer: Completer?,
      completerError: CompleterError?
  ) {
      playerItem.observe(\.status, options: [.new, .initial]) { item, change in
          switch item.status {
          case .readyToPlay:
              print("Player item is ready to play.")
              completer?()
          case .failed:
              if let error = item.error {
                  print("Player item failed: \(error.localizedDescription)")
                  completerError?(error)
              } else {
                  print("Player item failed with unknown error.")
                  completerError?(NSError(domain: "Unknown", code: -1, userInfo: nil))
              }
          case .unknown:
              print("Player item status is unknown.")
          @unknown default:
              print("Player item status is unrecognized.")
          }
      }
  }

  private func setUpSoundCompletedObserver(_ player: AVPlayer, _ playerItem: AVPlayerItem) {
    let observer = NotificationCenter.default.addObserver(
      forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: nil
    ) {
      [weak self] (notification) in
      self?.onSoundComplete()
    }
    self.completionObserver = TimeObserver(player: player, observer: observer)
  }

  private func configParameters(player: AVPlayer) {
    if isPlaying {
      player.volume = Float(volume)
      player.rate = Float(playbackRate)
    }
  }

  private func reset() {
    playerItemStatusObservation?.invalidate()
    playerItemStatusObservation = nil
    if let cObserver = completionObserver {
      NotificationCenter.default.removeObserver(cObserver.observer)
      completionObserver = nil
    }
    player.replaceCurrentItem(with: nil)
  }

  private func updateDuration() {
    guard let duration = player.currentItem?.asset.duration else {
      return
    }
    if CMTimeGetSeconds(duration) > 0 {
      let millis = fromCMTime(time: duration)
      eventHandler.onDuration(millis: millis)
    }
  }

  private func onSoundComplete() {
    if !isPlaying {
      return
    }

    seek(time: toCMTime(millis: 0)) {
      if self.looping {
        self.resume()
      } else {
        self.isPlaying = false
      }
    }

    reference.controlAudioSession()
    eventHandler.onComplete()
  }
}
