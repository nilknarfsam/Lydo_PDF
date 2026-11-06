/// Uma página no novo arranjo: qual página original (1-based) e quantos giros de 90° no sentido horário (0..3).
class PageSlot {
  const PageSlot({required this.sourcePage, this.quarterTurns = 0});

  final int sourcePage;
  final int quarterTurns;

  PageSlot rotated() => PageSlot(sourcePage: sourcePage, quarterTurns: (quarterTurns + 1) % 4);
}

/// Plano de páginas do PDF: a ordem final, com giros e sem as páginas excluídas.
/// Não altera o PDF; quem aplica o plano é outro código.
class PagePlan {
  const PagePlan(this.slots);

  final List<PageSlot> slots;

  /// Plano sem alterações: 1..n, na ordem, sem giro.
  factory PagePlan.identity(int pageCount) =>
      PagePlan([for (var p = 1; p <= pageCount; p++) PageSlot(sourcePage: p)]);

  /// Verdadeiro se ainda são todas as [originalCount] páginas, na mesma ordem e sem giro.
  bool isIdentity(int originalCount) {
    if (slots.length != originalCount) return false;
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].sourcePage != i + 1 || slots[i].quarterTurns != 0) return false;
    }
    return true;
  }

  /// Nova numeração (1-based) de uma página original, ou null se foi excluída.
  int? newNumberOf(int sourcePage) {
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].sourcePage == sourcePage) return i + 1;
    }
    return null;
  }
}
