#!/usr/bin/env python3
"""Build the standalone Java widget lab with Android SDK tools, without Gradle."""
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def build():
    sdk = Path(os.environ.get("ANDROID_SDK_ROOT", Path.home() / "Library/Android/sdk"))
    java = Path(os.environ.get("JAVA_HOME", "/Applications/Android Studio.app/Contents/jbr/Contents/Home"))
    tools = sdk / "build-tools/36.0.0"
    android_jar = sdk / "platforms/android-36/android.jar"
    if not (ROOT / "android/assets/clip_0.mp4").exists():
        raise SystemExit("Run python3 prepare_media.py first")
    output = ROOT / ".build/android"
    output.mkdir(parents=True, exist_ok=True)
    for directory in ["generated", "classes", "dex"]:
        path = output / directory
        if path.exists():
            shutil.rmtree(path)
        path.mkdir()
    run(tools / "aapt2", "compile", "--dir", ROOT / "android/res", "-o", output / "resources.zip")
    run(tools / "aapt2", "link", "-o", output / "unsigned.apk", "--manifest", ROOT / "android/AndroidManifest.xml",
        "-I", android_jar, "--java", output / "generated", "-A", ROOT / "android/assets", "-0", "mp4", output / "resources.zip")
    sources = sorted((ROOT / "android/src").rglob("*.java")) + sorted((output / "generated").rglob("*.java"))
    sources.append(ROOT / "tests/AndroidRenderingTests.java")
    run(java / "bin/javac", "--release", "17", "-classpath", android_jar, "-d", output / "classes", *sources)
    run(java / "bin/jar", "--create", "--file", output / "classes.jar", "-C", output / "classes", ".")
    env = dict(os.environ, JAVA_HOME=str(java))
    subprocess.run([str(tools / "d8"), "--lib", str(android_jar), "--min-api", "28",
                    "--output", str(output / "dex"), str(output / "classes.jar")], env=env, check=True)
    with zipfile.ZipFile(output / "unsigned.apk", "a", compression=zipfile.ZIP_DEFLATED) as apk:
        apk.write(output / "dex/classes.dex", "classes.dex")
    run(tools / "zipalign", "-f", "4", output / "unsigned.apk", output / "aligned.apk")
    keystore = output / "lab.keystore"
    if not keystore.exists():
        run(java / "bin/keytool", "-genkeypair", "-keystore", keystore, "-storepass", "android", "-keypass", "android",
            "-alias", "androiddebugkey", "-dname", "CN=Widget Lab Debug", "-keyalg", "RSA", "-validity", "365")
    subprocess.run([str(tools / "apksigner"), "sign", "--ks", str(keystore), "--ks-pass", "pass:android",
                    "--out", str(output / "widget-lab.apk"), str(output / "aligned.apk")], env=env, check=True)
    subprocess.run([str(tools / "apksigner"), "verify", str(output / "widget-lab.apk")], env=env, check=True)
    print(output / "widget-lab.apk")


if __name__ == "__main__":
    build()
