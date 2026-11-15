package org.purrcept.go

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import okhttp3.OkHttpClient
import org.json.JSONObject
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.SSLContext
import javax.net.ssl.X509TrustManager

/** Device credentials are encrypted with an Android Keystore key and never enter Flutter snapshots. */
class DeviceVault(context: Context) {
    private val preferences = context.getSharedPreferences("purrcept-vault", Context.MODE_PRIVATE)
    private val alias = "purrcept-device-v1"

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }

    fun save(value: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val encrypted = cipher.doFinal(value.toString().toByteArray(Charsets.UTF_8))
        check(preferences.edit().putString("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .putString("data", Base64.encodeToString(encrypted, Base64.NO_WRAP)).commit())
    }

    fun load(): JSONObject? {
        val data = preferences.getString("data", null) ?: return null
        val iv = preferences.getString("iv", null) ?: throw IllegalStateException("credential_corrupt")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
        }
        return JSONObject(String(cipher.doFinal(Base64.decode(data, Base64.NO_WRAP)), Charsets.UTF_8))
    }

    fun clear() { check(preferences.edit().clear().commit()) }
}

/** A pairing invitation pins the entire certificate. No public or self-signed certificate bypass is allowed. */
object DeviceSecurity {
    fun pinnedClient(expectedHash: String, expectedHost: String): OkHttpClient {
        require(expectedHash.matches(Regex("[a-fA-F0-9]{64}"))) { "invalid_certificate_pin" }
        val manager = object : X509TrustManager {
            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {
                throw CertificateException("client_certificate_not_supported")
            }
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
                if (chain.isEmpty()) throw CertificateException("empty_certificate")
                chain[0].checkValidity()
                val actual = MessageDigest.getInstance("SHA-256").digest(chain[0].encoded)
                    .joinToString("") { "%02x".format(it) }
                if (!MessageDigest.isEqual(actual.toByteArray(), expectedHash.lowercase().toByteArray())) {
                    throw CertificateException("certificate_changed")
                }
            }
        }
        val tls = SSLContext.getInstance("TLS").apply { init(null, arrayOf(manager), SecureRandom()) }
        return OkHttpClient.Builder().sslSocketFactory(tls.socketFactory, manager)
            // Trust is established by the out-of-band invitation's exact certificate and host together.
            .hostnameVerifier { host, _ -> host == expectedHost }
            .connectTimeout(10, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS)
            .pingInterval(15, TimeUnit.SECONDS).followRedirects(false).followSslRedirects(false).build()
    }
}
