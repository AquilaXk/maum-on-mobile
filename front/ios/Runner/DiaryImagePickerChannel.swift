import AVFoundation
import Flutter
import Photos
import UIKit

final class DiaryImagePickerChannel: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private let channel: FlutterMethodChannel
  private var pendingResult: FlutterResult?
  private var pendingSource: DiaryImageSource?

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "maum_on_mobile/diary_images",
      binaryMessenger: binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler(handleCall)
  }

  private func handleCall(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "pickDiaryImage":
      pickDiaryImage(call: call, result: result)
    case "openSettings":
      openSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickDiaryImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let rawSource = arguments["source"] as? String,
      let source = DiaryImageSource(rawValue: rawSource)
    else {
      result([
        "status": "error",
        "message": "이미지 선택 방식을 확인할 수 없습니다.",
      ])
      return
    }

    if let pendingResult {
      pendingResult([
        "status": "error",
        "message": "다른 이미지 선택이 진행 중입니다.",
      ])
    }

    pendingResult = result
    pendingSource = source
    requestPermissionIfNeeded(for: source)
  }

  private func requestPermissionIfNeeded(for source: DiaryImageSource) {
    switch source {
    case .camera:
      requestCameraPermission()
    case .gallery:
      requestPhotoPermission()
    }
  }

  private func requestCameraPermission() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      presentPicker(for: .camera)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          if granted {
            self.presentPicker(for: .camera)
          } else {
            self.completePermissionDenied(for: .camera)
          }
        }
      }
    default:
      completePermissionDenied(for: .camera)
    }
  }

  private func requestPhotoPermission() {
    if #available(iOS 14, *) {
      switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
      case .authorized, .limited:
        presentPicker(for: .gallery)
      case .notDetermined:
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
          DispatchQueue.main.async {
            if status == .authorized || status == .limited {
              self.presentPicker(for: .gallery)
            } else {
              self.completePermissionDenied(for: .gallery)
            }
          }
        }
      default:
        completePermissionDenied(for: .gallery)
      }
      return
    }

    switch PHPhotoLibrary.authorizationStatus() {
    case .authorized:
      presentPicker(for: .gallery)
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
          if status == .authorized {
            self.presentPicker(for: .gallery)
          } else {
            self.completePermissionDenied(for: .gallery)
          }
        }
      }
    default:
      completePermissionDenied(for: .gallery)
    }
  }

  private func presentPicker(for source: DiaryImageSource) {
    let pickerSource: UIImagePickerController.SourceType =
      source == .camera ? .camera : .photoLibrary
    guard UIImagePickerController.isSourceTypeAvailable(pickerSource) else {
      complete([
        "status": "unsupported",
        "source": source.rawValue,
        "message": "\(source.label)을 사용할 수 없습니다.",
      ])
      return
    }

    guard let presenter = topViewController() else {
      complete([
        "status": "error",
        "source": source.rawValue,
        "message": "이미지 선택 화면을 열지 못했습니다.",
      ])
      return
    }

    let picker = UIImagePickerController()
    picker.sourceType = pickerSource
    picker.mediaTypes = ["public.image"]
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) {
      self.complete([
        "status": "cancelled",
        "source": self.pendingSource?.rawValue ?? "",
      ])
    }
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    let source = pendingSource ?? .gallery
    guard let image = info[.originalImage] as? UIImage else {
      picker.dismiss(animated: true) {
        self.complete([
          "status": "error",
          "source": source.rawValue,
          "message": "선택한 이미지를 읽지 못했습니다.",
        ])
      }
      return
    }

    let resized = image.resizedForDiaryUpload(maxEdge: 1600)
    guard let data = resized.jpegData(compressionQuality: 0.88) else {
      picker.dismiss(animated: true) {
        self.complete([
          "status": "error",
          "source": source.rawValue,
          "message": "이미지를 업로드 형식으로 정리하지 못했습니다.",
        ])
      }
      return
    }

    let filename = (info[.imageURL] as? URL)?.lastPathComponent
      ?? "diary-\(source.rawValue)-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
    picker.dismiss(animated: true) {
      self.complete([
        "status": "picked",
        "source": source.rawValue,
        "filename": filename,
        "contentType": "image/jpeg",
        "bytes": FlutterStandardTypedData(bytes: data),
      ])
    }
  }

  private func completePermissionDenied(for source: DiaryImageSource) {
    complete([
      "status": "permissionDenied",
      "source": source.rawValue,
      "message": "\(source.label) 권한이 허용되지 않았습니다.",
      "canOpenSettings": true,
    ])
  }

  private func complete(_ payload: [String: Any]) {
    guard let result = pendingResult else {
      return
    }
    pendingResult = nil
    pendingSource = nil
    result(payload)
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

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    let root = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    var top = root
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

private enum DiaryImageSource: String {
  case camera
  case gallery

  var label: String {
    switch self {
    case .camera:
      return "카메라"
    case .gallery:
      return "사진"
    }
  }
}

private extension UIImage {
  func resizedForDiaryUpload(maxEdge: CGFloat) -> UIImage {
    let longestEdge = max(size.width, size.height)
    guard longestEdge > maxEdge else {
      return self
    }

    let scale = maxEdge / longestEdge
    let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
      self.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }
}
