// ABOUTME: Card widget for displaying user lists and curated video lists
// ABOUTME: Shows list metadata with proper dark theme styling

import 'package:flutter/material.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Card for displaying a user list (kind 30000 - people list)
class UserListCard extends StatelessWidget {
  const UserListCard({required this.userList, required this.onTap, super.key});

  final UserList userList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.cardBackground,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.group, color: VineTheme.vineGreen, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userList.name,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (userList.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            userList.description!,
                            style: TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: VineTheme.secondaryText),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${userList.pubkeys.length} ${userList.pubkeys.length == 1 ? 'person' : 'people'}',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for displaying a curated video list (kind 30005)
class CuratedListCard extends StatelessWidget {
  const CuratedListCard({
    required this.curatedList,
    required this.onTap,
    super.key,
  });

  final CuratedList curatedList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.cardBackground,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.video_library,
                    color: VineTheme.vineGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          curatedList.name,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (curatedList.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            curatedList.description!,
                            style: TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: VineTheme.secondaryText),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${curatedList.videoEventIds.length} ${curatedList.videoEventIds.length == 1 ? 'video' : 'videos'}',
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  if (curatedList.tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        curatedList.tags.take(3).map((t) => '#$t').join(' '),
                        style: TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
