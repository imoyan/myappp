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
      // ── OCR Channel ──
      let ocrChannel = FlutterMethodChannel(
        name: "screen_translator/ocr",
        binaryMessenger: controller.binaryMessenger
      )
      ocrChannel.setMethodCallHandler { [weak self] call, result in
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

      // ── Translation Channel ──
      let translationChannel = FlutterMethodChannel(
        name: "screen_translator/translation",
        binaryMessenger: controller.binaryMessenger
      )
      translationChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "DEALLOCATED", message: "AppDelegate deallocated", details: nil))
          return
        }
        switch call.method {
        case "isAvailable":
          self.checkTranslationAvailable(result: result)
        case "translate":
          self.translateText(call: call, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: - OCR

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
      let lines = observations.compactMap { $0.topCandidates(1).first?.string }
      result(lines.joined(separator: "\n"))
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US", "ja-JP", "zh-Hans", "zh-Hant", "ko-KR",
                                     "fr-FR", "de-DE", "es-ES", "pt-BR", "it-IT"]

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        result(FlutterError(code: "VISION_PERFORM_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }

  // MARK: - Translation

  private func checkTranslationAvailable(result: @escaping FlutterResult) {
    if #available(iOS 17.4, *) {
      result(true)
    } else {
      result(false)
    }
  }

  private func translateText(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let text = args["text"] as? String,
      let targetCode = args["targetLanguage"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "text, targetLanguage required", details: nil))
      return
    }

    let sourceCode = args["sourceLanguage"] as? String

    if #available(iOS 17.4, *) {
      performTranslation(text: text, sourceCode: sourceCode, targetCode: targetCode, result: result)
    } else {
      result(FlutterError(code: "UNSUPPORTED_OS", message: "Translation requires iOS 17.4+", details: nil))
    }
  }

  @available(iOS 17.4, *)
  private func performTranslation(text: String, sourceCode: String?, targetCode: String, result: @escaping FlutterResult) {
    Task {
      do {
        let target = Locale.Language(identifier: targetCode)

        let config: TranslationSession.Configuration
        if let sourceCode = sourceCode, sourceCode != "auto" {
          let source = Locale.Language(identifier: sourceCode)
          config = TranslationSession.Configuration(source: source, target: target)
        } else {
          config = TranslationSession.Configuration(target: target)
        }

        let session = TranslationSession(configuration: config)
        let response = try await session.translate(text)

        let resultDict: [String: Any] = [
          "translatedText": response.targetText,
          "sourceLanguage": response.sourceLanguage.minimalIdentifier,
        ]
        result(resultDict)
      } catch {
        result(FlutterError(code: "TRANSLATION_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }
}
