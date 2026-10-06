import 'package:equatable/equatable.dart';

sealed class LiveDiscoveryEvent extends Equatable {
  const LiveDiscoveryEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LiveDiscoveryRequested extends LiveDiscoveryEvent {
  const LiveDiscoveryRequested({this.force = false});

  final bool force;

  @override
  List<Object?> get props => <Object?>[force];
}
