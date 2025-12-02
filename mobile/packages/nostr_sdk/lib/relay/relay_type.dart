class RelayType {
  static const int NORMAL = 1;

  static const int TEMP = 2;

  static const int LOCAL = 3;

  static const int CACHE = 4;

  static const List<int> CACHE_AND_LOCAL = [LOCAL, CACHE];

  static const List<int> ONLY_NORMAL = [NORMAL];

  static const List<int> ONLY_TEMP = [TEMP];

  static const List<int> ALL = [NORMAL, TEMP, LOCAL, CACHE];

  static const List<int> NETWORK = [NORMAL, TEMP];
}
