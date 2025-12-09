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
  @override
  List<GeneratedColumn> get $columns => [
    pubkey,
    videoCount,
    followerCount,
    followingCount,
    totalViews,
    totalLikes,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile_stats';
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
  const ProfileStatRow({
    required this.pubkey,
    this.videoCount,
    this.followerCount,
    this.followingCount,
    this.totalViews,
    this.totalLikes,
    required this.cachedAt,
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
          ..write('cachedAt: $cachedAt')
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
          other.cachedAt == this.cachedAt);
}

class ProfileStatsCompanion extends UpdateCompanion<ProfileStatRow> {
  final Value<String> pubkey;
  final Value<int?> videoCount;
  final Value<int?> followerCount;
  final Value<int?> followingCount;
  final Value<int?> totalViews;
  final Value<int?> totalLikes;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const ProfileStatsCompanion({
    this.pubkey = const Value.absent(),
    this.videoCount = const Value.absent(),
    this.followerCount = const Value.absent(),
    this.followingCount = const Value.absent(),
    this.totalViews = const Value.absent(),
    this.totalLikes = const Value.absent(),
    this.cachedAt = const Value.absent(),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    fromPubkey,
    targetEventId,
    targetPubkey,
    content,
    timestamp,
    isRead,
    cachedAt,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
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
  final String? targetPubkey;
  final String? content;
  final int timestamp;
  final bool isRead;
  final DateTime cachedAt;
  const NotificationRow({
    required this.id,
    required this.type,
    required this.fromPubkey,
    this.targetEventId,
    this.targetPubkey,
    this.content,
    required this.timestamp,
    required this.isRead,
    required this.cachedAt,
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
    if (!nullToAbsent || targetPubkey != null) {
      map['target_pubkey'] = Variable<String>(targetPubkey);
    }
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['timestamp'] = Variable<int>(timestamp);
    map['is_read'] = Variable<bool>(isRead);
    map['cached_at'] = Variable<DateTime>(cachedAt);
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
      targetPubkey: targetPubkey == null && nullToAbsent
          ? const Value.absent()
          : Value(targetPubkey),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      timestamp: Value(timestamp),
      isRead: Value(isRead),
      cachedAt: Value(cachedAt),
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
      targetPubkey: serializer.fromJson<String?>(json['targetPubkey']),
      content: serializer.fromJson<String?>(json['content']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
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
      'targetPubkey': serializer.toJson<String?>(targetPubkey),
      'content': serializer.toJson<String?>(content),
      'timestamp': serializer.toJson<int>(timestamp),
      'isRead': serializer.toJson<bool>(isRead),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  NotificationRow copyWith({
    String? id,
    String? type,
    String? fromPubkey,
    Value<String?> targetEventId = const Value.absent(),
    Value<String?> targetPubkey = const Value.absent(),
    Value<String?> content = const Value.absent(),
    int? timestamp,
    bool? isRead,
    DateTime? cachedAt,
  }) => NotificationRow(
    id: id ?? this.id,
    type: type ?? this.type,
    fromPubkey: fromPubkey ?? this.fromPubkey,
    targetEventId: targetEventId.present
        ? targetEventId.value
        : this.targetEventId,
    targetPubkey: targetPubkey.present ? targetPubkey.value : this.targetPubkey,
    content: content.present ? content.value : this.content,
    timestamp: timestamp ?? this.timestamp,
    isRead: isRead ?? this.isRead,
    cachedAt: cachedAt ?? this.cachedAt,
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
      targetPubkey: data.targetPubkey.present
          ? data.targetPubkey.value
          : this.targetPubkey,
      content: data.content.present ? data.content.value : this.content,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('fromPubkey: $fromPubkey, ')
          ..write('targetEventId: $targetEventId, ')
          ..write('targetPubkey: $targetPubkey, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('isRead: $isRead, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    fromPubkey,
    targetEventId,
    targetPubkey,
    content,
    timestamp,
    isRead,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.fromPubkey == this.fromPubkey &&
          other.targetEventId == this.targetEventId &&
          other.targetPubkey == this.targetPubkey &&
          other.content == this.content &&
          other.timestamp == this.timestamp &&
          other.isRead == this.isRead &&
          other.cachedAt == this.cachedAt);
}

class NotificationsCompanion extends UpdateCompanion<NotificationRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> fromPubkey;
  final Value<String?> targetEventId;
  final Value<String?> targetPubkey;
  final Value<String?> content;
  final Value<int> timestamp;
  final Value<bool> isRead;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.fromPubkey = const Value.absent(),
    this.targetEventId = const Value.absent(),
    this.targetPubkey = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isRead = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsCompanion.insert({
    required String id,
    required String type,
    required String fromPubkey,
    this.targetEventId = const Value.absent(),
    this.targetPubkey = const Value.absent(),
    this.content = const Value.absent(),
    required int timestamp,
    this.isRead = const Value.absent(),
    required DateTime cachedAt,
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
    Expression<String>? targetPubkey,
    Expression<String>? content,
    Expression<int>? timestamp,
    Expression<bool>? isRead,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (fromPubkey != null) 'from_pubkey': fromPubkey,
      if (targetEventId != null) 'target_event_id': targetEventId,
      if (targetPubkey != null) 'target_pubkey': targetPubkey,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (isRead != null) 'is_read': isRead,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? fromPubkey,
    Value<String?>? targetEventId,
    Value<String?>? targetPubkey,
    Value<String?>? content,
    Value<int>? timestamp,
    Value<bool>? isRead,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return NotificationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      fromPubkey: fromPubkey ?? this.fromPubkey,
      targetEventId: targetEventId ?? this.targetEventId,
      targetPubkey: targetPubkey ?? this.targetPubkey,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      cachedAt: cachedAt ?? this.cachedAt,
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
          ..write('targetPubkey: $targetPubkey, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('isRead: $isRead, ')
          ..write('cachedAt: $cachedAt, ')
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
                Value<int> rowid = const Value.absent(),
              }) => ProfileStatsCompanion(
                pubkey: pubkey,
                videoCount: videoCount,
                followerCount: followerCount,
                followingCount: followingCount,
                totalViews: totalViews,
                totalLikes: totalLikes,
                cachedAt: cachedAt,
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
                Value<int> rowid = const Value.absent(),
              }) => ProfileStatsCompanion.insert(
                pubkey: pubkey,
                videoCount: videoCount,
                followerCount: followerCount,
                followingCount: followingCount,
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
      Value<String?> targetPubkey,
      Value<String?> content,
      required int timestamp,
      Value<bool> isRead,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$NotificationsTableUpdateCompanionBuilder =
    NotificationsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> fromPubkey,
      Value<String?> targetEventId,
      Value<String?> targetPubkey,
      Value<String?> content,
      Value<int> timestamp,
      Value<bool> isRead,
      Value<DateTime> cachedAt,
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
                Value<String?> targetPubkey = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion(
                id: id,
                type: type,
                fromPubkey: fromPubkey,
                targetEventId: targetEventId,
                targetPubkey: targetPubkey,
                content: content,
                timestamp: timestamp,
                isRead: isRead,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String fromPubkey,
                Value<String?> targetEventId = const Value.absent(),
                Value<String?> targetPubkey = const Value.absent(),
                Value<String?> content = const Value.absent(),
                required int timestamp,
                Value<bool> isRead = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion.insert(
                id: id,
                type: type,
                fromPubkey: fromPubkey,
                targetEventId: targetEventId,
                targetPubkey: targetPubkey,
                content: content,
                timestamp: timestamp,
                isRead: isRead,
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
}
