import 'package:material_ui/material_ui.dart';

import '../theme/lydo_theme.dart';

const _bar = Color(0xFF1A2130);
const _barBorder = Color(0xFF2C3546);
const _onBar = Colors.white;
const _onBarMuted = Color(0xFFA3ACBD);

/// Ações da aba Editar. A tela decide o que cada uma faz.
enum EditAction { image, signature, pages, export }

/// Barra de ferramentas do modo Editar (só callbacks, sem lógica de PDF).
class EditToolbar extends StatelessWidget {
  const EditToolbar({super.key, required this.onAction, required this.hint, this.busy = false});

  final ValueChanged<EditAction> onAction;

  /// Texto de ajuda acima da barra (ex.: "Toque na página onde quer a assinatura"); null = mostra "Escolha o que adicionar ou organizar".
  final String? hint;

  /// Enquanto true, mostra LinearProgressIndicator fino no topo da barra e desabilita os botões.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Hint(text: hint ?? 'Escolha o que adicionar ou organizar'),
              const SizedBox(height: 10),
              _Tools(onAction: onAction, busy: busy),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _barBorder),
      ),
      child: Text(text, style: const TextStyle(color: _onBarMuted, fontSize: 14)),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.onAction, required this.busy});
  final ValueChanged<EditAction> onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    Widget item(EditAction action, IconData icon, String label) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: busy ? null : () => onAction(action),
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: _onBar, size: 26),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(color: _onBar, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _barBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const LinearProgressIndicator(
                minHeight: 2,
                color: LydoColors.primary,
                backgroundColor: Colors.transparent,
              ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  item(EditAction.image, Icons.image_outlined, 'Imagem'),
                  item(EditAction.signature, Icons.draw_outlined, 'Assinar'),
                  item(EditAction.pages, Icons.copy_all_outlined, 'Páginas'),
                  item(EditAction.export, Icons.ios_share, 'Exportar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
