// ABOUTME: Tracks short-link loading and retry while discarding obsolete lookup results.
import 'package:bloc/bloc.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/services/short_link_resolver.dart';

sealed class ShortLinkState {
  const ShortLinkState();
}

class ShortLinkLoading extends ShortLinkState {
  const ShortLinkLoading();
}

class ShortLinkReady extends ShortLinkState {
  const ShortLinkReady(this.link);
  final DeepLink link;
}

class ShortLinkFailed extends ShortLinkState {
  const ShortLinkFailed();
}

class ShortLinkCubit extends Cubit<ShortLinkState> {
  ShortLinkCubit(this._resolver) : super(const ShortLinkLoading());
  final ShortLinkResolver _resolver;
  int _generation = 0;

  Future<void> resolve(Uri uri) async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(const ShortLinkLoading());
    try {
      final link = await _resolver.resolve(uri);
      if (!isClosed && generation == _generation) emit(ShortLinkReady(link));
    } on ShortLinkResolutionException {
      if (!isClosed && generation == _generation) emit(const ShortLinkFailed());
    }
  }
}
