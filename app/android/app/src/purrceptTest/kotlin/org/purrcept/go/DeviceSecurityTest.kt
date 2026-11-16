package org.purrcept.go

import java.io.IOException
import java.net.InetAddress
import java.security.MessageDigest
import okhttp3.Request
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.tls.HandshakeCertificates
import okhttp3.tls.HeldCertificate
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

/** Exercise the production pinned OkHttp client against a real local TLS server without an Android device. */
class DeviceSecurityTest {
    @Test fun exactSelfSignedCertificateAcceptsARealPairingPostAndWrongPinFails() {
        val certificate = HeldCertificate.Builder().commonName("Purrcept offline TLS fixture")
            .addSubjectAlternativeName("127.0.0.1").build()
        val identity = HandshakeCertificates.Builder().heldCertificate(certificate).build()
        val hash = MessageDigest.getInstance("SHA-256").digest(certificate.certificate.encoded)
            .joinToString("") { "%02x".format(it) }
        val server = MockWebServer()
        server.useHttps(identity.sslSocketFactory(), false)
        server.start(InetAddress.getByName("127.0.0.1"), 0)
        try {
            server.enqueue(MockResponse().setBody("{\"device_id\":\"fixture\",\"token\":\"synthetic\"}"))
            val client = DeviceSecurity.pinnedClient(hash, "127.0.0.1")
            try {
                val payload = JSONObject().put("invitation", "synthetic-offline-invitation").put("name", "Offline test")
                val request = Request.Builder().url(server.url("/phone/v1/pair").newBuilder().host("127.0.0.1").build())
                    .post(payload.toString().toRequestBody("application/json".toMediaType())).build()
                client.newCall(request).execute().use { response ->
                    assertEquals(200, response.code)
                    assertEquals("fixture", JSONObject(response.body!!.string()).getString("device_id"))
                }
                val received = server.takeRequest()
                assertEquals("POST", received.method)
                assertEquals("/phone/v1/pair", received.path)
                assertEquals("synthetic-offline-invitation", JSONObject(received.body.readUtf8()).getString("invitation"))
            } finally {
                client.connectionPool.evictAll()
                client.dispatcher.executorService.shutdown()
            }
            val wrong = DeviceSecurity.pinnedClient("0".repeat(64), "127.0.0.1")
            try {
                val failure = assertThrows(IOException::class.java) {
                    wrong.newCall(Request.Builder().url(server.url("/phone/v1/pair").newBuilder().host("127.0.0.1").build()).build()).execute().close()
                }
                assertEquals("certificate_mismatch", NetworkFailure.code(failure, pairing = true))
            } finally {
                wrong.connectionPool.evictAll()
                wrong.dispatcher.executorService.shutdown()
            }
        } finally {
            server.shutdown()
        }
    }
}
