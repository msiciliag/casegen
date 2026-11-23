import 'dart:convert';
import 'dart:io';
import 'package:casegen/cases.dart';
import 'package:casegen/news.dart';
import 'package:casegen/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryHistory extends History {
  final saved = <String>[];
  final drafts = <String, String>{};
  final attempts = <Map<String, dynamic>>[];
  int factWrites = 0;
  @override
  Future<Map<String, dynamic>?> draft(String id) async =>
      drafts.containsKey(id) ? jsonDecode(drafts[id]!) : null;
  @override
  Future<void> putDraft(String id, String value) async {
    drafts[id] = value;
  }

  @override
  Future<void> recordCheck(int id, int pick) async {
    factWrites++;
    attempts[id - 1]['fact_pick'] ??= pick;
  }

  @override
  Future<int> save(
    BusinessCase c,
    String answer, {
    int? move,
    List<Map<String, String>> turns = const [],
  }) async {
    saved.add(answer);
    attempts.add({
      'snapshot': jsonEncode(c.data),
      'answer': answer,
      'move_index': move,
      'transcript': jsonEncode(turns),
    });
    drafts.remove(c.id);
    return saved.length;
  }
}

Future<void> reveal(WidgetTester tester, Finder item) async {
  await tester.scrollUntilVisible(
    item,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(item), alignment: .5);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late final List<BusinessCase> cases;
  setUpAll(() async {
    cases = [...await BusinessCase.load(), ...await NewsFeed.load()];
  });
  testWidgets(
    'The meeting transcript and a quick strategy are playable offline',
    (tester) async {
      final c = cases.firstWhere(
        (item) => item.id == 'netflix',
      );
      final history = MemoryHistory();
      await tester.pumpWidget(MaterialApp(home: Reader(c, history)));
      await tester.pumpAndSettle();
      Future<void> tap(String label) async {
        final item = find.text(label);
        await reveal(tester, item);
        await tester.tap(item);
        await tester.pumpAndSettle();
      }

      await tap('Dramatización · Ver guion');
      expect(find.text(c.scene!['lines'].first['text']), findsOneWidget);
      expect(find.text(c.decision), findsNothing);
      Navigator.of(
        tester.element(find.text(c.scene!["lines"].first["text"])),
      ).pop();
      await tester.pumpAndSettle();
      await tap('Tomar una decisión');
      await tap(c.moves.first);
      await tap('Guardar y ver el desenlace');
      expect(history.saved.single, c.moves.first);
      expect(find.text(c.decision), findsOneWidget);
    },
  );
  testWidgets(
    'Los casos de negocio y FDE se leen y permiten guardar en una pantalla estrecha',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      expect(
        cases.map((c) => c.id),
        containsAll(['netflix', 'mulan', 'stadia']),
      );
      final history = MemoryHistory();
      for (final c in cases) {
        await tester.pumpWidget(
          MaterialApp(home: Reader(c, history, key: ValueKey(c.id))),
        );
        await tester.pumpAndSettle();
        expect(find.text(c.decision), findsNothing);
        final proceed = find.text('Tomar una decisión');
        await tester.scrollUntilVisible(
          proceed,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(proceed), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(proceed);
        await tester.pumpAndSettle();
        final submit = find.text('Guardar y ver el desenlace');
        await tester.scrollUntilVisible(
          submit,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(submit), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pump();
        expect(
          find.text('Escribe tu propuesta para continuar.'),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), c.title);
        await tester.ensureVisible(submit);
        await Scrollable.ensureVisible(tester.element(submit), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text(c.decision), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(history.saved, cases.map((c) => c.title));
    },
  );
  testWidgets(
    'Resume the same news edition and transcript, submit once and revisit the settled fact check',
    (tester) async {
      final c = NewsFeed.parse(
        File(NewsFeed.asset).readAsStringSync(),
      ).cases.first;
      final replacement = BusinessCase(c.id, {
        ...c.data,
        'title': 'Edición posterior',
        'moves': ['Otra postura', 'Una más'],
      });
      final history = MemoryHistory();
      final turns = [
        {'role': 'user', 'content': '¿Qué información te falta?'},
        {'role': 'assistant', 'content': 'Todavía no conozco el presupuesto.'},
      ];
      // An interview was completed before the player left the brief.
      await history.putDraft(
        c.id,
        jsonEncode({'snapshot': c.data, 'turns': turns, 'deciding': false}),
      );
      Future<void> open(Reader reader) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(MaterialApp(home: reader));
        await tester.pumpAndSettle();
      }

      Future<void> tapText(String text) async {
        final item = find.text(text);
        await reveal(tester, item);
        await tester.tap(item);
        await tester.pumpAndSettle();
      }

      await open(Reader(c, history));
      await tapText('Ver entrevista');
      expect(find.text(turns.last['content']!), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText('Tomar una decisión');
      await tapText(c.moves[1]);
      const reason = 'Reservaría el equipo solo después de la prueba.';
      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), reason);
      await tester.pumpAndSettle();
      final draft = (await history.draft(c.id))!;
      expect(draft['turns'], turns);
      expect(draft['move'], 1);
      expect(draft['deciding'], isTrue);
      expect(draft['snapshot']['title'], c.title);

      await open(Reader(replacement, history));
      expect(find.text(c.title), findsOneWidget);
      expect(find.text(replacement.title), findsNothing);
      await reveal(tester, find.byType(TextField));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        reason,
      );
      await tapText('Guardar y ver el desenlace');
      final attempt = history.attempts.single;
      expect(history.drafts, isEmpty);
      expect(attempt['answer'], '${c.moves[1]}\n\n$reason');
      expect(attempt['move_index'], 1);
      expect(jsonDecode(attempt['transcript']), turns);
      expect(jsonDecode(attempt['snapshot'])['title'], c.title);

      final check = c.factCheck!;
      final incorrect = 1 - (check['correct'] as int);
      final option = find.text(check['options'][incorrect]);
      await reveal(tester, option);
      await tester.tap(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(history.factWrites, 1);
      expect(attempt['fact_pick'], incorrect);
      expect(find.text(check['explanation']), findsOneWidget);

      await open(
        Reader(
          BusinessCase(c.id, jsonDecode(attempt['snapshot'])),
          history,
          answer: attempt['answer'],
          previousId: 1,
          previousPick: attempt['fact_pick'],
          previousMove: attempt['move_index'],
          previousTurns: [
            for (final t in jsonDecode(attempt['transcript']))
              Map<String, String>.from(t),
          ],
        ),
      );
      await reveal(tester, find.text(check['explanation']));
      expect(find.text('Revisa el matiz.'), findsOneWidget);
      expect(find.text(check['options'][incorrect]), findsNothing);
      await tapText('Tu entrevista');
      await reveal(tester, find.text(turns.last['content']!));
      expect(history.factWrites, 1);
      expect(history.attempts, hasLength(1));
    },
  );
}
