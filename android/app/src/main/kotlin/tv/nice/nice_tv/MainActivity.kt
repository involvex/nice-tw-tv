package tv.nice.nice_tv

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "tv.nice.nice_tv/pip"
    private var autoPipEnabled = false
    private var pipAspectWidth = 16
    private var pipAspectHeight = 9

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> {
                        result.success(isPipSupported())
                    }
                    "enterPip" -> {
                        val width = call.argument<Int>("width") ?: 16
                        val height = call.argument<Int>("height") ?: 9
                        result.success(enterPip(width, height))
                    }
                    "setAutoEnter" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val width = call.argument<Int>("width") ?: 16
                        val height = call.argument<Int>("height") ?: 9
                        autoPipEnabled = enabled
                        pipAspectWidth = width
                        pipAspectHeight = height
                        applyPipParams()
                        result.success(null)
                    }
                    "isInPipMode" -> {
                        val inPip =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                isInPictureInPictureMode
                            } else {
                                false
                            }
                        result.success(inPip)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (!autoPipEnabled) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (isInPictureInPictureMode) return
        // Pre-API 31: auto-enter is unavailable; enter manually on Home.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPip(pipAspectWidth, pipAspectHeight)
        }
    }

    private fun isPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPip(width: Int, height: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!isPipSupported()) return false
        val params = buildPipParams(width, height, autoEnter = false)
        return enterPictureInPictureMode(params)
    }

    private fun applyPipParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!isPipSupported()) return
        setPictureInPictureParams(
            buildPipParams(
                pipAspectWidth,
                pipAspectHeight,
                autoEnter = autoPipEnabled,
            ),
        )
    }

    private fun buildPipParams(
        width: Int,
        height: Int,
        autoEnter: Boolean,
    ): PictureInPictureParams {
        val builder =
            PictureInPictureParams.Builder()
                .setAspectRatio(Rational(width, height))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnter)
        }
        return builder.build()
    }
}
