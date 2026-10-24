#!/usr/bin/env python3
"""Run the native state tests without either mobile runtime."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent


def test():
    output = ROOT / ".build/tests"
    output.mkdir(parents=True, exist_ok=True)
    java = Path(os.environ.get("JAVA_HOME", "/Applications/Android Studio.app/Contents/jbr/Contents/Home")) / "bin"
    subprocess.run(["swiftc", str(ROOT / "ios/Shared/LabState.swift"), str(ROOT / "ios/Shared/LabRoutes.swift"), str(ROOT / "tests/StateTests.swift"),
                    "-o", str(output / "state-tests")], check=True)
    subprocess.run([str(output / "state-tests")], check=True)
    subprocess.run([str(java / "javac"), "-d", str(output), str(ROOT / "android/src/video/divine/widgetlab/LabState.java"),
                    str(ROOT / "tests/LabStateTest.java")], check=True)
    subprocess.run([str(java / "java"), "-cp", str(output), "video.divine.widgetlab.LabStateTest"], check=True)


if __name__ == "__main__":
    test()
