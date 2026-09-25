import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Defers closing a profile tab bloc while a fullscreen feed is using it.
///
/// The profile grid owns the bloc, but a pushed feed may outlive a grid rebuild
/// that replaces the bloc's captured repositories. The grid releases its
/// ownership when it replaces/disposes the bloc; each feed lease releases when
/// its route returns.
class ProfileTabBlocLifetime {
  ProfileTabBlocLifetime({
    required BlocBase<Object?> bloc,
    required void Function(Future<void> close) observeClose,
  }) : _bloc = bloc,
       _observeClose = observeClose;

  final BlocBase<Object?> _bloc;
  final void Function(Future<void> close) _observeClose;

  int _leases = 0;
  bool _ownerReleased = false;
  bool _closed = false;

  /// Retains the bloc until the returned callback is invoked.
  VoidCallback acquire() {
    if (_ownerReleased) {
      throw StateError('Cannot retain a released profile tab bloc.');
    }

    _leases++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _leases--;
      _closeWhenUnused();
    };
  }

  /// Releases the profile grid's ownership of the bloc.
  void releaseOwner() {
    if (_ownerReleased) return;
    _ownerReleased = true;
    _closeWhenUnused();
  }

  void _closeWhenUnused() {
    if (!_ownerReleased || _leases != 0 || _closed) return;
    _closed = true;
    _observeClose(_bloc.close());
  }
}
