import 'package:casegen/cases.dart';
import 'package:casegen/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryHistory extends History {
  final saved = <String>[];
  @override
  Future<void> save(BusinessCase c, String answer) async => saved.add(answer);
}

void main() {
  testWidgets(
    'Los casos de negocio y FDE se leen y permiten guardar en una pantalla estrecha',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final cases = await BusinessCase.load();
      expect(
        cases.map((c) => c.id),
        containsAll(['netflix', 'mulan', 'stadia']),
      );
      final history = MemoryHistory();
      for (final c in cases) {
        await tester.pumpWidget(
          MaterialApp(home: Reader(c, history, key: ValueKey(c.id))),
        );
        expect(find.text(c.decision), findsNothing);
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
}
