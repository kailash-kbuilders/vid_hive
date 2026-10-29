"""Prepares the generated android/ folder for VidHive.

- All files access, so the app scans storage itself instead of trusting the
  gallery index.
- Picture-in-picture on the player activity.
- MainActivity gains two small native helpers: PiP and a MediaMetadataRetriever
  bridge that returns thumbnails, duration and resolution for any file.

Safe to run more than once.
"""
import pathlib
import re

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")

PERMISSIONS = [
    '<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />',
    '<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />',
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" '
    'android:maxSdkVersion="32" />',
    '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
    'android:maxSdkVersion="29" />',
    '<uses-permission android:name="android.permission.WAKE_LOCK" />',
]

MAIN_ACTIVITY = '''package {package}

import android.app.PictureInPictureParams
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {{
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "vidhive/pip").setMethodCallHandler {{ call, result ->
            if (call.method != "enter") {{
                result.notImplemented()
                return@setMethodCallHandler
            }}
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {{
                result.error("pip_unsupported", "Android 8.0+ required", null)
                return@setMethodCallHandler
            }}
            try {{
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .build()
                result.success(enterPictureInPictureMode(params))
            }} catch (error: Exception) {{
                result.error("pip_failed", error.message, null)
            }}
        }}

        MethodChannel(messenger, "vidhive/media").setMethodCallHandler {{ call, result ->
            val path = call.argument<String>("path")
            if (path == null) {{
                result.error("bad_args", "path missing", null)
                return@setMethodCallHandler
            }}
            when (call.method) {{
                "meta" -> worker.execute {{
                    val data = HashMap<String, Any>()
                    val retriever = MediaMetadataRetriever()
                    try {{
                        retriever.setDataSource(path)
                        data["duration"] = retriever
                            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                            ?.toLongOrNull() ?: 0L
                        data["width"] = retriever
                            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                            ?.toIntOrNull() ?: 0
                        data["height"] = retriever
                            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                            ?.toIntOrNull() ?: 0
                    }} catch (error: Exception) {{
                        // Unreadable file: report zeroes, the UI copes.
                    }} finally {{
                        try {{ retriever.release() }} catch (_: Exception) {{}}
                    }}
                    runOnUiThread {{ result.success(data) }}
                }}
                "thumb" -> {{
                    val width = call.argument<Int>("width") ?: 360
                    worker.execute {{
                        val bytes = buildThumb(path, width)
                        runOnUiThread {{ result.success(bytes) }}
                    }}
                }}
                else -> result.notImplemented()
            }}
        }}
    }}

    private fun buildThumb(path: String, targetWidth: Int): ByteArray? {{
        val retriever = MediaMetadataRetriever()
        return try {{
            retriever.setDataSource(path)
            val frame = retriever.getFrameAtTime(
                2_000_000,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            ) ?: return null
            val ratio = targetWidth.toFloat() / frame.width
            val height = (frame.height * ratio).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(frame, targetWidth, height, true)
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 72, stream)
            stream.toByteArray()
        }} catch (error: Exception) {{
            null
        }} finally {{
            try {{ retriever.release() }} catch (_: Exception) {{}}
        }}
    }}

    override fun onDestroy() {{
        worker.shutdownNow()
        super.onDestroy()
    }}
}}
'''


def patch_manifest() -> None:
    if not MANIFEST.exists():
        print("manifest not found")
        return
    text = MANIFEST.read_text()

    missing = [p for p in PERMISSIONS if p.split('"')[1] not in text]
    if missing:
        block = "\n".join("    " + p for p in missing) + "\n"
        text = re.sub(r"(<manifest[^>]*>)", lambda m: m.group(1) + "\n" + block, text, count=1)

    if "supportsPictureInPicture" not in text:
        text = text.replace(
            'android:name=".MainActivity"',
            'android:name=".MainActivity"\n            android:supportsPictureInPicture="true"',
            1,
        )

    def add_config_changes(match: re.Match) -> str:
        current = match.group(1)
        wanted = [
            "orientation", "screenSize", "smallestScreenSize", "screenLayout",
            "keyboard", "keyboardHidden", "uiMode", "density",
            "layoutDirection", "fontScale", "locale",
        ]
        values = [v for v in current.split("|") if v]
        for value in wanted:
            if value not in values:
                values.append(value)
        return 'android:configChanges="' + "|".join(values) + '"'

    text = re.sub(r'android:configChanges="([^"]*)"', add_config_changes, text, count=1)
    text = re.sub(r'android:label="[^"]*"', 'android:label="VidHive"', text)
    MANIFEST.write_text(text)
    print("manifest patched")


def patch_main_activity() -> None:
    root = pathlib.Path("android/app/src/main/kotlin")
    if not root.exists():
        root = pathlib.Path("android/app/src/main/java")
    candidates = list(root.rglob("MainActivity.kt"))
    if not candidates:
        print("MainActivity.kt not found, skipping")
        return
    target = candidates[0]
    package = "com.example.vid_hive"
    for line in target.read_text().splitlines():
        if line.strip().startswith("package "):
            package = line.strip().split("package ", 1)[1].rstrip(";").strip()
            break
    target.write_text(MAIN_ACTIVITY.format(package=package))
    print("MainActivity rewritten with PiP + media helpers")


def main() -> None:
    patch_manifest()
    patch_main_activity()


if __name__ == "__main__":
    main()
