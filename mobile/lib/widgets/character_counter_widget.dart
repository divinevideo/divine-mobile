// ABOUTME: Character counter widget for text input fields with customizable limits and warning states
// ABOUTME: Provides visual feedback for character limits with color-coded status indicators

import 'package:flutter/material.dart';

class CharacterCounterWidget extends StatelessWidget {
  const CharacterCounterWidget({
    required this.currentLength,
    required this.maxLength,
    super.key,
    this.showWarning = true,
    this.warningThreshold = 0.8,
  });
  final int currentLength;
  final int maxLength;
  final bool showWarning;
  final double warningThreshold;

  @override
  Widget build(BuildContext context) {
    final ratio = currentLength / maxLength;
    final isOverLimit = currentLength > maxLength;
    final isWarning = showWarning && ratio >= warningThreshold && !isOverLimit;

    Color getColor() {
      if (isOverLimit) return Colors.red;
      if (isWarning) return Colors.orange;
      return Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOverLimit || isWarning)
          Icon(
            isOverLimit ? Icons.error : Icons.warning,
            size: 16,
            color: getColor(),
          ),
        if (isOverLimit || isWarning) const SizedBox(width: 4),
        Text(
          '$currentLength/$maxLength',
          style: TextStyle(
            color: getColor(),
            fontSize: 12,
            fontWeight: isOverLimit || isWarning
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
