import Flutter
import Security
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushNotificationChannel: FlutterMethodChannel?
  private var diaryImagePickerChannel: DiaryImagePickerChannel?
  private var secureStorageChannel: SecureStorageChannel?
  private var urlLauncherChannel: UrlLauncherChannel?
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
    if let launchUrl = launchOptions?[.url] as? URL {
      DeepLinkChannelBridge.shared.recordInitialUrl(launchUrl)
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
    let messenger = registrar.messenger()
    pushNotificationChannel = FlutterMethodChannel(
      name: "maum_on_mobile/push_notifications",
      binaryMessenger: messenger
    )
    pushNotificationChannel?.setMethodCallHandler(handlePushNotificationCall)
    diaryImagePickerChannel = DiaryImagePickerChannel(binaryMessenger: messenger)
    secureStorageChannel = SecureStorageChannel(binaryMessenger: messenger)
    urlLauncherChannel = UrlLauncherChannel(binaryMessenger: messenger)
    DeepLinkChannelBridge.shared.attach(binaryMessenger: messenger)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let handled = DeepLinkChannelBridge.shared.handleIncomingUrl(url)
    return super.application(app, open: url, options: options) || handled
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

final class SecureStorageChannel {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "com.aquilaxk.maumonmobile.secureStorage")
  private let service = "com.aquilaxk.maumonmobile.secure_kv"
  private let maxKeyLength = 256
  private let maxValueLength = 262_144

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "maum_on_mobile/secure_storage",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler(handleCall)
  }

  private func handleCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "read":
      handleRead(call: call, result: result)
    case "write":
      handleWrite(call: call, result: result)
    case "delete":
      handleDelete(call: call, result: result)
    case "readAll":
      handleReadAll(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func validatedKey(from call: FlutterMethodCall, result: @escaping FlutterResult) -> String? {
    guard
      let arguments = call.arguments as? [String: Any],
      let key = arguments["key"] as? String,
      !key.isEmpty,
      key.count <= maxKeyLength
    else {
      result(FlutterError(
        code: "SECURE_STORAGE_INVALID_ARGUMENT",
        message: "Secure storage key must be 1..\(maxKeyLength) characters.",
        details: nil
      ))
      return nil
    }
    return key
  }

  private func handleRead(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let key = validatedKey(from: call, result: result) else {
      return
    }
    queue.async {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: self.service,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
      ]
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      if status == errSecItemNotFound {
        DispatchQueue.main.async { result(nil) }
        return
      }
      guard status == errSecSuccess else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "SECURE_STORAGE_READ_FAILED",
            message: "Keychain read failed (\(status)).",
            details: nil
          ))
        }
        return
      }
      guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
        let deleteQuery: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: self.service,
          kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        DispatchQueue.main.async { result(nil) }
        return
      }
      DispatchQueue.main.async { result(value) }
    }
  }

  private func handleWrite(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let key = validatedKey(from: call, result: result) else {
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let value = arguments["value"] as? String,
      value.count <= maxValueLength,
      let data = value.data(using: .utf8)
    else {
      result(FlutterError(
        code: "SECURE_STORAGE_INVALID_ARGUMENT",
        message: "Secure storage value exceeds limit or is missing.",
        details: nil
      ))
      return
    }

    queue.async {
      let addQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: self.service,
        kSecAttrAccount as String: key,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecValueData as String: data,
      ]
      var status = SecItemAdd(addQuery as CFDictionary, nil)
      if status == errSecDuplicateItem {
        let matchQuery: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: self.service,
          kSecAttrAccount as String: key,
        ]
        let updateAttributes: [String: Any] = [
          kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
          kSecValueData as String: data,
        ]
        status = SecItemUpdate(matchQuery as CFDictionary, updateAttributes as CFDictionary)
      }
      if status == errSecSuccess {
        DispatchQueue.main.async { result(nil) }
      } else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "SECURE_STORAGE_WRITE_FAILED",
            message: "Keychain write failed (\(status)).",
            details: nil
          ))
        }
      }
    }
  }

  private func handleDelete(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let key = validatedKey(from: call, result: result) else {
      return
    }
    queue.async {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: self.service,
        kSecAttrAccount as String: key,
      ]
      let status = SecItemDelete(query as CFDictionary)
      if status == errSecSuccess || status == errSecItemNotFound {
        DispatchQueue.main.async { result(nil) }
      } else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "SECURE_STORAGE_DELETE_FAILED",
            message: "Keychain delete failed (\(status)).",
            details: nil
          ))
        }
      }
    }
  }

  private func handleReadAll(result: @escaping FlutterResult) {
    queue.async {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: self.service,
        kSecReturnAttributes as String: true,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitAll,
      ]
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      if status == errSecItemNotFound {
        DispatchQueue.main.async { result([String: String]()) }
        return
      }
      guard status == errSecSuccess else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "SECURE_STORAGE_READ_FAILED",
            message: "Keychain readAll failed (\(status)).",
            details: nil
          ))
        }
        return
      }
      guard let entries = item as? [[String: Any]] else {
        DispatchQueue.main.async { result([String: String]()) }
        return
      }
      var resultMap: [String: String] = [:]
      for entry in entries {
        if let key = entry[kSecAttrAccount as String] as? String,
           let data = entry[kSecValueData as String] as? Data,
           let value = String(data: data, encoding: .utf8) {
          resultMap[key] = value
        }
      }
      DispatchQueue.main.async { result(resultMap) }
    }
  }
}

final class UrlLauncherChannel {
  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "maum_on_mobile/external_url",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler(handleCall)
  }

  private func handleCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "launchUrl" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let rawUrl = arguments["url"] as? String
    else {
      result(false)
      return
    }

    let trimmed = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      !trimmed.isEmpty,
      !trimmed.contains("\r"),
      !trimmed.contains("\n"),
      let url = URL(string: trimmed),
      let scheme = url.scheme?.lowercased(),
      isAllowedUrl(url, scheme: scheme)
    else {
      result(false)
      return
    }

    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    }
  }

  private func isAllowedUrl(_ url: URL, scheme: String) -> Bool {
    switch scheme {
    case "https", "http":
      return !(url.host?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    case "tel", "mailto":
      let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path
      return !(path?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    default:
      return false
    }
  }
}

final class DeepLinkChannelBridge {
  static let shared = DeepLinkChannelBridge()

  private let lock = NSLock()
  private var channel: FlutterMethodChannel?
  private var pendingInitialLink: String?
  private var hasDeliveredInitialQuery = false

  private init() {}

  func attach(binaryMessenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "maum_on_mobile/deep_links",
      binaryMessenger: binaryMessenger
    )
    lock.lock()
    channel = methodChannel
    lock.unlock()
    methodChannel.setMethodCallHandler(handleCall)
  }

  func recordInitialUrl(_ url: URL) {
    let value = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      return
    }
    lock.lock()
    if !hasDeliveredInitialQuery {
      pendingInitialLink = value
    }
    lock.unlock()
  }

  @discardableResult
  func handleIncomingUrl(_ url: URL) -> Bool {
    let value = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      return false
    }
    lock.lock()
    let activeChannel = channel
    let shouldEmitLive = activeChannel != nil && hasDeliveredInitialQuery
    if !shouldEmitLive {
      pendingInitialLink = value
    }
    lock.unlock()

    if shouldEmitLive {
      DispatchQueue.main.async {
        activeChannel?.invokeMethod("onDeepLink", arguments: value)
      }
    }
    return true
  }

  private func handleCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInitialLink":
      lock.lock()
      let initial = pendingInitialLink
      pendingInitialLink = nil
      hasDeliveredInitialQuery = true
      lock.unlock()
      result(initial)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
