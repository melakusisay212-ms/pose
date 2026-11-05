#!/usr/bin/env python3
"""Patch the generated Android project for Pose Runner.

Adds the camera permission to AndroidManifest.xml and raises minSdk to 24.
Safe to run twice. Exits with an error if it cannot find what it must patch,
so a Flutter template change fails the build loudly instead of silently.

Usage: python3 tools/patch_android.py [project_root]
"""
import re
import sys
from pathlib import Path

MIN_SDK = 24
MANIFEST_LINES = [
    '<uses-permission android:name="android.permission.CAMERA" />',
    '<uses-feature android:name="android.hardware.camera.front" '
    'android:required="false" />',
]
MIN_SDK_PATTERN = re.compile(r"(minSdk(?:Version)?\s*=?\s*)(flutter\.minSdkVersion|\d+)")


def patch_manifest(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    missing = [line for line in MANIFEST_LINES if line.split('"')[1] not in text]
    if not missing:
        print(f"manifest: already patched ({path})")
        return
    if "<application" not in text:
        raise SystemExit(f"manifest: no <application> tag found in {path}")
    block = "".join(f"    {line}\n" for line in missing)
    patched = re.sub(
        r"[ \t]*<application", lambda m: block + m.group(0), text, count=1
    )
    path.write_text(patched, encoding="utf-8")
    print(f"manifest: added {len(missing)} line(s) ({path})")


def patch_gradle(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    found = 0
    changed = 0

    def repl(match: re.Match) -> str:
        nonlocal found, changed
        found += 1
        current = match.group(2)
        if current.isdigit() and int(current) >= MIN_SDK:
            return match.group(0)
        changed += 1
        return f"{match.group(1)}{MIN_SDK}"

    patched = MIN_SDK_PATTERN.sub(repl, text)
    if found == 0:
        raise SystemExit(f"gradle: no minSdk setting found in {path}")
    if changed:
        path.write_text(patched, encoding="utf-8")
    print(f"gradle: minSdk {'set to ' + str(MIN_SDK) if changed else 'already ok'} ({path})")


RELEASE_BLOCK = re.compile(r"(\brelease\s*\{)")


def patch_release_minify(path: Path) -> None:
    """Turn off R8 code shrinking/obfuscation for the release build.

    Crash logs showed the release APK dying at launch because R8 broke
    ML Kit's component registrars and WorkManager's Room database
    (androidx.work.impl.WorkDatabase). Disabling minify avoids that.
    """
    text = path.read_text(encoding="utf-8")
    if "PoseRunner: minify off" in text:
        print(f"gradle: release minify already off ({path})")
        return
    is_kts = path.suffix == ".kts"
    if is_kts:
        lines = ("isMinifyEnabled = false", "isShrinkResources = false")
    else:
        lines = ("minifyEnabled false", "shrinkResources false")
    match = None
    for m in RELEASE_BLOCK.finditer(text):
        if "buildTypes" in text[: m.start()]:
            match = m
            break
    if match is None:
        raise SystemExit(f"gradle: no release buildType found in {path}")
    block = "\n            // PoseRunner: minify off\n" + "".join(
        f"            {line}\n" for line in lines
    )
    patched = text[: match.end()] + block + text[match.end():]
    path.write_text(patched, encoding="utf-8")
    print(f"gradle: release minify disabled ({path})")


def main() -> None:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    manifest = root / "android/app/src/main/AndroidManifest.xml"
    if not manifest.is_file():
        raise SystemExit(f"manifest not found: {manifest}")
    gradle_files = [
        p
        for p in (root / "android/app/build.gradle.kts", root / "android/app/build.gradle")
        if p.is_file()
    ]
    if not gradle_files:
        raise SystemExit("no android/app/build.gradle(.kts) found")
    patch_manifest(manifest)
    for gradle in gradle_files:
        patch_gradle(gradle)
        patch_release_minify(gradle)


if __name__ == "__main__":
    main()
