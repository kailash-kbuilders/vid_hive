"""Prepares the generated android/ folder for VidHive.

Adds the video permissions, turns on picture-in-picture for the player
activity, and gives MainActivity a small PiP method channel. Safe to run more
than once.
"""
import pathlib
import re

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")

PERMISSIONS = [
    '<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />',
    '<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />',
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" '
    'android:maxSdkVersion="32" />',
    '<uses-permission android:name="android.permission.WAKE_LOCK" />',
]

MAIN_ACTIVITY = '''package {package}

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vidhive/pip")
            .setMethodCallHandler {{ call, result ->
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

    # Picture-in-picture needs to be declared on the activity.
    if "supportsPictureInPicture" not in text:
        text = text.replace(
            'android:name=".MainActivity"',
            'android:name=".MainActivity"\n            android:supportsPictureInPicture="true"',
            1,
        )

    # Rotation must not recreate the activity while a video is playing.
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
    print("MainActivity rewritten with PiP channel")


def main() -> None:
    patch_manifest()
    patch_main_activity()


if __name__ == "__main__":
    main()
