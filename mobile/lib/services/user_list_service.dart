// ABOUTME: Service for managing NIP-51 kind 30000 user/people lists
// ABOUTME: Handles creation, storage, and management of lists containing pubkeys

import 'dart:async';
import 'dart:convert';

import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a user list (NIP-51 kind 30000) containing pubkeys
class UserList {
  const UserList({
    required this.id,
    required this.name,
    required this.pubkeys,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.imageUrl,
    this.isPublic = true,
    this.nostrEventId,
    this.isEditable = true,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> pubkeys;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final String? nostrEventId;
  final bool isEditable; // false for Divine Team and other system lists

  UserList copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? pubkeys,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? nostrEventId,
    bool? isEditable,
  }) => UserList(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    pubkeys: pubkeys ?? this.pubkeys,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPublic: isPublic ?? this.isPublic,
    nostrEventId: nostrEventId ?? this.nostrEventId,
    isEditable: isEditable ?? this.isEditable,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'pubkeys': pubkeys,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPublic': isPublic,
    'nostrEventId': nostrEventId,
    'isEditable': isEditable,
  };

  static UserList fromJson(Map<String, dynamic> json) => UserList(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    imageUrl: json['imageUrl'],
    pubkeys: List<String>.from(json['pubkeys'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    isPublic: json['isPublic'] ?? true,
    nostrEventId: json['nostrEventId'],
    isEditable: json['isEditable'] ?? true,
  );
}

/// Service for managing NIP-51 kind 30000 user lists
class UserListService {
  UserListService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;
  static const String listsStorageKey = 'user_lists';

  final List<UserList> _userCreatedLists = [];
  bool _isInitialized = false;

  /// Get all lists (default + user-created)
  List<UserList> get lists => [..._defaultLists, ..._userCreatedLists];

  bool get isInitialized => _isInitialized;

  /// Static default lists baked into the app (not stored per-user)
  static final List<UserList> _defaultLists = [
    UserList(
      id: 'divine_team',
      name: 'Divine Team',
      description: 'Curated content from the diVine team',
      pubkeys: AppConstants.divineTeamPubkeys,
      createdAt: DateTime(2024, 1, 1), // Fixed date for default lists
      updatedAt: DateTime(2024, 1, 1),
      isPublic: true,
      isEditable: false, // Users cannot edit Divine Team
    ),
  ];

  /// Initialize service and load user-created lists
  Future<void> initialize() async {
    try {
      _loadUserCreatedLists();
      _isInitialized = true;
      Log.info(
        'User list service initialized with ${lists.length} total lists',
        name: 'UserListService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize user list service: $e',
        name: 'UserListService',
        category: LogCategory.system,
      );
    }
  }

  /// Get list by ID (checks both default and user-created)
  UserList? getListById(String listId) {
    try {
      return lists.firstWhere((list) => list.id == listId);
    } catch (e) {
      return null;
    }
  }

  /// Create a new user list
  Future<UserList?> createList({
    required String name,
    String? description,
    String? imageUrl,
    List<String> pubkeys = const [],
    bool isPublic = true,
  }) async {
    try {
      final listId = 'list_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final newList = UserList(
        id: listId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        pubkeys: pubkeys,
        createdAt: now,
        updatedAt: now,
        isPublic: isPublic,
        isEditable: true, // User-created lists are always editable
      );

      _userCreatedLists.add(newList);
      await _saveUserCreatedLists();

      Log.info(
        'Created new user list: $name ($listId)',
        name: 'UserListService',
        category: LogCategory.system,
      );

      return newList;
    } catch (e) {
      Log.error(
        'Failed to create user list: $e',
        name: 'UserListService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Add pubkey to a list
  Future<bool> addPubkeyToList(String listId, String pubkey) async {
    try {
      final listIndex = _userCreatedLists.indexWhere(
        (list) => list.id == listId,
      );
      if (listIndex == -1) {
        Log.warning(
          'List not found or not editable: $listId',
          name: 'UserListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _userCreatedLists[listIndex];
      if (!list.isEditable) {
        Log.warning(
          'Cannot edit non-editable list: $listId',
          name: 'UserListService',
          category: LogCategory.system,
        );
        return false;
      }

      // Check if pubkey is already in the list
      if (list.pubkeys.contains(pubkey)) {
        Log.warning(
          'Pubkey already in list: $pubkey',
          name: 'UserListService',
          category: LogCategory.system,
        );
        return true;
      }

      // Add pubkey to list
      final updatedPubkeys = [...list.pubkeys, pubkey];
      final updatedList = list.copyWith(
        pubkeys: updatedPubkeys,
        updatedAt: DateTime.now(),
      );

      _userCreatedLists[listIndex] = updatedList;
      await _saveUserCreatedLists();

      Log.debug(
        '➕ Added pubkey to list "${list.name}": $pubkey',
        name: 'UserListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to add pubkey to list: $e',
        name: 'UserListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove pubkey from a list
  Future<bool> removePubkeyFromList(String listId, String pubkey) async {
    try {
      final listIndex = _userCreatedLists.indexWhere(
        (list) => list.id == listId,
      );
      if (listIndex == -1) {
        Log.warning(
          'List not found or not editable: $listId',
          name: 'UserListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _userCreatedLists[listIndex];
      if (!list.isEditable) {
        Log.warning(
          'Cannot edit non-editable list: $listId',
          name: 'UserListService',
          category: LogCategory.system,
        );
        return false;
      }

      final updatedPubkeys = list.pubkeys.where((p) => p != pubkey).toList();

      final updatedList = list.copyWith(
        pubkeys: updatedPubkeys,
        updatedAt: DateTime.now(),
      );

      _userCreatedLists[listIndex] = updatedList;
      await _saveUserCreatedLists();

      Log.debug(
        '➖ Removed pubkey from list "${list.name}": $pubkey',
        name: 'UserListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to remove pubkey from list: $e',
        name: 'UserListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Delete a user-created list
  Future<bool> deleteList(String listId) async {
    try {
      final listIndex = _userCreatedLists.indexWhere(
        (list) => list.id == listId,
      );
      if (listIndex == -1) {
        return false;
      }

      final list = _userCreatedLists[listIndex];
      if (!list.isEditable) {
        Log.warning(
          'Cannot delete non-editable list: $listId',
          name: 'UserListService',
          category: LogCategory.system,
        );
        return false;
      }

      _userCreatedLists.removeAt(listIndex);
      await _saveUserCreatedLists();

      Log.debug(
        '🗑️ Deleted list: ${list.name}',
        name: 'UserListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to delete list: $e',
        name: 'UserListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Load user-created lists from local storage
  void _loadUserCreatedLists() {
    final listsJson = _prefs.getString(listsStorageKey);
    if (listsJson != null) {
      try {
        final List<dynamic> listsData = jsonDecode(listsJson);
        _userCreatedLists.clear();
        _userCreatedLists.addAll(
          listsData.map(
            (json) => UserList.fromJson(json as Map<String, dynamic>),
          ),
        );
        Log.debug(
          '📱 Loaded ${_userCreatedLists.length} user-created lists',
          name: 'UserListService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load user lists: $e',
          name: 'UserListService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save user-created lists to local storage
  Future<void> _saveUserCreatedLists() async {
    try {
      final listsJson = _userCreatedLists.map((list) => list.toJson()).toList();
      await _prefs.setString(listsStorageKey, jsonEncode(listsJson));
    } catch (e) {
      Log.error(
        'Failed to save user lists: $e',
        name: 'UserListService',
        category: LogCategory.system,
      );
    }
  }
}
