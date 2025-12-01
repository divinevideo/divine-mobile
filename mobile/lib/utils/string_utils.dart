// ABOUTME: String utility functions for safe operations and formatting
// ABOUTME: Provides safe substring operations and string truncation for logging

/// Utility functions for safe string operations
class StringUtils {
  /// Safely truncate a string to a maximum length for logging purposes
  /// Returns the string truncated to [maxLength] characters, or the full string if shorter
  static String safeTruncate(String str, int maxLength) {
    if (str.length <= maxLength) {
      return str;
    }
    return str.substring(0, maxLength);
  }

  /// Safe substring operation that won't throw RangeError
  /// Returns substring from [start] to [end], handling bounds automatically
  static String safeSubstring(String str, int start, [int? end]) {
    if (str.isEmpty) return '';

    // Clamp start to valid range
    start = start.clamp(0, str.length);

    // If no end specified, use string length
    end ??= str.length;

    // Clamp end to valid range
    end = end.clamp(start, str.length);

    return str.substring(start, end);
  }

  /// Format an ID for logging - safely truncates to 8 characters
  /// Commonly used pattern throughout the codebase for logging video/event IDs
  static String formatIdForLogging(String id) => safeTruncate(id, 8);

  /// Format a number to a compact, human-readable string
  /// Examples: 999 -> "999", 1203 -> "1.2k", 1500 -> "1.5k", 1000000 -> "1M"
  /// Removes unnecessary decimal zeros (e.g., "1.0k" becomes "1k")
  static String formatCompactNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      final result = (number / 1000).toStringAsFixed(1);
      // Remove trailing .0
      return result.endsWith('.0')
          ? '${result.substring(0, result.length - 2)}k'
          : '${result}k';
    } else if (number < 1000000000) {
      final result = (number / 1000000).toStringAsFixed(1);
      // Remove trailing .0
      return result.endsWith('.0')
          ? '${result.substring(0, result.length - 2)}M'
          : '${result}M';
    } else {
      final result = (number / 1000000000).toStringAsFixed(1);
      // Remove trailing .0
      return result.endsWith('.0')
          ? '${result.substring(0, result.length - 2)}B'
          : '${result}B';
    }
  }
}
