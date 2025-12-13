// ABOUTME: Widget for creating and editing text overlays with font, color, and size controls
// ABOUTME: Dark-themed modal interface with live preview, full color picker, and Google Fonts selection

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late TextEditingController _fontSearchController;
  late String _fontFamily;
  late Color _color;
  late double _fontSize;
  bool _showFontPicker = false;
  bool _showColorPicker = false;

  // Popular fonts shown first, then searchable list of all Google Fonts
  static const List<String> _popularFonts = [
    'Roboto',
    'Montserrat',
    'Pacifico',
    'Bebas Neue',
    'Oswald',
    'Playfair Display',
    'Lobster',
    'Anton',
    'Permanent Marker',
    'Bangers',
    'Alfa Slab One',
    'Righteous',
  ];

  // Quick-access color presets
  static const List<Color> _presetColors = [
    Colors.white,
    Colors.black,
    Colors.yellow,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.pink,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.overlay?.text ?? '');
    _fontSearchController = TextEditingController();
    _fontFamily = widget.overlay?.fontFamily ?? 'Roboto';
    _color = widget.overlay?.color ?? Colors.white;
    _fontSize = widget.overlay?.fontSize ?? 32.0;
  }

  @override
  void dispose() {
    _textController.dispose();
    _fontSearchController.dispose();
    super.dispose();
  }

  void _showFullColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Pick a Color', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color,
            onColorChanged: (color) => setState(() => _color = color),
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFontPickerDialog() {
    _fontSearchController.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final searchQuery = _fontSearchController.text.toLowerCase();
          final filteredFonts = searchQuery.isEmpty
              ? _popularFonts
              : GoogleFonts.asMap().keys
                  .where((font) => font.toLowerCase().contains(searchQuery))
                  .take(50)
                  .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Search field
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _fontSearchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search fonts...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                ),
                // Font list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: filteredFonts.length,
                    itemBuilder: (context, index) {
                      final font = filteredFonts[index];
                      final isSelected = font == _fontFamily;
                      return ListTile(
                        title: Text(
                          font,
                          style: GoogleFonts.getFont(
                            font,
                            color: isSelected ? Colors.green : Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() => _fontFamily = font);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
                style: GoogleFonts.getFont(
                  _fontFamily,
                  fontSize: _fontSize,
                  color: _color,
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
            GestureDetector(
              onTap: _showFontPickerDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fontFamily,
                      style: GoogleFonts.getFont(
                        _fontFamily,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Color Picker
            const Text(
              'Color',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Preset colors row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._presetColors.map((color) {
                  final isSelected = _color.value == color.value;
                  return GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 40,
                      height: 40,
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
                }),
                // Custom color picker button
                GestureDetector(
                  onTap: _showFullColorPicker,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[700]!, width: 1),
                    ),
                    child: const Icon(Icons.colorize, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Current color preview
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[600]!),
              ),
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
