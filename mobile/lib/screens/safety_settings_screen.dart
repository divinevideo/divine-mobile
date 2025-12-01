// ABOUTME: Safety Settings screen for content moderation and user safety controls
// ABOUTME: Provides access to blocked users, muted content, filters, and report history

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

class SafetySettingsScreen extends StatelessWidget {
  const SafetySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Settings'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      backgroundColor: Colors.black,
      body: ListView(
        children: [
          _buildSectionHeader('BLOCKED USERS'),
          _buildSectionHeader('MUTED CONTENT'),
          _buildSectionHeader('CONTENT FILTERS'),
          _buildSectionHeader('REPORT HISTORY'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: const TextStyle(
        color: VineTheme.vineGreen,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
  );
}
