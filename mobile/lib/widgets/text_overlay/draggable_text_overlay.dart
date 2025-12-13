// ABOUTME: Widget for displaying and dragging text overlays on videos
// ABOUTME: Converts between normalized (0.0-1.0) and absolute pixel coordinates

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/models/text_overlay.dart';

class DraggableTextOverlay extends StatefulWidget {
  final TextOverlay overlay;
  final Size videoSize;
  final void Function(Offset normalizedPosition) onPositionChanged;

  const DraggableTextOverlay({
    Key? key,
    required this.overlay,
    required this.videoSize,
    required this.onPositionChanged,
  }) : super(key: key);

  @override
  State<DraggableTextOverlay> createState() => _DraggableTextOverlayState();
}

class _DraggableTextOverlayState extends State<DraggableTextOverlay> {
  late Offset _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = _normalizedToAbsolute(widget.overlay.normalizedPosition);
  }

  @override
  void didUpdateWidget(DraggableTextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlay.normalizedPosition != widget.overlay.normalizedPosition) {
      _currentPosition = _normalizedToAbsolute(widget.overlay.normalizedPosition);
    }
  }

  Offset _normalizedToAbsolute(Offset normalized) {
    return Offset(
      normalized.dx * widget.videoSize.width,
      normalized.dy * widget.videoSize.height,
    );
  }

  Offset _absoluteToNormalized(Offset absolute) {
    final normalized = Offset(
      absolute.dx / widget.videoSize.width,
      absolute.dy / widget.videoSize.height,
    );

    return Offset(
      normalized.dx.clamp(0.0, 1.0),
      normalized.dy.clamp(0.0, 1.0),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPosition = Offset(
        (_currentPosition.dx + details.delta.dx).clamp(0.0, widget.videoSize.width),
        (_currentPosition.dy + details.delta.dy).clamp(0.0, widget.videoSize.height),
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final normalizedPosition = _absoluteToNormalized(_currentPosition);
    widget.onPositionChanged(normalizedPosition);
  }

  @override
  Widget build(BuildContext context) {
    // Return Positioned directly - this widget should be placed inside a Stack
    return Positioned(
      left: _currentPosition.dx,
      top: _currentPosition.dy,
      child: GestureDetector(
        onPanUpdate: _handleDragUpdate,
        onPanEnd: _handleDragEnd,
        child: Text(
          widget.overlay.text,
          style: GoogleFonts.getFont(
            widget.overlay.fontFamily,
            fontSize: widget.overlay.fontSize,
            color: widget.overlay.color,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 3.0,
                color: Colors.black.withValues(alpha: 0.8),
              ),
            ],
          ),
          textAlign: widget.overlay.alignment,
        ),
      ),
    );
  }
}
