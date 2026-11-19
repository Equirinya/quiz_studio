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
///
/// While a board is shown, a double-tap on the Pencil switches
/// it between pen and eraser, as the iPad's Pencil settings ask for.
final class PencilDrawing: NSObject, FlutterPlugin, UIPencilInteractionDelegate {
  private weak var registrar: FlutterPluginRegistrar?
  private var removed: [UIInteraction] = []
  private var channel: FlutterMethodChannel?
  private var pencil: UIPencilInteraction?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PencilDrawing()
    instance.registrar = registrar
    let channel = FlutterMethodChannel(name: "quiz_show/pencil", binaryMessenger: registrar.messenger())
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    switch UIPencilInteraction.preferredTapAction {
    case .ignore, .showColorPalette:
      return
    default:
      channel?.invokeMethod("switchTool", arguments: nil)
    }
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
      if pencil == nil {
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
        pencil = interaction
      }
    } else {
      if let interaction = pencil {
        view.removeInteraction(interaction)
        pencil = nil
      }
      for interaction in removed {
        view.addInteraction(interaction)
      }
      removed = []
    }
    result(true)
  }
}
