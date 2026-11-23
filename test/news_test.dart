import 'dart:convert';
import 'dart:io';
import 'package:casegen/cases.dart';
import 'package:casegen/news.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _editionFixture() {
  const id = 'news-fixture';
  Map<String, dynamic> copy(String lang) => {
    'title': 'Fixture $lang',
    'setting': 'Pilot · Fixture',
    'brief': 'A short trial is about to start.',
    'question': 'Where will you run it?',
    'decision': 'The team chose one site.',
    'outcome': 'Results are pending.',
    'playerRole': 'Lead',
    'role': 'Manager',
    'remit': 'Runs the trial.',
    'roleNotes': 'Two sites are available.',
    'starterQuestion': 'How much time do we have?',
    'moves': ['Start small', 'Try both sites'],
    'moveDebriefs': ['Less exposure', 'More data'],
    'sources': {'Report': 'https://example.org/report'},
    'factCheck': {
      'question': 'What does the report confirm?',
      'options': ['One site', 'Two sites'],
      'correct': 0,
      'explanation': 'It names one site.',
    },
    'scene': {
      'file': '$id-v1-$lang.mp3',
      'lines': [
        {'speaker': 'Narrator', 'text': 'The trial starts tomorrow.'},
        {'speaker': 'Manager', 'text': 'Which site shall we visit?'},
      ],
    },
  };
  return {
    'schema': 1,
    'revision': 1,
    'cases': [
      {'id': id, 'newsDate': '2026-01-01', ...copy('es'), 'en': copy('en')},
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = File(NewsFeed.asset).readAsStringSync();
  test(
    'packaged meeting recordings match their transcripts and locale',
    () async {
      final cases = [...await BusinessCase.load(), ...await NewsFeed.load()];
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final c in cases) {
        for (final lang in ['es', 'en']) {
          final scene = c.localized(lang).scene;
          if (scene == null) continue;
          expect(scene['file'], endsWith('-$lang.mp3'));
          expect(
            manifest.listAssets(),
            contains('editorial/audio/${scene['file']}'),
          );
          expect(
            (scene['lines'] as List).map((l) => l['speaker']).toSet().length,
            2,
          );
        }
      }
    },
  );
  test(
    'editorial edition is playable offline, bilingual and newest first',
    () async {
      final feed = NewsFeed.parse(source);
      expect(feed.cases, isNotEmpty);
      final bundled = await NewsFeed.load();
      expect(
        bundled.map((c) => c.id),
        orderedEquals(feed.cases.map((c) => c.id)),
      );
      final dates = feed.cases
          .map((c) => c.data['newsDate'] as String)
          .toList();
      expect(dates, orderedEquals([...dates]..sort((a, b) => b.compareTo(a))));
      for (final c in feed.cases) {
        expect(c.id, startsWith('news-'));
        expect(c.localized('en').title, isNot(c.title));
        expect(
          c.localized('en').sources.values.toSet(),
          c.sources.values.toSet(),
        );
      }
    },
  );
  test(
    'translations cannot override identity and older editions can omit debriefs',
    () {
      final data = _editionFixture();
      for (final item in data['cases']) {
        item.remove('moveDebriefs');
        item.remove('factCheck');
        item.remove('scene');
        item['en'].remove('scene');
        item['en'].remove('factCheck');
        item['en'].remove('moveDebriefs');
        item['en']['track'] = 'fde';
        item['en']['id'] = 'netflix';
        item['en']['newsDate'] = '2000-01-01';
      }
      for (final c in NewsFeed.parse(jsonEncode(data)).cases) {
        for (final locale in ['es', 'en']) {
          final localized = c.localized(locale);
          expect(localized.scene, isNull);
          expect(localized.data['factCheck'], isNull);
          expect(localized.data['moveDebriefs'], isNull);
        }
        expect(c.localized('en').isFde, isFalse);
        expect(c.data['en'], isNot(contains('newsDate')));
        expect(c.data['en'], isNot(contains('id')));
      }
    },
  );
  test('rejects incomplete, duplicate or unsafe editions atomically', () {
    expect(NewsFeed.parse(jsonEncode(_editionFixture())).cases, hasLength(1));
    for (final change in <void Function(Map<String, dynamic>)>[
      (e) => e['schema'] = 2,
      (e) => e['cases'].add(e['cases'].first),
      (e) => e['cases'].first['en'].remove('roleNotes'),
      (e) => e['cases'].first['newsDate'] = '2026-02-31',
      (e) => e['cases'].first['sources'] = {'Open': 'javascript:alert(1)'},
      (e) => e['cases'].first['en']['moveDebriefs'] = ['One'],
      (e) => e['cases'].first['en'].remove('factCheck'),
      (e) => e['cases'].first['en']['factCheck']['correct'] =
          1 - (e['cases'].first['factCheck']['correct'] as int),
      (e) => e['cases'].first['factCheck']['options'] = [],
      (e) => e['cases'].first['factCheck']['correct'] = false,
      (e) => e['cases'].first['en']['moves'] = ['Only one'],
      (e) => e['cases'].first['en']['scene']['file'] = '../foreign.mp3',
      (e) => e['cases'].first['scene']['lines'] = [],
      (e) => e['cases'].first['en'].remove('scene'),
    ]) {
      final bad = _editionFixture();
      change(bad);
      expect(() => NewsFeed.parse(jsonEncode(bad)), throwsFormatException);
    }
  });
}
