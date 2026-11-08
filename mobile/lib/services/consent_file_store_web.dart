// ABOUTME: Web has no native consent recordings to recover.
class ConsentFileStore {
  static final instance = ConsentFileStore();
  Future<String> createRecordingDirectory() =>
      throw UnsupportedError('Consent recording requires a native platform');
  Future<void> initialize() async {}
  Future<void> deleteClip(String path) async {}
}
