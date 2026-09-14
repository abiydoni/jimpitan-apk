package jimpitan.appsbee.my.id

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "jimpitan/signature_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSignatureFingerprints") {
                try {
                    val fingerprints = getCertificateFingerprints()
                    result.success(fingerprints)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getCertificateFingerprints(): Map<String, String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            val signingInfo = packageInfo.signingInfo
            if (signingInfo != null) {
                if (signingInfo.hasMultipleSigners()) {
                    signingInfo.apkContentsSigners
                } else {
                    signingInfo.signingCertificateHistory
                }
            } else {
                null
            }
        } else {
            @Suppress("DEPRECATION")
            val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            @Suppress("DEPRECATION")
            packageInfo.signatures
        }

        if (signatures == null || signatures.isEmpty()) {
            return mapOf("sha1" to "Not found", "sha256" to "Not found", "packageName" to packageName)
        }

        val certBytes = signatures[0].toByteArray()
        val sha1 = getFingerprint(certBytes, "SHA-1")
        val sha256 = getFingerprint(certBytes, "SHA-256")

        return mapOf(
            "sha1" to sha1,
            "sha256" to sha256,
            "packageName" to packageName
        )
    }

    private fun getFingerprint(certBytes: ByteArray, algorithm: String): String {
        val md = MessageDigest.getInstance(algorithm)
        val digest = md.digest(certBytes)
        val hexString = StringBuilder()
        for (i in digest.indices) {
            val hex = Integer.toHexString(0xFF and digest[i].toInt()).uppercase()
            if (hex.length == 1) {
                hexString.append("0")
            }
            hexString.append(hex)
            if (i < digest.size - 1) {
                hexString.append(":")
            }
        }
        return hexString.toString()
    }
}
