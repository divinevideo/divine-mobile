// ABOUTME: ProofMode information panel showing verification details and user explanation
// ABOUTME: Displays human activity analysis, device attestation, and ProofMode benefits

import 'package:flutter/material.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_human_detection.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Info panel explaining ProofMode verification and showing proof details
class ProofModeInfoPanel extends StatefulWidget {
  const ProofModeInfoPanel({
    super.key,
    required this.manifest,
  });

  final ProofManifest manifest;

  @override
  State<ProofModeInfoPanel> createState() => _ProofModeInfoPanelState();
}

class _ProofModeInfoPanelState extends State<ProofModeInfoPanel> {
  bool _isExpanded = false;
  HumanActivityAnalysis? _humanAnalysis;

  @override
  void initState() {
    super.initState();
    _analyzeHumanActivity();
  }

  void _analyzeHumanActivity() {
    try {
      _humanAnalysis = ProofModeHumanDetection.validateRecordingSession(
        widget.manifest,
      );
      Log.debug('Human activity analysis: ${_humanAnalysis?.toJson()}',
          name: 'ProofModeInfoPanel', category: LogCategory.auth);
    } catch (e) {
      Log.error('Failed to analyze human activity: $e',
          name: 'ProofModeInfoPanel', category: LogCategory.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade700, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.verified_user,
                      color: Colors.green.shade400,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ProofMode Enabled',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cryptographic proof of authenticity',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (_isExpanded) ...[
            const Divider(color: Colors.grey, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // What is ProofMode section
                  _buildSectionHeader('What is ProofMode?'),
                  const SizedBox(height: 8),
                  _buildInfoText(
                    'ProofMode creates cryptographic proof that your video is:',
                  ),
                  const SizedBox(height: 8),
                  _buildBulletPoint('Recorded by a real human, not a bot'),
                  _buildBulletPoint('Captured on this specific device'),
                  _buildBulletPoint('Not edited or manipulated after recording'),
                  _buildBulletPoint('Created at the claimed time'),
                  const SizedBox(height: 16),

                  // Verification details
                  _buildSectionHeader('Verification Details'),
                  const SizedBox(height: 8),
                  _buildVerificationItem(
                    'Session Duration',
                    '${widget.manifest.totalDuration.inSeconds}s',
                    Icons.timer,
                  ),
                  _buildVerificationItem(
                    'Recording Segments',
                    '${widget.manifest.segments.length}',
                    Icons.video_library,
                  ),
                  _buildVerificationItem(
                    'User Interactions',
                    '${widget.manifest.interactions.length}',
                    Icons.touch_app,
                  ),

                  // Human activity analysis
                  if (_humanAnalysis != null) ...[
                    const SizedBox(height: 12),
                    _buildHumanActivitySection(_humanAnalysis!),
                  ],

                  // Device attestation
                  if (widget.manifest.deviceAttestation != null) ...[
                    const SizedBox(height: 12),
                    _buildVerificationItem(
                      'Device Attestation',
                      widget.manifest.deviceAttestation!.isHardwareBacked
                          ? 'Hardware-backed'
                          : 'Software',
                      Icons.security,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // What viewers see section
                  _buildSectionHeader('What Viewers See'),
                  const SizedBox(height: 8),
                  _buildInfoText(
                    'Your video will display a verification badge showing viewers that:',
                  ),
                  const SizedBox(height: 8),
                  _buildBulletPoint('This is authentic, unedited content'),
                  _buildBulletPoint('Created by a verified human'),
                  _buildBulletPoint('Protected by cryptographic proof'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[300],
        fontSize: 13,
        height: 1.4,
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade400, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumanActivitySection(HumanActivityAnalysis analysis) {
    final color = analysis.isHumanLikely ? Colors.green : Colors.orange;
    final icon = analysis.isHumanLikely ? Icons.check_circle : Icons.warning;
    final status = analysis.isHumanLikely ? 'Human Verified' : 'Analyzing';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(analysis.confidenceScore * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (analysis.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...analysis.reasons.map((reason) => Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 2),
                  child: Text(
                    '• $reason',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 11,
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
