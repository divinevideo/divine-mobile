// ABOUTME: P2P Discovery Service for divine video sharing between nearby devices
// ABOUTME: Manages BLE discovery and WiFi Direct connections for local video sync

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;

/// P2P Discovery Service for finding and connecting to nearby divine users
class P2PDiscoveryService extends ChangeNotifier {
  final embedded.BleTransport _bleTransport = embedded.BleTransport();
  final embedded.WifiDirectTransport _wifiDirectTransport =
      embedded.WifiDirectTransport();

  final Map<String, P2PPeer> _discoveredPeers = {};
  final Map<String, P2PConnection> _activeConnections = {};
  final StreamController<P2PPeer> _peerController =
      StreamController.broadcast();

  bool _isDiscovering = false;
  bool _isAdvertising = false;
  String? _deviceName;

  // divine-specific configuration
  static const String appIdentifier = 'divine';
  static const Duration discoveryTimeout = Duration(minutes: 5);
  static const Duration connectionTimeout = Duration(seconds: 30);

  /// Stream of discovered nearby divine users
  Stream<P2PPeer> get discoveredPeers => _peerController.stream;

  /// List of currently discovered peers
  List<P2PPeer> get peers => _discoveredPeers.values.toList();

  /// List of active P2P connections
  List<P2PConnection> get connections => _activeConnections.values.toList();

  /// Whether discovery is currently active
  bool get isDiscovering => _isDiscovering;

  /// Whether advertising is currently active
  bool get isAdvertising => _isAdvertising;

  /// Initialize P2P discovery with permissions
  Future<bool> initialize({String? customDeviceName}) async {
    try {
      // Set device name
      _deviceName = customDeviceName ?? await _generateDeviceName();

      // Request necessary permissions
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        debugPrint('P2P: Required permissions not granted');
        return false;
      }

      debugPrint('P2P: Initialized with device name: $_deviceName');
      return true;
    } catch (e) {
      debugPrint('P2P: Initialization failed: $e');
      return false;
    }
  }

  /// Start discovering nearby divine devices
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    debugPrint('P2P: Starting discovery for nearby divine devices');
    _isDiscovering = true;
    notifyListeners();

    try {
      // Start BLE discovery for all platforms
      final bleStream = _bleTransport.discoverPeers();
      bleStream.listen(
        (peer) => _onPeerDiscovered(peer, P2PTransportType.ble),
        onError: (error) => debugPrint('P2P BLE Discovery error: $error'),
      );

      // Start WiFi Direct discovery on Android
      if (Platform.isAndroid) {
        final wifiDirectStream = _wifiDirectTransport.discoverPeers();
        wifiDirectStream.listen(
          (peer) => _onPeerDiscovered(peer, P2PTransportType.wifiDirect),
          onError: (error) =>
              debugPrint('P2P WiFi Direct Discovery error: $error'),
        );
      }

      // Auto-stop discovery after timeout
      Timer(discoveryTimeout, () {
        if (_isDiscovering) {
          stopDiscovery();
        }
      });
    } catch (e) {
      debugPrint('P2P: Failed to start discovery: $e');
      _isDiscovering = false;
      notifyListeners();
    }
  }

  /// Stop discovering nearby devices
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;

    debugPrint('P2P: Stopping discovery');
    _isDiscovering = false;
    notifyListeners();

    // Clear discovered peers (they may no longer be available)
    _discoveredPeers.clear();
  }

  /// Start advertising this device as available for P2P connections
  Future<void> startAdvertising() async {
    if (_isAdvertising || _deviceName == null) return;

    debugPrint('P2P: Starting advertising as $_deviceName');
    _isAdvertising = true;
    notifyListeners();

    try {
      // Start BLE advertising
      await _bleTransport.startAdvertising(name: _deviceName!);

      // Start WiFi Direct advertising on Android
      if (Platform.isAndroid) {
        await _wifiDirectTransport.startAdvertising(name: _deviceName!);
      }
    } catch (e) {
      debugPrint('P2P: Failed to start advertising: $e');
      _isAdvertising = false;
      notifyListeners();
    }
  }

  /// Stop advertising this device
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;

    debugPrint('P2P: Stopping advertising');
    _isAdvertising = false;
    notifyListeners();

    try {
      await _bleTransport.stopAdvertising();
      if (Platform.isAndroid) {
        await _wifiDirectTransport.stopAdvertising();
      }
    } catch (e) {
      debugPrint('P2P: Error stopping advertising: $e');
    }
  }

  /// Connect to a discovered peer
  Future<P2PConnection?> connectToPeer(P2PPeer peer) async {
    if (_activeConnections.containsKey(peer.id)) {
      return _activeConnections[peer.id];
    }

    debugPrint(
      'P2P: Connecting to peer ${peer.name} via ${peer.transportType.name}',
    );

    try {
      embedded.TransportConnection transportConnection;

      // Choose appropriate transport
      switch (peer.transportType) {
        case P2PTransportType.ble:
          transportConnection = await _bleTransport.connect(peer.transportPeer);
          break;
        case P2PTransportType.wifiDirect:
          transportConnection = await _wifiDirectTransport.connect(
            peer.transportPeer,
          );
          break;
      }

      final connection = P2PConnection(
        peer: peer,
        transport: transportConnection,
      );

      _activeConnections[peer.id] = connection;
      notifyListeners();

      // Listen for disconnection
      connection.transport.isConnected.listen((connected) {
        if (!connected) {
          _activeConnections.remove(peer.id);
          notifyListeners();
        }
      });

      debugPrint('P2P: Successfully connected to ${peer.name}');
      return connection;
    } catch (e) {
      debugPrint('P2P: Failed to connect to ${peer.name}: $e');
    }

    return null;
  }

  /// Disconnect from a peer
  Future<void> disconnectFromPeer(String peerId) async {
    final connection = _activeConnections[peerId];
    if (connection != null) {
      await connection.transport.close();
      _activeConnections.remove(peerId);
      notifyListeners();
      debugPrint('P2P: Disconnected from peer $peerId');
    }
  }

  /// Send video metadata to a connected peer
  Future<bool> sendVideoMetadata(
    String peerId,
    Map<String, dynamic> metadata,
  ) async {
    final connection = _activeConnections[peerId];
    if (connection == null) return false;

    try {
      final message = {
        'type': 'video_metadata',
        'data': metadata,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final jsonString = jsonEncode(message);
      final bytes = utf8.encode(jsonString);

      await connection.transport.send(bytes);
      debugPrint('P2P: Sent video metadata to ${connection.peer.name}');
      return true;
    } catch (e) {
      debugPrint('P2P: Failed to send metadata to $peerId: $e');
      return false;
    }
  }

  @override
  void dispose() {
    stopDiscovery();
    stopAdvertising();

    // Close all connections
    for (final connection in _activeConnections.values) {
      connection.transport.close();
    }
    _activeConnections.clear();

    _peerController.close();
    _bleTransport.dispose();
    _wifiDirectTransport.dispose();

    super.dispose();
  }

  // Private methods

  void _onPeerDiscovered(
    embedded.TransportPeer transportPeer,
    P2PTransportType transportType,
  ) {
    // Filter for divine devices only
    if (!transportPeer.name.contains(appIdentifier)) {
      return;
    }

    final peer = P2PPeer(
      id: transportPeer.id,
      name: transportPeer.name,
      transportType: transportType,
      transportPeer: transportPeer,
      discoveredAt: DateTime.now(),
    );

    if (!_discoveredPeers.containsKey(peer.id)) {
      _discoveredPeers[peer.id] = peer;
      _peerController.add(peer);
      notifyListeners();

      debugPrint('P2P: Discovered ${peer.name} via ${transportType.name}');
    }
  }

  Future<String> _generateDeviceName() async {
    // Generate a friendly device name for divine
    final timestamp = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(7);
    return '$appIdentifier-User-$timestamp';
  }

  Future<bool> _requestPermissions() async {
    final permissions = <Permission>[];

    // BLE permissions
    permissions.addAll([
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ]);

    // Location permissions (required for WiFi Direct and BLE on some Android versions)
    permissions.addAll([Permission.location, Permission.locationWhenInUse]);

    // WiFi permissions for Android
    if (Platform.isAndroid) {
      permissions.addAll([Permission.nearbyWifiDevices]);
    }

    final statuses = await permissions.request();

    // Check if all essential permissions are granted
    final bluetoothGranted = statuses[Permission.bluetooth]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;

    return bluetoothGranted && locationGranted;
  }
}

/// Represents a discovered P2P peer
class P2PPeer {
  final String id;
  final String name;
  final P2PTransportType transportType;
  final embedded.TransportPeer transportPeer;
  final DateTime discoveredAt;

  P2PPeer({
    required this.id,
    required this.name,
    required this.transportType,
    required this.transportPeer,
    required this.discoveredAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is P2PPeer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents an active P2P connection
class P2PConnection {
  final P2PPeer peer;
  final embedded.TransportConnection transport;
  final DateTime connectedAt;

  P2PConnection({required this.peer, required this.transport})
    : connectedAt = DateTime.now();

  /// Stream of incoming data from this peer
  Stream<List<int>> get dataStream => transport.dataStream;

  /// Whether this connection is active
  Stream<bool> get isConnected => transport.isConnected;

  /// Send data to this peer
  Future<void> send(List<int> data) => transport.send(data);
}

/// Available P2P transport types
enum P2PTransportType { ble, wifiDirect }
