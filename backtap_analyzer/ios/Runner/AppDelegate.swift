import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "backtap_analyzer/ocr", binaryMessenger: controller.binaryMessenger)

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "DEALLOCATED", message: "AppDelegate deallocated", details: nil))
          return
        }

        guard call.method == "extractTextFromImage" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "image path is required", details: nil))
          return
        }

        self.extractTextFromImage(path: path, result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func extractTextFromImage(path: String, result: @escaping FlutterResult) {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      result(FlutterError(code: "IMAGE_LOAD_FAILED", message: "failed to load image", details: path))
      return
    }

    let request = VNRecognizeTextRequest { request, error in
      if let error {
        result(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
        return
      }

      guard let observations = request.results as? [VNRecognizedTextObservation] else {
        result(FlutterError(code: "VISION_EMPTY", message: "no observations", details: nil))
        return
      }

      let lines = observations.compactMap { observation in
        observation.topCandidates(1).first?.string
      }

      result(lines.joined(separator: "\n"))
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        result(FlutterError(code: "VISION_PERFORM_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }
}
