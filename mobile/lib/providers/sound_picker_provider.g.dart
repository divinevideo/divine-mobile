// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sound_picker_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SoundPicker)
const soundPickerProvider = SoundPickerProvider._();

final class SoundPickerProvider
    extends $NotifierProvider<SoundPicker, SoundPickerState> {
  const SoundPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundPickerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundPickerHash();

  @$internal
  @override
  SoundPicker create() => SoundPicker();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoundPickerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoundPickerState>(value),
    );
  }
}

String _$soundPickerHash() => r'72c8449915b53bb8182ba0dac0eb21775edeb34c';

abstract class _$SoundPicker extends $Notifier<SoundPickerState> {
  SoundPickerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SoundPickerState, SoundPickerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SoundPickerState, SoundPickerState>,
              SoundPickerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
