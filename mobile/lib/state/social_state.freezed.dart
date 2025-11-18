// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SocialState {

// Like-related state
 Set<String> get likedEventIds; Map<String, int> get likeCounts;// NEW likes from Nostr only (add to originalLikes for total)
 Map<String, String> get likeEventIdToReactionId;// Comment-related state
 Map<String, int> get commentCounts;// NEW comments from Nostr only (add to originalComments for total)
// Repost-related state
 Set<String> get repostedEventIds; Map<String, String> get repostEventIdToRepostId;// Follow-related state
 List<String> get followingPubkeys; Map<String, Map<String, int>> get followerStats; Event? get currentUserContactListEvent;// Loading and error state
 bool get isLoading; bool get isInitialized; String? get error;// Operation-specific loading states
 Set<String> get likesInProgress; Set<String> get repostsInProgress; Set<String> get followsInProgress;
/// Create a copy of SocialState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SocialStateCopyWith<SocialState> get copyWith => _$SocialStateCopyWithImpl<SocialState>(this as SocialState, _$identity);

  /// Serializes this SocialState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SocialState&&const DeepCollectionEquality().equals(other.likedEventIds, likedEventIds)&&const DeepCollectionEquality().equals(other.likeCounts, likeCounts)&&const DeepCollectionEquality().equals(other.likeEventIdToReactionId, likeEventIdToReactionId)&&const DeepCollectionEquality().equals(other.commentCounts, commentCounts)&&const DeepCollectionEquality().equals(other.repostedEventIds, repostedEventIds)&&const DeepCollectionEquality().equals(other.repostEventIdToRepostId, repostEventIdToRepostId)&&const DeepCollectionEquality().equals(other.followingPubkeys, followingPubkeys)&&const DeepCollectionEquality().equals(other.followerStats, followerStats)&&(identical(other.currentUserContactListEvent, currentUserContactListEvent) || other.currentUserContactListEvent == currentUserContactListEvent)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.likesInProgress, likesInProgress)&&const DeepCollectionEquality().equals(other.repostsInProgress, repostsInProgress)&&const DeepCollectionEquality().equals(other.followsInProgress, followsInProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(likedEventIds),const DeepCollectionEquality().hash(likeCounts),const DeepCollectionEquality().hash(likeEventIdToReactionId),const DeepCollectionEquality().hash(commentCounts),const DeepCollectionEquality().hash(repostedEventIds),const DeepCollectionEquality().hash(repostEventIdToRepostId),const DeepCollectionEquality().hash(followingPubkeys),const DeepCollectionEquality().hash(followerStats),currentUserContactListEvent,isLoading,isInitialized,error,const DeepCollectionEquality().hash(likesInProgress),const DeepCollectionEquality().hash(repostsInProgress),const DeepCollectionEquality().hash(followsInProgress));

@override
String toString() {
  return 'SocialState(likedEventIds: $likedEventIds, likeCounts: $likeCounts, likeEventIdToReactionId: $likeEventIdToReactionId, commentCounts: $commentCounts, repostedEventIds: $repostedEventIds, repostEventIdToRepostId: $repostEventIdToRepostId, followingPubkeys: $followingPubkeys, followerStats: $followerStats, currentUserContactListEvent: $currentUserContactListEvent, isLoading: $isLoading, isInitialized: $isInitialized, error: $error, likesInProgress: $likesInProgress, repostsInProgress: $repostsInProgress, followsInProgress: $followsInProgress)';
}


}

/// @nodoc
abstract mixin class $SocialStateCopyWith<$Res>  {
  factory $SocialStateCopyWith(SocialState value, $Res Function(SocialState) _then) = _$SocialStateCopyWithImpl;
@useResult
$Res call({
 Set<String> likedEventIds, Map<String, int> likeCounts, Map<String, String> likeEventIdToReactionId, Map<String, int> commentCounts, Set<String> repostedEventIds, Map<String, String> repostEventIdToRepostId, List<String> followingPubkeys, Map<String, Map<String, int>> followerStats, Event? currentUserContactListEvent, bool isLoading, bool isInitialized, String? error, Set<String> likesInProgress, Set<String> repostsInProgress, Set<String> followsInProgress
});




}
/// @nodoc
class _$SocialStateCopyWithImpl<$Res>
    implements $SocialStateCopyWith<$Res> {
  _$SocialStateCopyWithImpl(this._self, this._then);

  final SocialState _self;
  final $Res Function(SocialState) _then;

/// Create a copy of SocialState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? likedEventIds = null,Object? likeCounts = null,Object? likeEventIdToReactionId = null,Object? commentCounts = null,Object? repostedEventIds = null,Object? repostEventIdToRepostId = null,Object? followingPubkeys = null,Object? followerStats = null,Object? currentUserContactListEvent = freezed,Object? isLoading = null,Object? isInitialized = null,Object? error = freezed,Object? likesInProgress = null,Object? repostsInProgress = null,Object? followsInProgress = null,}) {
  return _then(_self.copyWith(
likedEventIds: null == likedEventIds ? _self.likedEventIds : likedEventIds // ignore: cast_nullable_to_non_nullable
as Set<String>,likeCounts: null == likeCounts ? _self.likeCounts : likeCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,likeEventIdToReactionId: null == likeEventIdToReactionId ? _self.likeEventIdToReactionId : likeEventIdToReactionId // ignore: cast_nullable_to_non_nullable
as Map<String, String>,commentCounts: null == commentCounts ? _self.commentCounts : commentCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,repostedEventIds: null == repostedEventIds ? _self.repostedEventIds : repostedEventIds // ignore: cast_nullable_to_non_nullable
as Set<String>,repostEventIdToRepostId: null == repostEventIdToRepostId ? _self.repostEventIdToRepostId : repostEventIdToRepostId // ignore: cast_nullable_to_non_nullable
as Map<String, String>,followingPubkeys: null == followingPubkeys ? _self.followingPubkeys : followingPubkeys // ignore: cast_nullable_to_non_nullable
as List<String>,followerStats: null == followerStats ? _self.followerStats : followerStats // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, int>>,currentUserContactListEvent: freezed == currentUserContactListEvent ? _self.currentUserContactListEvent : currentUserContactListEvent // ignore: cast_nullable_to_non_nullable
as Event?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,likesInProgress: null == likesInProgress ? _self.likesInProgress : likesInProgress // ignore: cast_nullable_to_non_nullable
as Set<String>,repostsInProgress: null == repostsInProgress ? _self.repostsInProgress : repostsInProgress // ignore: cast_nullable_to_non_nullable
as Set<String>,followsInProgress: null == followsInProgress ? _self.followsInProgress : followsInProgress // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SocialState].
extension SocialStatePatterns on SocialState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SocialState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SocialState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SocialState value)  $default,){
final _that = this;
switch (_that) {
case _SocialState():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SocialState value)?  $default,){
final _that = this;
switch (_that) {
case _SocialState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<String> likedEventIds,  Map<String, int> likeCounts,  Map<String, String> likeEventIdToReactionId,  Map<String, int> commentCounts,  Set<String> repostedEventIds,  Map<String, String> repostEventIdToRepostId,  List<String> followingPubkeys,  Map<String, Map<String, int>> followerStats,  Event? currentUserContactListEvent,  bool isLoading,  bool isInitialized,  String? error,  Set<String> likesInProgress,  Set<String> repostsInProgress,  Set<String> followsInProgress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SocialState() when $default != null:
return $default(_that.likedEventIds,_that.likeCounts,_that.likeEventIdToReactionId,_that.commentCounts,_that.repostedEventIds,_that.repostEventIdToRepostId,_that.followingPubkeys,_that.followerStats,_that.currentUserContactListEvent,_that.isLoading,_that.isInitialized,_that.error,_that.likesInProgress,_that.repostsInProgress,_that.followsInProgress);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<String> likedEventIds,  Map<String, int> likeCounts,  Map<String, String> likeEventIdToReactionId,  Map<String, int> commentCounts,  Set<String> repostedEventIds,  Map<String, String> repostEventIdToRepostId,  List<String> followingPubkeys,  Map<String, Map<String, int>> followerStats,  Event? currentUserContactListEvent,  bool isLoading,  bool isInitialized,  String? error,  Set<String> likesInProgress,  Set<String> repostsInProgress,  Set<String> followsInProgress)  $default,) {final _that = this;
switch (_that) {
case _SocialState():
return $default(_that.likedEventIds,_that.likeCounts,_that.likeEventIdToReactionId,_that.commentCounts,_that.repostedEventIds,_that.repostEventIdToRepostId,_that.followingPubkeys,_that.followerStats,_that.currentUserContactListEvent,_that.isLoading,_that.isInitialized,_that.error,_that.likesInProgress,_that.repostsInProgress,_that.followsInProgress);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<String> likedEventIds,  Map<String, int> likeCounts,  Map<String, String> likeEventIdToReactionId,  Map<String, int> commentCounts,  Set<String> repostedEventIds,  Map<String, String> repostEventIdToRepostId,  List<String> followingPubkeys,  Map<String, Map<String, int>> followerStats,  Event? currentUserContactListEvent,  bool isLoading,  bool isInitialized,  String? error,  Set<String> likesInProgress,  Set<String> repostsInProgress,  Set<String> followsInProgress)?  $default,) {final _that = this;
switch (_that) {
case _SocialState() when $default != null:
return $default(_that.likedEventIds,_that.likeCounts,_that.likeEventIdToReactionId,_that.commentCounts,_that.repostedEventIds,_that.repostEventIdToRepostId,_that.followingPubkeys,_that.followerStats,_that.currentUserContactListEvent,_that.isLoading,_that.isInitialized,_that.error,_that.likesInProgress,_that.repostsInProgress,_that.followsInProgress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SocialState extends SocialState {
  const _SocialState({final  Set<String> likedEventIds = const {}, final  Map<String, int> likeCounts = const {}, final  Map<String, String> likeEventIdToReactionId = const {}, final  Map<String, int> commentCounts = const {}, final  Set<String> repostedEventIds = const {}, final  Map<String, String> repostEventIdToRepostId = const {}, final  List<String> followingPubkeys = const [], final  Map<String, Map<String, int>> followerStats = const {}, this.currentUserContactListEvent, this.isLoading = false, this.isInitialized = false, this.error, final  Set<String> likesInProgress = const {}, final  Set<String> repostsInProgress = const {}, final  Set<String> followsInProgress = const {}}): _likedEventIds = likedEventIds,_likeCounts = likeCounts,_likeEventIdToReactionId = likeEventIdToReactionId,_commentCounts = commentCounts,_repostedEventIds = repostedEventIds,_repostEventIdToRepostId = repostEventIdToRepostId,_followingPubkeys = followingPubkeys,_followerStats = followerStats,_likesInProgress = likesInProgress,_repostsInProgress = repostsInProgress,_followsInProgress = followsInProgress,super._();
  factory _SocialState.fromJson(Map<String, dynamic> json) => _$SocialStateFromJson(json);

// Like-related state
 final  Set<String> _likedEventIds;
// Like-related state
@override@JsonKey() Set<String> get likedEventIds {
  if (_likedEventIds is EqualUnmodifiableSetView) return _likedEventIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_likedEventIds);
}

 final  Map<String, int> _likeCounts;
@override@JsonKey() Map<String, int> get likeCounts {
  if (_likeCounts is EqualUnmodifiableMapView) return _likeCounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_likeCounts);
}

// NEW likes from Nostr only (add to originalLikes for total)
 final  Map<String, String> _likeEventIdToReactionId;
// NEW likes from Nostr only (add to originalLikes for total)
@override@JsonKey() Map<String, String> get likeEventIdToReactionId {
  if (_likeEventIdToReactionId is EqualUnmodifiableMapView) return _likeEventIdToReactionId;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_likeEventIdToReactionId);
}

// Comment-related state
 final  Map<String, int> _commentCounts;
// Comment-related state
@override@JsonKey() Map<String, int> get commentCounts {
  if (_commentCounts is EqualUnmodifiableMapView) return _commentCounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_commentCounts);
}

// NEW comments from Nostr only (add to originalComments for total)
// Repost-related state
 final  Set<String> _repostedEventIds;
// NEW comments from Nostr only (add to originalComments for total)
// Repost-related state
@override@JsonKey() Set<String> get repostedEventIds {
  if (_repostedEventIds is EqualUnmodifiableSetView) return _repostedEventIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_repostedEventIds);
}

 final  Map<String, String> _repostEventIdToRepostId;
@override@JsonKey() Map<String, String> get repostEventIdToRepostId {
  if (_repostEventIdToRepostId is EqualUnmodifiableMapView) return _repostEventIdToRepostId;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_repostEventIdToRepostId);
}

// Follow-related state
 final  List<String> _followingPubkeys;
// Follow-related state
@override@JsonKey() List<String> get followingPubkeys {
  if (_followingPubkeys is EqualUnmodifiableListView) return _followingPubkeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_followingPubkeys);
}

 final  Map<String, Map<String, int>> _followerStats;
@override@JsonKey() Map<String, Map<String, int>> get followerStats {
  if (_followerStats is EqualUnmodifiableMapView) return _followerStats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_followerStats);
}

@override final  Event? currentUserContactListEvent;
// Loading and error state
@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool isInitialized;
@override final  String? error;
// Operation-specific loading states
 final  Set<String> _likesInProgress;
// Operation-specific loading states
@override@JsonKey() Set<String> get likesInProgress {
  if (_likesInProgress is EqualUnmodifiableSetView) return _likesInProgress;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_likesInProgress);
}

 final  Set<String> _repostsInProgress;
@override@JsonKey() Set<String> get repostsInProgress {
  if (_repostsInProgress is EqualUnmodifiableSetView) return _repostsInProgress;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_repostsInProgress);
}

 final  Set<String> _followsInProgress;
@override@JsonKey() Set<String> get followsInProgress {
  if (_followsInProgress is EqualUnmodifiableSetView) return _followsInProgress;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_followsInProgress);
}


/// Create a copy of SocialState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SocialStateCopyWith<_SocialState> get copyWith => __$SocialStateCopyWithImpl<_SocialState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SocialStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SocialState&&const DeepCollectionEquality().equals(other._likedEventIds, _likedEventIds)&&const DeepCollectionEquality().equals(other._likeCounts, _likeCounts)&&const DeepCollectionEquality().equals(other._likeEventIdToReactionId, _likeEventIdToReactionId)&&const DeepCollectionEquality().equals(other._commentCounts, _commentCounts)&&const DeepCollectionEquality().equals(other._repostedEventIds, _repostedEventIds)&&const DeepCollectionEquality().equals(other._repostEventIdToRepostId, _repostEventIdToRepostId)&&const DeepCollectionEquality().equals(other._followingPubkeys, _followingPubkeys)&&const DeepCollectionEquality().equals(other._followerStats, _followerStats)&&(identical(other.currentUserContactListEvent, currentUserContactListEvent) || other.currentUserContactListEvent == currentUserContactListEvent)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other._likesInProgress, _likesInProgress)&&const DeepCollectionEquality().equals(other._repostsInProgress, _repostsInProgress)&&const DeepCollectionEquality().equals(other._followsInProgress, _followsInProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_likedEventIds),const DeepCollectionEquality().hash(_likeCounts),const DeepCollectionEquality().hash(_likeEventIdToReactionId),const DeepCollectionEquality().hash(_commentCounts),const DeepCollectionEquality().hash(_repostedEventIds),const DeepCollectionEquality().hash(_repostEventIdToRepostId),const DeepCollectionEquality().hash(_followingPubkeys),const DeepCollectionEquality().hash(_followerStats),currentUserContactListEvent,isLoading,isInitialized,error,const DeepCollectionEquality().hash(_likesInProgress),const DeepCollectionEquality().hash(_repostsInProgress),const DeepCollectionEquality().hash(_followsInProgress));

@override
String toString() {
  return 'SocialState(likedEventIds: $likedEventIds, likeCounts: $likeCounts, likeEventIdToReactionId: $likeEventIdToReactionId, commentCounts: $commentCounts, repostedEventIds: $repostedEventIds, repostEventIdToRepostId: $repostEventIdToRepostId, followingPubkeys: $followingPubkeys, followerStats: $followerStats, currentUserContactListEvent: $currentUserContactListEvent, isLoading: $isLoading, isInitialized: $isInitialized, error: $error, likesInProgress: $likesInProgress, repostsInProgress: $repostsInProgress, followsInProgress: $followsInProgress)';
}


}

/// @nodoc
abstract mixin class _$SocialStateCopyWith<$Res> implements $SocialStateCopyWith<$Res> {
  factory _$SocialStateCopyWith(_SocialState value, $Res Function(_SocialState) _then) = __$SocialStateCopyWithImpl;
@override @useResult
$Res call({
 Set<String> likedEventIds, Map<String, int> likeCounts, Map<String, String> likeEventIdToReactionId, Map<String, int> commentCounts, Set<String> repostedEventIds, Map<String, String> repostEventIdToRepostId, List<String> followingPubkeys, Map<String, Map<String, int>> followerStats, Event? currentUserContactListEvent, bool isLoading, bool isInitialized, String? error, Set<String> likesInProgress, Set<String> repostsInProgress, Set<String> followsInProgress
});




}
/// @nodoc
class __$SocialStateCopyWithImpl<$Res>
    implements _$SocialStateCopyWith<$Res> {
  __$SocialStateCopyWithImpl(this._self, this._then);

  final _SocialState _self;
  final $Res Function(_SocialState) _then;

/// Create a copy of SocialState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? likedEventIds = null,Object? likeCounts = null,Object? likeEventIdToReactionId = null,Object? commentCounts = null,Object? repostedEventIds = null,Object? repostEventIdToRepostId = null,Object? followingPubkeys = null,Object? followerStats = null,Object? currentUserContactListEvent = freezed,Object? isLoading = null,Object? isInitialized = null,Object? error = freezed,Object? likesInProgress = null,Object? repostsInProgress = null,Object? followsInProgress = null,}) {
  return _then(_SocialState(
likedEventIds: null == likedEventIds ? _self._likedEventIds : likedEventIds // ignore: cast_nullable_to_non_nullable
as Set<String>,likeCounts: null == likeCounts ? _self._likeCounts : likeCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,likeEventIdToReactionId: null == likeEventIdToReactionId ? _self._likeEventIdToReactionId : likeEventIdToReactionId // ignore: cast_nullable_to_non_nullable
as Map<String, String>,commentCounts: null == commentCounts ? _self._commentCounts : commentCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,repostedEventIds: null == repostedEventIds ? _self._repostedEventIds : repostedEventIds // ignore: cast_nullable_to_non_nullable
as Set<String>,repostEventIdToRepostId: null == repostEventIdToRepostId ? _self._repostEventIdToRepostId : repostEventIdToRepostId // ignore: cast_nullable_to_non_nullable
as Map<String, String>,followingPubkeys: null == followingPubkeys ? _self._followingPubkeys : followingPubkeys // ignore: cast_nullable_to_non_nullable
as List<String>,followerStats: null == followerStats ? _self._followerStats : followerStats // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, int>>,currentUserContactListEvent: freezed == currentUserContactListEvent ? _self.currentUserContactListEvent : currentUserContactListEvent // ignore: cast_nullable_to_non_nullable
as Event?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,likesInProgress: null == likesInProgress ? _self._likesInProgress : likesInProgress // ignore: cast_nullable_to_non_nullable
as Set<String>,repostsInProgress: null == repostsInProgress ? _self._repostsInProgress : repostsInProgress // ignore: cast_nullable_to_non_nullable
as Set<String>,followsInProgress: null == followsInProgress ? _self._followsInProgress : followsInProgress // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
