package com.aquilaxk.maumonmobile

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class DiaryImagePickerChannel(
    private val activity: FlutterActivity,
    binaryMessenger: BinaryMessenger,
) {
    private val channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
    private var pendingResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(::handleCall)
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        val source = when (requestCode) {
            CAMERA_PERMISSION_REQUEST -> DiaryImageSource.CAMERA
            GALLERY_PERMISSION_REQUEST -> DiaryImageSource.GALLERY
            else -> return false
        }

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            complete(
                mapOf(
                    "status" to "permissionDenied",
                    "source" to source.platformValue,
                    "message" to "${source.label} 권한이 허용되지 않았습니다.",
                    "canOpenSettings" to true,
                ),
            )
            return true
        }

        launchPicker(source)
        return true
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val source = when (requestCode) {
            CAMERA_PICK_REQUEST -> DiaryImageSource.CAMERA
            GALLERY_PICK_REQUEST -> DiaryImageSource.GALLERY
            else -> return false
        }

        if (resultCode != Activity.RESULT_OK) {
            complete(mapOf("status" to "cancelled", "source" to source.platformValue))
            return true
        }

        when (source) {
            DiaryImageSource.CAMERA -> completeCameraResult(data)
            DiaryImageSource.GALLERY -> completeGalleryResult(data)
        }
        return true
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDiaryImage" -> pickDiaryImage(call, result)
            "openSettings" -> result.success(openSettings())
            else -> result.notImplemented()
        }
    }

    private fun pickDiaryImage(call: MethodCall, result: MethodChannel.Result) {
        val source = DiaryImageSource.from(call.argument<String>("source"))
        if (source == null) {
            result.success(
                mapOf(
                    "status" to "error",
                    "message" to "이미지 선택 방식을 확인할 수 없습니다.",
                ),
            )
            return
        }

        pendingResult?.success(
            mapOf(
                "status" to "error",
                "message" to "다른 이미지 선택이 진행 중입니다.",
            ),
        )
        pendingResult = result

        val permission = permissionFor(source)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            activity.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(
                arrayOf(permission),
                if (source == DiaryImageSource.CAMERA) {
                    CAMERA_PERMISSION_REQUEST
                } else {
                    GALLERY_PERMISSION_REQUEST
                },
            )
            return
        }

        launchPicker(source)
    }

    private fun launchPicker(source: DiaryImageSource) {
        val intent = when (source) {
            DiaryImageSource.CAMERA -> Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            DiaryImageSource.GALLERY -> galleryIntent()
        }
        if (intent.resolveActivity(activity.packageManager) == null) {
            complete(
                mapOf(
                    "status" to "unsupported",
                    "source" to source.platformValue,
                    "message" to "${source.label}을 사용할 수 없습니다.",
                ),
            )
            return
        }

        activity.startActivityForResult(
            intent,
            if (source == DiaryImageSource.CAMERA) {
                CAMERA_PICK_REQUEST
            } else {
                GALLERY_PICK_REQUEST
            },
        )
    }

    private fun galleryIntent(): Intent {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                type = "image/*"
            }
        }

        return Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
    }

    private fun completeCameraResult(data: Intent?) {
        val bitmap = data?.extras?.get("data") as? Bitmap
        if (bitmap == null) {
            complete(
                mapOf(
                    "status" to "error",
                    "source" to DiaryImageSource.CAMERA.platformValue,
                    "message" to "촬영한 이미지를 읽지 못했습니다.",
                ),
            )
            return
        }

        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 88, output)
        complete(
            pickedPayload(
                source = DiaryImageSource.CAMERA,
                filename = "diary-camera-${System.currentTimeMillis()}.jpg",
                contentType = "image/jpeg",
                bytes = output.toByteArray(),
            ),
        )
    }

    private fun completeGalleryResult(data: Intent?) {
        val uri = data?.data
        if (uri == null) {
            complete(
                mapOf(
                    "status" to "error",
                    "source" to DiaryImageSource.GALLERY.platformValue,
                    "message" to "선택한 이미지를 읽지 못했습니다.",
                ),
            )
            return
        }

        val bytes = activity.contentResolver.openInputStream(uri)?.use { stream ->
            stream.readBytes()
        }
        if (bytes == null || bytes.isEmpty()) {
            complete(
                mapOf(
                    "status" to "error",
                    "source" to DiaryImageSource.GALLERY.platformValue,
                    "message" to "선택한 이미지가 비어 있습니다.",
                ),
            )
            return
        }

        complete(
            pickedPayload(
                source = DiaryImageSource.GALLERY,
                filename = displayName(uri) ?: "diary-gallery-${System.currentTimeMillis()}.jpg",
                contentType = activity.contentResolver.getType(uri) ?: "image/jpeg",
                bytes = bytes,
            ),
        )
    }

    private fun pickedPayload(
        source: DiaryImageSource,
        filename: String,
        contentType: String,
        bytes: ByteArray,
    ): Map<String, Any?> {
        return mapOf(
            "status" to "picked",
            "source" to source.platformValue,
            "filename" to filename,
            "contentType" to contentType,
            "bytes" to bytes,
        )
    }

    private fun displayName(uri: Uri): String? {
        return activity.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) {
                null
            } else {
                cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
            }
        }
    }

    private fun permissionFor(source: DiaryImageSource): String {
        return when (source) {
            DiaryImageSource.CAMERA -> Manifest.permission.CAMERA
            DiaryImageSource.GALLERY -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                Manifest.permission.READ_MEDIA_IMAGES
            } else {
                Manifest.permission.READ_EXTERNAL_STORAGE
            }
        }
    }

    private fun openSettings(): Boolean {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${activity.packageName}")
        }
        return runCatching {
            activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.isSuccess
    }

    private fun complete(payload: Map<String, Any?>) {
        val result = pendingResult ?: return
        pendingResult = null
        result.success(payload)
    }

    private enum class DiaryImageSource(
        val platformValue: String,
        val label: String,
    ) {
        CAMERA("camera", "카메라"),
        GALLERY("gallery", "사진");

        companion object {
            fun from(value: String?): DiaryImageSource? {
                return when (value) {
                    "camera" -> CAMERA
                    "gallery" -> GALLERY
                    else -> null
                }
            }
        }
    }

    private companion object {
        private const val CHANNEL_NAME = "maum_on_mobile/diary_images"
        private const val CAMERA_PERMISSION_REQUEST = 9201
        private const val GALLERY_PERMISSION_REQUEST = 9202
        private const val CAMERA_PICK_REQUEST = 9203
        private const val GALLERY_PICK_REQUEST = 9204
    }
}
