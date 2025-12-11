// ABOUTME: SQLite-based local relay database for caching Nostr events.
// ABOUTME: Handles event storage, querying, and batch operations with indexing.

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:nostr_sdk/utils/db_util.dart';
import 'package:sqflite/sqflite.dart';

import '../event.dart';
import '../relay/event_filter.dart';
import '../utils/later_function.dart';
import '../utils/string_util.dart';
import 'relay_db_extral.dart';

class RelayLocalDB extends RelayDBExtral with LaterFunction {
  static const _version = 2;

  static const _dbName = "local_relay.db";

  late Database _database;

  // a eventId map in mem, to avoid alway insert event.
  final Map<String, int> _memEventIdMap = {};

  RelayLocalDB._(Database database, super.appName) {
    _database = database;
  }

  static Future<RelayLocalDB?> init(String appName) async {
    var path = await getFilepath(appName);
    log("path $path");

    var database = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: onUpgrade,
    );

    return RelayLocalDB._(database, appName);
  }

  static Future<String> getFilepath(String appName) async {
    return await DBUtil.getPath(appName, _dbName);
  }

  @override
  Future<int> getDBFileSize() async {
    var path = await getFilepath(appName);
    var file = File(path);
    return await file.length();
  }

  static Future<void> _onCreate(Database db, int version) async {
    log("db onCreate version $version");
    // init db
    await db.execute(
      "CREATE TABLE IF NOT EXISTS event (id text NOT NULL, pubkey text NOT NULL, created_at integer NOT NULL, kind integer NOT NULL, tags jsonb NOT NULL, content text NOT NULL, sig text NOT NULL, sources text);",
    );
    await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS ididx ON event(id)");
    // these version 1 index was delete since version 2
    // await db
    //     .execute("CREATE INDEX IF NOT EXISTS pubkeyprefix ON event(pubkey)");
    // await db.execute(
    //     "CREATE INDEX IF NOT EXISTS timeidx ON event(created_at DESC)");
    // await db.execute("CREATE INDEX IF NOT EXISTS kindidx ON event(kind)");
    // await db.execute(
    //     "CREATE INDEX IF NOT EXISTS kindtimeidx ON event(kind,created_at DESC)");
    // this index create since version 2
    await db.execute(
      "CREATE INDEX IF NOT EXISTS kindpubtimeidx ON event(kind,pubkey,created_at DESC)",
    );
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    log("onUpgrade oldVersion $oldVersion newVersion $newVersion");
    if (oldVersion == 1 && newVersion == 2) {
      log("onUpgrade begin! ${DateTime.now().toLocal()}");
      // delete old index
      await db.execute("DROP INDEX IF EXISTS pubkeyprefix ;");
      await db.execute("DROP INDEX IF EXISTS timeidx ;");
      await db.execute("DROP INDEX IF EXISTS kindidx ;");
      await db.execute("DROP INDEX IF EXISTS kindtimeidx ;");
      // create new index
      await db.execute(
        "CREATE INDEX IF NOT EXISTS kindpubtimeidx ON event(kind,pubkey,created_at DESC)",
      );
      log("onUpgrade complete! ${DateTime.now().toLocal()}");
    }
  }

  List<Event> loadEventFromMaps(
    List<Map<String, Object?>> rawEvents, {
    EventFilter? eventFilter,
  }) {
    List<Event> events = [];
    for (var rawEvent in rawEvents) {
      var event = Event.fromJson(rawEvent);

      if (eventFilter != null && eventFilter.check(event)) {
        continue;
      }

      var sources = rawEvent["sources"];
      if (sources != null && sources is List) {
        for (var source in sources) {
          event.sources.add(source);
        }
      }
      events.add(event);
    }
    return events;
  }

  bool checkAndSetEventFromMem(Map<String, dynamic> event) {
    var id = event["id"];
    var value = _memEventIdMap[id];
    _memEventIdMap[id] = 1;
    return value != null;
  }

  @override
  Future<void> deleteEventByKind(String pubkey, int eventKind) async {
    var sql = "delete from event where kind = ? and pubkey = ?";
    await _database.execute(sql, [eventKind, pubkey]);
  }

  @override
  Future<void> deleteEvent(String pubkey, String id) async {
    var sql = "delete from event where id = ? and pubkey = ?";
    await _database.execute(sql, [id, pubkey]);
  }

  List<Map<String, dynamic>> penddingEventMspList = [];

  @override
  Future<int> addEvent(Map<String, dynamic> event) async {
    if (checkAndSetEventFromMem(event)) {
      return 0;
    }

    // clone one, avoid change by others.
    event = Map.from(event);
    penddingEventMspList.add(event);
    later(_batchAddEvents);

    return 0;
  }

  Future<void> _batchAddEvents() async {
    var eventMapList = penddingEventMspList;
    penddingEventMspList = [];

    // check if exist
    List<String> ids = [];
    for (var eventMap in eventMapList) {
      var id = eventMap["id"];
      if (StringUtil.isNotBlank(id)) {
        ids.add(id);
      }
    }
    var existEventMapList = await doQueryEvent({"ids": ids, "limit": 10000});
    Map<Object, int> existIdMap = {};
    for (var existEventMap in existEventMapList) {
      var id = existEventMap["id"];
      if (id != null) {
        existIdMap[id] = 1;
      }
    }

    // not exist list
    List<Map<String, dynamic>> notExistEventMapList = [];
    for (var event in eventMapList) {
      var id = event["id"];
      if (StringUtil.isNotBlank(id) && existIdMap[id] == null) {
        // event not exist!!!

        // handle event info
        var tags = event["tags"];
        if (tags != null) {
          var tagsStr = jsonEncode(tags);
          event["tags"] = tagsStr;
        }
        var sources = event["sources"];
        if (sources != null) {
          var sourcesStr = jsonEncode(sources);
          event["sources"] = sourcesStr;
        }

        notExistEventMapList.add(event);
      }
    }

    if (notExistEventMapList.isNotEmpty) {
      try {
        var batch = _database.batch();
        for (var event in notExistEventMapList) {
          batch.insert("event", event);
        }
        batch.commit();
        // print("batch insert ${notExistEventMapList.length} events");
      } catch (e) {
        log('$e');
      }
    }
  }

  // Future<int> _doAddEvent(Map<String, dynamic> event) async {
  //   event = Map.from(event);
  //   var tags = event["tags"];
  //   if (tags != null) {
  //     var tagsStr = jsonEncode(tags);
  //     event["tags"] = tagsStr;
  //   }
  //   var sources = event["sources"];
  //   if (sources != null) {
  //     var sourcesStr = jsonEncode(sources);
  //     event["sources"] = sourcesStr;
  //   }
  //   try {
  //     return await _database.insert("event", event);
  //   } catch (e) {
  //     // print(e);
  //     return 0;
  //   }
  // }

  String makePlaceHolders(int n) {
    if (n == 1) {
      return "?";
    }

    return "${List.filled(n - 1, "?").join(",")},?";
  }

  @override
  Future<List<Map<String, Object?>>> doQueryEvent(
    Map<String, dynamic> filter,
  ) async {
    List<dynamic> params = [];
    var sql = queryEventsSql(filter, false, params);
    // print("doQueryEvent $sql $params");
    var rawEvents = await _database.rawQuery(sql, params);
    var events = _handleEventMaps(rawEvents);
    return events;
  }

  @override
  Future<int?> doQueryCount(Map<String, dynamic> filter) async {
    List<dynamic> params = [];
    var sql = queryEventsSql(filter, true, params);
    return Sqflite.firstIntValue(await _database.rawQuery(sql, params));
  }

  String queryEventsSql(
    Map<String, dynamic> filter,
    bool doCount,
    List<dynamic> params,
  ) {
    List<String> conditions = [];

    // clone filter, due to filter will be change download.
    filter = Map<String, dynamic>.from(filter);

    var key = "ids";
    if (filter[key] != null && filter[key] is List && filter[key].isNotEmpty) {
      for (var id in filter[key]) {
        params.add(id);
      }

      conditions.add("id IN(${makePlaceHolders(filter[key]!.length)})");

      filter.remove(key);
    }

    key = "authors";
    if (filter[key] != null && filter[key] is List && filter[key]!.isNotEmpty) {
      for (var author in filter[key]!) {
        params.add(author);
      }

      conditions.add("pubkey IN(${makePlaceHolders(filter[key]!.length)})");

      filter.remove(key);
    }

    key = "kinds";
    if (filter[key] != null && filter[key] is List && filter[key]!.isNotEmpty) {
      for (var kind in filter[key]!) {
        params.add(kind);
      }

      conditions.add("kind IN(${makePlaceHolders(filter[key]!.length)})");

      filter.remove(key);
    }

    var since = filter.remove("since");
    if (since != null) {
      conditions.add("created_at >= ?");
      params.add(since);
    }

    var until = filter.remove("until");
    if (until != null) {
      conditions.add("created_at <= ?");
      params.add(until);
    }

    var search = filter.remove("search");
    if (search != null && search is String) {
      conditions.add("content LIKE ? ESCAPE '\\'");
      params.add("%${search.replaceAll("%", "%")}%");
    }

    List<String> tagQueryConditions = [];
    List<String> tagQuery = [];
    for (var entry in filter.entries) {
      var k = entry.key;
      var v = entry.value;

      if (k != "limit") {
        for (var vItem in v) {
          tagQueryConditions.add("tags LIKE ? ESCAPE '\\'");
          tagQuery.add("${k.replaceFirst("#", "")}\",\"$vItem");
        }
      }
    }
    if (tagQueryConditions.length > 1) {
      conditions.add("( ${tagQueryConditions.join(" OR ")} )");
    } else if (tagQueryConditions.length == 1) {
      conditions.add(tagQueryConditions[0]);
    }
    for (var tagValue in tagQuery) {
      params.add("%${tagValue.replaceAll("%", "%")}%");
    }

    if (conditions.isEmpty) {
      // fallback
      conditions.add("true");
    }

    var limit = filter["limit"];
    if (limit != null && limit > 0) {
      params.add(limit);
    } else {
      params.add(100); // This is a default num.
    }

    late String query;
    if (doCount) {
      query =
          " SELECT COUNT(1) FROM event WHERE ${conditions.join(" AND ")} ORDER BY created_at DESC LIMIT ?";
    } else {
      query =
          " SELECT id, pubkey, created_at, kind, tags, content, sig, sources FROM event WHERE ${conditions.join(" AND ")} ORDER BY created_at DESC LIMIT ?";
    }

    // print("sql ${query}");
    // print("params ${jsonEncode(params)}");

    return query;
  }

  @override
  Future<List<Map<String, Object?>>> queryEventByPubkey(
    String pubkey, {
    List<int>? eventKinds,
  }) async {
    // print("queryEventByPubkey $pubkey $eventKinds");
    String kindsStr = "";
    if (eventKinds != null && eventKinds.isNotEmpty) {
      var length = eventKinds.length;
      for (var i = 0; i < length; i++) {
        kindsStr += "?";
        if (i < length - 1) {
          kindsStr += ",";
        }
      }

      kindsStr = " and kind in ($kindsStr) ";
    }

    var sql =
        "SELECT id, pubkey, created_at, kind, tags, content, sig, sources FROM event WHERE pubkey = ? $kindsStr ORDER BY created_at DESC";
    List<dynamic> params = [pubkey];
    if (eventKinds != null && eventKinds.isNotEmpty) {
      params.addAll(eventKinds);
    }
    var rawEvents = await _database.rawQuery(sql, params);
    var events = _handleEventMaps(rawEvents);
    return events;
  }

  List<Map<String, Object?>> _handleEventMaps(
    List<Map<String, Object?>> rawEvents,
  ) {
    var length = rawEvents.length;
    List<Map<String, Object?>> events = List.filled(length, {});
    for (var i = 0; i < length; i++) {
      var rawEvent = rawEvents[i];
      var event = Map<String, Object?>.from(rawEvent);
      var tagsStr = rawEvent["tags"];
      if (tagsStr is String) {
        event["tags"] = jsonDecode(tagsStr);
      }
      var sourcesStr = rawEvent["sources"];
      if (sourcesStr != null) {
        event["sources"] = jsonDecode(sourcesStr as String);
      }

      events[i] = event;
    }

    return events;
  }

  @override
  Future<int?> allDataCount() async {
    var sql = "select count(1) from event";
    return Sqflite.firstIntValue(await _database.rawQuery(sql, []));
  }

  @override
  Future<void> deleteData({String? pubkey}) async {
    List params = [];
    var sql = "delete from event where 1 = 1";
    if (StringUtil.isNotBlank(pubkey)) {
      sql += " and pubkey <> ?";
      params.add(pubkey);
    }
    await _database.execute(sql, params);
  }
}
