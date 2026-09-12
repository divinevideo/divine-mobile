import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owns the user's appearance selection and applies it for the current run.
class AppearanceCubit extends Cubit<AppearanceMode> {
  AppearanceCubit(this._repository) : super(defaultAppearanceMode);

  final AppearanceRepository _repository;

  Future<void> load() async {
    try {
      emit(await _repository.load());
    } catch (error) {
      Log.warning(
        'Failed to load appearance preference: $error',
        name: 'AppearanceCubit',
        category: LogCategory.system,
      );
    }
  }

  Future<void> setMode(AppearanceMode mode) async {
    emit(mode);
    try {
      await _repository.save(mode);
    } catch (error) {
      Log.warning(
        'Failed to persist appearance preference: $error',
        name: 'AppearanceCubit',
        category: LogCategory.system,
      );
    }
  }
}

/// Maps the user's [AppearanceMode] choice onto the [ThemeMode] the root
/// `MaterialApp` consumes.
ThemeMode resolveThemeMode({required AppearanceMode mode}) => switch (mode) {
  AppearanceMode.system => ThemeMode.system,
  AppearanceMode.light => ThemeMode.light,
  AppearanceMode.dark => ThemeMode.dark,
};
