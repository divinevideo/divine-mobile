# Publication Issues to Fix

Based on `dart pub publish --dry-run`, here are the issues that need to be addressed:

## 1. Missing Dependencies

Several packages are imported but not declared in `pubspec.yaml`:

```yaml
dependencies:
  # Add these missing dependencies:
  path: ^1.8.3
  convert: ^3.1.1
  crypto: ^3.0.3
  pointycastle: ^3.7.3
  cookie_jar: ^4.0.8
```

## 2. Dependency Version Constraints

Current versions are too restrictive. Need to use `^` for ranges:

```yaml
# CHANGE FROM:
dio: 5.7.0
dio_cookie_manager: 3.1.1
sqflite: 2.4.1
sqflite_common_ffi: 2.3.4+4
sqflite_common: 2.5.4+6
sqflite_common_ffi_web: 0.4.5+4

# TO:
dio: ^5.7.0
dio_cookie_manager: ^3.1.1
sqflite: ^2.4.1
sqflite_common_ffi: ^2.3.4+4
sqflite_common: ^2.5.4+6
sqflite_common_ffi_web: ^0.4.5+4
```

## 3. Code Quality Issues

361 analysis issues found:
- Unused imports
- Unnecessary non-null assertions
- Unnecessary 'this.' qualifiers

## 4. CHANGELOG Update

Need to add current version (0.1.0) to CHANGELOG.md

## 5. Git State

4 files are modified and need to be committed:
- README.md
- lib/event.dart
- lib/nostr_sdk.dart
- pubspec.yaml

## 6. Dependency Override

Remove the `meta` dependency override if not needed

## Fix Commands

```bash
# 1. Fix dependencies
# 2. Fix analysis issues
dart analyze --fatal-infos
dart fix --apply

# 3. Format code
dart format .

# 4. Update CHANGELOG
# 5. Commit changes
git add .
git commit -m "Prepare for publication: fix dependencies and code quality"

# 6. Test again
dart pub publish --dry-run
```