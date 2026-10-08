// ABOUTME: Content preferences screen for language, audio sharing, and content filters
// ABOUTME: Composes three small Cubits (one per independent sub-setting).

import 'dart:async';

import 'package:divine_camera/divine_camera.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/audio_device/audio_device_cubit.dart';
import 'package:openvine/blocs/audio_sharing/audio_sharing_cubit.dart';
import 'package:openvine/blocs/language_setting/language_setting_cubit.dart';
import 'package:openvine/blocs/music_mode/music_mode_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/settings/account_content_labels_tile.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

class ContentPreferencesScreen extends ConsumerWidget {
  static const routeName = 'content-preferences';
  static const String path = RoutePaths.contentPreferences;

  const ContentPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.contentPreferencesTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              const ContentLanguageSetting(),
              const SubtitleTranslationSetting(),
              const _ContentFiltersTile(),
              const AccountContentLabelsTile(),
              const _AudioSharingToggle(),
              if (!kIsWeb &&
                  (defaultTargetPlatform == TargetPlatform.iOS ||
                      defaultTargetPlatform == TargetPlatform.android))
                const MusicModeSetting(),
              if (!kIsWeb && defaultTargetPlatform != TargetPlatform.linux)
                const AudioDeviceSetting(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentFiltersTile extends StatelessWidget {
  const _ContentFiltersTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: DivineIcon(
        icon: DivineIconName.funnelSimple,
        color: context.vineColors.accentPositive,
      ),
      title: Text(
        context.l10n.contentPreferencesContentFilters,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        context.l10n.contentPreferencesContentFiltersSubtitle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
      trailing: DivineIcon(
        icon: DivineIconName.caretRight,
        color: context.vineColors.mutedText,
      ),
      onTap: () => context.push(ContentFiltersScreen.path),
    );
  }
}

class ContentLanguageSetting extends ConsumerWidget {
  const ContentLanguageSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(languagePreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) {
        final cubit = LanguageSettingCubit(service: service);
        runDetached(
          cubit.load(),
          'load language setting',
          logName: 'ContentPreferencesScreen',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: const _ContentLanguageSettingTile(),
    );
  }
}

class _ContentLanguageSettingTile extends StatelessWidget {
  const _ContentLanguageSettingTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LanguageSettingCubit>().state;
    final currentCode = state.currentCode;
    final isCustom = state.isCustomLanguageSet;
    final displayName = LanguagePreferenceService.displayNameFor(currentCode);
    final subtitle = isCustom
        ? displayName
        : context.l10n.contentPreferencesContentLanguageDeviceDefault(
            displayName,
          );

    return ListTile(
      leading: DivineIcon(
        icon: DivineIconName.globe,
        color: context.vineColors.accentPositive,
      ),
      title: Text(
        context.l10n.contentPreferencesContentLanguage,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        subtitle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
      trailing: DivineIcon(
        icon: DivineIconName.caretRight,
        color: context.vineColors.mutedText,
      ),
      onTap: () => _showLanguagePicker(context),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final cubit = context.read<LanguageSettingCubit>();
    final state = cubit.state;
    await VineBottomSheet.show<void>(
      context: context,
      contentTitle: context.l10n.contentPreferencesContentLanguage,
      buildScrollBody: (scrollController) => _LanguagePickerContent(
        scrollController: scrollController,
        currentCode: state.currentCode,
        isCustomLanguageSet: state.isCustomLanguageSet,
        onUseDeviceLanguage: cubit.clearLanguage,
        onSelectLanguage: cubit.setLanguage,
      ),
    );
  }
}

class _LanguagePickerContent extends StatelessWidget {
  const _LanguagePickerContent({
    required this.scrollController,
    required this.currentCode,
    required this.isCustomLanguageSet,
    required this.onUseDeviceLanguage,
    required this.onSelectLanguage,
  });

  /// The sheet's own controller — without it the drag never reaches the
  /// [DraggableScrollableSheet], so the sheet cannot be resized or flung shut
  /// from the list.
  final ScrollController scrollController;
  final String currentCode;
  final bool isCustomLanguageSet;
  final Future<void> Function() onUseDeviceLanguage;
  final Future<void> Function(String code) onSelectLanguage;

  /// Runs [mutate], then closes the sheet from inside it. The guard is the
  /// sheet's own element, so a pop that lands after the user already dismissed
  /// it is dropped instead of closing the screen underneath.
  Future<void> _applyAndClose(
    BuildContext context,
    Future<void> Function() mutate,
  ) async {
    await mutate();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final languages = LanguagePreferenceService.supportedLanguages.entries
        .toList(growable: false);
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: languages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.l10n.contentPreferencesTagYourVideos,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.mutedText,
                  ),
                ),
              ),
              DivineSelectableRow(
                title: context.l10n.contentPreferencesUseDeviceLanguage,
                subtitle: LanguagePreferenceService.displayNameFor(
                  PlatformDispatcher.instance.locale.languageCode,
                ),
                isSelected: !isCustomLanguageSet,
                onTap: () => _applyAndClose(context, onUseDeviceLanguage),
              ),
            ],
          );
        }
        final entry = languages[index - 1];
        return DivineSelectableRow(
          title: entry.value,
          subtitle: entry.key.toUpperCase(),
          isSelected: isCustomLanguageSet && currentCode == entry.key,
          onTap: () => _applyAndClose(
            context,
            () => onSelectLanguage(entry.key),
          ),
        );
      },
    );
  }
}

class _AudioSharingToggle extends ConsumerWidget {
  const _AudioSharingToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(audioSharingPreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => AudioSharingCubit(service: service)..load(),
      child: const _AudioSharingToggleTile(),
    );
  }
}

class _AudioSharingToggleTile extends StatelessWidget {
  const _AudioSharingToggleTile();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (AudioSharingCubit cubit) => cubit.state.isEnabled,
    );
    return DivineSwitchTile(
      leadingIcon: DivineIconName.musicNote,
      title: context.l10n.contentPreferencesAudioSharing,
      subtitle: context.l10n.contentPreferencesAudioSharingSubtitle,
      value: isEnabled,
      onChanged: (value) => context.read<AudioSharingCubit>().setEnabled(value),
    );
  }
}

/// Opt-in unprocessed microphone capture.
///
/// iOS-only for now: it maps to the recording audio-session mode, and no
/// other platform acts on the preference yet (#7796).
class MusicModeSetting extends ConsumerWidget {
  const MusicModeSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(musicModePreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => MusicModeCubit(service: service)..load(),
      child: const _MusicModeSettingTile(),
    );
  }
}

class _MusicModeSettingTile extends StatelessWidget {
  const _MusicModeSettingTile();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (MusicModeCubit cubit) => cubit.state.isEnabled,
    );
    return DivineSwitchTile(
      leadingIcon: DivineIconName.waveform,
      title: context.l10n.contentPreferencesMusicMode,
      subtitle: context.l10n.contentPreferencesMusicModeSubtitle,
      value: isEnabled,
      onChanged: (value) => context.read<MusicModeCubit>().setEnabled(value),
    );
  }
}

class AudioDeviceSetting extends ConsumerWidget {
  const AudioDeviceSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(audioDevicePreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) {
        final cubit = AudioDeviceCubit(service: service);
        runDetached(
          cubit.load(),
          'load audio devices',
          logName: 'ContentPreferencesScreen',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: const _AudioDeviceSettingTile(),
    );
  }
}

class _AudioDeviceSettingTile extends StatelessWidget {
  const _AudioDeviceSettingTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AudioDevice>>(
      future: DivineCamera.instance.listAudioDevices(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.length <= 1) {
          return const SizedBox.shrink();
        }
        final devices = snapshot.data!;
        final currentDeviceId = context.select(
          (AudioDeviceCubit cubit) => cubit.state.currentDeviceId,
        );
        final currentDisplayName = _resolveCurrentDisplayName(
          context,
          devices: devices,
          currentDeviceId: currentDeviceId,
        );

        return ListTile(
          leading: DivineIcon(
            icon: DivineIconName.microphone,
            color: context.vineColors.accentPositive,
          ),
          title: Text(
            context.l10n.contentPreferencesAudioInputDevice,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          subtitle: Text(
            currentDisplayName,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          trailing: DivineIcon(
            icon: DivineIconName.caretRight,
            color: context.vineColors.mutedText,
          ),
          onTap: () => _showAudioDevicePicker(
            context,
            devices: devices,
            currentDeviceId: currentDeviceId,
          ),
        );
      },
    );
  }

  String _resolveCurrentDisplayName(
    BuildContext context, {
    required List<AudioDevice> devices,
    required String? currentDeviceId,
  }) {
    if (currentDeviceId == null) {
      return context.l10n.contentPreferencesAutoRecommended;
    }
    final match = devices.where((d) => d.id == currentDeviceId);
    if (match.isEmpty) {
      return context.l10n.contentPreferencesAutoRecommended;
    }
    return _formatAudioDeviceName(context, match.first.name);
  }

  Future<void> _showAudioDevicePicker(
    BuildContext context, {
    required List<AudioDevice> devices,
    required String? currentDeviceId,
  }) async {
    final cubit = context.read<AudioDeviceCubit>();
    await VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      contentTitle: context.l10n.contentPreferencesSelectAudioInput,
      children: [
        _AudioDevicePickerContent(
          devices: devices,
          currentDeviceId: currentDeviceId,
          onSelectDevice: cubit.setDeviceId,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// The audio-input rows, as a widget so each tap closes the sheet through the
/// sheet's own element rather than the settings screen's.
class _AudioDevicePickerContent extends StatelessWidget {
  const _AudioDevicePickerContent({
    required this.devices,
    required this.currentDeviceId,
    required this.onSelectDevice,
  });

  final List<AudioDevice> devices;
  final String? currentDeviceId;
  final Future<void> Function(String? deviceId) onSelectDevice;

  Future<void> _applyAndClose(BuildContext context, String? deviceId) async {
    await onSelectDevice(deviceId);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DivineSelectableRow(
          title: context.l10n.contentPreferencesAutoRecommended,
          subtitle: context.l10n.contentPreferencesAutoSelectsBest,
          isSelected: currentDeviceId == null,
          onTap: () => _applyAndClose(context, null),
        ),
        ...devices.map(
          (device) => DivineSelectableRow(
            title: _formatAudioDeviceName(context, device.name),
            subtitle: device.id,
            isSelected: currentDeviceId == device.id,
            onTap: () => _applyAndClose(context, device.id),
          ),
        ),
      ],
    );
  }
}

String _formatAudioDeviceName(BuildContext context, String name) {
  if (name.isEmpty) return context.l10n.contentPreferencesUnknownMicrophone;
  return name;
}

/// Viewer preference for translating incoming subtitles into their language.
///
/// Two rows: the target language subtitles are translated into (default: the
/// app language), and the set of source languages to leave untouched.
class SubtitleTranslationSetting extends ConsumerStatefulWidget {
  const SubtitleTranslationSetting({super.key});

  @override
  ConsumerState<SubtitleTranslationSetting> createState() =>
      _SubtitleTranslationSettingState();
}

class _SubtitleTranslationSettingState
    extends ConsumerState<SubtitleTranslationSetting> {
  String? _targetLanguage;
  Set<String> _keepOriginal = <String>{};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final service = ref.read(subtitleLanguagePreferenceServiceProvider);
    await service.initialize();
    if (!mounted) return;
    setState(() {
      _targetLanguage = service.targetLanguage;
      _keepOriginal = service.keepOriginalLanguages;
      _loaded = true;
    });
  }

  Future<void> _setTarget(String? code) async {
    final service = ref.read(subtitleLanguagePreferenceServiceProvider);
    await service.setTargetLanguage(code);
    if (!mounted) return;
    setState(() => _targetLanguage = service.targetLanguage);
  }

  Future<void> _setKeepOriginal(Set<String> languages) async {
    final service = ref.read(subtitleLanguagePreferenceServiceProvider);
    await service.setKeepOriginalLanguages(languages);
    if (!mounted) return;
    setState(() => _keepOriginal = service.keepOriginalLanguages);
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetLanguage;
    final targetSubtitle = target == null
        ? context.l10n.contentPreferencesSubtitleLanguageFollowApp
        : LanguagePreferenceService.displayNameFor(target);

    final keepSubtitle = _keepOriginal.isEmpty
        ? context.l10n.contentPreferencesSubtitleKeepOriginalNone
        : (_keepOriginal.toList()..sort())
              .map(LanguagePreferenceService.displayNameFor)
              .join(', ');

    return Column(
      children: [
        ListTile(
          leading: DivineIcon(
            icon: DivineIconName.closedCaptioning,
            color: context.vineColors.accentPositive,
          ),
          title: Text(
            context.l10n.contentPreferencesSubtitleLanguage,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          subtitle: Text(
            targetSubtitle,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          trailing: DivineIcon(
            icon: DivineIconName.caretRight,
            color: context.vineColors.mutedText,
          ),
          enabled: _loaded,
          onTap: _loaded ? () => _showTargetPicker(context) : null,
        ),
        ListTile(
          leading: DivineIcon(
            icon: DivineIconName.globe,
            color: context.vineColors.accentPositive,
          ),
          title: Text(
            context.l10n.contentPreferencesSubtitleKeepOriginal,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          subtitle: Text(
            keepSubtitle,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          trailing: DivineIcon(
            icon: DivineIconName.caretRight,
            color: context.vineColors.mutedText,
          ),
          enabled: _loaded,
          onTap: _loaded ? () => _showKeepOriginalPicker(context) : null,
        ),
      ],
    );
  }

  Future<void> _showTargetPicker(BuildContext context) async {
    await VineBottomSheet.show<void>(
      context: context,
      contentTitle: context.l10n.contentPreferencesSubtitleLanguage,
      buildScrollBody: (scrollController) => _SubtitleTargetPickerContent(
        scrollController: scrollController,
        currentTarget: _targetLanguage,
        onUseAppLanguage: () async {
          await _setTarget(null);
          if (context.mounted) Navigator.pop(context);
        },
        onSelect: (code) async {
          await _setTarget(code);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _showKeepOriginalPicker(BuildContext context) async {
    await VineBottomSheet.show<void>(
      context: context,
      contentTitle: context.l10n.contentPreferencesSubtitleKeepOriginal,
      buildScrollBody: (scrollController) => _SubtitleKeepOriginalPickerContent(
        scrollController: scrollController,
        keptLanguages: _keepOriginal,
        onChanged: _setKeepOriginal,
      ),
    );
  }
}

class _SubtitleTargetPickerContent extends StatelessWidget {
  const _SubtitleTargetPickerContent({
    required this.scrollController,
    required this.currentTarget,
    required this.onUseAppLanguage,
    required this.onSelect,
  });

  final ScrollController scrollController;
  final String? currentTarget;
  final Future<void> Function() onUseAppLanguage;
  final Future<void> Function(String code) onSelect;

  @override
  Widget build(BuildContext context) {
    final languages = LanguagePreferenceService.supportedLanguages.entries
        .toList(growable: false);
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: languages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return DivineSelectableRow(
            title: context.l10n.contentPreferencesSubtitleLanguageFollowApp,
            subtitle: LanguagePreferenceService.displayNameFor(
              PlatformDispatcher.instance.locale.languageCode,
            ),
            isSelected: currentTarget == null,
            onTap: onUseAppLanguage,
          );
        }
        final entry = languages[index - 1];
        return DivineSelectableRow(
          title: entry.value,
          subtitle: entry.key.toUpperCase(),
          isSelected: currentTarget == entry.key,
          onTap: () => onSelect(entry.key),
        );
      },
    );
  }
}

/// Multi-select list of source languages the viewer reads as-is.
///
/// Keeps its own working set so a toggle repaints immediately while the
/// preference write happens in the background.
class _SubtitleKeepOriginalPickerContent extends StatefulWidget {
  const _SubtitleKeepOriginalPickerContent({
    required this.scrollController,
    required this.keptLanguages,
    required this.onChanged,
  });

  final ScrollController scrollController;
  final Set<String> keptLanguages;
  final Future<void> Function(Set<String>) onChanged;

  @override
  State<_SubtitleKeepOriginalPickerContent> createState() =>
      _SubtitleKeepOriginalPickerContentState();
}

class _SubtitleKeepOriginalPickerContentState
    extends State<_SubtitleKeepOriginalPickerContent> {
  late final Set<String> _kept = Set<String>.from(widget.keptLanguages);

  void _toggle(String code) {
    setState(() {
      if (!_kept.add(code)) _kept.remove(code);
    });
    unawaited(widget.onChanged(Set<String>.from(_kept)));
  }

  @override
  Widget build(BuildContext context) {
    final languages = LanguagePreferenceService.supportedLanguages.entries
        .toList(growable: false);
    return ListView.builder(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      itemCount: languages.length,
      itemBuilder: (context, index) {
        final entry = languages[index];
        return DivineSelectableRow(
          title: entry.value,
          subtitle: entry.key.toUpperCase(),
          isSelected: _kept.contains(entry.key),
          onTap: () => _toggle(entry.key),
        );
      },
    );
  }
}
