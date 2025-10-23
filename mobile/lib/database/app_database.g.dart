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
  const NostrEventRow({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
    this.sources,
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
  }) => NostrEventRow(
    id: id ?? this.id,
    pubkey: pubkey ?? this.pubkey,
    createdAt: createdAt ?? this.createdAt,
    kind: kind ?? this.kind,
    tags: tags ?? this.tags,
    content: content ?? this.content,
    sig: sig ?? this.sig,
    sources: sources.present ? sources.value : this.sources,
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
          ..write('sources: $sources')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, pubkey, createdAt, kind, tags, content, sig, sources);
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
          other.sources == this.sources);
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NostrEventsTable nostrEvents = $NostrEventsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final UserProfilesDao userProfilesDao = UserProfilesDao(
    this as AppDatabase,
  );
  late final NostrEventsDao nostrEventsDao = NostrEventsDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    nostrEvents,
    userProfiles,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NostrEventsTableTableManager get nostrEvents =>
      $$NostrEventsTableTableManager(_db, _db.nostrEvents);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
}
