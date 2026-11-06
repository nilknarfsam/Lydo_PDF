import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../core/result.dart';
import '../../domain/signature_repository.dart';
import '../theme/lydo_theme.dart';

/// Resultado: assinatura escolhida, ou pedido para criar uma nova.
sealed class SignatureChoice {
  const SignatureChoice();
}

class UseSaved extends SignatureChoice {
  const UseSaved(this.signature);
  final SavedSignature signature;
}

class CreateNew extends SignatureChoice {
  const CreateNew();
}

/// Abre a folha com as assinaturas salvas. Devolve null se o usuário fechar.
Future<SignatureChoice?> showSignaturePicker(BuildContext context, SignatureRepository repository) {
  return showModalBottomSheet<SignatureChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SignaturePickerSheet(repository: repository),
  );
}

sealed class _SignatureList {
  const _SignatureList();
}

final class _Loading extends _SignatureList {
  const _Loading();
}

final class _Failed extends _SignatureList {
  const _Failed(this.message);
  final String message;
}

final class _Ready extends _SignatureList {
  const _Ready(this.items);
  final List<SavedSignature> items;
}

class _SignaturePickerSheet extends StatefulWidget {
  const _SignaturePickerSheet({required this.repository});
  final SignatureRepository repository;

  @override
  State<_SignaturePickerSheet> createState() => _SignaturePickerSheetState();
}

class _SignaturePickerSheetState extends State<_SignaturePickerSheet> {
  final _list = ValueNotifier<_SignatureList>(const _Loading());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _list.value = const _Loading();
    final result = await widget.repository.list();
    if (!mounted) return;
    _list.value = switch (result) {
      Ok(:final value) => _Ready(value),
      Err(:final failure) => _Failed(failure.message),
    };
  }

  Future<void> _delete(SavedSignature signature) async {
    final result = await widget.repository.delete(signature.id);
    if (!mounted) return;
    if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.6;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Assinaturas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(const CreateNew()),
              icon: const Icon(Icons.add),
              label: const Text('Nova assinatura'),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ValueListenableBuilder<_SignatureList>(
                valueListenable: _list,
                builder: (context, state, _) => _buildState(context, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildState(BuildContext context, _SignatureList state) {
    final muted = context.mutedText;
    return switch (state) {
      _Loading() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      _Failed(:final message) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ),
      _Ready(:final items) when items.isEmpty => Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'Nenhuma assinatura salva ainda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        ),
      _Ready(:final items) => ListView.separated(
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _SignatureCard(
            signature: items[i],
            onUse: () => Navigator.of(context).pop(UseSaved(items[i])),
            onDelete: () => _delete(items[i]),
          ),
        ),
    };
  }
}

/// Cartão branco: assinaturas são PNG transparente com traço escuro.
class _SignatureCard extends StatelessWidget {
  const _SignatureCard({required this.signature, required this.onUse, required this.onDelete});
  final SavedSignature signature;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onUse,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Image.file(
                    File(signature.path),
                    height: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Color(0xFF5B6475)),
                  ),
                ),
                IconButton(
                  tooltip: 'Excluir assinatura',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Color(0xFF5B6475)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
