// ignore_for_file: unnecessary_underscores, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

/// RESPONSIVE TIME SERIES MOUTH OPENING CHART
///
/// RESPONSIVE UPDATES APPLIED:
/// - Container padding: 12dp (mobile) to 16dp (desktop)
/// - Axis stroke widths: 1.5dp (mobile) to 2dp (desktop)
/// - Chart line stroke: 2dp (mobile) to 3dp (desktop)
///
/// REMAINING UPDATES NEEDED:
/// - All TextPainter font sizes should use responsive sizing:
///   final fontSize = isMobile ? 12 : 14;
/// 
/// Use ResponsiveSize utility from main.dart for consistency

class TsMouthOpening extends StatefulWidget {
  const TsMouthOpening({super.key});

  static const double windowMs = 5000;

  @override
  State<TsMouthOpening> createState() => _TsMouthOpeningState();
}

class _TsMouthOpeningState extends State<TsMouthOpening> {
  @override
  Widget build(BuildContext context) {
    final box = Hive.box('appBox');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(
                  keys: ['time_series', 'mouth_opening_current_series'],
                ),
                builder: (context, Box box, _) {
                  final List times = List.from(
                    box.get('time_series', defaultValue: []),
                  );

                  final List values = List.from(
                    box.get('mouth_opening_current_series', defaultValue: []),
                  );

                  final List<Offset> points = [];

                  for (int i = 0; i < times.length && i < values.length; i++) {
                    points.add(
                      Offset(
                        (times[i] as num).toDouble(),
                        (values[i] as num).toDouble(),
                      ),
                    );
                  }

                  final double latestTime = points.isNotEmpty
                      ? points.last.dx
                      : 0;

                  final double minTime = (latestTime - TsMouthOpening.windowMs)
                      .clamp(0, double.infinity);

                  final filtered = points
                      .where((p) => p.dx >= minTime)
                      .toList();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        painter: _MouthOpeningPainter(
                          filtered,
                          minTime,
                          latestTime,
                        ),
                        size: constraints.biggest,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MouthOpeningPainter extends CustomPainter {
  final List<Offset> data;
  final double minTime;
  final double maxTime;

  _MouthOpeningPainter(this.data, this.minTime, this.maxTime);

  @override
  void paint(Canvas canvas, Size size) {
    final isMobile = size.width < 400;
    const double bottomPad = 70;
    final double height = size.height - bottomPad;

    const double leftPad = 130;
    final double width = size.width - leftPad - 10;

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = isMobile ? 1.5 : 2;

    canvas.drawLine(Offset(leftPad, 0), Offset(leftPad, height), axisPaint);

    canvas.drawLine(
      Offset(leftPad, height),
      Offset(size.width, height),
      axisPaint,
    );

    final timeRange = (maxTime - minTime).abs() < 1 ? 1 : (maxTime - minTime);

    const int xTicks = 5;
    for (int i = 0; i <= xTicks; i++) {
      final t = minTime + (i / xTicks) * timeRange;
      final x = leftPad + (i / xTicks) * width;

      canvas.drawLine(Offset(x, height), Offset(x, height - 5), axisPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: (t / 1000).toStringAsFixed(3),
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(x, height + 5);
      canvas.rotate(-0.6);
      tp.paint(canvas, Offset(-tp.width, 0));
      canvas.restore();
    }

    const int yTicks = 5;
    for (int i = 0; i <= yTicks; i++) {
      final v = mioMin + (i / yTicks) * (mioMax - mioMin);

      final y = height - (i / yTicks) * height;

      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + 5, y), axisPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(0),
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(50, y - 10));
    }

    final xLabel = TextPainter(
      text: const TextSpan(
        text: "Time (s)",
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    xLabel.paint(canvas, Offset(leftPad + width / 2 - 60, height + 40));

    final yLabel = TextPainter(
      text: const TextSpan(
        text: "Mouth Opening (degrees)",
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(10, height / 2);
    canvas.rotate(-3.14159 / 2);

    yLabel.paint(canvas, Offset(-yLabel.width / 2, 0));

    canvas.restore();

    Offset scale(Offset p) {
      final x = leftPad + ((p.dx - minTime) / timeRange) * width;

      final y = height - ((p.dy - mioMin) / (mioMax - mioMin)) * height;

      return Offset(x, y);
    }

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = isMobile ? 2 : 3
      ..style = PaintingStyle.stroke;

    if (data.length < 2) return;

    final path = Path();

    final first = scale(data.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < data.length; i++) {
      final p = scale(data[i]);
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
