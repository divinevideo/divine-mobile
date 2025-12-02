// ABOUTME: Configuration class for relay-specific settings
// ABOUTME: Allows customization of relay behavior like authentication requirements

class RelayConfig {
  final bool alwaysAuth;
  final bool writeAccess;
  final bool readAccess;

  const RelayConfig({
    this.alwaysAuth = false,
    this.writeAccess = true,
    this.readAccess = true,
  });

  RelayConfig copyWith({
    bool? alwaysAuth,
    bool? writeAccess,
    bool? readAccess,
  }) {
    return RelayConfig(
      alwaysAuth: alwaysAuth ?? this.alwaysAuth,
      writeAccess: writeAccess ?? this.writeAccess,
      readAccess: readAccess ?? this.readAccess,
    );
  }

  @override
  String toString() {
    return 'RelayConfig(alwaysAuth: $alwaysAuth, writeAccess: $writeAccess, readAccess: $readAccess)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelayConfig &&
        other.alwaysAuth == alwaysAuth &&
        other.writeAccess == writeAccess &&
        other.readAccess == readAccess;
  }

  @override
  int get hashCode {
    return alwaysAuth.hashCode ^ writeAccess.hashCode ^ readAccess.hashCode;
  }
}