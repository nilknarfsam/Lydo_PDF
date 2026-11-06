import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/domain/page_plan.dart';
import 'package:pdf_reader/presentation/edit/page_organizer_controller.dart';

List<int> _order(PagePlan plan) => plan.slots.map((s) => s.sourcePage).toList();

void main() {
  group('PagePlan', () {
    test('identity numera 1..n, na ordem e sem giro', () {
      final plan = PagePlan.identity(3);
      expect(_order(plan), [1, 2, 3]);
      expect(plan.slots.every((s) => s.quarterTurns == 0), isTrue);
      expect(plan.isIdentity(3), isTrue);
    });

    test('isIdentity é falso com giro, reordenação ou contagem diferente', () {
      final rotated = PagePlan([const PageSlot(sourcePage: 1, quarterTurns: 1), const PageSlot(sourcePage: 2)]);
      expect(rotated.isIdentity(2), isFalse);

      final reordered = PagePlan([const PageSlot(sourcePage: 2), const PageSlot(sourcePage: 1)]);
      expect(reordered.isIdentity(2), isFalse);

      final identity2 = PagePlan.identity(2);
      expect(identity2.isIdentity(3), isFalse);
    });

    test('newNumberOf após excluir e mover', () {
      // Original: 1,2,3. Exclui a 2 e move a 3 para antes da 1.
      final plan = PagePlan([const PageSlot(sourcePage: 3), const PageSlot(sourcePage: 1)]);
      expect(plan.newNumberOf(3), 1);
      expect(plan.newNumberOf(1), 2);
      expect(plan.newNumberOf(2), isNull);
    });
  });

  group('PageOrganizerController', () {
    test('girar 4 vezes volta ao original (sem alterações)', () {
      final c = PageOrganizerController(3);
      addTearDown(c.dispose);
      c.toggleSelect(1);
      for (var i = 0; i < 4; i++) {
        c.rotateSelected();
      }
      expect(c.slots.value[1].quarterTurns, 0);
      expect(c.hasChanges, isFalse);
    });

    test('rotateSelected sem seleção não faz nada', () {
      final c = PageOrganizerController(2);
      addTearDown(c.dispose);
      c.rotateSelected();
      expect(c.slots.value.every((s) => s.quarterTurns == 0), isTrue);
      expect(c.canUndo.value, isFalse);
    });

    test('excluir todas as páginas é recusado e nada é apagado', () {
      final c = PageOrganizerController(2);
      addTearDown(c.dispose);
      c.toggleSelect(0);
      c.toggleSelect(1);
      expect(c.deleteSelected(), isFalse);
      expect(c.slots.value.length, 2);
    });

    test('excluir parte remove as páginas e limpa a seleção', () {
      final c = PageOrganizerController(3);
      addTearDown(c.dispose);
      c.toggleSelect(1);
      expect(c.deleteSelected(), isTrue);
      expect(_order(c.plan), [1, 3]);
      expect(c.plan.newNumberOf(2), isNull);
      expect(c.selected.value, isEmpty);
      expect(c.hasChanges, isTrue);
    });

    test('move segue a semântica do ReorderableListView', () {
      final c = PageOrganizerController(3);
      addTearDown(c.dispose);

      c.move(0, 3); // leva a 1 para o fim
      expect(_order(c.plan), [2, 3, 1]);

      c.move(2, 0); // leva a última de volta ao início
      expect(_order(c.plan), [1, 2, 3]);
    });

    test('mover para o mesmo lugar não muda nada e não entra no histórico', () {
      final c = PageOrganizerController(3);
      addTearDown(c.dispose);
      c.move(1, 1);
      c.move(1, 2);
      expect(_order(c.plan), [1, 2, 3]);
      expect(c.canUndo.value, isFalse);
    });

    test('undo desfaz giro e reordenação', () {
      final c = PageOrganizerController(3);
      addTearDown(c.dispose);

      c.toggleSelect(0);
      c.rotateSelected();
      expect(c.slots.value[0].quarterTurns, 1);
      c.undo();
      expect(c.slots.value[0].quarterTurns, 0);
      expect(c.canUndo.value, isFalse);

      c.move(0, 3);
      expect(_order(c.plan), [2, 3, 1]);
      c.undo();
      expect(_order(c.plan), [1, 2, 3]);
      expect(c.hasChanges, isFalse);
    });

    test('hasChanges acompanha giro, reordenação e exclusão', () {
      final c = PageOrganizerController(2);
      addTearDown(c.dispose);
      expect(c.hasChanges, isFalse);

      c.toggleSelect(0);
      c.rotateSelected();
      expect(c.hasChanges, isTrue);
      c.undo();
      expect(c.hasChanges, isFalse);

      c.move(0, 2);
      expect(c.hasChanges, isTrue);
      c.undo();
      expect(c.hasChanges, isFalse);

      c.toggleSelect(1);
      expect(c.deleteSelected(), isTrue);
      expect(c.hasChanges, isTrue);
    });
  });
}
