import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/go_live/go_live_cubit.dart';
import 'package:openvine/models/live/live_role.dart';
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
            role: LiveRole.host,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: VineTheme.surfaceBackground,
        appBar: AppBar(
          backgroundColor: VineTheme.surfaceBackground,
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }

              context.go(LiveDiscoveryPage.path);
            },
          ),
          title: Text(
            'Go live',
            style: VineTheme.headlineSmallFont(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<GoLiveCubit, GoLiveState>(
            builder: (context, state) {
              return ListView(
                children: [
                  Text(
                    'Start a public room in one shot.',
                    style: VineTheme.bodyLargeFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DivineAuthTextField(
                    label: 'Room title',
                    controller: _titleController,
                    errorText: state.titleError,
                    onChanged: context.read<GoLiveCubit>().titleChanged,
                  ),
                  const SizedBox(height: 16),
                  DivineAuthTextField(
                    label: 'What are you going live about?',
                    controller: _summaryController,
                    onChanged: context.read<GoLiveCubit>().summaryChanged,
                  ),
                  if ((state.imageUrl ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: VineTheme.surfaceContainer,
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
                                  'Default thumbnail',
                                  style: VineTheme.bodyLargeFont(),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Using your profile photo as the starting thumbnail.',
                                  style: VineTheme.bodyMediumFont(
                                    color: VineTheme.onSurfaceVariant,
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
                    label: 'Cover image URL',
                    controller: _imageController,
                    onChanged: context.read<GoLiveCubit>().imageUrlChanged,
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage!,
                      style: VineTheme.bodyMediumFont(color: VineTheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  DivineButton(
                    label: 'Start live now',
                    expanded: true,
                    isLoading: state.status == GoLiveStatus.submitting,
                    onPressed: context.read<GoLiveCubit>().submit,
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
