import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class BusinessCase {
  final String id, title, setting, brief, question, decision, outcome;
  final bool isFde;
  final Map<String, String> sources;
  BusinessCase(this.id, Map<String, dynamic> json)
    : isFde = json['track'] == 'fde',
      title = json['title'],
      setting = json['setting'],
      brief = json['brief'],
      question = json['question'],
      decision = json['decision'],
      outcome = json['outcome'],
      sources = Map<String, String>.from(json['sources']);

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
  Future<Database> open() => openDatabase(
    'casegen.db',
    version: 1,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE attempts (id INTEGER PRIMARY KEY, case_id TEXT NOT NULL, title TEXT NOT NULL, answer TEXT NOT NULL, saved TEXT NOT NULL)',
    ),
  );
  Future<void> save(BusinessCase c, String answer) async {
    final db = await open();
    await db.insert('attempts', {
      'case_id': c.id,
      'title': c.title,
      'answer': answer,
      'saved': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> all() async =>
      (await open()).query('attempts', orderBy: 'id DESC');
  Future<void> delete(int id) async =>
      (await open()).delete('attempts', where: 'id = ?', whereArgs: [id]);
}
