import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushNotificationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "PushNotificationPermissionChannel"
    )
    pushNotificationChannel = FlutterMethodChannel(
      name: "maum_on_mobile/push_notifications",
      binaryMessenger: registrar.messenger()
    )
    pushNotificationChannel?.setMethodCallHandler(handlePushNotificationCall)
  }

  private func handlePushNotificationCall(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard call.method == "requestPermission" else {
      result(FlutterMethodNotImplemented)
      return
    }

    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      DispatchQueue.main.async {
        if granted {
          UIApplication.shared.registerForRemoteNotifications()
        }
        result(self.permissionPayload(granted: granted, error: error))
      }
    }
  }

  private func permissionPayload(granted: Bool, error: Error?) -> [String: Any] {
    var payload: [String: Any] = [
      "granted": granted,
      "platform": "IOS",
    ]
    if granted {
      payload["token"] = deviceToken()
    } else {
      payload["message"] = error?.localizedDescription ?? "알림 권한이 허용되지 않았습니다."
    }
    return payload
  }

  private func deviceToken() -> String {
    let identifier = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    return "ios-\(identifier)"
  }
}
