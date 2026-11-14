// ABOUTME: Scopes shared link state to the header and its copy/share actions.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_link/profile_link_cubit.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/utils/profile_link_resolver.dart';
import 'package:profile_repository/profile_repository.dart';

class ProfileLinkScope extends ConsumerWidget {
  const ProfileLinkScope({
    required this.pubkey,
    required this.profile,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final String pubkey;
  final UserProfile? profile;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ProfileLinkOwner(
      pubkey: pubkey,
      profile: profile,
      enabled: enabled,
      repository: ref.watch(profileReadRepositoryProvider),
      resolver: profileLinkResolverFor(ref),
      child: child,
    );
  }
}

class _ProfileLinkOwner extends StatefulWidget {
  const _ProfileLinkOwner({
    required this.pubkey,
    required this.profile,
    required this.enabled,
    required this.repository,
    required this.resolver,
    required this.child,
  });

  final String pubkey;
  final UserProfile? profile;
  final bool enabled;

  /// Compared by identity only: a rebuilt repository re-resolves the link.
  final ProfileReader? repository;
  final ProfileLinkResolver resolver;
  final Widget child;

  @override
  State<_ProfileLinkOwner> createState() => _ProfileLinkOwnerState();
}

class _ProfileLinkOwnerState extends State<_ProfileLinkOwner> {
  late ProfileLinkCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = _createCubit();
    _load();
  }

  @override
  void didUpdateWidget(_ProfileLinkOwner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Swap the cubit instead of keying this widget: a key would remount the
    // whole profile header below it and re-run every descendant's initState.
    if (widget.pubkey != oldWidget.pubkey ||
        widget.enabled != oldWidget.enabled ||
        !identical(widget.repository, oldWidget.repository)) {
      unawaited(_cubit.close());
      _cubit = _createCubit();
    }
    _load();
  }

  ProfileLinkCubit _createCubit() => ProfileLinkCubit(
    resolver: widget.resolver,
    pubkey: widget.pubkey,
    profile: widget.profile,
  );

  void _load() {
    if (widget.enabled) {
      unawaited(_cubit.load(pubkey: widget.pubkey, profile: widget.profile));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: widget.child);
}
