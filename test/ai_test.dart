import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:casegen/ai.dart';
import 'package:casegen/cases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Cambiar de destino requiere una clave nueva; olvidar elimina la conexión',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final previous = Connection(
        checkedEndpoint(groqEndpoint),
        groqModel,
        'mock-old',
      );
      await previous.store();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openAiSettings(context),
              child: const Text('Ajustes'),
            ),
          ),
        ),
      );
      Future<void> edit() async {
        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();
      }

      await edit();
      await tester.tap(find.text('Otro compatible con OpenAI').last);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.last).controller!.text, isEmpty);
      await tester.enterText(
        fields.at(0),
        'https://example.org/v1/chat/completions',
      );
      await tester.enterText(fields.at(1), 'prueba');
      await tester.tap(find.text('Guardar conexión'));
      await tester.pumpAndSettle();
      expect((await Connection.read())!.url, previous.url);
      expect(
        find.text('Introduce una clave válida para este destino.'),
        findsOneWidget,
      );
      await tester.enterText(fields.at(2), 'mock-new');
      await tester.tap(find.text('Guardar conexión'));
      await tester.pumpAndSettle();
      expect((await Connection.read())!.key, 'mock-new');
      await edit();
      await tester.tap(find.text('Olvidar clave y conexión'));
      await tester.pumpAndSettle();
      expect(await Connection.read(), isNull);
    },
  );
  test(
    'La conexión antigua de Groq conserva su clave al cambiar de modelo',
    () async {
      const oldModel = 'openai/gpt-oss-120b';
      const newModel = 'qwen/qwen3.8-27b';
      const otherEndpoint = 'https://example.org/v1/chat/completions';
      for (final (url, old, expected) in [
        (groqEndpoint, oldModel, newModel),
        (groqEndpoint, 'mi-modelo', 'mi-modelo'),
        (otherEndpoint, oldModel, oldModel),
        (otherEndpoint, newModel, newModel),
      ]) {
        FlutterSecureStorage.setMockInitialValues({
          configKey: jsonEncode({'url': url, 'model': old, 'key': 'mock-byok'}),
        });
        final config = (await Connection.read())!;
        expect(config.url.toString(), url);
        expect(config.model, expected);
        expect(config.key, 'mock-byok');
      }

      await Connection(
        checkedEndpoint(groqEndpoint),
        oldModel,
        'mock-choice',
      ).store();
      final stored = jsonDecode((await vault.read(key: configKey))!);
      expect(stored['version'], 2);
      final explicit = (await Connection.read())!;
      expect(explicit.model, oldModel);
      expect(explicit.key, 'mock-choice');
    },
  );
  test(
    'Groq usa los parámetros acordados y el proveedor alternativo recibe solo el contrato común',
    () async {
      final cases = await BusinessCase.load();
      expect(cases.where((c) => c.isFde).length, 5);
      final c = cases.firstWhere((c) => c.isFde);
      final config = Connection(
        checkedEndpoint(groqEndpoint),
        groqModel,
        'mock',
      );
      final payload = config.payload(c, 'Mi propuesta');
      expect(payload['model'], 'qwen/qwen3.8-27b');
      expect(payload['reasoning_effort'], 'high');
      expect(payload['reasoning_format'], 'parsed');
      expect(payload['max_completion_tokens'], 4096);
      expect(payload['stream'], true);
      final chat =
          config.payload(
                c,
                '¿Qué necesitas?',
                interview: [
                  {'role': 'user', 'content': '¿Quién decide?'},
                  {'role': 'assistant', 'content': 'Yo.'},
                ],
              )['messages']
              as List;
      expect(chat.first['content'], contains(c.roleNotes));
      expect(chat.first['content'], isNot(contains(c.decision)));
      expect(chat.last['content'], '¿Qué necesitas?');
      expect(chat.length, 4);
      for (final (endpoint, model) in [
        ('https://example.org/v1/chat/completions', groqModel),
        (groqEndpoint, 'mi-modelo'),
      ]) {
        final other = Connection(
          checkedEndpoint(endpoint),
          model,
          'mock-other-key',
        );
        final custom = other.payload(c, 'respuesta');
        expect(custom.keys, unorderedEquals(['model', 'messages', 'stream']));
        expect(custom['model'], model);
        expect(jsonEncode(custom), isNot(contains(other.key)));
      }
      for (final endpoint in [
        'http://example.org/v1',
        'https://key@example.org/v1',
        'https://example.org/v1?key=x',
      ]) {
        expect(() => checkedEndpoint(endpoint), throwsFormatException);
      }
    },
  );
  test(
    'Streaming fragmentado: solo se muestra texto y un corte se detecta',
    () async {
      const events =
          'data: {"choices":[{"delta":{"reasoning":"interno"}}]}\r\n\r\ndata: {"choices":[{"delta":{"content":"útil"}}]}\n\ndata: [DONE]\n\n';
      final chunks = Stream.fromIterable(utf8.encode(events).map((b) => [b]));
      expect(await completionText(chunks).join(), 'útil');
      await expectLater(
        completionText(const Stream.empty()).toList(),
        throwsA(isA<ReviewError>()),
      );
    },
  );
}
