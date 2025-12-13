// ABOUTME: Model representing a text overlay on a video with position, style, and serialization
// ABOUTME: Supports JSON conversion for persistence and normalized positioning (0.0-1.0)

import 'package:flutter/material.dart';

class TextOverlay {
  final String id;
  final String text;
  final double fontSize;
  final Color color;
  final Offset normalizedPosition; // 0.0 to 1.0 for x and y
  final TextAlign alignment;
  final String fontFamily;

  TextOverlay({
    required this.id,
    required this.text,
    this.fontSize = 32.0,
    this.color = Colors.white,
    required Offset normalizedPosition,
    this.alignment = TextAlign.center,
    this.fontFamily = 'Roboto',
  }) : normalizedPosition = Offset(
          normalizedPosition.dx.clamp(0.0, 1.0),
          normalizedPosition.dy.clamp(0.0, 1.0),
        );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'fontSize': fontSize,
      'color': color.toARGB32(),
      'positionX': normalizedPosition.dx,
      'positionY': normalizedPosition.dy,
      'alignment': _textAlignToString(alignment),
      'fontFamily': fontFamily,
    };
  }

  factory TextOverlay.fromJson(Map<String, dynamic> json) {
    return TextOverlay(
      id: json['id'] as String,
      text: json['text'] as String,
      fontSize: (json['fontSize'] as num).toDouble(),
      color: Color(json['color'] as int),
      normalizedPosition: Offset(
        (json['positionX'] as num).toDouble(),
        (json['positionY'] as num).toDouble(),
      ),
      alignment: _stringToTextAlign(json['alignment'] as String),
      fontFamily: json['fontFamily'] as String,
    );
  }

  TextOverlay copyWith({
    String? id,
    String? text,
    double? fontSize,
    Color? color,
    Offset? normalizedPosition,
    TextAlign? alignment,
    String? fontFamily,
  }) {
    return TextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      normalizedPosition: normalizedPosition ?? this.normalizedPosition,
      alignment: alignment ?? this.alignment,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  static String _textAlignToString(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return 'left';
      case TextAlign.center:
        return 'center';
      case TextAlign.right:
        return 'right';
      default:
        return 'center';
    }
  }

  static TextAlign _stringToTextAlign(String align) {
    switch (align) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }
}
