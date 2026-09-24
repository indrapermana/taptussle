import 'package:flutter/material.dart';

abstract final class TapTussleColors {
  static const midnight = Color(0xFF061129);
  static const navy = Color(0xFF0A1E42);
  static const panel = Color(0xE610294A);
  static const panelBorder = Color(0xFF294D73);
  static const electricBlue = Color(0xFF27C7FF);
  static const rivalRed = Color(0xFFFF4F59);
  static const gold = Color(0xFFFFD338);
  static const text = Color(0xFFF7FBFF);
  static const mutedText = Color(0xFFB8CAE0);
}

ThemeData buildTapTussleTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Fredoka',
    scaffoldBackgroundColor: TapTussleColors.midnight,
    colorScheme: const ColorScheme.dark(
      primary: TapTussleColors.electricBlue,
      onPrimary: TapTussleColors.midnight,
      secondary: TapTussleColors.rivalRed,
      onSecondary: Colors.white,
      tertiary: TapTussleColors.gold,
      onTertiary: TapTussleColors.midnight,
      surface: TapTussleColors.navy,
      onSurface: TapTussleColors.text,
      error: Color(0xFFFF747C),
    ),
  );
  final textTheme = base.textTheme
      .apply(bodyColor: TapTussleColors.text, displayColor: Colors.white)
      .copyWith(
        displayLarge: _display(base.textTheme.displayLarge),
        displayMedium: _display(base.textTheme.displayMedium),
        displaySmall: _display(base.textTheme.displaySmall),
        headlineLarge: _display(base.textTheme.headlineLarge),
        headlineMedium: _display(base.textTheme.headlineMedium),
        headlineSmall: _display(base.textTheme.headlineSmall),
        titleLarge: _display(base.textTheme.titleLarge),
      );
  const displayButtonText = TextStyle(
    fontFamily: 'Lilita One',
    fontSize: 17,
    letterSpacing: .5,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: TapTussleColors.midnight,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: TapTussleColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: TapTussleColors.panel,
      shadowColor: Colors.black.withValues(alpha: .45),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    dividerColor: TapTussleColors.panelBorder,
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: TapTussleColors.electricBlue,
      inactiveTrackColor: TapTussleColors.panelBorder,
      thumbColor: TapTussleColors.gold,
      overlayColor: TapTussleColors.gold.withValues(alpha: .14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        backgroundColor: TapTussleColors.electricBlue,
        foregroundColor: TapTussleColors.midnight,
        textStyle: displayButtonText,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 54),
        foregroundColor: TapTussleColors.text,
        side: const BorderSide(color: TapTussleColors.electricBlue),
        textStyle: displayButtonText,
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TapTussleColors.electricBlue,
        textStyle: displayButtonText,
      ),
    ),
  );
}

TextStyle? _display(TextStyle? style) => style?.copyWith(
  fontFamily: 'Lilita One',
  fontWeight: FontWeight.w400,
  letterSpacing: .3,
  color: Colors.white,
);

/// Shared low-contrast arena lighting for menu and setup screens.
class TapTussleBackdrop extends StatelessWidget {
  const TapTussleBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1B3C),
              TapTussleColors.midnight,
              Color(0xFF040A1A),
            ],
          ),
        ),
      ),
      const RepaintBoundary(child: CustomPaint(painter: _ArenaEnergyPainter())),
      child,
    ],
  );
}

class ArcadePanel extends StatelessWidget {
  const ArcadePanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accent,
    this.borderRadius = 22,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent ?? TapTussleColors.panelBorder;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TapTussleColors.panel,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor.withValues(alpha: .78)),
        boxShadow: [
          const BoxShadow(
            color: Color(0x8A000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
          if (accent != null)
            BoxShadow(
              color: accent!.withValues(alpha: .13),
              blurRadius: 20,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _ArenaEnergyPainter extends CustomPainter {
  const _ArenaEnergyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    _glow(
      canvas,
      center: Offset(-size.width * .08, size.height * .18),
      radius: shortest * .72,
      color: TapTussleColors.rivalRed,
    );
    _glow(
      canvas,
      center: Offset(size.width * 1.05, size.height * .5),
      radius: shortest * .82,
      color: TapTussleColors.electricBlue,
    );

    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    final beams = <(Offset, Offset, Color)>[
      (
        Offset(-20, size.height * .34),
        Offset(size.width * .42, size.height * .1),
        TapTussleColors.rivalRed,
      ),
      (
        Offset(size.width * .58, size.height * .88),
        Offset(size.width + 24, size.height * .62),
        TapTussleColors.electricBlue,
      ),
      (
        Offset(size.width * .15, size.height + 10),
        Offset(size.width * .7, size.height * .72),
        TapTussleColors.gold,
      ),
    ];
    for (final beam in beams) {
      beamPaint.color = beam.$3.withValues(alpha: .12);
      canvas.drawLine(beam.$1, beam.$2, beamPaint);
    }

    final sparkPaint = Paint()..color = Colors.white.withValues(alpha: .14);
    const sparks = [
      (.12, .16, 2.0),
      (.82, .12, 1.5),
      (.92, .32, 2.3),
      (.08, .62, 1.4),
      (.72, .76, 1.8),
      (.32, .9, 1.2),
    ];
    for (final spark in sparks) {
      canvas.drawCircle(
        Offset(size.width * spark.$1, size.height * spark.$2),
        spark.$3,
        sparkPaint,
      );
    }
  }

  void _glow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: .19), Colors.transparent],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaEnergyPainter oldDelegate) => false;
}
