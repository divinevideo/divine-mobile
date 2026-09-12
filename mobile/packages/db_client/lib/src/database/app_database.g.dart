// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NostrEventsTable extends NostrEvents
    with TableInfo<$NostrEventsTable, NostrEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NostrEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sigMeta = const VerificationMeta('sig');
  @override
  late final GeneratedColumn<String> sig = GeneratedColumn<String>(
    'sig',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcesMeta = const VerificationMeta(
    'sources',
  );
  @override
  late final GeneratedColumn<String> sources = GeneratedColumn<String>(
    'sources',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expireAtMeta = const VerificationMeta(
    'expireAt',
  );
  @override
  late final GeneratedColumn<int> expireAt = GeneratedColumn<int>(
    'expire_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dTagMeta = const VerificationMeta('dTag');
  @override
  late final GeneratedColumn<String> dTag = GeneratedColumn<String>(
    'd_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pubkey,
    createdAt,
    kind,
    tags,
    content,
    sig,
    sources,
    expireAt,
    dTag,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event';
  @override
  VerificationContext validateIntegrity(
    Insertable<NostrEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('sig')) {
      context.handle(
        _sigMeta,
        sig.isAcceptableOrUnknown(data['sig']!, _sigMeta),
      );
    } else if (isInserting) {
      context.missing(_sigMeta);
    }
    if (data.containsKey('sources')) {
      context.handle(
        _sourcesMeta,
        sources.isAcceptableOrUnknown(data['sources']!, _sourcesMeta),
      );
    }
    if (data.containsKey('expire_at')) {
      context.handle(
        _expireAtMeta,
        expireAt.isAcceptableOrUnknown(data['expire_at']!, _expireAtMeta),
      );
    }
    if (data.containsKey('d_tag')) {
      context.handle(
        _dTagMeta,
        dTag.isAcceptableOrUnknown(data['d_tag']!, _dTagMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NostrEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NostrEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sig'],
      )!,
      sources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sources'],
      ),
      expireAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expire_at'],
      ),
      dTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}d_tag'],
      ),
    );
  }

  @override
  $NostrEventsTable createAlias(String alias) {
    return $NostrEventsTable(attachedDatabase, alias);
  }
}

class NostrEventRow extends DataClass implements Insertable<NostrEventRow> {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final String tags;
  final String content;
  final String sig;
  final String? sources;

  /// Unix timestamp when this cached event should be considered expired.
  /// Null means the event never expires. Used for cache eviction.
  final int? expireAt;

  /// Denormalized NIP-33 d-tag value for parameterized replaceable events
  /// (kind 30000-39999). Empty string when the event has no d-tag (per
  /// NIP-01); NULL for non-parameterized-replaceable kinds. Lets upserts
  /// find the existing version with an indexed lookup instead of decoding
  /// the tags JSON of every (pubkey, kind) row.
  final String? dTag;
  const NostrEventRow({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
    this.sources,
    this.expireAt,
    this.dTag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pubkey'] = Variable<String>(pubkey);
    map['created_at'] = Variable<int>(createdAt);
    map['kind'] = Variable<int>(kind);
    map['tags'] = Variable<String>(tags);
    map['content'] = Variable<String>(content);
    map['sig'] = Variable<String>(sig);
    if (!nullToAbsent || sources != null) {
      map['sources'] = Variable<String>(sources);
    }
    if (!nullToAbsent || expireAt != null) {
      map['expire_at'] = Variable<int>(expireAt);
    }
    if (!nullToAbsent || dTag != null) {
      map['d_tag'] = Variable<String>(dTag);
    }
    return map;
  }

  NostrEventsCompanion toCompanion(bool nullToAbsent) {
    return NostrEventsCompanion(
      id: Value(id),
      pubkey: Value(pubkey),
      createdAt: Value(createdAt),
      kind: Value(kind),
      tags: Value(tags),
      content: Value(content),
      sig: Value(sig),
      sources: sources == null && nullToAbsent
          ? const Value.absent()
          : Value(sources),
      expireAt: expireAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expireAt),
      dTag: dTag == null && nullToAbsent ? const Value.absent() : Value(dTag),
    );
  }

  factory NostrEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NostrEventRow(
      id: serializer.fromJson<String>(json['id']),
      pubkey: serializer.fromJson<String>(json['pubkey']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      kind: serializer.fromJson<int>(json['kind']),
      tags: serializer.fromJson<String>(json['tags']),
      content: serializer.fromJson<String>(json['content']),
      sig: serializer.fromJson<String>(json['sig']),
      sources: serializer.fromJson<String?>(json['sources']),
      expireAt: serializer.fromJson<int?>(json['expireAt']),
      dTag: serializer.fromJson<String?>(json['dTag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pubkey': serializer.toJson<String>(pubkey),
      'createdAt': serializer.toJson<int>(createdAt),
      'kind': serializer.toJson<int>(kind),
      'tags': serializer.toJson<String>(tags),
      'content': serializer.toJson<String>(content),
      'sig': serializer.toJson<String>(sig),
      'sources': serializer.toJson<String?>(sources),
      'expireAt': serializer.toJson<int?>(expireAt),
      'dTag': serializer.toJson<String?>(dTag),
    };
  }

  NostrEventRow copyWith({
    String? id,
    String? pubkey,
    int? createdAt,
    int? kind,
    String? tags,
    String? content,
    String? sig,
    Value<String?> sources = const Value.absent(),
    Value<int?> expireAt = const Value.absent(),
    Value<String?> dTag = const Value.absent(),
  }) => NostrEventRow(
    id: id ?? this.id,
    pubkey: pubkey ?? this.pubkey,
    createdAt: createdAt ?? this.createdAt,
    kind: kind ?? this.kind,
    tags: tags ?? this.tags,
    content: content ?? this.content,
    sig: sig ?? this.sig,
    sources: sources.present ? sources.value : this.sources,
    expireAt: expireAt.present ? expireAt.value : this.expireAt,
    dTag: dTag.present ? dTag.value : this.dTag,
  );
  NostrEventRow copyWithCompanion(NostrEventsCompanion data) {
    return NostrEventRow(
      id: data.id.present ? data.id.value : this.id,
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      tags: data.tags.present ? data.tags.value : this.tags,
      content: data.content.present ? data.content.value : this.content,
      sig: data.sig.present ? data.sig.value : this.sig,
      sources: data.sources.present ? data.sources.value : this.sources,
      expireAt: data.expireAt.present ? data.expireAt.value : this.expireAt,
      dTag: data.dTag.present ? data.dTag.value : this.dTag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NostrEventRow(')
          ..write('id: $id, ')
          ..write('pubkey: $pubkey, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind, ')
          ..write('tags: $tags, ')
          ..write('content: $content, ')
          ..write('sig: $sig, ')
          ..write('sources: $sources, ')
          ..write('expireAt: $expireAt, ')
          ..write('dTag: $dTag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pubkey,
    createdAt,
    kind,
    tags,
    content,
    sig,
    sources,
    expireAt,
    dTag,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NostrEventRow &&
          other.id == this.id &&
          other.pubkey == this.pubkey &&
          other.createdAt == this.createdAt &&
          other.kind == this.kind &&
          other.tags == this.tags &&
          other.content == this.content &&
          other.sig == this.sig &&
          other.sources == this.sources &&
          other.expireAt == this.expireAt &&
          other.dTag == this.dTag);
}

class NostrEventsCompanion extends UpdateCompanion<NostrEventRow> {
  final Value<String> id;
  final Value<String> pubkey;
  final Value<int> createdAt;
  final Value<int> kind;
  final Value<String> tags;
  final Value<String> content;
  final Value<String> sig;
  final Value<String?> sources;
  final Value<int?> expireAt;
  final Value<String?> dTag;
  final Value<int> rowid;
  const NostrEventsCompanion({
    this.id = const Value.absent(),
    this.pubkey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.tags = const Value.absent(),
    this.content = const Value.absent(),
    this.sig = const Value.absent(),
    this.sources = const Value.absent(),
    this.expireAt = const Value.absent(),
    this.dTag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NostrEventsCompanion.insert({
    required String id,
    required String pubkey,
    required int createdAt,
    required int kind,
    required String tags,
    required String content,
    required String sig,
    this.sources = const Value.absent(),
    this.expireAt = const Value.absent(),
    this.dTag = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pubkey = Value(pubkey),
       createdAt = Value(createdAt),
       kind = Value(kind),
       tags = Value(tags),
       content = Value(content),
       sig = Value(sig);
  static Insertable<NostrEventRow> custom({
    Expression<String>? id,
    Expression<String>? pubkey,
    Expression<int>? createdAt,
    Expression<int>? kind,
    Expression<String>? tags,
    Expression<String>? content,
    Expression<String>? sig,
    Expression<String>? sources,
    Expression<int>? expireAt,
    Expression<String>? dTag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pubkey != null) 'pubkey': pubkey,
      if (createdAt != null) 'created_at': createdAt,
      if (kind != null) 'kind': kind,
      if (tags != null) 'tags': tags,
      if (content != null) 'content': content,
      if (sig != null) 'sig': sig,
      if (sources != null) 'sources': sources,
      if (expireAt != null) 'expire_at': expireAt,
      if (dTag != null) 'd_tag': dTag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NostrEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? pubkey,
    Value<int>? createdAt,
    Value<int>? kind,
    Value<String>? tags,
    Value<String>? content,
    Value<String>? sig,
    Value<String?>? sources,
    Value<int?>? expireAt,
    Value<String?>? dTag,
    Value<int>? rowid,
  }) {
    return NostrEventsCompanion(
      id: id ?? this.id,
      pubkey: pubkey ?? this.pubkey,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
      tags: tags ?? this.tags,
      content: content ?? this.content,
      sig: sig ?? this.sig,
      sources: sources ?? this.sources,
      expireAt: expireAt ?? this.expireAt,
      dTag: dTag ?? this.dTag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sig.present) {
      map['sig'] = Variable<String>(sig.value);
    }
    if (sources.present) {
      map['sources'] = Variable<String>(sources.value);
    }
    if (expireAt.present) {
      map['expire_at'] = Variable<int>(expireAt.value);
    }
    if (dTag.present) {
      map['d_tag'] = Variable<String>(dTag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NostrEventsCompanion(')
          ..write('id: $id, ')
          ..write('pubkey: $pubkey, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind, ')
          ..write('tags: $tags, ')
          ..write('content: $content, ')
          ..write('sig: $sig, ')
          ..write('sources: $sources, ')
          ..write('expireAt: $expireAt, ')
          ..write('dTag: $dTag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aboutMeta = const VerificationMeta('about');
  @override
  late final GeneratedColumn<String> about = GeneratedColumn<String>(
    'about',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pictureMeta = const VerificationMeta(
    'picture',
  );
  @override
  late final GeneratedColumn<String> picture = GeneratedColumn<String>(
    'picture',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bannerMeta = const VerificationMeta('banner');
  @override
  late final GeneratedColumn<String> banner = GeneratedColumn<String>(
    'banner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _websiteMeta = const VerificationMeta(
    'website',
  );
  @override
  late final GeneratedColumn<String> website = GeneratedColumn<String>(
    'website',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nip05Meta = const VerificationMeta('nip05');
  @override
  late final GeneratedColumn<String> nip05 = GeneratedColumn<String>(
    'nip05',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lud16Meta = const VerificationMeta('lud16');
  @override
  late final GeneratedColumn<String> lud16 = GeneratedColumn<String>(
    'lud16',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lud06Meta = const VerificationMeta('lud06');
  @override
  late final GeneratedColumn<String> lud06 = GeneratedColumn<String>(
    'lud06',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawDataMeta = const VerificationMeta(
    'rawData',
  );
  @override
  late final GeneratedColumn<String> rawData = GeneratedColumn<String>(
    'raw_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastFetchedMeta = const VerificationMeta(
    'lastFetched',
  );
  @override
  late final GeneratedColumn<DateTime> lastFetched = GeneratedColumn<DateTime>(
    'last_fetched',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pubkey,
    displayName,
    name,
    about,
    picture,
    banner,
    website,
    nip05,
    lud16,
    lud06,
    rawData,
    createdAt,
    eventId,
    lastFetched,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('about')) {
      context.handle(
        _aboutMeta,
        about.isAcceptableOrUnknown(data['about']!, _aboutMeta),
      );
    }
    if (data.containsKey('picture')) {
      context.handle(
        _pictureMeta,
        picture.isAcceptableOrUnknown(data['picture']!, _pictureMeta),
      );
    }
    if (data.containsKey('banner')) {
      context.handle(
        _bannerMeta,
        banner.isAcceptableOrUnknown(data['banner']!, _bannerMeta),
      );
    }
    if (data.containsKey('website')) {
      context.handle(
        _websiteMeta,
        website.isAcceptableOrUnknown(data['website']!, _websiteMeta),
      );
    }
    if (data.containsKey('nip05')) {
      context.handle(
        _nip05Meta,
        nip05.isAcceptableOrUnknown(data['nip05']!, _nip05Meta),
      );
    }
    if (data.containsKey('lud16')) {
      context.handle(
        _lud16Meta,
        lud16.isAcceptableOrUnknown(data['lud16']!, _lud16Meta),
      );
    }
    if (data.containsKey('lud06')) {
      context.handle(
        _lud06Meta,
        lud06.isAcceptableOrUnknown(data['lud06']!, _lud06Meta),
      );
    }
    if (data.containsKey('raw_data')) {
      context.handle(
        _rawDataMeta,
        rawData.isAcceptableOrUnknown(data['raw_data']!, _rawDataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('last_fetched')) {
      context.handle(
        _lastFetchedMeta,
        lastFetched.isAcceptableOrUnknown(
          data['last_fetched']!,
          _lastFetchedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastFetchedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubkey};
  @override
  UserProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileRow(
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      about: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}about'],
      ),
      picture: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}picture'],
      ),
      banner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banner'],
      ),
      website: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website'],
      ),
      nip05: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nip05'],
      ),
      lud16: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lud16'],
      ),
      lud06: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lud06'],
      ),
      rawData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_data'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      lastFetched: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_fetched'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfileRow extends DataClass implements Insertable<UserProfileRow> {
  final String pubkey;
  final String? displayName;
  final String? name;
  final String? about;
  final String? picture;
  final String? banner;
  final String? website;
  final String? nip05;
  final String? lud16;
  final String? lud06;
  final String? rawData;
  final DateTime createdAt;
  final String eventId;
  final DateTime lastFetched;
  const UserProfileRow({
    required this.pubkey,
    this.displayName,
    this.name,
    this.about,
    this.picture,
    this.banner,
    this.website,
    this.nip05,
    this.lud16,
    this.lud06,
    this.rawData,
    required this.createdAt,
    required this.eventId,
    required this.lastFetched,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey'] = Variable<String>(pubkey);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || about != null) {
      map['about'] = Variable<String>(about);
    }
    if (!nullToAbsent || picture != null) {
      map['picture'] = Variable<String>(picture);
    }
    if (!nullToAbsent || banner != null) {
      map['banner'] = Variable<String>(banner);
    }
    if (!nullToAbsent || website != null) {
      map['website'] = Variable<String>(website);
    }
    if (!nullToAbsent || nip05 != null) {
      map['nip05'] = Variable<String>(nip05);
    }
    if (!nullToAbsent || lud16 != null) {
      map['lud16'] = Variable<String>(lud16);
    }
    if (!nullToAbsent || lud06 != null) {
      map['lud06'] = Variable<String>(lud06);
    }
    if (!nullToAbsent || rawData != null) {
      map['raw_data'] = Variable<String>(rawData);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['event_id'] = Variable<String>(eventId);
    map['last_fetched'] = Variable<DateTime>(lastFetched);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      pubkey: Value(pubkey),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      about: about == null && nullToAbsent
          ? const Value.absent()
          : Value(about),
      picture: picture == null && nullToAbsent
          ? const Value.absent()
          : Value(picture),
      banner: banner == null && nullToAbsent
          ? const Value.absent()
          : Value(banner),
      website: website == null && nullToAbsent
          ? const Value.absent()
          : Value(website),
      nip05: nip05 == null && nullToAbsent
          ? const Value.absent()
          : Value(nip05),
      lud16: lud16 == null && nullToAbsent
          ? const Value.absent()
          : Value(lud16),
      lud06: lud06 == null && nullToAbsent
          ? const Value.absent()
          : Value(lud06),
      rawData: rawData == null && nullToAbsent
          ? const Value.absent()
          : Value(rawData),
      createdAt: Value(createdAt),
      eventId: Value(eventId),
      lastFetched: Value(lastFetched),
    );
  }

  factory UserProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileRow(
      pubkey: serializer.fromJson<String>(json['pubkey']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      name: serializer.fromJson<String?>(json['name']),
      about: serializer.fromJson<String?>(json['about']),
      picture: serializer.fromJson<String?>(json['picture']),
      banner: serializer.fromJson<String?>(json['banner']),
      website: serializer.fromJson<String?>(json['website']),
      nip05: serializer.fromJson<String?>(json['nip05']),
      lud16: serializer.fromJson<String?>(json['lud16']),
      lud06: serializer.fromJson<String?>(json['lud06']),
      rawData: serializer.fromJson<String?>(json['rawData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      eventId: serializer.fromJson<String>(json['eventId']),
      lastFetched: serializer.fromJson<DateTime>(json['lastFetched']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkey': serializer.toJson<String>(pubkey),
      'displayName': serializer.toJson<String?>(displayName),
      'name': serializer.toJson<String?>(name),
      'about': serializer.toJson<String?>(about),
      'picture': serializer.toJson<String?>(picture),
      'banner': serializer.toJson<String?>(banner),
      'website': serializer.toJson<String?>(website),
      'nip05': serializer.toJson<String?>(nip05),
      'lud16': serializer.toJson<String?>(lud16),
      'lud06': serializer.toJson<String?>(lud06),
      'rawData': serializer.toJson<String?>(rawData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'eventId': serializer.toJson<String>(eventId),
      'lastFetched': serializer.toJson<DateTime>(lastFetched),
    };
  }

  UserProfileRow copyWith({
    String? pubkey,
    Value<String?> displayName = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> about = const Value.absent(),
    Value<String?> picture = const Value.absent(),
    Value<String?> banner = const Value.absent(),
    Value<String?> website = const Value.absent(),
    Value<String?> nip05 = const Value.absent(),
    Value<String?> lud16 = const Value.absent(),
    Value<String?> lud06 = const Value.absent(),
    Value<String?> rawData = const Value.absent(),
    DateTime? createdAt,
    String? eventId,
    DateTime? lastFetched,
  }) => UserProfileRow(
    pubkey: pubkey ?? this.pubkey,
    displayName: displayName.present ? displayName.value : this.displayName,
    name: name.present ? name.value : this.name,
    about: about.present ? about.value : this.about,
    picture: picture.present ? picture.value : this.picture,
    banner: banner.present ? banner.value : this.banner,
    website: website.present ? website.value : this.website,
    nip05: nip05.present ? nip05.value : this.nip05,
    lud16: lud16.present ? lud16.value : this.lud16,
    lud06: lud06.present ? lud06.value : this.lud06,
    rawData: rawData.present ? rawData.value : this.rawData,
    createdAt: createdAt ?? this.createdAt,
    eventId: eventId ?? this.eventId,
    lastFetched: lastFetched ?? this.lastFetched,
  );
  UserProfileRow copyWithCompanion(UserProfilesCompanion data) {
    return UserProfileRow(
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      name: data.name.present ? data.name.value : this.name,
      about: data.about.present ? data.about.value : this.about,
      picture: data.picture.present ? data.picture.value : this.picture,
      banner: data.banner.present ? data.banner.value : this.banner,
      website: data.website.present ? data.website.value : this.website,
      nip05: data.nip05.present ? data.nip05.value : this.nip05,
      lud16: data.lud16.present ? data.lud16.value : this.lud16,
      lud06: data.lud06.present ? data.lud06.value : this.lud06,
      rawData: data.rawData.present ? data.rawData.value : this.rawData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      lastFetched: data.lastFetched.present
          ? data.lastFetched.value
          : this.lastFetched,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileRow(')
          ..write('pubkey: $pubkey, ')
          ..write('displayName: $displayName, ')
          ..write('name: $name, ')
          ..write('about: $about, ')
          ..write('picture: $picture, ')
          ..write('banner: $banner, ')
          ..write('website: $website, ')
          ..write('nip05: $nip05, ')
          ..write('lud16: $lud16, ')
          ..write('lud06: $lud06, ')
          ..write('rawData: $rawData, ')
          ..write('createdAt: $createdAt, ')
          ..write('eventId: $eventId, ')
          ..write('lastFetched: $lastFetched')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pubkey,
    displayName,
    name,
    about,
    picture,
    banner,
    website,
    nip05,
    lud16,
    lud06,
    rawData,
    createdAt,
    eventId,
    lastFetched,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileRow &&
          other.pubkey == this.pubkey &&
          other.displayName == this.displayName &&
          other.name == this.name &&
          other.about == this.about &&
          other.picture == this.picture &&
          other.banner == this.banner &&
          other.website == this.website &&
          other.nip05 == this.nip05 &&
          other.lud16 == this.lud16 &&
          other.lud06 == this.lud06 &&
          other.rawData == this.rawData &&
          other.createdAt == this.createdAt &&
          other.eventId == this.eventId &&
          other.lastFetched == this.lastFetched);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfileRow> {
  final Value<String> pubkey;
  final Value<String?> displayName;
  final Value<String?> name;
  final Value<String?> about;
  final Value<String?> picture;
  final Value<String?> banner;
  final Value<String?> website;
  final Value<String?> nip05;
  final Value<String?> lud16;
  final Value<String?> lud06;
  final Value<String?> rawData;
  final Value<DateTime> createdAt;
  final Value<String> eventId;
  final Value<DateTime> lastFetched;
  final Value<int> rowid;
  const UserProfilesCompanion({
    this.pubkey = const Value.absent(),
    this.displayName = const Value.absent(),
    this.name = const Value.absent(),
    this.about = const Value.absent(),
    this.picture = const Value.absent(),
    this.banner = const Value.absent(),
    this.website = const Value.absent(),
    this.nip05 = const Value.absent(),
    this.lud16 = const Value.absent(),
    this.lud06 = const Value.absent(),
    this.rawData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.eventId = const Value.absent(),
    this.lastFetched = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    required String pubkey,
    this.displayName = const Value.absent(),
    this.name = const Value.absent(),
    this.about = const Value.absent(),
    this.picture = const Value.absent(),
    this.banner = const Value.absent(),
    this.website = const Value.absent(),
    this.nip05 = const Value.absent(),
    this.lud16 = const Value.absent(),
    this.lud06 = const Value.absent(),
    this.rawData = const Value.absent(),
    required DateTime createdAt,
    required String eventId,
    required DateTime lastFetched,
    this.rowid = const Value.absent(),
  }) : pubkey = Value(pubkey),
       createdAt = Value(createdAt),
       eventId = Value(eventId),
       lastFetched = Value(lastFetched);
  static Insertable<UserProfileRow> custom({
    Expression<String>? pubkey,
    Expression<String>? displayName,
    Expression<String>? name,
    Expression<String>? about,
    Expression<String>? picture,
    Expression<String>? banner,
    Expression<String>? website,
    Expression<String>? nip05,
    Expression<String>? lud16,
    Expression<String>? lud06,
    Expression<String>? rawData,
    Expression<DateTime>? createdAt,
    Expression<String>? eventId,
    Expression<DateTime>? lastFetched,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkey != null) 'pubkey': pubkey,
      if (displayName != null) 'display_name': displayName,
      if (name != null) 'name': name,
      if (about != null) 'about': about,
      if (picture != null) 'picture': picture,
      if (banner != null) 'banner': banner,
      if (website != null) 'website': website,
      if (nip05 != null) 'nip05': nip05,
      if (lud16 != null) 'lud16': lud16,
      if (lud06 != null) 'lud06': lud06,
      if (rawData != null) 'raw_data': rawData,
      if (createdAt != null) 'created_at': createdAt,
      if (eventId != null) 'event_id': eventId,
      if (lastFetched != null) 'last_fetched': lastFetched,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesCompanion copyWith({
    Value<String>? pubkey,
    Value<String?>? displayName,
    Value<String?>? name,
    Value<String?>? about,
    Value<String?>? picture,
    Value<String?>? banner,
    Value<String?>? website,
    Value<String?>? nip05,
    Value<String?>? lud16,
    Value<String?>? lud06,
    Value<String?>? rawData,
    Value<DateTime>? createdAt,
    Value<String>? eventId,
    Value<DateTime>? lastFetched,
    Value<int>? rowid,
  }) {
    return UserProfilesCompanion(
      pubkey: pubkey ?? this.pubkey,
      displayName: displayName ?? this.displayName,
      name: name ?? this.name,
      about: about ?? this.about,
      picture: picture ?? this.picture,
      banner: banner ?? this.banner,
      website: website ?? this.website,
      nip05: nip05 ?? this.nip05,
      lud16: lud16 ?? this.lud16,
      lud06: lud06 ?? this.lud06,
      rawData: rawData ?? this.rawData,
      createdAt: createdAt ?? this.createdAt,
      eventId: eventId ?? this.eventId,
      lastFetched: lastFetched ?? this.lastFetched,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (about.present) {
      map['about'] = Variable<String>(about.value);
    }
    if (picture.present) {
      map['picture'] = Variable<String>(picture.value);
    }
    if (banner.present) {
      map['banner'] = Variable<String>(banner.value);
    }
    if (website.present) {
      map['website'] = Variable<String>(website.value);
    }
    if (nip05.present) {
      map['nip05'] = Variable<String>(nip05.value);
    }
    if (lud16.present) {
      map['lud16'] = Variable<String>(lud16.value);
    }
    if (lud06.present) {
      map['lud06'] = Variable<String>(lud06.value);
    }
    if (rawData.present) {
      map['raw_data'] = Variable<String>(rawData.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (lastFetched.present) {
      map['last_fetched'] = Variable<DateTime>(lastFetched.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('pubkey: $pubkey, ')
          ..write('displayName: $displayName, ')
          ..write('name: $name, ')
          ..write('about: $about, ')
          ..write('picture: $picture, ')
          ..write('banner: $banner, ')
          ..write('website: $website, ')
          ..write('nip05: $nip05, ')
          ..write('lud16: $lud16, ')
          ..write('lud06: $lud06, ')
          ..write('rawData: $rawData, ')
          ..write('createdAt: $createdAt, ')
          ..write('eventId: $eventId, ')
          ..write('lastFetched: $lastFetched, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VideoMetricsTable extends VideoMetrics
    with TableInfo<$VideoMetricsTable, VideoMetricRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VideoMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loopCountMeta = const VerificationMeta(
    'loopCount',
  );
  @override
  late final GeneratedColumn<int> loopCount = GeneratedColumn<int>(
    'loop_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _likesMeta = const VerificationMeta('likes');
  @override
  late final GeneratedColumn<int> likes = GeneratedColumn<int>(
    'likes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewsMeta = const VerificationMeta('views');
  @override
  late final GeneratedColumn<int> views = GeneratedColumn<int>(
    'views',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentsMeta = const VerificationMeta(
    'comments',
  );
  @override
  late final GeneratedColumn<int> comments = GeneratedColumn<int>(
    'comments',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgCompletionMeta = const VerificationMeta(
    'avgCompletion',
  );
  @override
  late final GeneratedColumn<double> avgCompletion = GeneratedColumn<double>(
    'avg_completion',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasProofmodeMeta = const VerificationMeta(
    'hasProofmode',
  );
  @override
  late final GeneratedColumn<int> hasProofmode = GeneratedColumn<int>(
    'has_proofmode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasDeviceAttestationMeta =
      const VerificationMeta('hasDeviceAttestation');
  @override
  late final GeneratedColumn<int> hasDeviceAttestation = GeneratedColumn<int>(
    'has_device_attestation',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasPgpSignatureMeta = const VerificationMeta(
    'hasPgpSignature',
  );
  @override
  late final GeneratedColumn<int> hasPgpSignature = GeneratedColumn<int>(
    'has_pgp_signature',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    loopCount,
    likes,
    views,
    comments,
    avgCompletion,
    hasProofmode,
    hasDeviceAttestation,
    hasPgpSignature,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'video_metrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<VideoMetricRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('loop_count')) {
      context.handle(
        _loopCountMeta,
        loopCount.isAcceptableOrUnknown(data['loop_count']!, _loopCountMeta),
      );
    }
    if (data.containsKey('likes')) {
      context.handle(
        _likesMeta,
        likes.isAcceptableOrUnknown(data['likes']!, _likesMeta),
      );
    }
    if (data.containsKey('views')) {
      context.handle(
        _viewsMeta,
        views.isAcceptableOrUnknown(data['views']!, _viewsMeta),
      );
    }
    if (data.containsKey('comments')) {
      context.handle(
        _commentsMeta,
        comments.isAcceptableOrUnknown(data['comments']!, _commentsMeta),
      );
    }
    if (data.containsKey('avg_completion')) {
      context.handle(
        _avgCompletionMeta,
        avgCompletion.isAcceptableOrUnknown(
          data['avg_completion']!,
          _avgCompletionMeta,
        ),
      );
    }
    if (data.containsKey('has_proofmode')) {
      context.handle(
        _hasProofmodeMeta,
        hasProofmode.isAcceptableOrUnknown(
          data['has_proofmode']!,
          _hasProofmodeMeta,
        ),
      );
    }
    if (data.containsKey('has_device_attestation')) {
      context.handle(
        _hasDeviceAttestationMeta,
        hasDeviceAttestation.isAcceptableOrUnknown(
          data['has_device_attestation']!,
          _hasDeviceAttestationMeta,
        ),
      );
    }
    if (data.containsKey('has_pgp_signature')) {
      context.handle(
        _hasPgpSignatureMeta,
        hasPgpSignature.isAcceptableOrUnknown(
          data['has_pgp_signature']!,
          _hasPgpSignatureMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  VideoMetricRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VideoMetricRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      loopCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loop_count'],
      ),
      likes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}likes'],
      ),
      views: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}views'],
      ),
      comments: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}comments'],
      ),
      avgCompletion: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_completion'],
      ),
      hasProofmode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}has_proofmode'],
      ),
      hasDeviceAttestation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}has_device_attestation'],
      ),
      hasPgpSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}has_pgp_signature'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VideoMetricsTable createAlias(String alias) {
    return $VideoMetricsTable(attachedDatabase, alias);
  }
}

class VideoMetricRow extends DataClass implements Insertable<VideoMetricRow> {
  final String eventId;
  final int? loopCount;
  final int? likes;
  final int? views;
  final int? comments;
  final double? avgCompletion;
  final int? hasProofmode;
  final int? hasDeviceAttestation;
  final int? hasPgpSignature;
  final DateTime updatedAt;
  const VideoMetricRow({
    required this.eventId,
    this.loopCount,
    this.likes,
    this.views,
    this.comments,
    this.avgCompletion,
    this.hasProofmode,
    this.hasDeviceAttestation,
    this.hasPgpSignature,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    if (!nullToAbsent || loopCount != null) {
      map['loop_count'] = Variable<int>(loopCount);
    }
    if (!nullToAbsent || likes != null) {
      map['likes'] = Variable<int>(likes);
    }
    if (!nullToAbsent || views != null) {
      map['views'] = Variable<int>(views);
    }
    if (!nullToAbsent || comments != null) {
      map['comments'] = Variable<int>(comments);
    }
    if (!nullToAbsent || avgCompletion != null) {
      map['avg_completion'] = Variable<double>(avgCompletion);
    }
    if (!nullToAbsent || hasProofmode != null) {
      map['has_proofmode'] = Variable<int>(hasProofmode);
    }
    if (!nullToAbsent || hasDeviceAttestation != null) {
      map['has_device_attestation'] = Variable<int>(hasDeviceAttestation);
    }
    if (!nullToAbsent || hasPgpSignature != null) {
      map['has_pgp_signature'] = Variable<int>(hasPgpSignature);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VideoMetricsCompanion toCompanion(bool nullToAbsent) {
    return VideoMetricsCompanion(
      eventId: Value(eventId),
      loopCount: loopCount == null && nullToAbsent
          ? const Value.absent()
          : Value(loopCount),
      likes: likes == null && nullToAbsent
          ? const Value.absent()
          : Value(likes),
      views: views == null && nullToAbsent
          ? const Value.absent()
          : Value(views),
      comments: comments == null && nullToAbsent
          ? const Value.absent()
          : Value(comments),
      avgCompletion: avgCompletion == null && nullToAbsent
          ? const Value.absent()
          : Value(avgCompletion),
      hasProofmode: hasProofmode == null && nullToAbsent
          ? const Value.absent()
          : Value(hasProofmode),
      hasDeviceAttestation: hasDeviceAttestation == null && nullToAbsent
          ? const Value.absent()
          : Value(hasDeviceAttestation),
      hasPgpSignature: hasPgpSignature == null && nullToAbsent
          ? const Value.absent()
          : Value(hasPgpSignature),
      updatedAt: Value(updatedAt),
    );
  }

  factory VideoMetricRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VideoMetricRow(
      eventId: serializer.fromJson<String>(json['eventId']),
      loopCount: serializer.fromJson<int?>(json['loopCount']),
      likes: serializer.fromJson<int?>(json['likes']),
      views: serializer.fromJson<int?>(json['views']),
      comments: serializer.fromJson<int?>(json['comments']),
      avgCompletion: serializer.fromJson<double?>(json['avgCompletion']),
      hasProofmode: serializer.fromJson<int?>(json['hasProofmode']),
      hasDeviceAttestation: serializer.fromJson<int?>(
        json['hasDeviceAttestation'],
      ),
      hasPgpSignature: serializer.fromJson<int?>(json['hasPgpSignature']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'loopCount': serializer.toJson<int?>(loopCount),
      'likes': serializer.toJson<int?>(likes),
      'views': serializer.toJson<int?>(views),
      'comments': serializer.toJson<int?>(comments),
      'avgCompletion': serializer.toJson<double?>(avgCompletion),
      'hasProofmode': serializer.toJson<int?>(hasProofmode),
      'hasDeviceAttestation': serializer.toJson<int?>(hasDeviceAttestation),
      'hasPgpSignature': serializer.toJson<int?>(hasPgpSignature),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VideoMetricRow copyWith({
    String? eventId,
    Value<int?> loopCount = const Value.absent(),
    Value<int?> likes = const Value.absent(),
    Value<int?> views = const Value.absent(),
    Value<int?> comments = const Value.absent(),
    Value<double?> avgCompletion = const Value.absent(),
    Value<int?> hasProofmode = const Value.absent(),
    Value<int?> hasDeviceAttestation = const Value.absent(),
    Value<int?> hasPgpSignature = const Value.absent(),
    DateTime? updatedAt,
  }) => VideoMetricRow(
    eventId: eventId ?? this.eventId,
    loopCount: loopCount.present ? loopCount.value : this.loopCount,
    likes: likes.present ? likes.value : this.likes,
    views: views.present ? views.value : this.views,
    comments: comments.present ? comments.value : this.comments,
    avgCompletion: avgCompletion.present
        ? avgCompletion.value
        : this.avgCompletion,
    hasProofmode: hasProofmode.present ? hasProofmode.value : this.hasProofmode,
    hasDeviceAttestation: hasDeviceAttestation.present
        ? hasDeviceAttestation.value
        : this.hasDeviceAttestation,
    hasPgpSignature: hasPgpSignature.present
        ? hasPgpSignature.value
        : this.hasPgpSignature,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VideoMetricRow copyWithCompanion(VideoMetricsCompanion data) {
    return VideoMetricRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      loopCount: data.loopCount.present ? data.loopCount.value : this.loopCount,
      likes: data.likes.present ? data.likes.value : this.likes,
      views: data.views.present ? data.views.value : this.views,
      comments: data.comments.present ? data.comments.value : this.comments,
      avgCompletion: data.avgCompletion.present
          ? data.avgCompletion.value
          : this.avgCompletion,
      hasProofmode: data.hasProofmode.present
          ? data.hasProofmode.value
          : this.hasProofmode,
      hasDeviceAttestation: data.hasDeviceAttestation.present
          ? data.hasDeviceAttestation.value
          : this.hasDeviceAttestation,
      hasPgpSignature: data.hasPgpSignature.present
          ? data.hasPgpSignature.value
          : this.hasPgpSignature,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VideoMetricRow(')
          ..write('eventId: $eventId, ')
          ..write('loopCount: $loopCount, ')
          ..write('likes: $likes, ')
          ..write('views: $views, ')
          ..write('comments: $comments, ')
          ..write('avgCompletion: $avgCompletion, ')
          ..write('hasProofmode: $hasProofmode, ')
          ..write('hasDeviceAttestation: $hasDeviceAttestation, ')
          ..write('hasPgpSignature: $hasPgpSignature, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    loopCount,
    likes,
    views,
    comments,
    avgCompletion,
    hasProofmode,
    hasDeviceAttestation,
    hasPgpSignature,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoMetricRow &&
          other.eventId == this.eventId &&
          other.loopCount == this.loopCount &&
          other.likes == this.likes &&
          other.views == this.views &&
          other.comments == this.comments &&
          other.avgCompletion == this.avgCompletion &&
          other.hasProofmode == this.hasProofmode &&
          other.hasDeviceAttestation == this.hasDeviceAttestation &&
          other.hasPgpSignature == this.hasPgpSignature &&
          other.updatedAt == this.updatedAt);
}

class VideoMetricsCompanion extends UpdateCompanion<VideoMetricRow> {
  final Value<String> eventId;
  final Value<int?> loopCount;
  final Value<int?> likes;
  final Value<int?> views;
  final Value<int?> comments;
  final Value<double?> avgCompletion;
  final Value<int?> hasProofmode;
  final Value<int?> hasDeviceAttestation;
  final Value<int?> hasPgpSignature;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const VideoMetricsCompanion({
    this.eventId = const Value.absent(),
    this.loopCount = const Value.absent(),
    this.likes = const Value.absent(),
    this.views = const Value.absent(),
    this.comments = const Value.absent(),
    this.avgCompletion = const Value.absent(),
    this.hasProofmode = const Value.absent(),
    this.hasDeviceAttestation = const Value.absent(),
    this.hasPgpSignature = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VideoMetricsCompanion.insert({
    required String eventId,
    this.loopCount = const Value.absent(),
    this.likes = const Value.absent(),
    this.views = const Value.absent(),
    this.comments = const Value.absent(),
    this.avgCompletion = const Value.absent(),
    this.hasProofmode = const Value.absent(),
    this.hasDeviceAttestation = const Value.absent(),
    this.hasPgpSignature = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       updatedAt = Value(updatedAt);
  static Insertable<VideoMetricRow> custom({
    Expression<String>? eventId,
    Expression<int>? loopCount,
    Expression<int>? likes,
    Expression<int>? views,
    Expression<int>? comments,
    Expression<double>? avgCompletion,
    Expression<int>? hasProofmode,
    Expression<int>? hasDeviceAttestation,
    Expression<int>? hasPgpSignature,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (loopCount != null) 'loop_count': loopCount,
      if (likes != null) 'likes': likes,
      if (views != null) 'views': views,
      if (comments != null) 'comments': comments,
      if (avgCompletion != null) 'avg_completion': avgCompletion,
      if (hasProofmode != null) 'has_proofmode': hasProofmode,
      if (hasDeviceAttestation != null)
        'has_device_attestation': hasDeviceAttestation,
      if (hasPgpSignature != null) 'has_pgp_signature': hasPgpSignature,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VideoMetricsCompanion copyWith({
    Value<String>? eventId,
    Value<int?>? loopCount,
    Value<int?>? likes,
    Value<int?>? views,
    Value<int?>? comments,
    Value<double?>? avgCompletion,
    Value<int?>? hasProofmode,
    Value<int?>? hasDeviceAttestation,
    Value<int?>? hasPgpSignature,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return VideoMetricsCompanion(
      eventId: eventId ?? this.eventId,
      loopCount: loopCount ?? this.loopCount,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      comments: comments ?? this.comments,
      avgCompletion: avgCompletion ?? this.avgCompletion,
      hasProofmode: hasProofmode ?? this.hasProofmode,
      hasDeviceAttestation: hasDeviceAttestation ?? this.hasDeviceAttestation,
      hasPgpSignature: hasPgpSignature ?? this.hasPgpSignature,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (loopCount.present) {
      map['loop_count'] = Variable<int>(loopCount.value);
    }
    if (likes.present) {
      map['likes'] = Variable<int>(likes.value);
    }
    if (views.present) {
      map['views'] = Variable<int>(views.value);
    }
    if (comments.present) {
      map['comments'] = Variable<int>(comments.value);
    }
    if (avgCompletion.present) {
      map['avg_completion'] = Variable<double>(avgCompletion.value);
    }
    if (hasProofmode.present) {
      map['has_proofmode'] = Variable<int>(hasProofmode.value);
    }
    if (hasDeviceAttestation.present) {
      map['has_device_attestation'] = Variable<int>(hasDeviceAttestation.value);
    }
    if (hasPgpSignature.present) {
      map['has_pgp_signature'] = Variable<int>(hasPgpSignature.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VideoMetricsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('loopCount: $loopCount, ')
          ..write('likes: $likes, ')
          ..write('views: $views, ')
          ..write('comments: $comments, ')
          ..write('avgCompletion: $avgCompletion, ')
          ..write('hasProofmode: $hasProofmode, ')
          ..write('hasDeviceAttestation: $hasDeviceAttestation, ')
          ..write('hasPgpSignature: $hasPgpSignature, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfileStatsTable extends ProfileStats
    with TableInfo<$ProfileStatsTable, ProfileStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoCountMeta = const VerificationMeta(
    'videoCount',
  );
  @override
  late final GeneratedColumn<int> videoCount = GeneratedColumn<int>(
    'video_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followerCountMeta = const VerificationMeta(
    'followerCount',
  );
  @override
  late final GeneratedColumn<int> followerCount = GeneratedColumn<int>(
    'follower_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followingCountMeta = const VerificationMeta(
    'followingCount',
  );
  @override
  late final GeneratedColumn<int> followingCount = GeneratedColumn<int>(
    'following_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalViewsMeta = const VerificationMeta(
    'totalViews',
  );
  @override
  late final GeneratedColumn<int> totalViews = GeneratedColumn<int>(
    'total_views',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalLikesMeta = const VerificationMeta(
    'totalLikes',
  );
  @override
  late final GeneratedColumn<int> totalLikes = GeneratedColumn<int>(
    'total_likes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _followerCountsUpdatedAtMeta =
      const VerificationMeta('followerCountsUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> followerCountsUpdatedAt =
      GeneratedColumn<DateTime>(
        'follower_counts_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    pubkey,
    videoCount,
    followerCount,
    followingCount,
    totalViews,
    totalLikes,
    cachedAt,
    followerCountsUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile_statistics';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('video_count')) {
      context.handle(
        _videoCountMeta,
        videoCount.isAcceptableOrUnknown(data['video_count']!, _videoCountMeta),
      );
    }
    if (data.containsKey('follower_count')) {
      context.handle(
        _followerCountMeta,
        followerCount.isAcceptableOrUnknown(
          data['follower_count']!,
          _followerCountMeta,
        ),
      );
    }
    if (data.containsKey('following_count')) {
      context.handle(
        _followingCountMeta,
        followingCount.isAcceptableOrUnknown(
          data['following_count']!,
          _followingCountMeta,
        ),
      );
    }
    if (data.containsKey('total_views')) {
      context.handle(
        _totalViewsMeta,
        totalViews.isAcceptableOrUnknown(data['total_views']!, _totalViewsMeta),
      );
    }
    if (data.containsKey('total_likes')) {
      context.handle(
        _totalLikesMeta,
        totalLikes.isAcceptableOrUnknown(data['total_likes']!, _totalLikesMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('follower_counts_updated_at')) {
      context.handle(
        _followerCountsUpdatedAtMeta,
        followerCountsUpdatedAt.isAcceptableOrUnknown(
          data['follower_counts_updated_at']!,
          _followerCountsUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubkey};
  @override
  ProfileStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileStatRow(
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      videoCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_count'],
      ),
      followerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}follower_count'],
      ),
      followingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}following_count'],
      ),
      totalViews: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_views'],
      ),
      totalLikes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_likes'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      followerCountsUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}follower_counts_updated_at'],
      ),
    );
  }

  @override
  $ProfileStatsTable createAlias(String alias) {
    return $ProfileStatsTable(attachedDatabase, alias);
  }
}

class ProfileStatRow extends DataClass implements Insertable<ProfileStatRow> {
  final String pubkey;
  final int? videoCount;
  final int? followerCount;
  final int? followingCount;
  final int? totalViews;
  final int? totalLikes;
  final DateTime cachedAt;
  final DateTime? followerCountsUpdatedAt;
  const ProfileStatRow({
    required this.pubkey,
    this.videoCount,
    this.followerCount,
    this.followingCount,
    this.totalViews,
    this.totalLikes,
    required this.cachedAt,
    this.followerCountsUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey'] = Variable<String>(pubkey);
    if (!nullToAbsent || videoCount != null) {
      map['video_count'] = Variable<int>(videoCount);
    }
    if (!nullToAbsent || followerCount != null) {
      map['follower_count'] = Variable<int>(followerCount);
    }
    if (!nullToAbsent || followingCount != null) {
      map['following_count'] = Variable<int>(followingCount);
    }
    if (!nullToAbsent || totalViews != null) {
      map['total_views'] = Variable<int>(totalViews);
    }
    if (!nullToAbsent || totalLikes != null) {
      map['total_likes'] = Variable<int>(totalLikes);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    if (!nullToAbsent || followerCountsUpdatedAt != null) {
      map['follower_counts_updated_at'] = Variable<DateTime>(
        followerCountsUpdatedAt,
      );
    }
    return map;
  }

  ProfileStatsCompanion toCompanion(bool nullToAbsent) {
    return ProfileStatsCompanion(
      pubkey: Value(pubkey),
      videoCount: videoCount == null && nullToAbsent
          ? const Value.absent()
          : Value(videoCount),
      followerCount: followerCount == null && nullToAbsent
          ? const Value.absent()
          : Value(followerCount),
      followingCount: followingCount == null && nullToAbsent
          ? const Value.absent()
          : Value(followingCount),
      totalViews: totalViews == null && nullToAbsent
          ? const Value.absent()
          : Value(totalViews),
      totalLikes: totalLikes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalLikes),
      cachedAt: Value(cachedAt),
      followerCountsUpdatedAt: followerCountsUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(followerCountsUpdatedAt),
    );
  }

  factory ProfileStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileStatRow(
      pubkey: serializer.fromJson<String>(json['pubkey']),
      videoCount: serializer.fromJson<int?>(json['videoCount']),
      followerCount: serializer.fromJson<int?>(json['followerCount']),
      followingCount: serializer.fromJson<int?>(json['followingCount']),
      totalViews: serializer.fromJson<int?>(json['totalViews']),
      totalLikes: serializer.fromJson<int?>(json['totalLikes']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      followerCountsUpdatedAt: serializer.fromJson<DateTime?>(
        json['followerCountsUpdatedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkey': serializer.toJson<String>(pubkey),
      'videoCount': serializer.toJson<int?>(videoCount),
      'followerCount': serializer.toJson<int?>(followerCount),
      'followingCount': serializer.toJson<int?>(followingCount),
      'totalViews': serializer.toJson<int?>(totalViews),
      'totalLikes': serializer.toJson<int?>(totalLikes),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'followerCountsUpdatedAt': serializer.toJson<DateTime?>(
        followerCountsUpdatedAt,
      ),
    };
  }

  ProfileStatRow copyWith({
    String? pubkey,
    Value<int?> videoCount = const Value.absent(),
    Value<int?> followerCount = const Value.absent(),
    Value<int?> followingCount = const Value.absent(),
    Value<int?> totalViews = const Value.absent(),
    Value<int?> totalLikes = const Value.absent(),
    DateTime? cachedAt,
    Value<DateTime?> followerCountsUpdatedAt = const Value.absent(),
  }) => ProfileStatRow(
    pubkey: pubkey ?? this.pubkey,
    videoCount: videoCount.present ? videoCount.value : this.videoCount,
    followerCount: followerCount.present
        ? followerCount.value
        : this.followerCount,
    followingCount: followingCount.present
        ? followingCount.value
        : this.followingCount,
    totalViews: totalViews.present ? totalViews.value : this.totalViews,
    totalLikes: totalLikes.present ? totalLikes.value : this.totalLikes,
    cachedAt: cachedAt ?? this.cachedAt,
    followerCountsUpdatedAt: followerCountsUpdatedAt.present
        ? followerCountsUpdatedAt.value
        : this.followerCountsUpdatedAt,
  );
  ProfileStatRow copyWithCompanion(ProfileStatsCompanion data) {
    return ProfileStatRow(
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      videoCount: data.videoCount.present
          ? data.videoCount.value
          : this.videoCount,
      followerCount: data.followerCount.present
          ? data.followerCount.value
          : this.followerCount,
      followingCount: data.followingCount.present
          ? data.followingCount.value
          : this.followingCount,
      totalViews: data.totalViews.present
          ? data.totalViews.value
          : this.totalViews,
      totalLikes: data.totalLikes.present
          ? data.totalLikes.value
          : this.totalLikes,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      followerCountsUpdatedAt: data.followerCountsUpdatedAt.present
          ? data.followerCountsUpdatedAt.value
          : this.followerCountsUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileStatRow(')
          ..write('pubkey: $pubkey, ')
          ..write('videoCount: $videoCount, ')
          ..write('followerCount: $followerCount, ')
          ..write('followingCount: $followingCount, ')
          ..write('totalViews: $totalViews, ')
          ..write('totalLikes: $totalLikes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('followerCountsUpdatedAt: $followerCountsUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pubkey,
    videoCount,
    followerCount,
    followingCount,
    totalViews,
    totalLikes,
    cachedAt,
    followerCountsUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileStatRow &&
          other.pubkey == this.pubkey &&
          other.videoCount == this.videoCount &&
          other.followerCount == this.followerCount &&
          other.followingCount == this.followingCount &&
          other.totalViews == this.totalViews &&
          other.totalLikes == this.totalLikes &&
          other.cachedAt == this.cachedAt &&
          other.followerCountsUpdatedAt == this.followerCountsUpdatedAt);
}

class ProfileStatsCompanion extends UpdateCompanion<ProfileStatRow> {
  final Value<String> pubkey;
  final Value<int?> videoCount;
  final Value<int?> followerCount;
  final Value<int?> followingCount;
  final Value<int?> totalViews;
  final Value<int?> totalLikes;
  final Value<DateTime> cachedAt;
  final Value<DateTime?> followerCountsUpdatedAt;
  final Value<int> rowid;
  const ProfileStatsCompanion({
    this.pubkey = const Value.absent(),
    this.videoCount = const Value.absent(),
    this.followerCount = const Value.absent(),
    this.followingCount = const Value.absent(),
    this.totalViews = const Value.absent(),
    this.totalLikes = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.followerCountsUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfileStatsCompanion.insert({
    required String pubkey,
    this.videoCount = const Value.absent(),
    this.followerCount = const Value.absent(),
    this.followingCount = const Value.absent(),
    this.totalViews = const Value.absent(),
    this.totalLikes = const Value.absent(),
    required DateTime cachedAt,
    this.followerCountsUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pubkey = Value(pubkey),
       cachedAt = Value(cachedAt);
  static Insertable<ProfileStatRow> custom({
    Expression<String>? pubkey,
    Expression<int>? videoCount,
    Expression<int>? followerCount,
    Expression<int>? followingCount,
    Expression<int>? totalViews,
    Expression<int>? totalLikes,
    Expression<DateTime>? cachedAt,
    Expression<DateTime>? followerCountsUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkey != null) 'pubkey': pubkey,
      if (videoCount != null) 'video_count': videoCount,
      if (followerCount != null) 'follower_count': followerCount,
      if (followingCount != null) 'following_count': followingCount,
      if (totalViews != null) 'total_views': totalViews,
      if (totalLikes != null) 'total_likes': totalLikes,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (followerCountsUpdatedAt != null)
        'follower_counts_updated_at': followerCountsUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfileStatsCompanion copyWith({
    Value<String>? pubkey,
    Value<int?>? videoCount,
    Value<int?>? followerCount,
    Value<int?>? followingCount,
    Value<int?>? totalViews,
    Value<int?>? totalLikes,
    Value<DateTime>? cachedAt,
    Value<DateTime?>? followerCountsUpdatedAt,
    Value<int>? rowid,
  }) {
    return ProfileStatsCompanion(
      pubkey: pubkey ?? this.pubkey,
      videoCount: videoCount ?? this.videoCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      totalViews: totalViews ?? this.totalViews,
      totalLikes: totalLikes ?? this.totalLikes,
      cachedAt: cachedAt ?? this.cachedAt,
      followerCountsUpdatedAt:
          followerCountsUpdatedAt ?? this.followerCountsUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (videoCount.present) {
      map['video_count'] = Variable<int>(videoCount.value);
    }
    if (followerCount.present) {
      map['follower_count'] = Variable<int>(followerCount.value);
    }
    if (followingCount.present) {
      map['following_count'] = Variable<int>(followingCount.value);
    }
    if (totalViews.present) {
      map['total_views'] = Variable<int>(totalViews.value);
    }
    if (totalLikes.present) {
      map['total_likes'] = Variable<int>(totalLikes.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (followerCountsUpdatedAt.present) {
      map['follower_counts_updated_at'] = Variable<DateTime>(
        followerCountsUpdatedAt.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileStatsCompanion(')
          ..write('pubkey: $pubkey, ')
          ..write('videoCount: $videoCount, ')
          ..write('followerCount: $followerCount, ')
          ..write('followingCount: $followingCount, ')
          ..write('totalViews: $totalViews, ')
          ..write('totalLikes: $totalLikes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('followerCountsUpdatedAt: $followerCountsUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HashtagStatsTable extends HashtagStats
    with TableInfo<$HashtagStatsTable, HashtagStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HashtagStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hashtagMeta = const VerificationMeta(
    'hashtag',
  );
  @override
  late final GeneratedColumn<String> hashtag = GeneratedColumn<String>(
    'hashtag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoCountMeta = const VerificationMeta(
    'videoCount',
  );
  @override
  late final GeneratedColumn<int> videoCount = GeneratedColumn<int>(
    'video_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalViewsMeta = const VerificationMeta(
    'totalViews',
  );
  @override
  late final GeneratedColumn<int> totalViews = GeneratedColumn<int>(
    'total_views',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalLikesMeta = const VerificationMeta(
    'totalLikes',
  );
  @override
  late final GeneratedColumn<int> totalLikes = GeneratedColumn<int>(
    'total_likes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    hashtag,
    videoCount,
    totalViews,
    totalLikes,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hashtag_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<HashtagStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hashtag')) {
      context.handle(
        _hashtagMeta,
        hashtag.isAcceptableOrUnknown(data['hashtag']!, _hashtagMeta),
      );
    } else if (isInserting) {
      context.missing(_hashtagMeta);
    }
    if (data.containsKey('video_count')) {
      context.handle(
        _videoCountMeta,
        videoCount.isAcceptableOrUnknown(data['video_count']!, _videoCountMeta),
      );
    }
    if (data.containsKey('total_views')) {
      context.handle(
        _totalViewsMeta,
        totalViews.isAcceptableOrUnknown(data['total_views']!, _totalViewsMeta),
      );
    }
    if (data.containsKey('total_likes')) {
      context.handle(
        _totalLikesMeta,
        totalLikes.isAcceptableOrUnknown(data['total_likes']!, _totalLikesMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hashtag};
  @override
  HashtagStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HashtagStatRow(
      hashtag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hashtag'],
      )!,
      videoCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_count'],
      ),
      totalViews: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_views'],
      ),
      totalLikes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_likes'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $HashtagStatsTable createAlias(String alias) {
    return $HashtagStatsTable(attachedDatabase, alias);
  }
}

class HashtagStatRow extends DataClass implements Insertable<HashtagStatRow> {
  final String hashtag;
  final int? videoCount;
  final int? totalViews;
  final int? totalLikes;
  final DateTime cachedAt;
  const HashtagStatRow({
    required this.hashtag,
    this.videoCount,
    this.totalViews,
    this.totalLikes,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hashtag'] = Variable<String>(hashtag);
    if (!nullToAbsent || videoCount != null) {
      map['video_count'] = Variable<int>(videoCount);
    }
    if (!nullToAbsent || totalViews != null) {
      map['total_views'] = Variable<int>(totalViews);
    }
    if (!nullToAbsent || totalLikes != null) {
      map['total_likes'] = Variable<int>(totalLikes);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  HashtagStatsCompanion toCompanion(bool nullToAbsent) {
    return HashtagStatsCompanion(
      hashtag: Value(hashtag),
      videoCount: videoCount == null && nullToAbsent
          ? const Value.absent()
          : Value(videoCount),
      totalViews: totalViews == null && nullToAbsent
          ? const Value.absent()
          : Value(totalViews),
      totalLikes: totalLikes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalLikes),
      cachedAt: Value(cachedAt),
    );
  }

  factory HashtagStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HashtagStatRow(
      hashtag: serializer.fromJson<String>(json['hashtag']),
      videoCount: serializer.fromJson<int?>(json['videoCount']),
      totalViews: serializer.fromJson<int?>(json['totalViews']),
      totalLikes: serializer.fromJson<int?>(json['totalLikes']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hashtag': serializer.toJson<String>(hashtag),
      'videoCount': serializer.toJson<int?>(videoCount),
      'totalViews': serializer.toJson<int?>(totalViews),
      'totalLikes': serializer.toJson<int?>(totalLikes),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  HashtagStatRow copyWith({
    String? hashtag,
    Value<int?> videoCount = const Value.absent(),
    Value<int?> totalViews = const Value.absent(),
    Value<int?> totalLikes = const Value.absent(),
    DateTime? cachedAt,
  }) => HashtagStatRow(
    hashtag: hashtag ?? this.hashtag,
    videoCount: videoCount.present ? videoCount.value : this.videoCount,
    totalViews: totalViews.present ? totalViews.value : this.totalViews,
    totalLikes: totalLikes.present ? totalLikes.value : this.totalLikes,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  HashtagStatRow copyWithCompanion(HashtagStatsCompanion data) {
    return HashtagStatRow(
      hashtag: data.hashtag.present ? data.hashtag.value : this.hashtag,
      videoCount: data.videoCount.present
          ? data.videoCount.value
          : this.videoCount,
      totalViews: data.totalViews.present
          ? data.totalViews.value
          : this.totalViews,
      totalLikes: data.totalLikes.present
          ? data.totalLikes.value
          : this.totalLikes,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HashtagStatRow(')
          ..write('hashtag: $hashtag, ')
          ..write('videoCount: $videoCount, ')
          ..write('totalViews: $totalViews, ')
          ..write('totalLikes: $totalLikes, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(hashtag, videoCount, totalViews, totalLikes, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HashtagStatRow &&
          other.hashtag == this.hashtag &&
          other.videoCount == this.videoCount &&
          other.totalViews == this.totalViews &&
          other.totalLikes == this.totalLikes &&
          other.cachedAt == this.cachedAt);
}

class HashtagStatsCompanion extends UpdateCompanion<HashtagStatRow> {
  final Value<String> hashtag;
  final Value<int?> videoCount;
  final Value<int?> totalViews;
  final Value<int?> totalLikes;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const HashtagStatsCompanion({
    this.hashtag = const Value.absent(),
    this.videoCount = const Value.absent(),
    this.totalViews = const Value.absent(),
    this.totalLikes = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HashtagStatsCompanion.insert({
    required String hashtag,
    this.videoCount = const Value.absent(),
    this.totalViews = const Value.absent(),
    this.totalLikes = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : hashtag = Value(hashtag),
       cachedAt = Value(cachedAt);
  static Insertable<HashtagStatRow> custom({
    Expression<String>? hashtag,
    Expression<int>? videoCount,
    Expression<int>? totalViews,
    Expression<int>? totalLikes,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hashtag != null) 'hashtag': hashtag,
      if (videoCount != null) 'video_count': videoCount,
      if (totalViews != null) 'total_views': totalViews,
      if (totalLikes != null) 'total_likes': totalLikes,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HashtagStatsCompanion copyWith({
    Value<String>? hashtag,
    Value<int?>? videoCount,
    Value<int?>? totalViews,
    Value<int?>? totalLikes,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return HashtagStatsCompanion(
      hashtag: hashtag ?? this.hashtag,
      videoCount: videoCount ?? this.videoCount,
      totalViews: totalViews ?? this.totalViews,
      totalLikes: totalLikes ?? this.totalLikes,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hashtag.present) {
      map['hashtag'] = Variable<String>(hashtag.value);
    }
    if (videoCount.present) {
      map['video_count'] = Variable<int>(videoCount.value);
    }
    if (totalViews.present) {
      map['total_views'] = Variable<int>(totalViews.value);
    }
    if (totalLikes.present) {
      map['total_likes'] = Variable<int>(totalLikes.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HashtagStatsCompanion(')
          ..write('hashtag: $hashtag, ')
          ..write('videoCount: $videoCount, ')
          ..write('totalViews: $totalViews, ')
          ..write('totalLikes: $totalLikes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTable extends Notifications
    with TableInfo<$NotificationsTable, NotificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromPubkeyMeta = const VerificationMeta(
    'fromPubkey',
  );
  @override
  late final GeneratedColumn<String> fromPubkey = GeneratedColumn<String>(
    'from_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetEventIdMeta = const VerificationMeta(
    'targetEventId',
  );
  @override
  late final GeneratedColumn<String> targetEventId = GeneratedColumn<String>(
    'target_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoAddressableIdMeta =
      const VerificationMeta('videoAddressableId');
  @override
  late final GeneratedColumn<String> videoAddressableId =
      GeneratedColumn<String>(
        'video_addressable_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _hasCommentTargetMeta = const VerificationMeta(
    'hasCommentTarget',
  );
  @override
  late final GeneratedColumn<bool> hasCommentTarget = GeneratedColumn<bool>(
    'has_comment_target',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_comment_target" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _targetPubkeyMeta = const VerificationMeta(
    'targetPubkey',
  );
  @override
  late final GeneratedColumn<String> targetPubkey = GeneratedColumn<String>(
    'target_pubkey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    fromPubkey,
    targetEventId,
    videoAddressableId,
    hasCommentTarget,
    targetPubkey,
    content,
    timestamp,
    isRead,
    cachedAt,
    ownerPubkey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('from_pubkey')) {
      context.handle(
        _fromPubkeyMeta,
        fromPubkey.isAcceptableOrUnknown(data['from_pubkey']!, _fromPubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_fromPubkeyMeta);
    }
    if (data.containsKey('target_event_id')) {
      context.handle(
        _targetEventIdMeta,
        targetEventId.isAcceptableOrUnknown(
          data['target_event_id']!,
          _targetEventIdMeta,
        ),
      );
    }
    if (data.containsKey('video_addressable_id')) {
      context.handle(
        _videoAddressableIdMeta,
        videoAddressableId.isAcceptableOrUnknown(
          data['video_addressable_id']!,
          _videoAddressableIdMeta,
        ),
      );
    }
    if (data.containsKey('has_comment_target')) {
      context.handle(
        _hasCommentTargetMeta,
        hasCommentTarget.isAcceptableOrUnknown(
          data['has_comment_target']!,
          _hasCommentTargetMeta,
        ),
      );
    }
    if (data.containsKey('target_pubkey')) {
      context.handle(
        _targetPubkeyMeta,
        targetPubkey.isAcceptableOrUnknown(
          data['target_pubkey']!,
          _targetPubkeyMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, ownerPubkey};
  @override
  NotificationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      fromPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_pubkey'],
      )!,
      targetEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_event_id'],
      ),
      videoAddressableId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_addressable_id'],
      ),
      hasCommentTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_comment_target'],
      )!,
      targetPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_pubkey'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      ),
    );
  }

  @override
  $NotificationsTable createAlias(String alias) {
    return $NotificationsTable(attachedDatabase, alias);
  }
}

class NotificationRow extends DataClass implements Insertable<NotificationRow> {
  final String id;
  final String type;
  final String fromPubkey;
  final String? targetEventId;
  final String? videoAddressableId;
  final bool hasCommentTarget;
  final String? targetPubkey;
  final String? content;
  final int timestamp;
  final bool isRead;
  final DateTime cachedAt;

  /// Hex public key of the account this notification was delivered to.
  /// NULL for legacy rows created before multi-account support; those are
  /// claimed by the next signed-in account via `claimLegacyRows`.
  ///
  /// Notifications are viewer-scoped — the same relay event produces a row
  /// only for the account it targets — so reads must filter on this column
  /// or one account sees another's inbox.
  final String? ownerPubkey;
  const NotificationRow({
    required this.id,
    required this.type,
    required this.fromPubkey,
    this.targetEventId,
    this.videoAddressableId,
    required this.hasCommentTarget,
    this.targetPubkey,
    this.content,
    required this.timestamp,
    required this.isRead,
    required this.cachedAt,
    this.ownerPubkey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['from_pubkey'] = Variable<String>(fromPubkey);
    if (!nullToAbsent || targetEventId != null) {
      map['target_event_id'] = Variable<String>(targetEventId);
    }
    if (!nullToAbsent || videoAddressableId != null) {
      map['video_addressable_id'] = Variable<String>(videoAddressableId);
    }
    map['has_comment_target'] = Variable<bool>(hasCommentTarget);
    if (!nullToAbsent || targetPubkey != null) {
      map['target_pubkey'] = Variable<String>(targetPubkey);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['timestamp'] = Variable<int>(timestamp);
    map['is_read'] = Variable<bool>(isRead);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    if (!nullToAbsent || ownerPubkey != null) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey);
    }
    return map;
  }

  NotificationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationsCompanion(
      id: Value(id),
      type: Value(type),
      fromPubkey: Value(fromPubkey),
      targetEventId: targetEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetEventId),
      videoAddressableId: videoAddressableId == null && nullToAbsent
          ? const Value.absent()
          : Value(videoAddressableId),
      hasCommentTarget: Value(hasCommentTarget),
      targetPubkey: targetPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(targetPubkey),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      timestamp: Value(timestamp),
      isRead: Value(isRead),
      cachedAt: Value(cachedAt),
      ownerPubkey: ownerPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerPubkey),
    );
  }

  factory NotificationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      fromPubkey: serializer.fromJson<String>(json['fromPubkey']),
      targetEventId: serializer.fromJson<String?>(json['targetEventId']),
      videoAddressableId: serializer.fromJson<String?>(
        json['videoAddressableId'],
      ),
      hasCommentTarget: serializer.fromJson<bool>(json['hasCommentTarget']),
      targetPubkey: serializer.fromJson<String?>(json['targetPubkey']),
      content: serializer.fromJson<String?>(json['content']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      ownerPubkey: serializer.fromJson<String?>(json['ownerPubkey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'fromPubkey': serializer.toJson<String>(fromPubkey),
      'targetEventId': serializer.toJson<String?>(targetEventId),
      'videoAddressableId': serializer.toJson<String?>(videoAddressableId),
      'hasCommentTarget': serializer.toJson<bool>(hasCommentTarget),
      'targetPubkey': serializer.toJson<String?>(targetPubkey),
      'content': serializer.toJson<String?>(content),
      'timestamp': serializer.toJson<int>(timestamp),
      'isRead': serializer.toJson<bool>(isRead),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'ownerPubkey': serializer.toJson<String?>(ownerPubkey),
    };
  }

  NotificationRow copyWith({
    String? id,
    String? type,
    String? fromPubkey,
    Value<String?> targetEventId = const Value.absent(),
    Value<String?> videoAddressableId = const Value.absent(),
    bool? hasCommentTarget,
    Value<String?> targetPubkey = const Value.absent(),
    Value<String?> content = const Value.absent(),
    int? timestamp,
    bool? isRead,
    DateTime? cachedAt,
    Value<String?> ownerPubkey = const Value.absent(),
  }) => NotificationRow(
    id: id ?? this.id,
    type: type ?? this.type,
    fromPubkey: fromPubkey ?? this.fromPubkey,
    targetEventId: targetEventId.present
        ? targetEventId.value
        : this.targetEventId,
    videoAddressableId: videoAddressableId.present
        ? videoAddressableId.value
        : this.videoAddressableId,
    hasCommentTarget: hasCommentTarget ?? this.hasCommentTarget,
    targetPubkey: targetPubkey.present ? targetPubkey.value : this.targetPubkey,
    content: content.present ? content.value : this.content,
    timestamp: timestamp ?? this.timestamp,
    isRead: isRead ?? this.isRead,
    cachedAt: cachedAt ?? this.cachedAt,
    ownerPubkey: ownerPubkey.present ? ownerPubkey.value : this.ownerPubkey,
  );
  NotificationRow copyWithCompanion(NotificationsCompanion data) {
    return NotificationRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      fromPubkey: data.fromPubkey.present
          ? data.fromPubkey.value
          : this.fromPubkey,
      targetEventId: data.targetEventId.present
          ? data.targetEventId.value
          : this.targetEventId,
      videoAddressableId: data.videoAddressableId.present
          ? data.videoAddressableId.value
          : this.videoAddressableId,
      hasCommentTarget: data.hasCommentTarget.present
          ? data.hasCommentTarget.value
          : this.hasCommentTarget,
      targetPubkey: data.targetPubkey.present
          ? data.targetPubkey.value
          : this.targetPubkey,
      content: data.content.present ? data.content.value : this.content,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('fromPubkey: $fromPubkey, ')
          ..write('targetEventId: $targetEventId, ')
          ..write('videoAddressableId: $videoAddressableId, ')
          ..write('hasCommentTarget: $hasCommentTarget, ')
          ..write('targetPubkey: $targetPubkey, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('isRead: $isRead, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('ownerPubkey: $ownerPubkey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    fromPubkey,
    targetEventId,
    videoAddressableId,
    hasCommentTarget,
    targetPubkey,
    content,
    timestamp,
    isRead,
    cachedAt,
    ownerPubkey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.fromPubkey == this.fromPubkey &&
          other.targetEventId == this.targetEventId &&
          other.videoAddressableId == this.videoAddressableId &&
          other.hasCommentTarget == this.hasCommentTarget &&
          other.targetPubkey == this.targetPubkey &&
          other.content == this.content &&
          other.timestamp == this.timestamp &&
          other.isRead == this.isRead &&
          other.cachedAt == this.cachedAt &&
          other.ownerPubkey == this.ownerPubkey);
}

class NotificationsCompanion extends UpdateCompanion<NotificationRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> fromPubkey;
  final Value<String?> targetEventId;
  final Value<String?> videoAddressableId;
  final Value<bool> hasCommentTarget;
  final Value<String?> targetPubkey;
  final Value<String?> content;
  final Value<int> timestamp;
  final Value<bool> isRead;
  final Value<DateTime> cachedAt;
  final Value<String?> ownerPubkey;
  final Value<int> rowid;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.fromPubkey = const Value.absent(),
    this.targetEventId = const Value.absent(),
    this.videoAddressableId = const Value.absent(),
    this.hasCommentTarget = const Value.absent(),
    this.targetPubkey = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isRead = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsCompanion.insert({
    required String id,
    required String type,
    required String fromPubkey,
    this.targetEventId = const Value.absent(),
    this.videoAddressableId = const Value.absent(),
    this.hasCommentTarget = const Value.absent(),
    this.targetPubkey = const Value.absent(),
    this.content = const Value.absent(),
    required int timestamp,
    this.isRead = const Value.absent(),
    required DateTime cachedAt,
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       fromPubkey = Value(fromPubkey),
       timestamp = Value(timestamp),
       cachedAt = Value(cachedAt);
  static Insertable<NotificationRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? fromPubkey,
    Expression<String>? targetEventId,
    Expression<String>? videoAddressableId,
    Expression<bool>? hasCommentTarget,
    Expression<String>? targetPubkey,
    Expression<String>? content,
    Expression<int>? timestamp,
    Expression<bool>? isRead,
    Expression<DateTime>? cachedAt,
    Expression<String>? ownerPubkey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (fromPubkey != null) 'from_pubkey': fromPubkey,
      if (targetEventId != null) 'target_event_id': targetEventId,
      if (videoAddressableId != null)
        'video_addressable_id': videoAddressableId,
      if (hasCommentTarget != null) 'has_comment_target': hasCommentTarget,
      if (targetPubkey != null) 'target_pubkey': targetPubkey,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (isRead != null) 'is_read': isRead,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? fromPubkey,
    Value<String?>? targetEventId,
    Value<String?>? videoAddressableId,
    Value<bool>? hasCommentTarget,
    Value<String?>? targetPubkey,
    Value<String?>? content,
    Value<int>? timestamp,
    Value<bool>? isRead,
    Value<DateTime>? cachedAt,
    Value<String?>? ownerPubkey,
    Value<int>? rowid,
  }) {
    return NotificationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      fromPubkey: fromPubkey ?? this.fromPubkey,
      targetEventId: targetEventId ?? this.targetEventId,
      videoAddressableId: videoAddressableId ?? this.videoAddressableId,
      hasCommentTarget: hasCommentTarget ?? this.hasCommentTarget,
      targetPubkey: targetPubkey ?? this.targetPubkey,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      cachedAt: cachedAt ?? this.cachedAt,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (fromPubkey.present) {
      map['from_pubkey'] = Variable<String>(fromPubkey.value);
    }
    if (targetEventId.present) {
      map['target_event_id'] = Variable<String>(targetEventId.value);
    }
    if (videoAddressableId.present) {
      map['video_addressable_id'] = Variable<String>(videoAddressableId.value);
    }
    if (hasCommentTarget.present) {
      map['has_comment_target'] = Variable<bool>(hasCommentTarget.value);
    }
    if (targetPubkey.present) {
      map['target_pubkey'] = Variable<String>(targetPubkey.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('fromPubkey: $fromPubkey, ')
          ..write('targetEventId: $targetEventId, ')
          ..write('videoAddressableId: $videoAddressableId, ')
          ..write('hasCommentTarget: $hasCommentTarget, ')
          ..write('targetPubkey: $targetPubkey, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('isRead: $isRead, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingUploadsTable extends PendingUploads
    with TableInfo<$PendingUploadsTable, PendingUploadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingUploadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localVideoPathMeta = const VerificationMeta(
    'localVideoPath',
  );
  @override
  late final GeneratedColumn<String> localVideoPath = GeneratedColumn<String>(
    'local_video_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nostrPubkeyMeta = const VerificationMeta(
    'nostrPubkey',
  );
  @override
  late final GeneratedColumn<String> nostrPubkey = GeneratedColumn<String>(
    'nostr_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cloudinaryPublicIdMeta =
      const VerificationMeta('cloudinaryPublicId');
  @override
  late final GeneratedColumn<String> cloudinaryPublicId =
      GeneratedColumn<String>(
        'cloudinary_public_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cdnUrlMeta = const VerificationMeta('cdnUrl');
  @override
  late final GeneratedColumn<String> cdnUrl = GeneratedColumn<String>(
    'cdn_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadProgressMeta = const VerificationMeta(
    'uploadProgress',
  );
  @override
  late final GeneratedColumn<double> uploadProgress = GeneratedColumn<double>(
    'upload_progress',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hashtagsMeta = const VerificationMeta(
    'hashtags',
  );
  @override
  late final GeneratedColumn<String> hashtags = GeneratedColumn<String>(
    'hashtags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nostrEventIdMeta = const VerificationMeta(
    'nostrEventId',
  );
  @override
  late final GeneratedColumn<String> nostrEventId = GeneratedColumn<String>(
    'nostr_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _videoWidthMeta = const VerificationMeta(
    'videoWidth',
  );
  @override
  late final GeneratedColumn<int> videoWidth = GeneratedColumn<int>(
    'video_width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoHeightMeta = const VerificationMeta(
    'videoHeight',
  );
  @override
  late final GeneratedColumn<int> videoHeight = GeneratedColumn<int>(
    'video_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoDurationMillisMeta =
      const VerificationMeta('videoDurationMillis');
  @override
  late final GeneratedColumn<int> videoDurationMillis = GeneratedColumn<int>(
    'video_duration_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proofManifestJsonMeta = const VerificationMeta(
    'proofManifestJson',
  );
  @override
  late final GeneratedColumn<String> proofManifestJson =
      GeneratedColumn<String>(
        'proof_manifest_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _streamingMp4UrlMeta = const VerificationMeta(
    'streamingMp4Url',
  );
  @override
  late final GeneratedColumn<String> streamingMp4Url = GeneratedColumn<String>(
    'streaming_mp4_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamingHlsUrlMeta = const VerificationMeta(
    'streamingHlsUrl',
  );
  @override
  late final GeneratedColumn<String> streamingHlsUrl = GeneratedColumn<String>(
    'streaming_hls_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fallbackUrlMeta = const VerificationMeta(
    'fallbackUrl',
  );
  @override
  late final GeneratedColumn<String> fallbackUrl = GeneratedColumn<String>(
    'fallback_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localVideoPath,
    nostrPubkey,
    status,
    createdAt,
    cloudinaryPublicId,
    videoId,
    cdnUrl,
    errorMessage,
    uploadProgress,
    thumbnailPath,
    title,
    description,
    hashtags,
    nostrEventId,
    completedAt,
    retryCount,
    videoWidth,
    videoHeight,
    videoDurationMillis,
    proofManifestJson,
    streamingMp4Url,
    streamingHlsUrl,
    fallbackUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_uploads';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingUploadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('local_video_path')) {
      context.handle(
        _localVideoPathMeta,
        localVideoPath.isAcceptableOrUnknown(
          data['local_video_path']!,
          _localVideoPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localVideoPathMeta);
    }
    if (data.containsKey('nostr_pubkey')) {
      context.handle(
        _nostrPubkeyMeta,
        nostrPubkey.isAcceptableOrUnknown(
          data['nostr_pubkey']!,
          _nostrPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nostrPubkeyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('cloudinary_public_id')) {
      context.handle(
        _cloudinaryPublicIdMeta,
        cloudinaryPublicId.isAcceptableOrUnknown(
          data['cloudinary_public_id']!,
          _cloudinaryPublicIdMeta,
        ),
      );
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    }
    if (data.containsKey('cdn_url')) {
      context.handle(
        _cdnUrlMeta,
        cdnUrl.isAcceptableOrUnknown(data['cdn_url']!, _cdnUrlMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('upload_progress')) {
      context.handle(
        _uploadProgressMeta,
        uploadProgress.isAcceptableOrUnknown(
          data['upload_progress']!,
          _uploadProgressMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('hashtags')) {
      context.handle(
        _hashtagsMeta,
        hashtags.isAcceptableOrUnknown(data['hashtags']!, _hashtagsMeta),
      );
    }
    if (data.containsKey('nostr_event_id')) {
      context.handle(
        _nostrEventIdMeta,
        nostrEventId.isAcceptableOrUnknown(
          data['nostr_event_id']!,
          _nostrEventIdMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('video_width')) {
      context.handle(
        _videoWidthMeta,
        videoWidth.isAcceptableOrUnknown(data['video_width']!, _videoWidthMeta),
      );
    }
    if (data.containsKey('video_height')) {
      context.handle(
        _videoHeightMeta,
        videoHeight.isAcceptableOrUnknown(
          data['video_height']!,
          _videoHeightMeta,
        ),
      );
    }
    if (data.containsKey('video_duration_millis')) {
      context.handle(
        _videoDurationMillisMeta,
        videoDurationMillis.isAcceptableOrUnknown(
          data['video_duration_millis']!,
          _videoDurationMillisMeta,
        ),
      );
    }
    if (data.containsKey('proof_manifest_json')) {
      context.handle(
        _proofManifestJsonMeta,
        proofManifestJson.isAcceptableOrUnknown(
          data['proof_manifest_json']!,
          _proofManifestJsonMeta,
        ),
      );
    }
    if (data.containsKey('streaming_mp4_url')) {
      context.handle(
        _streamingMp4UrlMeta,
        streamingMp4Url.isAcceptableOrUnknown(
          data['streaming_mp4_url']!,
          _streamingMp4UrlMeta,
        ),
      );
    }
    if (data.containsKey('streaming_hls_url')) {
      context.handle(
        _streamingHlsUrlMeta,
        streamingHlsUrl.isAcceptableOrUnknown(
          data['streaming_hls_url']!,
          _streamingHlsUrlMeta,
        ),
      );
    }
    if (data.containsKey('fallback_url')) {
      context.handle(
        _fallbackUrlMeta,
        fallbackUrl.isAcceptableOrUnknown(
          data['fallback_url']!,
          _fallbackUrlMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingUploadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingUploadRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      localVideoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_video_path'],
      )!,
      nostrPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nostr_pubkey'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      cloudinaryPublicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloudinary_public_id'],
      ),
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      ),
      cdnUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cdn_url'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      uploadProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}upload_progress'],
      ),
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      hashtags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hashtags'],
      ),
      nostrEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nostr_event_id'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      videoWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_width'],
      ),
      videoHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_height'],
      ),
      videoDurationMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_duration_millis'],
      ),
      proofManifestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proof_manifest_json'],
      ),
      streamingMp4Url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}streaming_mp4_url'],
      ),
      streamingHlsUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}streaming_hls_url'],
      ),
      fallbackUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fallback_url'],
      ),
    );
  }

  @override
  $PendingUploadsTable createAlias(String alias) {
    return $PendingUploadsTable(attachedDatabase, alias);
  }
}

class PendingUploadRow extends DataClass
    implements Insertable<PendingUploadRow> {
  final String id;
  final String localVideoPath;
  final String nostrPubkey;
  final String status;
  final DateTime createdAt;
  final String? cloudinaryPublicId;
  final String? videoId;
  final String? cdnUrl;
  final String? errorMessage;
  final double? uploadProgress;
  final String? thumbnailPath;
  final String? title;
  final String? description;
  final String? hashtags;
  final String? nostrEventId;
  final DateTime? completedAt;
  final int retryCount;
  final int? videoWidth;
  final int? videoHeight;
  final int? videoDurationMillis;
  final String? proofManifestJson;
  final String? streamingMp4Url;
  final String? streamingHlsUrl;
  final String? fallbackUrl;
  const PendingUploadRow({
    required this.id,
    required this.localVideoPath,
    required this.nostrPubkey,
    required this.status,
    required this.createdAt,
    this.cloudinaryPublicId,
    this.videoId,
    this.cdnUrl,
    this.errorMessage,
    this.uploadProgress,
    this.thumbnailPath,
    this.title,
    this.description,
    this.hashtags,
    this.nostrEventId,
    this.completedAt,
    required this.retryCount,
    this.videoWidth,
    this.videoHeight,
    this.videoDurationMillis,
    this.proofManifestJson,
    this.streamingMp4Url,
    this.streamingHlsUrl,
    this.fallbackUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['local_video_path'] = Variable<String>(localVideoPath);
    map['nostr_pubkey'] = Variable<String>(nostrPubkey);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || cloudinaryPublicId != null) {
      map['cloudinary_public_id'] = Variable<String>(cloudinaryPublicId);
    }
    if (!nullToAbsent || videoId != null) {
      map['video_id'] = Variable<String>(videoId);
    }
    if (!nullToAbsent || cdnUrl != null) {
      map['cdn_url'] = Variable<String>(cdnUrl);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || uploadProgress != null) {
      map['upload_progress'] = Variable<double>(uploadProgress);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || hashtags != null) {
      map['hashtags'] = Variable<String>(hashtags);
    }
    if (!nullToAbsent || nostrEventId != null) {
      map['nostr_event_id'] = Variable<String>(nostrEventId);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || videoWidth != null) {
      map['video_width'] = Variable<int>(videoWidth);
    }
    if (!nullToAbsent || videoHeight != null) {
      map['video_height'] = Variable<int>(videoHeight);
    }
    if (!nullToAbsent || videoDurationMillis != null) {
      map['video_duration_millis'] = Variable<int>(videoDurationMillis);
    }
    if (!nullToAbsent || proofManifestJson != null) {
      map['proof_manifest_json'] = Variable<String>(proofManifestJson);
    }
    if (!nullToAbsent || streamingMp4Url != null) {
      map['streaming_mp4_url'] = Variable<String>(streamingMp4Url);
    }
    if (!nullToAbsent || streamingHlsUrl != null) {
      map['streaming_hls_url'] = Variable<String>(streamingHlsUrl);
    }
    if (!nullToAbsent || fallbackUrl != null) {
      map['fallback_url'] = Variable<String>(fallbackUrl);
    }
    return map;
  }

  PendingUploadsCompanion toCompanion(bool nullToAbsent) {
    return PendingUploadsCompanion(
      id: Value(id),
      localVideoPath: Value(localVideoPath),
      nostrPubkey: Value(nostrPubkey),
      status: Value(status),
      createdAt: Value(createdAt),
      cloudinaryPublicId: cloudinaryPublicId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudinaryPublicId),
      videoId: videoId == null && nullToAbsent
          ? const Value.absent()
          : Value(videoId),
      cdnUrl: cdnUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(cdnUrl),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      uploadProgress: uploadProgress == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadProgress),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      hashtags: hashtags == null && nullToAbsent
          ? const Value.absent()
          : Value(hashtags),
      nostrEventId: nostrEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(nostrEventId),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      retryCount: Value(retryCount),
      videoWidth: videoWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(videoWidth),
      videoHeight: videoHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(videoHeight),
      videoDurationMillis: videoDurationMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(videoDurationMillis),
      proofManifestJson: proofManifestJson == null && nullToAbsent
          ? const Value.absent()
          : Value(proofManifestJson),
      streamingMp4Url: streamingMp4Url == null && nullToAbsent
          ? const Value.absent()
          : Value(streamingMp4Url),
      streamingHlsUrl: streamingHlsUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(streamingHlsUrl),
      fallbackUrl: fallbackUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(fallbackUrl),
    );
  }

  factory PendingUploadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingUploadRow(
      id: serializer.fromJson<String>(json['id']),
      localVideoPath: serializer.fromJson<String>(json['localVideoPath']),
      nostrPubkey: serializer.fromJson<String>(json['nostrPubkey']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      cloudinaryPublicId: serializer.fromJson<String?>(
        json['cloudinaryPublicId'],
      ),
      videoId: serializer.fromJson<String?>(json['videoId']),
      cdnUrl: serializer.fromJson<String?>(json['cdnUrl']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      uploadProgress: serializer.fromJson<double?>(json['uploadProgress']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      title: serializer.fromJson<String?>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      hashtags: serializer.fromJson<String?>(json['hashtags']),
      nostrEventId: serializer.fromJson<String?>(json['nostrEventId']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      videoWidth: serializer.fromJson<int?>(json['videoWidth']),
      videoHeight: serializer.fromJson<int?>(json['videoHeight']),
      videoDurationMillis: serializer.fromJson<int?>(
        json['videoDurationMillis'],
      ),
      proofManifestJson: serializer.fromJson<String?>(
        json['proofManifestJson'],
      ),
      streamingMp4Url: serializer.fromJson<String?>(json['streamingMp4Url']),
      streamingHlsUrl: serializer.fromJson<String?>(json['streamingHlsUrl']),
      fallbackUrl: serializer.fromJson<String?>(json['fallbackUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'localVideoPath': serializer.toJson<String>(localVideoPath),
      'nostrPubkey': serializer.toJson<String>(nostrPubkey),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'cloudinaryPublicId': serializer.toJson<String?>(cloudinaryPublicId),
      'videoId': serializer.toJson<String?>(videoId),
      'cdnUrl': serializer.toJson<String?>(cdnUrl),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'uploadProgress': serializer.toJson<double?>(uploadProgress),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'title': serializer.toJson<String?>(title),
      'description': serializer.toJson<String?>(description),
      'hashtags': serializer.toJson<String?>(hashtags),
      'nostrEventId': serializer.toJson<String?>(nostrEventId),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'videoWidth': serializer.toJson<int?>(videoWidth),
      'videoHeight': serializer.toJson<int?>(videoHeight),
      'videoDurationMillis': serializer.toJson<int?>(videoDurationMillis),
      'proofManifestJson': serializer.toJson<String?>(proofManifestJson),
      'streamingMp4Url': serializer.toJson<String?>(streamingMp4Url),
      'streamingHlsUrl': serializer.toJson<String?>(streamingHlsUrl),
      'fallbackUrl': serializer.toJson<String?>(fallbackUrl),
    };
  }

  PendingUploadRow copyWith({
    String? id,
    String? localVideoPath,
    String? nostrPubkey,
    String? status,
    DateTime? createdAt,
    Value<String?> cloudinaryPublicId = const Value.absent(),
    Value<String?> videoId = const Value.absent(),
    Value<String?> cdnUrl = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<double?> uploadProgress = const Value.absent(),
    Value<String?> thumbnailPath = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> hashtags = const Value.absent(),
    Value<String?> nostrEventId = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    int? retryCount,
    Value<int?> videoWidth = const Value.absent(),
    Value<int?> videoHeight = const Value.absent(),
    Value<int?> videoDurationMillis = const Value.absent(),
    Value<String?> proofManifestJson = const Value.absent(),
    Value<String?> streamingMp4Url = const Value.absent(),
    Value<String?> streamingHlsUrl = const Value.absent(),
    Value<String?> fallbackUrl = const Value.absent(),
  }) => PendingUploadRow(
    id: id ?? this.id,
    localVideoPath: localVideoPath ?? this.localVideoPath,
    nostrPubkey: nostrPubkey ?? this.nostrPubkey,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    cloudinaryPublicId: cloudinaryPublicId.present
        ? cloudinaryPublicId.value
        : this.cloudinaryPublicId,
    videoId: videoId.present ? videoId.value : this.videoId,
    cdnUrl: cdnUrl.present ? cdnUrl.value : this.cdnUrl,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    uploadProgress: uploadProgress.present
        ? uploadProgress.value
        : this.uploadProgress,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    title: title.present ? title.value : this.title,
    description: description.present ? description.value : this.description,
    hashtags: hashtags.present ? hashtags.value : this.hashtags,
    nostrEventId: nostrEventId.present ? nostrEventId.value : this.nostrEventId,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    retryCount: retryCount ?? this.retryCount,
    videoWidth: videoWidth.present ? videoWidth.value : this.videoWidth,
    videoHeight: videoHeight.present ? videoHeight.value : this.videoHeight,
    videoDurationMillis: videoDurationMillis.present
        ? videoDurationMillis.value
        : this.videoDurationMillis,
    proofManifestJson: proofManifestJson.present
        ? proofManifestJson.value
        : this.proofManifestJson,
    streamingMp4Url: streamingMp4Url.present
        ? streamingMp4Url.value
        : this.streamingMp4Url,
    streamingHlsUrl: streamingHlsUrl.present
        ? streamingHlsUrl.value
        : this.streamingHlsUrl,
    fallbackUrl: fallbackUrl.present ? fallbackUrl.value : this.fallbackUrl,
  );
  PendingUploadRow copyWithCompanion(PendingUploadsCompanion data) {
    return PendingUploadRow(
      id: data.id.present ? data.id.value : this.id,
      localVideoPath: data.localVideoPath.present
          ? data.localVideoPath.value
          : this.localVideoPath,
      nostrPubkey: data.nostrPubkey.present
          ? data.nostrPubkey.value
          : this.nostrPubkey,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cloudinaryPublicId: data.cloudinaryPublicId.present
          ? data.cloudinaryPublicId.value
          : this.cloudinaryPublicId,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      cdnUrl: data.cdnUrl.present ? data.cdnUrl.value : this.cdnUrl,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      uploadProgress: data.uploadProgress.present
          ? data.uploadProgress.value
          : this.uploadProgress,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      hashtags: data.hashtags.present ? data.hashtags.value : this.hashtags,
      nostrEventId: data.nostrEventId.present
          ? data.nostrEventId.value
          : this.nostrEventId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      videoWidth: data.videoWidth.present
          ? data.videoWidth.value
          : this.videoWidth,
      videoHeight: data.videoHeight.present
          ? data.videoHeight.value
          : this.videoHeight,
      videoDurationMillis: data.videoDurationMillis.present
          ? data.videoDurationMillis.value
          : this.videoDurationMillis,
      proofManifestJson: data.proofManifestJson.present
          ? data.proofManifestJson.value
          : this.proofManifestJson,
      streamingMp4Url: data.streamingMp4Url.present
          ? data.streamingMp4Url.value
          : this.streamingMp4Url,
      streamingHlsUrl: data.streamingHlsUrl.present
          ? data.streamingHlsUrl.value
          : this.streamingHlsUrl,
      fallbackUrl: data.fallbackUrl.present
          ? data.fallbackUrl.value
          : this.fallbackUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingUploadRow(')
          ..write('id: $id, ')
          ..write('localVideoPath: $localVideoPath, ')
          ..write('nostrPubkey: $nostrPubkey, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('cloudinaryPublicId: $cloudinaryPublicId, ')
          ..write('videoId: $videoId, ')
          ..write('cdnUrl: $cdnUrl, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('uploadProgress: $uploadProgress, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('hashtags: $hashtags, ')
          ..write('nostrEventId: $nostrEventId, ')
          ..write('completedAt: $completedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('videoWidth: $videoWidth, ')
          ..write('videoHeight: $videoHeight, ')
          ..write('videoDurationMillis: $videoDurationMillis, ')
          ..write('proofManifestJson: $proofManifestJson, ')
          ..write('streamingMp4Url: $streamingMp4Url, ')
          ..write('streamingHlsUrl: $streamingHlsUrl, ')
          ..write('fallbackUrl: $fallbackUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    localVideoPath,
    nostrPubkey,
    status,
    createdAt,
    cloudinaryPublicId,
    videoId,
    cdnUrl,
    errorMessage,
    uploadProgress,
    thumbnailPath,
    title,
    description,
    hashtags,
    nostrEventId,
    completedAt,
    retryCount,
    videoWidth,
    videoHeight,
    videoDurationMillis,
    proofManifestJson,
    streamingMp4Url,
    streamingHlsUrl,
    fallbackUrl,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingUploadRow &&
          other.id == this.id &&
          other.localVideoPath == this.localVideoPath &&
          other.nostrPubkey == this.nostrPubkey &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.cloudinaryPublicId == this.cloudinaryPublicId &&
          other.videoId == this.videoId &&
          other.cdnUrl == this.cdnUrl &&
          other.errorMessage == this.errorMessage &&
          other.uploadProgress == this.uploadProgress &&
          other.thumbnailPath == this.thumbnailPath &&
          other.title == this.title &&
          other.description == this.description &&
          other.hashtags == this.hashtags &&
          other.nostrEventId == this.nostrEventId &&
          other.completedAt == this.completedAt &&
          other.retryCount == this.retryCount &&
          other.videoWidth == this.videoWidth &&
          other.videoHeight == this.videoHeight &&
          other.videoDurationMillis == this.videoDurationMillis &&
          other.proofManifestJson == this.proofManifestJson &&
          other.streamingMp4Url == this.streamingMp4Url &&
          other.streamingHlsUrl == this.streamingHlsUrl &&
          other.fallbackUrl == this.fallbackUrl);
}

class PendingUploadsCompanion extends UpdateCompanion<PendingUploadRow> {
  final Value<String> id;
  final Value<String> localVideoPath;
  final Value<String> nostrPubkey;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<String?> cloudinaryPublicId;
  final Value<String?> videoId;
  final Value<String?> cdnUrl;
  final Value<String?> errorMessage;
  final Value<double?> uploadProgress;
  final Value<String?> thumbnailPath;
  final Value<String?> title;
  final Value<String?> description;
  final Value<String?> hashtags;
  final Value<String?> nostrEventId;
  final Value<DateTime?> completedAt;
  final Value<int> retryCount;
  final Value<int?> videoWidth;
  final Value<int?> videoHeight;
  final Value<int?> videoDurationMillis;
  final Value<String?> proofManifestJson;
  final Value<String?> streamingMp4Url;
  final Value<String?> streamingHlsUrl;
  final Value<String?> fallbackUrl;
  final Value<int> rowid;
  const PendingUploadsCompanion({
    this.id = const Value.absent(),
    this.localVideoPath = const Value.absent(),
    this.nostrPubkey = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cloudinaryPublicId = const Value.absent(),
    this.videoId = const Value.absent(),
    this.cdnUrl = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.uploadProgress = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.hashtags = const Value.absent(),
    this.nostrEventId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.videoWidth = const Value.absent(),
    this.videoHeight = const Value.absent(),
    this.videoDurationMillis = const Value.absent(),
    this.proofManifestJson = const Value.absent(),
    this.streamingMp4Url = const Value.absent(),
    this.streamingHlsUrl = const Value.absent(),
    this.fallbackUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingUploadsCompanion.insert({
    required String id,
    required String localVideoPath,
    required String nostrPubkey,
    required String status,
    required DateTime createdAt,
    this.cloudinaryPublicId = const Value.absent(),
    this.videoId = const Value.absent(),
    this.cdnUrl = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.uploadProgress = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.hashtags = const Value.absent(),
    this.nostrEventId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.videoWidth = const Value.absent(),
    this.videoHeight = const Value.absent(),
    this.videoDurationMillis = const Value.absent(),
    this.proofManifestJson = const Value.absent(),
    this.streamingMp4Url = const Value.absent(),
    this.streamingHlsUrl = const Value.absent(),
    this.fallbackUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       localVideoPath = Value(localVideoPath),
       nostrPubkey = Value(nostrPubkey),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<PendingUploadRow> custom({
    Expression<String>? id,
    Expression<String>? localVideoPath,
    Expression<String>? nostrPubkey,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<String>? cloudinaryPublicId,
    Expression<String>? videoId,
    Expression<String>? cdnUrl,
    Expression<String>? errorMessage,
    Expression<double>? uploadProgress,
    Expression<String>? thumbnailPath,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? hashtags,
    Expression<String>? nostrEventId,
    Expression<DateTime>? completedAt,
    Expression<int>? retryCount,
    Expression<int>? videoWidth,
    Expression<int>? videoHeight,
    Expression<int>? videoDurationMillis,
    Expression<String>? proofManifestJson,
    Expression<String>? streamingMp4Url,
    Expression<String>? streamingHlsUrl,
    Expression<String>? fallbackUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localVideoPath != null) 'local_video_path': localVideoPath,
      if (nostrPubkey != null) 'nostr_pubkey': nostrPubkey,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (cloudinaryPublicId != null)
        'cloudinary_public_id': cloudinaryPublicId,
      if (videoId != null) 'video_id': videoId,
      if (cdnUrl != null) 'cdn_url': cdnUrl,
      if (errorMessage != null) 'error_message': errorMessage,
      if (uploadProgress != null) 'upload_progress': uploadProgress,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (hashtags != null) 'hashtags': hashtags,
      if (nostrEventId != null) 'nostr_event_id': nostrEventId,
      if (completedAt != null) 'completed_at': completedAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (videoWidth != null) 'video_width': videoWidth,
      if (videoHeight != null) 'video_height': videoHeight,
      if (videoDurationMillis != null)
        'video_duration_millis': videoDurationMillis,
      if (proofManifestJson != null) 'proof_manifest_json': proofManifestJson,
      if (streamingMp4Url != null) 'streaming_mp4_url': streamingMp4Url,
      if (streamingHlsUrl != null) 'streaming_hls_url': streamingHlsUrl,
      if (fallbackUrl != null) 'fallback_url': fallbackUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingUploadsCompanion copyWith({
    Value<String>? id,
    Value<String>? localVideoPath,
    Value<String>? nostrPubkey,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<String?>? cloudinaryPublicId,
    Value<String?>? videoId,
    Value<String?>? cdnUrl,
    Value<String?>? errorMessage,
    Value<double?>? uploadProgress,
    Value<String?>? thumbnailPath,
    Value<String?>? title,
    Value<String?>? description,
    Value<String?>? hashtags,
    Value<String?>? nostrEventId,
    Value<DateTime?>? completedAt,
    Value<int>? retryCount,
    Value<int?>? videoWidth,
    Value<int?>? videoHeight,
    Value<int?>? videoDurationMillis,
    Value<String?>? proofManifestJson,
    Value<String?>? streamingMp4Url,
    Value<String?>? streamingHlsUrl,
    Value<String?>? fallbackUrl,
    Value<int>? rowid,
  }) {
    return PendingUploadsCompanion(
      id: id ?? this.id,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      nostrPubkey: nostrPubkey ?? this.nostrPubkey,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      videoId: videoId ?? this.videoId,
      cdnUrl: cdnUrl ?? this.cdnUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      title: title ?? this.title,
      description: description ?? this.description,
      hashtags: hashtags ?? this.hashtags,
      nostrEventId: nostrEventId ?? this.nostrEventId,
      completedAt: completedAt ?? this.completedAt,
      retryCount: retryCount ?? this.retryCount,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      videoDurationMillis: videoDurationMillis ?? this.videoDurationMillis,
      proofManifestJson: proofManifestJson ?? this.proofManifestJson,
      streamingMp4Url: streamingMp4Url ?? this.streamingMp4Url,
      streamingHlsUrl: streamingHlsUrl ?? this.streamingHlsUrl,
      fallbackUrl: fallbackUrl ?? this.fallbackUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (localVideoPath.present) {
      map['local_video_path'] = Variable<String>(localVideoPath.value);
    }
    if (nostrPubkey.present) {
      map['nostr_pubkey'] = Variable<String>(nostrPubkey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (cloudinaryPublicId.present) {
      map['cloudinary_public_id'] = Variable<String>(cloudinaryPublicId.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (cdnUrl.present) {
      map['cdn_url'] = Variable<String>(cdnUrl.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (uploadProgress.present) {
      map['upload_progress'] = Variable<double>(uploadProgress.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (hashtags.present) {
      map['hashtags'] = Variable<String>(hashtags.value);
    }
    if (nostrEventId.present) {
      map['nostr_event_id'] = Variable<String>(nostrEventId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (videoWidth.present) {
      map['video_width'] = Variable<int>(videoWidth.value);
    }
    if (videoHeight.present) {
      map['video_height'] = Variable<int>(videoHeight.value);
    }
    if (videoDurationMillis.present) {
      map['video_duration_millis'] = Variable<int>(videoDurationMillis.value);
    }
    if (proofManifestJson.present) {
      map['proof_manifest_json'] = Variable<String>(proofManifestJson.value);
    }
    if (streamingMp4Url.present) {
      map['streaming_mp4_url'] = Variable<String>(streamingMp4Url.value);
    }
    if (streamingHlsUrl.present) {
      map['streaming_hls_url'] = Variable<String>(streamingHlsUrl.value);
    }
    if (fallbackUrl.present) {
      map['fallback_url'] = Variable<String>(fallbackUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingUploadsCompanion(')
          ..write('id: $id, ')
          ..write('localVideoPath: $localVideoPath, ')
          ..write('nostrPubkey: $nostrPubkey, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('cloudinaryPublicId: $cloudinaryPublicId, ')
          ..write('videoId: $videoId, ')
          ..write('cdnUrl: $cdnUrl, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('uploadProgress: $uploadProgress, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('hashtags: $hashtags, ')
          ..write('nostrEventId: $nostrEventId, ')
          ..write('completedAt: $completedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('videoWidth: $videoWidth, ')
          ..write('videoHeight: $videoHeight, ')
          ..write('videoDurationMillis: $videoDurationMillis, ')
          ..write('proofManifestJson: $proofManifestJson, ')
          ..write('streamingMp4Url: $streamingMp4Url, ')
          ..write('streamingHlsUrl: $streamingHlsUrl, ')
          ..write('fallbackUrl: $fallbackUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonalReactionsTable extends PersonalReactions
    with TableInfo<$PersonalReactionsTable, PersonalReactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonalReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _targetEventIdMeta = const VerificationMeta(
    'targetEventId',
  );
  @override
  late final GeneratedColumn<String> targetEventId = GeneratedColumn<String>(
    'target_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reactionEventIdMeta = const VerificationMeta(
    'reactionEventId',
  );
  @override
  late final GeneratedColumn<String> reactionEventId = GeneratedColumn<String>(
    'reaction_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userPubkeyMeta = const VerificationMeta(
    'userPubkey',
  );
  @override
  late final GeneratedColumn<String> userPubkey = GeneratedColumn<String>(
    'user_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressableIdMeta = const VerificationMeta(
    'addressableId',
  );
  @override
  late final GeneratedColumn<String> addressableId = GeneratedColumn<String>(
    'addressable_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    targetEventId,
    reactionEventId,
    userPubkey,
    createdAt,
    addressableId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'personal_reactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonalReactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('target_event_id')) {
      context.handle(
        _targetEventIdMeta,
        targetEventId.isAcceptableOrUnknown(
          data['target_event_id']!,
          _targetEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetEventIdMeta);
    }
    if (data.containsKey('reaction_event_id')) {
      context.handle(
        _reactionEventIdMeta,
        reactionEventId.isAcceptableOrUnknown(
          data['reaction_event_id']!,
          _reactionEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reactionEventIdMeta);
    }
    if (data.containsKey('user_pubkey')) {
      context.handle(
        _userPubkeyMeta,
        userPubkey.isAcceptableOrUnknown(data['user_pubkey']!, _userPubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_userPubkeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('addressable_id')) {
      context.handle(
        _addressableIdMeta,
        addressableId.isAcceptableOrUnknown(
          data['addressable_id']!,
          _addressableIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {targetEventId, userPubkey};
  @override
  PersonalReactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonalReactionRow(
      targetEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_event_id'],
      )!,
      reactionEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reaction_event_id'],
      )!,
      userPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_pubkey'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      addressableId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}addressable_id'],
      ),
    );
  }

  @override
  $PersonalReactionsTable createAlias(String alias) {
    return $PersonalReactionsTable(attachedDatabase, alias);
  }
}

class PersonalReactionRow extends DataClass
    implements Insertable<PersonalReactionRow> {
  /// The event ID that was liked (e.g., video event ID)
  final String targetEventId;

  /// The Kind 7 reaction event ID created by the user
  final String reactionEventId;

  /// The pubkey of the user who created this reaction
  final String userPubkey;

  /// Unix timestamp when the reaction was created
  final int createdAt;

  /// Addressable coordinate (`kind:pubkey:d-tag`) of the target event, when
  /// the target is a Kind 30000+ addressable event (e.g. a video).
  ///
  /// Null for likes on non-addressable targets (e.g. comments), which have
  /// no `d` tag / coordinate. Lets own-like state survive a target edit
  /// that mints a new [targetEventId] for the same coordinate (#6020).
  final String? addressableId;
  const PersonalReactionRow({
    required this.targetEventId,
    required this.reactionEventId,
    required this.userPubkey,
    required this.createdAt,
    this.addressableId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['target_event_id'] = Variable<String>(targetEventId);
    map['reaction_event_id'] = Variable<String>(reactionEventId);
    map['user_pubkey'] = Variable<String>(userPubkey);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || addressableId != null) {
      map['addressable_id'] = Variable<String>(addressableId);
    }
    return map;
  }

  PersonalReactionsCompanion toCompanion(bool nullToAbsent) {
    return PersonalReactionsCompanion(
      targetEventId: Value(targetEventId),
      reactionEventId: Value(reactionEventId),
      userPubkey: Value(userPubkey),
      createdAt: Value(createdAt),
      addressableId: addressableId == null && nullToAbsent
          ? const Value.absent()
          : Value(addressableId),
    );
  }

  factory PersonalReactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonalReactionRow(
      targetEventId: serializer.fromJson<String>(json['targetEventId']),
      reactionEventId: serializer.fromJson<String>(json['reactionEventId']),
      userPubkey: serializer.fromJson<String>(json['userPubkey']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      addressableId: serializer.fromJson<String?>(json['addressableId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'targetEventId': serializer.toJson<String>(targetEventId),
      'reactionEventId': serializer.toJson<String>(reactionEventId),
      'userPubkey': serializer.toJson<String>(userPubkey),
      'createdAt': serializer.toJson<int>(createdAt),
      'addressableId': serializer.toJson<String?>(addressableId),
    };
  }

  PersonalReactionRow copyWith({
    String? targetEventId,
    String? reactionEventId,
    String? userPubkey,
    int? createdAt,
    Value<String?> addressableId = const Value.absent(),
  }) => PersonalReactionRow(
    targetEventId: targetEventId ?? this.targetEventId,
    reactionEventId: reactionEventId ?? this.reactionEventId,
    userPubkey: userPubkey ?? this.userPubkey,
    createdAt: createdAt ?? this.createdAt,
    addressableId: addressableId.present
        ? addressableId.value
        : this.addressableId,
  );
  PersonalReactionRow copyWithCompanion(PersonalReactionsCompanion data) {
    return PersonalReactionRow(
      targetEventId: data.targetEventId.present
          ? data.targetEventId.value
          : this.targetEventId,
      reactionEventId: data.reactionEventId.present
          ? data.reactionEventId.value
          : this.reactionEventId,
      userPubkey: data.userPubkey.present
          ? data.userPubkey.value
          : this.userPubkey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      addressableId: data.addressableId.present
          ? data.addressableId.value
          : this.addressableId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonalReactionRow(')
          ..write('targetEventId: $targetEventId, ')
          ..write('reactionEventId: $reactionEventId, ')
          ..write('userPubkey: $userPubkey, ')
          ..write('createdAt: $createdAt, ')
          ..write('addressableId: $addressableId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    targetEventId,
    reactionEventId,
    userPubkey,
    createdAt,
    addressableId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonalReactionRow &&
          other.targetEventId == this.targetEventId &&
          other.reactionEventId == this.reactionEventId &&
          other.userPubkey == this.userPubkey &&
          other.createdAt == this.createdAt &&
          other.addressableId == this.addressableId);
}

class PersonalReactionsCompanion extends UpdateCompanion<PersonalReactionRow> {
  final Value<String> targetEventId;
  final Value<String> reactionEventId;
  final Value<String> userPubkey;
  final Value<int> createdAt;
  final Value<String?> addressableId;
  final Value<int> rowid;
  const PersonalReactionsCompanion({
    this.targetEventId = const Value.absent(),
    this.reactionEventId = const Value.absent(),
    this.userPubkey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.addressableId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonalReactionsCompanion.insert({
    required String targetEventId,
    required String reactionEventId,
    required String userPubkey,
    required int createdAt,
    this.addressableId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : targetEventId = Value(targetEventId),
       reactionEventId = Value(reactionEventId),
       userPubkey = Value(userPubkey),
       createdAt = Value(createdAt);
  static Insertable<PersonalReactionRow> custom({
    Expression<String>? targetEventId,
    Expression<String>? reactionEventId,
    Expression<String>? userPubkey,
    Expression<int>? createdAt,
    Expression<String>? addressableId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (targetEventId != null) 'target_event_id': targetEventId,
      if (reactionEventId != null) 'reaction_event_id': reactionEventId,
      if (userPubkey != null) 'user_pubkey': userPubkey,
      if (createdAt != null) 'created_at': createdAt,
      if (addressableId != null) 'addressable_id': addressableId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonalReactionsCompanion copyWith({
    Value<String>? targetEventId,
    Value<String>? reactionEventId,
    Value<String>? userPubkey,
    Value<int>? createdAt,
    Value<String?>? addressableId,
    Value<int>? rowid,
  }) {
    return PersonalReactionsCompanion(
      targetEventId: targetEventId ?? this.targetEventId,
      reactionEventId: reactionEventId ?? this.reactionEventId,
      userPubkey: userPubkey ?? this.userPubkey,
      createdAt: createdAt ?? this.createdAt,
      addressableId: addressableId ?? this.addressableId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (targetEventId.present) {
      map['target_event_id'] = Variable<String>(targetEventId.value);
    }
    if (reactionEventId.present) {
      map['reaction_event_id'] = Variable<String>(reactionEventId.value);
    }
    if (userPubkey.present) {
      map['user_pubkey'] = Variable<String>(userPubkey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (addressableId.present) {
      map['addressable_id'] = Variable<String>(addressableId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonalReactionsCompanion(')
          ..write('targetEventId: $targetEventId, ')
          ..write('reactionEventId: $reactionEventId, ')
          ..write('userPubkey: $userPubkey, ')
          ..write('createdAt: $createdAt, ')
          ..write('addressableId: $addressableId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonalRepostsTable extends PersonalReposts
    with TableInfo<$PersonalRepostsTable, PersonalRepostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonalRepostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addressableIdMeta = const VerificationMeta(
    'addressableId',
  );
  @override
  late final GeneratedColumn<String> addressableId = GeneratedColumn<String>(
    'addressable_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repostEventIdMeta = const VerificationMeta(
    'repostEventId',
  );
  @override
  late final GeneratedColumn<String> repostEventId = GeneratedColumn<String>(
    'repost_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalAuthorPubkeyMeta =
      const VerificationMeta('originalAuthorPubkey');
  @override
  late final GeneratedColumn<String> originalAuthorPubkey =
      GeneratedColumn<String>(
        'original_author_pubkey',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _userPubkeyMeta = const VerificationMeta(
    'userPubkey',
  );
  @override
  late final GeneratedColumn<String> userPubkey = GeneratedColumn<String>(
    'user_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    addressableId,
    repostEventId,
    originalAuthorPubkey,
    userPubkey,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'personal_reposts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonalRepostRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('addressable_id')) {
      context.handle(
        _addressableIdMeta,
        addressableId.isAcceptableOrUnknown(
          data['addressable_id']!,
          _addressableIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressableIdMeta);
    }
    if (data.containsKey('repost_event_id')) {
      context.handle(
        _repostEventIdMeta,
        repostEventId.isAcceptableOrUnknown(
          data['repost_event_id']!,
          _repostEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repostEventIdMeta);
    }
    if (data.containsKey('original_author_pubkey')) {
      context.handle(
        _originalAuthorPubkeyMeta,
        originalAuthorPubkey.isAcceptableOrUnknown(
          data['original_author_pubkey']!,
          _originalAuthorPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalAuthorPubkeyMeta);
    }
    if (data.containsKey('user_pubkey')) {
      context.handle(
        _userPubkeyMeta,
        userPubkey.isAcceptableOrUnknown(data['user_pubkey']!, _userPubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_userPubkeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {addressableId, userPubkey};
  @override
  PersonalRepostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonalRepostRow(
      addressableId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}addressable_id'],
      )!,
      repostEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repost_event_id'],
      )!,
      originalAuthorPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_author_pubkey'],
      )!,
      userPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_pubkey'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PersonalRepostsTable createAlias(String alias) {
    return $PersonalRepostsTable(attachedDatabase, alias);
  }
}

class PersonalRepostRow extends DataClass
    implements Insertable<PersonalRepostRow> {
  /// The addressable ID of the video that was reposted.
  /// Format: `34236:<author_pubkey>:<d-tag>`
  final String addressableId;

  /// The Kind 16 repost event ID created by the user
  final String repostEventId;

  /// The pubkey of the original video author
  final String originalAuthorPubkey;

  /// The pubkey of the user who created this repost
  final String userPubkey;

  /// Unix timestamp when the repost was created
  final int createdAt;
  const PersonalRepostRow({
    required this.addressableId,
    required this.repostEventId,
    required this.originalAuthorPubkey,
    required this.userPubkey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['addressable_id'] = Variable<String>(addressableId);
    map['repost_event_id'] = Variable<String>(repostEventId);
    map['original_author_pubkey'] = Variable<String>(originalAuthorPubkey);
    map['user_pubkey'] = Variable<String>(userPubkey);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PersonalRepostsCompanion toCompanion(bool nullToAbsent) {
    return PersonalRepostsCompanion(
      addressableId: Value(addressableId),
      repostEventId: Value(repostEventId),
      originalAuthorPubkey: Value(originalAuthorPubkey),
      userPubkey: Value(userPubkey),
      createdAt: Value(createdAt),
    );
  }

  factory PersonalRepostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonalRepostRow(
      addressableId: serializer.fromJson<String>(json['addressableId']),
      repostEventId: serializer.fromJson<String>(json['repostEventId']),
      originalAuthorPubkey: serializer.fromJson<String>(
        json['originalAuthorPubkey'],
      ),
      userPubkey: serializer.fromJson<String>(json['userPubkey']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'addressableId': serializer.toJson<String>(addressableId),
      'repostEventId': serializer.toJson<String>(repostEventId),
      'originalAuthorPubkey': serializer.toJson<String>(originalAuthorPubkey),
      'userPubkey': serializer.toJson<String>(userPubkey),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  PersonalRepostRow copyWith({
    String? addressableId,
    String? repostEventId,
    String? originalAuthorPubkey,
    String? userPubkey,
    int? createdAt,
  }) => PersonalRepostRow(
    addressableId: addressableId ?? this.addressableId,
    repostEventId: repostEventId ?? this.repostEventId,
    originalAuthorPubkey: originalAuthorPubkey ?? this.originalAuthorPubkey,
    userPubkey: userPubkey ?? this.userPubkey,
    createdAt: createdAt ?? this.createdAt,
  );
  PersonalRepostRow copyWithCompanion(PersonalRepostsCompanion data) {
    return PersonalRepostRow(
      addressableId: data.addressableId.present
          ? data.addressableId.value
          : this.addressableId,
      repostEventId: data.repostEventId.present
          ? data.repostEventId.value
          : this.repostEventId,
      originalAuthorPubkey: data.originalAuthorPubkey.present
          ? data.originalAuthorPubkey.value
          : this.originalAuthorPubkey,
      userPubkey: data.userPubkey.present
          ? data.userPubkey.value
          : this.userPubkey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonalRepostRow(')
          ..write('addressableId: $addressableId, ')
          ..write('repostEventId: $repostEventId, ')
          ..write('originalAuthorPubkey: $originalAuthorPubkey, ')
          ..write('userPubkey: $userPubkey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    addressableId,
    repostEventId,
    originalAuthorPubkey,
    userPubkey,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonalRepostRow &&
          other.addressableId == this.addressableId &&
          other.repostEventId == this.repostEventId &&
          other.originalAuthorPubkey == this.originalAuthorPubkey &&
          other.userPubkey == this.userPubkey &&
          other.createdAt == this.createdAt);
}

class PersonalRepostsCompanion extends UpdateCompanion<PersonalRepostRow> {
  final Value<String> addressableId;
  final Value<String> repostEventId;
  final Value<String> originalAuthorPubkey;
  final Value<String> userPubkey;
  final Value<int> createdAt;
  final Value<int> rowid;
  const PersonalRepostsCompanion({
    this.addressableId = const Value.absent(),
    this.repostEventId = const Value.absent(),
    this.originalAuthorPubkey = const Value.absent(),
    this.userPubkey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonalRepostsCompanion.insert({
    required String addressableId,
    required String repostEventId,
    required String originalAuthorPubkey,
    required String userPubkey,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : addressableId = Value(addressableId),
       repostEventId = Value(repostEventId),
       originalAuthorPubkey = Value(originalAuthorPubkey),
       userPubkey = Value(userPubkey),
       createdAt = Value(createdAt);
  static Insertable<PersonalRepostRow> custom({
    Expression<String>? addressableId,
    Expression<String>? repostEventId,
    Expression<String>? originalAuthorPubkey,
    Expression<String>? userPubkey,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (addressableId != null) 'addressable_id': addressableId,
      if (repostEventId != null) 'repost_event_id': repostEventId,
      if (originalAuthorPubkey != null)
        'original_author_pubkey': originalAuthorPubkey,
      if (userPubkey != null) 'user_pubkey': userPubkey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonalRepostsCompanion copyWith({
    Value<String>? addressableId,
    Value<String>? repostEventId,
    Value<String>? originalAuthorPubkey,
    Value<String>? userPubkey,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return PersonalRepostsCompanion(
      addressableId: addressableId ?? this.addressableId,
      repostEventId: repostEventId ?? this.repostEventId,
      originalAuthorPubkey: originalAuthorPubkey ?? this.originalAuthorPubkey,
      userPubkey: userPubkey ?? this.userPubkey,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (addressableId.present) {
      map['addressable_id'] = Variable<String>(addressableId.value);
    }
    if (repostEventId.present) {
      map['repost_event_id'] = Variable<String>(repostEventId.value);
    }
    if (originalAuthorPubkey.present) {
      map['original_author_pubkey'] = Variable<String>(
        originalAuthorPubkey.value,
      );
    }
    if (userPubkey.present) {
      map['user_pubkey'] = Variable<String>(userPubkey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonalRepostsCompanion(')
          ..write('addressableId: $addressableId, ')
          ..write('repostEventId: $repostEventId, ')
          ..write('originalAuthorPubkey: $originalAuthorPubkey, ')
          ..write('userPubkey: $userPubkey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonalEventsTable extends PersonalEvents
    with TableInfo<$PersonalEventsTable, PersonalEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonalEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sigMeta = const VerificationMeta('sig');
  @override
  late final GeneratedColumn<String> sig = GeneratedColumn<String>(
    'sig',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retentionMeta = const VerificationMeta(
    'retention',
  );
  @override
  late final GeneratedColumn<int> retention = GeneratedColumn<int>(
    'retention',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pubkey,
    kind,
    createdAt,
    tags,
    content,
    sig,
    retention,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'personal_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonalEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('sig')) {
      context.handle(
        _sigMeta,
        sig.isAcceptableOrUnknown(data['sig']!, _sigMeta),
      );
    } else if (isInserting) {
      context.missing(_sigMeta);
    }
    if (data.containsKey('retention')) {
      context.handle(
        _retentionMeta,
        retention.isAcceptableOrUnknown(data['retention']!, _retentionMeta),
      );
    } else if (isInserting) {
      context.missing(_retentionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonalEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonalEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sig'],
      )!,
      retention: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retention'],
      )!,
    );
  }

  @override
  $PersonalEventsTable createAlias(String alias) {
    return $PersonalEventsTable(attachedDatabase, alias);
  }
}

class PersonalEventRow extends DataClass
    implements Insertable<PersonalEventRow> {
  /// The Nostr event id (64-char hex).
  final String id;

  /// Author pubkey (64-char hex). Always the signed-in user; the column
  /// exists so reads are an indexed predicate rather than a post-hoc filter,
  /// and so one device can hold several accounts' rows without their costs
  /// leaking into each other.
  final String pubkey;
  final int kind;
  final int createdAt;

  /// JSON-encoded array of tag arrays.
  final String tags;
  final String content;
  final String sig;

  /// Retention policy applied when this row was written. See
  /// `PersonalEventRetention` in the DAO.
  final int retention;
  const PersonalEventRow({
    required this.id,
    required this.pubkey,
    required this.kind,
    required this.createdAt,
    required this.tags,
    required this.content,
    required this.sig,
    required this.retention,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pubkey'] = Variable<String>(pubkey);
    map['kind'] = Variable<int>(kind);
    map['created_at'] = Variable<int>(createdAt);
    map['tags'] = Variable<String>(tags);
    map['content'] = Variable<String>(content);
    map['sig'] = Variable<String>(sig);
    map['retention'] = Variable<int>(retention);
    return map;
  }

  PersonalEventsCompanion toCompanion(bool nullToAbsent) {
    return PersonalEventsCompanion(
      id: Value(id),
      pubkey: Value(pubkey),
      kind: Value(kind),
      createdAt: Value(createdAt),
      tags: Value(tags),
      content: Value(content),
      sig: Value(sig),
      retention: Value(retention),
    );
  }

  factory PersonalEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonalEventRow(
      id: serializer.fromJson<String>(json['id']),
      pubkey: serializer.fromJson<String>(json['pubkey']),
      kind: serializer.fromJson<int>(json['kind']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      tags: serializer.fromJson<String>(json['tags']),
      content: serializer.fromJson<String>(json['content']),
      sig: serializer.fromJson<String>(json['sig']),
      retention: serializer.fromJson<int>(json['retention']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pubkey': serializer.toJson<String>(pubkey),
      'kind': serializer.toJson<int>(kind),
      'createdAt': serializer.toJson<int>(createdAt),
      'tags': serializer.toJson<String>(tags),
      'content': serializer.toJson<String>(content),
      'sig': serializer.toJson<String>(sig),
      'retention': serializer.toJson<int>(retention),
    };
  }

  PersonalEventRow copyWith({
    String? id,
    String? pubkey,
    int? kind,
    int? createdAt,
    String? tags,
    String? content,
    String? sig,
    int? retention,
  }) => PersonalEventRow(
    id: id ?? this.id,
    pubkey: pubkey ?? this.pubkey,
    kind: kind ?? this.kind,
    createdAt: createdAt ?? this.createdAt,
    tags: tags ?? this.tags,
    content: content ?? this.content,
    sig: sig ?? this.sig,
    retention: retention ?? this.retention,
  );
  PersonalEventRow copyWithCompanion(PersonalEventsCompanion data) {
    return PersonalEventRow(
      id: data.id.present ? data.id.value : this.id,
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      kind: data.kind.present ? data.kind.value : this.kind,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      tags: data.tags.present ? data.tags.value : this.tags,
      content: data.content.present ? data.content.value : this.content,
      sig: data.sig.present ? data.sig.value : this.sig,
      retention: data.retention.present ? data.retention.value : this.retention,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonalEventRow(')
          ..write('id: $id, ')
          ..write('pubkey: $pubkey, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('tags: $tags, ')
          ..write('content: $content, ')
          ..write('sig: $sig, ')
          ..write('retention: $retention')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, pubkey, kind, createdAt, tags, content, sig, retention);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonalEventRow &&
          other.id == this.id &&
          other.pubkey == this.pubkey &&
          other.kind == this.kind &&
          other.createdAt == this.createdAt &&
          other.tags == this.tags &&
          other.content == this.content &&
          other.sig == this.sig &&
          other.retention == this.retention);
}

class PersonalEventsCompanion extends UpdateCompanion<PersonalEventRow> {
  final Value<String> id;
  final Value<String> pubkey;
  final Value<int> kind;
  final Value<int> createdAt;
  final Value<String> tags;
  final Value<String> content;
  final Value<String> sig;
  final Value<int> retention;
  final Value<int> rowid;
  const PersonalEventsCompanion({
    this.id = const Value.absent(),
    this.pubkey = const Value.absent(),
    this.kind = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.tags = const Value.absent(),
    this.content = const Value.absent(),
    this.sig = const Value.absent(),
    this.retention = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonalEventsCompanion.insert({
    required String id,
    required String pubkey,
    required int kind,
    required int createdAt,
    required String tags,
    required String content,
    required String sig,
    required int retention,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pubkey = Value(pubkey),
       kind = Value(kind),
       createdAt = Value(createdAt),
       tags = Value(tags),
       content = Value(content),
       sig = Value(sig),
       retention = Value(retention);
  static Insertable<PersonalEventRow> custom({
    Expression<String>? id,
    Expression<String>? pubkey,
    Expression<int>? kind,
    Expression<int>? createdAt,
    Expression<String>? tags,
    Expression<String>? content,
    Expression<String>? sig,
    Expression<int>? retention,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pubkey != null) 'pubkey': pubkey,
      if (kind != null) 'kind': kind,
      if (createdAt != null) 'created_at': createdAt,
      if (tags != null) 'tags': tags,
      if (content != null) 'content': content,
      if (sig != null) 'sig': sig,
      if (retention != null) 'retention': retention,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonalEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? pubkey,
    Value<int>? kind,
    Value<int>? createdAt,
    Value<String>? tags,
    Value<String>? content,
    Value<String>? sig,
    Value<int>? retention,
    Value<int>? rowid,
  }) {
    return PersonalEventsCompanion(
      id: id ?? this.id,
      pubkey: pubkey ?? this.pubkey,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      content: content ?? this.content,
      sig: sig ?? this.sig,
      retention: retention ?? this.retention,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sig.present) {
      map['sig'] = Variable<String>(sig.value);
    }
    if (retention.present) {
      map['retention'] = Variable<int>(retention.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonalEventsCompanion(')
          ..write('id: $id, ')
          ..write('pubkey: $pubkey, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('tags: $tags, ')
          ..write('content: $content, ')
          ..write('sig: $sig, ')
          ..write('retention: $retention, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingActionsTable extends PendingActions
    with TableInfo<$PendingActionsTable, PendingActionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorPubkeyMeta = const VerificationMeta(
    'authorPubkey',
  );
  @override
  late final GeneratedColumn<String> authorPubkey = GeneratedColumn<String>(
    'author_pubkey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressableIdMeta = const VerificationMeta(
    'addressableId',
  );
  @override
  late final GeneratedColumn<String> addressableId = GeneratedColumn<String>(
    'addressable_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetKindMeta = const VerificationMeta(
    'targetKind',
  );
  @override
  late final GeneratedColumn<int> targetKind = GeneratedColumn<int>(
    'target_kind',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userPubkeyMeta = const VerificationMeta(
    'userPubkey',
  );
  @override
  late final GeneratedColumn<String> userPubkey = GeneratedColumn<String>(
    'user_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    targetId,
    authorPubkey,
    addressableId,
    targetKind,
    status,
    userPubkey,
    createdAt,
    retryCount,
    lastError,
    lastAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingActionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('author_pubkey')) {
      context.handle(
        _authorPubkeyMeta,
        authorPubkey.isAcceptableOrUnknown(
          data['author_pubkey']!,
          _authorPubkeyMeta,
        ),
      );
    }
    if (data.containsKey('addressable_id')) {
      context.handle(
        _addressableIdMeta,
        addressableId.isAcceptableOrUnknown(
          data['addressable_id']!,
          _addressableIdMeta,
        ),
      );
    }
    if (data.containsKey('target_kind')) {
      context.handle(
        _targetKindMeta,
        targetKind.isAcceptableOrUnknown(data['target_kind']!, _targetKindMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('user_pubkey')) {
      context.handle(
        _userPubkeyMeta,
        userPubkey.isAcceptableOrUnknown(data['user_pubkey']!, _userPubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_userPubkeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingActionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingActionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      authorPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_pubkey'],
      ),
      addressableId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}addressable_id'],
      ),
      targetKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_kind'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      userPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_pubkey'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
    );
  }

  @override
  $PendingActionsTable createAlias(String alias) {
    return $PendingActionsTable(attachedDatabase, alias);
  }
}

class PendingActionRow extends DataClass
    implements Insertable<PendingActionRow> {
  /// Unique identifier for this action
  final String id;

  /// Type of action: like, unlike, repost, unrepost, follow, unfollow
  final String type;

  /// Target event ID (for likes/reposts) or pubkey (for follows)
  final String targetId;

  /// Pubkey of the original event author (for likes/reposts)
  final String? authorPubkey;

  /// Addressable ID for reposts (format: "kind:pubkey:d-tag")
  final String? addressableId;

  /// Kind of the target event (e.g., 34236 for videos)
  final int? targetKind;

  /// Current sync status: pending, syncing, completed, failed
  final String status;

  /// The pubkey of the user who queued this action
  final String userPubkey;

  /// When the action was queued
  final DateTime createdAt;

  /// Number of sync attempts
  final int retryCount;

  /// Last error message if sync failed
  final String? lastError;

  /// Timestamp of last sync attempt
  final DateTime? lastAttemptAt;
  const PendingActionRow({
    required this.id,
    required this.type,
    required this.targetId,
    this.authorPubkey,
    this.addressableId,
    this.targetKind,
    required this.status,
    required this.userPubkey,
    required this.createdAt,
    required this.retryCount,
    this.lastError,
    this.lastAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['target_id'] = Variable<String>(targetId);
    if (!nullToAbsent || authorPubkey != null) {
      map['author_pubkey'] = Variable<String>(authorPubkey);
    }
    if (!nullToAbsent || addressableId != null) {
      map['addressable_id'] = Variable<String>(addressableId);
    }
    if (!nullToAbsent || targetKind != null) {
      map['target_kind'] = Variable<int>(targetKind);
    }
    map['status'] = Variable<String>(status);
    map['user_pubkey'] = Variable<String>(userPubkey);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    return map;
  }

  PendingActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingActionsCompanion(
      id: Value(id),
      type: Value(type),
      targetId: Value(targetId),
      authorPubkey: authorPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(authorPubkey),
      addressableId: addressableId == null && nullToAbsent
          ? const Value.absent()
          : Value(addressableId),
      targetKind: targetKind == null && nullToAbsent
          ? const Value.absent()
          : Value(targetKind),
      status: Value(status),
      userPubkey: Value(userPubkey),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory PendingActionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingActionRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      targetId: serializer.fromJson<String>(json['targetId']),
      authorPubkey: serializer.fromJson<String?>(json['authorPubkey']),
      addressableId: serializer.fromJson<String?>(json['addressableId']),
      targetKind: serializer.fromJson<int?>(json['targetKind']),
      status: serializer.fromJson<String>(json['status']),
      userPubkey: serializer.fromJson<String>(json['userPubkey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'targetId': serializer.toJson<String>(targetId),
      'authorPubkey': serializer.toJson<String?>(authorPubkey),
      'addressableId': serializer.toJson<String?>(addressableId),
      'targetKind': serializer.toJson<int?>(targetKind),
      'status': serializer.toJson<String>(status),
      'userPubkey': serializer.toJson<String>(userPubkey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  PendingActionRow copyWith({
    String? id,
    String? type,
    String? targetId,
    Value<String?> authorPubkey = const Value.absent(),
    Value<String?> addressableId = const Value.absent(),
    Value<int?> targetKind = const Value.absent(),
    String? status,
    String? userPubkey,
    DateTime? createdAt,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
  }) => PendingActionRow(
    id: id ?? this.id,
    type: type ?? this.type,
    targetId: targetId ?? this.targetId,
    authorPubkey: authorPubkey.present ? authorPubkey.value : this.authorPubkey,
    addressableId: addressableId.present
        ? addressableId.value
        : this.addressableId,
    targetKind: targetKind.present ? targetKind.value : this.targetKind,
    status: status ?? this.status,
    userPubkey: userPubkey ?? this.userPubkey,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
  );
  PendingActionRow copyWithCompanion(PendingActionsCompanion data) {
    return PendingActionRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      authorPubkey: data.authorPubkey.present
          ? data.authorPubkey.value
          : this.authorPubkey,
      addressableId: data.addressableId.present
          ? data.addressableId.value
          : this.addressableId,
      targetKind: data.targetKind.present
          ? data.targetKind.value
          : this.targetKind,
      status: data.status.present ? data.status.value : this.status,
      userPubkey: data.userPubkey.present
          ? data.userPubkey.value
          : this.userPubkey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingActionRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('targetId: $targetId, ')
          ..write('authorPubkey: $authorPubkey, ')
          ..write('addressableId: $addressableId, ')
          ..write('targetKind: $targetKind, ')
          ..write('status: $status, ')
          ..write('userPubkey: $userPubkey, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    targetId,
    authorPubkey,
    addressableId,
    targetKind,
    status,
    userPubkey,
    createdAt,
    retryCount,
    lastError,
    lastAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingActionRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.targetId == this.targetId &&
          other.authorPubkey == this.authorPubkey &&
          other.addressableId == this.addressableId &&
          other.targetKind == this.targetKind &&
          other.status == this.status &&
          other.userPubkey == this.userPubkey &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class PendingActionsCompanion extends UpdateCompanion<PendingActionRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> targetId;
  final Value<String?> authorPubkey;
  final Value<String?> addressableId;
  final Value<int?> targetKind;
  final Value<String> status;
  final Value<String> userPubkey;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> rowid;
  const PendingActionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.targetId = const Value.absent(),
    this.authorPubkey = const Value.absent(),
    this.addressableId = const Value.absent(),
    this.targetKind = const Value.absent(),
    this.status = const Value.absent(),
    this.userPubkey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingActionsCompanion.insert({
    required String id,
    required String type,
    required String targetId,
    this.authorPubkey = const Value.absent(),
    this.addressableId = const Value.absent(),
    this.targetKind = const Value.absent(),
    required String status,
    required String userPubkey,
    required DateTime createdAt,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       targetId = Value(targetId),
       status = Value(status),
       userPubkey = Value(userPubkey),
       createdAt = Value(createdAt);
  static Insertable<PendingActionRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? targetId,
    Expression<String>? authorPubkey,
    Expression<String>? addressableId,
    Expression<int>? targetKind,
    Expression<String>? status,
    Expression<String>? userPubkey,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (targetId != null) 'target_id': targetId,
      if (authorPubkey != null) 'author_pubkey': authorPubkey,
      if (addressableId != null) 'addressable_id': addressableId,
      if (targetKind != null) 'target_kind': targetKind,
      if (status != null) 'status': status,
      if (userPubkey != null) 'user_pubkey': userPubkey,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingActionsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? targetId,
    Value<String?>? authorPubkey,
    Value<String?>? addressableId,
    Value<int?>? targetKind,
    Value<String>? status,
    Value<String>? userPubkey,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<DateTime?>? lastAttemptAt,
    Value<int>? rowid,
  }) {
    return PendingActionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      authorPubkey: authorPubkey ?? this.authorPubkey,
      addressableId: addressableId ?? this.addressableId,
      targetKind: targetKind ?? this.targetKind,
      status: status ?? this.status,
      userPubkey: userPubkey ?? this.userPubkey,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (authorPubkey.present) {
      map['author_pubkey'] = Variable<String>(authorPubkey.value);
    }
    if (addressableId.present) {
      map['addressable_id'] = Variable<String>(addressableId.value);
    }
    if (targetKind.present) {
      map['target_kind'] = Variable<int>(targetKind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (userPubkey.present) {
      map['user_pubkey'] = Variable<String>(userPubkey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingActionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('targetId: $targetId, ')
          ..write('authorPubkey: $authorPubkey, ')
          ..write('addressableId: $addressableId, ')
          ..write('targetKind: $targetKind, ')
          ..write('status: $status, ')
          ..write('userPubkey: $userPubkey, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $Nip05VerificationsTable extends Nip05Verifications
    with TableInfo<$Nip05VerificationsTable, Nip05VerificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $Nip05VerificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nip05Meta = const VerificationMeta('nip05');
  @override
  late final GeneratedColumn<String> nip05 = GeneratedColumn<String>(
    'nip05',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifiedAtMeta = const VerificationMeta(
    'verifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> verifiedAt = GeneratedColumn<DateTime>(
    'verified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pubkey,
    nip05,
    status,
    verifiedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nip05_verifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<Nip05VerificationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('nip05')) {
      context.handle(
        _nip05Meta,
        nip05.isAcceptableOrUnknown(data['nip05']!, _nip05Meta),
      );
    } else if (isInserting) {
      context.missing(_nip05Meta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('verified_at')) {
      context.handle(
        _verifiedAtMeta,
        verifiedAt.isAcceptableOrUnknown(data['verified_at']!, _verifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_verifiedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubkey};
  @override
  Nip05VerificationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Nip05VerificationRow(
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      nip05: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nip05'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      verifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}verified_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $Nip05VerificationsTable createAlias(String alias) {
    return $Nip05VerificationsTable(attachedDatabase, alias);
  }
}

class Nip05VerificationRow extends DataClass
    implements Insertable<Nip05VerificationRow> {
  /// The pubkey of the user whose NIP-05 is being verified
  final String pubkey;

  /// The claimed NIP-05 address (e.g., "alice@example.com")
  final String nip05;

  /// Verification status: 'verified', 'failed', 'error', 'pending'
  final String status;

  /// When the verification was performed
  final DateTime verifiedAt;

  /// When this cache entry expires (TTL-based)
  final DateTime expiresAt;
  const Nip05VerificationRow({
    required this.pubkey,
    required this.nip05,
    required this.status,
    required this.verifiedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey'] = Variable<String>(pubkey);
    map['nip05'] = Variable<String>(nip05);
    map['status'] = Variable<String>(status);
    map['verified_at'] = Variable<DateTime>(verifiedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  Nip05VerificationsCompanion toCompanion(bool nullToAbsent) {
    return Nip05VerificationsCompanion(
      pubkey: Value(pubkey),
      nip05: Value(nip05),
      status: Value(status),
      verifiedAt: Value(verifiedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory Nip05VerificationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Nip05VerificationRow(
      pubkey: serializer.fromJson<String>(json['pubkey']),
      nip05: serializer.fromJson<String>(json['nip05']),
      status: serializer.fromJson<String>(json['status']),
      verifiedAt: serializer.fromJson<DateTime>(json['verifiedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkey': serializer.toJson<String>(pubkey),
      'nip05': serializer.toJson<String>(nip05),
      'status': serializer.toJson<String>(status),
      'verifiedAt': serializer.toJson<DateTime>(verifiedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  Nip05VerificationRow copyWith({
    String? pubkey,
    String? nip05,
    String? status,
    DateTime? verifiedAt,
    DateTime? expiresAt,
  }) => Nip05VerificationRow(
    pubkey: pubkey ?? this.pubkey,
    nip05: nip05 ?? this.nip05,
    status: status ?? this.status,
    verifiedAt: verifiedAt ?? this.verifiedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  Nip05VerificationRow copyWithCompanion(Nip05VerificationsCompanion data) {
    return Nip05VerificationRow(
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      nip05: data.nip05.present ? data.nip05.value : this.nip05,
      status: data.status.present ? data.status.value : this.status,
      verifiedAt: data.verifiedAt.present
          ? data.verifiedAt.value
          : this.verifiedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Nip05VerificationRow(')
          ..write('pubkey: $pubkey, ')
          ..write('nip05: $nip05, ')
          ..write('status: $status, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pubkey, nip05, status, verifiedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Nip05VerificationRow &&
          other.pubkey == this.pubkey &&
          other.nip05 == this.nip05 &&
          other.status == this.status &&
          other.verifiedAt == this.verifiedAt &&
          other.expiresAt == this.expiresAt);
}

class Nip05VerificationsCompanion
    extends UpdateCompanion<Nip05VerificationRow> {
  final Value<String> pubkey;
  final Value<String> nip05;
  final Value<String> status;
  final Value<DateTime> verifiedAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const Nip05VerificationsCompanion({
    this.pubkey = const Value.absent(),
    this.nip05 = const Value.absent(),
    this.status = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  Nip05VerificationsCompanion.insert({
    required String pubkey,
    required String nip05,
    required String status,
    required DateTime verifiedAt,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : pubkey = Value(pubkey),
       nip05 = Value(nip05),
       status = Value(status),
       verifiedAt = Value(verifiedAt),
       expiresAt = Value(expiresAt);
  static Insertable<Nip05VerificationRow> custom({
    Expression<String>? pubkey,
    Expression<String>? nip05,
    Expression<String>? status,
    Expression<DateTime>? verifiedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkey != null) 'pubkey': pubkey,
      if (nip05 != null) 'nip05': nip05,
      if (status != null) 'status': status,
      if (verifiedAt != null) 'verified_at': verifiedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  Nip05VerificationsCompanion copyWith({
    Value<String>? pubkey,
    Value<String>? nip05,
    Value<String>? status,
    Value<DateTime>? verifiedAt,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return Nip05VerificationsCompanion(
      pubkey: pubkey ?? this.pubkey,
      nip05: nip05 ?? this.nip05,
      status: status ?? this.status,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (nip05.present) {
      map['nip05'] = Variable<String>(nip05.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (verifiedAt.present) {
      map['verified_at'] = Variable<DateTime>(verifiedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('Nip05VerificationsCompanion(')
          ..write('pubkey: $pubkey, ')
          ..write('nip05: $nip05, ')
          ..write('status: $status, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, DraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _publishStatusMeta = const VerificationMeta(
    'publishStatus',
  );
  @override
  late final GeneratedColumn<String> publishStatus = GeneratedColumn<String>(
    'publish_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _publishAttemptsMeta = const VerificationMeta(
    'publishAttempts',
  );
  @override
  late final GeneratedColumn<int> publishAttempts = GeneratedColumn<int>(
    'publish_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _publishErrorMeta = const VerificationMeta(
    'publishError',
  );
  @override
  late final GeneratedColumn<String> publishError = GeneratedColumn<String>(
    'publish_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _renderedFilePathMeta = const VerificationMeta(
    'renderedFilePath',
  );
  @override
  late final GeneratedColumn<String> renderedFilePath = GeneratedColumn<String>(
    'rendered_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _renderedThumbnailPathMeta =
      const VerificationMeta('renderedThumbnailPath');
  @override
  late final GeneratedColumn<String> renderedThumbnailPath =
      GeneratedColumn<String>(
        'rendered_thumbnail_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _customThumbnailPathMeta =
      const VerificationMeta('customThumbnailPath');
  @override
  late final GeneratedColumn<String> customThumbnailPath =
      GeneratedColumn<String>(
        'custom_thumbnail_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    publishStatus,
    publishAttempts,
    publishError,
    createdAt,
    lastModified,
    data,
    renderedFilePath,
    renderedThumbnailPath,
    customThumbnailPath,
    ownerPubkey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('publish_status')) {
      context.handle(
        _publishStatusMeta,
        publishStatus.isAcceptableOrUnknown(
          data['publish_status']!,
          _publishStatusMeta,
        ),
      );
    }
    if (data.containsKey('publish_attempts')) {
      context.handle(
        _publishAttemptsMeta,
        publishAttempts.isAcceptableOrUnknown(
          data['publish_attempts']!,
          _publishAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('publish_error')) {
      context.handle(
        _publishErrorMeta,
        publishError.isAcceptableOrUnknown(
          data['publish_error']!,
          _publishErrorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('rendered_file_path')) {
      context.handle(
        _renderedFilePathMeta,
        renderedFilePath.isAcceptableOrUnknown(
          data['rendered_file_path']!,
          _renderedFilePathMeta,
        ),
      );
    }
    if (data.containsKey('rendered_thumbnail_path')) {
      context.handle(
        _renderedThumbnailPathMeta,
        renderedThumbnailPath.isAcceptableOrUnknown(
          data['rendered_thumbnail_path']!,
          _renderedThumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('custom_thumbnail_path')) {
      context.handle(
        _customThumbnailPathMeta,
        customThumbnailPath.isAcceptableOrUnknown(
          data['custom_thumbnail_path']!,
          _customThumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      publishStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publish_status'],
      )!,
      publishAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}publish_attempts'],
      )!,
      publishError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publish_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      renderedFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rendered_file_path'],
      ),
      renderedThumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rendered_thumbnail_path'],
      ),
      customThumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_thumbnail_path'],
      ),
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      ),
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class DraftRow extends DataClass implements Insertable<DraftRow> {
  /// Unique draft identifier (e.g. "draft_1700000000000")
  final String id;

  /// User-provided title (may be empty)
  final String title;

  /// User-provided description (may be empty)
  final String description;

  /// Current publish status: draft, publishing, failed, published
  final String publishStatus;

  /// Number of publish attempts
  final int publishAttempts;

  /// Last publish error message
  final String? publishError;

  /// When the draft was originally created
  final DateTime createdAt;

  /// When the draft was last modified
  final DateTime lastModified;

  /// Full JSON-serialized draft payload (clips, hashtags, editor state, etc.)
  final String data;

  /// Basename of the final rendered video file (for indexed lookups)
  final String? renderedFilePath;

  /// Basename of the final rendered thumbnail (for indexed lookups)
  final String? renderedThumbnailPath;

  /// Basename of the selected custom cover thumbnail (for indexed lookups)
  final String? customThumbnailPath;

  /// Hex public key of the account that owns this draft.
  /// NULL for legacy drafts created before multi-account support.
  final String? ownerPubkey;
  const DraftRow({
    required this.id,
    required this.title,
    required this.description,
    required this.publishStatus,
    required this.publishAttempts,
    this.publishError,
    required this.createdAt,
    required this.lastModified,
    required this.data,
    this.renderedFilePath,
    this.renderedThumbnailPath,
    this.customThumbnailPath,
    this.ownerPubkey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['publish_status'] = Variable<String>(publishStatus);
    map['publish_attempts'] = Variable<int>(publishAttempts);
    if (!nullToAbsent || publishError != null) {
      map['publish_error'] = Variable<String>(publishError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_modified'] = Variable<DateTime>(lastModified);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || renderedFilePath != null) {
      map['rendered_file_path'] = Variable<String>(renderedFilePath);
    }
    if (!nullToAbsent || renderedThumbnailPath != null) {
      map['rendered_thumbnail_path'] = Variable<String>(renderedThumbnailPath);
    }
    if (!nullToAbsent || customThumbnailPath != null) {
      map['custom_thumbnail_path'] = Variable<String>(customThumbnailPath);
    }
    if (!nullToAbsent || ownerPubkey != null) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey);
    }
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      publishStatus: Value(publishStatus),
      publishAttempts: Value(publishAttempts),
      publishError: publishError == null && nullToAbsent
          ? const Value.absent()
          : Value(publishError),
      createdAt: Value(createdAt),
      lastModified: Value(lastModified),
      data: Value(data),
      renderedFilePath: renderedFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(renderedFilePath),
      renderedThumbnailPath: renderedThumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(renderedThumbnailPath),
      customThumbnailPath: customThumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(customThumbnailPath),
      ownerPubkey: ownerPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerPubkey),
    );
  }

  factory DraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      publishStatus: serializer.fromJson<String>(json['publishStatus']),
      publishAttempts: serializer.fromJson<int>(json['publishAttempts']),
      publishError: serializer.fromJson<String?>(json['publishError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      data: serializer.fromJson<String>(json['data']),
      renderedFilePath: serializer.fromJson<String?>(json['renderedFilePath']),
      renderedThumbnailPath: serializer.fromJson<String?>(
        json['renderedThumbnailPath'],
      ),
      customThumbnailPath: serializer.fromJson<String?>(
        json['customThumbnailPath'],
      ),
      ownerPubkey: serializer.fromJson<String?>(json['ownerPubkey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'publishStatus': serializer.toJson<String>(publishStatus),
      'publishAttempts': serializer.toJson<int>(publishAttempts),
      'publishError': serializer.toJson<String?>(publishError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'data': serializer.toJson<String>(data),
      'renderedFilePath': serializer.toJson<String?>(renderedFilePath),
      'renderedThumbnailPath': serializer.toJson<String?>(
        renderedThumbnailPath,
      ),
      'customThumbnailPath': serializer.toJson<String?>(customThumbnailPath),
      'ownerPubkey': serializer.toJson<String?>(ownerPubkey),
    };
  }

  DraftRow copyWith({
    String? id,
    String? title,
    String? description,
    String? publishStatus,
    int? publishAttempts,
    Value<String?> publishError = const Value.absent(),
    DateTime? createdAt,
    DateTime? lastModified,
    String? data,
    Value<String?> renderedFilePath = const Value.absent(),
    Value<String?> renderedThumbnailPath = const Value.absent(),
    Value<String?> customThumbnailPath = const Value.absent(),
    Value<String?> ownerPubkey = const Value.absent(),
  }) => DraftRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    publishStatus: publishStatus ?? this.publishStatus,
    publishAttempts: publishAttempts ?? this.publishAttempts,
    publishError: publishError.present ? publishError.value : this.publishError,
    createdAt: createdAt ?? this.createdAt,
    lastModified: lastModified ?? this.lastModified,
    data: data ?? this.data,
    renderedFilePath: renderedFilePath.present
        ? renderedFilePath.value
        : this.renderedFilePath,
    renderedThumbnailPath: renderedThumbnailPath.present
        ? renderedThumbnailPath.value
        : this.renderedThumbnailPath,
    customThumbnailPath: customThumbnailPath.present
        ? customThumbnailPath.value
        : this.customThumbnailPath,
    ownerPubkey: ownerPubkey.present ? ownerPubkey.value : this.ownerPubkey,
  );
  DraftRow copyWithCompanion(DraftsCompanion data) {
    return DraftRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      publishStatus: data.publishStatus.present
          ? data.publishStatus.value
          : this.publishStatus,
      publishAttempts: data.publishAttempts.present
          ? data.publishAttempts.value
          : this.publishAttempts,
      publishError: data.publishError.present
          ? data.publishError.value
          : this.publishError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      data: data.data.present ? data.data.value : this.data,
      renderedFilePath: data.renderedFilePath.present
          ? data.renderedFilePath.value
          : this.renderedFilePath,
      renderedThumbnailPath: data.renderedThumbnailPath.present
          ? data.renderedThumbnailPath.value
          : this.renderedThumbnailPath,
      customThumbnailPath: data.customThumbnailPath.present
          ? data.customThumbnailPath.value
          : this.customThumbnailPath,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('publishStatus: $publishStatus, ')
          ..write('publishAttempts: $publishAttempts, ')
          ..write('publishError: $publishError, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastModified: $lastModified, ')
          ..write('data: $data, ')
          ..write('renderedFilePath: $renderedFilePath, ')
          ..write('renderedThumbnailPath: $renderedThumbnailPath, ')
          ..write('customThumbnailPath: $customThumbnailPath, ')
          ..write('ownerPubkey: $ownerPubkey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    publishStatus,
    publishAttempts,
    publishError,
    createdAt,
    lastModified,
    data,
    renderedFilePath,
    renderedThumbnailPath,
    customThumbnailPath,
    ownerPubkey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.publishStatus == this.publishStatus &&
          other.publishAttempts == this.publishAttempts &&
          other.publishError == this.publishError &&
          other.createdAt == this.createdAt &&
          other.lastModified == this.lastModified &&
          other.data == this.data &&
          other.renderedFilePath == this.renderedFilePath &&
          other.renderedThumbnailPath == this.renderedThumbnailPath &&
          other.customThumbnailPath == this.customThumbnailPath &&
          other.ownerPubkey == this.ownerPubkey);
}

class DraftsCompanion extends UpdateCompanion<DraftRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> publishStatus;
  final Value<int> publishAttempts;
  final Value<String?> publishError;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastModified;
  final Value<String> data;
  final Value<String?> renderedFilePath;
  final Value<String?> renderedThumbnailPath;
  final Value<String?> customThumbnailPath;
  final Value<String?> ownerPubkey;
  final Value<int> rowid;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.publishStatus = const Value.absent(),
    this.publishAttempts = const Value.absent(),
    this.publishError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.data = const Value.absent(),
    this.renderedFilePath = const Value.absent(),
    this.renderedThumbnailPath = const Value.absent(),
    this.customThumbnailPath = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.publishStatus = const Value.absent(),
    this.publishAttempts = const Value.absent(),
    this.publishError = const Value.absent(),
    required DateTime createdAt,
    required DateTime lastModified,
    required String data,
    this.renderedFilePath = const Value.absent(),
    this.renderedThumbnailPath = const Value.absent(),
    this.customThumbnailPath = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       lastModified = Value(lastModified),
       data = Value(data);
  static Insertable<DraftRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? publishStatus,
    Expression<int>? publishAttempts,
    Expression<String>? publishError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastModified,
    Expression<String>? data,
    Expression<String>? renderedFilePath,
    Expression<String>? renderedThumbnailPath,
    Expression<String>? customThumbnailPath,
    Expression<String>? ownerPubkey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (publishStatus != null) 'publish_status': publishStatus,
      if (publishAttempts != null) 'publish_attempts': publishAttempts,
      if (publishError != null) 'publish_error': publishError,
      if (createdAt != null) 'created_at': createdAt,
      if (lastModified != null) 'last_modified': lastModified,
      if (data != null) 'data': data,
      if (renderedFilePath != null) 'rendered_file_path': renderedFilePath,
      if (renderedThumbnailPath != null)
        'rendered_thumbnail_path': renderedThumbnailPath,
      if (customThumbnailPath != null)
        'custom_thumbnail_path': customThumbnailPath,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? publishStatus,
    Value<int>? publishAttempts,
    Value<String?>? publishError,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastModified,
    Value<String>? data,
    Value<String?>? renderedFilePath,
    Value<String?>? renderedThumbnailPath,
    Value<String?>? customThumbnailPath,
    Value<String?>? ownerPubkey,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      publishStatus: publishStatus ?? this.publishStatus,
      publishAttempts: publishAttempts ?? this.publishAttempts,
      publishError: publishError ?? this.publishError,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      data: data ?? this.data,
      renderedFilePath: renderedFilePath ?? this.renderedFilePath,
      renderedThumbnailPath:
          renderedThumbnailPath ?? this.renderedThumbnailPath,
      customThumbnailPath: customThumbnailPath ?? this.customThumbnailPath,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (publishStatus.present) {
      map['publish_status'] = Variable<String>(publishStatus.value);
    }
    if (publishAttempts.present) {
      map['publish_attempts'] = Variable<int>(publishAttempts.value);
    }
    if (publishError.present) {
      map['publish_error'] = Variable<String>(publishError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (renderedFilePath.present) {
      map['rendered_file_path'] = Variable<String>(renderedFilePath.value);
    }
    if (renderedThumbnailPath.present) {
      map['rendered_thumbnail_path'] = Variable<String>(
        renderedThumbnailPath.value,
      );
    }
    if (customThumbnailPath.present) {
      map['custom_thumbnail_path'] = Variable<String>(
        customThumbnailPath.value,
      );
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('publishStatus: $publishStatus, ')
          ..write('publishAttempts: $publishAttempts, ')
          ..write('publishError: $publishError, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastModified: $lastModified, ')
          ..write('data: $data, ')
          ..write('renderedFilePath: $renderedFilePath, ')
          ..write('renderedThumbnailPath: $renderedThumbnailPath, ')
          ..write('customThumbnailPath: $customThumbnailPath, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClipsTable extends Clips with TableInfo<$ClipsTable, ClipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    draftId,
    orderIndex,
    durationMs,
    recordedAt,
    data,
    filePath,
    thumbnailPath,
    ownerPubkey,
    deletedAt,
    categoryId,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clips';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClipRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClipRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $ClipsTable createAlias(String alias) {
    return $ClipsTable(attachedDatabase, alias);
  }
}

class ClipRow extends DataClass implements Insertable<ClipRow> {
  /// Unique clip identifier
  final String id;

  /// Foreign key to the parent draft (null for library clips)
  final String? draftId;

  /// Position of this clip within the draft (0-based)
  final int orderIndex;

  /// Duration in milliseconds
  final int durationMs;

  /// When the clip was recorded
  final DateTime recordedAt;

  /// Full JSON-serialized clip payload (file path, thumbnail, lens metadata,
  /// aspect ratio, etc.)
  final String data;

  /// Basename of the video file (for indexed lookups)
  final String? filePath;

  /// Basename of the thumbnail file (for indexed lookups)
  final String? thumbnailPath;

  /// Hex public key of the account that owns this clip.
  /// NULL for legacy clips created before multi-account support.
  final String? ownerPubkey;

  /// Soft-delete marker. NULL = active; non-NULL = in trash since this time.
  /// Trashed clips are filtered out of normal queries and purged after the
  /// retention window. See `ClipLibraryService.purgeExpiredTrash`.
  final DateTime? deletedAt;

  /// Id of the user-created [ClipCategories] row this clip is filed under.
  /// NULL = uncategorized. Cleared when its category is deleted.
  final String? categoryId;

  /// Archive marker. NULL = active; non-NULL = archived since this time.
  /// Archived clips are hidden from the library's default view and shown
  /// under its Archive filter and any category they remain filed under.
  final DateTime? archivedAt;
  const ClipRow({
    required this.id,
    this.draftId,
    required this.orderIndex,
    required this.durationMs,
    required this.recordedAt,
    required this.data,
    this.filePath,
    this.thumbnailPath,
    this.ownerPubkey,
    this.deletedAt,
    this.categoryId,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || draftId != null) {
      map['draft_id'] = Variable<String>(draftId);
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['duration_ms'] = Variable<int>(durationMs);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || ownerPubkey != null) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  ClipsCompanion toCompanion(bool nullToAbsent) {
    return ClipsCompanion(
      id: Value(id),
      draftId: draftId == null && nullToAbsent
          ? const Value.absent()
          : Value(draftId),
      orderIndex: Value(orderIndex),
      durationMs: Value(durationMs),
      recordedAt: Value(recordedAt),
      data: Value(data),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      ownerPubkey: ownerPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerPubkey),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory ClipRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipRow(
      id: serializer.fromJson<String>(json['id']),
      draftId: serializer.fromJson<String?>(json['draftId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      data: serializer.fromJson<String>(json['data']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      ownerPubkey: serializer.fromJson<String?>(json['ownerPubkey']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'draftId': serializer.toJson<String?>(draftId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'durationMs': serializer.toJson<int>(durationMs),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'data': serializer.toJson<String>(data),
      'filePath': serializer.toJson<String?>(filePath),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'ownerPubkey': serializer.toJson<String?>(ownerPubkey),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'categoryId': serializer.toJson<String?>(categoryId),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  ClipRow copyWith({
    String? id,
    Value<String?> draftId = const Value.absent(),
    int? orderIndex,
    int? durationMs,
    DateTime? recordedAt,
    String? data,
    Value<String?> filePath = const Value.absent(),
    Value<String?> thumbnailPath = const Value.absent(),
    Value<String?> ownerPubkey = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => ClipRow(
    id: id ?? this.id,
    draftId: draftId.present ? draftId.value : this.draftId,
    orderIndex: orderIndex ?? this.orderIndex,
    durationMs: durationMs ?? this.durationMs,
    recordedAt: recordedAt ?? this.recordedAt,
    data: data ?? this.data,
    filePath: filePath.present ? filePath.value : this.filePath,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    ownerPubkey: ownerPubkey.present ? ownerPubkey.value : this.ownerPubkey,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  ClipRow copyWithCompanion(ClipsCompanion data) {
    return ClipRow(
      id: data.id.present ? data.id.value : this.id,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      data: data.data.present ? data.data.value : this.data,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipRow(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('durationMs: $durationMs, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('data: $data, ')
          ..write('filePath: $filePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('categoryId: $categoryId, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    draftId,
    orderIndex,
    durationMs,
    recordedAt,
    data,
    filePath,
    thumbnailPath,
    ownerPubkey,
    deletedAt,
    categoryId,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipRow &&
          other.id == this.id &&
          other.draftId == this.draftId &&
          other.orderIndex == this.orderIndex &&
          other.durationMs == this.durationMs &&
          other.recordedAt == this.recordedAt &&
          other.data == this.data &&
          other.filePath == this.filePath &&
          other.thumbnailPath == this.thumbnailPath &&
          other.ownerPubkey == this.ownerPubkey &&
          other.deletedAt == this.deletedAt &&
          other.categoryId == this.categoryId &&
          other.archivedAt == this.archivedAt);
}

class ClipsCompanion extends UpdateCompanion<ClipRow> {
  final Value<String> id;
  final Value<String?> draftId;
  final Value<int> orderIndex;
  final Value<int> durationMs;
  final Value<DateTime> recordedAt;
  final Value<String> data;
  final Value<String?> filePath;
  final Value<String?> thumbnailPath;
  final Value<String?> ownerPubkey;
  final Value<DateTime?> deletedAt;
  final Value<String?> categoryId;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const ClipsCompanion({
    this.id = const Value.absent(),
    this.draftId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.data = const Value.absent(),
    this.filePath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClipsCompanion.insert({
    required String id,
    this.draftId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    required int durationMs,
    required DateTime recordedAt,
    required String data,
    this.filePath = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       durationMs = Value(durationMs),
       recordedAt = Value(recordedAt),
       data = Value(data);
  static Insertable<ClipRow> custom({
    Expression<String>? id,
    Expression<String>? draftId,
    Expression<int>? orderIndex,
    Expression<int>? durationMs,
    Expression<DateTime>? recordedAt,
    Expression<String>? data,
    Expression<String>? filePath,
    Expression<String>? thumbnailPath,
    Expression<String>? ownerPubkey,
    Expression<DateTime>? deletedAt,
    Expression<String>? categoryId,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (draftId != null) 'draft_id': draftId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (durationMs != null) 'duration_ms': durationMs,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (data != null) 'data': data,
      if (filePath != null) 'file_path': filePath,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (categoryId != null) 'category_id': categoryId,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClipsCompanion copyWith({
    Value<String>? id,
    Value<String?>? draftId,
    Value<int>? orderIndex,
    Value<int>? durationMs,
    Value<DateTime>? recordedAt,
    Value<String>? data,
    Value<String?>? filePath,
    Value<String?>? thumbnailPath,
    Value<String?>? ownerPubkey,
    Value<DateTime?>? deletedAt,
    Value<String?>? categoryId,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return ClipsCompanion(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      orderIndex: orderIndex ?? this.orderIndex,
      durationMs: durationMs ?? this.durationMs,
      recordedAt: recordedAt ?? this.recordedAt,
      data: data ?? this.data,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      deletedAt: deletedAt ?? this.deletedAt,
      categoryId: categoryId ?? this.categoryId,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipsCompanion(')
          ..write('id: $id, ')
          ..write('draftId: $draftId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('durationMs: $durationMs, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('data: $data, ')
          ..write('filePath: $filePath, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('categoryId: $categoryId, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClipCategoriesTable extends ClipCategories
    with TableInfo<$ClipCategoriesTable, ClipCategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    orderIndex,
    createdAt,
    ownerPubkey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clip_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClipCategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClipCategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipCategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      ),
    );
  }

  @override
  $ClipCategoriesTable createAlias(String alias) {
    return $ClipCategoriesTable(attachedDatabase, alias);
  }
}

class ClipCategoryRow extends DataClass implements Insertable<ClipCategoryRow> {
  /// Unique category identifier.
  final String id;

  /// User-entered display name. Not localized — it is the user's own text.
  final String name;

  /// Position of this category in the library's chip row (0-based).
  final int orderIndex;

  /// When the category was created.
  final DateTime createdAt;

  /// Hex public key of the account that owns this category.
  /// NULL for categories created before an account was known.
  final String? ownerPubkey;
  const ClipCategoryRow({
    required this.id,
    required this.name,
    required this.orderIndex,
    required this.createdAt,
    this.ownerPubkey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || ownerPubkey != null) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey);
    }
    return map;
  }

  ClipCategoriesCompanion toCompanion(bool nullToAbsent) {
    return ClipCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      orderIndex: Value(orderIndex),
      createdAt: Value(createdAt),
      ownerPubkey: ownerPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerPubkey),
    );
  }

  factory ClipCategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipCategoryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      ownerPubkey: serializer.fromJson<String?>(json['ownerPubkey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'ownerPubkey': serializer.toJson<String?>(ownerPubkey),
    };
  }

  ClipCategoryRow copyWith({
    String? id,
    String? name,
    int? orderIndex,
    DateTime? createdAt,
    Value<String?> ownerPubkey = const Value.absent(),
  }) => ClipCategoryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    createdAt: createdAt ?? this.createdAt,
    ownerPubkey: ownerPubkey.present ? ownerPubkey.value : this.ownerPubkey,
  );
  ClipCategoryRow copyWithCompanion(ClipCategoriesCompanion data) {
    return ClipCategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipCategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('ownerPubkey: $ownerPubkey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, orderIndex, createdAt, ownerPubkey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipCategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex &&
          other.createdAt == this.createdAt &&
          other.ownerPubkey == this.ownerPubkey);
}

class ClipCategoriesCompanion extends UpdateCompanion<ClipCategoryRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<DateTime> createdAt;
  final Value<String?> ownerPubkey;
  final Value<int> rowid;
  const ClipCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClipCategoriesCompanion.insert({
    required String id,
    required String name,
    this.orderIndex = const Value.absent(),
    required DateTime createdAt,
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ClipCategoryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<DateTime>? createdAt,
    Expression<String>? ownerPubkey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClipCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<DateTime>? createdAt,
    Value<String?>? ownerPubkey,
    Value<int>? rowid,
  }) {
    return ClipCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DirectMessagesTable extends DirectMessages
    with TableInfo<$DirectMessagesTable, DirectMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DirectMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderPubkeyMeta = const VerificationMeta(
    'senderPubkey',
  );
  @override
  late final GeneratedColumn<String> senderPubkey = GeneratedColumn<String>(
    'sender_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _giftWrapIdMeta = const VerificationMeta(
    'giftWrapId',
  );
  @override
  late final GeneratedColumn<String> giftWrapId = GeneratedColumn<String>(
    'gift_wrap_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageKindMeta = const VerificationMeta(
    'messageKind',
  );
  @override
  late final GeneratedColumn<int> messageKind = GeneratedColumn<int>(
    'message_kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(14),
  );
  static const VerificationMeta _fileTypeMeta = const VerificationMeta(
    'fileType',
  );
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
    'file_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptionAlgorithmMeta =
      const VerificationMeta('encryptionAlgorithm');
  @override
  late final GeneratedColumn<String> encryptionAlgorithm =
      GeneratedColumn<String>(
        'encryption_algorithm',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _decryptionKeyMeta = const VerificationMeta(
    'decryptionKey',
  );
  @override
  late final GeneratedColumn<String> decryptionKey = GeneratedColumn<String>(
    'decryption_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _decryptionNonceMeta = const VerificationMeta(
    'decryptionNonce',
  );
  @override
  late final GeneratedColumn<String> decryptionNonce = GeneratedColumn<String>(
    'decryption_nonce',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalFileHashMeta = const VerificationMeta(
    'originalFileHash',
  );
  @override
  late final GeneratedColumn<String> originalFileHash = GeneratedColumn<String>(
    'original_file_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dimensionsMeta = const VerificationMeta(
    'dimensions',
  );
  @override
  late final GeneratedColumn<String> dimensions = GeneratedColumn<String>(
    'dimensions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blurhashMeta = const VerificationMeta(
    'blurhash',
  );
  @override
  late final GeneratedColumn<String> blurhash = GeneratedColumn<String>(
    'blurhash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _twinCollapsedMeta = const VerificationMeta(
    'twinCollapsed',
  );
  @override
  late final GeneratedColumn<bool> twinCollapsed = GeneratedColumn<bool>(
    'twin_collapsed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("twin_collapsed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sendBatchIdMeta = const VerificationMeta(
    'sendBatchId',
  );
  @override
  late final GeneratedColumn<String> sendBatchId = GeneratedColumn<String>(
    'send_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletionRumorJsonMeta = const VerificationMeta(
    'deletionRumorJson',
  );
  @override
  late final GeneratedColumn<String> deletionRumorJson =
      GeneratedColumn<String>(
        'deletion_rumor_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletionPublishStatusMeta =
      const VerificationMeta('deletionPublishStatus');
  @override
  late final GeneratedColumn<String> deletionPublishStatus =
      GeneratedColumn<String>(
        'deletion_publish_status',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    senderPubkey,
    content,
    createdAt,
    replyToId,
    giftWrapId,
    subject,
    tagsJson,
    messageKind,
    fileType,
    encryptionAlgorithm,
    decryptionKey,
    decryptionNonce,
    fileHash,
    originalFileHash,
    fileSize,
    dimensions,
    blurhash,
    thumbnailUrl,
    isDeleted,
    twinCollapsed,
    ownerPubkey,
    sendBatchId,
    deletionRumorJson,
    deletionPublishStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'direct_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<DirectMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_pubkey')) {
      context.handle(
        _senderPubkeyMeta,
        senderPubkey.isAcceptableOrUnknown(
          data['sender_pubkey']!,
          _senderPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderPubkeyMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('gift_wrap_id')) {
      context.handle(
        _giftWrapIdMeta,
        giftWrapId.isAcceptableOrUnknown(
          data['gift_wrap_id']!,
          _giftWrapIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_giftWrapIdMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('message_kind')) {
      context.handle(
        _messageKindMeta,
        messageKind.isAcceptableOrUnknown(
          data['message_kind']!,
          _messageKindMeta,
        ),
      );
    }
    if (data.containsKey('file_type')) {
      context.handle(
        _fileTypeMeta,
        fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta),
      );
    }
    if (data.containsKey('encryption_algorithm')) {
      context.handle(
        _encryptionAlgorithmMeta,
        encryptionAlgorithm.isAcceptableOrUnknown(
          data['encryption_algorithm']!,
          _encryptionAlgorithmMeta,
        ),
      );
    }
    if (data.containsKey('decryption_key')) {
      context.handle(
        _decryptionKeyMeta,
        decryptionKey.isAcceptableOrUnknown(
          data['decryption_key']!,
          _decryptionKeyMeta,
        ),
      );
    }
    if (data.containsKey('decryption_nonce')) {
      context.handle(
        _decryptionNonceMeta,
        decryptionNonce.isAcceptableOrUnknown(
          data['decryption_nonce']!,
          _decryptionNonceMeta,
        ),
      );
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    }
    if (data.containsKey('original_file_hash')) {
      context.handle(
        _originalFileHashMeta,
        originalFileHash.isAcceptableOrUnknown(
          data['original_file_hash']!,
          _originalFileHashMeta,
        ),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('dimensions')) {
      context.handle(
        _dimensionsMeta,
        dimensions.isAcceptableOrUnknown(data['dimensions']!, _dimensionsMeta),
      );
    }
    if (data.containsKey('blurhash')) {
      context.handle(
        _blurhashMeta,
        blurhash.isAcceptableOrUnknown(data['blurhash']!, _blurhashMeta),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('twin_collapsed')) {
      context.handle(
        _twinCollapsedMeta,
        twinCollapsed.isAcceptableOrUnknown(
          data['twin_collapsed']!,
          _twinCollapsedMeta,
        ),
      );
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    }
    if (data.containsKey('send_batch_id')) {
      context.handle(
        _sendBatchIdMeta,
        sendBatchId.isAcceptableOrUnknown(
          data['send_batch_id']!,
          _sendBatchIdMeta,
        ),
      );
    }
    if (data.containsKey('deletion_rumor_json')) {
      context.handle(
        _deletionRumorJsonMeta,
        deletionRumorJson.isAcceptableOrUnknown(
          data['deletion_rumor_json']!,
          _deletionRumorJsonMeta,
        ),
      );
    }
    if (data.containsKey('deletion_publish_status')) {
      context.handle(
        _deletionPublishStatusMeta,
        deletionPublishStatus.isAcceptableOrUnknown(
          data['deletion_publish_status']!,
          _deletionPublishStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, ownerPubkey};
  @override
  DirectMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DirectMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_pubkey'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      giftWrapId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gift_wrap_id'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      ),
      messageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_kind'],
      )!,
      fileType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_type'],
      ),
      encryptionAlgorithm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encryption_algorithm'],
      ),
      decryptionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decryption_key'],
      ),
      decryptionNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decryption_nonce'],
      ),
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      ),
      originalFileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_file_hash'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      dimensions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dimensions'],
      ),
      blurhash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blurhash'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      twinCollapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}twin_collapsed'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      )!,
      sendBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}send_batch_id'],
      ),
      deletionRumorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deletion_rumor_json'],
      ),
      deletionPublishStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deletion_publish_status'],
      ),
    );
  }

  @override
  $DirectMessagesTable createAlias(String alias) {
    return $DirectMessagesTable(attachedDatabase, alias);
  }
}

class DirectMessageRow extends DataClass
    implements Insertable<DirectMessageRow> {
  /// The rumor event ID (kind 14/15 id field).
  final String id;

  /// Deterministic conversation identifier (SHA-256 of sorted participant
  /// pubkeys). Shared by all messages in the same chat room.
  final String conversationId;

  /// Public key of the message sender.
  final String senderPubkey;

  /// For kind 14: decrypted plaintext content.
  /// For kind 15: the encrypted file URL.
  final String content;

  /// Unix timestamp from the rumor event's created_at.
  final int createdAt;

  /// Optional parent message ID (from `e` tag) for threaded replies.
  final String? replyToId;

  /// The gift-wrap event ID (kind 1059) used for deduplication.
  final String giftWrapId;

  /// Optional conversation subject/title (from `subject` tag).
  final String? subject;

  /// JSON-encoded tags from the decrypted NIP-17 rumor event.
  final String? tagsJson;

  /// The inner event kind: 14 (text) or 15 (file). Defaults to 14.
  final int messageKind;

  /// MIME type of the file before encryption (e.g. `image/jpeg`).
  final String? fileType;

  /// Encryption algorithm (e.g. `aes-gcm`).
  final String? encryptionAlgorithm;

  /// Hex-encoded AES key for file decryption.
  final String? decryptionKey;

  /// Hex-encoded nonce/IV for file decryption.
  final String? decryptionNonce;

  /// SHA-256 hex hash of the encrypted file.
  final String? fileHash;

  /// SHA-256 hex hash of the original file before encryption.
  final String? originalFileHash;

  /// Size of the encrypted file in bytes.
  final int? fileSize;

  /// Dimensions in `<width>x<height>` format.
  final String? dimensions;

  /// BlurHash string for image preview.
  final String? blurhash;

  /// URL of an encrypted thumbnail (same key/nonce).
  final String? thumbnailUrl;

  /// Whether this message has been soft-deleted via a NIP-09 kind 5 event.
  ///
  /// Soft-deleting (rather than hard-deleting) preserves the `giftWrapId` so
  /// the dedup check (`hasGiftWrap`) continues to reject the relay
  /// re-delivering the gift-wrapped event on the next poll cycle.
  final bool isDeleted;

  /// Whether this row has already absorbed its cross-protocol twin.
  ///
  /// A dual-send puts one message on the wire twice — a NIP-17 rumor and a
  /// NIP-04 event with unrelated ids — so nothing but the
  /// `(sender, content, ~time)` window can collapse them. That window matched
  /// on *existence*, so one stored copy absorbed every later same-text arrival
  /// inside it, and a peer's genuine repeat was lost in the NIP-04-first
  /// ordering — the very symptom #7324 was filed for, surviving in the other
  /// direction (#8211).
  ///
  /// A twin is 1:1: one message on the wire twice yields exactly one
  /// counterpart, so a row may absorb exactly one. This marks the row that
  /// already did. Self-send matching does not use it — any number of echoes
  /// may legitimately match the user's own persisted send.
  final bool twinCollapsed;

  /// Hex public key of the account that received/sent this message.
  ///
  /// Part of the primary key. A NIP-17 group send seals ONE rumor for every
  /// recipient, so two local accounts in the same room receive distinct gift
  /// wraps carrying an identical rumor id, and each must be able to hold its
  /// own row (#6645).
  ///
  /// NOT NULL with an empty-string default rather than nullable, because
  /// SQLite compares NULLs as *distinct* inside a unique constraint: a
  /// nullable owner in the key would stop two legacy rows that share a rumor
  /// id from collapsing, silently weakening the dedup this table relies on.
  /// `''` is already this schema's legacy sentinel — `clearForAccountSwitch`
  /// and `clearUnowned` have always treated `NULL` and `''` alike. Rows
  /// written before multi-account support are backfilled to `''` by the v12
  /// migration.
  final String ownerPubkey;

  /// Durable, collision-proof identity of one send invocation. Set on the
  /// sender's local message for 1:1 sends and shared by the single local
  /// message representing a group fan-out. A self-wrap received on another
  /// device preserves it; peer-authored and legacy messages leave it NULL. It
  /// gives same-second 1:1 sends distinct rumor ids and lets group recovery and
  /// optimistic UI grouping match a fan-out by an exact value instead of the
  /// collision-prone `(sender, content, created_at ±5s)` tuple.
  final String? sendBatchId;

  /// Serialized kind-5 rumor for an own delete-for-everyone that is awaiting
  /// confirmed delivery or was blocked. Null for every other row.
  ///
  /// Stored rather than rebuilt so every retry replays a byte-identical rumor
  /// id, keeping one retraction one kind-5 however many attempts it takes.
  /// Receive-side dedup does not collapse the repeats — it is keyed on
  /// gift-wrap id and NIP-59 gives every wrap a fresh ephemeral key — so what
  /// makes them harmless is that re-applying a deletion is a no-op. Mirrors
  /// `DmReactions.rumorEventJson`, which serves the same purpose for a
  /// reaction removal.
  final String? deletionRumorJson;

  /// Delivery state of the kind-5 in [deletionRumorJson]; null when the row
  /// carries no own deletion. Values: `deletion_pending` (soft-deleted
  /// locally, wrap awaiting a confirmed relay `OK`), `deletion_sent`
  /// (confirmed, terminal), `deletion_blocked` (send policy blocked every
  /// failed recipient, terminal; other recipients may have succeeded).
  ///
  /// Reaction removals likewise record a distinct `deletion_refused` status
  /// in their publish-status column. A block describes the current attempt,
  /// not whether the original message or reaction was previously delivered.
  /// Both distinct values stop automatic retries without asserting delivery.
  final String? deletionPublishStatus;
  const DirectMessageRow({
    required this.id,
    required this.conversationId,
    required this.senderPubkey,
    required this.content,
    required this.createdAt,
    this.replyToId,
    required this.giftWrapId,
    this.subject,
    this.tagsJson,
    required this.messageKind,
    this.fileType,
    this.encryptionAlgorithm,
    this.decryptionKey,
    this.decryptionNonce,
    this.fileHash,
    this.originalFileHash,
    this.fileSize,
    this.dimensions,
    this.blurhash,
    this.thumbnailUrl,
    required this.isDeleted,
    required this.twinCollapsed,
    required this.ownerPubkey,
    this.sendBatchId,
    this.deletionRumorJson,
    this.deletionPublishStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_pubkey'] = Variable<String>(senderPubkey);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    map['gift_wrap_id'] = Variable<String>(giftWrapId);
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || tagsJson != null) {
      map['tags_json'] = Variable<String>(tagsJson);
    }
    map['message_kind'] = Variable<int>(messageKind);
    if (!nullToAbsent || fileType != null) {
      map['file_type'] = Variable<String>(fileType);
    }
    if (!nullToAbsent || encryptionAlgorithm != null) {
      map['encryption_algorithm'] = Variable<String>(encryptionAlgorithm);
    }
    if (!nullToAbsent || decryptionKey != null) {
      map['decryption_key'] = Variable<String>(decryptionKey);
    }
    if (!nullToAbsent || decryptionNonce != null) {
      map['decryption_nonce'] = Variable<String>(decryptionNonce);
    }
    if (!nullToAbsent || fileHash != null) {
      map['file_hash'] = Variable<String>(fileHash);
    }
    if (!nullToAbsent || originalFileHash != null) {
      map['original_file_hash'] = Variable<String>(originalFileHash);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || dimensions != null) {
      map['dimensions'] = Variable<String>(dimensions);
    }
    if (!nullToAbsent || blurhash != null) {
      map['blurhash'] = Variable<String>(blurhash);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['twin_collapsed'] = Variable<bool>(twinCollapsed);
    map['owner_pubkey'] = Variable<String>(ownerPubkey);
    if (!nullToAbsent || sendBatchId != null) {
      map['send_batch_id'] = Variable<String>(sendBatchId);
    }
    if (!nullToAbsent || deletionRumorJson != null) {
      map['deletion_rumor_json'] = Variable<String>(deletionRumorJson);
    }
    if (!nullToAbsent || deletionPublishStatus != null) {
      map['deletion_publish_status'] = Variable<String>(deletionPublishStatus);
    }
    return map;
  }

  DirectMessagesCompanion toCompanion(bool nullToAbsent) {
    return DirectMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderPubkey: Value(senderPubkey),
      content: Value(content),
      createdAt: Value(createdAt),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      giftWrapId: Value(giftWrapId),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      tagsJson: tagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsJson),
      messageKind: Value(messageKind),
      fileType: fileType == null && nullToAbsent
          ? const Value.absent()
          : Value(fileType),
      encryptionAlgorithm: encryptionAlgorithm == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionAlgorithm),
      decryptionKey: decryptionKey == null && nullToAbsent
          ? const Value.absent()
          : Value(decryptionKey),
      decryptionNonce: decryptionNonce == null && nullToAbsent
          ? const Value.absent()
          : Value(decryptionNonce),
      fileHash: fileHash == null && nullToAbsent
          ? const Value.absent()
          : Value(fileHash),
      originalFileHash: originalFileHash == null && nullToAbsent
          ? const Value.absent()
          : Value(originalFileHash),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      dimensions: dimensions == null && nullToAbsent
          ? const Value.absent()
          : Value(dimensions),
      blurhash: blurhash == null && nullToAbsent
          ? const Value.absent()
          : Value(blurhash),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      isDeleted: Value(isDeleted),
      twinCollapsed: Value(twinCollapsed),
      ownerPubkey: Value(ownerPubkey),
      sendBatchId: sendBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(sendBatchId),
      deletionRumorJson: deletionRumorJson == null && nullToAbsent
          ? const Value.absent()
          : Value(deletionRumorJson),
      deletionPublishStatus: deletionPublishStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(deletionPublishStatus),
    );
  }

  factory DirectMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DirectMessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderPubkey: serializer.fromJson<String>(json['senderPubkey']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      giftWrapId: serializer.fromJson<String>(json['giftWrapId']),
      subject: serializer.fromJson<String?>(json['subject']),
      tagsJson: serializer.fromJson<String?>(json['tagsJson']),
      messageKind: serializer.fromJson<int>(json['messageKind']),
      fileType: serializer.fromJson<String?>(json['fileType']),
      encryptionAlgorithm: serializer.fromJson<String?>(
        json['encryptionAlgorithm'],
      ),
      decryptionKey: serializer.fromJson<String?>(json['decryptionKey']),
      decryptionNonce: serializer.fromJson<String?>(json['decryptionNonce']),
      fileHash: serializer.fromJson<String?>(json['fileHash']),
      originalFileHash: serializer.fromJson<String?>(json['originalFileHash']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      dimensions: serializer.fromJson<String?>(json['dimensions']),
      blurhash: serializer.fromJson<String?>(json['blurhash']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      twinCollapsed: serializer.fromJson<bool>(json['twinCollapsed']),
      ownerPubkey: serializer.fromJson<String>(json['ownerPubkey']),
      sendBatchId: serializer.fromJson<String?>(json['sendBatchId']),
      deletionRumorJson: serializer.fromJson<String?>(
        json['deletionRumorJson'],
      ),
      deletionPublishStatus: serializer.fromJson<String?>(
        json['deletionPublishStatus'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderPubkey': serializer.toJson<String>(senderPubkey),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<int>(createdAt),
      'replyToId': serializer.toJson<String?>(replyToId),
      'giftWrapId': serializer.toJson<String>(giftWrapId),
      'subject': serializer.toJson<String?>(subject),
      'tagsJson': serializer.toJson<String?>(tagsJson),
      'messageKind': serializer.toJson<int>(messageKind),
      'fileType': serializer.toJson<String?>(fileType),
      'encryptionAlgorithm': serializer.toJson<String?>(encryptionAlgorithm),
      'decryptionKey': serializer.toJson<String?>(decryptionKey),
      'decryptionNonce': serializer.toJson<String?>(decryptionNonce),
      'fileHash': serializer.toJson<String?>(fileHash),
      'originalFileHash': serializer.toJson<String?>(originalFileHash),
      'fileSize': serializer.toJson<int?>(fileSize),
      'dimensions': serializer.toJson<String?>(dimensions),
      'blurhash': serializer.toJson<String?>(blurhash),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'twinCollapsed': serializer.toJson<bool>(twinCollapsed),
      'ownerPubkey': serializer.toJson<String>(ownerPubkey),
      'sendBatchId': serializer.toJson<String?>(sendBatchId),
      'deletionRumorJson': serializer.toJson<String?>(deletionRumorJson),
      'deletionPublishStatus': serializer.toJson<String?>(
        deletionPublishStatus,
      ),
    };
  }

  DirectMessageRow copyWith({
    String? id,
    String? conversationId,
    String? senderPubkey,
    String? content,
    int? createdAt,
    Value<String?> replyToId = const Value.absent(),
    String? giftWrapId,
    Value<String?> subject = const Value.absent(),
    Value<String?> tagsJson = const Value.absent(),
    int? messageKind,
    Value<String?> fileType = const Value.absent(),
    Value<String?> encryptionAlgorithm = const Value.absent(),
    Value<String?> decryptionKey = const Value.absent(),
    Value<String?> decryptionNonce = const Value.absent(),
    Value<String?> fileHash = const Value.absent(),
    Value<String?> originalFileHash = const Value.absent(),
    Value<int?> fileSize = const Value.absent(),
    Value<String?> dimensions = const Value.absent(),
    Value<String?> blurhash = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    bool? isDeleted,
    bool? twinCollapsed,
    String? ownerPubkey,
    Value<String?> sendBatchId = const Value.absent(),
    Value<String?> deletionRumorJson = const Value.absent(),
    Value<String?> deletionPublishStatus = const Value.absent(),
  }) => DirectMessageRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderPubkey: senderPubkey ?? this.senderPubkey,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    giftWrapId: giftWrapId ?? this.giftWrapId,
    subject: subject.present ? subject.value : this.subject,
    tagsJson: tagsJson.present ? tagsJson.value : this.tagsJson,
    messageKind: messageKind ?? this.messageKind,
    fileType: fileType.present ? fileType.value : this.fileType,
    encryptionAlgorithm: encryptionAlgorithm.present
        ? encryptionAlgorithm.value
        : this.encryptionAlgorithm,
    decryptionKey: decryptionKey.present
        ? decryptionKey.value
        : this.decryptionKey,
    decryptionNonce: decryptionNonce.present
        ? decryptionNonce.value
        : this.decryptionNonce,
    fileHash: fileHash.present ? fileHash.value : this.fileHash,
    originalFileHash: originalFileHash.present
        ? originalFileHash.value
        : this.originalFileHash,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    dimensions: dimensions.present ? dimensions.value : this.dimensions,
    blurhash: blurhash.present ? blurhash.value : this.blurhash,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    isDeleted: isDeleted ?? this.isDeleted,
    twinCollapsed: twinCollapsed ?? this.twinCollapsed,
    ownerPubkey: ownerPubkey ?? this.ownerPubkey,
    sendBatchId: sendBatchId.present ? sendBatchId.value : this.sendBatchId,
    deletionRumorJson: deletionRumorJson.present
        ? deletionRumorJson.value
        : this.deletionRumorJson,
    deletionPublishStatus: deletionPublishStatus.present
        ? deletionPublishStatus.value
        : this.deletionPublishStatus,
  );
  DirectMessageRow copyWithCompanion(DirectMessagesCompanion data) {
    return DirectMessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderPubkey: data.senderPubkey.present
          ? data.senderPubkey.value
          : this.senderPubkey,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      giftWrapId: data.giftWrapId.present
          ? data.giftWrapId.value
          : this.giftWrapId,
      subject: data.subject.present ? data.subject.value : this.subject,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      messageKind: data.messageKind.present
          ? data.messageKind.value
          : this.messageKind,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      encryptionAlgorithm: data.encryptionAlgorithm.present
          ? data.encryptionAlgorithm.value
          : this.encryptionAlgorithm,
      decryptionKey: data.decryptionKey.present
          ? data.decryptionKey.value
          : this.decryptionKey,
      decryptionNonce: data.decryptionNonce.present
          ? data.decryptionNonce.value
          : this.decryptionNonce,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      originalFileHash: data.originalFileHash.present
          ? data.originalFileHash.value
          : this.originalFileHash,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      dimensions: data.dimensions.present
          ? data.dimensions.value
          : this.dimensions,
      blurhash: data.blurhash.present ? data.blurhash.value : this.blurhash,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      twinCollapsed: data.twinCollapsed.present
          ? data.twinCollapsed.value
          : this.twinCollapsed,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
      sendBatchId: data.sendBatchId.present
          ? data.sendBatchId.value
          : this.sendBatchId,
      deletionRumorJson: data.deletionRumorJson.present
          ? data.deletionRumorJson.value
          : this.deletionRumorJson,
      deletionPublishStatus: data.deletionPublishStatus.present
          ? data.deletionPublishStatus.value
          : this.deletionPublishStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DirectMessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderPubkey: $senderPubkey, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('replyToId: $replyToId, ')
          ..write('giftWrapId: $giftWrapId, ')
          ..write('subject: $subject, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('messageKind: $messageKind, ')
          ..write('fileType: $fileType, ')
          ..write('encryptionAlgorithm: $encryptionAlgorithm, ')
          ..write('decryptionKey: $decryptionKey, ')
          ..write('decryptionNonce: $decryptionNonce, ')
          ..write('fileHash: $fileHash, ')
          ..write('originalFileHash: $originalFileHash, ')
          ..write('fileSize: $fileSize, ')
          ..write('dimensions: $dimensions, ')
          ..write('blurhash: $blurhash, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('twinCollapsed: $twinCollapsed, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('sendBatchId: $sendBatchId, ')
          ..write('deletionRumorJson: $deletionRumorJson, ')
          ..write('deletionPublishStatus: $deletionPublishStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    conversationId,
    senderPubkey,
    content,
    createdAt,
    replyToId,
    giftWrapId,
    subject,
    tagsJson,
    messageKind,
    fileType,
    encryptionAlgorithm,
    decryptionKey,
    decryptionNonce,
    fileHash,
    originalFileHash,
    fileSize,
    dimensions,
    blurhash,
    thumbnailUrl,
    isDeleted,
    twinCollapsed,
    ownerPubkey,
    sendBatchId,
    deletionRumorJson,
    deletionPublishStatus,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DirectMessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderPubkey == this.senderPubkey &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.replyToId == this.replyToId &&
          other.giftWrapId == this.giftWrapId &&
          other.subject == this.subject &&
          other.tagsJson == this.tagsJson &&
          other.messageKind == this.messageKind &&
          other.fileType == this.fileType &&
          other.encryptionAlgorithm == this.encryptionAlgorithm &&
          other.decryptionKey == this.decryptionKey &&
          other.decryptionNonce == this.decryptionNonce &&
          other.fileHash == this.fileHash &&
          other.originalFileHash == this.originalFileHash &&
          other.fileSize == this.fileSize &&
          other.dimensions == this.dimensions &&
          other.blurhash == this.blurhash &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.isDeleted == this.isDeleted &&
          other.twinCollapsed == this.twinCollapsed &&
          other.ownerPubkey == this.ownerPubkey &&
          other.sendBatchId == this.sendBatchId &&
          other.deletionRumorJson == this.deletionRumorJson &&
          other.deletionPublishStatus == this.deletionPublishStatus);
}

class DirectMessagesCompanion extends UpdateCompanion<DirectMessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderPubkey;
  final Value<String> content;
  final Value<int> createdAt;
  final Value<String?> replyToId;
  final Value<String> giftWrapId;
  final Value<String?> subject;
  final Value<String?> tagsJson;
  final Value<int> messageKind;
  final Value<String?> fileType;
  final Value<String?> encryptionAlgorithm;
  final Value<String?> decryptionKey;
  final Value<String?> decryptionNonce;
  final Value<String?> fileHash;
  final Value<String?> originalFileHash;
  final Value<int?> fileSize;
  final Value<String?> dimensions;
  final Value<String?> blurhash;
  final Value<String?> thumbnailUrl;
  final Value<bool> isDeleted;
  final Value<bool> twinCollapsed;
  final Value<String> ownerPubkey;
  final Value<String?> sendBatchId;
  final Value<String?> deletionRumorJson;
  final Value<String?> deletionPublishStatus;
  final Value<int> rowid;
  const DirectMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderPubkey = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.giftWrapId = const Value.absent(),
    this.subject = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.messageKind = const Value.absent(),
    this.fileType = const Value.absent(),
    this.encryptionAlgorithm = const Value.absent(),
    this.decryptionKey = const Value.absent(),
    this.decryptionNonce = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.originalFileHash = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.blurhash = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.twinCollapsed = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.sendBatchId = const Value.absent(),
    this.deletionRumorJson = const Value.absent(),
    this.deletionPublishStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DirectMessagesCompanion.insert({
    required String id,
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    this.replyToId = const Value.absent(),
    required String giftWrapId,
    this.subject = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.messageKind = const Value.absent(),
    this.fileType = const Value.absent(),
    this.encryptionAlgorithm = const Value.absent(),
    this.decryptionKey = const Value.absent(),
    this.decryptionNonce = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.originalFileHash = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.blurhash = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.twinCollapsed = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.sendBatchId = const Value.absent(),
    this.deletionRumorJson = const Value.absent(),
    this.deletionPublishStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       senderPubkey = Value(senderPubkey),
       content = Value(content),
       createdAt = Value(createdAt),
       giftWrapId = Value(giftWrapId);
  static Insertable<DirectMessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderPubkey,
    Expression<String>? content,
    Expression<int>? createdAt,
    Expression<String>? replyToId,
    Expression<String>? giftWrapId,
    Expression<String>? subject,
    Expression<String>? tagsJson,
    Expression<int>? messageKind,
    Expression<String>? fileType,
    Expression<String>? encryptionAlgorithm,
    Expression<String>? decryptionKey,
    Expression<String>? decryptionNonce,
    Expression<String>? fileHash,
    Expression<String>? originalFileHash,
    Expression<int>? fileSize,
    Expression<String>? dimensions,
    Expression<String>? blurhash,
    Expression<String>? thumbnailUrl,
    Expression<bool>? isDeleted,
    Expression<bool>? twinCollapsed,
    Expression<String>? ownerPubkey,
    Expression<String>? sendBatchId,
    Expression<String>? deletionRumorJson,
    Expression<String>? deletionPublishStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderPubkey != null) 'sender_pubkey': senderPubkey,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (giftWrapId != null) 'gift_wrap_id': giftWrapId,
      if (subject != null) 'subject': subject,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (messageKind != null) 'message_kind': messageKind,
      if (fileType != null) 'file_type': fileType,
      if (encryptionAlgorithm != null)
        'encryption_algorithm': encryptionAlgorithm,
      if (decryptionKey != null) 'decryption_key': decryptionKey,
      if (decryptionNonce != null) 'decryption_nonce': decryptionNonce,
      if (fileHash != null) 'file_hash': fileHash,
      if (originalFileHash != null) 'original_file_hash': originalFileHash,
      if (fileSize != null) 'file_size': fileSize,
      if (dimensions != null) 'dimensions': dimensions,
      if (blurhash != null) 'blurhash': blurhash,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (twinCollapsed != null) 'twin_collapsed': twinCollapsed,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (sendBatchId != null) 'send_batch_id': sendBatchId,
      if (deletionRumorJson != null) 'deletion_rumor_json': deletionRumorJson,
      if (deletionPublishStatus != null)
        'deletion_publish_status': deletionPublishStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DirectMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? senderPubkey,
    Value<String>? content,
    Value<int>? createdAt,
    Value<String?>? replyToId,
    Value<String>? giftWrapId,
    Value<String?>? subject,
    Value<String?>? tagsJson,
    Value<int>? messageKind,
    Value<String?>? fileType,
    Value<String?>? encryptionAlgorithm,
    Value<String?>? decryptionKey,
    Value<String?>? decryptionNonce,
    Value<String?>? fileHash,
    Value<String?>? originalFileHash,
    Value<int?>? fileSize,
    Value<String?>? dimensions,
    Value<String?>? blurhash,
    Value<String?>? thumbnailUrl,
    Value<bool>? isDeleted,
    Value<bool>? twinCollapsed,
    Value<String>? ownerPubkey,
    Value<String?>? sendBatchId,
    Value<String?>? deletionRumorJson,
    Value<String?>? deletionPublishStatus,
    Value<int>? rowid,
  }) {
    return DirectMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderPubkey: senderPubkey ?? this.senderPubkey,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      replyToId: replyToId ?? this.replyToId,
      giftWrapId: giftWrapId ?? this.giftWrapId,
      subject: subject ?? this.subject,
      tagsJson: tagsJson ?? this.tagsJson,
      messageKind: messageKind ?? this.messageKind,
      fileType: fileType ?? this.fileType,
      encryptionAlgorithm: encryptionAlgorithm ?? this.encryptionAlgorithm,
      decryptionKey: decryptionKey ?? this.decryptionKey,
      decryptionNonce: decryptionNonce ?? this.decryptionNonce,
      fileHash: fileHash ?? this.fileHash,
      originalFileHash: originalFileHash ?? this.originalFileHash,
      fileSize: fileSize ?? this.fileSize,
      dimensions: dimensions ?? this.dimensions,
      blurhash: blurhash ?? this.blurhash,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isDeleted: isDeleted ?? this.isDeleted,
      twinCollapsed: twinCollapsed ?? this.twinCollapsed,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      sendBatchId: sendBatchId ?? this.sendBatchId,
      deletionRumorJson: deletionRumorJson ?? this.deletionRumorJson,
      deletionPublishStatus:
          deletionPublishStatus ?? this.deletionPublishStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderPubkey.present) {
      map['sender_pubkey'] = Variable<String>(senderPubkey.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (giftWrapId.present) {
      map['gift_wrap_id'] = Variable<String>(giftWrapId.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (messageKind.present) {
      map['message_kind'] = Variable<int>(messageKind.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (encryptionAlgorithm.present) {
      map['encryption_algorithm'] = Variable<String>(encryptionAlgorithm.value);
    }
    if (decryptionKey.present) {
      map['decryption_key'] = Variable<String>(decryptionKey.value);
    }
    if (decryptionNonce.present) {
      map['decryption_nonce'] = Variable<String>(decryptionNonce.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (originalFileHash.present) {
      map['original_file_hash'] = Variable<String>(originalFileHash.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (dimensions.present) {
      map['dimensions'] = Variable<String>(dimensions.value);
    }
    if (blurhash.present) {
      map['blurhash'] = Variable<String>(blurhash.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (twinCollapsed.present) {
      map['twin_collapsed'] = Variable<bool>(twinCollapsed.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (sendBatchId.present) {
      map['send_batch_id'] = Variable<String>(sendBatchId.value);
    }
    if (deletionRumorJson.present) {
      map['deletion_rumor_json'] = Variable<String>(deletionRumorJson.value);
    }
    if (deletionPublishStatus.present) {
      map['deletion_publish_status'] = Variable<String>(
        deletionPublishStatus.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DirectMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderPubkey: $senderPubkey, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('replyToId: $replyToId, ')
          ..write('giftWrapId: $giftWrapId, ')
          ..write('subject: $subject, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('messageKind: $messageKind, ')
          ..write('fileType: $fileType, ')
          ..write('encryptionAlgorithm: $encryptionAlgorithm, ')
          ..write('decryptionKey: $decryptionKey, ')
          ..write('decryptionNonce: $decryptionNonce, ')
          ..write('fileHash: $fileHash, ')
          ..write('originalFileHash: $originalFileHash, ')
          ..write('fileSize: $fileSize, ')
          ..write('dimensions: $dimensions, ')
          ..write('blurhash: $blurhash, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('twinCollapsed: $twinCollapsed, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('sendBatchId: $sendBatchId, ')
          ..write('deletionRumorJson: $deletionRumorJson, ')
          ..write('deletionPublishStatus: $deletionPublishStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DmMessageReactionsTable extends DmMessageReactions
    with TableInfo<$DmMessageReactionsTable, DmReactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DmMessageReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMessageIdMeta = const VerificationMeta(
    'targetMessageId',
  );
  @override
  late final GeneratedColumn<String> targetMessageId = GeneratedColumn<String>(
    'target_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMessageAuthorMeta =
      const VerificationMeta('targetMessageAuthor');
  @override
  late final GeneratedColumn<String> targetMessageAuthor =
      GeneratedColumn<String>(
        'target_message_author',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _reactorPubkeyMeta = const VerificationMeta(
    'reactorPubkey',
  );
  @override
  late final GeneratedColumn<String> reactorPubkey = GeneratedColumn<String>(
    'reactor_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _giftWrapIdMeta = const VerificationMeta(
    'giftWrapId',
  );
  @override
  late final GeneratedColumn<String> giftWrapId = GeneratedColumn<String>(
    'gift_wrap_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rumorEventJsonMeta = const VerificationMeta(
    'rumorEventJson',
  );
  @override
  late final GeneratedColumn<String> rumorEventJson = GeneratedColumn<String>(
    'rumor_event_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishStatusMeta = const VerificationMeta(
    'publishStatus',
  );
  @override
  late final GeneratedColumn<String> publishStatus = GeneratedColumn<String>(
    'publish_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    targetMessageId,
    targetMessageAuthor,
    reactorPubkey,
    emoji,
    createdAt,
    giftWrapId,
    ownerPubkey,
    isDeleted,
    rumorEventJson,
    publishStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dm_message_reactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DmReactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('target_message_id')) {
      context.handle(
        _targetMessageIdMeta,
        targetMessageId.isAcceptableOrUnknown(
          data['target_message_id']!,
          _targetMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetMessageIdMeta);
    }
    if (data.containsKey('target_message_author')) {
      context.handle(
        _targetMessageAuthorMeta,
        targetMessageAuthor.isAcceptableOrUnknown(
          data['target_message_author']!,
          _targetMessageAuthorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetMessageAuthorMeta);
    }
    if (data.containsKey('reactor_pubkey')) {
      context.handle(
        _reactorPubkeyMeta,
        reactorPubkey.isAcceptableOrUnknown(
          data['reactor_pubkey']!,
          _reactorPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reactorPubkeyMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('gift_wrap_id')) {
      context.handle(
        _giftWrapIdMeta,
        giftWrapId.isAcceptableOrUnknown(
          data['gift_wrap_id']!,
          _giftWrapIdMeta,
        ),
      );
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerPubkeyMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('rumor_event_json')) {
      context.handle(
        _rumorEventJsonMeta,
        rumorEventJson.isAcceptableOrUnknown(
          data['rumor_event_json']!,
          _rumorEventJsonMeta,
        ),
      );
    }
    if (data.containsKey('publish_status')) {
      context.handle(
        _publishStatusMeta,
        publishStatus.isAcceptableOrUnknown(
          data['publish_status']!,
          _publishStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, ownerPubkey};
  @override
  DmReactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DmReactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      targetMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_message_id'],
      )!,
      targetMessageAuthor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_message_author'],
      )!,
      reactorPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reactor_pubkey'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      giftWrapId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gift_wrap_id'],
      ),
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      rumorEventJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rumor_event_json'],
      ),
      publishStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publish_status'],
      ),
    );
  }

  @override
  $DmMessageReactionsTable createAlias(String alias) {
    return $DmMessageReactionsTable(attachedDatabase, alias);
  }
}

class DmReactionRow extends DataClass implements Insertable<DmReactionRow> {
  /// The reaction rumor event id (kind 7). Stable across recipient + self
  /// wraps. Combined with [ownerPubkey] it forms the dedup key.
  final String id;

  /// Conversation the target message belongs to. Indexed for chip render.
  final String conversationId;

  /// Rumor id of the kind-14/15 message being reacted to.
  final String targetMessageId;

  /// Pubkey of the author of the target message. Carried so future detail
  /// sheets and NIP-25 `p` tag echoes don't need a join.
  final String targetMessageAuthor;

  /// Pubkey of the user who created this reaction.
  final String reactorPubkey;

  /// Reaction content. Almost always an emoji codepoint; per NIP-25 may
  /// also be a NIP-30 `:shortcode:` (rendered as-is at v1, no lookup).
  final String emoji;

  /// Unix timestamp from the rumor's `created_at`.
  final int createdAt;

  /// The first gift-wrap id we observed carrying this reaction. Kept for
  /// dedup-of-incoming and for relay-replay protection. Nullable for
  /// optimistic rows that have not yet been published.
  final String? giftWrapId;

  /// Hex public key of the account viewing this reaction (multi-account
  /// isolation).
  final String ownerPubkey;

  /// Soft-delete marker for NIP-09 kind 5 deletions and for own-reaction
  /// supersede (cap-at-one). Soft delete preserves the audit trail and
  /// blocks stale relay re-delivery from "un-deleting" the row.
  final bool isDeleted;

  /// Serialized rumor JSON for pending rows that may need retry.
  /// Null once successfully published.
  final String? rumorEventJson;

  /// Publish status for outgoing rows; null for incoming (received from
  /// relay). Values: `pending`, `sent`, `failed`, `blocked` (send-policy
  /// refused, terminal), `deletion_pending` (soft-deleted, kind-5 awaiting
  /// durable delivery), `deletion_sent` (kind-5 confirmed, terminal), and
  /// `deletion_refused` (automatic retries stopped, retained for user retry).
  final String? publishStatus;
  const DmReactionRow({
    required this.id,
    required this.conversationId,
    required this.targetMessageId,
    required this.targetMessageAuthor,
    required this.reactorPubkey,
    required this.emoji,
    required this.createdAt,
    this.giftWrapId,
    required this.ownerPubkey,
    required this.isDeleted,
    this.rumorEventJson,
    this.publishStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['target_message_id'] = Variable<String>(targetMessageId);
    map['target_message_author'] = Variable<String>(targetMessageAuthor);
    map['reactor_pubkey'] = Variable<String>(reactorPubkey);
    map['emoji'] = Variable<String>(emoji);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || giftWrapId != null) {
      map['gift_wrap_id'] = Variable<String>(giftWrapId);
    }
    map['owner_pubkey'] = Variable<String>(ownerPubkey);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || rumorEventJson != null) {
      map['rumor_event_json'] = Variable<String>(rumorEventJson);
    }
    if (!nullToAbsent || publishStatus != null) {
      map['publish_status'] = Variable<String>(publishStatus);
    }
    return map;
  }

  DmMessageReactionsCompanion toCompanion(bool nullToAbsent) {
    return DmMessageReactionsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      targetMessageId: Value(targetMessageId),
      targetMessageAuthor: Value(targetMessageAuthor),
      reactorPubkey: Value(reactorPubkey),
      emoji: Value(emoji),
      createdAt: Value(createdAt),
      giftWrapId: giftWrapId == null && nullToAbsent
          ? const Value.absent()
          : Value(giftWrapId),
      ownerPubkey: Value(ownerPubkey),
      isDeleted: Value(isDeleted),
      rumorEventJson: rumorEventJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rumorEventJson),
      publishStatus: publishStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(publishStatus),
    );
  }

  factory DmReactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DmReactionRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      targetMessageId: serializer.fromJson<String>(json['targetMessageId']),
      targetMessageAuthor: serializer.fromJson<String>(
        json['targetMessageAuthor'],
      ),
      reactorPubkey: serializer.fromJson<String>(json['reactorPubkey']),
      emoji: serializer.fromJson<String>(json['emoji']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      giftWrapId: serializer.fromJson<String?>(json['giftWrapId']),
      ownerPubkey: serializer.fromJson<String>(json['ownerPubkey']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      rumorEventJson: serializer.fromJson<String?>(json['rumorEventJson']),
      publishStatus: serializer.fromJson<String?>(json['publishStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'targetMessageId': serializer.toJson<String>(targetMessageId),
      'targetMessageAuthor': serializer.toJson<String>(targetMessageAuthor),
      'reactorPubkey': serializer.toJson<String>(reactorPubkey),
      'emoji': serializer.toJson<String>(emoji),
      'createdAt': serializer.toJson<int>(createdAt),
      'giftWrapId': serializer.toJson<String?>(giftWrapId),
      'ownerPubkey': serializer.toJson<String>(ownerPubkey),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'rumorEventJson': serializer.toJson<String?>(rumorEventJson),
      'publishStatus': serializer.toJson<String?>(publishStatus),
    };
  }

  DmReactionRow copyWith({
    String? id,
    String? conversationId,
    String? targetMessageId,
    String? targetMessageAuthor,
    String? reactorPubkey,
    String? emoji,
    int? createdAt,
    Value<String?> giftWrapId = const Value.absent(),
    String? ownerPubkey,
    bool? isDeleted,
    Value<String?> rumorEventJson = const Value.absent(),
    Value<String?> publishStatus = const Value.absent(),
  }) => DmReactionRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    targetMessageId: targetMessageId ?? this.targetMessageId,
    targetMessageAuthor: targetMessageAuthor ?? this.targetMessageAuthor,
    reactorPubkey: reactorPubkey ?? this.reactorPubkey,
    emoji: emoji ?? this.emoji,
    createdAt: createdAt ?? this.createdAt,
    giftWrapId: giftWrapId.present ? giftWrapId.value : this.giftWrapId,
    ownerPubkey: ownerPubkey ?? this.ownerPubkey,
    isDeleted: isDeleted ?? this.isDeleted,
    rumorEventJson: rumorEventJson.present
        ? rumorEventJson.value
        : this.rumorEventJson,
    publishStatus: publishStatus.present
        ? publishStatus.value
        : this.publishStatus,
  );
  DmReactionRow copyWithCompanion(DmMessageReactionsCompanion data) {
    return DmReactionRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      targetMessageId: data.targetMessageId.present
          ? data.targetMessageId.value
          : this.targetMessageId,
      targetMessageAuthor: data.targetMessageAuthor.present
          ? data.targetMessageAuthor.value
          : this.targetMessageAuthor,
      reactorPubkey: data.reactorPubkey.present
          ? data.reactorPubkey.value
          : this.reactorPubkey,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      giftWrapId: data.giftWrapId.present
          ? data.giftWrapId.value
          : this.giftWrapId,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      rumorEventJson: data.rumorEventJson.present
          ? data.rumorEventJson.value
          : this.rumorEventJson,
      publishStatus: data.publishStatus.present
          ? data.publishStatus.value
          : this.publishStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DmReactionRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('targetMessageId: $targetMessageId, ')
          ..write('targetMessageAuthor: $targetMessageAuthor, ')
          ..write('reactorPubkey: $reactorPubkey, ')
          ..write('emoji: $emoji, ')
          ..write('createdAt: $createdAt, ')
          ..write('giftWrapId: $giftWrapId, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rumorEventJson: $rumorEventJson, ')
          ..write('publishStatus: $publishStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    targetMessageId,
    targetMessageAuthor,
    reactorPubkey,
    emoji,
    createdAt,
    giftWrapId,
    ownerPubkey,
    isDeleted,
    rumorEventJson,
    publishStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DmReactionRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.targetMessageId == this.targetMessageId &&
          other.targetMessageAuthor == this.targetMessageAuthor &&
          other.reactorPubkey == this.reactorPubkey &&
          other.emoji == this.emoji &&
          other.createdAt == this.createdAt &&
          other.giftWrapId == this.giftWrapId &&
          other.ownerPubkey == this.ownerPubkey &&
          other.isDeleted == this.isDeleted &&
          other.rumorEventJson == this.rumorEventJson &&
          other.publishStatus == this.publishStatus);
}

class DmMessageReactionsCompanion extends UpdateCompanion<DmReactionRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> targetMessageId;
  final Value<String> targetMessageAuthor;
  final Value<String> reactorPubkey;
  final Value<String> emoji;
  final Value<int> createdAt;
  final Value<String?> giftWrapId;
  final Value<String> ownerPubkey;
  final Value<bool> isDeleted;
  final Value<String?> rumorEventJson;
  final Value<String?> publishStatus;
  final Value<int> rowid;
  const DmMessageReactionsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.targetMessageId = const Value.absent(),
    this.targetMessageAuthor = const Value.absent(),
    this.reactorPubkey = const Value.absent(),
    this.emoji = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.giftWrapId = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rumorEventJson = const Value.absent(),
    this.publishStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DmMessageReactionsCompanion.insert({
    required String id,
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String reactorPubkey,
    required String emoji,
    required int createdAt,
    this.giftWrapId = const Value.absent(),
    required String ownerPubkey,
    this.isDeleted = const Value.absent(),
    this.rumorEventJson = const Value.absent(),
    this.publishStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       targetMessageId = Value(targetMessageId),
       targetMessageAuthor = Value(targetMessageAuthor),
       reactorPubkey = Value(reactorPubkey),
       emoji = Value(emoji),
       createdAt = Value(createdAt),
       ownerPubkey = Value(ownerPubkey);
  static Insertable<DmReactionRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? targetMessageId,
    Expression<String>? targetMessageAuthor,
    Expression<String>? reactorPubkey,
    Expression<String>? emoji,
    Expression<int>? createdAt,
    Expression<String>? giftWrapId,
    Expression<String>? ownerPubkey,
    Expression<bool>? isDeleted,
    Expression<String>? rumorEventJson,
    Expression<String>? publishStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (targetMessageId != null) 'target_message_id': targetMessageId,
      if (targetMessageAuthor != null)
        'target_message_author': targetMessageAuthor,
      if (reactorPubkey != null) 'reactor_pubkey': reactorPubkey,
      if (emoji != null) 'emoji': emoji,
      if (createdAt != null) 'created_at': createdAt,
      if (giftWrapId != null) 'gift_wrap_id': giftWrapId,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rumorEventJson != null) 'rumor_event_json': rumorEventJson,
      if (publishStatus != null) 'publish_status': publishStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DmMessageReactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? targetMessageId,
    Value<String>? targetMessageAuthor,
    Value<String>? reactorPubkey,
    Value<String>? emoji,
    Value<int>? createdAt,
    Value<String?>? giftWrapId,
    Value<String>? ownerPubkey,
    Value<bool>? isDeleted,
    Value<String?>? rumorEventJson,
    Value<String?>? publishStatus,
    Value<int>? rowid,
  }) {
    return DmMessageReactionsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      targetMessageId: targetMessageId ?? this.targetMessageId,
      targetMessageAuthor: targetMessageAuthor ?? this.targetMessageAuthor,
      reactorPubkey: reactorPubkey ?? this.reactorPubkey,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      giftWrapId: giftWrapId ?? this.giftWrapId,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      isDeleted: isDeleted ?? this.isDeleted,
      rumorEventJson: rumorEventJson ?? this.rumorEventJson,
      publishStatus: publishStatus ?? this.publishStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (targetMessageId.present) {
      map['target_message_id'] = Variable<String>(targetMessageId.value);
    }
    if (targetMessageAuthor.present) {
      map['target_message_author'] = Variable<String>(
        targetMessageAuthor.value,
      );
    }
    if (reactorPubkey.present) {
      map['reactor_pubkey'] = Variable<String>(reactorPubkey.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (giftWrapId.present) {
      map['gift_wrap_id'] = Variable<String>(giftWrapId.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rumorEventJson.present) {
      map['rumor_event_json'] = Variable<String>(rumorEventJson.value);
    }
    if (publishStatus.present) {
      map['publish_status'] = Variable<String>(publishStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DmMessageReactionsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('targetMessageId: $targetMessageId, ')
          ..write('targetMessageAuthor: $targetMessageAuthor, ')
          ..write('reactorPubkey: $reactorPubkey, ')
          ..write('emoji: $emoji, ')
          ..write('createdAt: $createdAt, ')
          ..write('giftWrapId: $giftWrapId, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rumorEventJson: $rumorEventJson, ')
          ..write('publishStatus: $publishStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _participantPubkeysMeta =
      const VerificationMeta('participantPubkeys');
  @override
  late final GeneratedColumn<String> participantPubkeys =
      GeneratedColumn<String>(
        'participant_pubkeys',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _isGroupMeta = const VerificationMeta(
    'isGroup',
  );
  @override
  late final GeneratedColumn<bool> isGroup = GeneratedColumn<bool>(
    'is_group',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_group" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastMessageContentMeta =
      const VerificationMeta('lastMessageContent');
  @override
  late final GeneratedColumn<String> lastMessageContent =
      GeneratedColumn<String>(
        'last_message_content',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageTimestampMeta =
      const VerificationMeta('lastMessageTimestamp');
  @override
  late final GeneratedColumn<int> lastMessageTimestamp = GeneratedColumn<int>(
    'last_message_timestamp',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageSenderPubkeyMeta =
      const VerificationMeta('lastMessageSenderPubkey');
  @override
  late final GeneratedColumn<String> lastMessageSenderPubkey =
      GeneratedColumn<String>(
        'last_message_sender_pubkey',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastReadTimestampMeta = const VerificationMeta(
    'lastReadTimestamp',
  );
  @override
  late final GeneratedColumn<int> lastReadTimestamp = GeneratedColumn<int>(
    'last_read_timestamp',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentUserHasSentMeta =
      const VerificationMeta('currentUserHasSent');
  @override
  late final GeneratedColumn<bool> currentUserHasSent = GeneratedColumn<bool>(
    'current_user_has_sent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("current_user_has_sent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dmProtocolMeta = const VerificationMeta(
    'dmProtocol',
  );
  @override
  late final GeneratedColumn<String> dmProtocol = GeneratedColumn<String>(
    'dm_protocol',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    participantPubkeys,
    isGroup,
    lastMessageContent,
    lastMessageTimestamp,
    lastMessageSenderPubkey,
    subject,
    isRead,
    lastReadTimestamp,
    currentUserHasSent,
    createdAt,
    ownerPubkey,
    dmProtocol,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('participant_pubkeys')) {
      context.handle(
        _participantPubkeysMeta,
        participantPubkeys.isAcceptableOrUnknown(
          data['participant_pubkeys']!,
          _participantPubkeysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_participantPubkeysMeta);
    }
    if (data.containsKey('is_group')) {
      context.handle(
        _isGroupMeta,
        isGroup.isAcceptableOrUnknown(data['is_group']!, _isGroupMeta),
      );
    }
    if (data.containsKey('last_message_content')) {
      context.handle(
        _lastMessageContentMeta,
        lastMessageContent.isAcceptableOrUnknown(
          data['last_message_content']!,
          _lastMessageContentMeta,
        ),
      );
    }
    if (data.containsKey('last_message_timestamp')) {
      context.handle(
        _lastMessageTimestampMeta,
        lastMessageTimestamp.isAcceptableOrUnknown(
          data['last_message_timestamp']!,
          _lastMessageTimestampMeta,
        ),
      );
    }
    if (data.containsKey('last_message_sender_pubkey')) {
      context.handle(
        _lastMessageSenderPubkeyMeta,
        lastMessageSenderPubkey.isAcceptableOrUnknown(
          data['last_message_sender_pubkey']!,
          _lastMessageSenderPubkeyMeta,
        ),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('last_read_timestamp')) {
      context.handle(
        _lastReadTimestampMeta,
        lastReadTimestamp.isAcceptableOrUnknown(
          data['last_read_timestamp']!,
          _lastReadTimestampMeta,
        ),
      );
    }
    if (data.containsKey('current_user_has_sent')) {
      context.handle(
        _currentUserHasSentMeta,
        currentUserHasSent.isAcceptableOrUnknown(
          data['current_user_has_sent']!,
          _currentUserHasSentMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    }
    if (data.containsKey('dm_protocol')) {
      context.handle(
        _dmProtocolMeta,
        dmProtocol.isAcceptableOrUnknown(data['dm_protocol']!, _dmProtocolMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, ownerPubkey};
  @override
  ConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      participantPubkeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participant_pubkeys'],
      )!,
      isGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_group'],
      )!,
      lastMessageContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_content'],
      ),
      lastMessageTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_timestamp'],
      ),
      lastMessageSenderPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_sender_pubkey'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      lastReadTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_timestamp'],
      ),
      currentUserHasSent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}current_user_has_sent'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      )!,
      dmProtocol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dm_protocol'],
      ),
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  /// Deterministic conversation identifier (SHA-256 of sorted participant
  /// pubkeys).
  final String id;

  /// JSON-encoded list of participant pubkeys (sorted).
  final String participantPubkeys;

  /// Whether this is a group conversation (more than 2 participants).
  final bool isGroup;

  /// Preview text of the last message.
  final String? lastMessageContent;

  /// Unix timestamp of the last message.
  final int? lastMessageTimestamp;

  /// Pubkey of the last message sender.
  final String? lastMessageSenderPubkey;

  /// Optional conversation title (from `subject` tag).
  final String? subject;

  /// Whether the conversation has unread messages.
  final bool isRead;

  /// Per-conversation read cursor (unix seconds) for cross-device read-state
  /// sync (#4977). Monotonic high-water mark of the newest message the user
  /// has read; published encrypted-to-self over Nostr and restored on
  /// reinstall. NULL until the conversation is first read. Ingest never writes
  /// it — only `ConversationsDao.markAsRead` / `applyReadCursor` advance it,
  /// and only ever forward (`max`).
  final int? lastReadTimestamp;

  /// Whether the current user has sent a message in this conversation.
  final bool currentUserHasSent;

  /// Unix timestamp when the conversation was first created.
  final int createdAt;

  /// Hex public key of the account that owns this conversation view.
  ///
  /// Part of the primary key, for the same reason as
  /// [DirectMessages.ownerPubkey]: the conversation id is derived from the
  /// participant set, which is owner-independent, so two local accounts in one
  /// room compute the same id. With a global key the second account's upsert
  /// did not merely fail — `ownerPubkey` merged as `coalesce(excluded, old)`,
  /// so the incoming owner won and the room disappeared from the first
  /// account's inbox (#6645).
  ///
  /// NOT NULL with an empty-string default; see [DirectMessages.ownerPubkey]
  /// for why a nullable column cannot carry this invariant.
  final String ownerPubkey;

  /// The DM protocol used for this conversation: 'nip04' or 'nip17'.
  /// NULL when the protocol is unknown (e.g. conversation created before
  /// protocol tracking was added).
  final String? dmProtocol;
  const ConversationRow({
    required this.id,
    required this.participantPubkeys,
    required this.isGroup,
    this.lastMessageContent,
    this.lastMessageTimestamp,
    this.lastMessageSenderPubkey,
    this.subject,
    required this.isRead,
    this.lastReadTimestamp,
    required this.currentUserHasSent,
    required this.createdAt,
    required this.ownerPubkey,
    this.dmProtocol,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['participant_pubkeys'] = Variable<String>(participantPubkeys);
    map['is_group'] = Variable<bool>(isGroup);
    if (!nullToAbsent || lastMessageContent != null) {
      map['last_message_content'] = Variable<String>(lastMessageContent);
    }
    if (!nullToAbsent || lastMessageTimestamp != null) {
      map['last_message_timestamp'] = Variable<int>(lastMessageTimestamp);
    }
    if (!nullToAbsent || lastMessageSenderPubkey != null) {
      map['last_message_sender_pubkey'] = Variable<String>(
        lastMessageSenderPubkey,
      );
    }
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    map['is_read'] = Variable<bool>(isRead);
    if (!nullToAbsent || lastReadTimestamp != null) {
      map['last_read_timestamp'] = Variable<int>(lastReadTimestamp);
    }
    map['current_user_has_sent'] = Variable<bool>(currentUserHasSent);
    map['created_at'] = Variable<int>(createdAt);
    map['owner_pubkey'] = Variable<String>(ownerPubkey);
    if (!nullToAbsent || dmProtocol != null) {
      map['dm_protocol'] = Variable<String>(dmProtocol);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      participantPubkeys: Value(participantPubkeys),
      isGroup: Value(isGroup),
      lastMessageContent: lastMessageContent == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageContent),
      lastMessageTimestamp: lastMessageTimestamp == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageTimestamp),
      lastMessageSenderPubkey: lastMessageSenderPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageSenderPubkey),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      isRead: Value(isRead),
      lastReadTimestamp: lastReadTimestamp == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadTimestamp),
      currentUserHasSent: Value(currentUserHasSent),
      createdAt: Value(createdAt),
      ownerPubkey: Value(ownerPubkey),
      dmProtocol: dmProtocol == null && nullToAbsent
          ? const Value.absent()
          : Value(dmProtocol),
    );
  }

  factory ConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationRow(
      id: serializer.fromJson<String>(json['id']),
      participantPubkeys: serializer.fromJson<String>(
        json['participantPubkeys'],
      ),
      isGroup: serializer.fromJson<bool>(json['isGroup']),
      lastMessageContent: serializer.fromJson<String?>(
        json['lastMessageContent'],
      ),
      lastMessageTimestamp: serializer.fromJson<int?>(
        json['lastMessageTimestamp'],
      ),
      lastMessageSenderPubkey: serializer.fromJson<String?>(
        json['lastMessageSenderPubkey'],
      ),
      subject: serializer.fromJson<String?>(json['subject']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      lastReadTimestamp: serializer.fromJson<int?>(json['lastReadTimestamp']),
      currentUserHasSent: serializer.fromJson<bool>(json['currentUserHasSent']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      ownerPubkey: serializer.fromJson<String>(json['ownerPubkey']),
      dmProtocol: serializer.fromJson<String?>(json['dmProtocol']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'participantPubkeys': serializer.toJson<String>(participantPubkeys),
      'isGroup': serializer.toJson<bool>(isGroup),
      'lastMessageContent': serializer.toJson<String?>(lastMessageContent),
      'lastMessageTimestamp': serializer.toJson<int?>(lastMessageTimestamp),
      'lastMessageSenderPubkey': serializer.toJson<String?>(
        lastMessageSenderPubkey,
      ),
      'subject': serializer.toJson<String?>(subject),
      'isRead': serializer.toJson<bool>(isRead),
      'lastReadTimestamp': serializer.toJson<int?>(lastReadTimestamp),
      'currentUserHasSent': serializer.toJson<bool>(currentUserHasSent),
      'createdAt': serializer.toJson<int>(createdAt),
      'ownerPubkey': serializer.toJson<String>(ownerPubkey),
      'dmProtocol': serializer.toJson<String?>(dmProtocol),
    };
  }

  ConversationRow copyWith({
    String? id,
    String? participantPubkeys,
    bool? isGroup,
    Value<String?> lastMessageContent = const Value.absent(),
    Value<int?> lastMessageTimestamp = const Value.absent(),
    Value<String?> lastMessageSenderPubkey = const Value.absent(),
    Value<String?> subject = const Value.absent(),
    bool? isRead,
    Value<int?> lastReadTimestamp = const Value.absent(),
    bool? currentUserHasSent,
    int? createdAt,
    String? ownerPubkey,
    Value<String?> dmProtocol = const Value.absent(),
  }) => ConversationRow(
    id: id ?? this.id,
    participantPubkeys: participantPubkeys ?? this.participantPubkeys,
    isGroup: isGroup ?? this.isGroup,
    lastMessageContent: lastMessageContent.present
        ? lastMessageContent.value
        : this.lastMessageContent,
    lastMessageTimestamp: lastMessageTimestamp.present
        ? lastMessageTimestamp.value
        : this.lastMessageTimestamp,
    lastMessageSenderPubkey: lastMessageSenderPubkey.present
        ? lastMessageSenderPubkey.value
        : this.lastMessageSenderPubkey,
    subject: subject.present ? subject.value : this.subject,
    isRead: isRead ?? this.isRead,
    lastReadTimestamp: lastReadTimestamp.present
        ? lastReadTimestamp.value
        : this.lastReadTimestamp,
    currentUserHasSent: currentUserHasSent ?? this.currentUserHasSent,
    createdAt: createdAt ?? this.createdAt,
    ownerPubkey: ownerPubkey ?? this.ownerPubkey,
    dmProtocol: dmProtocol.present ? dmProtocol.value : this.dmProtocol,
  );
  ConversationRow copyWithCompanion(ConversationsCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      participantPubkeys: data.participantPubkeys.present
          ? data.participantPubkeys.value
          : this.participantPubkeys,
      isGroup: data.isGroup.present ? data.isGroup.value : this.isGroup,
      lastMessageContent: data.lastMessageContent.present
          ? data.lastMessageContent.value
          : this.lastMessageContent,
      lastMessageTimestamp: data.lastMessageTimestamp.present
          ? data.lastMessageTimestamp.value
          : this.lastMessageTimestamp,
      lastMessageSenderPubkey: data.lastMessageSenderPubkey.present
          ? data.lastMessageSenderPubkey.value
          : this.lastMessageSenderPubkey,
      subject: data.subject.present ? data.subject.value : this.subject,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      lastReadTimestamp: data.lastReadTimestamp.present
          ? data.lastReadTimestamp.value
          : this.lastReadTimestamp,
      currentUserHasSent: data.currentUserHasSent.present
          ? data.currentUserHasSent.value
          : this.currentUserHasSent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
      dmProtocol: data.dmProtocol.present
          ? data.dmProtocol.value
          : this.dmProtocol,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('participantPubkeys: $participantPubkeys, ')
          ..write('isGroup: $isGroup, ')
          ..write('lastMessageContent: $lastMessageContent, ')
          ..write('lastMessageTimestamp: $lastMessageTimestamp, ')
          ..write('lastMessageSenderPubkey: $lastMessageSenderPubkey, ')
          ..write('subject: $subject, ')
          ..write('isRead: $isRead, ')
          ..write('lastReadTimestamp: $lastReadTimestamp, ')
          ..write('currentUserHasSent: $currentUserHasSent, ')
          ..write('createdAt: $createdAt, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('dmProtocol: $dmProtocol')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    participantPubkeys,
    isGroup,
    lastMessageContent,
    lastMessageTimestamp,
    lastMessageSenderPubkey,
    subject,
    isRead,
    lastReadTimestamp,
    currentUserHasSent,
    createdAt,
    ownerPubkey,
    dmProtocol,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.participantPubkeys == this.participantPubkeys &&
          other.isGroup == this.isGroup &&
          other.lastMessageContent == this.lastMessageContent &&
          other.lastMessageTimestamp == this.lastMessageTimestamp &&
          other.lastMessageSenderPubkey == this.lastMessageSenderPubkey &&
          other.subject == this.subject &&
          other.isRead == this.isRead &&
          other.lastReadTimestamp == this.lastReadTimestamp &&
          other.currentUserHasSent == this.currentUserHasSent &&
          other.createdAt == this.createdAt &&
          other.ownerPubkey == this.ownerPubkey &&
          other.dmProtocol == this.dmProtocol);
}

class ConversationsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String> participantPubkeys;
  final Value<bool> isGroup;
  final Value<String?> lastMessageContent;
  final Value<int?> lastMessageTimestamp;
  final Value<String?> lastMessageSenderPubkey;
  final Value<String?> subject;
  final Value<bool> isRead;
  final Value<int?> lastReadTimestamp;
  final Value<bool> currentUserHasSent;
  final Value<int> createdAt;
  final Value<String> ownerPubkey;
  final Value<String?> dmProtocol;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.participantPubkeys = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.lastMessageContent = const Value.absent(),
    this.lastMessageTimestamp = const Value.absent(),
    this.lastMessageSenderPubkey = const Value.absent(),
    this.subject = const Value.absent(),
    this.isRead = const Value.absent(),
    this.lastReadTimestamp = const Value.absent(),
    this.currentUserHasSent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.dmProtocol = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String participantPubkeys,
    this.isGroup = const Value.absent(),
    this.lastMessageContent = const Value.absent(),
    this.lastMessageTimestamp = const Value.absent(),
    this.lastMessageSenderPubkey = const Value.absent(),
    this.subject = const Value.absent(),
    this.isRead = const Value.absent(),
    this.lastReadTimestamp = const Value.absent(),
    this.currentUserHasSent = const Value.absent(),
    required int createdAt,
    this.ownerPubkey = const Value.absent(),
    this.dmProtocol = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       participantPubkeys = Value(participantPubkeys),
       createdAt = Value(createdAt);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? participantPubkeys,
    Expression<bool>? isGroup,
    Expression<String>? lastMessageContent,
    Expression<int>? lastMessageTimestamp,
    Expression<String>? lastMessageSenderPubkey,
    Expression<String>? subject,
    Expression<bool>? isRead,
    Expression<int>? lastReadTimestamp,
    Expression<bool>? currentUserHasSent,
    Expression<int>? createdAt,
    Expression<String>? ownerPubkey,
    Expression<String>? dmProtocol,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (participantPubkeys != null) 'participant_pubkeys': participantPubkeys,
      if (isGroup != null) 'is_group': isGroup,
      if (lastMessageContent != null)
        'last_message_content': lastMessageContent,
      if (lastMessageTimestamp != null)
        'last_message_timestamp': lastMessageTimestamp,
      if (lastMessageSenderPubkey != null)
        'last_message_sender_pubkey': lastMessageSenderPubkey,
      if (subject != null) 'subject': subject,
      if (isRead != null) 'is_read': isRead,
      if (lastReadTimestamp != null) 'last_read_timestamp': lastReadTimestamp,
      if (currentUserHasSent != null)
        'current_user_has_sent': currentUserHasSent,
      if (createdAt != null) 'created_at': createdAt,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (dmProtocol != null) 'dm_protocol': dmProtocol,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? participantPubkeys,
    Value<bool>? isGroup,
    Value<String?>? lastMessageContent,
    Value<int?>? lastMessageTimestamp,
    Value<String?>? lastMessageSenderPubkey,
    Value<String?>? subject,
    Value<bool>? isRead,
    Value<int?>? lastReadTimestamp,
    Value<bool>? currentUserHasSent,
    Value<int>? createdAt,
    Value<String>? ownerPubkey,
    Value<String?>? dmProtocol,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      participantPubkeys: participantPubkeys ?? this.participantPubkeys,
      isGroup: isGroup ?? this.isGroup,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSenderPubkey:
          lastMessageSenderPubkey ?? this.lastMessageSenderPubkey,
      subject: subject ?? this.subject,
      isRead: isRead ?? this.isRead,
      lastReadTimestamp: lastReadTimestamp ?? this.lastReadTimestamp,
      currentUserHasSent: currentUserHasSent ?? this.currentUserHasSent,
      createdAt: createdAt ?? this.createdAt,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      dmProtocol: dmProtocol ?? this.dmProtocol,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (participantPubkeys.present) {
      map['participant_pubkeys'] = Variable<String>(participantPubkeys.value);
    }
    if (isGroup.present) {
      map['is_group'] = Variable<bool>(isGroup.value);
    }
    if (lastMessageContent.present) {
      map['last_message_content'] = Variable<String>(lastMessageContent.value);
    }
    if (lastMessageTimestamp.present) {
      map['last_message_timestamp'] = Variable<int>(lastMessageTimestamp.value);
    }
    if (lastMessageSenderPubkey.present) {
      map['last_message_sender_pubkey'] = Variable<String>(
        lastMessageSenderPubkey.value,
      );
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (lastReadTimestamp.present) {
      map['last_read_timestamp'] = Variable<int>(lastReadTimestamp.value);
    }
    if (currentUserHasSent.present) {
      map['current_user_has_sent'] = Variable<bool>(currentUserHasSent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (dmProtocol.present) {
      map['dm_protocol'] = Variable<String>(dmProtocol.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('participantPubkeys: $participantPubkeys, ')
          ..write('isGroup: $isGroup, ')
          ..write('lastMessageContent: $lastMessageContent, ')
          ..write('lastMessageTimestamp: $lastMessageTimestamp, ')
          ..write('lastMessageSenderPubkey: $lastMessageSenderPubkey, ')
          ..write('subject: $subject, ')
          ..write('isRead: $isRead, ')
          ..write('lastReadTimestamp: $lastReadTimestamp, ')
          ..write('currentUserHasSent: $currentUserHasSent, ')
          ..write('createdAt: $createdAt, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('dmProtocol: $dmProtocol, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutgoingDmsTable extends OutgoingDms
    with TableInfo<$OutgoingDmsTable, OutgoingDmRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutgoingDmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientPubkeyMeta = const VerificationMeta(
    'recipientPubkey',
  );
  @override
  late final GeneratedColumn<String> recipientPubkey = GeneratedColumn<String>(
    'recipient_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rumorEventJsonMeta = const VerificationMeta(
    'rumorEventJson',
  );
  @override
  late final GeneratedColumn<String> rumorEventJson = GeneratedColumn<String>(
    'rumor_event_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageKindMeta = const VerificationMeta(
    'messageKind',
  );
  @override
  late final GeneratedColumn<int> messageKind = GeneratedColumn<int>(
    'message_kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(14),
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recipientWrapStatusMeta =
      const VerificationMeta('recipientWrapStatus');
  @override
  late final GeneratedColumn<String> recipientWrapStatus =
      GeneratedColumn<String>(
        'recipient_wrap_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _selfWrapStatusMeta = const VerificationMeta(
    'selfWrapStatus',
  );
  @override
  late final GeneratedColumn<String> selfWrapStatus = GeneratedColumn<String>(
    'self_wrap_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientWrapEventIdMeta =
      const VerificationMeta('recipientWrapEventId');
  @override
  late final GeneratedColumn<String> recipientWrapEventId =
      GeneratedColumn<String>(
        'recipient_wrap_event_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _selfWrapEventIdMeta = const VerificationMeta(
    'selfWrapEventId',
  );
  @override
  late final GeneratedColumn<String> selfWrapEventId = GeneratedColumn<String>(
    'self_wrap_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _recipientWrapLastErrorMeta =
      const VerificationMeta('recipientWrapLastError');
  @override
  late final GeneratedColumn<String> recipientWrapLastError =
      GeneratedColumn<String>(
        'recipient_wrap_last_error',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _selfWrapLastErrorMeta = const VerificationMeta(
    'selfWrapLastError',
  );
  @override
  late final GeneratedColumn<String> selfWrapLastError =
      GeneratedColumn<String>(
        'self_wrap_last_error',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sendBatchIdMeta = const VerificationMeta(
    'sendBatchId',
  );
  @override
  late final GeneratedColumn<String> sendBatchId = GeneratedColumn<String>(
    'send_batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    recipientPubkey,
    content,
    createdAt,
    rumorEventJson,
    messageKind,
    replyToId,
    recipientWrapStatus,
    selfWrapStatus,
    recipientWrapEventId,
    selfWrapEventId,
    retryCount,
    recipientWrapLastError,
    selfWrapLastError,
    lastAttemptAt,
    queuedAt,
    ownerPubkey,
    sendBatchId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outgoing_dms';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutgoingDmRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('recipient_pubkey')) {
      context.handle(
        _recipientPubkeyMeta,
        recipientPubkey.isAcceptableOrUnknown(
          data['recipient_pubkey']!,
          _recipientPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientPubkeyMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('rumor_event_json')) {
      context.handle(
        _rumorEventJsonMeta,
        rumorEventJson.isAcceptableOrUnknown(
          data['rumor_event_json']!,
          _rumorEventJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rumorEventJsonMeta);
    }
    if (data.containsKey('message_kind')) {
      context.handle(
        _messageKindMeta,
        messageKind.isAcceptableOrUnknown(
          data['message_kind']!,
          _messageKindMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('recipient_wrap_status')) {
      context.handle(
        _recipientWrapStatusMeta,
        recipientWrapStatus.isAcceptableOrUnknown(
          data['recipient_wrap_status']!,
          _recipientWrapStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientWrapStatusMeta);
    }
    if (data.containsKey('self_wrap_status')) {
      context.handle(
        _selfWrapStatusMeta,
        selfWrapStatus.isAcceptableOrUnknown(
          data['self_wrap_status']!,
          _selfWrapStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selfWrapStatusMeta);
    }
    if (data.containsKey('recipient_wrap_event_id')) {
      context.handle(
        _recipientWrapEventIdMeta,
        recipientWrapEventId.isAcceptableOrUnknown(
          data['recipient_wrap_event_id']!,
          _recipientWrapEventIdMeta,
        ),
      );
    }
    if (data.containsKey('self_wrap_event_id')) {
      context.handle(
        _selfWrapEventIdMeta,
        selfWrapEventId.isAcceptableOrUnknown(
          data['self_wrap_event_id']!,
          _selfWrapEventIdMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('recipient_wrap_last_error')) {
      context.handle(
        _recipientWrapLastErrorMeta,
        recipientWrapLastError.isAcceptableOrUnknown(
          data['recipient_wrap_last_error']!,
          _recipientWrapLastErrorMeta,
        ),
      );
    }
    if (data.containsKey('self_wrap_last_error')) {
      context.handle(
        _selfWrapLastErrorMeta,
        selfWrapLastError.isAcceptableOrUnknown(
          data['self_wrap_last_error']!,
          _selfWrapLastErrorMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerPubkeyMeta);
    }
    if (data.containsKey('send_batch_id')) {
      context.handle(
        _sendBatchIdMeta,
        sendBatchId.isAcceptableOrUnknown(
          data['send_batch_id']!,
          _sendBatchIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutgoingDmRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutgoingDmRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      recipientPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_pubkey'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      rumorEventJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rumor_event_json'],
      )!,
      messageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_kind'],
      )!,
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      recipientWrapStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_wrap_status'],
      )!,
      selfWrapStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}self_wrap_status'],
      )!,
      recipientWrapEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_wrap_event_id'],
      ),
      selfWrapEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}self_wrap_event_id'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      recipientWrapLastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_wrap_last_error'],
      ),
      selfWrapLastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}self_wrap_last_error'],
      ),
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      )!,
      sendBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}send_batch_id'],
      ),
    );
  }

  @override
  $OutgoingDmsTable createAlias(String alias) {
    return $OutgoingDmsTable(attachedDatabase, alias);
  }
}

class OutgoingDmRow extends DataClass implements Insertable<OutgoingDmRow> {
  /// Opaque durable queue-row handle. It equals the rumor event id for 1:1
  /// and legacy sends. Group sends append the recipient pubkey because one
  /// shared wire rumor needs separate delivery state for each recipient.
  final String id;

  /// Deterministic conversation identifier (SHA-256 of sorted
  /// participant pubkeys). Same shape as `direct_messages.conversation_id`
  /// so the BLoC can `Rx.combineLatest2(watchMessages, watchOutgoing)`
  /// for a conversation view.
  final String conversationId;

  /// Recipient's hex pubkey for the 1:1 path. (Group sends file one row
  /// per participant — `conversation_id` is the group conversation, but
  /// each row is targeted at one recipient.)
  final String recipientPubkey;

  /// Plaintext message content. Stored alongside `rumor_event_json` so
  /// the UI can render the bubble without re-parsing the rumor on every
  /// rebuild. Authoritative source for retries is `rumor_event_json`.
  final String content;

  /// Unix timestamp from the rumor event's `created_at`. Stable across
  /// retries because the rumor itself is reused.
  final int createdAt;

  /// Serialized JSON of the unsigned NIP-17 rumor (kind 14 or 15). Used
  /// on retry so we re-wrap the same rumor — preserving `rumor.id`,
  /// which is what the receiver's gift-wrap dedup keys on.
  final String rumorEventJson;

  /// The rumor event kind (14 = text, 15 = file). Defaults to 14.
  final int messageKind;

  /// Optional reply target rumor id.
  final String? replyToId;

  /// Status of the recipient gift-wrap publish: `pending` | `sent` |
  /// `failed`. Stored as a string (rather than an int-coded enum) so a
  /// dump of the table is human-readable. Adding a new state requires a
  /// matching update to `OutgoingWrapStatus` in the DAO — the read
  /// path throws on unknown values rather than silently coercing them
  /// back to `pending` (which would put corrupt or future-schema rows
  /// back into the retry service's active set and risk double-delivery).
  final String recipientWrapStatus;

  /// Status of the self-addressed gift-wrap publish: same enum as
  /// `recipient_wrap_status`. The `false` value of
  /// `NIP17SendResult.selfWrapPublished` flips this to `failed`; a row
  /// with `recipient: sent, self: failed` is the partial-delivery state
  /// from #3909 / #3902.
  final String selfWrapStatus;

  /// Recipient gift-wrap event id (kind 1059) once published. Null while
  /// `recipient_wrap_status` is `pending` or `failed`.
  final String? recipientWrapEventId;

  /// Self gift-wrap event id (kind 1059) once published. Null while
  /// `self_wrap_status` is `pending` or `failed`.
  final String? selfWrapEventId;

  /// How many publish attempts this row has survived. Caps growth at the
  /// retry policy's max; once exhausted the UI surfaces a manual retry
  /// affordance.
  final int retryCount;

  /// Last error message from the most recent failed **recipient** wrap
  /// publish. `null` when the recipient wrap has never failed or when the
  /// most recent recipient transition was a success.
  ///
  /// Stored independently of [selfWrapLastError] because the two wraps
  /// fail for different reasons (e.g. recipient relay rejected the
  /// kind-1059 vs ephemeral self-relay timeout) — collapsing both into a
  /// single column would silently overwrite one cause with the other on
  /// the second failure and starve the retry service of useful diagnostics.
  final String? recipientWrapLastError;

  /// Last error message from the most recent failed **self** wrap
  /// publish. Same lifecycle and rationale as [recipientWrapLastError];
  /// kept in its own column so a recipient failure followed by a self
  /// failure preserves both reasons.
  final String? selfWrapLastError;

  /// Wall-clock timestamp of the most recent publish attempt. Drives
  /// the retry service's backoff scheduling.
  final DateTime? lastAttemptAt;

  /// Wall-clock timestamp of the row's creation. Used to order the queue
  /// when retrying.
  final DateTime queuedAt;

  /// Hex pubkey of the account that queued this send. Mirrors
  /// `direct_messages.owner_pubkey` for multi-account isolation.
  final String ownerPubkey;

  /// Durable, collision-proof identity of one send invocation. A 1:1 send has
  /// one unique value; `sendGroupMessage` stamps one shared value on every
  /// per-recipient sibling. It separates same-second identical sends and lets
  /// group persistence dedup, optimistic grouping, sibling lookup, and
  /// cancellation use an exact value. NULL only for legacy rows. See
  /// `DirectMessages.sendBatchId`.
  final String? sendBatchId;
  const OutgoingDmRow({
    required this.id,
    required this.conversationId,
    required this.recipientPubkey,
    required this.content,
    required this.createdAt,
    required this.rumorEventJson,
    required this.messageKind,
    this.replyToId,
    required this.recipientWrapStatus,
    required this.selfWrapStatus,
    this.recipientWrapEventId,
    this.selfWrapEventId,
    required this.retryCount,
    this.recipientWrapLastError,
    this.selfWrapLastError,
    this.lastAttemptAt,
    required this.queuedAt,
    required this.ownerPubkey,
    this.sendBatchId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['recipient_pubkey'] = Variable<String>(recipientPubkey);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<int>(createdAt);
    map['rumor_event_json'] = Variable<String>(rumorEventJson);
    map['message_kind'] = Variable<int>(messageKind);
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    map['recipient_wrap_status'] = Variable<String>(recipientWrapStatus);
    map['self_wrap_status'] = Variable<String>(selfWrapStatus);
    if (!nullToAbsent || recipientWrapEventId != null) {
      map['recipient_wrap_event_id'] = Variable<String>(recipientWrapEventId);
    }
    if (!nullToAbsent || selfWrapEventId != null) {
      map['self_wrap_event_id'] = Variable<String>(selfWrapEventId);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || recipientWrapLastError != null) {
      map['recipient_wrap_last_error'] = Variable<String>(
        recipientWrapLastError,
      );
    }
    if (!nullToAbsent || selfWrapLastError != null) {
      map['self_wrap_last_error'] = Variable<String>(selfWrapLastError);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['owner_pubkey'] = Variable<String>(ownerPubkey);
    if (!nullToAbsent || sendBatchId != null) {
      map['send_batch_id'] = Variable<String>(sendBatchId);
    }
    return map;
  }

  OutgoingDmsCompanion toCompanion(bool nullToAbsent) {
    return OutgoingDmsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      recipientPubkey: Value(recipientPubkey),
      content: Value(content),
      createdAt: Value(createdAt),
      rumorEventJson: Value(rumorEventJson),
      messageKind: Value(messageKind),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      recipientWrapStatus: Value(recipientWrapStatus),
      selfWrapStatus: Value(selfWrapStatus),
      recipientWrapEventId: recipientWrapEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(recipientWrapEventId),
      selfWrapEventId: selfWrapEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(selfWrapEventId),
      retryCount: Value(retryCount),
      recipientWrapLastError: recipientWrapLastError == null && nullToAbsent
          ? const Value.absent()
          : Value(recipientWrapLastError),
      selfWrapLastError: selfWrapLastError == null && nullToAbsent
          ? const Value.absent()
          : Value(selfWrapLastError),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      queuedAt: Value(queuedAt),
      ownerPubkey: Value(ownerPubkey),
      sendBatchId: sendBatchId == null && nullToAbsent
          ? const Value.absent()
          : Value(sendBatchId),
    );
  }

  factory OutgoingDmRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutgoingDmRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      recipientPubkey: serializer.fromJson<String>(json['recipientPubkey']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      rumorEventJson: serializer.fromJson<String>(json['rumorEventJson']),
      messageKind: serializer.fromJson<int>(json['messageKind']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      recipientWrapStatus: serializer.fromJson<String>(
        json['recipientWrapStatus'],
      ),
      selfWrapStatus: serializer.fromJson<String>(json['selfWrapStatus']),
      recipientWrapEventId: serializer.fromJson<String?>(
        json['recipientWrapEventId'],
      ),
      selfWrapEventId: serializer.fromJson<String?>(json['selfWrapEventId']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      recipientWrapLastError: serializer.fromJson<String?>(
        json['recipientWrapLastError'],
      ),
      selfWrapLastError: serializer.fromJson<String?>(
        json['selfWrapLastError'],
      ),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      ownerPubkey: serializer.fromJson<String>(json['ownerPubkey']),
      sendBatchId: serializer.fromJson<String?>(json['sendBatchId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'recipientPubkey': serializer.toJson<String>(recipientPubkey),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<int>(createdAt),
      'rumorEventJson': serializer.toJson<String>(rumorEventJson),
      'messageKind': serializer.toJson<int>(messageKind),
      'replyToId': serializer.toJson<String?>(replyToId),
      'recipientWrapStatus': serializer.toJson<String>(recipientWrapStatus),
      'selfWrapStatus': serializer.toJson<String>(selfWrapStatus),
      'recipientWrapEventId': serializer.toJson<String?>(recipientWrapEventId),
      'selfWrapEventId': serializer.toJson<String?>(selfWrapEventId),
      'retryCount': serializer.toJson<int>(retryCount),
      'recipientWrapLastError': serializer.toJson<String?>(
        recipientWrapLastError,
      ),
      'selfWrapLastError': serializer.toJson<String?>(selfWrapLastError),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'ownerPubkey': serializer.toJson<String>(ownerPubkey),
      'sendBatchId': serializer.toJson<String?>(sendBatchId),
    };
  }

  OutgoingDmRow copyWith({
    String? id,
    String? conversationId,
    String? recipientPubkey,
    String? content,
    int? createdAt,
    String? rumorEventJson,
    int? messageKind,
    Value<String?> replyToId = const Value.absent(),
    String? recipientWrapStatus,
    String? selfWrapStatus,
    Value<String?> recipientWrapEventId = const Value.absent(),
    Value<String?> selfWrapEventId = const Value.absent(),
    int? retryCount,
    Value<String?> recipientWrapLastError = const Value.absent(),
    Value<String?> selfWrapLastError = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    DateTime? queuedAt,
    String? ownerPubkey,
    Value<String?> sendBatchId = const Value.absent(),
  }) => OutgoingDmRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    recipientPubkey: recipientPubkey ?? this.recipientPubkey,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    rumorEventJson: rumorEventJson ?? this.rumorEventJson,
    messageKind: messageKind ?? this.messageKind,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    recipientWrapStatus: recipientWrapStatus ?? this.recipientWrapStatus,
    selfWrapStatus: selfWrapStatus ?? this.selfWrapStatus,
    recipientWrapEventId: recipientWrapEventId.present
        ? recipientWrapEventId.value
        : this.recipientWrapEventId,
    selfWrapEventId: selfWrapEventId.present
        ? selfWrapEventId.value
        : this.selfWrapEventId,
    retryCount: retryCount ?? this.retryCount,
    recipientWrapLastError: recipientWrapLastError.present
        ? recipientWrapLastError.value
        : this.recipientWrapLastError,
    selfWrapLastError: selfWrapLastError.present
        ? selfWrapLastError.value
        : this.selfWrapLastError,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    queuedAt: queuedAt ?? this.queuedAt,
    ownerPubkey: ownerPubkey ?? this.ownerPubkey,
    sendBatchId: sendBatchId.present ? sendBatchId.value : this.sendBatchId,
  );
  OutgoingDmRow copyWithCompanion(OutgoingDmsCompanion data) {
    return OutgoingDmRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      recipientPubkey: data.recipientPubkey.present
          ? data.recipientPubkey.value
          : this.recipientPubkey,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      rumorEventJson: data.rumorEventJson.present
          ? data.rumorEventJson.value
          : this.rumorEventJson,
      messageKind: data.messageKind.present
          ? data.messageKind.value
          : this.messageKind,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      recipientWrapStatus: data.recipientWrapStatus.present
          ? data.recipientWrapStatus.value
          : this.recipientWrapStatus,
      selfWrapStatus: data.selfWrapStatus.present
          ? data.selfWrapStatus.value
          : this.selfWrapStatus,
      recipientWrapEventId: data.recipientWrapEventId.present
          ? data.recipientWrapEventId.value
          : this.recipientWrapEventId,
      selfWrapEventId: data.selfWrapEventId.present
          ? data.selfWrapEventId.value
          : this.selfWrapEventId,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      recipientWrapLastError: data.recipientWrapLastError.present
          ? data.recipientWrapLastError.value
          : this.recipientWrapLastError,
      selfWrapLastError: data.selfWrapLastError.present
          ? data.selfWrapLastError.value
          : this.selfWrapLastError,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
      sendBatchId: data.sendBatchId.present
          ? data.sendBatchId.value
          : this.sendBatchId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutgoingDmRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('recipientPubkey: $recipientPubkey, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('rumorEventJson: $rumorEventJson, ')
          ..write('messageKind: $messageKind, ')
          ..write('replyToId: $replyToId, ')
          ..write('recipientWrapStatus: $recipientWrapStatus, ')
          ..write('selfWrapStatus: $selfWrapStatus, ')
          ..write('recipientWrapEventId: $recipientWrapEventId, ')
          ..write('selfWrapEventId: $selfWrapEventId, ')
          ..write('retryCount: $retryCount, ')
          ..write('recipientWrapLastError: $recipientWrapLastError, ')
          ..write('selfWrapLastError: $selfWrapLastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('sendBatchId: $sendBatchId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    recipientPubkey,
    content,
    createdAt,
    rumorEventJson,
    messageKind,
    replyToId,
    recipientWrapStatus,
    selfWrapStatus,
    recipientWrapEventId,
    selfWrapEventId,
    retryCount,
    recipientWrapLastError,
    selfWrapLastError,
    lastAttemptAt,
    queuedAt,
    ownerPubkey,
    sendBatchId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutgoingDmRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.recipientPubkey == this.recipientPubkey &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.rumorEventJson == this.rumorEventJson &&
          other.messageKind == this.messageKind &&
          other.replyToId == this.replyToId &&
          other.recipientWrapStatus == this.recipientWrapStatus &&
          other.selfWrapStatus == this.selfWrapStatus &&
          other.recipientWrapEventId == this.recipientWrapEventId &&
          other.selfWrapEventId == this.selfWrapEventId &&
          other.retryCount == this.retryCount &&
          other.recipientWrapLastError == this.recipientWrapLastError &&
          other.selfWrapLastError == this.selfWrapLastError &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.queuedAt == this.queuedAt &&
          other.ownerPubkey == this.ownerPubkey &&
          other.sendBatchId == this.sendBatchId);
}

class OutgoingDmsCompanion extends UpdateCompanion<OutgoingDmRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> recipientPubkey;
  final Value<String> content;
  final Value<int> createdAt;
  final Value<String> rumorEventJson;
  final Value<int> messageKind;
  final Value<String?> replyToId;
  final Value<String> recipientWrapStatus;
  final Value<String> selfWrapStatus;
  final Value<String?> recipientWrapEventId;
  final Value<String?> selfWrapEventId;
  final Value<int> retryCount;
  final Value<String?> recipientWrapLastError;
  final Value<String?> selfWrapLastError;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime> queuedAt;
  final Value<String> ownerPubkey;
  final Value<String?> sendBatchId;
  final Value<int> rowid;
  const OutgoingDmsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.recipientPubkey = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rumorEventJson = const Value.absent(),
    this.messageKind = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.recipientWrapStatus = const Value.absent(),
    this.selfWrapStatus = const Value.absent(),
    this.recipientWrapEventId = const Value.absent(),
    this.selfWrapEventId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.recipientWrapLastError = const Value.absent(),
    this.selfWrapLastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.sendBatchId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutgoingDmsCompanion.insert({
    required String id,
    required String conversationId,
    required String recipientPubkey,
    required String content,
    required int createdAt,
    required String rumorEventJson,
    this.messageKind = const Value.absent(),
    this.replyToId = const Value.absent(),
    required String recipientWrapStatus,
    required String selfWrapStatus,
    this.recipientWrapEventId = const Value.absent(),
    this.selfWrapEventId = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.recipientWrapLastError = const Value.absent(),
    this.selfWrapLastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    required DateTime queuedAt,
    required String ownerPubkey,
    this.sendBatchId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       recipientPubkey = Value(recipientPubkey),
       content = Value(content),
       createdAt = Value(createdAt),
       rumorEventJson = Value(rumorEventJson),
       recipientWrapStatus = Value(recipientWrapStatus),
       selfWrapStatus = Value(selfWrapStatus),
       queuedAt = Value(queuedAt),
       ownerPubkey = Value(ownerPubkey);
  static Insertable<OutgoingDmRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? recipientPubkey,
    Expression<String>? content,
    Expression<int>? createdAt,
    Expression<String>? rumorEventJson,
    Expression<int>? messageKind,
    Expression<String>? replyToId,
    Expression<String>? recipientWrapStatus,
    Expression<String>? selfWrapStatus,
    Expression<String>? recipientWrapEventId,
    Expression<String>? selfWrapEventId,
    Expression<int>? retryCount,
    Expression<String>? recipientWrapLastError,
    Expression<String>? selfWrapLastError,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? queuedAt,
    Expression<String>? ownerPubkey,
    Expression<String>? sendBatchId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (recipientPubkey != null) 'recipient_pubkey': recipientPubkey,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (rumorEventJson != null) 'rumor_event_json': rumorEventJson,
      if (messageKind != null) 'message_kind': messageKind,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (recipientWrapStatus != null)
        'recipient_wrap_status': recipientWrapStatus,
      if (selfWrapStatus != null) 'self_wrap_status': selfWrapStatus,
      if (recipientWrapEventId != null)
        'recipient_wrap_event_id': recipientWrapEventId,
      if (selfWrapEventId != null) 'self_wrap_event_id': selfWrapEventId,
      if (retryCount != null) 'retry_count': retryCount,
      if (recipientWrapLastError != null)
        'recipient_wrap_last_error': recipientWrapLastError,
      if (selfWrapLastError != null) 'self_wrap_last_error': selfWrapLastError,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (sendBatchId != null) 'send_batch_id': sendBatchId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutgoingDmsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? recipientPubkey,
    Value<String>? content,
    Value<int>? createdAt,
    Value<String>? rumorEventJson,
    Value<int>? messageKind,
    Value<String?>? replyToId,
    Value<String>? recipientWrapStatus,
    Value<String>? selfWrapStatus,
    Value<String?>? recipientWrapEventId,
    Value<String?>? selfWrapEventId,
    Value<int>? retryCount,
    Value<String?>? recipientWrapLastError,
    Value<String?>? selfWrapLastError,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime>? queuedAt,
    Value<String>? ownerPubkey,
    Value<String?>? sendBatchId,
    Value<int>? rowid,
  }) {
    return OutgoingDmsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      recipientPubkey: recipientPubkey ?? this.recipientPubkey,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      rumorEventJson: rumorEventJson ?? this.rumorEventJson,
      messageKind: messageKind ?? this.messageKind,
      replyToId: replyToId ?? this.replyToId,
      recipientWrapStatus: recipientWrapStatus ?? this.recipientWrapStatus,
      selfWrapStatus: selfWrapStatus ?? this.selfWrapStatus,
      recipientWrapEventId: recipientWrapEventId ?? this.recipientWrapEventId,
      selfWrapEventId: selfWrapEventId ?? this.selfWrapEventId,
      retryCount: retryCount ?? this.retryCount,
      recipientWrapLastError:
          recipientWrapLastError ?? this.recipientWrapLastError,
      selfWrapLastError: selfWrapLastError ?? this.selfWrapLastError,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      queuedAt: queuedAt ?? this.queuedAt,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      sendBatchId: sendBatchId ?? this.sendBatchId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (recipientPubkey.present) {
      map['recipient_pubkey'] = Variable<String>(recipientPubkey.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rumorEventJson.present) {
      map['rumor_event_json'] = Variable<String>(rumorEventJson.value);
    }
    if (messageKind.present) {
      map['message_kind'] = Variable<int>(messageKind.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (recipientWrapStatus.present) {
      map['recipient_wrap_status'] = Variable<String>(
        recipientWrapStatus.value,
      );
    }
    if (selfWrapStatus.present) {
      map['self_wrap_status'] = Variable<String>(selfWrapStatus.value);
    }
    if (recipientWrapEventId.present) {
      map['recipient_wrap_event_id'] = Variable<String>(
        recipientWrapEventId.value,
      );
    }
    if (selfWrapEventId.present) {
      map['self_wrap_event_id'] = Variable<String>(selfWrapEventId.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (recipientWrapLastError.present) {
      map['recipient_wrap_last_error'] = Variable<String>(
        recipientWrapLastError.value,
      );
    }
    if (selfWrapLastError.present) {
      map['self_wrap_last_error'] = Variable<String>(selfWrapLastError.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (sendBatchId.present) {
      map['send_batch_id'] = Variable<String>(sendBatchId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutgoingDmsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('recipientPubkey: $recipientPubkey, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('rumorEventJson: $rumorEventJson, ')
          ..write('messageKind: $messageKind, ')
          ..write('replyToId: $replyToId, ')
          ..write('recipientWrapStatus: $recipientWrapStatus, ')
          ..write('selfWrapStatus: $selfWrapStatus, ')
          ..write('recipientWrapEventId: $recipientWrapEventId, ')
          ..write('selfWrapEventId: $selfWrapEventId, ')
          ..write('retryCount: $retryCount, ')
          ..write('recipientWrapLastError: $recipientWrapLastError, ')
          ..write('selfWrapLastError: $selfWrapLastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('sendBatchId: $sendBatchId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingViewEventsTable extends PendingViewEvents
    with TableInfo<$PendingViewEventsTable, PendingViewEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingViewEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoPubkeyMeta = const VerificationMeta(
    'videoPubkey',
  );
  @override
  late final GeneratedColumn<String> videoPubkey = GeneratedColumn<String>(
    'video_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoVineIdMeta = const VerificationMeta(
    'videoVineId',
  );
  @override
  late final GeneratedColumn<String> videoVineId = GeneratedColumn<String>(
    'video_vine_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoAddressableDTagMeta =
      const VerificationMeta('videoAddressableDTag');
  @override
  late final GeneratedColumn<String> videoAddressableDTag =
      GeneratedColumn<String>(
        'video_addressable_d_tag',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _videoEventKindMeta = const VerificationMeta(
    'videoEventKind',
  );
  @override
  late final GeneratedColumn<int> videoEventKind = GeneratedColumn<int>(
    'video_event_kind',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userPubkeyMeta = const VerificationMeta(
    'userPubkey',
  );
  @override
  late final GeneratedColumn<String> userPubkey = GeneratedColumn<String>(
    'user_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _watchDurationMsMeta = const VerificationMeta(
    'watchDurationMs',
  );
  @override
  late final GeneratedColumn<int> watchDurationMs = GeneratedColumn<int>(
    'watch_duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalDurationMsMeta = const VerificationMeta(
    'totalDurationMs',
  );
  @override
  late final GeneratedColumn<int> totalDurationMs = GeneratedColumn<int>(
    'total_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loopCountMeta = const VerificationMeta(
    'loopCount',
  );
  @override
  late final GeneratedColumn<int> loopCount = GeneratedColumn<int>(
    'loop_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trafficSourceMeta = const VerificationMeta(
    'trafficSource',
  );
  @override
  late final GeneratedColumn<String> trafficSource = GeneratedColumn<String>(
    'traffic_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDetailMeta = const VerificationMeta(
    'sourceDetail',
  );
  @override
  late final GeneratedColumn<String> sourceDetail = GeneratedColumn<String>(
    'source_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    videoId,
    videoPubkey,
    videoVineId,
    videoAddressableDTag,
    videoEventKind,
    userPubkey,
    watchDurationMs,
    totalDurationMs,
    loopCount,
    phase,
    trafficSource,
    sourceDetail,
    status,
    retryCount,
    lastError,
    lastAttemptAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_view_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingViewEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('video_pubkey')) {
      context.handle(
        _videoPubkeyMeta,
        videoPubkey.isAcceptableOrUnknown(
          data['video_pubkey']!,
          _videoPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_videoPubkeyMeta);
    }
    if (data.containsKey('video_vine_id')) {
      context.handle(
        _videoVineIdMeta,
        videoVineId.isAcceptableOrUnknown(
          data['video_vine_id']!,
          _videoVineIdMeta,
        ),
      );
    }
    if (data.containsKey('video_addressable_d_tag')) {
      context.handle(
        _videoAddressableDTagMeta,
        videoAddressableDTag.isAcceptableOrUnknown(
          data['video_addressable_d_tag']!,
          _videoAddressableDTagMeta,
        ),
      );
    }
    if (data.containsKey('video_event_kind')) {
      context.handle(
        _videoEventKindMeta,
        videoEventKind.isAcceptableOrUnknown(
          data['video_event_kind']!,
          _videoEventKindMeta,
        ),
      );
    }
    if (data.containsKey('user_pubkey')) {
      context.handle(
        _userPubkeyMeta,
        userPubkey.isAcceptableOrUnknown(data['user_pubkey']!, _userPubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_userPubkeyMeta);
    }
    if (data.containsKey('watch_duration_ms')) {
      context.handle(
        _watchDurationMsMeta,
        watchDurationMs.isAcceptableOrUnknown(
          data['watch_duration_ms']!,
          _watchDurationMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_watchDurationMsMeta);
    }
    if (data.containsKey('total_duration_ms')) {
      context.handle(
        _totalDurationMsMeta,
        totalDurationMs.isAcceptableOrUnknown(
          data['total_duration_ms']!,
          _totalDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('loop_count')) {
      context.handle(
        _loopCountMeta,
        loopCount.isAcceptableOrUnknown(data['loop_count']!, _loopCountMeta),
      );
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    }
    if (data.containsKey('traffic_source')) {
      context.handle(
        _trafficSourceMeta,
        trafficSource.isAcceptableOrUnknown(
          data['traffic_source']!,
          _trafficSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trafficSourceMeta);
    }
    if (data.containsKey('source_detail')) {
      context.handle(
        _sourceDetailMeta,
        sourceDetail.isAcceptableOrUnknown(
          data['source_detail']!,
          _sourceDetailMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingViewEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingViewEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      videoPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_pubkey'],
      )!,
      videoVineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_vine_id'],
      ),
      videoAddressableDTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_addressable_d_tag'],
      ),
      videoEventKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_event_kind'],
      ),
      userPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_pubkey'],
      )!,
      watchDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watch_duration_ms'],
      )!,
      totalDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_duration_ms'],
      ),
      loopCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loop_count'],
      ),
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      ),
      trafficSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}traffic_source'],
      )!,
      sourceDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_detail'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingViewEventsTable createAlias(String alias) {
    return $PendingViewEventsTable(attachedDatabase, alias);
  }
}

class PendingViewEventRow extends DataClass
    implements Insertable<PendingViewEventRow> {
  final String id;
  final String videoId;
  final String videoPubkey;
  final String? videoVineId;

  /// The video's addressable `d` tag.
  ///
  /// A kind 22236 view event addresses its subject by `kind:pubkey:d-tag`, so
  /// a queued row without this can never be published. Schema v4 copies a
  /// distinct pre-existing `video_vine_id` into this column; later nulls stay
  /// null and the sweep discards them.
  final String? videoAddressableDTag;

  /// The original NIP-71 video event kind, when known.
  final int? videoEventKind;
  final String userPubkey;
  final int watchDurationMs;
  final int? totalDurationMs;
  final int? loopCount;

  /// Two-phase reporting phase: `start` or `end`.
  ///
  /// NULL marks a pre-phase queued row: a legacy end-of-session event that
  /// must replay WITHOUT a phase tag so the relay still counts its view.
  /// A `start` row carries no watch time; an `end` row contributes loops
  /// only — the relay counts the view on the matching `start` row.
  final String? phase;
  final String trafficSource;
  final String? sourceDetail;
  final String status;
  final int retryCount;
  final String? lastError;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;
  const PendingViewEventRow({
    required this.id,
    required this.videoId,
    required this.videoPubkey,
    this.videoVineId,
    this.videoAddressableDTag,
    this.videoEventKind,
    required this.userPubkey,
    required this.watchDurationMs,
    this.totalDurationMs,
    this.loopCount,
    this.phase,
    required this.trafficSource,
    this.sourceDetail,
    required this.status,
    required this.retryCount,
    this.lastError,
    this.lastAttemptAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['video_id'] = Variable<String>(videoId);
    map['video_pubkey'] = Variable<String>(videoPubkey);
    if (!nullToAbsent || videoVineId != null) {
      map['video_vine_id'] = Variable<String>(videoVineId);
    }
    if (!nullToAbsent || videoAddressableDTag != null) {
      map['video_addressable_d_tag'] = Variable<String>(videoAddressableDTag);
    }
    if (!nullToAbsent || videoEventKind != null) {
      map['video_event_kind'] = Variable<int>(videoEventKind);
    }
    map['user_pubkey'] = Variable<String>(userPubkey);
    map['watch_duration_ms'] = Variable<int>(watchDurationMs);
    if (!nullToAbsent || totalDurationMs != null) {
      map['total_duration_ms'] = Variable<int>(totalDurationMs);
    }
    if (!nullToAbsent || loopCount != null) {
      map['loop_count'] = Variable<int>(loopCount);
    }
    if (!nullToAbsent || phase != null) {
      map['phase'] = Variable<String>(phase);
    }
    map['traffic_source'] = Variable<String>(trafficSource);
    if (!nullToAbsent || sourceDetail != null) {
      map['source_detail'] = Variable<String>(sourceDetail);
    }
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingViewEventsCompanion toCompanion(bool nullToAbsent) {
    return PendingViewEventsCompanion(
      id: Value(id),
      videoId: Value(videoId),
      videoPubkey: Value(videoPubkey),
      videoVineId: videoVineId == null && nullToAbsent
          ? const Value.absent()
          : Value(videoVineId),
      videoAddressableDTag: videoAddressableDTag == null && nullToAbsent
          ? const Value.absent()
          : Value(videoAddressableDTag),
      videoEventKind: videoEventKind == null && nullToAbsent
          ? const Value.absent()
          : Value(videoEventKind),
      userPubkey: Value(userPubkey),
      watchDurationMs: Value(watchDurationMs),
      totalDurationMs: totalDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(totalDurationMs),
      loopCount: loopCount == null && nullToAbsent
          ? const Value.absent()
          : Value(loopCount),
      phase: phase == null && nullToAbsent
          ? const Value.absent()
          : Value(phase),
      trafficSource: Value(trafficSource),
      sourceDetail: sourceDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceDetail),
      status: Value(status),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      createdAt: Value(createdAt),
    );
  }

  factory PendingViewEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingViewEventRow(
      id: serializer.fromJson<String>(json['id']),
      videoId: serializer.fromJson<String>(json['videoId']),
      videoPubkey: serializer.fromJson<String>(json['videoPubkey']),
      videoVineId: serializer.fromJson<String?>(json['videoVineId']),
      videoAddressableDTag: serializer.fromJson<String?>(
        json['videoAddressableDTag'],
      ),
      videoEventKind: serializer.fromJson<int?>(json['videoEventKind']),
      userPubkey: serializer.fromJson<String>(json['userPubkey']),
      watchDurationMs: serializer.fromJson<int>(json['watchDurationMs']),
      totalDurationMs: serializer.fromJson<int?>(json['totalDurationMs']),
      loopCount: serializer.fromJson<int?>(json['loopCount']),
      phase: serializer.fromJson<String?>(json['phase']),
      trafficSource: serializer.fromJson<String>(json['trafficSource']),
      sourceDetail: serializer.fromJson<String?>(json['sourceDetail']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'videoId': serializer.toJson<String>(videoId),
      'videoPubkey': serializer.toJson<String>(videoPubkey),
      'videoVineId': serializer.toJson<String?>(videoVineId),
      'videoAddressableDTag': serializer.toJson<String?>(videoAddressableDTag),
      'videoEventKind': serializer.toJson<int?>(videoEventKind),
      'userPubkey': serializer.toJson<String>(userPubkey),
      'watchDurationMs': serializer.toJson<int>(watchDurationMs),
      'totalDurationMs': serializer.toJson<int?>(totalDurationMs),
      'loopCount': serializer.toJson<int?>(loopCount),
      'phase': serializer.toJson<String?>(phase),
      'trafficSource': serializer.toJson<String>(trafficSource),
      'sourceDetail': serializer.toJson<String?>(sourceDetail),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingViewEventRow copyWith({
    String? id,
    String? videoId,
    String? videoPubkey,
    Value<String?> videoVineId = const Value.absent(),
    Value<String?> videoAddressableDTag = const Value.absent(),
    Value<int?> videoEventKind = const Value.absent(),
    String? userPubkey,
    int? watchDurationMs,
    Value<int?> totalDurationMs = const Value.absent(),
    Value<int?> loopCount = const Value.absent(),
    Value<String?> phase = const Value.absent(),
    String? trafficSource,
    Value<String?> sourceDetail = const Value.absent(),
    String? status,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    DateTime? createdAt,
  }) => PendingViewEventRow(
    id: id ?? this.id,
    videoId: videoId ?? this.videoId,
    videoPubkey: videoPubkey ?? this.videoPubkey,
    videoVineId: videoVineId.present ? videoVineId.value : this.videoVineId,
    videoAddressableDTag: videoAddressableDTag.present
        ? videoAddressableDTag.value
        : this.videoAddressableDTag,
    videoEventKind: videoEventKind.present
        ? videoEventKind.value
        : this.videoEventKind,
    userPubkey: userPubkey ?? this.userPubkey,
    watchDurationMs: watchDurationMs ?? this.watchDurationMs,
    totalDurationMs: totalDurationMs.present
        ? totalDurationMs.value
        : this.totalDurationMs,
    loopCount: loopCount.present ? loopCount.value : this.loopCount,
    phase: phase.present ? phase.value : this.phase,
    trafficSource: trafficSource ?? this.trafficSource,
    sourceDetail: sourceDetail.present ? sourceDetail.value : this.sourceDetail,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingViewEventRow copyWithCompanion(PendingViewEventsCompanion data) {
    return PendingViewEventRow(
      id: data.id.present ? data.id.value : this.id,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      videoPubkey: data.videoPubkey.present
          ? data.videoPubkey.value
          : this.videoPubkey,
      videoVineId: data.videoVineId.present
          ? data.videoVineId.value
          : this.videoVineId,
      videoAddressableDTag: data.videoAddressableDTag.present
          ? data.videoAddressableDTag.value
          : this.videoAddressableDTag,
      videoEventKind: data.videoEventKind.present
          ? data.videoEventKind.value
          : this.videoEventKind,
      userPubkey: data.userPubkey.present
          ? data.userPubkey.value
          : this.userPubkey,
      watchDurationMs: data.watchDurationMs.present
          ? data.watchDurationMs.value
          : this.watchDurationMs,
      totalDurationMs: data.totalDurationMs.present
          ? data.totalDurationMs.value
          : this.totalDurationMs,
      loopCount: data.loopCount.present ? data.loopCount.value : this.loopCount,
      phase: data.phase.present ? data.phase.value : this.phase,
      trafficSource: data.trafficSource.present
          ? data.trafficSource.value
          : this.trafficSource,
      sourceDetail: data.sourceDetail.present
          ? data.sourceDetail.value
          : this.sourceDetail,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingViewEventRow(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('videoPubkey: $videoPubkey, ')
          ..write('videoVineId: $videoVineId, ')
          ..write('videoAddressableDTag: $videoAddressableDTag, ')
          ..write('videoEventKind: $videoEventKind, ')
          ..write('userPubkey: $userPubkey, ')
          ..write('watchDurationMs: $watchDurationMs, ')
          ..write('totalDurationMs: $totalDurationMs, ')
          ..write('loopCount: $loopCount, ')
          ..write('phase: $phase, ')
          ..write('trafficSource: $trafficSource, ')
          ..write('sourceDetail: $sourceDetail, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    videoId,
    videoPubkey,
    videoVineId,
    videoAddressableDTag,
    videoEventKind,
    userPubkey,
    watchDurationMs,
    totalDurationMs,
    loopCount,
    phase,
    trafficSource,
    sourceDetail,
    status,
    retryCount,
    lastError,
    lastAttemptAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingViewEventRow &&
          other.id == this.id &&
          other.videoId == this.videoId &&
          other.videoPubkey == this.videoPubkey &&
          other.videoVineId == this.videoVineId &&
          other.videoAddressableDTag == this.videoAddressableDTag &&
          other.videoEventKind == this.videoEventKind &&
          other.userPubkey == this.userPubkey &&
          other.watchDurationMs == this.watchDurationMs &&
          other.totalDurationMs == this.totalDurationMs &&
          other.loopCount == this.loopCount &&
          other.phase == this.phase &&
          other.trafficSource == this.trafficSource &&
          other.sourceDetail == this.sourceDetail &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.createdAt == this.createdAt);
}

class PendingViewEventsCompanion extends UpdateCompanion<PendingViewEventRow> {
  final Value<String> id;
  final Value<String> videoId;
  final Value<String> videoPubkey;
  final Value<String?> videoVineId;
  final Value<String?> videoAddressableDTag;
  final Value<int?> videoEventKind;
  final Value<String> userPubkey;
  final Value<int> watchDurationMs;
  final Value<int?> totalDurationMs;
  final Value<int?> loopCount;
  final Value<String?> phase;
  final Value<String> trafficSource;
  final Value<String?> sourceDetail;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingViewEventsCompanion({
    this.id = const Value.absent(),
    this.videoId = const Value.absent(),
    this.videoPubkey = const Value.absent(),
    this.videoVineId = const Value.absent(),
    this.videoAddressableDTag = const Value.absent(),
    this.videoEventKind = const Value.absent(),
    this.userPubkey = const Value.absent(),
    this.watchDurationMs = const Value.absent(),
    this.totalDurationMs = const Value.absent(),
    this.loopCount = const Value.absent(),
    this.phase = const Value.absent(),
    this.trafficSource = const Value.absent(),
    this.sourceDetail = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingViewEventsCompanion.insert({
    required String id,
    required String videoId,
    required String videoPubkey,
    this.videoVineId = const Value.absent(),
    this.videoAddressableDTag = const Value.absent(),
    this.videoEventKind = const Value.absent(),
    required String userPubkey,
    required int watchDurationMs,
    this.totalDurationMs = const Value.absent(),
    this.loopCount = const Value.absent(),
    this.phase = const Value.absent(),
    required String trafficSource,
    this.sourceDetail = const Value.absent(),
    required String status,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       videoId = Value(videoId),
       videoPubkey = Value(videoPubkey),
       userPubkey = Value(userPubkey),
       watchDurationMs = Value(watchDurationMs),
       trafficSource = Value(trafficSource),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<PendingViewEventRow> custom({
    Expression<String>? id,
    Expression<String>? videoId,
    Expression<String>? videoPubkey,
    Expression<String>? videoVineId,
    Expression<String>? videoAddressableDTag,
    Expression<int>? videoEventKind,
    Expression<String>? userPubkey,
    Expression<int>? watchDurationMs,
    Expression<int>? totalDurationMs,
    Expression<int>? loopCount,
    Expression<String>? phase,
    Expression<String>? trafficSource,
    Expression<String>? sourceDetail,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (videoId != null) 'video_id': videoId,
      if (videoPubkey != null) 'video_pubkey': videoPubkey,
      if (videoVineId != null) 'video_vine_id': videoVineId,
      if (videoAddressableDTag != null)
        'video_addressable_d_tag': videoAddressableDTag,
      if (videoEventKind != null) 'video_event_kind': videoEventKind,
      if (userPubkey != null) 'user_pubkey': userPubkey,
      if (watchDurationMs != null) 'watch_duration_ms': watchDurationMs,
      if (totalDurationMs != null) 'total_duration_ms': totalDurationMs,
      if (loopCount != null) 'loop_count': loopCount,
      if (phase != null) 'phase': phase,
      if (trafficSource != null) 'traffic_source': trafficSource,
      if (sourceDetail != null) 'source_detail': sourceDetail,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingViewEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? videoId,
    Value<String>? videoPubkey,
    Value<String?>? videoVineId,
    Value<String?>? videoAddressableDTag,
    Value<int?>? videoEventKind,
    Value<String>? userPubkey,
    Value<int>? watchDurationMs,
    Value<int?>? totalDurationMs,
    Value<int?>? loopCount,
    Value<String?>? phase,
    Value<String>? trafficSource,
    Value<String?>? sourceDetail,
    Value<String>? status,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingViewEventsCompanion(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      videoPubkey: videoPubkey ?? this.videoPubkey,
      videoVineId: videoVineId ?? this.videoVineId,
      videoAddressableDTag: videoAddressableDTag ?? this.videoAddressableDTag,
      videoEventKind: videoEventKind ?? this.videoEventKind,
      userPubkey: userPubkey ?? this.userPubkey,
      watchDurationMs: watchDurationMs ?? this.watchDurationMs,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      loopCount: loopCount ?? this.loopCount,
      phase: phase ?? this.phase,
      trafficSource: trafficSource ?? this.trafficSource,
      sourceDetail: sourceDetail ?? this.sourceDetail,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (videoPubkey.present) {
      map['video_pubkey'] = Variable<String>(videoPubkey.value);
    }
    if (videoVineId.present) {
      map['video_vine_id'] = Variable<String>(videoVineId.value);
    }
    if (videoAddressableDTag.present) {
      map['video_addressable_d_tag'] = Variable<String>(
        videoAddressableDTag.value,
      );
    }
    if (videoEventKind.present) {
      map['video_event_kind'] = Variable<int>(videoEventKind.value);
    }
    if (userPubkey.present) {
      map['user_pubkey'] = Variable<String>(userPubkey.value);
    }
    if (watchDurationMs.present) {
      map['watch_duration_ms'] = Variable<int>(watchDurationMs.value);
    }
    if (totalDurationMs.present) {
      map['total_duration_ms'] = Variable<int>(totalDurationMs.value);
    }
    if (loopCount.present) {
      map['loop_count'] = Variable<int>(loopCount.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (trafficSource.present) {
      map['traffic_source'] = Variable<String>(trafficSource.value);
    }
    if (sourceDetail.present) {
      map['source_detail'] = Variable<String>(sourceDetail.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingViewEventsCompanion(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('videoPubkey: $videoPubkey, ')
          ..write('videoVineId: $videoVineId, ')
          ..write('videoAddressableDTag: $videoAddressableDTag, ')
          ..write('videoEventKind: $videoEventKind, ')
          ..write('userPubkey: $userPubkey, ')
          ..write('watchDurationMs: $watchDurationMs, ')
          ..write('totalDurationMs: $totalDurationMs, ')
          ..write('loopCount: $loopCount, ')
          ..write('phase: $phase, ')
          ..write('trafficSource: $trafficSource, ')
          ..write('sourceDetail: $sourceDetail, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingProductEventsTable extends PendingProductEvents
    with TableInfo<$PendingProductEventsTable, PendingProductEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingProductEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventNameMeta = const VerificationMeta(
    'eventName',
  );
  @override
  late final GeneratedColumn<String> eventName = GeneratedColumn<String>(
    'event_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventName,
    payloadJson,
    status,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    ownerPubkey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_product_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingProductEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_name')) {
      context.handle(
        _eventNameMeta,
        eventName.isAcceptableOrUnknown(data['event_name']!, _eventNameMeta),
      );
    } else if (isInserting) {
      context.missing(_eventNameMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingProductEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingProductEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_name'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      ),
    );
  }

  @override
  $PendingProductEventsTable createAlias(String alias) {
    return $PendingProductEventsTable(attachedDatabase, alias);
  }
}

class PendingProductEventRow extends DataClass
    implements Insertable<PendingProductEventRow> {
  final String id;
  final String eventName;
  final String payloadJson;
  final String status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;

  /// Hex pubkey of the account that produced this event.
  ///
  /// The flush signs the batch with the *current* account's NIP-98 token, so
  /// events are filtered to the current owner at flush time — otherwise a
  /// logout/login as a different account would publish the prior account's
  /// queued events under the new account's signature. NULL for legacy rows
  /// enqueued before this column existed; those flush under whoever is active.
  final String? ownerPubkey;
  const PendingProductEventRow({
    required this.id,
    required this.eventName,
    required this.payloadJson,
    required this.status,
    required this.attemptCount,
    this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
    this.ownerPubkey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_name'] = Variable<String>(eventName);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || ownerPubkey != null) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey);
    }
    return map;
  }

  PendingProductEventsCompanion toCompanion(bool nullToAbsent) {
    return PendingProductEventsCompanion(
      id: Value(id),
      eventName: Value(eventName),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attemptCount: Value(attemptCount),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      ownerPubkey: ownerPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerPubkey),
    );
  }

  factory PendingProductEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingProductEventRow(
      id: serializer.fromJson<String>(json['id']),
      eventName: serializer.fromJson<String>(json['eventName']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      ownerPubkey: serializer.fromJson<String?>(json['ownerPubkey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventName': serializer.toJson<String>(eventName),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'ownerPubkey': serializer.toJson<String?>(ownerPubkey),
    };
  }

  PendingProductEventRow copyWith({
    String? id,
    String? eventName,
    String? payloadJson,
    String? status,
    int? attemptCount,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    Value<String?> ownerPubkey = const Value.absent(),
  }) => PendingProductEventRow(
    id: id ?? this.id,
    eventName: eventName ?? this.eventName,
    payloadJson: payloadJson ?? this.payloadJson,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    ownerPubkey: ownerPubkey.present ? ownerPubkey.value : this.ownerPubkey,
  );
  PendingProductEventRow copyWithCompanion(PendingProductEventsCompanion data) {
    return PendingProductEventRow(
      id: data.id.present ? data.id.value : this.id,
      eventName: data.eventName.present ? data.eventName.value : this.eventName,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingProductEventRow(')
          ..write('id: $id, ')
          ..write('eventName: $eventName, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('ownerPubkey: $ownerPubkey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventName,
    payloadJson,
    status,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    ownerPubkey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingProductEventRow &&
          other.id == this.id &&
          other.eventName == this.eventName &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.ownerPubkey == this.ownerPubkey);
}

class PendingProductEventsCompanion
    extends UpdateCompanion<PendingProductEventRow> {
  final Value<String> id;
  final Value<String> eventName;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<String?> ownerPubkey;
  final Value<int> rowid;
  const PendingProductEventsCompanion({
    this.id = const Value.absent(),
    this.eventName = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingProductEventsCompanion.insert({
    required String id,
    required String eventName,
    required String payloadJson,
    required String status,
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventName = Value(eventName),
       payloadJson = Value(payloadJson),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<PendingProductEventRow> custom({
    Expression<String>? id,
    Expression<String>? eventName,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<String>? ownerPubkey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventName != null) 'event_name': eventName,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingProductEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventName,
    Value<String>? payloadJson,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<String?>? ownerPubkey,
    Value<int>? rowid,
  }) {
    return PendingProductEventsCompanion(
      id: id ?? this.id,
      eventName: eventName ?? this.eventName,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventName.present) {
      map['event_name'] = Variable<String>(eventName.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingProductEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventName: $eventName, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingGiftWrapsTable extends PendingGiftWraps
    with TableInfo<$PendingGiftWrapsTable, PendingGiftWrapRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingGiftWrapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _giftWrapIdMeta = const VerificationMeta(
    'giftWrapId',
  );
  @override
  late final GeneratedColumn<String> giftWrapId = GeneratedColumn<String>(
    'gift_wrap_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<int> lastAttemptAt = GeneratedColumn<int>(
    'last_attempt_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    giftWrapId,
    ownerPubkey,
    rawJson,
    createdAt,
    attempts,
    lastAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_gift_wraps';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingGiftWrapRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gift_wrap_id')) {
      context.handle(
        _giftWrapIdMeta,
        giftWrapId.isAcceptableOrUnknown(
          data['gift_wrap_id']!,
          _giftWrapIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_giftWrapIdMeta);
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerPubkeyMeta);
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {giftWrapId, ownerPubkey};
  @override
  PendingGiftWrapRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingGiftWrapRow(
      giftWrapId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gift_wrap_id'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_attempt_at'],
      ),
    );
  }

  @override
  $PendingGiftWrapsTable createAlias(String alias) {
    return $PendingGiftWrapsTable(attachedDatabase, alias);
  }
}

class PendingGiftWrapRow extends DataClass
    implements Insertable<PendingGiftWrapRow> {
  /// The kind 1059 gift-wrap event id (outer). Dedup key with [ownerPubkey].
  final String giftWrapId;

  /// Recipient pubkey this wrap was addressed to (multi-account scope).
  final String ownerPubkey;

  /// The raw gift-wrap event JSON, replayed through the decrypt pipeline.
  final String rawJson;

  /// Outer gift-wrap `created_at` (unix seconds). Ordering only — NIP-17
  /// randomizes it, so it is not the true message time.
  final int createdAt;

  /// Number of decryption attempts so far. Retries stop at a cap so a
  /// permanently-undecryptable wrap cannot loop forever.
  final int attempts;

  /// Last attempt time (unix seconds), informational.
  final int? lastAttemptAt;
  const PendingGiftWrapRow({
    required this.giftWrapId,
    required this.ownerPubkey,
    required this.rawJson,
    required this.createdAt,
    required this.attempts,
    this.lastAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gift_wrap_id'] = Variable<String>(giftWrapId);
    map['owner_pubkey'] = Variable<String>(ownerPubkey);
    map['raw_json'] = Variable<String>(rawJson);
    map['created_at'] = Variable<int>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<int>(lastAttemptAt);
    }
    return map;
  }

  PendingGiftWrapsCompanion toCompanion(bool nullToAbsent) {
    return PendingGiftWrapsCompanion(
      giftWrapId: Value(giftWrapId),
      ownerPubkey: Value(ownerPubkey),
      rawJson: Value(rawJson),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory PendingGiftWrapRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingGiftWrapRow(
      giftWrapId: serializer.fromJson<String>(json['giftWrapId']),
      ownerPubkey: serializer.fromJson<String>(json['ownerPubkey']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttemptAt: serializer.fromJson<int?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'giftWrapId': serializer.toJson<String>(giftWrapId),
      'ownerPubkey': serializer.toJson<String>(ownerPubkey),
      'rawJson': serializer.toJson<String>(rawJson),
      'createdAt': serializer.toJson<int>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttemptAt': serializer.toJson<int?>(lastAttemptAt),
    };
  }

  PendingGiftWrapRow copyWith({
    String? giftWrapId,
    String? ownerPubkey,
    String? rawJson,
    int? createdAt,
    int? attempts,
    Value<int?> lastAttemptAt = const Value.absent(),
  }) => PendingGiftWrapRow(
    giftWrapId: giftWrapId ?? this.giftWrapId,
    ownerPubkey: ownerPubkey ?? this.ownerPubkey,
    rawJson: rawJson ?? this.rawJson,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
  );
  PendingGiftWrapRow copyWithCompanion(PendingGiftWrapsCompanion data) {
    return PendingGiftWrapRow(
      giftWrapId: data.giftWrapId.present
          ? data.giftWrapId.value
          : this.giftWrapId,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingGiftWrapRow(')
          ..write('giftWrapId: $giftWrapId, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    giftWrapId,
    ownerPubkey,
    rawJson,
    createdAt,
    attempts,
    lastAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingGiftWrapRow &&
          other.giftWrapId == this.giftWrapId &&
          other.ownerPubkey == this.ownerPubkey &&
          other.rawJson == this.rawJson &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class PendingGiftWrapsCompanion extends UpdateCompanion<PendingGiftWrapRow> {
  final Value<String> giftWrapId;
  final Value<String> ownerPubkey;
  final Value<String> rawJson;
  final Value<int> createdAt;
  final Value<int> attempts;
  final Value<int?> lastAttemptAt;
  final Value<int> rowid;
  const PendingGiftWrapsCompanion({
    this.giftWrapId = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingGiftWrapsCompanion.insert({
    required String giftWrapId,
    required String ownerPubkey,
    required String rawJson,
    required int createdAt,
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : giftWrapId = Value(giftWrapId),
       ownerPubkey = Value(ownerPubkey),
       rawJson = Value(rawJson),
       createdAt = Value(createdAt);
  static Insertable<PendingGiftWrapRow> custom({
    Expression<String>? giftWrapId,
    Expression<String>? ownerPubkey,
    Expression<String>? rawJson,
    Expression<int>? createdAt,
    Expression<int>? attempts,
    Expression<int>? lastAttemptAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (giftWrapId != null) 'gift_wrap_id': giftWrapId,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (rawJson != null) 'raw_json': rawJson,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingGiftWrapsCompanion copyWith({
    Value<String>? giftWrapId,
    Value<String>? ownerPubkey,
    Value<String>? rawJson,
    Value<int>? createdAt,
    Value<int>? attempts,
    Value<int?>? lastAttemptAt,
    Value<int>? rowid,
  }) {
    return PendingGiftWrapsCompanion(
      giftWrapId: giftWrapId ?? this.giftWrapId,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      rawJson: rawJson ?? this.rawJson,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (giftWrapId.present) {
      map['gift_wrap_id'] = Variable<String>(giftWrapId.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<int>(lastAttemptAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingGiftWrapsCompanion(')
          ..write('giftWrapId: $giftWrapId, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProcessedGiftWrapsTable extends ProcessedGiftWraps
    with TableInfo<$ProcessedGiftWrapsTable, ProcessedGiftWrap> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessedGiftWrapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _giftWrapIdMeta = const VerificationMeta(
    'giftWrapId',
  );
  @override
  late final GeneratedColumn<String> giftWrapId = GeneratedColumn<String>(
    'gift_wrap_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<int> processedAt = GeneratedColumn<int>(
    'processed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [giftWrapId, processedAt, ownerPubkey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processed_gift_wraps';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProcessedGiftWrap> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gift_wrap_id')) {
      context.handle(
        _giftWrapIdMeta,
        giftWrapId.isAcceptableOrUnknown(
          data['gift_wrap_id']!,
          _giftWrapIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_giftWrapIdMeta);
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_processedAtMeta);
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {giftWrapId};
  @override
  ProcessedGiftWrap map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessedGiftWrap(
      giftWrapId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gift_wrap_id'],
      )!,
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}processed_at'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      ),
    );
  }

  @override
  $ProcessedGiftWrapsTable createAlias(String alias) {
    return $ProcessedGiftWrapsTable(attachedDatabase, alias);
  }
}

class ProcessedGiftWrap extends DataClass
    implements Insertable<ProcessedGiftWrap> {
  /// The kind 1059 gift-wrap event id (outer). Dedup key.
  ///
  /// Intentionally NOT scoped by owner: gift-wrap event ids are globally unique
  /// per the Nostr protocol, so cross-account dedup prevents re-processing the
  /// same relay event for multiple local accounts — matching
  /// [DirectMessages.giftWrapId] dedup semantics.
  final String giftWrapId;

  /// When the wrap was terminally processed (unix seconds). Informational and
  /// available for any future time-based retention.
  final int processedAt;

  /// Recipient pubkey this wrap was processed for. Not part of the global
  /// gift-wrap dedup key, but used to scope account cleanup without deleting
  /// another saved account's ledger entries.
  final String? ownerPubkey;
  const ProcessedGiftWrap({
    required this.giftWrapId,
    required this.processedAt,
    this.ownerPubkey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gift_wrap_id'] = Variable<String>(giftWrapId);
    map['processed_at'] = Variable<int>(processedAt);
    if (!nullToAbsent || ownerPubkey != null) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey);
    }
    return map;
  }

  ProcessedGiftWrapsCompanion toCompanion(bool nullToAbsent) {
    return ProcessedGiftWrapsCompanion(
      giftWrapId: Value(giftWrapId),
      processedAt: Value(processedAt),
      ownerPubkey: ownerPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerPubkey),
    );
  }

  factory ProcessedGiftWrap.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessedGiftWrap(
      giftWrapId: serializer.fromJson<String>(json['giftWrapId']),
      processedAt: serializer.fromJson<int>(json['processedAt']),
      ownerPubkey: serializer.fromJson<String?>(json['ownerPubkey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'giftWrapId': serializer.toJson<String>(giftWrapId),
      'processedAt': serializer.toJson<int>(processedAt),
      'ownerPubkey': serializer.toJson<String?>(ownerPubkey),
    };
  }

  ProcessedGiftWrap copyWith({
    String? giftWrapId,
    int? processedAt,
    Value<String?> ownerPubkey = const Value.absent(),
  }) => ProcessedGiftWrap(
    giftWrapId: giftWrapId ?? this.giftWrapId,
    processedAt: processedAt ?? this.processedAt,
    ownerPubkey: ownerPubkey.present ? ownerPubkey.value : this.ownerPubkey,
  );
  ProcessedGiftWrap copyWithCompanion(ProcessedGiftWrapsCompanion data) {
    return ProcessedGiftWrap(
      giftWrapId: data.giftWrapId.present
          ? data.giftWrapId.value
          : this.giftWrapId,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessedGiftWrap(')
          ..write('giftWrapId: $giftWrapId, ')
          ..write('processedAt: $processedAt, ')
          ..write('ownerPubkey: $ownerPubkey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(giftWrapId, processedAt, ownerPubkey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessedGiftWrap &&
          other.giftWrapId == this.giftWrapId &&
          other.processedAt == this.processedAt &&
          other.ownerPubkey == this.ownerPubkey);
}

class ProcessedGiftWrapsCompanion extends UpdateCompanion<ProcessedGiftWrap> {
  final Value<String> giftWrapId;
  final Value<int> processedAt;
  final Value<String?> ownerPubkey;
  final Value<int> rowid;
  const ProcessedGiftWrapsCompanion({
    this.giftWrapId = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProcessedGiftWrapsCompanion.insert({
    required String giftWrapId,
    required int processedAt,
    this.ownerPubkey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : giftWrapId = Value(giftWrapId),
       processedAt = Value(processedAt);
  static Insertable<ProcessedGiftWrap> custom({
    Expression<String>? giftWrapId,
    Expression<int>? processedAt,
    Expression<String>? ownerPubkey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (giftWrapId != null) 'gift_wrap_id': giftWrapId,
      if (processedAt != null) 'processed_at': processedAt,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProcessedGiftWrapsCompanion copyWith({
    Value<String>? giftWrapId,
    Value<int>? processedAt,
    Value<String?>? ownerPubkey,
    Value<int>? rowid,
  }) {
    return ProcessedGiftWrapsCompanion(
      giftWrapId: giftWrapId ?? this.giftWrapId,
      processedAt: processedAt ?? this.processedAt,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (giftWrapId.present) {
      map['gift_wrap_id'] = Variable<String>(giftWrapId.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<int>(processedAt.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessedGiftWrapsCompanion(')
          ..write('giftWrapId: $giftWrapId, ')
          ..write('processedAt: $processedAt, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemovedConversationsTable extends RemovedConversations
    with TableInfo<$RemovedConversationsTable, RemovedConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemovedConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerPubkeyMeta = const VerificationMeta(
    'ownerPubkey',
  );
  @override
  late final GeneratedColumn<String> ownerPubkey = GeneratedColumn<String>(
    'owner_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _removedAtMeta = const VerificationMeta(
    'removedAt',
  );
  @override
  late final GeneratedColumn<int> removedAt = GeneratedColumn<int>(
    'removed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    ownerPubkey,
    removedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'removed_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemovedConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('owner_pubkey')) {
      context.handle(
        _ownerPubkeyMeta,
        ownerPubkey.isAcceptableOrUnknown(
          data['owner_pubkey']!,
          _ownerPubkeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerPubkeyMeta);
    }
    if (data.containsKey('removed_at')) {
      context.handle(
        _removedAtMeta,
        removedAt.isAcceptableOrUnknown(data['removed_at']!, _removedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_removedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, ownerPubkey};
  @override
  RemovedConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemovedConversation(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      ownerPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_pubkey'],
      )!,
      removedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}removed_at'],
      )!,
    );
  }

  @override
  $RemovedConversationsTable createAlias(String alias) {
    return $RemovedConversationsTable(attachedDatabase, alias);
  }
}

class RemovedConversation extends DataClass
    implements Insertable<RemovedConversation> {
  final String conversationId;
  final String ownerPubkey;

  /// Unix timestamp when the user removed the conversation.
  final int removedAt;
  const RemovedConversation({
    required this.conversationId,
    required this.ownerPubkey,
    required this.removedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['owner_pubkey'] = Variable<String>(ownerPubkey);
    map['removed_at'] = Variable<int>(removedAt);
    return map;
  }

  RemovedConversationsCompanion toCompanion(bool nullToAbsent) {
    return RemovedConversationsCompanion(
      conversationId: Value(conversationId),
      ownerPubkey: Value(ownerPubkey),
      removedAt: Value(removedAt),
    );
  }

  factory RemovedConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemovedConversation(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      ownerPubkey: serializer.fromJson<String>(json['ownerPubkey']),
      removedAt: serializer.fromJson<int>(json['removedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'ownerPubkey': serializer.toJson<String>(ownerPubkey),
      'removedAt': serializer.toJson<int>(removedAt),
    };
  }

  RemovedConversation copyWith({
    String? conversationId,
    String? ownerPubkey,
    int? removedAt,
  }) => RemovedConversation(
    conversationId: conversationId ?? this.conversationId,
    ownerPubkey: ownerPubkey ?? this.ownerPubkey,
    removedAt: removedAt ?? this.removedAt,
  );
  RemovedConversation copyWithCompanion(RemovedConversationsCompanion data) {
    return RemovedConversation(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      ownerPubkey: data.ownerPubkey.present
          ? data.ownerPubkey.value
          : this.ownerPubkey,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemovedConversation(')
          ..write('conversationId: $conversationId, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('removedAt: $removedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(conversationId, ownerPubkey, removedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemovedConversation &&
          other.conversationId == this.conversationId &&
          other.ownerPubkey == this.ownerPubkey &&
          other.removedAt == this.removedAt);
}

class RemovedConversationsCompanion
    extends UpdateCompanion<RemovedConversation> {
  final Value<String> conversationId;
  final Value<String> ownerPubkey;
  final Value<int> removedAt;
  final Value<int> rowid;
  const RemovedConversationsCompanion({
    this.conversationId = const Value.absent(),
    this.ownerPubkey = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemovedConversationsCompanion.insert({
    required String conversationId,
    required String ownerPubkey,
    required int removedAt,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       ownerPubkey = Value(ownerPubkey),
       removedAt = Value(removedAt);
  static Insertable<RemovedConversation> custom({
    Expression<String>? conversationId,
    Expression<String>? ownerPubkey,
    Expression<int>? removedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (ownerPubkey != null) 'owner_pubkey': ownerPubkey,
      if (removedAt != null) 'removed_at': removedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemovedConversationsCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? ownerPubkey,
    Value<int>? removedAt,
    Value<int>? rowid,
  }) {
    return RemovedConversationsCompanion(
      conversationId: conversationId ?? this.conversationId,
      ownerPubkey: ownerPubkey ?? this.ownerPubkey,
      removedAt: removedAt ?? this.removedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (ownerPubkey.present) {
      map['owner_pubkey'] = Variable<String>(ownerPubkey.value);
    }
    if (removedAt.present) {
      map['removed_at'] = Variable<int>(removedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemovedConversationsCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('ownerPubkey: $ownerPubkey, ')
          ..write('removedAt: $removedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingProfileSavesTable extends PendingProfileSaves
    with TableInfo<$PendingProfileSavesTable, PendingProfileSaveRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingProfileSavesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userPubkeyMeta = const VerificationMeta(
    'userPubkey',
  );
  @override
  late final GeneratedColumn<String> userPubkey = GeneratedColumn<String>(
    'user_pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimConfirmedMeta = const VerificationMeta(
    'claimConfirmed',
  );
  @override
  late final GeneratedColumn<bool> claimConfirmed = GeneratedColumn<bool>(
    'claim_confirmed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("claim_confirmed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<String> generation = GeneratedColumn<String>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    userPubkey,
    payloadJson,
    claimConfirmed,
    status,
    retryCount,
    lastAttemptAt,
    queuedAt,
    lastError,
    generation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_profile_saves';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingProfileSaveRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_pubkey')) {
      context.handle(
        _userPubkeyMeta,
        userPubkey.isAcceptableOrUnknown(data['user_pubkey']!, _userPubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_userPubkeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('claim_confirmed')) {
      context.handle(
        _claimConfirmedMeta,
        claimConfirmed.isAcceptableOrUnknown(
          data['claim_confirmed']!,
          _claimConfirmedMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userPubkey};
  @override
  PendingProfileSaveRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingProfileSaveRow(
      userPubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_pubkey'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      claimConfirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}claim_confirmed'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation'],
      )!,
    );
  }

  @override
  $PendingProfileSavesTable createAlias(String alias) {
    return $PendingProfileSavesTable(attachedDatabase, alias);
  }
}

class PendingProfileSaveRow extends DataClass
    implements Insertable<PendingProfileSaveRow> {
  /// Owner hex pubkey. Primary key → exactly one pending save per account.
  final String userPubkey;

  /// Serialized `PendingProfileSave` payload (every `saveProfileEvent` field
  /// the user submitted). Authoritative source for the re-drive.
  final String payloadJson;

  /// Whether the divine.video username claim already returned 200 for this
  /// payload, so re-drives skip the (idempotent) HTTP claim round-trip.
  /// Always `true` for saves with no divine.video username to claim
  /// (external NIP-05, or no NIP-05 change).
  final bool claimConfirmed;

  /// `pending` | `syncing` | `failed`. Stored as a string for readable
  /// dumps; the DAO throws on an unrecognised value rather than coercing it
  /// back to `pending`.
  final String status;

  /// Publish attempts survived. Backoff caps growth at the policy max; once
  /// exhausted the row moves to `failed` and the UI surfaces a retry.
  final int retryCount;

  /// Wall-clock timestamp of the most recent publish attempt. Drives the
  /// retry service's backoff scheduling. Null until the first attempt.
  final DateTime? lastAttemptAt;

  /// Wall-clock timestamp the row was queued.
  final DateTime queuedAt;

  /// Last publish error message, for diagnostics. Null when the most recent
  /// transition was not a failure.
  final String? lastError;

  /// Immutable per-enqueue token stamped fresh on every `upsert` (a new save
  /// or a manual retry). A background re-drive captures it at read time and
  /// guards every mutation with it, so a newer save that replaces this row
  /// while an older drive is awaiting relay work is never cleared or
  /// reclassified by that stale drive — latest intent wins (#3161 review).
  /// Empty string only on legacy rows written before this column existed.
  final String generation;
  const PendingProfileSaveRow({
    required this.userPubkey,
    required this.payloadJson,
    required this.claimConfirmed,
    required this.status,
    required this.retryCount,
    this.lastAttemptAt,
    required this.queuedAt,
    this.lastError,
    required this.generation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_pubkey'] = Variable<String>(userPubkey);
    map['payload_json'] = Variable<String>(payloadJson);
    map['claim_confirmed'] = Variable<bool>(claimConfirmed);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['queued_at'] = Variable<DateTime>(queuedAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['generation'] = Variable<String>(generation);
    return map;
  }

  PendingProfileSavesCompanion toCompanion(bool nullToAbsent) {
    return PendingProfileSavesCompanion(
      userPubkey: Value(userPubkey),
      payloadJson: Value(payloadJson),
      claimConfirmed: Value(claimConfirmed),
      status: Value(status),
      retryCount: Value(retryCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      queuedAt: Value(queuedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      generation: Value(generation),
    );
  }

  factory PendingProfileSaveRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingProfileSaveRow(
      userPubkey: serializer.fromJson<String>(json['userPubkey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      claimConfirmed: serializer.fromJson<bool>(json['claimConfirmed']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      generation: serializer.fromJson<String>(json['generation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userPubkey': serializer.toJson<String>(userPubkey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'claimConfirmed': serializer.toJson<bool>(claimConfirmed),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'lastError': serializer.toJson<String?>(lastError),
      'generation': serializer.toJson<String>(generation),
    };
  }

  PendingProfileSaveRow copyWith({
    String? userPubkey,
    String? payloadJson,
    bool? claimConfirmed,
    String? status,
    int? retryCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    DateTime? queuedAt,
    Value<String?> lastError = const Value.absent(),
    String? generation,
  }) => PendingProfileSaveRow(
    userPubkey: userPubkey ?? this.userPubkey,
    payloadJson: payloadJson ?? this.payloadJson,
    claimConfirmed: claimConfirmed ?? this.claimConfirmed,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    queuedAt: queuedAt ?? this.queuedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    generation: generation ?? this.generation,
  );
  PendingProfileSaveRow copyWithCompanion(PendingProfileSavesCompanion data) {
    return PendingProfileSaveRow(
      userPubkey: data.userPubkey.present
          ? data.userPubkey.value
          : this.userPubkey,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      claimConfirmed: data.claimConfirmed.present
          ? data.claimConfirmed.value
          : this.claimConfirmed,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingProfileSaveRow(')
          ..write('userPubkey: $userPubkey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('claimConfirmed: $claimConfirmed, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('lastError: $lastError, ')
          ..write('generation: $generation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userPubkey,
    payloadJson,
    claimConfirmed,
    status,
    retryCount,
    lastAttemptAt,
    queuedAt,
    lastError,
    generation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingProfileSaveRow &&
          other.userPubkey == this.userPubkey &&
          other.payloadJson == this.payloadJson &&
          other.claimConfirmed == this.claimConfirmed &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.queuedAt == this.queuedAt &&
          other.lastError == this.lastError &&
          other.generation == this.generation);
}

class PendingProfileSavesCompanion
    extends UpdateCompanion<PendingProfileSaveRow> {
  final Value<String> userPubkey;
  final Value<String> payloadJson;
  final Value<bool> claimConfirmed;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime> queuedAt;
  final Value<String?> lastError;
  final Value<String> generation;
  final Value<int> rowid;
  const PendingProfileSavesCompanion({
    this.userPubkey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.claimConfirmed = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.generation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingProfileSavesCompanion.insert({
    required String userPubkey,
    required String payloadJson,
    this.claimConfirmed = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    required DateTime queuedAt,
    this.lastError = const Value.absent(),
    this.generation = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userPubkey = Value(userPubkey),
       payloadJson = Value(payloadJson),
       queuedAt = Value(queuedAt);
  static Insertable<PendingProfileSaveRow> custom({
    Expression<String>? userPubkey,
    Expression<String>? payloadJson,
    Expression<bool>? claimConfirmed,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? queuedAt,
    Expression<String>? lastError,
    Expression<String>? generation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userPubkey != null) 'user_pubkey': userPubkey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (claimConfirmed != null) 'claim_confirmed': claimConfirmed,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (lastError != null) 'last_error': lastError,
      if (generation != null) 'generation': generation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingProfileSavesCompanion copyWith({
    Value<String>? userPubkey,
    Value<String>? payloadJson,
    Value<bool>? claimConfirmed,
    Value<String>? status,
    Value<int>? retryCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime>? queuedAt,
    Value<String?>? lastError,
    Value<String>? generation,
    Value<int>? rowid,
  }) {
    return PendingProfileSavesCompanion(
      userPubkey: userPubkey ?? this.userPubkey,
      payloadJson: payloadJson ?? this.payloadJson,
      claimConfirmed: claimConfirmed ?? this.claimConfirmed,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      queuedAt: queuedAt ?? this.queuedAt,
      lastError: lastError ?? this.lastError,
      generation: generation ?? this.generation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userPubkey.present) {
      map['user_pubkey'] = Variable<String>(userPubkey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (claimConfirmed.present) {
      map['claim_confirmed'] = Variable<bool>(claimConfirmed.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (generation.present) {
      map['generation'] = Variable<String>(generation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingProfileSavesCompanion(')
          ..write('userPubkey: $userPubkey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('claimConfirmed: $claimConfirmed, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('lastError: $lastError, ')
          ..write('generation: $generation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdentityEventsTable extends IdentityEvents
    with TableInfo<$IdentityEventsTable, IdentityEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdentityEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<int> sourceKind = GeneratedColumn<int>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceCreatedAtMeta = const VerificationMeta(
    'sourceCreatedAt',
  );
  @override
  late final GeneratedColumn<int> sourceCreatedAt = GeneratedColumn<int>(
    'source_created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceEventIdMeta = const VerificationMeta(
    'sourceEventId',
  );
  @override
  late final GeneratedColumn<String> sourceEventId = GeneratedColumn<String>(
    'source_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pubkey,
    tagsJson,
    sourceKind,
    sourceCreatedAt,
    sourceEventId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'identity_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdentityEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsJsonMeta);
    }
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKindMeta);
    }
    if (data.containsKey('source_created_at')) {
      context.handle(
        _sourceCreatedAtMeta,
        sourceCreatedAt.isAcceptableOrUnknown(
          data['source_created_at']!,
          _sourceCreatedAtMeta,
        ),
      );
    }
    if (data.containsKey('source_event_id')) {
      context.handle(
        _sourceEventIdMeta,
        sourceEventId.isAcceptableOrUnknown(
          data['source_event_id']!,
          _sourceEventIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubkey};
  @override
  IdentityEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdentityEventRow(
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_kind'],
      )!,
      sourceCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_created_at'],
      ),
      sourceEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_event_id'],
      ),
    );
  }

  @override
  $IdentityEventsTable createAlias(String alias) {
    return $IdentityEventsTable(attachedDatabase, alias);
  }
}

class IdentityEventRow extends DataClass
    implements Insertable<IdentityEventRow> {
  /// Hex pubkey of the profile the identity event belongs to.
  final String pubkey;

  /// JSON-encoded `List<List<String>>` of the event's `i` tags only.
  final String tagsJson;

  /// Which event kind the tags came from: 10011 (current spec) or 0
  /// (legacy fallback).
  final int sourceKind;

  /// `created_at` of the kind-10011 event [tagsJson] was taken from.
  ///
  /// Null for a kind-0 fallback row and for rows written before this column
  /// existed. Kind 10011 is replaceable, so this is what lets a later read be
  /// recognised as behind: an event older than the one a row was built from
  /// cannot be the current state of the profile, it is a relay that has not
  /// caught up. The write path refuses to publish on such a base instead of
  /// replacing the event with a set that predates what this device has
  /// already seen (#7081).
  final int? sourceCreatedAt;

  /// Event id that goes with [sourceCreatedAt], for the NIP-01 same-second
  /// tie (lowest id wins). Null under exactly the same conditions.
  final String? sourceEventId;
  const IdentityEventRow({
    required this.pubkey,
    required this.tagsJson,
    required this.sourceKind,
    this.sourceCreatedAt,
    this.sourceEventId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey'] = Variable<String>(pubkey);
    map['tags_json'] = Variable<String>(tagsJson);
    map['source_kind'] = Variable<int>(sourceKind);
    if (!nullToAbsent || sourceCreatedAt != null) {
      map['source_created_at'] = Variable<int>(sourceCreatedAt);
    }
    if (!nullToAbsent || sourceEventId != null) {
      map['source_event_id'] = Variable<String>(sourceEventId);
    }
    return map;
  }

  IdentityEventsCompanion toCompanion(bool nullToAbsent) {
    return IdentityEventsCompanion(
      pubkey: Value(pubkey),
      tagsJson: Value(tagsJson),
      sourceKind: Value(sourceKind),
      sourceCreatedAt: sourceCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceCreatedAt),
      sourceEventId: sourceEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceEventId),
    );
  }

  factory IdentityEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdentityEventRow(
      pubkey: serializer.fromJson<String>(json['pubkey']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      sourceKind: serializer.fromJson<int>(json['sourceKind']),
      sourceCreatedAt: serializer.fromJson<int?>(json['sourceCreatedAt']),
      sourceEventId: serializer.fromJson<String?>(json['sourceEventId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkey': serializer.toJson<String>(pubkey),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'sourceKind': serializer.toJson<int>(sourceKind),
      'sourceCreatedAt': serializer.toJson<int?>(sourceCreatedAt),
      'sourceEventId': serializer.toJson<String?>(sourceEventId),
    };
  }

  IdentityEventRow copyWith({
    String? pubkey,
    String? tagsJson,
    int? sourceKind,
    Value<int?> sourceCreatedAt = const Value.absent(),
    Value<String?> sourceEventId = const Value.absent(),
  }) => IdentityEventRow(
    pubkey: pubkey ?? this.pubkey,
    tagsJson: tagsJson ?? this.tagsJson,
    sourceKind: sourceKind ?? this.sourceKind,
    sourceCreatedAt: sourceCreatedAt.present
        ? sourceCreatedAt.value
        : this.sourceCreatedAt,
    sourceEventId: sourceEventId.present
        ? sourceEventId.value
        : this.sourceEventId,
  );
  IdentityEventRow copyWithCompanion(IdentityEventsCompanion data) {
    return IdentityEventRow(
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      sourceCreatedAt: data.sourceCreatedAt.present
          ? data.sourceCreatedAt.value
          : this.sourceCreatedAt,
      sourceEventId: data.sourceEventId.present
          ? data.sourceEventId.value
          : this.sourceEventId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdentityEventRow(')
          ..write('pubkey: $pubkey, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceCreatedAt: $sourceCreatedAt, ')
          ..write('sourceEventId: $sourceEventId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(pubkey, tagsJson, sourceKind, sourceCreatedAt, sourceEventId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdentityEventRow &&
          other.pubkey == this.pubkey &&
          other.tagsJson == this.tagsJson &&
          other.sourceKind == this.sourceKind &&
          other.sourceCreatedAt == this.sourceCreatedAt &&
          other.sourceEventId == this.sourceEventId);
}

class IdentityEventsCompanion extends UpdateCompanion<IdentityEventRow> {
  final Value<String> pubkey;
  final Value<String> tagsJson;
  final Value<int> sourceKind;
  final Value<int?> sourceCreatedAt;
  final Value<String?> sourceEventId;
  final Value<int> rowid;
  const IdentityEventsCompanion({
    this.pubkey = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.sourceCreatedAt = const Value.absent(),
    this.sourceEventId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdentityEventsCompanion.insert({
    required String pubkey,
    required String tagsJson,
    required int sourceKind,
    this.sourceCreatedAt = const Value.absent(),
    this.sourceEventId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pubkey = Value(pubkey),
       tagsJson = Value(tagsJson),
       sourceKind = Value(sourceKind);
  static Insertable<IdentityEventRow> custom({
    Expression<String>? pubkey,
    Expression<String>? tagsJson,
    Expression<int>? sourceKind,
    Expression<int>? sourceCreatedAt,
    Expression<String>? sourceEventId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkey != null) 'pubkey': pubkey,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (sourceCreatedAt != null) 'source_created_at': sourceCreatedAt,
      if (sourceEventId != null) 'source_event_id': sourceEventId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdentityEventsCompanion copyWith({
    Value<String>? pubkey,
    Value<String>? tagsJson,
    Value<int>? sourceKind,
    Value<int?>? sourceCreatedAt,
    Value<String?>? sourceEventId,
    Value<int>? rowid,
  }) {
    return IdentityEventsCompanion(
      pubkey: pubkey ?? this.pubkey,
      tagsJson: tagsJson ?? this.tagsJson,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceCreatedAt: sourceCreatedAt ?? this.sourceCreatedAt,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<int>(sourceKind.value);
    }
    if (sourceCreatedAt.present) {
      map['source_created_at'] = Variable<int>(sourceCreatedAt.value);
    }
    if (sourceEventId.present) {
      map['source_event_id'] = Variable<String>(sourceEventId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdentityEventsCompanion(')
          ..write('pubkey: $pubkey, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceCreatedAt: $sourceCreatedAt, ')
          ..write('sourceEventId: $sourceEventId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdentityVerificationsTable extends IdentityVerifications
    with TableInfo<$IdentityVerificationsTable, IdentityVerificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdentityVerificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifiedClaimsJsonMeta =
      const VerificationMeta('verifiedClaimsJson');
  @override
  late final GeneratedColumn<String> verifiedClaimsJson =
      GeneratedColumn<String>(
        'verified_claims_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _checkedAtFloorMeta = const VerificationMeta(
    'checkedAtFloor',
  );
  @override
  late final GeneratedColumn<int> checkedAtFloor = GeneratedColumn<int>(
    'checked_at_floor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pubkey,
    verifiedClaimsJson,
    checkedAtFloor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'identity_verifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdentityVerificationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('verified_claims_json')) {
      context.handle(
        _verifiedClaimsJsonMeta,
        verifiedClaimsJson.isAcceptableOrUnknown(
          data['verified_claims_json']!,
          _verifiedClaimsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_verifiedClaimsJsonMeta);
    }
    if (data.containsKey('checked_at_floor')) {
      context.handle(
        _checkedAtFloorMeta,
        checkedAtFloor.isAcceptableOrUnknown(
          data['checked_at_floor']!,
          _checkedAtFloorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkedAtFloorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubkey};
  @override
  IdentityVerificationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdentityVerificationRow(
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      verifiedClaimsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verified_claims_json'],
      )!,
      checkedAtFloor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checked_at_floor'],
      )!,
    );
  }

  @override
  $IdentityVerificationsTable createAlias(String alias) {
    return $IdentityVerificationsTable(attachedDatabase, alias);
  }
}

class IdentityVerificationRow extends DataClass
    implements Insertable<IdentityVerificationRow> {
  /// Hex pubkey of the profile the verified claims belong to.
  final String pubkey;

  /// JSON-encoded list of verified claim objects
  /// `{"platform": ..., "identity": ..., "proof": ...}`.
  ///
  /// Proof participates in cache matching: a rotated proof no longer
  /// matches its snapshot entry, so the claim re-verifies instead of
  /// serving a stale verdict.
  final String verifiedClaimsJson;

  /// Minimum verifier `checked_at` (unix seconds) across the verified
  /// batch. Freshness = `checkedAtFloor + 24h > now`.
  final int checkedAtFloor;
  const IdentityVerificationRow({
    required this.pubkey,
    required this.verifiedClaimsJson,
    required this.checkedAtFloor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey'] = Variable<String>(pubkey);
    map['verified_claims_json'] = Variable<String>(verifiedClaimsJson);
    map['checked_at_floor'] = Variable<int>(checkedAtFloor);
    return map;
  }

  IdentityVerificationsCompanion toCompanion(bool nullToAbsent) {
    return IdentityVerificationsCompanion(
      pubkey: Value(pubkey),
      verifiedClaimsJson: Value(verifiedClaimsJson),
      checkedAtFloor: Value(checkedAtFloor),
    );
  }

  factory IdentityVerificationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdentityVerificationRow(
      pubkey: serializer.fromJson<String>(json['pubkey']),
      verifiedClaimsJson: serializer.fromJson<String>(
        json['verifiedClaimsJson'],
      ),
      checkedAtFloor: serializer.fromJson<int>(json['checkedAtFloor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkey': serializer.toJson<String>(pubkey),
      'verifiedClaimsJson': serializer.toJson<String>(verifiedClaimsJson),
      'checkedAtFloor': serializer.toJson<int>(checkedAtFloor),
    };
  }

  IdentityVerificationRow copyWith({
    String? pubkey,
    String? verifiedClaimsJson,
    int? checkedAtFloor,
  }) => IdentityVerificationRow(
    pubkey: pubkey ?? this.pubkey,
    verifiedClaimsJson: verifiedClaimsJson ?? this.verifiedClaimsJson,
    checkedAtFloor: checkedAtFloor ?? this.checkedAtFloor,
  );
  IdentityVerificationRow copyWithCompanion(
    IdentityVerificationsCompanion data,
  ) {
    return IdentityVerificationRow(
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      verifiedClaimsJson: data.verifiedClaimsJson.present
          ? data.verifiedClaimsJson.value
          : this.verifiedClaimsJson,
      checkedAtFloor: data.checkedAtFloor.present
          ? data.checkedAtFloor.value
          : this.checkedAtFloor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdentityVerificationRow(')
          ..write('pubkey: $pubkey, ')
          ..write('verifiedClaimsJson: $verifiedClaimsJson, ')
          ..write('checkedAtFloor: $checkedAtFloor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pubkey, verifiedClaimsJson, checkedAtFloor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdentityVerificationRow &&
          other.pubkey == this.pubkey &&
          other.verifiedClaimsJson == this.verifiedClaimsJson &&
          other.checkedAtFloor == this.checkedAtFloor);
}

class IdentityVerificationsCompanion
    extends UpdateCompanion<IdentityVerificationRow> {
  final Value<String> pubkey;
  final Value<String> verifiedClaimsJson;
  final Value<int> checkedAtFloor;
  final Value<int> rowid;
  const IdentityVerificationsCompanion({
    this.pubkey = const Value.absent(),
    this.verifiedClaimsJson = const Value.absent(),
    this.checkedAtFloor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdentityVerificationsCompanion.insert({
    required String pubkey,
    required String verifiedClaimsJson,
    required int checkedAtFloor,
    this.rowid = const Value.absent(),
  }) : pubkey = Value(pubkey),
       verifiedClaimsJson = Value(verifiedClaimsJson),
       checkedAtFloor = Value(checkedAtFloor);
  static Insertable<IdentityVerificationRow> custom({
    Expression<String>? pubkey,
    Expression<String>? verifiedClaimsJson,
    Expression<int>? checkedAtFloor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkey != null) 'pubkey': pubkey,
      if (verifiedClaimsJson != null)
        'verified_claims_json': verifiedClaimsJson,
      if (checkedAtFloor != null) 'checked_at_floor': checkedAtFloor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdentityVerificationsCompanion copyWith({
    Value<String>? pubkey,
    Value<String>? verifiedClaimsJson,
    Value<int>? checkedAtFloor,
    Value<int>? rowid,
  }) {
    return IdentityVerificationsCompanion(
      pubkey: pubkey ?? this.pubkey,
      verifiedClaimsJson: verifiedClaimsJson ?? this.verifiedClaimsJson,
      checkedAtFloor: checkedAtFloor ?? this.checkedAtFloor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (verifiedClaimsJson.present) {
      map['verified_claims_json'] = Variable<String>(verifiedClaimsJson.value);
    }
    if (checkedAtFloor.present) {
      map['checked_at_floor'] = Variable<int>(checkedAtFloor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdentityVerificationsCompanion(')
          ..write('pubkey: $pubkey, ')
          ..write('verifiedClaimsJson: $verifiedClaimsJson, ')
          ..write('checkedAtFloor: $checkedAtFloor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeenVideosTable extends SeenVideos
    with TableInfo<$SeenVideosTable, SeenVideoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeenVideosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<int> firstSeenAt = GeneratedColumn<int>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [videoId, firstSeenAt, lastSeenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seen_videos';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeenVideoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  SeenVideoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeenVideoRow(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $SeenVideosTable createAlias(String alias) {
    return $SeenVideosTable(attachedDatabase, alias);
  }
}

class SeenVideoRow extends DataClass implements Insertable<SeenVideoRow> {
  /// Nostr event id of the seen video (hex).
  final String videoId;

  /// Unix milliseconds of first-seen (for diagnostics, not filtering).
  final int firstSeenAt;

  /// Unix milliseconds of last-seen — the recency signal.
  final int lastSeenAt;
  const SeenVideoRow({
    required this.videoId,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['first_seen_at'] = Variable<int>(firstSeenAt);
    map['last_seen_at'] = Variable<int>(lastSeenAt);
    return map;
  }

  SeenVideosCompanion toCompanion(bool nullToAbsent) {
    return SeenVideosCompanion(
      videoId: Value(videoId),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory SeenVideoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeenVideoRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      firstSeenAt: serializer.fromJson<int>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<int>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'firstSeenAt': serializer.toJson<int>(firstSeenAt),
      'lastSeenAt': serializer.toJson<int>(lastSeenAt),
    };
  }

  SeenVideoRow copyWith({String? videoId, int? firstSeenAt, int? lastSeenAt}) =>
      SeenVideoRow(
        videoId: videoId ?? this.videoId,
        firstSeenAt: firstSeenAt ?? this.firstSeenAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
  SeenVideoRow copyWithCompanion(SeenVideosCompanion data) {
    return SeenVideoRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeenVideoRow(')
          ..write('videoId: $videoId, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(videoId, firstSeenAt, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenVideoRow &&
          other.videoId == this.videoId &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class SeenVideosCompanion extends UpdateCompanion<SeenVideoRow> {
  final Value<String> videoId;
  final Value<int> firstSeenAt;
  final Value<int> lastSeenAt;
  final Value<int> rowid;
  const SeenVideosCompanion({
    this.videoId = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeenVideosCompanion.insert({
    required String videoId,
    required int firstSeenAt,
    required int lastSeenAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<SeenVideoRow> custom({
    Expression<String>? videoId,
    Expression<int>? firstSeenAt,
    Expression<int>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeenVideosCompanion copyWith({
    Value<String>? videoId,
    Value<int>? firstSeenAt,
    Value<int>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return SeenVideosCompanion(
      videoId: videoId ?? this.videoId,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<int>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeenVideosCompanion(')
          ..write('videoId: $videoId, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VanishedProfilesTable extends VanishedProfiles
    with TableInfo<$VanishedProfilesTable, VanishedProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VanishedProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubkeyMeta = const VerificationMeta('pubkey');
  @override
  late final GeneratedColumn<String> pubkey = GeneratedColumn<String>(
    'pubkey',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [pubkey, detectedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vanished_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<VanishedProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pubkey')) {
      context.handle(
        _pubkeyMeta,
        pubkey.isAcceptableOrUnknown(data['pubkey']!, _pubkeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubkey};
  @override
  VanishedProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VanishedProfileRow(
      pubkey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey'],
      )!,
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}detected_at'],
      )!,
    );
  }

  @override
  $VanishedProfilesTable createAlias(String alias) {
    return $VanishedProfilesTable(attachedDatabase, alias);
  }
}

class VanishedProfileRow extends DataClass
    implements Insertable<VanishedProfileRow> {
  /// Hex pubkey of the account that requested deletion.
  final String pubkey;

  /// When this device first learned the account had vanished.
  ///
  /// First-seen and stable: re-marking an already-recorded pubkey keeps this
  /// value rather than refreshing it.
  final DateTime detectedAt;
  const VanishedProfileRow({required this.pubkey, required this.detectedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey'] = Variable<String>(pubkey);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    return map;
  }

  VanishedProfilesCompanion toCompanion(bool nullToAbsent) {
    return VanishedProfilesCompanion(
      pubkey: Value(pubkey),
      detectedAt: Value(detectedAt),
    );
  }

  factory VanishedProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VanishedProfileRow(
      pubkey: serializer.fromJson<String>(json['pubkey']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkey': serializer.toJson<String>(pubkey),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
    };
  }

  VanishedProfileRow copyWith({String? pubkey, DateTime? detectedAt}) =>
      VanishedProfileRow(
        pubkey: pubkey ?? this.pubkey,
        detectedAt: detectedAt ?? this.detectedAt,
      );
  VanishedProfileRow copyWithCompanion(VanishedProfilesCompanion data) {
    return VanishedProfileRow(
      pubkey: data.pubkey.present ? data.pubkey.value : this.pubkey,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VanishedProfileRow(')
          ..write('pubkey: $pubkey, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pubkey, detectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VanishedProfileRow &&
          other.pubkey == this.pubkey &&
          other.detectedAt == this.detectedAt);
}

class VanishedProfilesCompanion extends UpdateCompanion<VanishedProfileRow> {
  final Value<String> pubkey;
  final Value<DateTime> detectedAt;
  final Value<int> rowid;
  const VanishedProfilesCompanion({
    this.pubkey = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VanishedProfilesCompanion.insert({
    required String pubkey,
    required DateTime detectedAt,
    this.rowid = const Value.absent(),
  }) : pubkey = Value(pubkey),
       detectedAt = Value(detectedAt);
  static Insertable<VanishedProfileRow> custom({
    Expression<String>? pubkey,
    Expression<DateTime>? detectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkey != null) 'pubkey': pubkey,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VanishedProfilesCompanion copyWith({
    Value<String>? pubkey,
    Value<DateTime>? detectedAt,
    Value<int>? rowid,
  }) {
    return VanishedProfilesCompanion(
      pubkey: pubkey ?? this.pubkey,
      detectedAt: detectedAt ?? this.detectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubkey.present) {
      map['pubkey'] = Variable<String>(pubkey.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VanishedProfilesCompanion(')
          ..write('pubkey: $pubkey, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NostrEventsTable nostrEvents = $NostrEventsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $VideoMetricsTable videoMetrics = $VideoMetricsTable(this);
  late final $ProfileStatsTable profileStats = $ProfileStatsTable(this);
  late final $HashtagStatsTable hashtagStats = $HashtagStatsTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final $PendingUploadsTable pendingUploads = $PendingUploadsTable(this);
  late final $PersonalReactionsTable personalReactions =
      $PersonalReactionsTable(this);
  late final $PersonalRepostsTable personalReposts = $PersonalRepostsTable(
    this,
  );
  late final $PersonalEventsTable personalEvents = $PersonalEventsTable(this);
  late final $PendingActionsTable pendingActions = $PendingActionsTable(this);
  late final $Nip05VerificationsTable nip05Verifications =
      $Nip05VerificationsTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $ClipsTable clips = $ClipsTable(this);
  late final $ClipCategoriesTable clipCategories = $ClipCategoriesTable(this);
  late final $DirectMessagesTable directMessages = $DirectMessagesTable(this);
  late final $DmMessageReactionsTable dmMessageReactions =
      $DmMessageReactionsTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $OutgoingDmsTable outgoingDms = $OutgoingDmsTable(this);
  late final $PendingViewEventsTable pendingViewEvents =
      $PendingViewEventsTable(this);
  late final $PendingProductEventsTable pendingProductEvents =
      $PendingProductEventsTable(this);
  late final $PendingGiftWrapsTable pendingGiftWraps = $PendingGiftWrapsTable(
    this,
  );
  late final $ProcessedGiftWrapsTable processedGiftWraps =
      $ProcessedGiftWrapsTable(this);
  late final $RemovedConversationsTable removedConversations =
      $RemovedConversationsTable(this);
  late final $PendingProfileSavesTable pendingProfileSaves =
      $PendingProfileSavesTable(this);
  late final $IdentityEventsTable identityEvents = $IdentityEventsTable(this);
  late final $IdentityVerificationsTable identityVerifications =
      $IdentityVerificationsTable(this);
  late final $SeenVideosTable seenVideos = $SeenVideosTable(this);
  late final $VanishedProfilesTable vanishedProfiles = $VanishedProfilesTable(
    this,
  );
  late final Index idxMetricsLoopCount = Index(
    'idx_metrics_loop_count',
    'CREATE INDEX IF NOT EXISTS idx_metrics_loop_count ON video_metrics (loop_count)',
  );
  late final Index idxMetricsLikes = Index(
    'idx_metrics_likes',
    'CREATE INDEX IF NOT EXISTS idx_metrics_likes ON video_metrics (likes)',
  );
  late final Index idxMetricsViews = Index(
    'idx_metrics_views',
    'CREATE INDEX IF NOT EXISTS idx_metrics_views ON video_metrics (views)',
  );
  late final Index idxHashtagVideoCount = Index(
    'idx_hashtag_video_count',
    'CREATE INDEX IF NOT EXISTS idx_hashtag_video_count ON hashtag_stats (video_count DESC)',
  );
  late final Index idxNotificationTimestamp = Index(
    'idx_notification_timestamp',
    'CREATE INDEX IF NOT EXISTS idx_notification_timestamp ON notifications (timestamp DESC)',
  );
  late final Index idxNotificationIsRead = Index(
    'idx_notification_is_read',
    'CREATE INDEX IF NOT EXISTS idx_notification_is_read ON notifications (is_read)',
  );
  late final Index idxNotificationOwnerTimestamp = Index(
    'idx_notification_owner_timestamp',
    'CREATE INDEX IF NOT EXISTS idx_notification_owner_timestamp ON notifications (owner_pubkey, timestamp DESC)',
  );
  late final Index idxPendingUploadStatus = Index(
    'idx_pending_upload_status',
    'CREATE INDEX IF NOT EXISTS idx_pending_upload_status ON pending_uploads (status)',
  );
  late final Index idxPendingUploadCreated = Index(
    'idx_pending_upload_created',
    'CREATE INDEX IF NOT EXISTS idx_pending_upload_created ON pending_uploads (created_at DESC)',
  );
  late final Index idxPersonalReactionsUser = Index(
    'idx_personal_reactions_user',
    'CREATE INDEX IF NOT EXISTS idx_personal_reactions_user ON personal_reactions (user_pubkey)',
  );
  late final Index idxPersonalReactionsReactionId = Index(
    'idx_personal_reactions_reaction_id',
    'CREATE INDEX IF NOT EXISTS idx_personal_reactions_reaction_id ON personal_reactions (reaction_event_id)',
  );
  late final Index idxPersonalReactionsAddressableId = Index(
    'idx_personal_reactions_addressable_id',
    'CREATE INDEX IF NOT EXISTS idx_personal_reactions_addressable_id ON personal_reactions (addressable_id)',
  );
  late final Index idxPersonalRepostsUser = Index(
    'idx_personal_reposts_user',
    'CREATE INDEX IF NOT EXISTS idx_personal_reposts_user ON personal_reposts (user_pubkey)',
  );
  late final Index idxPersonalRepostsRepostId = Index(
    'idx_personal_reposts_repost_id',
    'CREATE INDEX IF NOT EXISTS idx_personal_reposts_repost_id ON personal_reposts (repost_event_id)',
  );
  late final Index idxPersonalRepostsUserCreated = Index(
    'idx_personal_reposts_user_created',
    'CREATE INDEX IF NOT EXISTS idx_personal_reposts_user_created ON personal_reposts (user_pubkey, created_at DESC)',
  );
  late final Index idxPersonalEventsPubkeyKindCreatedAt = Index(
    'idx_personal_events_pubkey_kind_created_at',
    'CREATE INDEX IF NOT EXISTS idx_personal_events_pubkey_kind_created_at ON personal_events (pubkey, kind, created_at DESC)',
  );
  late final Index idxPersonalEventsPubkeyCreatedAt = Index(
    'idx_personal_events_pubkey_created_at',
    'CREATE INDEX IF NOT EXISTS idx_personal_events_pubkey_created_at ON personal_events (pubkey, created_at DESC)',
  );
  late final UserProfilesDao userProfilesDao = UserProfilesDao(
    this as AppDatabase,
  );
  late final NostrEventsDao nostrEventsDao = NostrEventsDao(
    this as AppDatabase,
  );
  late final VideoMetricsDao videoMetricsDao = VideoMetricsDao(
    this as AppDatabase,
  );
  late final ProfileStatsDao profileStatsDao = ProfileStatsDao(
    this as AppDatabase,
  );
  late final HashtagStatsDao hashtagStatsDao = HashtagStatsDao(
    this as AppDatabase,
  );
  late final NotificationsDao notificationsDao = NotificationsDao(
    this as AppDatabase,
  );
  late final PendingUploadsDao pendingUploadsDao = PendingUploadsDao(
    this as AppDatabase,
  );
  late final PersonalEventsDao personalEventsDao = PersonalEventsDao(
    this as AppDatabase,
  );
  late final PersonalReactionsDao personalReactionsDao = PersonalReactionsDao(
    this as AppDatabase,
  );
  late final PersonalRepostsDao personalRepostsDao = PersonalRepostsDao(
    this as AppDatabase,
  );
  late final PendingActionsDao pendingActionsDao = PendingActionsDao(
    this as AppDatabase,
  );
  late final Nip05VerificationsDao nip05VerificationsDao =
      Nip05VerificationsDao(this as AppDatabase);
  late final DraftsDao draftsDao = DraftsDao(this as AppDatabase);
  late final ClipsDao clipsDao = ClipsDao(this as AppDatabase);
  late final ClipCategoriesDao clipCategoriesDao = ClipCategoriesDao(
    this as AppDatabase,
  );
  late final DirectMessagesDao directMessagesDao = DirectMessagesDao(
    this as AppDatabase,
  );
  late final DmReactionsDao dmReactionsDao = DmReactionsDao(
    this as AppDatabase,
  );
  late final ConversationsDao conversationsDao = ConversationsDao(
    this as AppDatabase,
  );
  late final OutgoingDmsDao outgoingDmsDao = OutgoingDmsDao(
    this as AppDatabase,
  );
  late final PendingViewEventsDao pendingViewEventsDao = PendingViewEventsDao(
    this as AppDatabase,
  );
  late final PendingProductEventsDao pendingProductEventsDao =
      PendingProductEventsDao(this as AppDatabase);
  late final PendingGiftWrapsDao pendingGiftWrapsDao = PendingGiftWrapsDao(
    this as AppDatabase,
  );
  late final ProcessedGiftWrapsDao processedGiftWrapsDao =
      ProcessedGiftWrapsDao(this as AppDatabase);
  late final RemovedConversationsDao removedConversationsDao =
      RemovedConversationsDao(this as AppDatabase);
  late final PendingProfileSavesDao pendingProfileSavesDao =
      PendingProfileSavesDao(this as AppDatabase);
  late final IdentityEventsDao identityEventsDao = IdentityEventsDao(
    this as AppDatabase,
  );
  late final IdentityVerificationsDao identityVerificationsDao =
      IdentityVerificationsDao(this as AppDatabase);
  late final SeenVideosDao seenVideosDao = SeenVideosDao(this as AppDatabase);
  late final VanishedProfilesDao vanishedProfilesDao = VanishedProfilesDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    nostrEvents,
    userProfiles,
    videoMetrics,
    profileStats,
    hashtagStats,
    notifications,
    pendingUploads,
    personalReactions,
    personalReposts,
    personalEvents,
    pendingActions,
    nip05Verifications,
    drafts,
    clips,
    clipCategories,
    directMessages,
    dmMessageReactions,
    conversations,
    outgoingDms,
    pendingViewEvents,
    pendingProductEvents,
    pendingGiftWraps,
    processedGiftWraps,
    removedConversations,
    pendingProfileSaves,
    identityEvents,
    identityVerifications,
    seenVideos,
    vanishedProfiles,
    idxMetricsLoopCount,
    idxMetricsLikes,
    idxMetricsViews,
    idxHashtagVideoCount,
    idxNotificationTimestamp,
    idxNotificationIsRead,
    idxNotificationOwnerTimestamp,
    idxPendingUploadStatus,
    idxPendingUploadCreated,
    idxPersonalReactionsUser,
    idxPersonalReactionsReactionId,
    idxPersonalReactionsAddressableId,
    idxPersonalRepostsUser,
    idxPersonalRepostsRepostId,
    idxPersonalRepostsUserCreated,
    idxPersonalEventsPubkeyKindCreatedAt,
    idxPersonalEventsPubkeyCreatedAt,
  ];
}

typedef $$NostrEventsTableCreateCompanionBuilder =
    NostrEventsCompanion Function({
      required String id,
      required String pubkey,
      required int createdAt,
      required int kind,
      required String tags,
      required String content,
      required String sig,
      Value<String?> sources,
      Value<int?> expireAt,
      Value<String?> dTag,
      Value<int> rowid,
    });
typedef $$NostrEventsTableUpdateCompanionBuilder =
    NostrEventsCompanion Function({
      Value<String> id,
      Value<String> pubkey,
      Value<int> createdAt,
      Value<int> kind,
      Value<String> tags,
      Value<String> content,
      Value<String> sig,
      Value<String?> sources,
      Value<int?> expireAt,
      Value<String?> dTag,
      Value<int> rowid,
    });

class $$NostrEventsTableFilterComposer
    extends Composer<_$AppDatabase, $NostrEventsTable> {
  $$NostrEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sig => $composableBuilder(
    column: $table.sig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expireAt => $composableBuilder(
    column: $table.expireAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dTag => $composableBuilder(
    column: $table.dTag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NostrEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $NostrEventsTable> {
  $$NostrEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sig => $composableBuilder(
    column: $table.sig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expireAt => $composableBuilder(
    column: $table.expireAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dTag => $composableBuilder(
    column: $table.dTag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NostrEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NostrEventsTable> {
  $$NostrEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sig =>
      $composableBuilder(column: $table.sig, builder: (column) => column);

  GeneratedColumn<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => column);

  GeneratedColumn<int> get expireAt =>
      $composableBuilder(column: $table.expireAt, builder: (column) => column);

  GeneratedColumn<String> get dTag =>
      $composableBuilder(column: $table.dTag, builder: (column) => column);
}

class $$NostrEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NostrEventsTable,
          NostrEventRow,
          $$NostrEventsTableFilterComposer,
          $$NostrEventsTableOrderingComposer,
          $$NostrEventsTableAnnotationComposer,
          $$NostrEventsTableCreateCompanionBuilder,
          $$NostrEventsTableUpdateCompanionBuilder,
          (
            NostrEventRow,
            BaseReferences<_$AppDatabase, $NostrEventsTable, NostrEventRow>,
          ),
          NostrEventRow,
          PrefetchHooks Function()
        > {
  $$NostrEventsTableTableManager(_$AppDatabase db, $NostrEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NostrEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NostrEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NostrEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pubkey = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> sig = const Value.absent(),
                Value<String?> sources = const Value.absent(),
                Value<int?> expireAt = const Value.absent(),
                Value<String?> dTag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NostrEventsCompanion(
                id: id,
                pubkey: pubkey,
                createdAt: createdAt,
                kind: kind,
                tags: tags,
                content: content,
                sig: sig,
                sources: sources,
                expireAt: expireAt,
                dTag: dTag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String pubkey,
                required int createdAt,
                required int kind,
                required String tags,
                required String content,
                required String sig,
                Value<String?> sources = const Value.absent(),
                Value<int?> expireAt = const Value.absent(),
                Value<String?> dTag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NostrEventsCompanion.insert(
                id: id,
                pubkey: pubkey,
                createdAt: createdAt,
                kind: kind,
                tags: tags,
                content: content,
                sig: sig,
                sources: sources,
                expireAt: expireAt,
                dTag: dTag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NostrEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NostrEventsTable,
      NostrEventRow,
      $$NostrEventsTableFilterComposer,
      $$NostrEventsTableOrderingComposer,
      $$NostrEventsTableAnnotationComposer,
      $$NostrEventsTableCreateCompanionBuilder,
      $$NostrEventsTableUpdateCompanionBuilder,
      (
        NostrEventRow,
        BaseReferences<_$AppDatabase, $NostrEventsTable, NostrEventRow>,
      ),
      NostrEventRow,
      PrefetchHooks Function()
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      required String pubkey,
      Value<String?> displayName,
      Value<String?> name,
      Value<String?> about,
      Value<String?> picture,
      Value<String?> banner,
      Value<String?> website,
      Value<String?> nip05,
      Value<String?> lud16,
      Value<String?> lud06,
      Value<String?> rawData,
      required DateTime createdAt,
      required String eventId,
      required DateTime lastFetched,
      Value<int> rowid,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<String> pubkey,
      Value<String?> displayName,
      Value<String?> name,
      Value<String?> about,
      Value<String?> picture,
      Value<String?> banner,
      Value<String?> website,
      Value<String?> nip05,
      Value<String?> lud16,
      Value<String?> lud06,
      Value<String?> rawData,
      Value<DateTime> createdAt,
      Value<String> eventId,
      Value<DateTime> lastFetched,
      Value<int> rowid,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get about => $composableBuilder(
    column: $table.about,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get picture => $composableBuilder(
    column: $table.picture,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get banner => $composableBuilder(
    column: $table.banner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nip05 => $composableBuilder(
    column: $table.nip05,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lud16 => $composableBuilder(
    column: $table.lud16,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lud06 => $composableBuilder(
    column: $table.lud06,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawData => $composableBuilder(
    column: $table.rawData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastFetched => $composableBuilder(
    column: $table.lastFetched,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get about => $composableBuilder(
    column: $table.about,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get picture => $composableBuilder(
    column: $table.picture,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get banner => $composableBuilder(
    column: $table.banner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nip05 => $composableBuilder(
    column: $table.nip05,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lud16 => $composableBuilder(
    column: $table.lud16,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lud06 => $composableBuilder(
    column: $table.lud06,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawData => $composableBuilder(
    column: $table.rawData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastFetched => $composableBuilder(
    column: $table.lastFetched,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get about =>
      $composableBuilder(column: $table.about, builder: (column) => column);

  GeneratedColumn<String> get picture =>
      $composableBuilder(column: $table.picture, builder: (column) => column);

  GeneratedColumn<String> get banner =>
      $composableBuilder(column: $table.banner, builder: (column) => column);

  GeneratedColumn<String> get website =>
      $composableBuilder(column: $table.website, builder: (column) => column);

  GeneratedColumn<String> get nip05 =>
      $composableBuilder(column: $table.nip05, builder: (column) => column);

  GeneratedColumn<String> get lud16 =>
      $composableBuilder(column: $table.lud16, builder: (column) => column);

  GeneratedColumn<String> get lud06 =>
      $composableBuilder(column: $table.lud06, builder: (column) => column);

  GeneratedColumn<String> get rawData =>
      $composableBuilder(column: $table.rawData, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastFetched => $composableBuilder(
    column: $table.lastFetched,
    builder: (column) => column,
  );
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfileRow,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfileRow,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>,
          ),
          UserProfileRow,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pubkey = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> about = const Value.absent(),
                Value<String?> picture = const Value.absent(),
                Value<String?> banner = const Value.absent(),
                Value<String?> website = const Value.absent(),
                Value<String?> nip05 = const Value.absent(),
                Value<String?> lud16 = const Value.absent(),
                Value<String?> lud06 = const Value.absent(),
                Value<String?> rawData = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<DateTime> lastFetched = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion(
                pubkey: pubkey,
                displayName: displayName,
                name: name,
                about: about,
                picture: picture,
                banner: banner,
                website: website,
                nip05: nip05,
                lud16: lud16,
                lud06: lud06,
                rawData: rawData,
                createdAt: createdAt,
                eventId: eventId,
                lastFetched: lastFetched,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkey,
                Value<String?> displayName = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> about = const Value.absent(),
                Value<String?> picture = const Value.absent(),
                Value<String?> banner = const Value.absent(),
                Value<String?> website = const Value.absent(),
                Value<String?> nip05 = const Value.absent(),
                Value<String?> lud16 = const Value.absent(),
                Value<String?> lud06 = const Value.absent(),
                Value<String?> rawData = const Value.absent(),
                required DateTime createdAt,
                required String eventId,
                required DateTime lastFetched,
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                pubkey: pubkey,
                displayName: displayName,
                name: name,
                about: about,
                picture: picture,
                banner: banner,
                website: website,
                nip05: nip05,
                lud16: lud16,
                lud06: lud06,
                rawData: rawData,
                createdAt: createdAt,
                eventId: eventId,
                lastFetched: lastFetched,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfileRow,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfileRow,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>,
      ),
      UserProfileRow,
      PrefetchHooks Function()
    >;
typedef $$VideoMetricsTableCreateCompanionBuilder =
    VideoMetricsCompanion Function({
      required String eventId,
      Value<int?> loopCount,
      Value<int?> likes,
      Value<int?> views,
      Value<int?> comments,
      Value<double?> avgCompletion,
      Value<int?> hasProofmode,
      Value<int?> hasDeviceAttestation,
      Value<int?> hasPgpSignature,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$VideoMetricsTableUpdateCompanionBuilder =
    VideoMetricsCompanion Function({
      Value<String> eventId,
      Value<int?> loopCount,
      Value<int?> likes,
      Value<int?> views,
      Value<int?> comments,
      Value<double?> avgCompletion,
      Value<int?> hasProofmode,
      Value<int?> hasDeviceAttestation,
      Value<int?> hasPgpSignature,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$VideoMetricsTableFilterComposer
    extends Composer<_$AppDatabase, $VideoMetricsTable> {
  $$VideoMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loopCount => $composableBuilder(
    column: $table.loopCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likes => $composableBuilder(
    column: $table.likes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get views => $composableBuilder(
    column: $table.views,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get comments => $composableBuilder(
    column: $table.comments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgCompletion => $composableBuilder(
    column: $table.avgCompletion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasProofmode => $composableBuilder(
    column: $table.hasProofmode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasDeviceAttestation => $composableBuilder(
    column: $table.hasDeviceAttestation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hasPgpSignature => $composableBuilder(
    column: $table.hasPgpSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VideoMetricsTableOrderingComposer
    extends Composer<_$AppDatabase, $VideoMetricsTable> {
  $$VideoMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loopCount => $composableBuilder(
    column: $table.loopCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likes => $composableBuilder(
    column: $table.likes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get views => $composableBuilder(
    column: $table.views,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get comments => $composableBuilder(
    column: $table.comments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgCompletion => $composableBuilder(
    column: $table.avgCompletion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasProofmode => $composableBuilder(
    column: $table.hasProofmode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasDeviceAttestation => $composableBuilder(
    column: $table.hasDeviceAttestation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hasPgpSignature => $composableBuilder(
    column: $table.hasPgpSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VideoMetricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VideoMetricsTable> {
  $$VideoMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get loopCount =>
      $composableBuilder(column: $table.loopCount, builder: (column) => column);

  GeneratedColumn<int> get likes =>
      $composableBuilder(column: $table.likes, builder: (column) => column);

  GeneratedColumn<int> get views =>
      $composableBuilder(column: $table.views, builder: (column) => column);

  GeneratedColumn<int> get comments =>
      $composableBuilder(column: $table.comments, builder: (column) => column);

  GeneratedColumn<double> get avgCompletion => $composableBuilder(
    column: $table.avgCompletion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hasProofmode => $composableBuilder(
    column: $table.hasProofmode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hasDeviceAttestation => $composableBuilder(
    column: $table.hasDeviceAttestation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hasPgpSignature => $composableBuilder(
    column: $table.hasPgpSignature,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$VideoMetricsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VideoMetricsTable,
          VideoMetricRow,
          $$VideoMetricsTableFilterComposer,
          $$VideoMetricsTableOrderingComposer,
          $$VideoMetricsTableAnnotationComposer,
          $$VideoMetricsTableCreateCompanionBuilder,
          $$VideoMetricsTableUpdateCompanionBuilder,
          (
            VideoMetricRow,
            BaseReferences<_$AppDatabase, $VideoMetricsTable, VideoMetricRow>,
          ),
          VideoMetricRow,
          PrefetchHooks Function()
        > {
  $$VideoMetricsTableTableManager(_$AppDatabase db, $VideoMetricsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VideoMetricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VideoMetricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VideoMetricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<int?> loopCount = const Value.absent(),
                Value<int?> likes = const Value.absent(),
                Value<int?> views = const Value.absent(),
                Value<int?> comments = const Value.absent(),
                Value<double?> avgCompletion = const Value.absent(),
                Value<int?> hasProofmode = const Value.absent(),
                Value<int?> hasDeviceAttestation = const Value.absent(),
                Value<int?> hasPgpSignature = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VideoMetricsCompanion(
                eventId: eventId,
                loopCount: loopCount,
                likes: likes,
                views: views,
                comments: comments,
                avgCompletion: avgCompletion,
                hasProofmode: hasProofmode,
                hasDeviceAttestation: hasDeviceAttestation,
                hasPgpSignature: hasPgpSignature,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                Value<int?> loopCount = const Value.absent(),
                Value<int?> likes = const Value.absent(),
                Value<int?> views = const Value.absent(),
                Value<int?> comments = const Value.absent(),
                Value<double?> avgCompletion = const Value.absent(),
                Value<int?> hasProofmode = const Value.absent(),
                Value<int?> hasDeviceAttestation = const Value.absent(),
                Value<int?> hasPgpSignature = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => VideoMetricsCompanion.insert(
                eventId: eventId,
                loopCount: loopCount,
                likes: likes,
                views: views,
                comments: comments,
                avgCompletion: avgCompletion,
                hasProofmode: hasProofmode,
                hasDeviceAttestation: hasDeviceAttestation,
                hasPgpSignature: hasPgpSignature,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VideoMetricsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VideoMetricsTable,
      VideoMetricRow,
      $$VideoMetricsTableFilterComposer,
      $$VideoMetricsTableOrderingComposer,
      $$VideoMetricsTableAnnotationComposer,
      $$VideoMetricsTableCreateCompanionBuilder,
      $$VideoMetricsTableUpdateCompanionBuilder,
      (
        VideoMetricRow,
        BaseReferences<_$AppDatabase, $VideoMetricsTable, VideoMetricRow>,
      ),
      VideoMetricRow,
      PrefetchHooks Function()
    >;
typedef $$ProfileStatsTableCreateCompanionBuilder =
    ProfileStatsCompanion Function({
      required String pubkey,
      Value<int?> videoCount,
      Value<int?> followerCount,
      Value<int?> followingCount,
      Value<int?> totalViews,
      Value<int?> totalLikes,
      required DateTime cachedAt,
      Value<DateTime?> followerCountsUpdatedAt,
      Value<int> rowid,
    });
typedef $$ProfileStatsTableUpdateCompanionBuilder =
    ProfileStatsCompanion Function({
      Value<String> pubkey,
      Value<int?> videoCount,
      Value<int?> followerCount,
      Value<int?> followingCount,
      Value<int?> totalViews,
      Value<int?> totalLikes,
      Value<DateTime> cachedAt,
      Value<DateTime?> followerCountsUpdatedAt,
      Value<int> rowid,
    });

class $$ProfileStatsTableFilterComposer
    extends Composer<_$AppDatabase, $ProfileStatsTable> {
  $$ProfileStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoCount => $composableBuilder(
    column: $table.videoCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get followerCount => $composableBuilder(
    column: $table.followerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get followingCount => $composableBuilder(
    column: $table.followingCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalViews => $composableBuilder(
    column: $table.totalViews,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalLikes => $composableBuilder(
    column: $table.totalLikes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get followerCountsUpdatedAt => $composableBuilder(
    column: $table.followerCountsUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfileStatsTable> {
  $$ProfileStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoCount => $composableBuilder(
    column: $table.videoCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get followerCount => $composableBuilder(
    column: $table.followerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get followingCount => $composableBuilder(
    column: $table.followingCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalViews => $composableBuilder(
    column: $table.totalViews,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalLikes => $composableBuilder(
    column: $table.totalLikes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get followerCountsUpdatedAt => $composableBuilder(
    column: $table.followerCountsUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfileStatsTable> {
  $$ProfileStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<int> get videoCount => $composableBuilder(
    column: $table.videoCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get followerCount => $composableBuilder(
    column: $table.followerCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get followingCount => $composableBuilder(
    column: $table.followingCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalViews => $composableBuilder(
    column: $table.totalViews,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalLikes => $composableBuilder(
    column: $table.totalLikes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get followerCountsUpdatedAt => $composableBuilder(
    column: $table.followerCountsUpdatedAt,
    builder: (column) => column,
  );
}

class $$ProfileStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfileStatsTable,
          ProfileStatRow,
          $$ProfileStatsTableFilterComposer,
          $$ProfileStatsTableOrderingComposer,
          $$ProfileStatsTableAnnotationComposer,
          $$ProfileStatsTableCreateCompanionBuilder,
          $$ProfileStatsTableUpdateCompanionBuilder,
          (
            ProfileStatRow,
            BaseReferences<_$AppDatabase, $ProfileStatsTable, ProfileStatRow>,
          ),
          ProfileStatRow,
          PrefetchHooks Function()
        > {
  $$ProfileStatsTableTableManager(_$AppDatabase db, $ProfileStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pubkey = const Value.absent(),
                Value<int?> videoCount = const Value.absent(),
                Value<int?> followerCount = const Value.absent(),
                Value<int?> followingCount = const Value.absent(),
                Value<int?> totalViews = const Value.absent(),
                Value<int?> totalLikes = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<DateTime?> followerCountsUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfileStatsCompanion(
                pubkey: pubkey,
                videoCount: videoCount,
                followerCount: followerCount,
                followingCount: followingCount,
                totalViews: totalViews,
                totalLikes: totalLikes,
                cachedAt: cachedAt,
                followerCountsUpdatedAt: followerCountsUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkey,
                Value<int?> videoCount = const Value.absent(),
                Value<int?> followerCount = const Value.absent(),
                Value<int?> followingCount = const Value.absent(),
                Value<int?> totalViews = const Value.absent(),
                Value<int?> totalLikes = const Value.absent(),
                required DateTime cachedAt,
                Value<DateTime?> followerCountsUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfileStatsCompanion.insert(
                pubkey: pubkey,
                videoCount: videoCount,
                followerCount: followerCount,
                followingCount: followingCount,
                totalViews: totalViews,
                totalLikes: totalLikes,
                cachedAt: cachedAt,
                followerCountsUpdatedAt: followerCountsUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfileStatsTable,
      ProfileStatRow,
      $$ProfileStatsTableFilterComposer,
      $$ProfileStatsTableOrderingComposer,
      $$ProfileStatsTableAnnotationComposer,
      $$ProfileStatsTableCreateCompanionBuilder,
      $$ProfileStatsTableUpdateCompanionBuilder,
      (
        ProfileStatRow,
        BaseReferences<_$AppDatabase, $ProfileStatsTable, ProfileStatRow>,
      ),
      ProfileStatRow,
      PrefetchHooks Function()
    >;
typedef $$HashtagStatsTableCreateCompanionBuilder =
    HashtagStatsCompanion Function({
      required String hashtag,
      Value<int?> videoCount,
      Value<int?> totalViews,
      Value<int?> totalLikes,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$HashtagStatsTableUpdateCompanionBuilder =
    HashtagStatsCompanion Function({
      Value<String> hashtag,
      Value<int?> videoCount,
      Value<int?> totalViews,
      Value<int?> totalLikes,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$HashtagStatsTableFilterComposer
    extends Composer<_$AppDatabase, $HashtagStatsTable> {
  $$HashtagStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hashtag => $composableBuilder(
    column: $table.hashtag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoCount => $composableBuilder(
    column: $table.videoCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalViews => $composableBuilder(
    column: $table.totalViews,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalLikes => $composableBuilder(
    column: $table.totalLikes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HashtagStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $HashtagStatsTable> {
  $$HashtagStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hashtag => $composableBuilder(
    column: $table.hashtag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoCount => $composableBuilder(
    column: $table.videoCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalViews => $composableBuilder(
    column: $table.totalViews,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalLikes => $composableBuilder(
    column: $table.totalLikes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HashtagStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HashtagStatsTable> {
  $$HashtagStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hashtag =>
      $composableBuilder(column: $table.hashtag, builder: (column) => column);

  GeneratedColumn<int> get videoCount => $composableBuilder(
    column: $table.videoCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalViews => $composableBuilder(
    column: $table.totalViews,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalLikes => $composableBuilder(
    column: $table.totalLikes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$HashtagStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HashtagStatsTable,
          HashtagStatRow,
          $$HashtagStatsTableFilterComposer,
          $$HashtagStatsTableOrderingComposer,
          $$HashtagStatsTableAnnotationComposer,
          $$HashtagStatsTableCreateCompanionBuilder,
          $$HashtagStatsTableUpdateCompanionBuilder,
          (
            HashtagStatRow,
            BaseReferences<_$AppDatabase, $HashtagStatsTable, HashtagStatRow>,
          ),
          HashtagStatRow,
          PrefetchHooks Function()
        > {
  $$HashtagStatsTableTableManager(_$AppDatabase db, $HashtagStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HashtagStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HashtagStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HashtagStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hashtag = const Value.absent(),
                Value<int?> videoCount = const Value.absent(),
                Value<int?> totalViews = const Value.absent(),
                Value<int?> totalLikes = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HashtagStatsCompanion(
                hashtag: hashtag,
                videoCount: videoCount,
                totalViews: totalViews,
                totalLikes: totalLikes,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hashtag,
                Value<int?> videoCount = const Value.absent(),
                Value<int?> totalViews = const Value.absent(),
                Value<int?> totalLikes = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => HashtagStatsCompanion.insert(
                hashtag: hashtag,
                videoCount: videoCount,
                totalViews: totalViews,
                totalLikes: totalLikes,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HashtagStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HashtagStatsTable,
      HashtagStatRow,
      $$HashtagStatsTableFilterComposer,
      $$HashtagStatsTableOrderingComposer,
      $$HashtagStatsTableAnnotationComposer,
      $$HashtagStatsTableCreateCompanionBuilder,
      $$HashtagStatsTableUpdateCompanionBuilder,
      (
        HashtagStatRow,
        BaseReferences<_$AppDatabase, $HashtagStatsTable, HashtagStatRow>,
      ),
      HashtagStatRow,
      PrefetchHooks Function()
    >;
typedef $$NotificationsTableCreateCompanionBuilder =
    NotificationsCompanion Function({
      required String id,
      required String type,
      required String fromPubkey,
      Value<String?> targetEventId,
      Value<String?> videoAddressableId,
      Value<bool> hasCommentTarget,
      Value<String?> targetPubkey,
      Value<String?> content,
      required int timestamp,
      Value<bool> isRead,
      required DateTime cachedAt,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });
typedef $$NotificationsTableUpdateCompanionBuilder =
    NotificationsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> fromPubkey,
      Value<String?> targetEventId,
      Value<String?> videoAddressableId,
      Value<bool> hasCommentTarget,
      Value<String?> targetPubkey,
      Value<String?> content,
      Value<int> timestamp,
      Value<bool> isRead,
      Value<DateTime> cachedAt,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });

class $$NotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromPubkey => $composableBuilder(
    column: $table.fromPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetEventId => $composableBuilder(
    column: $table.targetEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoAddressableId => $composableBuilder(
    column: $table.videoAddressableId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasCommentTarget => $composableBuilder(
    column: $table.hasCommentTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPubkey => $composableBuilder(
    column: $table.targetPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromPubkey => $composableBuilder(
    column: $table.fromPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetEventId => $composableBuilder(
    column: $table.targetEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoAddressableId => $composableBuilder(
    column: $table.videoAddressableId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasCommentTarget => $composableBuilder(
    column: $table.hasCommentTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPubkey => $composableBuilder(
    column: $table.targetPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get fromPubkey => $composableBuilder(
    column: $table.fromPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetEventId => $composableBuilder(
    column: $table.targetEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoAddressableId => $composableBuilder(
    column: $table.videoAddressableId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasCommentTarget => $composableBuilder(
    column: $table.hasCommentTarget,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetPubkey => $composableBuilder(
    column: $table.targetPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );
}

class $$NotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationsTable,
          NotificationRow,
          $$NotificationsTableFilterComposer,
          $$NotificationsTableOrderingComposer,
          $$NotificationsTableAnnotationComposer,
          $$NotificationsTableCreateCompanionBuilder,
          $$NotificationsTableUpdateCompanionBuilder,
          (
            NotificationRow,
            BaseReferences<_$AppDatabase, $NotificationsTable, NotificationRow>,
          ),
          NotificationRow,
          PrefetchHooks Function()
        > {
  $$NotificationsTableTableManager(_$AppDatabase db, $NotificationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> fromPubkey = const Value.absent(),
                Value<String?> targetEventId = const Value.absent(),
                Value<String?> videoAddressableId = const Value.absent(),
                Value<bool> hasCommentTarget = const Value.absent(),
                Value<String?> targetPubkey = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion(
                id: id,
                type: type,
                fromPubkey: fromPubkey,
                targetEventId: targetEventId,
                videoAddressableId: videoAddressableId,
                hasCommentTarget: hasCommentTarget,
                targetPubkey: targetPubkey,
                content: content,
                timestamp: timestamp,
                isRead: isRead,
                cachedAt: cachedAt,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String fromPubkey,
                Value<String?> targetEventId = const Value.absent(),
                Value<String?> videoAddressableId = const Value.absent(),
                Value<bool> hasCommentTarget = const Value.absent(),
                Value<String?> targetPubkey = const Value.absent(),
                Value<String?> content = const Value.absent(),
                required int timestamp,
                Value<bool> isRead = const Value.absent(),
                required DateTime cachedAt,
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion.insert(
                id: id,
                type: type,
                fromPubkey: fromPubkey,
                targetEventId: targetEventId,
                videoAddressableId: videoAddressableId,
                hasCommentTarget: hasCommentTarget,
                targetPubkey: targetPubkey,
                content: content,
                timestamp: timestamp,
                isRead: isRead,
                cachedAt: cachedAt,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationsTable,
      NotificationRow,
      $$NotificationsTableFilterComposer,
      $$NotificationsTableOrderingComposer,
      $$NotificationsTableAnnotationComposer,
      $$NotificationsTableCreateCompanionBuilder,
      $$NotificationsTableUpdateCompanionBuilder,
      (
        NotificationRow,
        BaseReferences<_$AppDatabase, $NotificationsTable, NotificationRow>,
      ),
      NotificationRow,
      PrefetchHooks Function()
    >;
typedef $$PendingUploadsTableCreateCompanionBuilder =
    PendingUploadsCompanion Function({
      required String id,
      required String localVideoPath,
      required String nostrPubkey,
      required String status,
      required DateTime createdAt,
      Value<String?> cloudinaryPublicId,
      Value<String?> videoId,
      Value<String?> cdnUrl,
      Value<String?> errorMessage,
      Value<double?> uploadProgress,
      Value<String?> thumbnailPath,
      Value<String?> title,
      Value<String?> description,
      Value<String?> hashtags,
      Value<String?> nostrEventId,
      Value<DateTime?> completedAt,
      Value<int> retryCount,
      Value<int?> videoWidth,
      Value<int?> videoHeight,
      Value<int?> videoDurationMillis,
      Value<String?> proofManifestJson,
      Value<String?> streamingMp4Url,
      Value<String?> streamingHlsUrl,
      Value<String?> fallbackUrl,
      Value<int> rowid,
    });
typedef $$PendingUploadsTableUpdateCompanionBuilder =
    PendingUploadsCompanion Function({
      Value<String> id,
      Value<String> localVideoPath,
      Value<String> nostrPubkey,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<String?> cloudinaryPublicId,
      Value<String?> videoId,
      Value<String?> cdnUrl,
      Value<String?> errorMessage,
      Value<double?> uploadProgress,
      Value<String?> thumbnailPath,
      Value<String?> title,
      Value<String?> description,
      Value<String?> hashtags,
      Value<String?> nostrEventId,
      Value<DateTime?> completedAt,
      Value<int> retryCount,
      Value<int?> videoWidth,
      Value<int?> videoHeight,
      Value<int?> videoDurationMillis,
      Value<String?> proofManifestJson,
      Value<String?> streamingMp4Url,
      Value<String?> streamingHlsUrl,
      Value<String?> fallbackUrl,
      Value<int> rowid,
    });

class $$PendingUploadsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localVideoPath => $composableBuilder(
    column: $table.localVideoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nostrPubkey => $composableBuilder(
    column: $table.nostrPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudinaryPublicId => $composableBuilder(
    column: $table.cloudinaryPublicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cdnUrl => $composableBuilder(
    column: $table.cdnUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get uploadProgress => $composableBuilder(
    column: $table.uploadProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hashtags => $composableBuilder(
    column: $table.hashtags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nostrEventId => $composableBuilder(
    column: $table.nostrEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoWidth => $composableBuilder(
    column: $table.videoWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoDurationMillis => $composableBuilder(
    column: $table.videoDurationMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proofManifestJson => $composableBuilder(
    column: $table.proofManifestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamingMp4Url => $composableBuilder(
    column: $table.streamingMp4Url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamingHlsUrl => $composableBuilder(
    column: $table.streamingHlsUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fallbackUrl => $composableBuilder(
    column: $table.fallbackUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingUploadsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localVideoPath => $composableBuilder(
    column: $table.localVideoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nostrPubkey => $composableBuilder(
    column: $table.nostrPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudinaryPublicId => $composableBuilder(
    column: $table.cloudinaryPublicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cdnUrl => $composableBuilder(
    column: $table.cdnUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get uploadProgress => $composableBuilder(
    column: $table.uploadProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hashtags => $composableBuilder(
    column: $table.hashtags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nostrEventId => $composableBuilder(
    column: $table.nostrEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoWidth => $composableBuilder(
    column: $table.videoWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoDurationMillis => $composableBuilder(
    column: $table.videoDurationMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proofManifestJson => $composableBuilder(
    column: $table.proofManifestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamingMp4Url => $composableBuilder(
    column: $table.streamingMp4Url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamingHlsUrl => $composableBuilder(
    column: $table.streamingHlsUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fallbackUrl => $composableBuilder(
    column: $table.fallbackUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingUploadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localVideoPath => $composableBuilder(
    column: $table.localVideoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nostrPubkey => $composableBuilder(
    column: $table.nostrPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get cloudinaryPublicId => $composableBuilder(
    column: $table.cloudinaryPublicId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get cdnUrl =>
      $composableBuilder(column: $table.cdnUrl, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get uploadProgress => $composableBuilder(
    column: $table.uploadProgress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hashtags =>
      $composableBuilder(column: $table.hashtags, builder: (column) => column);

  GeneratedColumn<String> get nostrEventId => $composableBuilder(
    column: $table.nostrEventId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get videoWidth => $composableBuilder(
    column: $table.videoWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get videoDurationMillis => $composableBuilder(
    column: $table.videoDurationMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proofManifestJson => $composableBuilder(
    column: $table.proofManifestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamingMp4Url => $composableBuilder(
    column: $table.streamingMp4Url,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamingHlsUrl => $composableBuilder(
    column: $table.streamingHlsUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fallbackUrl => $composableBuilder(
    column: $table.fallbackUrl,
    builder: (column) => column,
  );
}

class $$PendingUploadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingUploadsTable,
          PendingUploadRow,
          $$PendingUploadsTableFilterComposer,
          $$PendingUploadsTableOrderingComposer,
          $$PendingUploadsTableAnnotationComposer,
          $$PendingUploadsTableCreateCompanionBuilder,
          $$PendingUploadsTableUpdateCompanionBuilder,
          (
            PendingUploadRow,
            BaseReferences<
              _$AppDatabase,
              $PendingUploadsTable,
              PendingUploadRow
            >,
          ),
          PendingUploadRow,
          PrefetchHooks Function()
        > {
  $$PendingUploadsTableTableManager(
    _$AppDatabase db,
    $PendingUploadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingUploadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingUploadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingUploadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> localVideoPath = const Value.absent(),
                Value<String> nostrPubkey = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> cloudinaryPublicId = const Value.absent(),
                Value<String?> videoId = const Value.absent(),
                Value<String?> cdnUrl = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<double?> uploadProgress = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> hashtags = const Value.absent(),
                Value<String?> nostrEventId = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> videoWidth = const Value.absent(),
                Value<int?> videoHeight = const Value.absent(),
                Value<int?> videoDurationMillis = const Value.absent(),
                Value<String?> proofManifestJson = const Value.absent(),
                Value<String?> streamingMp4Url = const Value.absent(),
                Value<String?> streamingHlsUrl = const Value.absent(),
                Value<String?> fallbackUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingUploadsCompanion(
                id: id,
                localVideoPath: localVideoPath,
                nostrPubkey: nostrPubkey,
                status: status,
                createdAt: createdAt,
                cloudinaryPublicId: cloudinaryPublicId,
                videoId: videoId,
                cdnUrl: cdnUrl,
                errorMessage: errorMessage,
                uploadProgress: uploadProgress,
                thumbnailPath: thumbnailPath,
                title: title,
                description: description,
                hashtags: hashtags,
                nostrEventId: nostrEventId,
                completedAt: completedAt,
                retryCount: retryCount,
                videoWidth: videoWidth,
                videoHeight: videoHeight,
                videoDurationMillis: videoDurationMillis,
                proofManifestJson: proofManifestJson,
                streamingMp4Url: streamingMp4Url,
                streamingHlsUrl: streamingHlsUrl,
                fallbackUrl: fallbackUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String localVideoPath,
                required String nostrPubkey,
                required String status,
                required DateTime createdAt,
                Value<String?> cloudinaryPublicId = const Value.absent(),
                Value<String?> videoId = const Value.absent(),
                Value<String?> cdnUrl = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<double?> uploadProgress = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> hashtags = const Value.absent(),
                Value<String?> nostrEventId = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> videoWidth = const Value.absent(),
                Value<int?> videoHeight = const Value.absent(),
                Value<int?> videoDurationMillis = const Value.absent(),
                Value<String?> proofManifestJson = const Value.absent(),
                Value<String?> streamingMp4Url = const Value.absent(),
                Value<String?> streamingHlsUrl = const Value.absent(),
                Value<String?> fallbackUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingUploadsCompanion.insert(
                id: id,
                localVideoPath: localVideoPath,
                nostrPubkey: nostrPubkey,
                status: status,
                createdAt: createdAt,
                cloudinaryPublicId: cloudinaryPublicId,
                videoId: videoId,
                cdnUrl: cdnUrl,
                errorMessage: errorMessage,
                uploadProgress: uploadProgress,
                thumbnailPath: thumbnailPath,
                title: title,
                description: description,
                hashtags: hashtags,
                nostrEventId: nostrEventId,
                completedAt: completedAt,
                retryCount: retryCount,
                videoWidth: videoWidth,
                videoHeight: videoHeight,
                videoDurationMillis: videoDurationMillis,
                proofManifestJson: proofManifestJson,
                streamingMp4Url: streamingMp4Url,
                streamingHlsUrl: streamingHlsUrl,
                fallbackUrl: fallbackUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingUploadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingUploadsTable,
      PendingUploadRow,
      $$PendingUploadsTableFilterComposer,
      $$PendingUploadsTableOrderingComposer,
      $$PendingUploadsTableAnnotationComposer,
      $$PendingUploadsTableCreateCompanionBuilder,
      $$PendingUploadsTableUpdateCompanionBuilder,
      (
        PendingUploadRow,
        BaseReferences<_$AppDatabase, $PendingUploadsTable, PendingUploadRow>,
      ),
      PendingUploadRow,
      PrefetchHooks Function()
    >;
typedef $$PersonalReactionsTableCreateCompanionBuilder =
    PersonalReactionsCompanion Function({
      required String targetEventId,
      required String reactionEventId,
      required String userPubkey,
      required int createdAt,
      Value<String?> addressableId,
      Value<int> rowid,
    });
typedef $$PersonalReactionsTableUpdateCompanionBuilder =
    PersonalReactionsCompanion Function({
      Value<String> targetEventId,
      Value<String> reactionEventId,
      Value<String> userPubkey,
      Value<int> createdAt,
      Value<String?> addressableId,
      Value<int> rowid,
    });

class $$PersonalReactionsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonalReactionsTable> {
  $$PersonalReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get targetEventId => $composableBuilder(
    column: $table.targetEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reactionEventId => $composableBuilder(
    column: $table.reactionEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonalReactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonalReactionsTable> {
  $$PersonalReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get targetEventId => $composableBuilder(
    column: $table.targetEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reactionEventId => $composableBuilder(
    column: $table.reactionEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonalReactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonalReactionsTable> {
  $$PersonalReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get targetEventId => $composableBuilder(
    column: $table.targetEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reactionEventId => $composableBuilder(
    column: $table.reactionEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => column,
  );
}

class $$PersonalReactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonalReactionsTable,
          PersonalReactionRow,
          $$PersonalReactionsTableFilterComposer,
          $$PersonalReactionsTableOrderingComposer,
          $$PersonalReactionsTableAnnotationComposer,
          $$PersonalReactionsTableCreateCompanionBuilder,
          $$PersonalReactionsTableUpdateCompanionBuilder,
          (
            PersonalReactionRow,
            BaseReferences<
              _$AppDatabase,
              $PersonalReactionsTable,
              PersonalReactionRow
            >,
          ),
          PersonalReactionRow,
          PrefetchHooks Function()
        > {
  $$PersonalReactionsTableTableManager(
    _$AppDatabase db,
    $PersonalReactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonalReactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonalReactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonalReactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> targetEventId = const Value.absent(),
                Value<String> reactionEventId = const Value.absent(),
                Value<String> userPubkey = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> addressableId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalReactionsCompanion(
                targetEventId: targetEventId,
                reactionEventId: reactionEventId,
                userPubkey: userPubkey,
                createdAt: createdAt,
                addressableId: addressableId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String targetEventId,
                required String reactionEventId,
                required String userPubkey,
                required int createdAt,
                Value<String?> addressableId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalReactionsCompanion.insert(
                targetEventId: targetEventId,
                reactionEventId: reactionEventId,
                userPubkey: userPubkey,
                createdAt: createdAt,
                addressableId: addressableId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonalReactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonalReactionsTable,
      PersonalReactionRow,
      $$PersonalReactionsTableFilterComposer,
      $$PersonalReactionsTableOrderingComposer,
      $$PersonalReactionsTableAnnotationComposer,
      $$PersonalReactionsTableCreateCompanionBuilder,
      $$PersonalReactionsTableUpdateCompanionBuilder,
      (
        PersonalReactionRow,
        BaseReferences<
          _$AppDatabase,
          $PersonalReactionsTable,
          PersonalReactionRow
        >,
      ),
      PersonalReactionRow,
      PrefetchHooks Function()
    >;
typedef $$PersonalRepostsTableCreateCompanionBuilder =
    PersonalRepostsCompanion Function({
      required String addressableId,
      required String repostEventId,
      required String originalAuthorPubkey,
      required String userPubkey,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$PersonalRepostsTableUpdateCompanionBuilder =
    PersonalRepostsCompanion Function({
      Value<String> addressableId,
      Value<String> repostEventId,
      Value<String> originalAuthorPubkey,
      Value<String> userPubkey,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$PersonalRepostsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonalRepostsTable> {
  $$PersonalRepostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repostEventId => $composableBuilder(
    column: $table.repostEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalAuthorPubkey => $composableBuilder(
    column: $table.originalAuthorPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonalRepostsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonalRepostsTable> {
  $$PersonalRepostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repostEventId => $composableBuilder(
    column: $table.repostEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalAuthorPubkey => $composableBuilder(
    column: $table.originalAuthorPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonalRepostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonalRepostsTable> {
  $$PersonalRepostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repostEventId => $composableBuilder(
    column: $table.repostEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalAuthorPubkey => $composableBuilder(
    column: $table.originalAuthorPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PersonalRepostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonalRepostsTable,
          PersonalRepostRow,
          $$PersonalRepostsTableFilterComposer,
          $$PersonalRepostsTableOrderingComposer,
          $$PersonalRepostsTableAnnotationComposer,
          $$PersonalRepostsTableCreateCompanionBuilder,
          $$PersonalRepostsTableUpdateCompanionBuilder,
          (
            PersonalRepostRow,
            BaseReferences<
              _$AppDatabase,
              $PersonalRepostsTable,
              PersonalRepostRow
            >,
          ),
          PersonalRepostRow,
          PrefetchHooks Function()
        > {
  $$PersonalRepostsTableTableManager(
    _$AppDatabase db,
    $PersonalRepostsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonalRepostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonalRepostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonalRepostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> addressableId = const Value.absent(),
                Value<String> repostEventId = const Value.absent(),
                Value<String> originalAuthorPubkey = const Value.absent(),
                Value<String> userPubkey = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalRepostsCompanion(
                addressableId: addressableId,
                repostEventId: repostEventId,
                originalAuthorPubkey: originalAuthorPubkey,
                userPubkey: userPubkey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String addressableId,
                required String repostEventId,
                required String originalAuthorPubkey,
                required String userPubkey,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PersonalRepostsCompanion.insert(
                addressableId: addressableId,
                repostEventId: repostEventId,
                originalAuthorPubkey: originalAuthorPubkey,
                userPubkey: userPubkey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonalRepostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonalRepostsTable,
      PersonalRepostRow,
      $$PersonalRepostsTableFilterComposer,
      $$PersonalRepostsTableOrderingComposer,
      $$PersonalRepostsTableAnnotationComposer,
      $$PersonalRepostsTableCreateCompanionBuilder,
      $$PersonalRepostsTableUpdateCompanionBuilder,
      (
        PersonalRepostRow,
        BaseReferences<_$AppDatabase, $PersonalRepostsTable, PersonalRepostRow>,
      ),
      PersonalRepostRow,
      PrefetchHooks Function()
    >;
typedef $$PersonalEventsTableCreateCompanionBuilder =
    PersonalEventsCompanion Function({
      required String id,
      required String pubkey,
      required int kind,
      required int createdAt,
      required String tags,
      required String content,
      required String sig,
      required int retention,
      Value<int> rowid,
    });
typedef $$PersonalEventsTableUpdateCompanionBuilder =
    PersonalEventsCompanion Function({
      Value<String> id,
      Value<String> pubkey,
      Value<int> kind,
      Value<int> createdAt,
      Value<String> tags,
      Value<String> content,
      Value<String> sig,
      Value<int> retention,
      Value<int> rowid,
    });

class $$PersonalEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonalEventsTable> {
  $$PersonalEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sig => $composableBuilder(
    column: $table.sig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retention => $composableBuilder(
    column: $table.retention,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonalEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonalEventsTable> {
  $$PersonalEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sig => $composableBuilder(
    column: $table.sig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retention => $composableBuilder(
    column: $table.retention,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonalEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonalEventsTable> {
  $$PersonalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sig =>
      $composableBuilder(column: $table.sig, builder: (column) => column);

  GeneratedColumn<int> get retention =>
      $composableBuilder(column: $table.retention, builder: (column) => column);
}

class $$PersonalEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonalEventsTable,
          PersonalEventRow,
          $$PersonalEventsTableFilterComposer,
          $$PersonalEventsTableOrderingComposer,
          $$PersonalEventsTableAnnotationComposer,
          $$PersonalEventsTableCreateCompanionBuilder,
          $$PersonalEventsTableUpdateCompanionBuilder,
          (
            PersonalEventRow,
            BaseReferences<
              _$AppDatabase,
              $PersonalEventsTable,
              PersonalEventRow
            >,
          ),
          PersonalEventRow,
          PrefetchHooks Function()
        > {
  $$PersonalEventsTableTableManager(
    _$AppDatabase db,
    $PersonalEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pubkey = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> sig = const Value.absent(),
                Value<int> retention = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalEventsCompanion(
                id: id,
                pubkey: pubkey,
                kind: kind,
                createdAt: createdAt,
                tags: tags,
                content: content,
                sig: sig,
                retention: retention,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String pubkey,
                required int kind,
                required int createdAt,
                required String tags,
                required String content,
                required String sig,
                required int retention,
                Value<int> rowid = const Value.absent(),
              }) => PersonalEventsCompanion.insert(
                id: id,
                pubkey: pubkey,
                kind: kind,
                createdAt: createdAt,
                tags: tags,
                content: content,
                sig: sig,
                retention: retention,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonalEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonalEventsTable,
      PersonalEventRow,
      $$PersonalEventsTableFilterComposer,
      $$PersonalEventsTableOrderingComposer,
      $$PersonalEventsTableAnnotationComposer,
      $$PersonalEventsTableCreateCompanionBuilder,
      $$PersonalEventsTableUpdateCompanionBuilder,
      (
        PersonalEventRow,
        BaseReferences<_$AppDatabase, $PersonalEventsTable, PersonalEventRow>,
      ),
      PersonalEventRow,
      PrefetchHooks Function()
    >;
typedef $$PendingActionsTableCreateCompanionBuilder =
    PendingActionsCompanion Function({
      required String id,
      required String type,
      required String targetId,
      Value<String?> authorPubkey,
      Value<String?> addressableId,
      Value<int?> targetKind,
      required String status,
      required String userPubkey,
      required DateTime createdAt,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<DateTime?> lastAttemptAt,
      Value<int> rowid,
    });
typedef $$PendingActionsTableUpdateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> targetId,
      Value<String?> authorPubkey,
      Value<String?> addressableId,
      Value<int?> targetKind,
      Value<String> status,
      Value<String> userPubkey,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<DateTime?> lastAttemptAt,
      Value<int> rowid,
    });

class $$PendingActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorPubkey => $composableBuilder(
    column: $table.authorPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorPubkey => $composableBuilder(
    column: $table.authorPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get authorPubkey => $composableBuilder(
    column: $table.authorPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addressableId => $composableBuilder(
    column: $table.addressableId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );
}

class $$PendingActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingActionsTable,
          PendingActionRow,
          $$PendingActionsTableFilterComposer,
          $$PendingActionsTableOrderingComposer,
          $$PendingActionsTableAnnotationComposer,
          $$PendingActionsTableCreateCompanionBuilder,
          $$PendingActionsTableUpdateCompanionBuilder,
          (
            PendingActionRow,
            BaseReferences<
              _$AppDatabase,
              $PendingActionsTable,
              PendingActionRow
            >,
          ),
          PendingActionRow,
          PrefetchHooks Function()
        > {
  $$PendingActionsTableTableManager(
    _$AppDatabase db,
    $PendingActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String?> authorPubkey = const Value.absent(),
                Value<String?> addressableId = const Value.absent(),
                Value<int?> targetKind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> userPubkey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingActionsCompanion(
                id: id,
                type: type,
                targetId: targetId,
                authorPubkey: authorPubkey,
                addressableId: addressableId,
                targetKind: targetKind,
                status: status,
                userPubkey: userPubkey,
                createdAt: createdAt,
                retryCount: retryCount,
                lastError: lastError,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String targetId,
                Value<String?> authorPubkey = const Value.absent(),
                Value<String?> addressableId = const Value.absent(),
                Value<int?> targetKind = const Value.absent(),
                required String status,
                required String userPubkey,
                required DateTime createdAt,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingActionsCompanion.insert(
                id: id,
                type: type,
                targetId: targetId,
                authorPubkey: authorPubkey,
                addressableId: addressableId,
                targetKind: targetKind,
                status: status,
                userPubkey: userPubkey,
                createdAt: createdAt,
                retryCount: retryCount,
                lastError: lastError,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingActionsTable,
      PendingActionRow,
      $$PendingActionsTableFilterComposer,
      $$PendingActionsTableOrderingComposer,
      $$PendingActionsTableAnnotationComposer,
      $$PendingActionsTableCreateCompanionBuilder,
      $$PendingActionsTableUpdateCompanionBuilder,
      (
        PendingActionRow,
        BaseReferences<_$AppDatabase, $PendingActionsTable, PendingActionRow>,
      ),
      PendingActionRow,
      PrefetchHooks Function()
    >;
typedef $$Nip05VerificationsTableCreateCompanionBuilder =
    Nip05VerificationsCompanion Function({
      required String pubkey,
      required String nip05,
      required String status,
      required DateTime verifiedAt,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$Nip05VerificationsTableUpdateCompanionBuilder =
    Nip05VerificationsCompanion Function({
      Value<String> pubkey,
      Value<String> nip05,
      Value<String> status,
      Value<DateTime> verifiedAt,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$Nip05VerificationsTableFilterComposer
    extends Composer<_$AppDatabase, $Nip05VerificationsTable> {
  $$Nip05VerificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nip05 => $composableBuilder(
    column: $table.nip05,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$Nip05VerificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $Nip05VerificationsTable> {
  $$Nip05VerificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nip05 => $composableBuilder(
    column: $table.nip05,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$Nip05VerificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $Nip05VerificationsTable> {
  $$Nip05VerificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<String> get nip05 =>
      $composableBuilder(column: $table.nip05, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$Nip05VerificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $Nip05VerificationsTable,
          Nip05VerificationRow,
          $$Nip05VerificationsTableFilterComposer,
          $$Nip05VerificationsTableOrderingComposer,
          $$Nip05VerificationsTableAnnotationComposer,
          $$Nip05VerificationsTableCreateCompanionBuilder,
          $$Nip05VerificationsTableUpdateCompanionBuilder,
          (
            Nip05VerificationRow,
            BaseReferences<
              _$AppDatabase,
              $Nip05VerificationsTable,
              Nip05VerificationRow
            >,
          ),
          Nip05VerificationRow,
          PrefetchHooks Function()
        > {
  $$Nip05VerificationsTableTableManager(
    _$AppDatabase db,
    $Nip05VerificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$Nip05VerificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$Nip05VerificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$Nip05VerificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> pubkey = const Value.absent(),
                Value<String> nip05 = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> verifiedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => Nip05VerificationsCompanion(
                pubkey: pubkey,
                nip05: nip05,
                status: status,
                verifiedAt: verifiedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkey,
                required String nip05,
                required String status,
                required DateTime verifiedAt,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => Nip05VerificationsCompanion.insert(
                pubkey: pubkey,
                nip05: nip05,
                status: status,
                verifiedAt: verifiedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$Nip05VerificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $Nip05VerificationsTable,
      Nip05VerificationRow,
      $$Nip05VerificationsTableFilterComposer,
      $$Nip05VerificationsTableOrderingComposer,
      $$Nip05VerificationsTableAnnotationComposer,
      $$Nip05VerificationsTableCreateCompanionBuilder,
      $$Nip05VerificationsTableUpdateCompanionBuilder,
      (
        Nip05VerificationRow,
        BaseReferences<
          _$AppDatabase,
          $Nip05VerificationsTable,
          Nip05VerificationRow
        >,
      ),
      Nip05VerificationRow,
      PrefetchHooks Function()
    >;
typedef $$DraftsTableCreateCompanionBuilder =
    DraftsCompanion Function({
      required String id,
      Value<String> title,
      Value<String> description,
      Value<String> publishStatus,
      Value<int> publishAttempts,
      Value<String?> publishError,
      required DateTime createdAt,
      required DateTime lastModified,
      required String data,
      Value<String?> renderedFilePath,
      Value<String?> renderedThumbnailPath,
      Value<String?> customThumbnailPath,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });
typedef $$DraftsTableUpdateCompanionBuilder =
    DraftsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> description,
      Value<String> publishStatus,
      Value<int> publishAttempts,
      Value<String?> publishError,
      Value<DateTime> createdAt,
      Value<DateTime> lastModified,
      Value<String> data,
      Value<String?> renderedFilePath,
      Value<String?> renderedThumbnailPath,
      Value<String?> customThumbnailPath,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });

class $$DraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishStatus => $composableBuilder(
    column: $table.publishStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishAttempts => $composableBuilder(
    column: $table.publishAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishError => $composableBuilder(
    column: $table.publishError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get renderedFilePath => $composableBuilder(
    column: $table.renderedFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get renderedThumbnailPath => $composableBuilder(
    column: $table.renderedThumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customThumbnailPath => $composableBuilder(
    column: $table.customThumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishStatus => $composableBuilder(
    column: $table.publishStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishAttempts => $composableBuilder(
    column: $table.publishAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishError => $composableBuilder(
    column: $table.publishError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get renderedFilePath => $composableBuilder(
    column: $table.renderedFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get renderedThumbnailPath => $composableBuilder(
    column: $table.renderedThumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customThumbnailPath => $composableBuilder(
    column: $table.customThumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publishStatus => $composableBuilder(
    column: $table.publishStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get publishAttempts => $composableBuilder(
    column: $table.publishAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publishError => $composableBuilder(
    column: $table.publishError,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get renderedFilePath => $composableBuilder(
    column: $table.renderedFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get renderedThumbnailPath => $composableBuilder(
    column: $table.renderedThumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customThumbnailPath => $composableBuilder(
    column: $table.customThumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          DraftRow,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (DraftRow, BaseReferences<_$AppDatabase, $DraftsTable, DraftRow>),
          DraftRow,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> publishStatus = const Value.absent(),
                Value<int> publishAttempts = const Value.absent(),
                Value<String?> publishError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastModified = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> renderedFilePath = const Value.absent(),
                Value<String?> renderedThumbnailPath = const Value.absent(),
                Value<String?> customThumbnailPath = const Value.absent(),
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                id: id,
                title: title,
                description: description,
                publishStatus: publishStatus,
                publishAttempts: publishAttempts,
                publishError: publishError,
                createdAt: createdAt,
                lastModified: lastModified,
                data: data,
                renderedFilePath: renderedFilePath,
                renderedThumbnailPath: renderedThumbnailPath,
                customThumbnailPath: customThumbnailPath,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> publishStatus = const Value.absent(),
                Value<int> publishAttempts = const Value.absent(),
                Value<String?> publishError = const Value.absent(),
                required DateTime createdAt,
                required DateTime lastModified,
                required String data,
                Value<String?> renderedFilePath = const Value.absent(),
                Value<String?> renderedThumbnailPath = const Value.absent(),
                Value<String?> customThumbnailPath = const Value.absent(),
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                id: id,
                title: title,
                description: description,
                publishStatus: publishStatus,
                publishAttempts: publishAttempts,
                publishError: publishError,
                createdAt: createdAt,
                lastModified: lastModified,
                data: data,
                renderedFilePath: renderedFilePath,
                renderedThumbnailPath: renderedThumbnailPath,
                customThumbnailPath: customThumbnailPath,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      DraftRow,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (DraftRow, BaseReferences<_$AppDatabase, $DraftsTable, DraftRow>),
      DraftRow,
      PrefetchHooks Function()
    >;
typedef $$ClipsTableCreateCompanionBuilder =
    ClipsCompanion Function({
      required String id,
      Value<String?> draftId,
      Value<int> orderIndex,
      required int durationMs,
      required DateTime recordedAt,
      required String data,
      Value<String?> filePath,
      Value<String?> thumbnailPath,
      Value<String?> ownerPubkey,
      Value<DateTime?> deletedAt,
      Value<String?> categoryId,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$ClipsTableUpdateCompanionBuilder =
    ClipsCompanion Function({
      Value<String> id,
      Value<String?> draftId,
      Value<int> orderIndex,
      Value<int> durationMs,
      Value<DateTime> recordedAt,
      Value<String> data,
      Value<String?> filePath,
      Value<String?> thumbnailPath,
      Value<String?> ownerPubkey,
      Value<DateTime?> deletedAt,
      Value<String?> categoryId,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

class $$ClipsTableFilterComposer extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClipsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );
}

class $$ClipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClipsTable,
          ClipRow,
          $$ClipsTableFilterComposer,
          $$ClipsTableOrderingComposer,
          $$ClipsTableAnnotationComposer,
          $$ClipsTableCreateCompanionBuilder,
          $$ClipsTableUpdateCompanionBuilder,
          (ClipRow, BaseReferences<_$AppDatabase, $ClipsTable, ClipRow>),
          ClipRow,
          PrefetchHooks Function()
        > {
  $$ClipsTableTableManager(_$AppDatabase db, $ClipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> draftId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> ownerPubkey = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClipsCompanion(
                id: id,
                draftId: draftId,
                orderIndex: orderIndex,
                durationMs: durationMs,
                recordedAt: recordedAt,
                data: data,
                filePath: filePath,
                thumbnailPath: thumbnailPath,
                ownerPubkey: ownerPubkey,
                deletedAt: deletedAt,
                categoryId: categoryId,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> draftId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                required int durationMs,
                required DateTime recordedAt,
                required String data,
                Value<String?> filePath = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> ownerPubkey = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClipsCompanion.insert(
                id: id,
                draftId: draftId,
                orderIndex: orderIndex,
                durationMs: durationMs,
                recordedAt: recordedAt,
                data: data,
                filePath: filePath,
                thumbnailPath: thumbnailPath,
                ownerPubkey: ownerPubkey,
                deletedAt: deletedAt,
                categoryId: categoryId,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClipsTable,
      ClipRow,
      $$ClipsTableFilterComposer,
      $$ClipsTableOrderingComposer,
      $$ClipsTableAnnotationComposer,
      $$ClipsTableCreateCompanionBuilder,
      $$ClipsTableUpdateCompanionBuilder,
      (ClipRow, BaseReferences<_$AppDatabase, $ClipsTable, ClipRow>),
      ClipRow,
      PrefetchHooks Function()
    >;
typedef $$ClipCategoriesTableCreateCompanionBuilder =
    ClipCategoriesCompanion Function({
      required String id,
      required String name,
      Value<int> orderIndex,
      required DateTime createdAt,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });
typedef $$ClipCategoriesTableUpdateCompanionBuilder =
    ClipCategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> orderIndex,
      Value<DateTime> createdAt,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });

class $$ClipCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $ClipCategoriesTable> {
  $$ClipCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClipCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClipCategoriesTable> {
  $$ClipCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClipCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClipCategoriesTable> {
  $$ClipCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );
}

class $$ClipCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClipCategoriesTable,
          ClipCategoryRow,
          $$ClipCategoriesTableFilterComposer,
          $$ClipCategoriesTableOrderingComposer,
          $$ClipCategoriesTableAnnotationComposer,
          $$ClipCategoriesTableCreateCompanionBuilder,
          $$ClipCategoriesTableUpdateCompanionBuilder,
          (
            ClipCategoryRow,
            BaseReferences<
              _$AppDatabase,
              $ClipCategoriesTable,
              ClipCategoryRow
            >,
          ),
          ClipCategoryRow,
          PrefetchHooks Function()
        > {
  $$ClipCategoriesTableTableManager(
    _$AppDatabase db,
    $ClipCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClipCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClipCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClipCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClipCategoriesCompanion(
                id: id,
                name: name,
                orderIndex: orderIndex,
                createdAt: createdAt,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> orderIndex = const Value.absent(),
                required DateTime createdAt,
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClipCategoriesCompanion.insert(
                id: id,
                name: name,
                orderIndex: orderIndex,
                createdAt: createdAt,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClipCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClipCategoriesTable,
      ClipCategoryRow,
      $$ClipCategoriesTableFilterComposer,
      $$ClipCategoriesTableOrderingComposer,
      $$ClipCategoriesTableAnnotationComposer,
      $$ClipCategoriesTableCreateCompanionBuilder,
      $$ClipCategoriesTableUpdateCompanionBuilder,
      (
        ClipCategoryRow,
        BaseReferences<_$AppDatabase, $ClipCategoriesTable, ClipCategoryRow>,
      ),
      ClipCategoryRow,
      PrefetchHooks Function()
    >;
typedef $$DirectMessagesTableCreateCompanionBuilder =
    DirectMessagesCompanion Function({
      required String id,
      required String conversationId,
      required String senderPubkey,
      required String content,
      required int createdAt,
      Value<String?> replyToId,
      required String giftWrapId,
      Value<String?> subject,
      Value<String?> tagsJson,
      Value<int> messageKind,
      Value<String?> fileType,
      Value<String?> encryptionAlgorithm,
      Value<String?> decryptionKey,
      Value<String?> decryptionNonce,
      Value<String?> fileHash,
      Value<String?> originalFileHash,
      Value<int?> fileSize,
      Value<String?> dimensions,
      Value<String?> blurhash,
      Value<String?> thumbnailUrl,
      Value<bool> isDeleted,
      Value<bool> twinCollapsed,
      Value<String> ownerPubkey,
      Value<String?> sendBatchId,
      Value<String?> deletionRumorJson,
      Value<String?> deletionPublishStatus,
      Value<int> rowid,
    });
typedef $$DirectMessagesTableUpdateCompanionBuilder =
    DirectMessagesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> senderPubkey,
      Value<String> content,
      Value<int> createdAt,
      Value<String?> replyToId,
      Value<String> giftWrapId,
      Value<String?> subject,
      Value<String?> tagsJson,
      Value<int> messageKind,
      Value<String?> fileType,
      Value<String?> encryptionAlgorithm,
      Value<String?> decryptionKey,
      Value<String?> decryptionNonce,
      Value<String?> fileHash,
      Value<String?> originalFileHash,
      Value<int?> fileSize,
      Value<String?> dimensions,
      Value<String?> blurhash,
      Value<String?> thumbnailUrl,
      Value<bool> isDeleted,
      Value<bool> twinCollapsed,
      Value<String> ownerPubkey,
      Value<String?> sendBatchId,
      Value<String?> deletionRumorJson,
      Value<String?> deletionPublishStatus,
      Value<int> rowid,
    });

class $$DirectMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $DirectMessagesTable> {
  $$DirectMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPubkey => $composableBuilder(
    column: $table.senderPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptionAlgorithm => $composableBuilder(
    column: $table.encryptionAlgorithm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decryptionKey => $composableBuilder(
    column: $table.decryptionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decryptionNonce => $composableBuilder(
    column: $table.decryptionNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalFileHash => $composableBuilder(
    column: $table.originalFileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blurhash => $composableBuilder(
    column: $table.blurhash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get twinCollapsed => $composableBuilder(
    column: $table.twinCollapsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sendBatchId => $composableBuilder(
    column: $table.sendBatchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletionRumorJson => $composableBuilder(
    column: $table.deletionRumorJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletionPublishStatus => $composableBuilder(
    column: $table.deletionPublishStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DirectMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $DirectMessagesTable> {
  $$DirectMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPubkey => $composableBuilder(
    column: $table.senderPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptionAlgorithm => $composableBuilder(
    column: $table.encryptionAlgorithm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decryptionKey => $composableBuilder(
    column: $table.decryptionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decryptionNonce => $composableBuilder(
    column: $table.decryptionNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalFileHash => $composableBuilder(
    column: $table.originalFileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blurhash => $composableBuilder(
    column: $table.blurhash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get twinCollapsed => $composableBuilder(
    column: $table.twinCollapsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sendBatchId => $composableBuilder(
    column: $table.sendBatchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletionRumorJson => $composableBuilder(
    column: $table.deletionRumorJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletionPublishStatus => $composableBuilder(
    column: $table.deletionPublishStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DirectMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DirectMessagesTable> {
  $$DirectMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderPubkey => $composableBuilder(
    column: $table.senderPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<int> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileType =>
      $composableBuilder(column: $table.fileType, builder: (column) => column);

  GeneratedColumn<String> get encryptionAlgorithm => $composableBuilder(
    column: $table.encryptionAlgorithm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decryptionKey => $composableBuilder(
    column: $table.decryptionKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decryptionNonce => $composableBuilder(
    column: $table.decryptionNonce,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<String> get originalFileHash => $composableBuilder(
    column: $table.originalFileHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blurhash =>
      $composableBuilder(column: $table.blurhash, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get twinCollapsed => $composableBuilder(
    column: $table.twinCollapsed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sendBatchId => $composableBuilder(
    column: $table.sendBatchId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletionRumorJson => $composableBuilder(
    column: $table.deletionRumorJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletionPublishStatus => $composableBuilder(
    column: $table.deletionPublishStatus,
    builder: (column) => column,
  );
}

class $$DirectMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DirectMessagesTable,
          DirectMessageRow,
          $$DirectMessagesTableFilterComposer,
          $$DirectMessagesTableOrderingComposer,
          $$DirectMessagesTableAnnotationComposer,
          $$DirectMessagesTableCreateCompanionBuilder,
          $$DirectMessagesTableUpdateCompanionBuilder,
          (
            DirectMessageRow,
            BaseReferences<
              _$AppDatabase,
              $DirectMessagesTable,
              DirectMessageRow
            >,
          ),
          DirectMessageRow,
          PrefetchHooks Function()
        > {
  $$DirectMessagesTableTableManager(
    _$AppDatabase db,
    $DirectMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DirectMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DirectMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DirectMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderPubkey = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String> giftWrapId = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<int> messageKind = const Value.absent(),
                Value<String?> fileType = const Value.absent(),
                Value<String?> encryptionAlgorithm = const Value.absent(),
                Value<String?> decryptionKey = const Value.absent(),
                Value<String?> decryptionNonce = const Value.absent(),
                Value<String?> fileHash = const Value.absent(),
                Value<String?> originalFileHash = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String?> dimensions = const Value.absent(),
                Value<String?> blurhash = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> twinCollapsed = const Value.absent(),
                Value<String> ownerPubkey = const Value.absent(),
                Value<String?> sendBatchId = const Value.absent(),
                Value<String?> deletionRumorJson = const Value.absent(),
                Value<String?> deletionPublishStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DirectMessagesCompanion(
                id: id,
                conversationId: conversationId,
                senderPubkey: senderPubkey,
                content: content,
                createdAt: createdAt,
                replyToId: replyToId,
                giftWrapId: giftWrapId,
                subject: subject,
                tagsJson: tagsJson,
                messageKind: messageKind,
                fileType: fileType,
                encryptionAlgorithm: encryptionAlgorithm,
                decryptionKey: decryptionKey,
                decryptionNonce: decryptionNonce,
                fileHash: fileHash,
                originalFileHash: originalFileHash,
                fileSize: fileSize,
                dimensions: dimensions,
                blurhash: blurhash,
                thumbnailUrl: thumbnailUrl,
                isDeleted: isDeleted,
                twinCollapsed: twinCollapsed,
                ownerPubkey: ownerPubkey,
                sendBatchId: sendBatchId,
                deletionRumorJson: deletionRumorJson,
                deletionPublishStatus: deletionPublishStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String senderPubkey,
                required String content,
                required int createdAt,
                Value<String?> replyToId = const Value.absent(),
                required String giftWrapId,
                Value<String?> subject = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<int> messageKind = const Value.absent(),
                Value<String?> fileType = const Value.absent(),
                Value<String?> encryptionAlgorithm = const Value.absent(),
                Value<String?> decryptionKey = const Value.absent(),
                Value<String?> decryptionNonce = const Value.absent(),
                Value<String?> fileHash = const Value.absent(),
                Value<String?> originalFileHash = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String?> dimensions = const Value.absent(),
                Value<String?> blurhash = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> twinCollapsed = const Value.absent(),
                Value<String> ownerPubkey = const Value.absent(),
                Value<String?> sendBatchId = const Value.absent(),
                Value<String?> deletionRumorJson = const Value.absent(),
                Value<String?> deletionPublishStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DirectMessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderPubkey: senderPubkey,
                content: content,
                createdAt: createdAt,
                replyToId: replyToId,
                giftWrapId: giftWrapId,
                subject: subject,
                tagsJson: tagsJson,
                messageKind: messageKind,
                fileType: fileType,
                encryptionAlgorithm: encryptionAlgorithm,
                decryptionKey: decryptionKey,
                decryptionNonce: decryptionNonce,
                fileHash: fileHash,
                originalFileHash: originalFileHash,
                fileSize: fileSize,
                dimensions: dimensions,
                blurhash: blurhash,
                thumbnailUrl: thumbnailUrl,
                isDeleted: isDeleted,
                twinCollapsed: twinCollapsed,
                ownerPubkey: ownerPubkey,
                sendBatchId: sendBatchId,
                deletionRumorJson: deletionRumorJson,
                deletionPublishStatus: deletionPublishStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DirectMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DirectMessagesTable,
      DirectMessageRow,
      $$DirectMessagesTableFilterComposer,
      $$DirectMessagesTableOrderingComposer,
      $$DirectMessagesTableAnnotationComposer,
      $$DirectMessagesTableCreateCompanionBuilder,
      $$DirectMessagesTableUpdateCompanionBuilder,
      (
        DirectMessageRow,
        BaseReferences<_$AppDatabase, $DirectMessagesTable, DirectMessageRow>,
      ),
      DirectMessageRow,
      PrefetchHooks Function()
    >;
typedef $$DmMessageReactionsTableCreateCompanionBuilder =
    DmMessageReactionsCompanion Function({
      required String id,
      required String conversationId,
      required String targetMessageId,
      required String targetMessageAuthor,
      required String reactorPubkey,
      required String emoji,
      required int createdAt,
      Value<String?> giftWrapId,
      required String ownerPubkey,
      Value<bool> isDeleted,
      Value<String?> rumorEventJson,
      Value<String?> publishStatus,
      Value<int> rowid,
    });
typedef $$DmMessageReactionsTableUpdateCompanionBuilder =
    DmMessageReactionsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> targetMessageId,
      Value<String> targetMessageAuthor,
      Value<String> reactorPubkey,
      Value<String> emoji,
      Value<int> createdAt,
      Value<String?> giftWrapId,
      Value<String> ownerPubkey,
      Value<bool> isDeleted,
      Value<String?> rumorEventJson,
      Value<String?> publishStatus,
      Value<int> rowid,
    });

class $$DmMessageReactionsTableFilterComposer
    extends Composer<_$AppDatabase, $DmMessageReactionsTable> {
  $$DmMessageReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetMessageId => $composableBuilder(
    column: $table.targetMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetMessageAuthor => $composableBuilder(
    column: $table.targetMessageAuthor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reactorPubkey => $composableBuilder(
    column: $table.reactorPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rumorEventJson => $composableBuilder(
    column: $table.rumorEventJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishStatus => $composableBuilder(
    column: $table.publishStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DmMessageReactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DmMessageReactionsTable> {
  $$DmMessageReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetMessageId => $composableBuilder(
    column: $table.targetMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetMessageAuthor => $composableBuilder(
    column: $table.targetMessageAuthor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reactorPubkey => $composableBuilder(
    column: $table.reactorPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rumorEventJson => $composableBuilder(
    column: $table.rumorEventJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishStatus => $composableBuilder(
    column: $table.publishStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DmMessageReactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DmMessageReactionsTable> {
  $$DmMessageReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetMessageId => $composableBuilder(
    column: $table.targetMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetMessageAuthor => $composableBuilder(
    column: $table.targetMessageAuthor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reactorPubkey => $composableBuilder(
    column: $table.reactorPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get rumorEventJson => $composableBuilder(
    column: $table.rumorEventJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publishStatus => $composableBuilder(
    column: $table.publishStatus,
    builder: (column) => column,
  );
}

class $$DmMessageReactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DmMessageReactionsTable,
          DmReactionRow,
          $$DmMessageReactionsTableFilterComposer,
          $$DmMessageReactionsTableOrderingComposer,
          $$DmMessageReactionsTableAnnotationComposer,
          $$DmMessageReactionsTableCreateCompanionBuilder,
          $$DmMessageReactionsTableUpdateCompanionBuilder,
          (
            DmReactionRow,
            BaseReferences<
              _$AppDatabase,
              $DmMessageReactionsTable,
              DmReactionRow
            >,
          ),
          DmReactionRow,
          PrefetchHooks Function()
        > {
  $$DmMessageReactionsTableTableManager(
    _$AppDatabase db,
    $DmMessageReactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DmMessageReactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DmMessageReactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DmMessageReactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> targetMessageId = const Value.absent(),
                Value<String> targetMessageAuthor = const Value.absent(),
                Value<String> reactorPubkey = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> giftWrapId = const Value.absent(),
                Value<String> ownerPubkey = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> rumorEventJson = const Value.absent(),
                Value<String?> publishStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DmMessageReactionsCompanion(
                id: id,
                conversationId: conversationId,
                targetMessageId: targetMessageId,
                targetMessageAuthor: targetMessageAuthor,
                reactorPubkey: reactorPubkey,
                emoji: emoji,
                createdAt: createdAt,
                giftWrapId: giftWrapId,
                ownerPubkey: ownerPubkey,
                isDeleted: isDeleted,
                rumorEventJson: rumorEventJson,
                publishStatus: publishStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String targetMessageId,
                required String targetMessageAuthor,
                required String reactorPubkey,
                required String emoji,
                required int createdAt,
                Value<String?> giftWrapId = const Value.absent(),
                required String ownerPubkey,
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> rumorEventJson = const Value.absent(),
                Value<String?> publishStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DmMessageReactionsCompanion.insert(
                id: id,
                conversationId: conversationId,
                targetMessageId: targetMessageId,
                targetMessageAuthor: targetMessageAuthor,
                reactorPubkey: reactorPubkey,
                emoji: emoji,
                createdAt: createdAt,
                giftWrapId: giftWrapId,
                ownerPubkey: ownerPubkey,
                isDeleted: isDeleted,
                rumorEventJson: rumorEventJson,
                publishStatus: publishStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DmMessageReactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DmMessageReactionsTable,
      DmReactionRow,
      $$DmMessageReactionsTableFilterComposer,
      $$DmMessageReactionsTableOrderingComposer,
      $$DmMessageReactionsTableAnnotationComposer,
      $$DmMessageReactionsTableCreateCompanionBuilder,
      $$DmMessageReactionsTableUpdateCompanionBuilder,
      (
        DmReactionRow,
        BaseReferences<_$AppDatabase, $DmMessageReactionsTable, DmReactionRow>,
      ),
      DmReactionRow,
      PrefetchHooks Function()
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      required String participantPubkeys,
      Value<bool> isGroup,
      Value<String?> lastMessageContent,
      Value<int?> lastMessageTimestamp,
      Value<String?> lastMessageSenderPubkey,
      Value<String?> subject,
      Value<bool> isRead,
      Value<int?> lastReadTimestamp,
      Value<bool> currentUserHasSent,
      required int createdAt,
      Value<String> ownerPubkey,
      Value<String?> dmProtocol,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> participantPubkeys,
      Value<bool> isGroup,
      Value<String?> lastMessageContent,
      Value<int?> lastMessageTimestamp,
      Value<String?> lastMessageSenderPubkey,
      Value<String?> subject,
      Value<bool> isRead,
      Value<int?> lastReadTimestamp,
      Value<bool> currentUserHasSent,
      Value<int> createdAt,
      Value<String> ownerPubkey,
      Value<String?> dmProtocol,
      Value<int> rowid,
    });

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantPubkeys => $composableBuilder(
    column: $table.participantPubkeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageContent => $composableBuilder(
    column: $table.lastMessageContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageTimestamp => $composableBuilder(
    column: $table.lastMessageTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageSenderPubkey => $composableBuilder(
    column: $table.lastMessageSenderPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadTimestamp => $composableBuilder(
    column: $table.lastReadTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get currentUserHasSent => $composableBuilder(
    column: $table.currentUserHasSent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dmProtocol => $composableBuilder(
    column: $table.dmProtocol,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantPubkeys => $composableBuilder(
    column: $table.participantPubkeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageContent => $composableBuilder(
    column: $table.lastMessageContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageTimestamp => $composableBuilder(
    column: $table.lastMessageTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageSenderPubkey => $composableBuilder(
    column: $table.lastMessageSenderPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadTimestamp => $composableBuilder(
    column: $table.lastReadTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get currentUserHasSent => $composableBuilder(
    column: $table.currentUserHasSent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dmProtocol => $composableBuilder(
    column: $table.dmProtocol,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get participantPubkeys => $composableBuilder(
    column: $table.participantPubkeys,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isGroup =>
      $composableBuilder(column: $table.isGroup, builder: (column) => column);

  GeneratedColumn<String> get lastMessageContent => $composableBuilder(
    column: $table.lastMessageContent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageTimestamp => $composableBuilder(
    column: $table.lastMessageTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageSenderPubkey => $composableBuilder(
    column: $table.lastMessageSenderPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<int> get lastReadTimestamp => $composableBuilder(
    column: $table.lastReadTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get currentUserHasSent => $composableBuilder(
    column: $table.currentUserHasSent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dmProtocol => $composableBuilder(
    column: $table.dmProtocol,
    builder: (column) => column,
  );
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          ConversationRow,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (
            ConversationRow,
            BaseReferences<_$AppDatabase, $ConversationsTable, ConversationRow>,
          ),
          ConversationRow,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> participantPubkeys = const Value.absent(),
                Value<bool> isGroup = const Value.absent(),
                Value<String?> lastMessageContent = const Value.absent(),
                Value<int?> lastMessageTimestamp = const Value.absent(),
                Value<String?> lastMessageSenderPubkey = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<int?> lastReadTimestamp = const Value.absent(),
                Value<bool> currentUserHasSent = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> ownerPubkey = const Value.absent(),
                Value<String?> dmProtocol = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                participantPubkeys: participantPubkeys,
                isGroup: isGroup,
                lastMessageContent: lastMessageContent,
                lastMessageTimestamp: lastMessageTimestamp,
                lastMessageSenderPubkey: lastMessageSenderPubkey,
                subject: subject,
                isRead: isRead,
                lastReadTimestamp: lastReadTimestamp,
                currentUserHasSent: currentUserHasSent,
                createdAt: createdAt,
                ownerPubkey: ownerPubkey,
                dmProtocol: dmProtocol,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String participantPubkeys,
                Value<bool> isGroup = const Value.absent(),
                Value<String?> lastMessageContent = const Value.absent(),
                Value<int?> lastMessageTimestamp = const Value.absent(),
                Value<String?> lastMessageSenderPubkey = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<int?> lastReadTimestamp = const Value.absent(),
                Value<bool> currentUserHasSent = const Value.absent(),
                required int createdAt,
                Value<String> ownerPubkey = const Value.absent(),
                Value<String?> dmProtocol = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                participantPubkeys: participantPubkeys,
                isGroup: isGroup,
                lastMessageContent: lastMessageContent,
                lastMessageTimestamp: lastMessageTimestamp,
                lastMessageSenderPubkey: lastMessageSenderPubkey,
                subject: subject,
                isRead: isRead,
                lastReadTimestamp: lastReadTimestamp,
                currentUserHasSent: currentUserHasSent,
                createdAt: createdAt,
                ownerPubkey: ownerPubkey,
                dmProtocol: dmProtocol,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      ConversationRow,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (
        ConversationRow,
        BaseReferences<_$AppDatabase, $ConversationsTable, ConversationRow>,
      ),
      ConversationRow,
      PrefetchHooks Function()
    >;
typedef $$OutgoingDmsTableCreateCompanionBuilder =
    OutgoingDmsCompanion Function({
      required String id,
      required String conversationId,
      required String recipientPubkey,
      required String content,
      required int createdAt,
      required String rumorEventJson,
      Value<int> messageKind,
      Value<String?> replyToId,
      required String recipientWrapStatus,
      required String selfWrapStatus,
      Value<String?> recipientWrapEventId,
      Value<String?> selfWrapEventId,
      Value<int> retryCount,
      Value<String?> recipientWrapLastError,
      Value<String?> selfWrapLastError,
      Value<DateTime?> lastAttemptAt,
      required DateTime queuedAt,
      required String ownerPubkey,
      Value<String?> sendBatchId,
      Value<int> rowid,
    });
typedef $$OutgoingDmsTableUpdateCompanionBuilder =
    OutgoingDmsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> recipientPubkey,
      Value<String> content,
      Value<int> createdAt,
      Value<String> rumorEventJson,
      Value<int> messageKind,
      Value<String?> replyToId,
      Value<String> recipientWrapStatus,
      Value<String> selfWrapStatus,
      Value<String?> recipientWrapEventId,
      Value<String?> selfWrapEventId,
      Value<int> retryCount,
      Value<String?> recipientWrapLastError,
      Value<String?> selfWrapLastError,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime> queuedAt,
      Value<String> ownerPubkey,
      Value<String?> sendBatchId,
      Value<int> rowid,
    });

class $$OutgoingDmsTableFilterComposer
    extends Composer<_$AppDatabase, $OutgoingDmsTable> {
  $$OutgoingDmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientPubkey => $composableBuilder(
    column: $table.recipientPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rumorEventJson => $composableBuilder(
    column: $table.rumorEventJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientWrapStatus => $composableBuilder(
    column: $table.recipientWrapStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selfWrapStatus => $composableBuilder(
    column: $table.selfWrapStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientWrapEventId => $composableBuilder(
    column: $table.recipientWrapEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selfWrapEventId => $composableBuilder(
    column: $table.selfWrapEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientWrapLastError => $composableBuilder(
    column: $table.recipientWrapLastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selfWrapLastError => $composableBuilder(
    column: $table.selfWrapLastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sendBatchId => $composableBuilder(
    column: $table.sendBatchId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutgoingDmsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutgoingDmsTable> {
  $$OutgoingDmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientPubkey => $composableBuilder(
    column: $table.recipientPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rumorEventJson => $composableBuilder(
    column: $table.rumorEventJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientWrapStatus => $composableBuilder(
    column: $table.recipientWrapStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selfWrapStatus => $composableBuilder(
    column: $table.selfWrapStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientWrapEventId => $composableBuilder(
    column: $table.recipientWrapEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selfWrapEventId => $composableBuilder(
    column: $table.selfWrapEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientWrapLastError => $composableBuilder(
    column: $table.recipientWrapLastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selfWrapLastError => $composableBuilder(
    column: $table.selfWrapLastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sendBatchId => $composableBuilder(
    column: $table.sendBatchId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutgoingDmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutgoingDmsTable> {
  $$OutgoingDmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientPubkey => $composableBuilder(
    column: $table.recipientPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get rumorEventJson => $composableBuilder(
    column: $table.rumorEventJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<String> get recipientWrapStatus => $composableBuilder(
    column: $table.recipientWrapStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selfWrapStatus => $composableBuilder(
    column: $table.selfWrapStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientWrapEventId => $composableBuilder(
    column: $table.recipientWrapEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selfWrapEventId => $composableBuilder(
    column: $table.selfWrapEventId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientWrapLastError => $composableBuilder(
    column: $table.recipientWrapLastError,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selfWrapLastError => $composableBuilder(
    column: $table.selfWrapLastError,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sendBatchId => $composableBuilder(
    column: $table.sendBatchId,
    builder: (column) => column,
  );
}

class $$OutgoingDmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutgoingDmsTable,
          OutgoingDmRow,
          $$OutgoingDmsTableFilterComposer,
          $$OutgoingDmsTableOrderingComposer,
          $$OutgoingDmsTableAnnotationComposer,
          $$OutgoingDmsTableCreateCompanionBuilder,
          $$OutgoingDmsTableUpdateCompanionBuilder,
          (
            OutgoingDmRow,
            BaseReferences<_$AppDatabase, $OutgoingDmsTable, OutgoingDmRow>,
          ),
          OutgoingDmRow,
          PrefetchHooks Function()
        > {
  $$OutgoingDmsTableTableManager(_$AppDatabase db, $OutgoingDmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutgoingDmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutgoingDmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutgoingDmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> recipientPubkey = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> rumorEventJson = const Value.absent(),
                Value<int> messageKind = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String> recipientWrapStatus = const Value.absent(),
                Value<String> selfWrapStatus = const Value.absent(),
                Value<String?> recipientWrapEventId = const Value.absent(),
                Value<String?> selfWrapEventId = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> recipientWrapLastError = const Value.absent(),
                Value<String?> selfWrapLastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<String> ownerPubkey = const Value.absent(),
                Value<String?> sendBatchId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutgoingDmsCompanion(
                id: id,
                conversationId: conversationId,
                recipientPubkey: recipientPubkey,
                content: content,
                createdAt: createdAt,
                rumorEventJson: rumorEventJson,
                messageKind: messageKind,
                replyToId: replyToId,
                recipientWrapStatus: recipientWrapStatus,
                selfWrapStatus: selfWrapStatus,
                recipientWrapEventId: recipientWrapEventId,
                selfWrapEventId: selfWrapEventId,
                retryCount: retryCount,
                recipientWrapLastError: recipientWrapLastError,
                selfWrapLastError: selfWrapLastError,
                lastAttemptAt: lastAttemptAt,
                queuedAt: queuedAt,
                ownerPubkey: ownerPubkey,
                sendBatchId: sendBatchId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String recipientPubkey,
                required String content,
                required int createdAt,
                required String rumorEventJson,
                Value<int> messageKind = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                required String recipientWrapStatus,
                required String selfWrapStatus,
                Value<String?> recipientWrapEventId = const Value.absent(),
                Value<String?> selfWrapEventId = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> recipientWrapLastError = const Value.absent(),
                Value<String?> selfWrapLastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                required DateTime queuedAt,
                required String ownerPubkey,
                Value<String?> sendBatchId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutgoingDmsCompanion.insert(
                id: id,
                conversationId: conversationId,
                recipientPubkey: recipientPubkey,
                content: content,
                createdAt: createdAt,
                rumorEventJson: rumorEventJson,
                messageKind: messageKind,
                replyToId: replyToId,
                recipientWrapStatus: recipientWrapStatus,
                selfWrapStatus: selfWrapStatus,
                recipientWrapEventId: recipientWrapEventId,
                selfWrapEventId: selfWrapEventId,
                retryCount: retryCount,
                recipientWrapLastError: recipientWrapLastError,
                selfWrapLastError: selfWrapLastError,
                lastAttemptAt: lastAttemptAt,
                queuedAt: queuedAt,
                ownerPubkey: ownerPubkey,
                sendBatchId: sendBatchId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutgoingDmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutgoingDmsTable,
      OutgoingDmRow,
      $$OutgoingDmsTableFilterComposer,
      $$OutgoingDmsTableOrderingComposer,
      $$OutgoingDmsTableAnnotationComposer,
      $$OutgoingDmsTableCreateCompanionBuilder,
      $$OutgoingDmsTableUpdateCompanionBuilder,
      (
        OutgoingDmRow,
        BaseReferences<_$AppDatabase, $OutgoingDmsTable, OutgoingDmRow>,
      ),
      OutgoingDmRow,
      PrefetchHooks Function()
    >;
typedef $$PendingViewEventsTableCreateCompanionBuilder =
    PendingViewEventsCompanion Function({
      required String id,
      required String videoId,
      required String videoPubkey,
      Value<String?> videoVineId,
      Value<String?> videoAddressableDTag,
      Value<int?> videoEventKind,
      required String userPubkey,
      required int watchDurationMs,
      Value<int?> totalDurationMs,
      Value<int?> loopCount,
      Value<String?> phase,
      required String trafficSource,
      Value<String?> sourceDetail,
      required String status,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<DateTime?> lastAttemptAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PendingViewEventsTableUpdateCompanionBuilder =
    PendingViewEventsCompanion Function({
      Value<String> id,
      Value<String> videoId,
      Value<String> videoPubkey,
      Value<String?> videoVineId,
      Value<String?> videoAddressableDTag,
      Value<int?> videoEventKind,
      Value<String> userPubkey,
      Value<int> watchDurationMs,
      Value<int?> totalDurationMs,
      Value<int?> loopCount,
      Value<String?> phase,
      Value<String> trafficSource,
      Value<String?> sourceDetail,
      Value<String> status,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PendingViewEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingViewEventsTable> {
  $$PendingViewEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoPubkey => $composableBuilder(
    column: $table.videoPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoVineId => $composableBuilder(
    column: $table.videoVineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoAddressableDTag => $composableBuilder(
    column: $table.videoAddressableDTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoEventKind => $composableBuilder(
    column: $table.videoEventKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get watchDurationMs => $composableBuilder(
    column: $table.watchDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loopCount => $composableBuilder(
    column: $table.loopCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trafficSource => $composableBuilder(
    column: $table.trafficSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDetail => $composableBuilder(
    column: $table.sourceDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingViewEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingViewEventsTable> {
  $$PendingViewEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoPubkey => $composableBuilder(
    column: $table.videoPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoVineId => $composableBuilder(
    column: $table.videoVineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoAddressableDTag => $composableBuilder(
    column: $table.videoAddressableDTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoEventKind => $composableBuilder(
    column: $table.videoEventKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get watchDurationMs => $composableBuilder(
    column: $table.watchDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loopCount => $composableBuilder(
    column: $table.loopCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trafficSource => $composableBuilder(
    column: $table.trafficSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDetail => $composableBuilder(
    column: $table.sourceDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingViewEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingViewEventsTable> {
  $$PendingViewEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get videoPubkey => $composableBuilder(
    column: $table.videoPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoVineId => $composableBuilder(
    column: $table.videoVineId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoAddressableDTag => $composableBuilder(
    column: $table.videoAddressableDTag,
    builder: (column) => column,
  );

  GeneratedColumn<int> get videoEventKind => $composableBuilder(
    column: $table.videoEventKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get watchDurationMs => $composableBuilder(
    column: $table.watchDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalDurationMs => $composableBuilder(
    column: $table.totalDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get loopCount =>
      $composableBuilder(column: $table.loopCount, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get trafficSource => $composableBuilder(
    column: $table.trafficSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDetail => $composableBuilder(
    column: $table.sourceDetail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingViewEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingViewEventsTable,
          PendingViewEventRow,
          $$PendingViewEventsTableFilterComposer,
          $$PendingViewEventsTableOrderingComposer,
          $$PendingViewEventsTableAnnotationComposer,
          $$PendingViewEventsTableCreateCompanionBuilder,
          $$PendingViewEventsTableUpdateCompanionBuilder,
          (
            PendingViewEventRow,
            BaseReferences<
              _$AppDatabase,
              $PendingViewEventsTable,
              PendingViewEventRow
            >,
          ),
          PendingViewEventRow,
          PrefetchHooks Function()
        > {
  $$PendingViewEventsTableTableManager(
    _$AppDatabase db,
    $PendingViewEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingViewEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingViewEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingViewEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String> videoPubkey = const Value.absent(),
                Value<String?> videoVineId = const Value.absent(),
                Value<String?> videoAddressableDTag = const Value.absent(),
                Value<int?> videoEventKind = const Value.absent(),
                Value<String> userPubkey = const Value.absent(),
                Value<int> watchDurationMs = const Value.absent(),
                Value<int?> totalDurationMs = const Value.absent(),
                Value<int?> loopCount = const Value.absent(),
                Value<String?> phase = const Value.absent(),
                Value<String> trafficSource = const Value.absent(),
                Value<String?> sourceDetail = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingViewEventsCompanion(
                id: id,
                videoId: videoId,
                videoPubkey: videoPubkey,
                videoVineId: videoVineId,
                videoAddressableDTag: videoAddressableDTag,
                videoEventKind: videoEventKind,
                userPubkey: userPubkey,
                watchDurationMs: watchDurationMs,
                totalDurationMs: totalDurationMs,
                loopCount: loopCount,
                phase: phase,
                trafficSource: trafficSource,
                sourceDetail: sourceDetail,
                status: status,
                retryCount: retryCount,
                lastError: lastError,
                lastAttemptAt: lastAttemptAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String videoId,
                required String videoPubkey,
                Value<String?> videoVineId = const Value.absent(),
                Value<String?> videoAddressableDTag = const Value.absent(),
                Value<int?> videoEventKind = const Value.absent(),
                required String userPubkey,
                required int watchDurationMs,
                Value<int?> totalDurationMs = const Value.absent(),
                Value<int?> loopCount = const Value.absent(),
                Value<String?> phase = const Value.absent(),
                required String trafficSource,
                Value<String?> sourceDetail = const Value.absent(),
                required String status,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingViewEventsCompanion.insert(
                id: id,
                videoId: videoId,
                videoPubkey: videoPubkey,
                videoVineId: videoVineId,
                videoAddressableDTag: videoAddressableDTag,
                videoEventKind: videoEventKind,
                userPubkey: userPubkey,
                watchDurationMs: watchDurationMs,
                totalDurationMs: totalDurationMs,
                loopCount: loopCount,
                phase: phase,
                trafficSource: trafficSource,
                sourceDetail: sourceDetail,
                status: status,
                retryCount: retryCount,
                lastError: lastError,
                lastAttemptAt: lastAttemptAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingViewEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingViewEventsTable,
      PendingViewEventRow,
      $$PendingViewEventsTableFilterComposer,
      $$PendingViewEventsTableOrderingComposer,
      $$PendingViewEventsTableAnnotationComposer,
      $$PendingViewEventsTableCreateCompanionBuilder,
      $$PendingViewEventsTableUpdateCompanionBuilder,
      (
        PendingViewEventRow,
        BaseReferences<
          _$AppDatabase,
          $PendingViewEventsTable,
          PendingViewEventRow
        >,
      ),
      PendingViewEventRow,
      PrefetchHooks Function()
    >;
typedef $$PendingProductEventsTableCreateCompanionBuilder =
    PendingProductEventsCompanion Function({
      required String id,
      required String eventName,
      required String payloadJson,
      required String status,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String?> lastError,
      required DateTime createdAt,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });
typedef $$PendingProductEventsTableUpdateCompanionBuilder =
    PendingProductEventsCompanion Function({
      Value<String> id,
      Value<String> eventName,
      Value<String> payloadJson,
      Value<String> status,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });

class $$PendingProductEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingProductEventsTable> {
  $$PendingProductEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventName => $composableBuilder(
    column: $table.eventName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingProductEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingProductEventsTable> {
  $$PendingProductEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventName => $composableBuilder(
    column: $table.eventName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingProductEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingProductEventsTable> {
  $$PendingProductEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventName =>
      $composableBuilder(column: $table.eventName, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );
}

class $$PendingProductEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingProductEventsTable,
          PendingProductEventRow,
          $$PendingProductEventsTableFilterComposer,
          $$PendingProductEventsTableOrderingComposer,
          $$PendingProductEventsTableAnnotationComposer,
          $$PendingProductEventsTableCreateCompanionBuilder,
          $$PendingProductEventsTableUpdateCompanionBuilder,
          (
            PendingProductEventRow,
            BaseReferences<
              _$AppDatabase,
              $PendingProductEventsTable,
              PendingProductEventRow
            >,
          ),
          PendingProductEventRow,
          PrefetchHooks Function()
        > {
  $$PendingProductEventsTableTableManager(
    _$AppDatabase db,
    $PendingProductEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingProductEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingProductEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingProductEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventName = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingProductEventsCompanion(
                id: id,
                eventName: eventName,
                payloadJson: payloadJson,
                status: status,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventName,
                required String payloadJson,
                required String status,
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingProductEventsCompanion.insert(
                id: id,
                eventName: eventName,
                payloadJson: payloadJson,
                status: status,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingProductEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingProductEventsTable,
      PendingProductEventRow,
      $$PendingProductEventsTableFilterComposer,
      $$PendingProductEventsTableOrderingComposer,
      $$PendingProductEventsTableAnnotationComposer,
      $$PendingProductEventsTableCreateCompanionBuilder,
      $$PendingProductEventsTableUpdateCompanionBuilder,
      (
        PendingProductEventRow,
        BaseReferences<
          _$AppDatabase,
          $PendingProductEventsTable,
          PendingProductEventRow
        >,
      ),
      PendingProductEventRow,
      PrefetchHooks Function()
    >;
typedef $$PendingGiftWrapsTableCreateCompanionBuilder =
    PendingGiftWrapsCompanion Function({
      required String giftWrapId,
      required String ownerPubkey,
      required String rawJson,
      required int createdAt,
      Value<int> attempts,
      Value<int?> lastAttemptAt,
      Value<int> rowid,
    });
typedef $$PendingGiftWrapsTableUpdateCompanionBuilder =
    PendingGiftWrapsCompanion Function({
      Value<String> giftWrapId,
      Value<String> ownerPubkey,
      Value<String> rawJson,
      Value<int> createdAt,
      Value<int> attempts,
      Value<int?> lastAttemptAt,
      Value<int> rowid,
    });

class $$PendingGiftWrapsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingGiftWrapsTable> {
  $$PendingGiftWrapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingGiftWrapsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingGiftWrapsTable> {
  $$PendingGiftWrapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingGiftWrapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingGiftWrapsTable> {
  $$PendingGiftWrapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );
}

class $$PendingGiftWrapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingGiftWrapsTable,
          PendingGiftWrapRow,
          $$PendingGiftWrapsTableFilterComposer,
          $$PendingGiftWrapsTableOrderingComposer,
          $$PendingGiftWrapsTableAnnotationComposer,
          $$PendingGiftWrapsTableCreateCompanionBuilder,
          $$PendingGiftWrapsTableUpdateCompanionBuilder,
          (
            PendingGiftWrapRow,
            BaseReferences<
              _$AppDatabase,
              $PendingGiftWrapsTable,
              PendingGiftWrapRow
            >,
          ),
          PendingGiftWrapRow,
          PrefetchHooks Function()
        > {
  $$PendingGiftWrapsTableTableManager(
    _$AppDatabase db,
    $PendingGiftWrapsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingGiftWrapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingGiftWrapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingGiftWrapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> giftWrapId = const Value.absent(),
                Value<String> ownerPubkey = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingGiftWrapsCompanion(
                giftWrapId: giftWrapId,
                ownerPubkey: ownerPubkey,
                rawJson: rawJson,
                createdAt: createdAt,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String giftWrapId,
                required String ownerPubkey,
                required String rawJson,
                required int createdAt,
                Value<int> attempts = const Value.absent(),
                Value<int?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingGiftWrapsCompanion.insert(
                giftWrapId: giftWrapId,
                ownerPubkey: ownerPubkey,
                rawJson: rawJson,
                createdAt: createdAt,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingGiftWrapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingGiftWrapsTable,
      PendingGiftWrapRow,
      $$PendingGiftWrapsTableFilterComposer,
      $$PendingGiftWrapsTableOrderingComposer,
      $$PendingGiftWrapsTableAnnotationComposer,
      $$PendingGiftWrapsTableCreateCompanionBuilder,
      $$PendingGiftWrapsTableUpdateCompanionBuilder,
      (
        PendingGiftWrapRow,
        BaseReferences<
          _$AppDatabase,
          $PendingGiftWrapsTable,
          PendingGiftWrapRow
        >,
      ),
      PendingGiftWrapRow,
      PrefetchHooks Function()
    >;
typedef $$ProcessedGiftWrapsTableCreateCompanionBuilder =
    ProcessedGiftWrapsCompanion Function({
      required String giftWrapId,
      required int processedAt,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });
typedef $$ProcessedGiftWrapsTableUpdateCompanionBuilder =
    ProcessedGiftWrapsCompanion Function({
      Value<String> giftWrapId,
      Value<int> processedAt,
      Value<String?> ownerPubkey,
      Value<int> rowid,
    });

class $$ProcessedGiftWrapsTableFilterComposer
    extends Composer<_$AppDatabase, $ProcessedGiftWrapsTable> {
  $$ProcessedGiftWrapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProcessedGiftWrapsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProcessedGiftWrapsTable> {
  $$ProcessedGiftWrapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProcessedGiftWrapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProcessedGiftWrapsTable> {
  $$ProcessedGiftWrapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get giftWrapId => $composableBuilder(
    column: $table.giftWrapId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );
}

class $$ProcessedGiftWrapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProcessedGiftWrapsTable,
          ProcessedGiftWrap,
          $$ProcessedGiftWrapsTableFilterComposer,
          $$ProcessedGiftWrapsTableOrderingComposer,
          $$ProcessedGiftWrapsTableAnnotationComposer,
          $$ProcessedGiftWrapsTableCreateCompanionBuilder,
          $$ProcessedGiftWrapsTableUpdateCompanionBuilder,
          (
            ProcessedGiftWrap,
            BaseReferences<
              _$AppDatabase,
              $ProcessedGiftWrapsTable,
              ProcessedGiftWrap
            >,
          ),
          ProcessedGiftWrap,
          PrefetchHooks Function()
        > {
  $$ProcessedGiftWrapsTableTableManager(
    _$AppDatabase db,
    $ProcessedGiftWrapsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessedGiftWrapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessedGiftWrapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProcessedGiftWrapsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> giftWrapId = const Value.absent(),
                Value<int> processedAt = const Value.absent(),
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProcessedGiftWrapsCompanion(
                giftWrapId: giftWrapId,
                processedAt: processedAt,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String giftWrapId,
                required int processedAt,
                Value<String?> ownerPubkey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProcessedGiftWrapsCompanion.insert(
                giftWrapId: giftWrapId,
                processedAt: processedAt,
                ownerPubkey: ownerPubkey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProcessedGiftWrapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProcessedGiftWrapsTable,
      ProcessedGiftWrap,
      $$ProcessedGiftWrapsTableFilterComposer,
      $$ProcessedGiftWrapsTableOrderingComposer,
      $$ProcessedGiftWrapsTableAnnotationComposer,
      $$ProcessedGiftWrapsTableCreateCompanionBuilder,
      $$ProcessedGiftWrapsTableUpdateCompanionBuilder,
      (
        ProcessedGiftWrap,
        BaseReferences<
          _$AppDatabase,
          $ProcessedGiftWrapsTable,
          ProcessedGiftWrap
        >,
      ),
      ProcessedGiftWrap,
      PrefetchHooks Function()
    >;
typedef $$RemovedConversationsTableCreateCompanionBuilder =
    RemovedConversationsCompanion Function({
      required String conversationId,
      required String ownerPubkey,
      required int removedAt,
      Value<int> rowid,
    });
typedef $$RemovedConversationsTableUpdateCompanionBuilder =
    RemovedConversationsCompanion Function({
      Value<String> conversationId,
      Value<String> ownerPubkey,
      Value<int> removedAt,
      Value<int> rowid,
    });

class $$RemovedConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $RemovedConversationsTable> {
  $$RemovedConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemovedConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $RemovedConversationsTable> {
  $$RemovedConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemovedConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemovedConversationsTable> {
  $$RemovedConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerPubkey => $composableBuilder(
    column: $table.ownerPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get removedAt =>
      $composableBuilder(column: $table.removedAt, builder: (column) => column);
}

class $$RemovedConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemovedConversationsTable,
          RemovedConversation,
          $$RemovedConversationsTableFilterComposer,
          $$RemovedConversationsTableOrderingComposer,
          $$RemovedConversationsTableAnnotationComposer,
          $$RemovedConversationsTableCreateCompanionBuilder,
          $$RemovedConversationsTableUpdateCompanionBuilder,
          (
            RemovedConversation,
            BaseReferences<
              _$AppDatabase,
              $RemovedConversationsTable,
              RemovedConversation
            >,
          ),
          RemovedConversation,
          PrefetchHooks Function()
        > {
  $$RemovedConversationsTableTableManager(
    _$AppDatabase db,
    $RemovedConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemovedConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemovedConversationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RemovedConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> ownerPubkey = const Value.absent(),
                Value<int> removedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemovedConversationsCompanion(
                conversationId: conversationId,
                ownerPubkey: ownerPubkey,
                removedAt: removedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String ownerPubkey,
                required int removedAt,
                Value<int> rowid = const Value.absent(),
              }) => RemovedConversationsCompanion.insert(
                conversationId: conversationId,
                ownerPubkey: ownerPubkey,
                removedAt: removedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemovedConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemovedConversationsTable,
      RemovedConversation,
      $$RemovedConversationsTableFilterComposer,
      $$RemovedConversationsTableOrderingComposer,
      $$RemovedConversationsTableAnnotationComposer,
      $$RemovedConversationsTableCreateCompanionBuilder,
      $$RemovedConversationsTableUpdateCompanionBuilder,
      (
        RemovedConversation,
        BaseReferences<
          _$AppDatabase,
          $RemovedConversationsTable,
          RemovedConversation
        >,
      ),
      RemovedConversation,
      PrefetchHooks Function()
    >;
typedef $$PendingProfileSavesTableCreateCompanionBuilder =
    PendingProfileSavesCompanion Function({
      required String userPubkey,
      required String payloadJson,
      Value<bool> claimConfirmed,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime?> lastAttemptAt,
      required DateTime queuedAt,
      Value<String?> lastError,
      Value<String> generation,
      Value<int> rowid,
    });
typedef $$PendingProfileSavesTableUpdateCompanionBuilder =
    PendingProfileSavesCompanion Function({
      Value<String> userPubkey,
      Value<String> payloadJson,
      Value<bool> claimConfirmed,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime> queuedAt,
      Value<String?> lastError,
      Value<String> generation,
      Value<int> rowid,
    });

class $$PendingProfileSavesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingProfileSavesTable> {
  $$PendingProfileSavesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get claimConfirmed => $composableBuilder(
    column: $table.claimConfirmed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingProfileSavesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingProfileSavesTable> {
  $$PendingProfileSavesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get claimConfirmed => $composableBuilder(
    column: $table.claimConfirmed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingProfileSavesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingProfileSavesTable> {
  $$PendingProfileSavesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userPubkey => $composableBuilder(
    column: $table.userPubkey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get claimConfirmed => $composableBuilder(
    column: $table.claimConfirmed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );
}

class $$PendingProfileSavesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingProfileSavesTable,
          PendingProfileSaveRow,
          $$PendingProfileSavesTableFilterComposer,
          $$PendingProfileSavesTableOrderingComposer,
          $$PendingProfileSavesTableAnnotationComposer,
          $$PendingProfileSavesTableCreateCompanionBuilder,
          $$PendingProfileSavesTableUpdateCompanionBuilder,
          (
            PendingProfileSaveRow,
            BaseReferences<
              _$AppDatabase,
              $PendingProfileSavesTable,
              PendingProfileSaveRow
            >,
          ),
          PendingProfileSaveRow,
          PrefetchHooks Function()
        > {
  $$PendingProfileSavesTableTableManager(
    _$AppDatabase db,
    $PendingProfileSavesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingProfileSavesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingProfileSavesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingProfileSavesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userPubkey = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<bool> claimConfirmed = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> generation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingProfileSavesCompanion(
                userPubkey: userPubkey,
                payloadJson: payloadJson,
                claimConfirmed: claimConfirmed,
                status: status,
                retryCount: retryCount,
                lastAttemptAt: lastAttemptAt,
                queuedAt: queuedAt,
                lastError: lastError,
                generation: generation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userPubkey,
                required String payloadJson,
                Value<bool> claimConfirmed = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                required DateTime queuedAt,
                Value<String?> lastError = const Value.absent(),
                Value<String> generation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingProfileSavesCompanion.insert(
                userPubkey: userPubkey,
                payloadJson: payloadJson,
                claimConfirmed: claimConfirmed,
                status: status,
                retryCount: retryCount,
                lastAttemptAt: lastAttemptAt,
                queuedAt: queuedAt,
                lastError: lastError,
                generation: generation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingProfileSavesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingProfileSavesTable,
      PendingProfileSaveRow,
      $$PendingProfileSavesTableFilterComposer,
      $$PendingProfileSavesTableOrderingComposer,
      $$PendingProfileSavesTableAnnotationComposer,
      $$PendingProfileSavesTableCreateCompanionBuilder,
      $$PendingProfileSavesTableUpdateCompanionBuilder,
      (
        PendingProfileSaveRow,
        BaseReferences<
          _$AppDatabase,
          $PendingProfileSavesTable,
          PendingProfileSaveRow
        >,
      ),
      PendingProfileSaveRow,
      PrefetchHooks Function()
    >;
typedef $$IdentityEventsTableCreateCompanionBuilder =
    IdentityEventsCompanion Function({
      required String pubkey,
      required String tagsJson,
      required int sourceKind,
      Value<int?> sourceCreatedAt,
      Value<String?> sourceEventId,
      Value<int> rowid,
    });
typedef $$IdentityEventsTableUpdateCompanionBuilder =
    IdentityEventsCompanion Function({
      Value<String> pubkey,
      Value<String> tagsJson,
      Value<int> sourceKind,
      Value<int?> sourceCreatedAt,
      Value<String?> sourceEventId,
      Value<int> rowid,
    });

class $$IdentityEventsTableFilterComposer
    extends Composer<_$AppDatabase, $IdentityEventsTable> {
  $$IdentityEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceCreatedAt => $composableBuilder(
    column: $table.sourceCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceEventId => $composableBuilder(
    column: $table.sourceEventId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdentityEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $IdentityEventsTable> {
  $$IdentityEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceCreatedAt => $composableBuilder(
    column: $table.sourceCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceEventId => $composableBuilder(
    column: $table.sourceEventId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdentityEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdentityEventsTable> {
  $$IdentityEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<int> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceCreatedAt => $composableBuilder(
    column: $table.sourceCreatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceEventId => $composableBuilder(
    column: $table.sourceEventId,
    builder: (column) => column,
  );
}

class $$IdentityEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdentityEventsTable,
          IdentityEventRow,
          $$IdentityEventsTableFilterComposer,
          $$IdentityEventsTableOrderingComposer,
          $$IdentityEventsTableAnnotationComposer,
          $$IdentityEventsTableCreateCompanionBuilder,
          $$IdentityEventsTableUpdateCompanionBuilder,
          (
            IdentityEventRow,
            BaseReferences<
              _$AppDatabase,
              $IdentityEventsTable,
              IdentityEventRow
            >,
          ),
          IdentityEventRow,
          PrefetchHooks Function()
        > {
  $$IdentityEventsTableTableManager(
    _$AppDatabase db,
    $IdentityEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdentityEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdentityEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdentityEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pubkey = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<int> sourceKind = const Value.absent(),
                Value<int?> sourceCreatedAt = const Value.absent(),
                Value<String?> sourceEventId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdentityEventsCompanion(
                pubkey: pubkey,
                tagsJson: tagsJson,
                sourceKind: sourceKind,
                sourceCreatedAt: sourceCreatedAt,
                sourceEventId: sourceEventId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkey,
                required String tagsJson,
                required int sourceKind,
                Value<int?> sourceCreatedAt = const Value.absent(),
                Value<String?> sourceEventId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdentityEventsCompanion.insert(
                pubkey: pubkey,
                tagsJson: tagsJson,
                sourceKind: sourceKind,
                sourceCreatedAt: sourceCreatedAt,
                sourceEventId: sourceEventId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdentityEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdentityEventsTable,
      IdentityEventRow,
      $$IdentityEventsTableFilterComposer,
      $$IdentityEventsTableOrderingComposer,
      $$IdentityEventsTableAnnotationComposer,
      $$IdentityEventsTableCreateCompanionBuilder,
      $$IdentityEventsTableUpdateCompanionBuilder,
      (
        IdentityEventRow,
        BaseReferences<_$AppDatabase, $IdentityEventsTable, IdentityEventRow>,
      ),
      IdentityEventRow,
      PrefetchHooks Function()
    >;
typedef $$IdentityVerificationsTableCreateCompanionBuilder =
    IdentityVerificationsCompanion Function({
      required String pubkey,
      required String verifiedClaimsJson,
      required int checkedAtFloor,
      Value<int> rowid,
    });
typedef $$IdentityVerificationsTableUpdateCompanionBuilder =
    IdentityVerificationsCompanion Function({
      Value<String> pubkey,
      Value<String> verifiedClaimsJson,
      Value<int> checkedAtFloor,
      Value<int> rowid,
    });

class $$IdentityVerificationsTableFilterComposer
    extends Composer<_$AppDatabase, $IdentityVerificationsTable> {
  $$IdentityVerificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verifiedClaimsJson => $composableBuilder(
    column: $table.verifiedClaimsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkedAtFloor => $composableBuilder(
    column: $table.checkedAtFloor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdentityVerificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $IdentityVerificationsTable> {
  $$IdentityVerificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verifiedClaimsJson => $composableBuilder(
    column: $table.verifiedClaimsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkedAtFloor => $composableBuilder(
    column: $table.checkedAtFloor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdentityVerificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdentityVerificationsTable> {
  $$IdentityVerificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<String> get verifiedClaimsJson => $composableBuilder(
    column: $table.verifiedClaimsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get checkedAtFloor => $composableBuilder(
    column: $table.checkedAtFloor,
    builder: (column) => column,
  );
}

class $$IdentityVerificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdentityVerificationsTable,
          IdentityVerificationRow,
          $$IdentityVerificationsTableFilterComposer,
          $$IdentityVerificationsTableOrderingComposer,
          $$IdentityVerificationsTableAnnotationComposer,
          $$IdentityVerificationsTableCreateCompanionBuilder,
          $$IdentityVerificationsTableUpdateCompanionBuilder,
          (
            IdentityVerificationRow,
            BaseReferences<
              _$AppDatabase,
              $IdentityVerificationsTable,
              IdentityVerificationRow
            >,
          ),
          IdentityVerificationRow,
          PrefetchHooks Function()
        > {
  $$IdentityVerificationsTableTableManager(
    _$AppDatabase db,
    $IdentityVerificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdentityVerificationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$IdentityVerificationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$IdentityVerificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> pubkey = const Value.absent(),
                Value<String> verifiedClaimsJson = const Value.absent(),
                Value<int> checkedAtFloor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdentityVerificationsCompanion(
                pubkey: pubkey,
                verifiedClaimsJson: verifiedClaimsJson,
                checkedAtFloor: checkedAtFloor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkey,
                required String verifiedClaimsJson,
                required int checkedAtFloor,
                Value<int> rowid = const Value.absent(),
              }) => IdentityVerificationsCompanion.insert(
                pubkey: pubkey,
                verifiedClaimsJson: verifiedClaimsJson,
                checkedAtFloor: checkedAtFloor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdentityVerificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdentityVerificationsTable,
      IdentityVerificationRow,
      $$IdentityVerificationsTableFilterComposer,
      $$IdentityVerificationsTableOrderingComposer,
      $$IdentityVerificationsTableAnnotationComposer,
      $$IdentityVerificationsTableCreateCompanionBuilder,
      $$IdentityVerificationsTableUpdateCompanionBuilder,
      (
        IdentityVerificationRow,
        BaseReferences<
          _$AppDatabase,
          $IdentityVerificationsTable,
          IdentityVerificationRow
        >,
      ),
      IdentityVerificationRow,
      PrefetchHooks Function()
    >;
typedef $$SeenVideosTableCreateCompanionBuilder =
    SeenVideosCompanion Function({
      required String videoId,
      required int firstSeenAt,
      required int lastSeenAt,
      Value<int> rowid,
    });
typedef $$SeenVideosTableUpdateCompanionBuilder =
    SeenVideosCompanion Function({
      Value<String> videoId,
      Value<int> firstSeenAt,
      Value<int> lastSeenAt,
      Value<int> rowid,
    });

class $$SeenVideosTableFilterComposer
    extends Composer<_$AppDatabase, $SeenVideosTable> {
  $$SeenVideosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeenVideosTableOrderingComposer
    extends Composer<_$AppDatabase, $SeenVideosTable> {
  $$SeenVideosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeenVideosTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeenVideosTable> {
  $$SeenVideosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$SeenVideosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeenVideosTable,
          SeenVideoRow,
          $$SeenVideosTableFilterComposer,
          $$SeenVideosTableOrderingComposer,
          $$SeenVideosTableAnnotationComposer,
          $$SeenVideosTableCreateCompanionBuilder,
          $$SeenVideosTableUpdateCompanionBuilder,
          (
            SeenVideoRow,
            BaseReferences<_$AppDatabase, $SeenVideosTable, SeenVideoRow>,
          ),
          SeenVideoRow,
          PrefetchHooks Function()
        > {
  $$SeenVideosTableTableManager(_$AppDatabase db, $SeenVideosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeenVideosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeenVideosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeenVideosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<int> firstSeenAt = const Value.absent(),
                Value<int> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeenVideosCompanion(
                videoId: videoId,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required int firstSeenAt,
                required int lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => SeenVideosCompanion.insert(
                videoId: videoId,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeenVideosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeenVideosTable,
      SeenVideoRow,
      $$SeenVideosTableFilterComposer,
      $$SeenVideosTableOrderingComposer,
      $$SeenVideosTableAnnotationComposer,
      $$SeenVideosTableCreateCompanionBuilder,
      $$SeenVideosTableUpdateCompanionBuilder,
      (
        SeenVideoRow,
        BaseReferences<_$AppDatabase, $SeenVideosTable, SeenVideoRow>,
      ),
      SeenVideoRow,
      PrefetchHooks Function()
    >;
typedef $$VanishedProfilesTableCreateCompanionBuilder =
    VanishedProfilesCompanion Function({
      required String pubkey,
      required DateTime detectedAt,
      Value<int> rowid,
    });
typedef $$VanishedProfilesTableUpdateCompanionBuilder =
    VanishedProfilesCompanion Function({
      Value<String> pubkey,
      Value<DateTime> detectedAt,
      Value<int> rowid,
    });

class $$VanishedProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $VanishedProfilesTable> {
  $$VanishedProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VanishedProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $VanishedProfilesTable> {
  $$VanishedProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubkey => $composableBuilder(
    column: $table.pubkey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VanishedProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VanishedProfilesTable> {
  $$VanishedProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubkey =>
      $composableBuilder(column: $table.pubkey, builder: (column) => column);

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );
}

class $$VanishedProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VanishedProfilesTable,
          VanishedProfileRow,
          $$VanishedProfilesTableFilterComposer,
          $$VanishedProfilesTableOrderingComposer,
          $$VanishedProfilesTableAnnotationComposer,
          $$VanishedProfilesTableCreateCompanionBuilder,
          $$VanishedProfilesTableUpdateCompanionBuilder,
          (
            VanishedProfileRow,
            BaseReferences<
              _$AppDatabase,
              $VanishedProfilesTable,
              VanishedProfileRow
            >,
          ),
          VanishedProfileRow,
          PrefetchHooks Function()
        > {
  $$VanishedProfilesTableTableManager(
    _$AppDatabase db,
    $VanishedProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VanishedProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VanishedProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VanishedProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pubkey = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VanishedProfilesCompanion(
                pubkey: pubkey,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkey,
                required DateTime detectedAt,
                Value<int> rowid = const Value.absent(),
              }) => VanishedProfilesCompanion.insert(
                pubkey: pubkey,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VanishedProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VanishedProfilesTable,
      VanishedProfileRow,
      $$VanishedProfilesTableFilterComposer,
      $$VanishedProfilesTableOrderingComposer,
      $$VanishedProfilesTableAnnotationComposer,
      $$VanishedProfilesTableCreateCompanionBuilder,
      $$VanishedProfilesTableUpdateCompanionBuilder,
      (
        VanishedProfileRow,
        BaseReferences<
          _$AppDatabase,
          $VanishedProfilesTable,
          VanishedProfileRow
        >,
      ),
      VanishedProfileRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NostrEventsTableTableManager get nostrEvents =>
      $$NostrEventsTableTableManager(_db, _db.nostrEvents);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$VideoMetricsTableTableManager get videoMetrics =>
      $$VideoMetricsTableTableManager(_db, _db.videoMetrics);
  $$ProfileStatsTableTableManager get profileStats =>
      $$ProfileStatsTableTableManager(_db, _db.profileStats);
  $$HashtagStatsTableTableManager get hashtagStats =>
      $$HashtagStatsTableTableManager(_db, _db.hashtagStats);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db, _db.notifications);
  $$PendingUploadsTableTableManager get pendingUploads =>
      $$PendingUploadsTableTableManager(_db, _db.pendingUploads);
  $$PersonalReactionsTableTableManager get personalReactions =>
      $$PersonalReactionsTableTableManager(_db, _db.personalReactions);
  $$PersonalRepostsTableTableManager get personalReposts =>
      $$PersonalRepostsTableTableManager(_db, _db.personalReposts);
  $$PersonalEventsTableTableManager get personalEvents =>
      $$PersonalEventsTableTableManager(_db, _db.personalEvents);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(_db, _db.pendingActions);
  $$Nip05VerificationsTableTableManager get nip05Verifications =>
      $$Nip05VerificationsTableTableManager(_db, _db.nip05Verifications);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$ClipsTableTableManager get clips =>
      $$ClipsTableTableManager(_db, _db.clips);
  $$ClipCategoriesTableTableManager get clipCategories =>
      $$ClipCategoriesTableTableManager(_db, _db.clipCategories);
  $$DirectMessagesTableTableManager get directMessages =>
      $$DirectMessagesTableTableManager(_db, _db.directMessages);
  $$DmMessageReactionsTableTableManager get dmMessageReactions =>
      $$DmMessageReactionsTableTableManager(_db, _db.dmMessageReactions);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$OutgoingDmsTableTableManager get outgoingDms =>
      $$OutgoingDmsTableTableManager(_db, _db.outgoingDms);
  $$PendingViewEventsTableTableManager get pendingViewEvents =>
      $$PendingViewEventsTableTableManager(_db, _db.pendingViewEvents);
  $$PendingProductEventsTableTableManager get pendingProductEvents =>
      $$PendingProductEventsTableTableManager(_db, _db.pendingProductEvents);
  $$PendingGiftWrapsTableTableManager get pendingGiftWraps =>
      $$PendingGiftWrapsTableTableManager(_db, _db.pendingGiftWraps);
  $$ProcessedGiftWrapsTableTableManager get processedGiftWraps =>
      $$ProcessedGiftWrapsTableTableManager(_db, _db.processedGiftWraps);
  $$RemovedConversationsTableTableManager get removedConversations =>
      $$RemovedConversationsTableTableManager(_db, _db.removedConversations);
  $$PendingProfileSavesTableTableManager get pendingProfileSaves =>
      $$PendingProfileSavesTableTableManager(_db, _db.pendingProfileSaves);
  $$IdentityEventsTableTableManager get identityEvents =>
      $$IdentityEventsTableTableManager(_db, _db.identityEvents);
  $$IdentityVerificationsTableTableManager get identityVerifications =>
      $$IdentityVerificationsTableTableManager(_db, _db.identityVerifications);
  $$SeenVideosTableTableManager get seenVideos =>
      $$SeenVideosTableTableManager(_db, _db.seenVideos);
  $$VanishedProfilesTableTableManager get vanishedProfiles =>
      $$VanishedProfilesTableTableManager(_db, _db.vanishedProfiles);
}
