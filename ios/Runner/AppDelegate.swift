import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // With the scene lifecycle the engine is created by the scene, so plugins
  // are registered here instead of in didFinishLaunching.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PencilDrawing") {
      PencilDrawing.register(with: registrar)
    }
  }
}

/// Apple Pencil on a whiteboard. Flutter puts an indirect Scribble
/// interaction (handwriting into text fields) on its whole view, and while it
/// is there iPadOS holds back the start of every Pencil stroke to find out
/// whether it is handwriting: the first moments of a stroke arrive late or
/// not at all. The app takes it off while a board is on screen.
final class PencilDrawing: NSObject, FlutterPlugin {
  private weak var registrar: FlutterPluginRegistrar?
  private var removed: [UIInteraction] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PencilDrawing()
    instance.registrar = registrar
    let channel = FlutterMethodChannel(name: "quiz_show/pencil", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "drawing", let drawing = call.arguments as? Bool else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let view = registrar?.viewController?.view else {
      result(false)
      return
    }
    if drawing {
      // UIIndirectScribbleInteraction is generic over its delegate, so Swift
      // cannot test for it with `is`; Flutter makes it in Objective-C, where
      // the class keeps its plain name.
      let scribbles = view.interactions.filter {
        NSStringFromClass(type(of: $0)).contains("IndirectScribbleInteraction")
      }
      for interaction in scribbles {
        view.removeInteraction(interaction)
      }
      removed += scribbles
    } else {
      for interaction in removed {
        view.addInteraction(interaction)
      }
      removed = []
    }
    result(true)
  }
}
