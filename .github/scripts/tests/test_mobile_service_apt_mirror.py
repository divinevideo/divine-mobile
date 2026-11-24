import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / ".github/scripts/use_ubuntu_archive_mirror.py"
SOURCE_PATH = "/etc/apt/sources.list.d/ubuntu.sources"


class MobileServiceAptMirrorTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.sandbox = Path(self.temporary.name)
        self.source = self.sandbox / "ubuntu.sources"

    def test_setup_routes_ec2_downloads_before_apt_update(self):
        # Run the real workflow shell and normalizer; only privilege, package
        # installation and Flutter configuration are replaced at the boundary.
        workflow = json.loads(subprocess.check_output([
            "ruby", "-ryaml", "-rjson", "-e",
            "print JSON.generate(YAML.load_file(ARGV[0]))",
            str(ROOT / ".github/workflows/mobile_service_integration_tests.yaml"),
        ], text=True))
        setup = next(step for step in workflow["jobs"]["service-tests"]["steps"]
                     if step.get("name") == "🧰 Linux desktop toolchain")
        self.source.write_text(
            "Types: deb\n"
            "URIs: http://us-east-2.ec2.archive.ubuntu.com/ubuntu\n"
            "Suites: noble noble-updates noble-backports\n"
            "Components: main restricted universe multiverse\n"
            "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n"
        )
        bin_dir = self.sandbox / "bin"
        bin_dir.mkdir()
        sudo = bin_dir / "sudo"
        sudo.write_text("""#!/usr/bin/env python3
import os
from pathlib import Path
import sys

args = sys.argv[1:]
source = os.environ['APT_MIRROR_TEST_SOURCE_FILE']
if args[0] == 'python3':
    args = [source if arg == '/etc/apt/sources.list.d/ubuntu.sources' else arg
            for arg in args]
    os.execvp(args[0], args)
elif args == ['apt-get', 'update']:
    Path(os.environ['APT_MIRROR_TEST_UPDATE_SNAPSHOT']).write_bytes(
        Path(source).read_bytes())
elif args[:2] != ['apt-get', 'install']:
    raise SystemExit('Unexpected privileged command: ' + repr(args))
""")
        sudo.chmod(0o755)
        flutter = bin_dir / "flutter"
        flutter.write_text("#!/bin/sh\nexit 0\n")
        flutter.chmod(0o755)
        snapshot = self.sandbox / "at-update.sources"

        subprocess.run(
            ["bash", "-euo", "pipefail", "-c", setup["run"]],
            cwd=ROOT / "mobile",
            env={**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}",
                 "APT_MIRROR_TEST_SOURCE_FILE": str(self.source),
                 "APT_MIRROR_TEST_UPDATE_SNAPSHOT": str(snapshot)},
            check=True, capture_output=True, text=True,
        )

        self.assertEqual(snapshot.read_text(),
                         "Types: deb\n"
                         "URIs: https://archive.ubuntu.com/ubuntu/\n"
                         "Suites: noble noble-updates noble-backports\n"
                         "Components: main restricted universe multiverse\n"
                         "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n")

    def test_changes_only_ec2_archive_uri_tokens_and_is_idempotent(self):
        original = (
            b"Types: deb deb-src\n"
            b"URIs: http://us-east-2.ec2.archive.ubuntu.com/ubuntu "
            b"https://eu-west-1.ec2.archive.ubuntu.com/ubuntu/\n"
            b"Suites: noble noble-updates noble-backports\n"
            b"Components: main restricted universe multiverse\n"
            b"Architectures: amd64\n"
            b"Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n\n"
            b"Types: deb\n"
            b"URIs: http://security.ubuntu.com/ubuntu/\n"
            b"Suites: noble-security\n"
            b"Components: main restricted universe multiverse\n"
            b"Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n\n"
            b"Types: deb\n"
            b"URIs: https://packages.microsoft.com/repos/azure-cli/ "
            b"https://us-east-2.ec2.archive.ubuntu.com.example.org/ubuntu "
            b"https://us-east-2.ec2.archive.ubuntu.com/ubuntu-extra\n"
            b"Suites: noble\nComponents: main\n"
            b"Signed-By: /usr/share/keyrings/microsoft.gpg\n"
        )
        expected = original.replace(
            b"http://us-east-2.ec2.archive.ubuntu.com/ubuntu ",
            b"https://archive.ubuntu.com/ubuntu/ ",
        ).replace(
            b"https://eu-west-1.ec2.archive.ubuntu.com/ubuntu/\n",
            b"https://archive.ubuntu.com/ubuntu/\n",
        )
        self.source.write_bytes(original)

        for _ in range(2):
            subprocess.run([sys.executable, str(SCRIPT), str(self.source)],
                           check=True, capture_output=True, text=True)
            self.assertEqual(self.source.read_bytes(), expected)

    def test_already_canonical_sources_are_unchanged(self):
        source = (
            b"Types: deb\nURIs: https://archive.ubuntu.com/ubuntu/\n"
            b"Suites: noble noble-updates\nComponents: main universe\n"
            b"Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n"
        )
        self.source.write_bytes(source)
        subprocess.run([sys.executable, str(SCRIPT), str(self.source)],
                       check=True, capture_output=True, text=True)
        self.assertEqual(self.source.read_bytes(), source)
