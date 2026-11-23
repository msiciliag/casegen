import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class BusinessCase {
  final String id, title, setting, brief, question, decision, outcome;
  final String role, roleNotes, playerRole, remit, starterQuestion;
  final List<String> moves, moveDebriefs;
  final Map<String, dynamic>? factCheck, scene;
  final bool isFde;
  final Map<String, String> sources;
  final Map<String, dynamic> data;
  BusinessCase(String id, Map<String, dynamic> data) : this._(id, data, data);
  BusinessCase._(this.id, this.data, Map<String, dynamic> json)
    : scene = json['scene'],
      factCheck = json['factCheck'],
      role = json['role'],
      roleNotes = json['roleNotes'],
      playerRole = json['playerRole'] ?? '',
      remit = json['remit'] ?? '',
      starterQuestion = json['starterQuestion'] ?? '',
      moves = List<String>.from(json['moves'] ?? const []),
      moveDebriefs = List<String>.from(json['moveDebriefs'] ?? const []),
      isFde = json['track'] == 'fde',
      title = json['title'],
      setting = json['setting'],
      brief = json['brief'],
      question = json['question'],
      decision = json['decision'],
      outcome = json['outcome'],
      sources = Map<String, String>.from(json['sources']);

  BusinessCase localized(String language) => BusinessCase._(
    id,
    data,
    language == 'en' ? {...data, ...data['en']} : data,
  );

  String get topic => setting.split(' · ').first;
  String get company => setting.split(' · ')[1];

  static Future<List<BusinessCase>> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths =
        manifest
            .listAssets()
            .where((p) => p.startsWith('cases/') && p.endsWith('.json'))
            .toList()
          ..sort();
    final cases = await Future.wait(
      paths.map(
        (p) async => BusinessCase(
          p.split('/').last.split('.').first,
          jsonDecode(await rootBundle.loadString(p)),
        ),
      ),
    );
    // Lead with the pricing case in the first edition.
    final index = cases.indexWhere((c) => c.id == 'netflix');
    if (index > 0) cases.insert(0, cases.removeAt(index));
    return cases;
  }
}

class History {
  Future<void> _pending = Future.value();

  Future<T> _write<T>(Future<T> Function(Database db) action) {
    final write = _pending.then((_) async => action(await open()));
    _pending = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

  static const draftSchema =
      'CREATE TABLE drafts (case_id TEXT PRIMARY KEY, state TEXT NOT NULL)';
  Future<Database> open() => openDatabase(
    'casegen.db',
    version: 2,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE attempts (id INTEGER PRIMARY KEY, case_id TEXT NOT NULL, title TEXT NOT NULL, answer TEXT NOT NULL, saved TEXT NOT NULL, snapshot TEXT, move_index INTEGER, transcript TEXT, fact_pick INTEGER)',
      );
      await db.execute(draftSchema);
    },
    onUpgrade: (db, oldVersion, _) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE attempts ADD COLUMN snapshot TEXT');
        await db.execute('ALTER TABLE attempts ADD COLUMN move_index INTEGER');
        await db.execute('ALTER TABLE attempts ADD COLUMN transcript TEXT');
        await db.execute('ALTER TABLE attempts ADD COLUMN fact_pick INTEGER');
        await db.execute(draftSchema);
      }
    },
  );

  Future<Map<String, BusinessCase>> draftCases() async {
    await _pending;
    final rows = await (await open()).query('drafts', orderBy: 'rowid DESC');
    return {
      for (final row in rows)
        row['case_id'] as String: BusinessCase(
          row['case_id'] as String,
          jsonDecode(row['state'] as String)['snapshot'],
        ),
    };
  }

  Future<Map<String, dynamic>?> draft(String id) async {
    await _pending;
    final rows = await (await open()).query(
      'drafts',
      where: 'case_id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : jsonDecode(rows.first['state'] as String);
  }

  Future<void> putDraft(String id, String state) => _write((db) async {
    await db.insert('drafts', {
      'case_id': id,
      'state': state,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<int> save(
    BusinessCase c,
    String answer, {
    int? move,
    List<Map<String, String>> turns = const [],
  }) => _write(
    (db) => db.transaction((txn) async {
      final id = await txn.insert('attempts', {
        'case_id': c.id,
        'title': c.title,
        'answer': answer,
        'saved': DateTime.now().toIso8601String(),
        'move_index': move,
        'transcript': jsonEncode(turns),
        'snapshot': jsonEncode(c.data),
      });
      await txn.delete('drafts', where: 'case_id = ?', whereArgs: [c.id]);
      return id;
    }),
  );

  Future<List<Map<String, Object?>>> all() async {
    await _pending;
    return (await open()).query('attempts', orderBy: 'id DESC');
  }

  Future<void> recordCheck(int id, int pick) => _write((db) async {
    await db.update(
      'attempts',
      {'fact_pick': pick},
      where: 'id = ? AND fact_pick IS NULL',
      whereArgs: [id],
    );
  });

  Future<void> delete(int id) => _write((db) async {
    await db.delete('attempts', where: 'id = ?', whereArgs: [id]);
  });
}
