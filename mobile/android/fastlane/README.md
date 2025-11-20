## fastlane documentation

# Installation

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

1. Download Google Service account JSON file and put it in `/.keys/` folder (added to .gitignore) and set the path in `Appfile`.
2. `fastlane supply init` to download the metadata for your app from Google Play and check it in with git.

# usage

- `fastlane beta` => Deploy a new version to open Testing Track
- `fastlane production` => Deploy a new version to Google Play
