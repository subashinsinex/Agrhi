import Flutter
import UIKit
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let registrar = registrar(forPlugin: "AgrhiNative")!
    let channel = FlutterMethodChannel(name: "app.agrhi.com/native", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "packageInfo":
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              let packageName = Bundle.main.bundleIdentifier else {
          result(FlutterError(code: "metadata", message: "Missing installed app metadata", details: nil))
          return
        }
        result(["buildNumber": build, "packageName": packageName])
      case "compressImage":
        guard let args = call.arguments as? [String: String],
              let source = args["source"], let destination = args["destination"],
              source != destination else {
          result(FlutterError(code: "compression", message: "Invalid image paths", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let outputURL = URL(fileURLWithPath: destination)
          let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1280,
            kCGImageSourceShouldCacheImmediately: true
          ]
          guard let input = CGImageSourceCreateWithURL(URL(fileURLWithPath: source) as CFURL, nil),
                let image = CGImageSourceCreateThumbnailAtIndex(input, 0, options as CFDictionary),
                let output = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.jpeg" as CFString, 1, nil) else {
            DispatchQueue.main.async { result(FlutterError(code: "compression", message: "Cannot decode image", details: nil)) }
            return
          }
          CGImageDestinationAddImage(output, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
          let success = CGImageDestinationFinalize(output)
          if !success { try? FileManager.default.removeItem(at: outputURL) }
          DispatchQueue.main.async {
            if success { result(destination) }
            else { result(FlutterError(code: "compression", message: "JPEG encoding failed", details: nil)) }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
