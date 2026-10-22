// ABOUTME: State for FrontCameraMirrorCubit — the mirror front camera setting.

import 'package:equatable/equatable.dart';

/// State for `FrontCameraMirrorCubit`.
class FrontCameraMirrorState extends Equatable {
  const FrontCameraMirrorState({this.isEnabled = false});

  /// Whether front camera recordings are saved mirrored.
  final bool isEnabled;

  FrontCameraMirrorState copyWith({bool? isEnabled}) {
    return FrontCameraMirrorState(isEnabled: isEnabled ?? this.isEnabled);
  }

  @override
  List<Object?> get props => [isEnabled];
}
