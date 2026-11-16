package org.purrcept.go

import java.io.IOException
import java.net.ConnectException
import java.net.SocketException
import java.net.SocketTimeoutException
import java.security.cert.CertificateException
import java.security.cert.CertificateNotYetValidException
import javax.net.ssl.SSLHandshakeException
import org.junit.Assert.*
import org.junit.Test

/** Network guidance follows actual transport causes, never pairing state or exception text shown to users. */
class NetworkFailureTest {
    @Test fun certificateAndTlsFailuresAreDistinctFromConnectivity() {
        val date = SSLHandshakeException("wrapped").apply { initCause(CertificateNotYetValidException()) }
        val pin = SSLHandshakeException("wrapped").apply { initCause(CertificateException("certificate_changed")) }
        assertEquals("certificate_date_invalid", NetworkFailure.code(date, pairing = true))
        assertEquals("certificate_mismatch", NetworkFailure.code(pin, pairing = true))
        assertEquals("tls_connection_failed", NetworkFailure.code(SSLHandshakeException("other")))
    }

    @Test fun firstPairingNeverClaimsAnExistingChatConnectionWasInterrupted() {
        assertEquals("pairing_network_error", NetworkFailure.code(IOException("private details"), pairing = true))
        assertEquals("network_error", NetworkFailure.code(IOException("private details")))
        assertEquals("network_timeout", NetworkFailure.code(SocketTimeoutException()))
        assertEquals("computer_unreachable", NetworkFailure.code(ConnectException()))
        assertEquals("network_permission_denied", NetworkFailure.code(SocketException("socket failed: EPERM (Operation not permitted)")))
        val secret = IOException("private-request-body").apply { initCause(SocketException("private-address")) }
        assertEquals("IOException → SocketException", NetworkFailure.diagnostics(secret))
        assertFalse(NetworkFailure.diagnostics(secret).contains("private"))
    }
}
