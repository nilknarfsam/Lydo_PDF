import 'package:flutter/foundation.dart';

import '../../domain/page_plan.dart';

/// Estado da tela "Organizar páginas". Só monta o [plan]; não toca no PDF.
///
/// Listas em [slots] nunca são alteradas no lugar: cada mudança cria uma nova lista,
/// e a pilha de desfazer guarda as versões anteriores.
class PageOrganizerController {
  PageOrganizerController(this.pageCount) : slots = ValueNotifier(PagePlan.identity(pageCount).slots);

  final int pageCount;
  final ValueNotifier<List<PageSlot>> slots;

  /// Índices (na lista atual) das páginas selecionadas.
  final ValueNotifier<Set<int>> selected = ValueNotifier<Set<int>>(<int>{});
  final ValueNotifier<bool> canUndo = ValueNotifier<bool>(false);

  final List<List<PageSlot>> _history = [];

  bool get hasChanges => !PagePlan(slots.value).isIdentity(pageCount);

  PagePlan get plan => PagePlan(List.unmodifiable(slots.value));

  void toggleSelect(int index) {
    if (index < 0 || index >= slots.value.length) return;
    final next = {...selected.value};
    if (!next.remove(index)) next.add(index);
    selected.value = next;
  }

  /// Gira as páginas selecionadas 90° no sentido horário. Sem seleção, não faz nada.
  void rotateSelected() {
    if (selected.value.isEmpty) return;
    final current = slots.value;
    final chosen = selected.value;
    _pushHistory();
    slots.value = [
      for (var i = 0; i < current.length; i++) chosen.contains(i) ? current[i].rotated() : current[i],
    ];
  }

  /// Exclui as páginas selecionadas.
  /// Retorna false (e não apaga nada) se não há seleção ou se apagaria todas as páginas.
  bool deleteSelected() {
    final current = slots.value;
    final toRemove = selected.value.where((i) => i >= 0 && i < current.length).toSet();
    if (toRemove.isEmpty || toRemove.length >= current.length) return false;
    _pushHistory();
    slots.value = [
      for (var i = 0; i < current.length; i++)
        if (!toRemove.contains(i)) current[i],
    ];
    selected.value = <int>{};
    return true;
  }

  /// Move uma página. Segue a semântica do ReorderableListView: [to] é a posição
  /// de inserção antes da remoção, então se to > from ele é reduzido em 1.
  void move(int from, int to) {
    final current = slots.value;
    if (from < 0 || from >= current.length) return;
    if (to < 0 || to > current.length) return;
    final target = to > from ? to - 1 : to;
    if (target == from) return;
    final next = [...current];
    final item = next.removeAt(from);
    next.insert(target, item);
    _pushHistory();
    slots.value = next;
    selected.value = <int>{};
  }

  void undo() {
    if (_history.isEmpty) return;
    slots.value = _history.removeLast();
    selected.value = <int>{};
    canUndo.value = _history.isNotEmpty;
  }

  void _pushHistory() {
    _history.add(slots.value);
    canUndo.value = true;
  }

  void dispose() {
    slots.dispose();
    selected.dispose();
    canUndo.dispose();
  }
}
