import Flutter
import ImageIO
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TahrirAppleVisionOcr") {
      let channel = FlutterMethodChannel(
        name: "com.akarworks.tahrir/apple_vision_ocr",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "recognizeImage" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard
          let args = call.arguments as? [String: Any],
          let imagePath = args["imagePath"] as? String,
          !imagePath.isEmpty
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing imagePath", details: nil))
          return
        }
        let languages = args["languages"] as? [String] ?? ["tr-TR", "ar-SA", "en-US"]
        DispatchQueue.global(qos: .userInitiated).async {
          Self.runAppleVisionOcr(imagePath: imagePath, languages: languages, completion: result)
        }
      }
    }
  }

  private static func runAppleVisionOcr(
    imagePath: String,
    languages: [String],
    completion: @escaping FlutterResult
  ) {
    let url = URL(fileURLWithPath: imagePath)
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      DispatchQueue.main.async {
        completion(FlutterError(code: "IMAGE_LOAD_FAILED", message: "Could not decode image", details: imagePath))
      }
      return
    }

    let request = VNRecognizeTextRequest { req, error in
      if let error = error {
        DispatchQueue.main.async {
          completion(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
        }
        return
      }

      let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
      var serializedLines: [[String: Any]] = []

      for observation in observations {
        guard let topCandidate = observation.topCandidates(1).first else { continue }
        let lineBox = observation.boundingBox
        let topLeftY = 1.0 - lineBox.origin.y - lineBox.height

        var wordsList: [[String: Any]] = []
        let textStr = topCandidate.string
        let nsStr = textStr as NSString
        nsStr.enumerateSubstrings(
          in: NSRange(location: 0, length: nsStr.length),
          options: [.byWords]
        ) { substring, substringRange, _, _ in
          guard let wordText = substring, !wordText.isEmpty,
                let swiftRange = Range(substringRange, in: textStr) else {
            return
          }
          do {
            if let wordBoxObservation = try topCandidate.boundingBox(for: swiftRange) {
              let wb = wordBoxObservation.boundingBox
              wordsList.append([
                "text": wordText,
                "confidence": Double(topCandidate.confidence),
                "left": Double(wb.origin.x),
                "top": Double(1.0 - wb.origin.y - wb.height),
                "width": Double(wb.width),
                "height": Double(wb.height),
              ])
            }
          } catch {
            // Word box lookup skipped when range mapping fails
          }
        }

        serializedLines.append([
          "text": textStr,
          "confidence": Double(topCandidate.confidence),
          "left": Double(lineBox.origin.x),
          "top": Double(topLeftY),
          "width": Double(lineBox.width),
          "height": Double(lineBox.height),
          "words": wordsList,
        ])
      }

      DispatchQueue.main.async {
        completion(["lines": serializedLines])
      }
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = languages

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
      try handler.perform([request])
    } catch {
      DispatchQueue.main.async {
        completion(FlutterError(code: "VISION_PERFORM_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }
}
