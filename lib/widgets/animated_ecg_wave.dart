import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedEcgWave extends StatefulWidget {
  final double width;
  final double height;
  final Color color;
  const AnimatedEcgWave({
    super.key,
    this.width = 220,
    this.height = 45,
    this.color = const Color(0xFF00E5FF),
  });

  @override
  State<AnimatedEcgWave> createState() => _AnimatedEcgWaveState();
}

class _AnimatedEcgWaveState extends State<AnimatedEcgWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: EcgPainter(progress: _ctrl.value, color: widget.color),
        ),
      ),
    );
  }
}

class EcgPainter extends CustomPainter {
  final double progress;
  final Color color;
  EcgPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()
      ..color = color.withOpacity(0.20)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintGlow = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final mid = size.height / 2;
    path.moveTo(0, mid);
    path.lineTo(size.width * 0.28, mid);
    path.lineTo(size.width * 0.34, mid - 6);
    path.lineTo(size.width * 0.39, mid + 6);
    path.lineTo(size.width * 0.45, mid - (size.height * 0.48));
    path.lineTo(size.width * 0.51, mid + (size.height * 0.42));
    path.lineTo(size.width * 0.57, mid - 9);
    path.lineTo(size.width * 0.63, mid);
    path.lineTo(size.width, mid);

    canvas.drawPath(path, paintBase);
    final metric = path.computeMetrics().first;
    final len = metric.length * 0.38;
    final start = (metric.length * progress) - (len / 2);
    final extract = metric.extractPath(
      math.max(0, start),
      math.min(metric.length, start + len),
    );
    canvas.drawPath(extract, paintGlow);
  }

  @override
  bool shouldRepaint(covariant EcgPainter old) => old.progress != progress;
}
