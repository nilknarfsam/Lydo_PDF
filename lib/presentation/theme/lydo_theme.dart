import 'package:material_ui/material_ui.dart';

/// Cores e tema do Lydo (baseado nas telas de referência).
abstract final class LydoColors {
  static const primary = Color(0xFF2F6BF6);
  static const primarySoft = Color(0xFFE6EEFF);
  static const pdfRed = Color(0xFFE5484D);

  // Claro
  static const lightBg = Color(0xFFF6F8FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2E6EE);
  static const lightText = Color(0xFF0F1523);
  static const lightMuted = Color(0xFF5B6475);

  // Escuro
  static const darkBg = Color(0xFF0D121B);
  static const darkSurface = Color(0xFF161D29);
  static const darkBorder = Color(0xFF2A3344);
  static const darkText = Color(0xFFF2F5FA);
  static const darkMuted = Color(0xFFA3ACBD);

  /// Fundo atrás das páginas no leitor.
  static const readerBg = Color(0xFF0D121B);
}

/// Atalhos para as cores "de marca" que não existem no ColorScheme.
extension LydoContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get borderColor => isDark ? LydoColors.darkBorder : LydoColors.lightBorder;
  Color get mutedText => isDark ? LydoColors.darkMuted : LydoColors.lightMuted;
  Color get softPrimary => isDark ? const Color(0xFF1C2A47) : LydoColors.primarySoft;
}

abstract final class LydoTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? LydoColors.darkBg : LydoColors.lightBg;
    final surface = dark ? LydoColors.darkSurface : LydoColors.lightSurface;
    final border = dark ? LydoColors.darkBorder : LydoColors.lightBorder;
    final text = dark ? LydoColors.darkText : LydoColors.lightText;
    final muted = dark ? LydoColors.darkMuted : LydoColors.lightMuted;

    final scheme = ColorScheme.fromSeed(
      seedColor: LydoColors.primary,
      brightness: b,
    ).copyWith(
      primary: LydoColors.primary,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: border,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: border),
    );

    return ThemeData(
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero, shape: shape),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      textTheme: TextTheme(
        headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: text),
        bodyLarge: TextStyle(fontSize: 16, color: text),
        bodyMedium: TextStyle(fontSize: 14, color: text),
        bodySmall: TextStyle(fontSize: 13, color: muted),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LydoColors.primary, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LydoColors.primary,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: dark ? const Color(0xFF1C2A47) : LydoColors.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 13,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? LydoColors.primary : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? LydoColors.primary : muted),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? LydoColors.primary : border,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: LydoColors.primary,
        linearTrackColor: border,
      ),
    );
  }
}

/// Logo do Lydo: folha azul com a ponta dobrada.
class LydoLogo extends StatelessWidget {
  const LydoLogo({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size * 0.8, size), painter: _LogoPainter());
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final fold = s.width * 0.38;
    final r = s.width * 0.14;
    final body = Path()
      ..moveTo(r, 0)
      ..lineTo(s.width - fold, 0)
      ..lineTo(s.width, fold)
      ..lineTo(s.width, s.height - r)
      ..quadraticBezierTo(s.width, s.height, s.width - r, s.height)
      ..lineTo(r, s.height)
      ..quadraticBezierTo(0, s.height, 0, s.height - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
    canvas.drawPath(body, Paint()..color = LydoColors.primary);
    final corner = Path()
      ..moveTo(s.width - fold, 0)
      ..lineTo(s.width - fold, fold)
      ..lineTo(s.width, fold)
      ..close();
    canvas.drawPath(corner, Paint()..color = const Color(0xFF9DB8FF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
