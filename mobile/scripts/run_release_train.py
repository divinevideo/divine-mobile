#!/usr/bin/env python3
import sys

from release_train.providers import ProviderError
from release_train.runner import main

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ProviderError, KeyError, ValueError, OSError) as error:
        print(
            "Release train stopped: "
            + (
                str(error)
                if isinstance(error, ProviderError)
                else "missing configuration or malformed provider response"
            )
        )
        sys.exit(1)
