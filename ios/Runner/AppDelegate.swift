import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  var deepLinkChannel: FlutterMethodChannel?
  var initialLink: String?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    deepLinkChannel = FlutterMethodChannel(
      name: "app.channel.deeplink",
      binaryMessenger: controller.binaryMessenger
    )
    
    // Store initial link if app opened from terminated state
    if let url = launchOptions?[.url] as? URL {
      initialLink = url.absoluteString
    }
    
    // Set method call handler for getInitialLink
    deepLinkChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getInitialLink" {
        // Return stored initial link or nil
        result(self?.initialLink)
        // Clear after returning
        self?.initialLink = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // If there's an initial link, send it after a short delay to ensure Flutter is ready
    if let link = initialLink {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.deepLinkChannel?.invokeMethod("onDeepLink", arguments: link)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle deep link when app is already running
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    deepLinkChannel?.invokeMethod("onDeepLink", arguments: url.absoluteString)
    return true
  }
  
  // Handle universal links (applinks)
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
      if let url = userActivity.webpageURL {
        deepLinkChannel?.invokeMethod("onDeepLink", arguments: url.absoluteString)
        return true
      }
    }
    return false
  }
}
