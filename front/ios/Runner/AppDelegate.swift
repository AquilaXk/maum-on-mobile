import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushNotificationChannel: FlutterMethodChannel?
  private var pendingPushResult: FlutterResult?
  private var latestDeviceToken: String?
  private var initialNotificationPayload: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      initialNotificationPayload = notificationPayload(from: payload)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "PushNotificationPermissionChannel"
    ) else {
      return
    }
    pushNotificationChannel = FlutterMethodChannel(
      name: "maum_on_mobile/push_notifications",
      binaryMessenger: registrar.messenger()
    )
    pushNotificationChannel?.setMethodCallHandler(handlePushNotificationCall)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    latestDeviceToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    completePendingPermission(granted: true, message: nil)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    completePendingPermission(granted: true, message: error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let payload = notificationPayload(
      from: response.notification.request.content.userInfo
    )
    if let payload {
      pushNotificationChannel?.invokeMethod("notificationTapped", arguments: payload)
    }
    completionHandler()
  }

  private func handlePushNotificationCall(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "requestPermission":
      requestPermission(result: result)
    case "getPermissionStatus":
      getPermissionStatus(result: result)
    case "openSettings":
      openSettings(result: result)
    case "consumeInitialPayload":
      let payload = initialNotificationPayload
      initialNotificationPayload = nil
      result(payload)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      DispatchQueue.main.async {
        guard granted else {
          result(self.permissionPayload(
            granted: false,
            token: nil,
            message: error?.localizedDescription ?? "알림 권한이 허용되지 않았습니다."
          ))
          return
        }

        self.completePermissionAfterRemoteRegistration(result: result)
      }
    }
  }

  private func getPermissionStatus(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        let granted = settings.authorizationStatus == .authorized ||
          settings.authorizationStatus == .provisional ||
          settings.authorizationStatus == .ephemeral
        guard granted else {
          result(self.permissionPayload(
            granted: false,
            token: nil,
            message: "알림 권한이 허용되지 않았습니다."
          ))
          return
        }

        self.completePermissionAfterRemoteRegistration(result: result)
      }
    }
  }

  private func openSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(url) { opened in
      result(opened)
    }
  }

  private func completePermissionAfterRemoteRegistration(
    result: @escaping FlutterResult
  ) {
    if let latestDeviceToken {
      result(permissionPayload(granted: true, token: latestDeviceToken, message: nil))
      return
    }

    pendingPushResult?(permissionPayload(
      granted: true,
      token: nil,
      message: "다른 알림 권한 요청이 진행 중입니다."
    ))
    pendingPushResult = result
    UIApplication.shared.registerForRemoteNotifications()
  }

  private func completePendingPermission(granted: Bool, message: String?) {
    guard let result = pendingPushResult else {
      return
    }
    pendingPushResult = nil
    result(permissionPayload(
      granted: granted,
      token: latestDeviceToken,
      message: message
    ))
  }

  private func permissionPayload(
    granted: Bool,
    token: String?,
    message: String?
  ) -> [String: Any] {
    var payload: [String: Any] = [
      "granted": granted,
      "platform": "IOS",
      "canOpenSettings": true,
    ]
    if let token {
      payload["token"] = token
    }
    if let message {
      payload["message"] = message
    }
    return payload
  }

  private func notificationPayload(from userInfo: [AnyHashable: Any]) -> [String: Any]? {
    var payload: [String: Any] = [:]
    for key in ["type", "event", "route", "destination", "notificationId", "letterId", "reportId"] {
      if let value = userInfo[key] {
        payload[key] = "\(value)"
      }
    }
    return payload.isEmpty ? nil : payload
  }
}
