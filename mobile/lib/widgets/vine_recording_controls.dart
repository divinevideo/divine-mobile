// ABOUTME: Universal Vine recording UI controls that work across all platforms
// ABOUTME: Provides press-to-record button, progress bar, and recording state feedback

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// ProofMode indicator badge showing active cryptographic proof recording
class ProofModeIndicator extends StatelessWidget {
  const ProofModeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade700.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade400, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            'ProofMode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress bar that uses provider state for updates
class VineRecordingProgressBarWithState extends StatelessWidget {
  const VineRecordingProgressBarWithState({
    required this.progress,
    required this.recordingState,
    super.key,
  });
  final double progress;
  final VineRecordingState recordingState;

  @override
  Widget build(BuildContext context) => Container(
    height: 4,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(2),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final progressWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);

        return Stack(
          children: [
            // Background
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Progress fill
            AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              width: progressWidth,
              decoration: BoxDecoration(
                color: recordingState == VineRecordingState.recording
                    ? VineTheme.vineGreen
                    : Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Progress bar that shows recording progress with segments (legacy)
class VineRecordingProgressBar extends StatelessWidget {
  const VineRecordingProgressBar({required this.controller, super.key});
  final VineRecordingController controller;

  @override
  Widget build(BuildContext context) => Container(
    height: 4,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(2),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final progressWidth =
            constraints.maxWidth * controller.progress.clamp(0.0, 1.0);

        return Stack(
          children: [
            // Background
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Progress fill
            AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              width: progressWidth,
              decoration: BoxDecoration(
                color: controller.state == VineRecordingState.recording
                    ? VineTheme.vineGreen
                    : Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The main record button with press-to-record functionality
class VineRecordButton extends StatefulWidget {
  const VineRecordButton({
    required this.controller,
    super.key,
    this.onRecordingComplete,
  });
  final VineRecordingController controller;
  final VoidCallback? onRecordingComplete;

  @override
  State<VineRecordButton> createState() => _VineRecordButtonState();
}

class _VineRecordButtonState extends State<VineRecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Set up callback for recording completion
    widget.controller.setStateChangeCallback(_onRecordingStateChanged);
  }

  @override
  void dispose() {
    // Clear the callback to prevent memory leaks
    widget.controller.setStateChangeCallback(null);
    _animationController.dispose();
    super.dispose();
  }

  void _onRecordingStateChanged() {
    if (mounted) {
      setState(() {}); // Trigger rebuild to update button appearance
      if (widget.controller.state == VineRecordingState.completed) {
        widget.onRecordingComplete?.call();
      }
    }
  }

  void _onTapDown(TapDownDetails details) {
    Log.debug(
      'Record button tap down - canRecord: ${widget.controller.canRecord}, state: ${widget.controller.state}',
      name: 'VineRecordingControls',
      category: LogCategory.ui,
    );

    // If in error state, try to reset first
    if (widget.controller.state == VineRecordingState.error) {
      Log.error(
        'Resetting from error state before recording',
        name: 'VineRecordingControls',
        category: LogCategory.ui,
      );
      widget.controller.reset();
      return;
    }

    if (!widget.controller.canRecord) return;

    setState(() => _isPressed = true);
    _animationController.forward();
    widget.controller.startRecording();
  }

  void _onTapUp(TapUpDetails details) {
    Log.debug(
      'Record button tap up - isPressed: $_isPressed, state: ${widget.controller.state}',
      name: 'VineRecordingControls',
      category: LogCategory.ui,
    );
    if (!_isPressed || !mounted) return;

    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.controller.stopRecording();
  }

  void _onTapCancel() {
    Log.debug(
      'Record button tap cancel - isPressed: $_isPressed, state: ${widget.controller.state}',
      name: 'VineRecordingControls',
      category: LogCategory.ui,
    );
    if (!_isPressed || !mounted) return;

    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.controller.stopRecording();
  }

  @override
  Widget build(BuildContext context) {
    // Use press-and-hold behavior for all platforms
    return Listener(
      onPointerDown: (event) {
        _onTapDown(TapDownDetails(globalPosition: event.position));
      },
      onPointerUp: (event) {
        _onTapUp(TapUpDetails(kind: event.kind));
      },
      onPointerCancel: (event) {
        _onTapCancel();
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        // Add pan events for better web support
        onPanStart: (details) =>
            _onTapDown(TapDownDetails(globalPosition: details.globalPosition)),
        onPanEnd: (details) =>
            _onTapUp(TapUpDetails(kind: PointerDeviceKind.touch)),
        onPanCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getButtonColor(),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: _isPressed
                    ? [
                        const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(_getButtonIcon(), color: Colors.white, size: 40),
            ),
          ),
        ),
      ),
    );
  }

  Color _getButtonColor() {
    switch (widget.controller.state) {
      case VineRecordingState.recording:
        return Colors.red;
      case VineRecordingState.completed:
        return Colors.green;
      case VineRecordingState.error:
        return Colors.orange;
      case VineRecordingState.processing:
        return Colors.blue;
      default:
        return widget.controller.canRecord ? VineTheme.vineGreen : Colors.grey;
    }
  }

  IconData _getButtonIcon() {
    switch (widget.controller.state) {
      case VineRecordingState.recording:
        return Icons.fiber_manual_record;
      case VineRecordingState.completed:
        return Icons.check;
      case VineRecordingState.processing:
        return Icons.hourglass_empty;
      case VineRecordingState.error:
        return Icons.error;
      default:
        return Icons.videocam;
    }
  }
}

/// Recording instructions that use provider state for updates
class VineRecordingInstructionsWithState extends StatelessWidget {
  const VineRecordingInstructionsWithState({required this.state, super.key});
  final VineRecordingUIState state;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Duration display
      Text(
        _getDurationText(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),

      const SizedBox(height: 8),

      // Instructions
      Text(
        _getInstructionText(),
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    ],
  );

  String _getDurationText() {
    final recorded = state.totalRecordedDuration.inSeconds;
    final remaining = state.remainingDuration.inSeconds;

    switch (state.recordingState) {
      case VineRecordingState.recording:
        return '$recorded"/${VineRecordingController.maxRecordingDuration.inSeconds}" • Recording...';
      case VineRecordingState.completed:
        return 'Recording Complete!';
      case VineRecordingState.processing:
        return 'Processing...';
      case VineRecordingState.error:
        return 'Error occurred';
      default:
        if (state.segments.isNotEmpty) {
          return '$recorded"/${VineRecordingController.maxRecordingDuration.inSeconds}" • ${remaining}s remaining';
        }
        return '${VineRecordingController.maxRecordingDuration.inSeconds}s Vine • Press and hold to record';
    }
  }

  String _getInstructionText() {
    switch (state.recordingState) {
      case VineRecordingState.recording:
        return 'Release to pause • Recording segment ${state.segments.length + 1}';
      case VineRecordingState.paused:
        return 'Press and hold to continue recording';
      case VineRecordingState.completed:
        return 'Tap next to add caption and share';
      case VineRecordingState.processing:
        return 'Compiling your vine...';
      case VineRecordingState.error:
        return 'Something went wrong. Tap button to retry.';
      default:
        return 'Press and hold to record, release to pause';
    }
  }
}

/// Record button that uses provider state for updates
class VineRecordButtonWithState extends StatefulWidget {
  const VineRecordButtonWithState({
    required this.controller,
    required this.state,
    super.key,
    this.onRecordingComplete,
  });
  final VineRecordingController controller;
  final VineRecordingUIState state;
  final VoidCallback? onRecordingComplete;

  @override
  State<VineRecordButtonWithState> createState() =>
      _VineRecordButtonWithStateState();
}

class _VineRecordButtonWithStateState extends State<VineRecordButtonWithState>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(VineRecordButtonWithState oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check for recording completion
    if (widget.state.recordingState == VineRecordingState.completed &&
        oldWidget.state.recordingState != VineRecordingState.completed) {
      // Defer the callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRecordingComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    Log.debug(
      'Record button tap down - canRecord: ${widget.state.canRecord}, state: ${widget.state.recordingState}',
      name: 'VineRecordingControls',
      category: LogCategory.ui,
    );

    // If in error state, try to reset first
    if (widget.state.recordingState == VineRecordingState.error) {
      Log.error(
        'Resetting from error state before recording',
        name: 'VineRecordingControls',
        category: LogCategory.ui,
      );
      widget.controller.reset();
      return;
    }

    if (!widget.state.canRecord) return;

    setState(() => _isPressed = true);
    _animationController.forward();
    widget.controller.startRecording();
  }

  void _onTapUp(TapUpDetails details) {
    Log.debug(
      'Record button tap up - isPressed: $_isPressed, state: ${widget.state.recordingState}',
      name: 'VineRecordingControls',
      category: LogCategory.ui,
    );
    if (!_isPressed || !mounted) return;

    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.controller.stopRecording();
  }

  void _onTapCancel() {
    Log.debug(
      'Record button tap cancel - isPressed: $_isPressed, state: ${widget.state.recordingState}',
      name: 'VineRecordingControls',
      category: LogCategory.ui,
    );
    if (!_isPressed || !mounted) return;

    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.controller.stopRecording();
  }

  @override
  Widget build(BuildContext context) {
    // Use press-and-hold behavior for all platforms
    return Listener(
      onPointerDown: (event) {
        _onTapDown(TapDownDetails(globalPosition: event.position));
      },
      onPointerUp: (event) {
        _onTapUp(TapUpDetails(kind: event.kind));
      },
      onPointerCancel: (event) {
        _onTapCancel();
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        // Add pan events for better web support
        onPanStart: (details) =>
            _onTapDown(TapDownDetails(globalPosition: details.globalPosition)),
        onPanEnd: (details) =>
            _onTapUp(TapUpDetails(kind: PointerDeviceKind.touch)),
        onPanCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getButtonColor(),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: _isPressed
                    ? [
                        const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(_getButtonIcon(), color: Colors.white, size: 40),
            ),
          ),
        ),
      ),
    );
  }

  Color _getButtonColor() {
    switch (widget.state.recordingState) {
      case VineRecordingState.recording:
        return Colors.red;
      case VineRecordingState.completed:
        return Colors.green;
      case VineRecordingState.error:
        return Colors.orange;
      case VineRecordingState.processing:
        return Colors.blue;
      default:
        return widget.state.canRecord ? VineTheme.vineGreen : Colors.grey;
    }
  }

  IconData _getButtonIcon() {
    switch (widget.state.recordingState) {
      case VineRecordingState.recording:
        return Icons.fiber_manual_record;
      case VineRecordingState.completed:
        return Icons.check;
      case VineRecordingState.processing:
        return Icons.hourglass_empty;
      case VineRecordingState.error:
        return Icons.error;
      default:
        return Icons.videocam;
    }
  }
}

/// Recording instructions and feedback text (legacy)
class VineRecordingInstructions extends StatelessWidget {
  const VineRecordingInstructions({required this.controller, super.key});
  final VineRecordingController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Duration display
      Text(
        _getDurationText(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),

      const SizedBox(height: 8),

      // Instructions
      Text(
        _getInstructionText(),
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    ],
  );

  String _getDurationText() {
    final recorded = controller.totalRecordedDuration.inSeconds;
    final remaining = controller.remainingDuration.inSeconds;

    switch (controller.state) {
      case VineRecordingState.recording:
        return '$recorded"/${VineRecordingController.maxRecordingDuration.inSeconds}" • Recording...';
      case VineRecordingState.completed:
        return 'Recording Complete!';
      case VineRecordingState.processing:
        return 'Processing...';
      case VineRecordingState.error:
        return 'Error occurred';
      default:
        if (controller.hasSegments) {
          return '$recorded"/${VineRecordingController.maxRecordingDuration.inSeconds}" • ${remaining}s remaining';
        }
        return '${VineRecordingController.maxRecordingDuration.inSeconds}s Vine • Press and hold to record';
    }
  }

  String _getInstructionText() {
    switch (controller.state) {
      case VineRecordingState.recording:
        return 'Release to pause • Recording segment ${controller.segments.length + 1}';
      case VineRecordingState.paused:
        return 'Press and hold to continue recording';
      case VineRecordingState.completed:
        return 'Tap next to add caption and share';
      case VineRecordingState.processing:
        return 'Compiling your vine...';
      case VineRecordingState.error:
        return 'Something went wrong. Tap button to retry.';
      default:
        return 'Press and hold to record, release to pause';
    }
  }
}

/// Vine recording UI that uses provider state for updates
class VineRecordingUIWithProvider extends StatelessWidget {
  const VineRecordingUIWithProvider({
    required this.controller,
    required this.state,
    super.key,
    this.onRecordingComplete,
    this.onCancel,
  });
  final VineRecordingController controller;
  final VineRecordingUIState state;
  final VoidCallback? onRecordingComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top controls: ProofMode indicator, progress bar and camera switch
          Row(
            children: [
              // Camera switch button (only show when not recording and switching is available)
              if (state.recordingState != VineRecordingState.recording &&
                  controller.canSwitchCamera)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: GestureDetector(
                    onTap: controller.switchCamera,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                        border: Border.all(color: Colors.white54, width: 1),
                      ),
                      child: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

              // Progress bar (takes remaining space)
              Expanded(
                child: Column(
                  children: [
                    // ProofMode indicator at top
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ProofModeIndicator(),
                    ),
                    // Progress bar below
                    VineRecordingProgressBarWithState(
                      progress: state.progress,
                      recordingState: state.recordingState,
                    ),
                  ],
                ),
              ),

              // Spacer to balance the camera switch button (only when button is shown)
              if (state.recordingState != VineRecordingState.recording &&
                  controller.canSwitchCamera)
                const SizedBox(width: 56), // Same width as button + padding
            ],
          ),

          const Spacer(),

          // Recording controls at bottom
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instructions
              VineRecordingInstructionsWithState(state: state),

              const SizedBox(height: 30),

              // Control buttons
              SizedBox(
                height: 80, // Fixed height to prevent overflow
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel/Reset button
                    if (state.segments.isNotEmpty ||
                        state.recordingState == VineRecordingState.error) ...[
                      GestureDetector(
                        onTap: () {
                          controller.reset();
                          onCancel?.call();
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                            border: Border.all(color: Colors.white54, width: 2),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 50), // Placeholder for spacing
                    ],

                    // Main record button (hide when completed to avoid duplicate check icons)
                    if (state.recordingState !=
                        VineRecordingState.completed) ...[
                      VineRecordButtonWithState(
                        controller: controller,
                        state: state,
                        onRecordingComplete: onRecordingComplete,
                      ),
                    ] else ...[
                      const SizedBox(
                        width: 80,
                      ), // Placeholder matching button size
                    ],

                    // Done/Next button
                    if ((state.segments.isNotEmpty ||
                            state.recordingState ==
                                VineRecordingState.completed) &&
                        state.recordingState !=
                            VineRecordingState.recording) ...[
                      GestureDetector(
                        onTap: onRecordingComplete,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VineTheme.vineGreen,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 50), // Placeholder for spacing
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Complete Vine recording UI that combines all components (legacy version)
class VineRecordingUI extends StatefulWidget {
  const VineRecordingUI({
    required this.controller,
    super.key,
    this.onRecordingComplete,
    this.onCancel,
  });
  final VineRecordingController controller;
  final VoidCallback? onRecordingComplete;
  final VoidCallback? onCancel;

  @override
  State<VineRecordingUI> createState() => _VineRecordingUIState();
}

class _VineRecordingUIState extends State<VineRecordingUI> {
  @override
  void initState() {
    super.initState();
    // Listen for state changes to trigger rebuilds
    widget.controller.setStateChangeCallback(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.controller.setStateChangeCallback(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top controls: progress bar and camera switch
          Row(
            children: [
              // Camera switch button (only show when not recording and switching is available)
              if (widget.controller.state != VineRecordingState.recording &&
                  widget.controller.canSwitchCamera)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: GestureDetector(
                    onTap: widget.controller.switchCamera,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                        border: Border.all(color: Colors.white54, width: 1),
                      ),
                      child: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

              // Progress bar (takes remaining space)
              Expanded(
                child: VineRecordingProgressBar(controller: widget.controller),
              ),

              // Spacer to balance the camera switch button (only when button is shown)
              if (widget.controller.state != VineRecordingState.recording &&
                  widget.controller.canSwitchCamera)
                const SizedBox(width: 56), // Same width as button + padding
            ],
          ),

          const Spacer(),

          // Recording controls at bottom
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instructions
              VineRecordingInstructions(controller: widget.controller),

              const SizedBox(height: 30),

              // Control buttons
              SizedBox(
                height: 80, // Fixed height to prevent overflow
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel/Reset button
                    if (widget.controller.hasSegments ||
                        widget.controller.state ==
                            VineRecordingState.error) ...[
                      GestureDetector(
                        onTap: () {
                          widget.controller.reset();
                          widget.onCancel?.call();
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                            border: Border.all(color: Colors.white54, width: 2),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 50), // Placeholder for spacing
                    ],

                    // Main record button
                    VineRecordButton(
                      controller: widget.controller,
                      onRecordingComplete: widget.onRecordingComplete,
                    ),

                    // Done/Next button
                    if ((widget.controller.hasSegments ||
                            widget.controller.state ==
                                VineRecordingState.completed) &&
                        widget.controller.state !=
                            VineRecordingState.recording) ...[
                      GestureDetector(
                        onTap: widget.onRecordingComplete,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VineTheme.vineGreen,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 50), // Placeholder for spacing
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    ),
  );
}
