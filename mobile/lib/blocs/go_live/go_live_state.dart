import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';

enum GoLiveStatus { initial, submitting, success, failure }

enum GoLiveTitleError { required }

enum GoLiveError { startFailed }

class GoLiveState extends Equatable {
  const GoLiveState({
    this.status = GoLiveStatus.initial,
    this.title = '',
    this.summary = '',
    this.imageUrl,
    this.room,
    this.session,
    this.titleError,
    this.error,
  });

  final GoLiveStatus status;
  final String title;
  final String summary;
  final String? imageUrl;
  final LiveRoom? room;
  final LiveSession? session;
  final GoLiveTitleError? titleError;
  final GoLiveError? error;

  bool get isValid => title.trim().isNotEmpty;

  GoLiveState copyWith({
    GoLiveStatus? status,
    String? title,
    String? summary,
    String? imageUrl,
    bool clearImageUrl = false,
    LiveRoom? room,
    LiveSession? session,
    GoLiveTitleError? titleError,
    bool clearTitleError = false,
    GoLiveError? error,
    bool clearError = false,
  }) {
    return GoLiveState(
      status: status ?? this.status,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      room: room ?? this.room,
      session: session ?? this.session,
      titleError: clearTitleError ? null : (titleError ?? this.titleError),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    title,
    summary,
    imageUrl,
    room,
    session,
    titleError,
    error,
  ];
}
