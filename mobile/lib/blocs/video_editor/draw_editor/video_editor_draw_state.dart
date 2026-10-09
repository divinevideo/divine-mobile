part of 'video_editor_draw_bloc.dart';

/// Available drawing tool types.
enum DrawToolType {
  /// Pencil with thin line.
  pencil,

  /// Marker with medium line and a bit transparent.
  marker,

  /// Pencil line with a arrow on the end.
  arrow,

  /// Eraser tool.
  eraser,

  /// Hides the area dragged over behind a blur.
  blur,

  /// Hides the area dragged over behind large square blocks.
  pixelate;

  /// Returns the paint configuration (mode, opacity, stroke width) for this tool.
  DrawToolConfig get config => switch (this) {
    .pencil => (mode: .freeStyle, opacity: 1.0, strokeWidth: 6.0),
    .marker => (mode: .freeStyle, opacity: 0.7, strokeWidth: 12.0),
    .arrow => (mode: .freeStyleArrowEnd, opacity: 1.0, strokeWidth: 8.0),
    .eraser => (mode: .eraser, opacity: 1.0, strokeWidth: 12.0),
    // A censor area is a rectangle; it has no stroke.
    .blur => (mode: .blur, opacity: 1.0, strokeWidth: 1.0),
    .pixelate => (mode: .pixelate, opacity: 1.0, strokeWidth: 1.0),
  };

  /// Whether this tool hides an area rather than drawing on the video.
  bool get isCensor => this == .blur || this == .pixelate;
}

/// Paint configuration for a drawing tool.
typedef DrawToolConfig = ({PaintMode mode, double opacity, double strokeWidth});

/// The stroke width, in logical pixels of the editor body, of a brush at
/// [brushSize] on its 0 to 1 slider.
///
/// The slider is quadratic, so the thin end, where a pixel more or less shows
/// most, gets more of its travel.
double drawStrokeWidthOf(double brushSize) {
  const min = VideoEditorConstants.drawMinStrokeWidth;
  const range = VideoEditorConstants.drawMaxStrokeWidth - min;
  final size = brushSize.clamp(0.0, 1.0);
  return min + range * size * size;
}

/// Where [strokeWidth] sits on the 0 to 1 brush size slider; the inverse of
/// [drawStrokeWidthOf].
double drawBrushSizeOf(double strokeWidth) {
  const min = VideoEditorConstants.drawMinStrokeWidth;
  const range = VideoEditorConstants.drawMaxStrokeWidth - min;
  return math.sqrt(((strokeWidth - min) / range).clamp(0.0, 1.0));
}

/// State for the video editor draw/paint screen.
class VideoEditorDrawState extends Equatable {
  const VideoEditorDrawState({
    this.canUndo = false,
    this.canRedo = false,
    this.strokeWidths = const {},
    this.opacity = 1.0,
    this.selectedColor = VideoEditorConstants.primaryColor,
    this.selectedTool = .pencil,
    this.mode = .freeStyle,
    this.blurIntensity = VideoEditorConstants.censorDefaultIntensity,
    this.pixelateIntensity = VideoEditorConstants.censorDefaultIntensity,
  });

  /// Whether the undo action is available.
  final bool canUndo;

  /// Whether the redo action is available.
  final bool canRedo;

  /// The currently selected drawing tool.
  final DrawToolType selectedTool;

  /// The stroke widths the creator set per drawing tool. A tool missing here
  /// draws at the width of its [DrawToolType.config].
  final Map<DrawToolType, double> strokeWidths;

  /// The opacity for drawing.
  final double opacity;

  /// The currently selected drawing color.
  final Color selectedColor;

  /// The current paint mode.
  final PaintMode mode;

  /// How strongly the blur tool hides an area, from 0 to 1.
  final double blurIntensity;

  /// How strongly the pixelate tool hides an area, from 0 to 1.
  final double pixelateIntensity;

  /// The stroke width the selected tool draws with.
  double get strokeWidth => strokeWidthOf(selectedTool);

  /// The stroke width [tool] draws with.
  double strokeWidthOf(DrawToolType tool) =>
      strokeWidths[tool] ?? tool.config.strokeWidth;

  /// Where the selected tool's stroke width sits on its 0 to 1 slider.
  double get brushSize => drawBrushSizeOf(strokeWidth);

  /// How strongly the selected censor tool hides an area, from 0 to 1.
  double get censorIntensity => censorIntensityOf(selectedTool);

  /// How strongly [tool] hides an area, from 0 to 1.
  double censorIntensityOf(DrawToolType tool) =>
      tool == .pixelate ? pixelateIntensity : blurIntensity;

  /// Whether the editor hides areas (blur, pixelate) instead of drawing.
  bool get isCensorMode => selectedTool.isCensor;

  /// Creates a copy with the given fields replaced.
  VideoEditorDrawState copyWith({
    bool? canUndo,
    bool? canRedo,
    DrawToolType? selectedTool,
    Map<DrawToolType, double>? strokeWidths,
    double? opacity,
    Color? selectedColor,
    PaintMode? mode,
    double? blurIntensity,
    double? pixelateIntensity,
  }) {
    return VideoEditorDrawState(
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      selectedTool: selectedTool ?? this.selectedTool,
      strokeWidths: strokeWidths ?? this.strokeWidths,
      opacity: opacity ?? this.opacity,
      selectedColor: selectedColor ?? this.selectedColor,
      mode: mode ?? this.mode,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      pixelateIntensity: pixelateIntensity ?? this.pixelateIntensity,
    );
  }

  @override
  List<Object?> get props => [
    canUndo,
    canRedo,
    selectedTool,
    strokeWidths,
    opacity,
    selectedColor,
    mode,
    blurIntensity,
    pixelateIntensity,
  ];
}
