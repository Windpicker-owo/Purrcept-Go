package org.purrcept.go

import java.io.IOException
import java.io.InterruptedIOException
import java.net.ConnectException
import java.net.NoRouteToHostException
import java.net.UnknownHostException
import java.security.cert.CertificateExpiredException
import java.security.cert.CertificateNotYetValidException
import javax.net.ssl.SSLException

/** Stable network failures for pairing and reconnect UI; exception text and credentials never cross Flutter. */
internal object NetworkFailure {
    /** Copyable diagnosis contains class names only; platform messages may contain private request data. */
    fun diagnostics(error: IOException): String = generateSequence<Throwable>(error) { it.cause }
        .take(8).joinToString(" → ") { it.javaClass.simpleName.take(80) }

    /** Android TLS can wrap certificate failures; inspect bounded causes before classifying transport symptoms. */
    fun code(error: IOException, pairing: Boolean = false): String {
        val causes = generateSequence<Throwable>(error) { it.cause }.take(8).toList()
        val platformDeniedAccess = causes.any { cause ->
            val detail = cause.message.orEmpty()
            detail.contains("EACCES", ignoreCase = true) ||
                detail.contains("EPERM", ignoreCase = true) ||
                detail.contains("Permission denied", ignoreCase = true)
        }
        return when {
            causes.any { it is CertificateExpiredException || it is CertificateNotYetValidException } -> "certificate_date_invalid"
            causes.any { it.message == "certificate_changed" } -> "certificate_mismatch"
            causes.any { it is SSLException } -> "tls_connection_failed"
            causes.any { it is UnknownHostException } -> "computer_not_found"
            platformDeniedAccess -> "network_permission_denied"
            causes.any { it is InterruptedIOException } -> "network_timeout"
            causes.any { it is ConnectException || it is NoRouteToHostException } -> "computer_unreachable"
            pairing -> "pairing_network_error"
            else -> "network_error"
        }
    }
}
