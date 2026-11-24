"""Route EC2 Ubuntu mirrors through the official HTTPS archive for CI setup."""

import argparse
from pathlib import Path
import re


EC2_ARCHIVE_URI = re.compile(
    rb"(?<!\S)https?://[a-z0-9-]+\.ec2\.archive\.ubuntu\.com/ubuntu/?(?=\s|$)"
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", type=Path, nargs="+")
    for source in parser.parse_args().sources:
        original = source.read_bytes()
        updated = EC2_ARCHIVE_URI.sub(
            b"https://archive.ubuntu.com/ubuntu/", original
        )
        if updated != original:
            source.write_bytes(updated)


if __name__ == "__main__":
    main()
