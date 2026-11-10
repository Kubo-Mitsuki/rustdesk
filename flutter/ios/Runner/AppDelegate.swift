import UIKit
import Flutter
import AVFoundation

// Flutter cannot hide the iPad pointer (SystemMouseCursors.none has no effect on
// iOS), so on the remote page the iPad pointer and the remote PC's cursor are
// drawn on top of each other. The remote page asks to hide it over this channel.
// Flutter tracks the pointer with a hover gesture recognizer, which keeps working
// while the pointer style is hidden.
class IrisPointerHider: NSObject, UIPointerInteractionDelegate {
  private var hidden = false
  private var interaction: UIPointerInteraction?

  func attach(to controller: FlutterViewController) {
    let interaction = UIPointerInteraction(delegate: self)
    controller.view.addInteraction(interaction)
    self.interaction = interaction
    FlutterMethodChannel(name: "iris/pointer", binaryMessenger: controller.binaryMessenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "setHidden", let hidden = call.arguments as? Bool else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.hidden = hidden
        self?.interaction?.invalidate()
        result(nil)
      }
  }

  func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
    return hidden ? UIPointerStyle.hidden() : nil
  }
}

// In iPadOS windowed mode, a drag near the top edge moves the iPad window, so dragging
// a remote PC window by its title bar moved Iris instead. Deferring the top edge asks
// the system to let the app see the touch first (Moonlight does the same for all edges).
// Only the top: deferring the bottom would make going home take two swipes.
class IrisViewController: FlutterViewController {
  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return .top
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pointerHider = IrisPointerHider()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    do {
      // Mix remote audio with other apps while still respecting silent mode.
      try AVAudioSession.sharedInstance().setCategory(.ambient)
    } catch {
      NSLog("Failed to configure audio mixing: %@", error.localizedDescription)
    }
    dummyMethodToEnforceBundling();
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // With the UIScene life cycle, the FlutterViewController only exists once the scene
  // connects, and FlutterAppDelegate reaches its engine through `window`. A launch URL
  // also arrives with the scene instead of in launchOptions, so forward it to plugins here.
  func sceneWillConnect(window: UIWindow?, launchURL: URL?) {
    self.window = window
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      pointerHider.attach(to: controller)
    }
    var launchOptions: [UIApplication.LaunchOptionsKey: Any] = [:]
    if let launchURL = launchURL {
      launchOptions[.url] = launchURL
    }
    _ = super.application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)
  }
    
  public func dummyMethodToEnforceBundling() {
      dummy_method_to_enforce_bundling();
    session_get_rgba(nil, 0);
  }
}
