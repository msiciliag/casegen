import 'dart:convert';
import 'package:casegen/ai.dart';
import 'package:casegen/cases.dart';
import 'package:casegen/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<BusinessCase> cases;
  setUpAll(() async {
    cases = await BusinessCase.load();
  });
  test(
    'Each interview briefs both roles and keeps the outcome out of play',
    () async {
      final config = Connection(
        checkedEndpoint(groqEndpoint),
        groqModel,
        'test',
      );
      addTearDown(() => appLanguage.value = 'es');
      for (final lang in ['es', 'en']) {
        appLanguage.value = lang;
        for (final item in cases) {
          final c = item.localized(lang);
          expect(c.playerRole, isNotEmpty, reason: c.id);
          expect(c.remit, isNotEmpty, reason: c.id);
          expect(c.starterQuestion, isNotEmpty, reason: c.id);
          expect(c.moves.toSet(), hasLength(2), reason: c.id);
          expect(
            c.moveDebriefs.toSet(),
            hasLength(c.moves.length),
            reason: c.id,
          );
          final messages =
              config.payload(c, c.starterQuestion, interview: [])['messages']
                  as List;
          final instructions = messages.first['content'] as String;
          for (final field in [
            c.role,
            c.playerRole,
            c.roleNotes,
            c.remit,
            c.brief,
          ]) {
            expect(instructions, contains(field), reason: c.id);
          }
          expect(instructions, isNot(contains(c.decision)));
          expect(instructions, isNot(contains(c.outcome)));
          final notes = [
            {'role': 'user', 'content': 'Mi pregunta'},
            {'role': 'assistant', 'content': 'Simulated answer'},
          ];
          final review =
              config.payload(
                    c,
                    'Mi decisión',
                    reviewInterview: notes,
                  )['messages']
                  as List;
          expect(review, hasLength(2));
          expect(review[0]['content'], isNot(contains('Simulated answer')));
          expect(
            jsonDecode(review[1]['content'])[lang == 'es'
                ? 'notas_de_la_entrevista_simulada'
                : 'simulated_interview_notes'],
            notes,
          );
        }
      }
    },
  );

  testWidgets(
    'A first-time player identifies the Netflix stakeholder and can edit the suggested question before sending',
    (tester) async {
      final c = cases.firstWhere((c) => c.id == 'netflix');
      final turns = <Map<String, String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: [AiReview(c, '', interview: turns)]),
          ),
        ),
      );
      expect(find.textContaining(c.role), findsOneWidget);
      expect(find.text(c.remit), findsOneWidget);
      expect(find.textContaining(c.playerRole), findsOneWidget);
      await tester.tap(find.text(c.starterQuestion));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, c.starterQuestion);
      expect(turns, isEmpty);
      await tester.enterText(
        find.byType(TextField),
        '¿Quién conoce las tarifas?',
      );
      expect(field.controller!.text, '¿Quién conoce las tarifas?');
    },
  );
}
