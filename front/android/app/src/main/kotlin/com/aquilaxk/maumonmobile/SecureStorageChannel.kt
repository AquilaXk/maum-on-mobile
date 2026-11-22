package com.aquilaxk.maumonmobile

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class SecureStorageChannel(
    context: Context,
    binaryMessenger: BinaryMessenger,
) {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )
    private val channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
    private val lock = Any()

    init {
        channel.setMethodCallHandler(::handleCall)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> handleRead(call, result)
            "write" -> handleWrite(call, result)
            "delete" -> handleDelete(call, result)
            "readAll" -> handleReadAll(result)
            else -> result.notImplemented()
        }
    }

    private fun handleRead(call: MethodCall, result: MethodChannel.Result) {
        val key = validatedKey(call, result) ?: return
        synchronized(lock) {
            val encoded = preferences.getString(key, null)
            if (encoded == null) {
                result.success(null)
                return
            }
            val decrypted = decryptEntryOrCleanup(key, encoded)
            result.success(decrypted)
        }
    }

    private fun handleWrite(call: MethodCall, result: MethodChannel.Result) {
        val key = validatedKey(call, result) ?: return
        val value = call.argument<String>("value")
        if (value == null || value.length > MAX_VALUE_LENGTH) {
            result.error(
                "SECURE_STORAGE_INVALID_ARGUMENT",
                "Secure storage value exceeds limit or is missing.",
                null,
            )
            return
        }

        synchronized(lock) {
            try {
                val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
                cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
                val iv = cipher.iv
                val ciphertext = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
                if (iv == null || iv.isEmpty() || iv.size > 255) {
                    result.error(
                        "SECURE_STORAGE_WRITE_FAILED",
                        "Invalid encryption parameters.",
                        null,
                    )
                    return
                }
                val payload = ByteArray(1 + iv.size + ciphertext.size)
                payload[0] = iv.size.toByte()
                System.arraycopy(iv, 0, payload, 1, iv.size)
                System.arraycopy(ciphertext, 0, payload, 1 + iv.size, ciphertext.size)
                val encoded = Base64.encodeToString(payload, Base64.NO_WRAP)
                val committed = preferences.edit().putString(key, encoded).commit()
                if (!committed) {
                    result.error(
                        "SECURE_STORAGE_WRITE_FAILED",
                        "Failed to persist encrypted value.",
                        null,
                    )
                    return
                }
                result.success(null)
            } catch (_: GeneralSecurityException) {
                result.error(
                    "SECURE_STORAGE_WRITE_FAILED",
                    "Failed to encrypt value.",
                    null,
                )
            } catch (_: IllegalStateException) {
                result.error(
                    "SECURE_STORAGE_WRITE_FAILED",
                    "Failed to access secure key.",
                    null,
                )
            }
        }
    }

    private fun handleDelete(call: MethodCall, result: MethodChannel.Result) {
        val key = validatedKey(call, result) ?: return
        synchronized(lock) {
            val committed = preferences.edit().remove(key).commit()
            if (!committed) {
                result.error(
                    "SECURE_STORAGE_DELETE_FAILED",
                    "Failed to delete stored value.",
                    null,
                )
                return
            }
            result.success(null)
        }
    }

    private fun handleReadAll(result: MethodChannel.Result) {
        synchronized(lock) {
            val entries = preferences.all
            if (entries.isEmpty()) {
                result.success(emptyMap<String, String>())
                return
            }

            val decryptedMap = LinkedHashMap<String, String>()
            val corruptedKeys = ArrayList<String>()
            for ((key, rawValue) in entries) {
                val encoded = rawValue as? String
                if (encoded == null) {
                    corruptedKeys.add(key)
                    continue
                }
                val decrypted = decryptEntry(encoded)
                if (decrypted != null) {
                    decryptedMap[key] = decrypted
                } else {
                    corruptedKeys.add(key)
                }
            }

            if (corruptedKeys.isNotEmpty()) {
                val editor = preferences.edit()
                for (corruptedKey in corruptedKeys) {
                    editor.remove(corruptedKey)
                }
                editor.commit()
            }

            result.success(decryptedMap)
        }
    }

    private fun validatedKey(
        call: MethodCall,
        result: MethodChannel.Result,
    ): String? {
        val key = call.argument<String>("key")
        if (key.isNullOrEmpty() || key.length > MAX_KEY_LENGTH) {
            result.error(
                "SECURE_STORAGE_INVALID_ARGUMENT",
                "Secure storage key must be 1..$MAX_KEY_LENGTH characters.",
                null,
            )
            return null
        }
        return key
    }

    private fun decryptEntryOrCleanup(key: String, encoded: String): String? {
        val decrypted = decryptEntry(encoded)
        if (decrypted == null) {
            preferences.edit().remove(key).commit()
        }
        return decrypted
    }

    private fun decryptEntry(encoded: String): String? {
        return try {
            val payload = Base64.decode(encoded, Base64.DEFAULT)
            if (payload.size < 1 + MIN_GCM_IV_BYTES + GCM_TAG_BYTES) {
                return null
            }
            val ivLength = payload[0].toInt() and 0xFF
            if (ivLength < MIN_GCM_IV_BYTES || payload.size < 1 + ivLength + GCM_TAG_BYTES) {
                return null
            }
            val iv = payload.copyOfRange(1, 1 + ivLength)
            val ciphertext = payload.copyOfRange(1 + ivLength, payload.size)
            val secretKey = findSecretKey() ?: return null
            val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(GCM_TAG_BITS, iv))
            val plaintext = cipher.doFinal(ciphertext)
            String(plaintext, Charsets.UTF_8)
        } catch (_: GeneralSecurityException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        } catch (_: IllegalStateException) {
            null
        }
    }

    private fun findSecretKey(): SecretKey? {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        return keyStore.getKey(KEY_ALIAS, null) as? SecretKey
    }

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = runCatching { keyStore.getKey(KEY_ALIAS, null) as? SecretKey }.getOrNull()
        if (existing != null) {
            return existing
        }

        if (keyStore.containsAlias(KEY_ALIAS)) {
            runCatching { keyStore.deleteEntry(KEY_ALIAS) }
        }

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE,
        )
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(AES_KEY_BITS)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    private companion object {
        private const val CHANNEL_NAME = "maum_on_mobile/secure_storage"
        private const val PREFERENCES_NAME = "maum_on_mobile.secure_kv"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "maum_on_mobile_secure_kv_v1"
        private const val CIPHER_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val AES_KEY_BITS = 256
        private const val MIN_GCM_IV_BYTES = 12
        private const val GCM_TAG_BITS = 128
        private const val GCM_TAG_BYTES = 16
        private const val MAX_KEY_LENGTH = 256
        private const val MAX_VALUE_LENGTH = 262_144
    }
}
