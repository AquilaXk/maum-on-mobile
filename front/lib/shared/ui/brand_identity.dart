import 'package:flutter/material.dart';

abstract final class AppBrandColors {
  static const Color iconBlue = Color(0xFF18A9ED);
  static const Color primaryBlue = Color(0xFF4F8CF0);
  static const Color primaryBluePressed = Color(0xFF3F80EB);
  static const Color brandText = Color(0xFF5B7291);
  static const Color foreground = Color(0xFF25324A);
  static const Color mutedForeground = Color(0xFF7A8DA9);
  static const Color backgroundBlue = Color(0xFFEDF5FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceStrong = Color(0xFFFBFDFF);
  static const Color borderSoft = Color(0xFFDBE7FB);
}

class MaumOnBrandWordmark extends StatelessWidget {
  const MaumOnBrandWordmark({
    this.height = 40,
    this.foregroundColor = AppBrandColors.brandText,
    Key? key,
  }) : super(key: key ?? const ValueKey('maum-on-brand-wordmark'));

  final double height;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
          color: foregroundColor,
          fontSize: height * 0.72,
          height: 1,
          fontWeight: FontWeight.w800,
        );

    return Semantics(
      label: 'Maum On',
      header: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CustomPaint(
                size: Size.square(height * 0.86),
                painter: const _MaumOnWaveIconPainter(
                  backgroundColor: AppBrandColors.iconBlue,
                ),
              ),
              SizedBox(width: height * 0.22),
              Text('Maum On', style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaumOnWaveIconPainter extends CustomPainter {
  const _MaumOnWaveIconPainter({required this.backgroundColor});

  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.25);
    final backgroundPaint = Paint()..color = backgroundColor;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      backgroundPaint,
    );

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.07;

    for (final y in <double>[0.38, 0.50, 0.62]) {
      final path = Path()
        ..moveTo(size.width * 0.28, size.height * y)
        ..cubicTo(
          size.width * 0.36,
          size.height * (y - 0.08),
          size.width * 0.44,
          size.height * (y - 0.08),
          size.width * 0.52,
          size.height * y,
        )
        ..cubicTo(
          size.width * 0.60,
          size.height * (y + 0.08),
          size.width * 0.68,
          size.height * (y + 0.08),
          size.width * 0.76,
          size.height * y,
        );
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _MaumOnWaveIconPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor;
  }
}
