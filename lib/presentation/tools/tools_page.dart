import 'package:material_ui/material_ui.dart';

import '../theme/lydo_theme.dart';

/// Aba "Ferramentas": vitrine do que vem nas próximas fases.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  static const _tools = [
    (Icons.border_color_outlined, 'Anotar', 'Realçar, caneta, texto e notas'),
    (Icons.draw_outlined, 'Assinar', 'Assine documentos com o dedo'),
    (Icons.document_scanner_outlined, 'Reconhecer texto (OCR)', 'Transforme PDF escaneado em texto'),
    (Icons.call_merge, 'Juntar PDFs', 'Una vários arquivos em um só'),
    (Icons.call_split, 'Dividir PDF', 'Separe páginas em outro arquivo'),
    (Icons.rotate_right, 'Organizar páginas', 'Girar, reordenar e excluir'),
    (Icons.image_outlined, 'Imagens para PDF', 'Fotos viram um PDF'),
    (Icons.auto_awesome_outlined, 'Resumo com IA', 'Pergunte e resuma o documento'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text('Ferramentas', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Chegando nas próximas versões do Lydo.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.mutedText)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tools.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, i) {
              final (icon, title, subtitle) = _tools[i];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text('$title chega em breve.'))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.softPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: LydoColors.primary),
                        ),
                        const Spacer(),
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
                        const SizedBox(height: 6),
                        Text('EM BREVE',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: LydoColors.primary)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
