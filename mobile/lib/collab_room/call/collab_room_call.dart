// ABOUTME: A Together room's call: one WebRTC connection to each other person,
// ABOUTME: set up through the room's sealed connection messages

import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/collab_room/call/collab_room_call_signal.dart';
import 'package:openvine/collab_room/call/collab_room_call_transport.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'CollabRoomCall';

/// A call step the device refused, such as a microphone it would not open.
class CollabRoomCallException implements Exception {
  /// Creates an exception saying [message].
  const CollabRoomCallException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'CollabRoomCallException: $message';
}

/// Runs [step], a flutter_webrtc call. That plugin reports a failure by
/// throwing a plain string, which no `on Exception` catches; here it becomes
/// a [CollabRoomCallException].
Future<T> _device<T>(Future<T> Function() step) async {
  try {
    return await step();
  } on Exception {
    rethrow;
  } on Object catch (error) {
    throw CollabRoomCallException('$error');
  }
}

/// One other person in the call as this device sees them.
class CollabRoomCallPeer extends Equatable {
  /// Creates a peer view.
  const CollabRoomCallPeer({
    required this.pubkey,
    this.connected = false,
    this.micOn = true,
    this.cameraOn = false,
    this.stream,
  });

  /// Who.
  final String pubkey;

  /// Whether audio and video flow between the two devices.
  final bool connected;

  /// Whether their microphone is on.
  final bool micOn;

  /// Whether their camera is on.
  final bool cameraOn;

  /// What their device sends, once connected.
  final MediaStream? stream;

  @override
  List<Object?> get props => [pubkey, connected, micOn, cameraOn, stream];
}

/// A lobby someone described in the call: the layout and who sits where.
class CollabRoomCallLobby extends Equatable {
  /// Creates a lobby description.
  const CollabRoomCallLobby({
    required this.from,
    required this.layout,
    required this.seats,
    required this.revision,
    required this.sentAt,
  });

  /// Who described it.
  final String from;

  /// The layout, by name.
  final String? layout;

  /// Pubkeys in cell order.
  final List<String> seats;

  /// The newest snapshot revision [from] had published.
  final int revision;

  /// When it was sent, in microseconds since the epoch.
  final int sentAt;

  @override
  List<Object?> get props => [from, layout, seats, revision, sentAt];
}

/// The call as this device sees it.
class CollabRoomCallSnapshot extends Equatable {
  /// Creates a snapshot.
  const CollabRoomCallSnapshot({
    this.micOn = true,
    this.cameraOn = false,
    this.localVideo,
    this.peers = const {},
    this.lobby,
  });

  /// Whether this device's microphone is on.
  final bool micOn;

  /// Whether this device's camera is on.
  final bool cameraOn;

  /// This device's camera, for its own cell, while on.
  final MediaStream? localVideo;

  /// Everyone else in the call, by pubkey.
  final Map<String, CollabRoomCallPeer> peers;

  /// The newest lobby someone else described.
  final CollabRoomCallLobby? lobby;

  @override
  List<Object?> get props => [micOn, cameraOn, localVideo, peers, lobby];
}

/// A room's call.
abstract interface class CollabRoomCall {
  /// The call as it changes.
  Stream<CollabRoomCallSnapshot> get changes;

  /// Joins: turns the microphone on and connects to whoever is in the room.
  ///
  /// Throws when the microphone cannot be opened.
  Future<void> start();

  /// Turns the microphone on or off.
  Future<void> setMicOn(bool on);

  /// Turns the camera on or off.
  ///
  /// Throws when the camera cannot be opened.
  Future<void> setCameraOn(bool on);

  /// The other people in the room changed.
  void updateOthers(Set<String> others);

  /// Tells everyone in the call the lobby as it stands: [layout], by name,
  /// and [seats], pubkeys in cell order, building on the snapshot at
  /// [revision]. The room's own snapshot follows; this only gets there first.
  Future<void> shareLobby({
    required String? layout,
    required List<String> seats,
    required int revision,
  });

  /// Leaves the call and releases the microphone and camera.
  Future<void> stop();
}

/// Creates the call of a room for [me] with [others].
typedef CollabRoomCallFactory = CollabRoomCall Function({
  required String me,
  required Set<String> others,
  required String callKey,
});

/// A [CollabRoomCall] over WebRTC: one peer connection to each other person.
///
/// Of every two people the one with the smaller pubkey offers, so offers
/// never cross. Candidates go inside the offer and the answer instead of one
/// message each, which keeps the setup to three messages per pair. The video
/// slot is negotiated from the start and the camera is only attached to it
/// when turned on, so turning it on needs no new negotiation.
class WebRtcCollabRoomCall implements CollabRoomCall {
  /// Creates the call of the room whose call key is [callKey].
  WebRtcCollabRoomCall({
    required String me,
    required Set<String> others,
    required String callKey,
    required CollabRoomCallTransport transport,
  }) : _me = me,
       _others = {...others},
       _channel = CollabRoomCallChannel(callKey),
       _transport = transport,
       _session = _newSession();

  static String _newSession() {
    final random = Random.secure();
    return List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static const Map<String, Object> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// How long to wait for the network paths before sending what was found.
  static const _gatherTimeout = Duration(seconds: 3);

  final String _me;
  final Set<String> _others;
  final CollabRoomCallChannel _channel;
  final CollabRoomCallTransport _transport;
  final String _session;
  final _changes = StreamController<CollabRoomCallSnapshot>.broadcast();
  final _peers = <String, _Peer>{};

  StreamSubscription<Event>? _subscription;
  MediaStream? _audio;
  MediaStream? _video;
  bool _micOn = true;
  bool _stopped = false;
  CollabRoomCallLobby? _lobby;

  /// Ids of the messages handled so far. Every relay the app reads from
  /// delivers the same message, and an answer applied twice fails.
  final _seen = <String>{};

  /// Signals are handled one after another, so two never set up the same
  /// connection at once.
  Future<void> _queue = Future.value();

  @override
  Stream<CollabRoomCallSnapshot> get changes => _changes.stream;

  @override
  Future<void> start() async {
    _audio = await _device(
      () => navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      }),
    );
    await Helper.setSpeakerphoneOn(true);
    final since = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 5;
    _subscription = _transport
        .watch(_channel.pubkey, since: since)
        .listen(_onEvent, onError: _onTransportError);
    await _send(
      CollabRoomCallSignal(
        type: CollabRoomCallSignalType.hello,
        from: _me,
        session: _session,
        micOn: _micOn,
        cameraOn: _video != null,
      ),
    );
    _emit();
  }

  @override
  Future<void> setMicOn(bool on) async {
    _micOn = on;
    for (final track in _audio?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = on;
    }
    await _sendState();
    _emit();
  }

  @override
  Future<void> setCameraOn(bool on) async {
    if (on == (_video != null)) return;
    if (on) {
      _video = await _device(
        () => navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
            'frameRate': {'ideal': 24},
          },
        }),
      );
    } else {
      final video = _video;
      _video = null;
      await _attachVideo(null);
      for (final track in video?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await video?.dispose();
    }
    if (on) await _attachVideo(_video?.getVideoTracks().firstOrNull);
    await _sendState();
    _emit();
  }

  Future<void> _attachVideo(MediaStreamTrack? track) async {
    for (final peer in _peers.values) {
      await peer.videoSender?.replaceTrack(track);
    }
  }

  @override
  void updateOthers(Set<String> others) {
    _others
      ..clear()
      ..addAll(others);
    for (final pubkey in _peers.keys.toList()) {
      if (!others.contains(pubkey)) {
        _enqueue(() => _closePeer(pubkey));
      }
    }
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    try {
      await _send(
        CollabRoomCallSignal(
          type: CollabRoomCallSignalType.bye,
          from: _me,
          session: _session,
          micOn: _micOn,
        ),
      );
    } on Exception catch (error) {
      Log.warning(
        'Could not say goodbye to the call: $error',
        name: _logName,
        category: LogCategory.video,
      );
    }
    await _subscription?.cancel();
    for (final pubkey in _peers.keys.toList()) {
      await _closePeer(pubkey);
    }
    for (final stream in [_audio, _video]) {
      for (final track in stream?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await stream?.dispose();
    }
    _audio = null;
    _video = null;
    await _changes.close();
  }

  void _onEvent(Event event) {
    if (!_seen.add(event.id)) return;
    _enqueue(() async {
      final signal = await _channel.open(event);
      if (signal == null || !signal.isFor(_me)) return;
      if (!_others.contains(signal.from)) return;
      await _onSignal(signal);
    });
  }

  void _onTransportError(Object error, StackTrace stackTrace) {
    Log.warning(
      'Call messages stopped: $error',
      name: _logName,
      category: LogCategory.video,
    );
  }

  void _enqueue(Future<void> Function() work) {
    _queue = _queue.then((_) async {
      if (_stopped) return;
      try {
        await work();
      } on Object catch (error, stackTrace) {
        // Anything, not only an Exception: flutter_webrtc throws strings, and
        // one that escaped would break the queue for every later message.
        Log.warning(
          'Call step failed: $error',
          name: _logName,
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<void> _onSignal(CollabRoomCallSignal signal) async {
    Log.info(
      'Call ${signal.type.name} from ${pubkeyForLogs(signal.from)}',
      name: _logName,
      category: LogCategory.video,
    );
    final peer = _peers.putIfAbsent(
      signal.from,
      () => _Peer(signal.from),
    );
    peer
      ..micOn = signal.micOn
      ..cameraOn = signal.cameraOn;
    switch (signal.type) {
      case CollabRoomCallSignalType.hello:
        if (peer.session != signal.session) {
          await _resetPeer(peer);
          peer.session = signal.session;
        }
        if (collabRoomCallOffers(_me, peer.pubkey)) {
          if (peer.connection == null) await _offer(peer);
        } else if (signal.toSession != _session) {
          // Tell the one who offers that this session is here.
          await _send(
            CollabRoomCallSignal(
              type: CollabRoomCallSignalType.hello,
              from: _me,
              session: _session,
              to: peer.pubkey,
              toSession: signal.session,
              micOn: _micOn,
              cameraOn: _video != null,
            ),
          );
        }
      case CollabRoomCallSignalType.offer:
        if (signal.toSession != _session) return;
        await _resetPeer(peer);
        peer.session = signal.session;
        await _answer(peer, signal.sdp!);
      case CollabRoomCallSignalType.answer:
        final connection = peer.connection;
        // Only an offer still waiting takes an answer: a second copy of one
        // already applied would be refused.
        if (signal.toSession != _session ||
            signal.session != peer.session ||
            connection == null ||
            connection.signalingState !=
                RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          return;
        }
        await connection.setRemoteDescription(
          RTCSessionDescription(signal.sdp, 'answer'),
        );
      case CollabRoomCallSignalType.state:
        break;
      case CollabRoomCallSignalType.lobby:
        final current = _lobby;
        if (current == null || signal.sentAt! > current.sentAt) {
          _lobby = CollabRoomCallLobby(
            from: signal.from,
            layout: signal.layout,
            seats: signal.seats!,
            revision: signal.revision!,
            sentAt: signal.sentAt!,
          );
        }
      case CollabRoomCallSignalType.bye:
        if (signal.session == peer.session) {
          await _resetPeer(peer);
          peer.session = null;
        }
    }
    _emit();
  }

  Future<RTCPeerConnection> _connection(_Peer peer) async {
    final connection = await createPeerConnection(_iceServers);
    peer.connection = connection;
    connection
      ..onConnectionState = (state) {
        Log.info(
          'Call connection to ${pubkeyForLogs(peer.pubkey)}: ${state.name}',
          name: _logName,
          category: LogCategory.video,
        );
        peer.connected =
            state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed &&
            collabRoomCallOffers(_me, peer.pubkey) &&
            peer.retries < 2) {
          peer.retries++;
          _enqueue(() async {
            await _resetPeer(peer, keepRetries: true);
            await _offer(peer);
          });
        }
        _emit();
      }
      ..onTrack = (event) async {
        try {
          final remote = peer.stream ??= await createLocalMediaStream(
            'peer-${peer.pubkey}',
          );
          await remote.addTrack(event.track);
          _emit();
        } on Object catch (error) {
          // flutter_webrtc throws strings; the call goes on without this
          // track's picture.
          Log.warning(
            'Could not show a call track: $error',
            name: _logName,
            category: LogCategory.video,
          );
        }
      };
    return connection;
  }

  Future<void> _offer(_Peer peer) async {
    final audio = _audio;
    if (audio == null) return;
    final connection = await _connection(peer);
    for (final track in audio.getAudioTracks()) {
      await connection.addTrack(track, audio);
    }
    final video = await connection.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
    );
    peer.videoSender = video.sender;
    final camera = _video?.getVideoTracks().firstOrNull;
    if (camera != null) await video.sender.replaceTrack(camera);
    final gathered = _gathered(connection);
    await connection.setLocalDescription(await connection.createOffer());
    final offer = await gathered;
    if (offer?.sdp == null) return;
    await _send(
      CollabRoomCallSignal(
        type: CollabRoomCallSignalType.offer,
        from: _me,
        session: _session,
        to: peer.pubkey,
        toSession: peer.session,
        sdp: offer!.sdp,
        sdpType: 'offer',
        micOn: _micOn,
        cameraOn: camera != null,
      ),
    );
  }

  Future<void> _answer(_Peer peer, String sdp) async {
    final audio = _audio;
    if (audio == null) return;
    final connection = await _connection(peer);
    await connection.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    for (final track in audio.getAudioTracks()) {
      await connection.addTrack(track, audio);
    }
    for (final transceiver in await connection.getTransceivers()) {
      if (transceiver.receiver.track?.kind != 'video') continue;
      await transceiver.setDirection(TransceiverDirection.SendRecv);
      peer.videoSender = transceiver.sender;
      final camera = _video?.getVideoTracks().firstOrNull;
      if (camera != null) await transceiver.sender.replaceTrack(camera);
    }
    final gathered = _gathered(connection);
    await connection.setLocalDescription(await connection.createAnswer());
    final answer = await gathered;
    if (answer?.sdp == null) return;
    await _send(
      CollabRoomCallSignal(
        type: CollabRoomCallSignalType.answer,
        from: _me,
        session: _session,
        to: peer.pubkey,
        toSession: peer.session,
        sdp: answer!.sdp,
        sdpType: 'answer',
        micOn: _micOn,
        cameraOn: _video != null,
      ),
    );
  }

  /// The local description once the network paths are found, or what was
  /// found when [_gatherTimeout] runs out.
  Future<RTCSessionDescription?> _gathered(
    RTCPeerConnection connection,
  ) async {
    final complete = Completer<void>();
    connection.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !complete.isCompleted) {
        complete.complete();
      }
    };
    await complete.future.timeout(_gatherTimeout, onTimeout: () {});
    return connection.getLocalDescription();
  }

  Future<void> _resetPeer(_Peer peer, {bool keepRetries = false}) async {
    final connection = peer.connection;
    peer
      ..connection = null
      ..videoSender = null
      ..connected = false;
    if (!keepRetries) peer.retries = 0;
    await connection?.close();
    await peer.stream?.dispose();
    peer.stream = null;
  }

  Future<void> _closePeer(String pubkey) async {
    final peer = _peers.remove(pubkey);
    if (peer != null) await _resetPeer(peer);
    _emit();
  }

  @override
  Future<void> shareLobby({
    required String? layout,
    required List<String> seats,
    required int revision,
  }) async {
    if (_stopped) return;
    await _send(
      CollabRoomCallSignal(
        type: CollabRoomCallSignalType.lobby,
        from: _me,
        session: _session,
        micOn: _micOn,
        cameraOn: _video != null,
        layout: layout,
        seats: seats,
        revision: revision,
        sentAt: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  Future<void> _sendState() => _send(
    CollabRoomCallSignal(
      type: CollabRoomCallSignalType.state,
      from: _me,
      session: _session,
      micOn: _micOn,
      cameraOn: _video != null,
    ),
  );

  Future<void> _send(CollabRoomCallSignal signal) async {
    await _transport.publish(await _channel.seal(signal));
  }

  void _emit() {
    if (_changes.isClosed) return;
    _changes.add(
      CollabRoomCallSnapshot(
        micOn: _micOn,
        cameraOn: _video != null,
        localVideo: _video,
        peers: {
          for (final peer in _peers.values)
            if (_others.contains(peer.pubkey) && peer.session != null)
              peer.pubkey: CollabRoomCallPeer(
                pubkey: peer.pubkey,
                connected: peer.connected,
                micOn: peer.micOn,
                cameraOn: peer.cameraOn,
                stream: peer.stream,
              ),
        },
        lobby: _lobby,
      ),
    );
  }
}

class _Peer {
  _Peer(this.pubkey);

  final String pubkey;
  String? session;
  RTCPeerConnection? connection;
  RTCRtpSender? videoSender;
  MediaStream? stream;
  bool connected = false;
  bool micOn = true;
  bool cameraOn = false;
  int retries = 0;
}
