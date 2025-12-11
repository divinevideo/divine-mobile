// ABOUTME: Defines relay type constants for categorizing relay connections.
// ABOUTME: Used to distinguish normal, temporary, local, and cache relays.

class RelayType {
  static const int normal = 1;

  static const int temp = 2;

  static const int local = 3;

  static const int cache = 4;

  static const List<int> cacheAndLocal = [local, cache];

  static const List<int> onlyNormal = [normal];

  static const List<int> onlyTemp = [temp];

  static const List<int> all = [normal, temp, local, cache];

  static const List<int> network = [normal, temp];
}
