import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var pendingImagePickResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let printChannel = FlutterMethodChannel(
      name: "com.akarworks.hasibu/print",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    printChannel.setMethodCallHandler { call, result in
      guard call.method == "printHtml" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      guard let html = args?["html"] as? String, !html.isEmpty else {
        result(FlutterError(code: "PRINT_ERROR", message: "Yazdırılacak HTML içeriği boş.", details: nil))
        return
      }
      let jobName = (args?["jobName"] as? String) ?? "Hasibu_Belge"
      let landscape = (args?["landscape"] as? Bool) ?? false

      DispatchQueue.main.async {
        let controller = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = jobName
        printInfo.orientation = landscape ? .landscape : .portrait
        controller.printInfo = printInfo
        controller.printFormatter = UIMarkupTextPrintFormatter(markupText: html)
        controller.present(animated: true) { _, completed, error in
          if let error = error {
            result(FlutterError(code: "PRINT_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(completed)
          }
        }
      }
    }

    let filesChannel = FlutterMethodChannel(
      name: "com.akarworks.hasibu/files",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    filesChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickImageFile" || call.method == "pickDocumentFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self else {
        result(nil)
        return
      }
      if self.pendingImagePickResult != nil {
        result(FlutterError(code: "PICK_IN_PROGRESS", message: "Zaten bir dosya seçici açık.", details: nil))
        return
      }
      let isDocument = call.method == "pickDocumentFile"
      DispatchQueue.main.async {
        let sceneRootVc = UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap { $0.windows }
          .first { $0.isKeyWindow }?
          .rootViewController
        guard let rootVc = self.window?.rootViewController ?? sceneRootVc else {
          result(nil)
          return
        }
        self.pendingImagePickResult = result
        let types: [UTType] = isDocument
          ? [.pdf, .image, .plainText, .commaSeparatedText, .data]
          : [.image]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        rootVc.present(picker, animated: true)
      }
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let pending = pendingImagePickResult
    pendingImagePickResult = nil
    pending?(urls.first?.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let pending = pendingImagePickResult
    pendingImagePickResult = nil
    pending?(nil)
  }
}
