# Test Watcher for TDD

Automatic test runner that watches for file changes and runs tests immediately.

## Quick Start

```bash
# Watch all tests (default)
./watch_tests.sh

# Watch specific test file
./watch_tests.sh test/unit/services/video_cache_service_tdd_test.dart

# Watch specific test directory
./watch_tests.sh test/unit/
```

## Installation

The script requires `fswatch` to watch for file changes:

```bash
brew install fswatch
```

## How It Works

1. **Initial Run**: Runs tests once when started
2. **Watch Mode**: Monitors `lib/` and `test/` directories for `.dart` file changes
3. **Debouncing**: Groups rapid changes (1-second debounce) to avoid test spam
4. **Auto-Run**: Automatically runs tests after file changes detected

## Features

- ✅ Colored output for easy status reading
- ✅ Timestamps for each test run
- ✅ Excludes build artifacts and dependencies
- ✅ Works with both individual test files and directories
- ✅ Debounced to prevent test spam during rapid edits

## TDD Workflow

```bash
# Terminal 1: Run test watcher
./watch_tests.sh test/unit/my_feature_test.dart

# Terminal 2: Edit code
# Make changes to lib/my_feature.dart or test/unit/my_feature_test.dart
# Tests automatically run on save
```

## Configuration

Edit `watch_tests.sh` to customize:
- `DEBOUNCE_SECONDS`: Time to wait after changes (default: 1 second)
- Exclude patterns: Add more paths to ignore
- Watch patterns: Change what file types trigger tests

## Tips

- Use specific test paths during focused TDD work
- Watch full `test/` directory for broader coverage
- Terminal stays open showing test history
- Stop with `Ctrl+C`
