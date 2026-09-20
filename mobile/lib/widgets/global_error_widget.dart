// ABOUTME: The app's ErrorWidget.builder: the branded "got a bit tangled"
// ABOUTME: surface shown in place of any widget that throws during build

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unified_logger/unified_logger.dart';

/// The illustration above the copy: the Divine mascot caught in a vine, so the
/// picture says what the copy says — it was us that got tangled, not the user.
@visibleForTesting
const globalErrorMascotAsset = 'assets/illustrations/error_mascot_tangled.png';

/// Builds the surface the framework shows in place of a widget whose build
/// failed. The startup sequence installs it as [ErrorWidget.builder].
///
/// It has to render anywhere in the tree, including before [MaterialApp]
/// exists, so it brings its own [Directionality] and reads colours through
/// `context.vineColors`, which follows the ambient appearance inside the app
/// shell and falls back to the dark palette when no theme exists yet. The copy
/// sets raw text styles with an explicit `TextDecoration.none` so it paints on
/// the first frame without waiting on a font. Reload is the real
/// design-system button: its label variant, Bricolage Grotesque ExtraBold,
/// ships in `assets/fonts/`, so resolving it is a local asset read and never a
/// network fetch.
///
/// Reporting is not this widget's job. Every framework call site reports
/// [details] through [FlutterError.onError] before it asks the builder for a
/// replacement, and that handler already owns classification and Crashlytics.
/// A second report from here would count every build failure twice and file
/// as fatal the ones the handler deliberately downgraded.
Widget buildGlobalErrorWidget(FlutterErrorDetails details) {
  // On web, log error details for debugging
  if (kIsWeb) {
    Log.error(
      'ErrorWidget: ${details.exception}\n${details.stack}',
      name: 'ErrorWidget',
      category: LogCategory.system,
    );
  }
  return _GlobalErrorWidget(details: details);
}

/// Re-runs the build that failed.
///
/// The framework mounts this surface as the direct child of the element whose
/// build threw, so marking that parent dirty makes it build again, and a build
/// that succeeds replaces this surface with the real subtree.
void _retryFailedBuild(BuildContext context) {
  if (!context.mounted) return;
  context.visitAncestorElements((failedElement) {
    failedElement.markNeedsBuild();
    return false;
  });
}

/// The surface itself: the message on the app's background.
class _GlobalErrorWidget extends StatelessWidget {
  const _GlobalErrorWidget({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: context.vineColors.background,
        child: _ErrorMessage(
          details: details,
          // This context, not a descendant's: its parent is the element whose
          // build failed.
          onReload: () => _retryFailedBuild(context),
        ),
      ),
    );
  }
}

/// The illustration, the copy and the Reload action, centred and scrollable.
class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.details,
    required this.onReload,
  });

  final FlutterErrorDetails details;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                globalErrorMascotAsset,
                width: 220,
                excludeFromSemantics: true,
                // A missing illustration must not turn the crash surface into
                // a second failure.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 28),

              // Headline
              Text(
                'got a bit tangled',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.vineColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Friendly explanation
              Text(
                "something tripped up here.\nit's not you, it's us.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.vineColors.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),

              // Gentle nudge
              Text(
                'try navigating away and coming back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.vineColors.onSurfaceMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 24),

              DivineButton(
                label: 'Reload',
                type: DivineButtonType.secondary,
                onPressed: onReload,
              ),

              // Debug info for developers; on web the exception text is shown
              // in every build mode.
              if (kDebugMode || kIsWeb) ...[
                const SizedBox(height: 24),
                _ErrorDetailsBlock(details: details),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What failed, for developers.
class _ErrorDetailsBlock extends StatelessWidget {
  const _ErrorDetailsBlock({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.vineColors.disabled),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'debug info',
            style: TextStyle(
              color: context.vineColors.accentPositive,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details.exceptionAsString(),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VineTheme.error,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              fontFamily: 'monospace',
              decoration: TextDecoration.none,
              height: 1.4,
            ),
          ),
          if (details.context != null) ...[
            const SizedBox(height: 6),
            Text(
              details.context!.toDescription(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.vineColors.onSurfaceMuted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                fontFamily: 'monospace',
                decoration: TextDecoration.none,
              ),
            ),
          ],
          if (details.library != null) ...[
            const SizedBox(height: 6),
            Text(
              'library: ${details.library}',
              style: TextStyle(
                color: context.vineColors.onSurfaceMuted,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                fontFamily: 'monospace',
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
