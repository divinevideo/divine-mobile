import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/go_live/go_live_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/screens/live/go_live_view.dart';

class GoLivePage extends ConsumerStatefulWidget {
  const GoLivePage({super.key});

  static const String routeName = 'goLive';
  static const String path = '/live/go';

  @override
  ConsumerState<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends ConsumerState<GoLivePage> {
  late final String _currentUserPubkey;
  late final Future<_GoLivePrefill> _prefillFuture;

  @override
  void initState() {
    super.initState();
    _currentUserPubkey =
        ref.read(authServiceProvider).currentPublicKeyHex ?? '';
    _prefillFuture = _loadPrefill();
  }

  Future<_GoLivePrefill> _loadPrefill() async {
    if (_currentUserPubkey.isEmpty) {
      return _GoLivePrefill.empty;
    }

    final profileRepository = ref.read(profileRepositoryProvider);
    if (profileRepository == null) {
      return _GoLivePrefill.empty;
    }

    final profile = await profileRepository.getCachedProfile(
      pubkey: _currentUserPubkey,
    );
    return _GoLivePrefill.fromProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GoLivePrefill>(
      future: _prefillFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: VineTheme.surfaceBackground,
            appBar: AppBar(
              backgroundColor: VineTheme.surfaceBackground,
              title: Text(
                'Go live',
                style: VineTheme.headlineSmallFont(),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final prefill = snapshot.data ?? _GoLivePrefill.empty;

        return BlocProvider(
          create: (_) => GoLiveCubit(
            liveApiService: ref.watch(liveApiServiceProvider),
            liveRepository: ref.watch(liveRepositoryProvider),
            currentUserPubkey: _currentUserPubkey,
            initialTitle: prefill.title,
            initialSummary: prefill.summary,
            initialImageUrl: prefill.imageUrl,
          ),
          child: const GoLiveView(),
        );
      },
    );
  }
}

class _GoLivePrefill {
  const _GoLivePrefill({
    this.title = '',
    this.summary = '',
    this.imageUrl,
  });

  static const _GoLivePrefill empty = _GoLivePrefill();

  final String title;
  final String summary;
  final String? imageUrl;

  factory _GoLivePrefill.fromProfile(UserProfile? profile) {
    if (profile == null) {
      return empty;
    }

    final displayName = profile.bestDisplayName;
    return _GoLivePrefill(
      title: '$displayName is live',
      summary: 'Come hang out with $displayName live on Divine.',
      imageUrl: _normalizeImageUrl(profile.picture),
    );
  }

  static String? _normalizeImageUrl(String? imageUrl) {
    final trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
