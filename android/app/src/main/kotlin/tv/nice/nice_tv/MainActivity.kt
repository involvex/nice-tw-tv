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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> {
                        val supported =
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                packageManager.hasSystemFeature(
                                    PackageManager.FEATURE_PICTURE_IN_PICTURE,
                                )
                        result.success(supported)
                    }
                    "enterPip" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val width = call.argument<Int>("width") ?: 16
                        val height = call.argument<Int>("height") ?: 9
                        val params =
                            PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(width, height))
                                .build()
                        result.success(enterPictureInPictureMode(params))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
