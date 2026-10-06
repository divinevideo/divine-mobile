import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';

enum GoLiveStatus { initial, submitting, success, failure }

class GoLiveState extends Equatable {
  const GoLiveState({
    this.status = GoLiveStatus.initial,
    this.title = '',
    this.summary = '',
    this.imageUrl,
    this.room,
    this.session,
    this.titleError,
    this.errorMessage,
  });

  final GoLiveStatus status;
  final String title;
  final String summary;
  final String? imageUrl;
  final LiveRoom? room;
  final LiveSession? session;
  final String? titleError;
  final String? errorMessage;

  bool get isValid => title.trim().isNotEmpty;

  GoLiveState copyWith({
    GoLiveStatus? status,
    String? title,
    String? summary,
    String? imageUrl,
    bool clearImageUrl = false,
    LiveRoom? room,
    LiveSession? session,
    String? titleError,
    bool clearTitleError = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return GoLiveState(
      status: status ?? this.status,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      room: room ?? this.room,
      session: session ?? this.session,
      titleError: clearTitleError ? null : (titleError ?? this.titleError),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
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
    errorMessage,
  ];
}
