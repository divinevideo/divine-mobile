import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/go_live/go_live_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/live_room_page.dart';
import 'package:openvine/screens/live/live_route_data.dart';
import 'package:openvine/widgets/user_avatar.dart';

class GoLiveView extends StatefulWidget {
  const GoLiveView({super.key});

  static const Key coverPreviewKey = Key('go_live_cover_preview');

  @override
  State<GoLiveView> createState() => _GoLiveViewState();
}

class _GoLiveViewState extends State<GoLiveView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialState = context.read<GoLiveCubit>().state;
    _titleController.text = initialState.title;
    _summaryController.text = initialState.summary;
    _imageController.text = initialState.imageUrl ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GoLiveCubit, GoLiveState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == GoLiveStatus.success,
      listener: (context, state) {
        final room = state.room;
        final session = state.session;
        if (room == null || session == null) {
          return;
        }

        context.go(
          LiveRoomPage.pathFor(room.id, session.id),
          extra: LiveRoomRouteData(
            room: room,
            session: session,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: context.vineColors.surface,
        appBar: AppBar(
          backgroundColor: context.vineColors.surface,
          leading: DivineIconButton(
            icon: DivineIconName.arrowLeft,
            tooltip: context.l10n.commonBack,
            type: DivineIconButtonType.ghostSecondary,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }

              context.go(LiveDiscoveryPage.path);
            },
          ),
          title: Text(
            context.l10n.liveGoLive,
            style: VineTheme.headlineSmallFont(
              color: context.vineColors.onSurface,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<GoLiveCubit, GoLiveState>(
            builder: (context, state) {
              return ListView(
                children: [
                  Text(
                    context.l10n.liveStartAPublicRoomInOneShot,
                    style: VineTheme.bodyLargeFont(
                      color: context.vineColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DivineAuthTextField(
                    label: context.l10n.liveRoomTitle,
                    controller: _titleController,
                    errorText: state.titleError == null
                        ? null
                        : context.l10n.liveTitleRequired,
                    onChanged: context.read<GoLiveCubit>().titleChanged,
                  ),
                  const SizedBox(height: 16),
                  DivineAuthTextField(
                    label: context.l10n.liveWhatAreYouGoingLiveAbout,
                    controller: _summaryController,
                    onChanged: context.read<GoLiveCubit>().summaryChanged,
                  ),
                  if ((state.imageUrl ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.vineColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            key: GoLiveView.coverPreviewKey,
                            imageUrl: state.imageUrl,
                            name: state.title,
                            size: 72,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.liveDefaultThumbnail,
                                  style: VineTheme.bodyLargeFont(
                                    color: context.vineColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context
                                      .l10n
                                      .liveUsingYourProfilePhotoAsTheStartingThumbnail,
                                  style: VineTheme.bodyMediumFont(
                                    color: context.vineColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DivineAuthTextField(
                    label: context.l10n.liveCoverImageURL,
                    controller: _imageController,
                    onChanged: context.read<GoLiveCubit>().imageUrlChanged,
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        context.l10n.liveStartFailed,
                        style: VineTheme.bodyMediumFont(color: VineTheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Semantics(
                    liveRegion: true,
                    value: state.status == GoLiveStatus.submitting
                        ? context.l10n.commonLoading
                        : null,
                    child: DivineButton(
                      label: context.l10n.liveStartLiveNow,
                      expanded: true,
                      isLoading: state.status == GoLiveStatus.submitting,
                      onPressed: context.read<GoLiveCubit>().submit,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
