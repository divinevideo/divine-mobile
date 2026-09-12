// ABOUTME: Diagnostic screen for debugging relay connectivity issues
// ABOUTME: Shows relay connection status, network health, Blossom, and FunnelCake API

import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart' show RelayState;
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result for a single FunnelCake API endpoint test
class FunnelCakeEndpointResult {
  FunnelCakeEndpointResult({
    required this.endpoint,
    required this.isSuccess,
    this.latencyMs,
    this.count,
    this.errorMessage,
    this.details,
  });

  final String endpoint;
  final bool isSuccess;
  final int? latencyMs;
  final int? count;
  final String? errorMessage;
  final String? details;
}

/// Comprehensive FunnelCake API test results
class FunnelCakeTestResults {
  FunnelCakeTestResults({required this.apiBaseUrl, required this.endpoints});

  final String apiBaseUrl;
  final List<FunnelCakeEndpointResult> endpoints;

  int get successCount => endpoints.where((e) => e.isSuccess).length;
  int get failCount => endpoints.where((e) => !e.isSuccess).length;
  bool get allSuccess => failCount == 0;

  /// Average response time across successful endpoints
  int get avgLatencyMs {
    final successful = endpoints.where(
      (e) => e.isSuccess && e.latencyMs != null,
    );
    if (successful.isEmpty) return 0;
    final total = successful.fold<int>(0, (sum, e) => sum + e.latencyMs!);
    return total ~/ successful.length;
  }
}

/// Comprehensive diagnostic screen for relay connectivity debugging
class RelayDiagnosticScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'relay-diagnostic';

  /// Path for this route.
  static const String path = RoutePaths.relayDiagnostic;

  const RelayDiagnosticScreen({super.key});

  @override
  ConsumerState<RelayDiagnosticScreen> createState() =>
      _RelayDiagnosticScreenState();
}

class _RelayDiagnosticScreenState extends ConsumerState<RelayDiagnosticScreen> {
  Map<String, dynamic>? _relayStats;
  Map<String, String> _networkTests = {};
  bool _isTestingNetwork = false;
  bool _isRetrying = false;
  DateTime? _lastRefresh;

  // REST endpoint test results
  BlossomHealthCheckResult? _blossomResult;
  FunnelCakeTestResults? _funnelCakeResults;
  bool _isTestingRestEndpoints = false;

  @override
  void initState() {
    super.initState();
    _refreshDiagnostics();
  }

  Future<void> _refreshDiagnostics() async {
    setState(() {
      _lastRefresh = DateTime.now();
    });

    final nostrService = ref.read(nostrServiceProvider);

    // Get relay stats from NostrClient
    try {
      final stats = await nostrService.getRelayStats();
      setState(() {
        _relayStats = stats;
      });

      // Check if there are video events in the database
      if (stats != null && stats['database'] != null) {
        final totalEvents = stats['database']['total_events'] ?? 0;
        Log.info(
          'Relay cache has $totalEvents total events',
          name: 'RelayDiagnostic',
        );

        // Query for video events specifically to see if any exist
        try {
          final videoEvents = await nostrService.queryEvents([
            nostr.Filter(
              kinds: const [NIP71VideoKinds.addressableShortVideo],
              limit: 10,
            ),
          ]);
          Log.info(
            'Found ${videoEvents.length} video events in relay cache',
            name: 'RelayDiagnostic',
          );
        } catch (e) {
          Log.error(
            'Failed to query video events: $e',
            name: 'RelayDiagnostic',
          );
        }
      }
    } catch (e) {
      Log.error('Failed to get relay stats: $e', name: 'RelayDiagnostic');
    }
  }

  Future<void> _testNetworkConnectivity() async {
    setState(() {
      _isTestingNetwork = true;
      _networkTests = {};
    });

    final nostrService = ref.read(nostrServiceProvider);
    final relays = nostrService.configuredRelays;

    for (final relayUrl in relays) {
      try {
        // Extract hostname from WebSocket URL
        final uri = Uri.parse(relayUrl);
        final host = uri.host;
        // Use default ports if not explicitly specified (uri.port returns 0 if not set)
        final port = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);

        Log.info(
          'Testing connectivity to $host:$port (scheme=${uri.scheme})',
          name: 'RelayDiagnostic',
        );

        // Test TCP connection
        final stopwatch = Stopwatch()..start();
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 5),
        );
        stopwatch.stop();
        await socket.close();

        setState(() {
          _networkTests[relayUrl] = 'OK (${stopwatch.elapsedMilliseconds}ms)';
        });

        Log.info(
          '✅ Relay $relayUrl reachable in ${stopwatch.elapsedMilliseconds}ms',
          name: 'RelayDiagnostic',
        );
      } catch (e) {
        setState(() {
          _networkTests[relayUrl] = 'FAILED: $e';
        });

        Log.error('❌ Relay $relayUrl unreachable: $e', name: 'RelayDiagnostic');
      }
    }

    setState(() {
      _isTestingNetwork = false;
    });
  }

  Future<void> _testRestEndpoints() async {
    setState(() {
      _isTestingRestEndpoints = true;
      _blossomResult = null;
      _funnelCakeResults = null;
    });

    Log.info('🔍 Testing REST endpoints...', name: 'RelayDiagnostic');

    // Test Blossom server
    try {
      final blossomService = ref.read(blossomUploadServiceProvider);
      final blossomResult = await blossomService.testServerConnection();
      setState(() {
        _blossomResult = blossomResult;
      });
      Log.info(
        'Blossom server: ${blossomResult.isReachable ? "OK" : "FAILED"} '
        '(${blossomResult.latencyMs}ms)',
        name: 'RelayDiagnostic',
      );
    } catch (e) {
      Log.error('Blossom test error: $e', name: 'RelayDiagnostic');
      setState(() {
        _blossomResult = BlossomHealthCheckResult(
          isReachable: false,
          errorMessage: e.toString(),
        );
      });
    }

    // Test FunnelCake API - comprehensive endpoint testing
    final nostrService = ref.read(nostrServiceProvider);
    final relays = nostrService.configuredRelays;
    if (relays.isNotEmpty) {
      final relayUrl = relays.first;
      final apiBaseUrl = relayUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://');

      final results = await _testAllFunnelCakeEndpoints(apiBaseUrl);
      setState(() {
        _funnelCakeResults = results;
      });
    } else {
      setState(() {
        _funnelCakeResults = FunnelCakeTestResults(
          apiBaseUrl: 'N/A',
          endpoints: [
            FunnelCakeEndpointResult(
              endpoint: 'N/A',
              isSuccess: false,
              errorMessage: 'No relays configured',
            ),
          ],
        );
      });
    }

    setState(() {
      _isTestingRestEndpoints = false;
    });

    if (mounted) {
      final blossomOk = _blossomResult?.isReachable ?? false;
      final funnelCakeOk = _funnelCakeResults?.allSuccess ?? false;

      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          blossomOk && funnelCakeOk
              ? context.l10n.relayDiagnosticAllEndpointsHealthy
              : context.l10n.relayDiagnosticSomeEndpointsFailed,
          error: !(blossomOk && funnelCakeOk),
        ),
      );
    }
  }

  Future<FunnelCakeTestResults> _testAllFunnelCakeEndpoints(
    String apiBaseUrl,
  ) async {
    final endpoints = <FunnelCakeEndpointResult>[];

    // Test /api/stats
    endpoints.add(
      await _testFunnelCakeEndpoint(apiBaseUrl, '/api/stats', (json) {
        final totalVideos = json['total_videos'] as int?;
        final totalEvents = json['total_events'] as int?;
        return (
          count: totalVideos,
          details: '$totalEvents events, $totalVideos videos',
        );
      }),
    );

    // Test /api/videos
    endpoints.add(
      await _testFunnelCakeEndpoint(apiBaseUrl, '/api/videos?limit=5', (json) {
        final list = json as List;
        return (count: list.length, details: 'returned ${list.length}');
      }),
    );

    // Test /api/videos/events (with full Nostr events)
    endpoints.add(
      await _testFunnelCakeEndpoint(apiBaseUrl, '/api/videos/events?limit=5', (
        json,
      ) {
        final videos = json['videos'] as List?;
        final hasMore = json['has_more'] as bool?;
        return (
          count: videos?.length,
          details: '${videos?.length ?? 0} events, hasMore=$hasMore',
        );
      }),
    );

    // Test /api/videos?sort=trending
    endpoints.add(
      await _testFunnelCakeEndpoint(
        apiBaseUrl,
        '/api/videos?sort=trending&limit=5',
        (json) {
          final list = json as List;
          return (count: list.length, details: '${list.length} trending');
        },
      ),
    );

    // Test /api/hashtags
    endpoints.add(
      await _testFunnelCakeEndpoint(apiBaseUrl, '/api/hashtags?limit=5', (
        json,
      ) {
        final list = json as List;
        final topTag = list.isNotEmpty ? list[0]['hashtag'] : 'none';
        return (count: list.length, details: 'top: #$topTag');
      }),
    );

    // Test /api/hashtags/trending
    endpoints.add(
      await _testFunnelCakeEndpoint(
        apiBaseUrl,
        '/api/hashtags/trending?limit=5',
        (json) {
          final list = json as List;
          return (count: list.length, details: '${list.length} trending tags');
        },
      ),
    );

    return FunnelCakeTestResults(apiBaseUrl: apiBaseUrl, endpoints: endpoints);
  }

  Future<FunnelCakeEndpointResult> _testFunnelCakeEndpoint(
    String apiBaseUrl,
    String path,
    ({int? count, String? details}) Function(dynamic json) parseResponse,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl$path'))
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();

      if (response.statusCode == 200) {
        try {
          final json = response.body.isNotEmpty
              ? _parseJson(response.body)
              : null;
          final parsed = json != null
              ? parseResponse(json)
              : (count: null, details: null);
          return FunnelCakeEndpointResult(
            endpoint: path.split('?').first,
            isSuccess: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            count: parsed.count,
            details: parsed.details,
          );
        } catch (e) {
          return FunnelCakeEndpointResult(
            endpoint: path.split('?').first,
            isSuccess: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            details: 'Parse error: $e',
          );
        }
      } else {
        return FunnelCakeEndpointResult(
          endpoint: path.split('?').first,
          isSuccess: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return FunnelCakeEndpointResult(
        endpoint: path.split('?').first,
        isSuccess: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString().length > 50
            ? '${e.toString().substring(0, 50)}...'
            : e.toString(),
      );
    }
  }

  dynamic _parseJson(String body) {
    return body.startsWith('[')
        ? (body.isNotEmpty ? _decodeJsonList(body) : [])
        : (body.isNotEmpty ? _decodeJsonMap(body) : {});
  }

  List<dynamic> _decodeJsonList(String body) {
    return (const JsonDecoder().convert(body)) as List<dynamic>;
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    return (const JsonDecoder().convert(body)) as Map<String, dynamic>;
  }

  Future<void> _testDirectEventQuery() async {
    Log.info(
      '🔍 Testing direct event query (bypassing subscriptions)...',
      name: 'RelayDiagnostic',
    );

    final nostrService = ref.read(nostrServiceProvider);

    try {
      // Query for video events directly from relay
      final videoEvents = await nostrService.queryEvents([
        nostr.Filter(
          kinds: const [NIP71VideoKinds.addressableShortVideo],
          limit: 100,
        ),
      ]);

      Log.info(
        '✅ Direct query returned ${videoEvents.length} video events',
        name: 'RelayDiagnostic',
      );

      if (videoEvents.isNotEmpty) {
        Log.info('📹 Sample events:', name: 'RelayDiagnostic');
        for (var i = 0; i < videoEvents.take(3).length; i++) {
          final event = videoEvents[i];
          Log.info(
            '  Event $i: kind=${event.kind}, author=${pubkeyForLogs(event.pubkey)}, timestamp=${event.createdAt}',
            name: 'RelayDiagnostic',
          );
        }
      } else {
        Log.warning(
          '⚠️ No video events found in relay cache!',
          name: 'RelayDiagnostic',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.relayDiagnosticFoundVideoEvents(videoEvents.length),
            error: videoEvents.isEmpty,
          ),
        );
      }
    } catch (e) {
      Log.error('❌ Direct query failed: $e', name: 'RelayDiagnostic');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.relayDiagnosticQueryFailed,
            error: true,
          ),
        );
      }
    }
  }

  Future<void> _retryConnection() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      final nostrService = ref.read(nostrServiceProvider);

      Log.info('Retrying relay connections...', name: 'RelayDiagnostic');

      // Resolves only once every relay's connect attempt has settled — the
      // await chain runs down to `channel.ready` — and _updateRelayStatus has
      // already written the statuses connectedRelayCount reads. Nothing here
      // needs an extra wall-clock wait.
      await nostrService.retryDisconnectedRelays();

      await _refreshDiagnostics();

      // Check if any relays connected
      final connectedCount = nostrService.connectedRelayCount;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            connectedCount > 0
                ? context.l10n.relayDiagnosticConnectedToRelays(connectedCount)
                : context.l10n.relayDiagnosticFailedToConnect,
            error: connectedCount == 0,
          ),
        );
      }

      // Trigger feed refresh if connected
      if (connectedCount > 0) {
        final videoService = ref.read(videoEventServiceProvider);
        await videoService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
      }
    } catch (e) {
      Log.error('Failed to retry connection: $e', name: 'RelayDiagnostic');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.relayDiagnosticConnectionRetryFailed,
            error: true,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final videoService = ref.watch(videoEventServiceProvider);

    final configuredRelays = nostrService.configuredRelays;
    final connectedRelays = nostrService.connectedRelays;
    final relayStatuses = nostrService.relayStatuses;

    // Count events in different feeds
    final homeFeedCount = videoService.homeFeedVideos.length;
    final discoveryCount = videoService.discoveryVideos.length;

    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.relayDiagnosticTitle,
        showBackButton: true,
        onBackPressed: context.pop,
        actions: [
          DiVineAppBarAction(
            icon: SvgIconSource(DivineIconName.arrowClockwise.assetPath),
            onPressed: _refreshDiagnostics,
            tooltip: context.l10n.relayDiagnosticRefreshTooltip,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: .fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              // Last refresh time
              if (_lastRefresh != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    context.l10n.relayDiagnosticLastRefresh(
                      _formatTime(_lastRefresh!),
                    ),
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.mutedText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Relay status
              _buildSection(
                title: context.l10n.relayDiagnosticRelayStatus,
                icon: Icons.storage,
                children: [
                  _buildStatusRow(
                    context.l10n.relayDiagnosticInitialized,
                    nostrService.isInitialized,
                    nostrService.isInitialized
                        ? context.l10n.relayDiagnosticReady
                        : context.l10n.relayDiagnosticNotInitialized,
                  ),
                  if (_relayStats != null) ...[
                    _buildInfoRow(
                      context.l10n.relayDiagnosticDatabaseEvents,
                      _relayStats!['database']?['total_events']?.toString() ??
                          'N/A',
                    ),
                    _buildInfoRow(
                      context.l10n.relayDiagnosticActiveSubscriptions,
                      _relayStats!['subscriptions']?['active_count']
                              ?.toString() ??
                          'N/A',
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // External relays status
              _buildSection(
                title: context.l10n.relayDiagnosticExternalRelays,
                icon: Icons.cloud,
                children: [
                  _buildInfoRow(
                    context.l10n.relayDiagnosticConfigured,
                    context.l10n.relayDiagnosticRelayCount(
                      configuredRelays.length,
                    ),
                  ),
                  _buildInfoRow(
                    context.l10n.relayDiagnosticConnectedLabel,
                    context.l10n.relayDiagnosticConnectedRatio(
                      connectedRelays.length,
                      configuredRelays.length,
                    ),
                  ),
                  Divider(color: context.vineColors.mutedText),
                  ...configuredRelays.map((relayUrl) {
                    final isConnected = connectedRelays.contains(relayUrl);
                    final status = relayStatuses[relayUrl];
                    final isAuthenticated =
                        status?.state == RelayState.authenticated;
                    return _buildRelayRow(
                      relayUrl,
                      isConnected,
                      isAuthenticated,
                    );
                  }),
                ],
              ),

              const SizedBox(height: 16),

              // Video events status
              _buildSection(
                title: context.l10n.relayDiagnosticVideoEvents,
                icon: Icons.video_library,
                children: [
                  _buildInfoRow(
                    context.l10n.relayDiagnosticHomeFeed,
                    context.l10n.relayDiagnosticVideosCount(homeFeedCount),
                  ),
                  _buildInfoRow(
                    context.l10n.relayDiagnosticDiscovery,
                    context.l10n.relayDiagnosticVideosCount(discoveryCount),
                  ),
                  _buildInfoRow(
                    context.l10n.relayDiagnosticLoading,
                    videoService.isLoading
                        ? context.l10n.relayDiagnosticYes
                        : context.l10n.relayDiagnosticNo,
                  ),
                  if (videoService.error != null)
                    _buildErrorRow('Error', videoService.error!),
                  Divider(color: context.vineColors.mutedText),
                  Center(
                    child: DivineButton(
                      label: context.l10n.relayDiagnosticTestDirectQuery,
                      leadingIcon: DivineIconName.search,
                      onPressed: _testDirectEventQuery,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Network connectivity test
              _buildSection(
                title: context.l10n.relayDiagnosticNetworkConnectivity,
                icon: Icons.network_check,
                children: [
                  if (_networkTests.isEmpty && !_isTestingNetwork)
                    Center(
                      child: DivineButton(
                        label: context.l10n.relayDiagnosticRunNetworkTest,
                        leadingIcon: DivineIconName.play,
                        onPressed: _testNetworkConnectivity,
                      ),
                    ),
                  if (_isTestingNetwork)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: BrandedLoadingIndicator(size: 44),
                      ),
                    ),
                  if (_networkTests.isNotEmpty)
                    ..._networkTests.entries.map((entry) {
                      final isOk = entry.value.startsWith('OK');
                      return _buildInfoRow(
                        entry.key,
                        entry.value,
                        textColor: isOk ? VineTheme.success : VineTheme.error,
                      );
                    }),
                ],
              ),

              const SizedBox(height: 16),

              // Blossom Server status
              _buildSection(
                title: context.l10n.relayDiagnosticBlossomServer,
                icon: Icons.cloud_upload,
                children: [
                  if (_blossomResult == null && !_isTestingRestEndpoints)
                    Center(
                      child: DivineButton(
                        label: context.l10n.relayDiagnosticTestAllEndpoints,
                        leadingIcon: DivineIconName.play,
                        onPressed: _testRestEndpoints,
                      ),
                    ),
                  if (_isTestingRestEndpoints && _blossomResult == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: BrandedLoadingIndicator(size: 44),
                      ),
                    ),
                  if (_blossomResult != null) ...[
                    _buildInfoRow(
                      context.l10n.relayDiagnosticStatus,
                      _blossomResult!.isReachable
                          ? 'OK (${_blossomResult!.latencyMs}ms)'
                          : 'FAILED',
                      textColor: _blossomResult!.isReachable
                          ? VineTheme.success
                          : VineTheme.error,
                    ),
                    if (_blossomResult!.serverUrl != null)
                      _buildInfoRow(
                        context.l10n.relayDiagnosticUrl,
                        _blossomResult!.serverUrl!,
                      ),
                    if (_blossomResult!.errorMessage != null)
                      _buildErrorRow(
                        context.l10n.relayDiagnosticError,
                        _blossomResult!.errorMessage!,
                      ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // FunnelCake API status - comprehensive endpoint testing
              _buildSection(
                title: context.l10n.relayDiagnosticFunnelCakeApi,
                icon: Icons.api,
                children: [
                  if (_funnelCakeResults == null && !_isTestingRestEndpoints)
                    Center(
                      child: DivineButton(
                        label: context.l10n.relayDiagnosticTestAllEndpoints,
                        leadingIcon: DivineIconName.play,
                        onPressed: _testRestEndpoints,
                      ),
                    ),
                  if (_isTestingRestEndpoints && _funnelCakeResults == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: BrandedLoadingIndicator(size: 44),
                      ),
                    ),
                  if (_funnelCakeResults != null) ...[
                    // Summary row
                    _buildInfoRow(
                      context.l10n.relayDiagnosticBaseUrl,
                      _funnelCakeResults!.apiBaseUrl,
                    ),
                    _buildInfoRow(
                      context.l10n.relayDiagnosticSummary,
                      context.l10n.relayDiagnosticEndpointSummary(
                        _funnelCakeResults!.successCount,
                        _funnelCakeResults!.endpoints.length,
                        _funnelCakeResults!.avgLatencyMs,
                      ),
                      textColor: _funnelCakeResults!.allSuccess
                          ? VineTheme.success
                          : VineTheme.warning,
                    ),
                    Divider(color: context.vineColors.mutedText),
                    // Individual endpoint results
                    ..._funnelCakeResults!.endpoints.map(
                      _buildEndpointResultRow,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: DivineButton(
                        label: context.l10n.relayDiagnosticRetestAll,
                        type: DivineButtonType.link,
                        onPressed: _testRestEndpoints,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Retry connection button
              DivineButton(
                label: _isRetrying
                    ? context.l10n.relayDiagnosticRetrying
                    : context.l10n.relayDiagnosticRetryConnection,
                leadingIcon: DivineIconName.arrowClockwise,
                expanded: true,
                isLoading: _isRetrying,
                onPressed: _isRetrying ? null : _retryConnection,
              ),

              const SizedBox(height: 16),

              DivineInfoCard(
                tone: DivineInfoCardTone.neutral,
                compact: true,
                title: context.l10n.relayDiagnosticTroubleshooting,
                message: context.l10n.relayDiagnosticTroubleshootingGuide,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: VineTheme.vineGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.vineColors.mutedText),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isOk, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          DivineIcon(
            icon: isOk
                ? DivineIconName.checkCircle
                : DivineIconName.warningCircle,
            color: isOk ? VineTheme.success : VineTheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: VineTheme.titleSmallFont(
              color: isOk ? VineTheme.success : VineTheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: VineTheme.labelLargeFont(
                color: textColor ?? context.vineColors.primaryText,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRow(String label, String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.vineColors.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              error,
              style: VineTheme.bodySmallFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointResultRow(FunnelCakeEndpointResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DivineIcon(
            icon: result.isSuccess
                ? DivineIconName.checkCircle
                : DivineIconName.warningCircle,
            color: result.isSuccess ? VineTheme.success : VineTheme.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.endpoint,
                  style: VineTheme.codeFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                if (result.isSuccess)
                  Text(
                    '${result.latencyMs}ms${result.details != null ? ' • ${result.details}' : ''}',
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.secondaryText,
                    ),
                  )
                else
                  Text(
                    result.errorMessage ?? 'Failed',
                    style: VineTheme.bodySmallFont(color: VineTheme.error),
                  ),
              ],
            ),
          ),
          if (result.count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: VineTheme.vineGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${result.count}',
                style: VineTheme.labelMediumFont(color: VineTheme.vineGreen),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRelayRow(
    String relayUrl,
    bool isConnected,
    bool isAuthenticated,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DivineIcon(
                // No cloud pair in the icon set; check / warning carries the
                // same connected vs. not-connected read.
                icon: isConnected
                    ? DivineIconName.checkCircle
                    : DivineIconName.warningCircle,
                color: isConnected ? VineTheme.success : VineTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  relayUrl,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 28),
            child: Text(
              isConnected
                  ? (isAuthenticated
                        ? context.l10n.relayDiagnosticConnectedAuthenticated
                        : context.l10n.relayDiagnosticConnectedOnly)
                  : context.l10n.relayDiagnosticNotConnected,
              style: VineTheme.bodySmallFont(
                color: isConnected ? VineTheme.success : VineTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
