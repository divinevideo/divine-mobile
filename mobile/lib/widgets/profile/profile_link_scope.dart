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
    final repository = ref.watch(profileReadRepositoryProvider);
    return _ProfileLinkOwner(
      key: ValueKey((pubkey, repository, enabled)),
      pubkey: pubkey,
      profile: profile,
      enabled: enabled,
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
    required this.resolver,
    required this.child,
    super.key,
  });

  final String pubkey;
  final UserProfile? profile;
  final bool enabled;
  final ProfileLinkResolver resolver;
  final Widget child;

  @override
  State<_ProfileLinkOwner> createState() => _ProfileLinkOwnerState();
}

class _ProfileLinkOwnerState extends State<_ProfileLinkOwner> {
  late final ProfileLinkCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ProfileLinkCubit(
      resolver: widget.resolver,
      pubkey: widget.pubkey,
      profile: widget.profile,
    );
    _load();
  }

  @override
  void didUpdateWidget(_ProfileLinkOwner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

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
