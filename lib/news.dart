import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'cases.dart';

class NewsFeed {
  static const asset = 'editorial/feed.json';
  static final endpoint = Uri.https(
    'raw.githubusercontent.com',
    '/msiciliag/casegen/main/$asset',
  );
  static const _maxBytes = 512 * 1024;
  static const _timeout = Duration(seconds: 10);

  final int revision;
  final List<BusinessCase> cases;
  NewsFeed._(this.revision, this.cases);

  static NewsFeed parse(String source) {
    if (source.length > _maxBytes) throw const FormatException('Feed size');
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> ||
        json['schema'] != 1 ||
        json['revision'] is! int ||
        json['revision'] < 1 ||
        json['cases'] is! List) {
      throw const FormatException('Feed header');
    }

    final entries = json['cases'] as List;
    if (entries.length > 200) throw const FormatException('Too many cases');
    final seen = <String>{};
    final cases = <BusinessCase>[];
    for (final entry in entries) {
      if (entry is! Map<String, dynamic> ||
          entry['id'] is! String ||
          !RegExp(r'^news-[a-z0-9-]{1,96}$').hasMatch(entry['id']) ||
          !seen.add(entry['id']) ||
          entry['newsDate'] is! String ||
          !_validDate(entry['newsDate']) ||
          entry['en'] is! Map<String, dynamic>) {
        throw const FormatException('News case header');
      }
      final spanish = _copy(entry);
      final english = _copy(entry['en']);
      if (entry['scene'] != null || entry['en']['scene'] != null) {
        spanish['scene'] = _scene(entry['scene'], entry['id'], 'es');
        english['scene'] = _scene(entry['en']['scene'], entry['id'], 'en');
      }
      if (spanish.containsKey('moveDebriefs') !=
          english.containsKey('moveDebriefs')) {
        throw const FormatException('Missing translated debriefs');
      }
      if (spanish['factCheck']?['correct'] !=
          english['factCheck']?['correct']) {
        throw const FormatException('Mismatched fact checks');
      }
      final urls = (entry['sources'] as Map).values.toSet();
      if (!urls.containsAll((english['sources'] as Map).values) ||
          !(english['sources'] as Map).values.toSet().containsAll(urls)) {
        throw const FormatException('Mismatched sources');
      }
      cases.add(
        BusinessCase(entry['id'], {
          ...spanish,
          'en': english,
          'track': 'news',
          'newsDate': entry['newsDate'],
        }),
      );
    }
    cases.sort((a, b) {
      final cmp = (b.data['newsDate'] as String).compareTo(a.data['newsDate']);
      return cmp == 0 ? a.id.compareTo(b.id) : cmp;
    });
    return NewsFeed._(json['revision'], cases);
  }

  static bool _validDate(String date) {
    final parsed = DateTime.tryParse(date);
    return date.length == 10 &&
        parsed != null &&
        parsed.toIso8601String().split('T').first == date;
  }

  static bool _text(dynamic value) =>
      value is String && value.trim().isNotEmpty && value.length <= 6000;

  static Map<String, dynamic> _scene(dynamic scene, String id, String lang) {
    if (scene is! Map<String, dynamic> ||
        scene['file'] is! String ||
        !RegExp(
          '^${RegExp.escape(id)}-v[1-9][0-9]{0,5}-$lang\\.mp3\$',
        ).hasMatch(scene['file']) ||
        scene['lines'] is! List ||
        scene['lines'].length < 2 ||
        scene['lines'].length > 24) {
      throw const FormatException('Audio scene');
    }
    final lines = <Map<String, String>>[];
    for (final line in scene['lines']) {
      if (line is! Map || !_text(line['speaker']) || !_text(line['text'])) {
        throw const FormatException('Audio transcript');
      }
      lines.add({'speaker': line['speaker'], 'text': line['text']});
    }
    return {'file': scene['file'], 'lines': lines};
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> copy) {
    const fields = [
      'title',
      'setting',
      'brief',
      'question',
      'decision',
      'outcome',
      'playerRole',
      'role',
      'remit',
      'roleNotes',
      'starterQuestion',
    ];
    if (!fields.every((key) => _text(copy[key])) ||
        (copy['setting'] as String).split(' · ').length < 2 ||
        copy['moves'] is! List ||
        copy['moves'].length != 2 ||
        !(copy['moves'] as List).every(_text) ||
        copy['sources'] is! Map ||
        copy['sources'].isEmpty ||
        copy['sources'].length > 10) {
      throw const FormatException('Case copy');
    }
    final debriefs = copy['moveDebriefs'];
    if (debriefs != null &&
        (debriefs is! List || debriefs.length != 2 || !debriefs.every(_text))) {
      throw const FormatException('Move debriefs');
    }
    final check = copy['factCheck'];
    if (check != null &&
        (check is! Map<String, dynamic> ||
            !_text(check['question']) ||
            !_text(check['explanation']) ||
            check['options'] is! List ||
            check['options'].length != 2 ||
            !(check['options'] as List).every(_text) ||
            check['options'][0] == check['options'][1] ||
            check['correct'] is! int ||
            !const [0, 1].contains(check['correct']))) {
      throw const FormatException('Fact check');
    }
    for (final link in (copy['sources'] as Map).entries) {
      final uri = link.value is String ? Uri.tryParse(link.value) : null;
      if (!_text(link.key) ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Source URL');
      }
    }
    return {
      for (final f in fields) f: copy[f],
      'sources': copy['sources'],
      'moves': copy['moves'],
      if (debriefs != null) 'moveDebriefs': debriefs,
      if (check != null)
        'factCheck': {
          for (final key in ['question', 'options', 'correct', 'explanation'])
            key: check[key],
        },
    };
  }

  static Future<Database> _cache() async {
    final db = await History().open();
    await db.execute(
      'CREATE TABLE IF NOT EXISTS news_edition '
      '(id INTEGER PRIMARY KEY, revision INTEGER NOT NULL, source TEXT NOT NULL)',
    );
    return db;
  }

  static Future<NewsFeed> _latest() async {
    final bundled = parse(await rootBundle.loadString(asset));
    if (!Platform.isAndroid && !Platform.isIOS) return bundled;
    try {
      final db = await _cache();
      final rows = await db.query(
        'news_edition',
        columns: ['source'],
        where: 'id = 1',
      );
      if (rows.isNotEmpty) {
        final cached = parse(rows.single['source'] as String);
        if (cached.revision > bundled.revision) return cached;
      }
    } on DatabaseException {
      // The bundled edition is playable even when storage is unavailable.
    } on FormatException {
      // A malformed or obsolete cache must not break the bundled library.
    } on MissingPluginException {
      // SQLite may be unavailable on a non-mobile host.
    }
    return bundled;
  }

  static Future<List<BusinessCase>> load() async => (await _latest()).cases;

  static Future<List<BusinessCase>> refresh() async {
    final client = HttpClient()..connectionTimeout = _timeout;
    late final String source;
    try {
      source = await _download(client).timeout(_timeout);
    } finally {
      client.close(force: true);
    }
    final remote = parse(source);
    final latest = await _latest();
    if (remote.revision <= latest.revision) return latest.cases;
    final db = await _cache();
    // A slow, older response cannot overwrite a newer edition.
    await db.transaction((txn) async {
      final row = await txn.query(
        'news_edition',
        columns: ['revision'],
        where: 'id = 1',
      );
      if (row.isEmpty || (row.single['revision'] as int) < remote.revision) {
        await txn.insert('news_edition', {
          'id': 1,
          'revision': remote.revision,
          'source': source,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return load();
  }

  static Future<String> _download(HttpClient client) async {
    final req = await client.getUrl(endpoint);
    req.followRedirects = false;
    final response = await req.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('News feed HTTP ${response.statusCode}');
    }
    if (response.contentLength > _maxBytes)
      throw const FormatException('Feed size');
    final bytes = BytesBuilder();
    await for (final chunk in response) {
      if (bytes.length + chunk.length > _maxBytes)
        throw const FormatException('Feed size');
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }
}
