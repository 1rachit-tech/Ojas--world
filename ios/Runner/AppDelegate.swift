import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = self.registrar(forPlugin: "OjasHlsPlayerPlugin") {
      registrar.register(
        OjasHlsPlayerFactory(),
        withId: "ojas/hls_player"
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

final class OjasHlsPlayerFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let urlString = (args as? [String: Any])?["url"] as? String ?? ""
    return OjasHlsPlayer(frame: frame, urlString: urlString)
  }
}

final class OjasHlsPlayer: NSObject, FlutterPlatformView {
  private let containerView: UIView
  private let player: AVPlayer
  private let playerLayer: AVPlayerLayer

  init(frame: CGRect, urlString: String) {
    containerView = UIView(frame: frame)
    guard let url = URL(string: urlString) else {
      player = AVPlayer()
      playerLayer = AVPlayerLayer(player: player)
      super.init()
      playerLayer.frame = containerView.bounds
      playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
      containerView.layer.addSublayer(playerLayer)
      return
    }

    player = AVPlayer(url: url)
    playerLayer = AVPlayerLayer(player: player)
    super.init()

    player.automaticallyWaitsToMinimizeStalling = false
    player.currentItem?.preferredForwardBufferDuration = 3.0
    playerLayer.videoGravity = .resizeAspectFill
    playerLayer.frame = containerView.bounds
    playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    containerView.backgroundColor = .black
    containerView.layer.addSublayer(playerLayer)
    player.play()

    let tap = UITapGestureRecognizer(target: self, action: #selector(togglePlayback))
    containerView.addGestureRecognizer(tap)
    containerView.isUserInteractionEnabled = true
  }

  func view() -> UIView {
    containerView
  }

  @objc private func togglePlayback() {
    if player.timeControlStatus == .playing {
      player.pause()
    } else {
      player.play()
    }
  }

  deinit {
    player.pause()
    player.replaceCurrentItem(with: nil)
  }
}
