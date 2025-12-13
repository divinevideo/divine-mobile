// ABOUTME: Widget for creating and editing text overlays with font, color, and size controls
// ABOUTME: Dark-themed modal interface with live preview and preset style options

import 'package:flutter/material.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:uuid/uuid.dart';

class TextOverlayEditor extends StatefulWidget {
  final TextOverlay? overlay;
  final void Function(TextOverlay overlay) onSave;
  final VoidCallback? onCancel;

  const TextOverlayEditor({
    Key? key,
    this.overlay,
    required this.onSave,
    this.onCancel,
  }) : super(key: key);

  @override
  State<TextOverlayEditor> createState() => _TextOverlayEditorState();
}

class _TextOverlayEditorState extends State<TextOverlayEditor> {
  late TextEditingController _textController;
  late String _fontFamily;
  late Color _color;
  late double _fontSize;

  final List<String> _fontOptions = ['Roboto', 'Montserrat', 'Pacifico'];
  final List<Color> _colorOptions = [
    Colors.white,
    Colors.black,
    Colors.yellow,
    Colors.red,
    Colors.blue,
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.overlay?.text ?? '');
    _fontFamily = widget.overlay?.fontFamily ?? 'Roboto';
    _color = widget.overlay?.color ?? Colors.white;
    _fontSize = widget.overlay?.fontSize ?? 32.0;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_textController.text.trim().isEmpty) {
      return;
    }

    final overlay = TextOverlay(
      id: widget.overlay?.id ?? const Uuid().v4(),
      text: _textController.text,
      fontSize: _fontSize,
      color: _color,
      normalizedPosition: widget.overlay?.normalizedPosition ?? const Offset(0.5, 0.5),
      fontFamily: _fontFamily,
      alignment: widget.overlay?.alignment ?? TextAlign.center,
    );

    widget.onSave(overlay);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            Container(
              height: 120,
              alignment: Alignment.center,
              color: Colors.black,
              child: Text(
                _textController.text.isEmpty ? 'Preview' : _textController.text,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: _color,
                  fontFamily: _fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Text Input
            TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter text',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // Font Family Selector
            const Text(
              'Font',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: _fontOptions.map((font) {
                final isSelected = font == _fontFamily;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _fontFamily = font),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          font,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontFamily: font,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Color Picker
            const Text(
              'Color',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _colorOptions.map((color) {
                final isSelected = color == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.grey[700]!,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Size Slider
            const Text(
              'Size',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _fontSize,
              min: 16.0,
              max: 64.0,
              divisions: 24,
              activeColor: Colors.white,
              inactiveColor: Colors.grey[700],
              onChanged: (value) => setState(() => _fontSize = value),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (widget.onCancel != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                if (widget.onCancel != null) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
