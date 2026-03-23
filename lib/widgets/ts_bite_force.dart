// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

class TsBiteForce extends StatefulWidget {
  const TsBiteForce({super.key});

  static const double windowMs = 5000;

  @override
  State<TsBiteForce> createState() => _TsBiteForceState();
}

class _TsBiteForceState extends State<TsBiteForce> {
  final Set<int> selectedSensors = {1};

  void _openSensorSelector() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Select Sensors"),
          content: Wrap(
            spacing: 8,
            children: List.generate(10, (i) {
              final s = i + 1;

              return FilterChip(
                label: Text("S$s"),
                selected: selectedSensors.contains(s),
                onSelected: (_) {
                  setState(() {
                    if (selectedSensors.contains(s)) {
                      selectedSensors.remove(s);
                    } else {
                      selectedSensors.add(s);
                    }
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('appBox');

    return Stack(
      children: [
        ValueListenableBuilder(
          valueListenable: box.listenable(keys: ['session']),
          builder: (context, Box box, _) {
            final List session = List.from(
              box.get('session', defaultValue: []),
            );

            if (session.isEmpty) {
              return const Center(child: Text("Waiting for data..."));
            }

            final Map<int, List<Offset>> sensorPoints = {
              for (int i = 1; i <= 10; i++) i: [],
            };

            // Build averaged data
            for (final row in session) {
              final int time = (row['time_ms'] ?? 0) as int;

              List bites = [];
              if (row['bites'] != null) {
                bites = List.from(row['bites']);
              }

              for (int s = 1; s <= 10; s++) {
                double v1 = 0;
                double v2 = 0;

                if (bites.length > (s - 1)) {
                  v1 = (bites[s - 1] as num).toDouble();
                }

                if (bites.length > (s + 9)) {
                  v2 = (bites[s + 9] as num).toDouble();
                }

                final avg = (v1 + v2) / 2.0;
                sensorPoints[s]!.add(Offset(time.toDouble(), avg));
              }
            }

            final double latestTime =
                sensorPoints[1]!.isNotEmpty ? sensorPoints[1]!.last.dx : 0;

            final double minTime =
                (latestTime - TsBiteForce.windowMs).clamp(0, double.infinity);

            final Map<int, List<Offset>> filtered = {};

            for (final s in selectedSensors) {
              filtered[s] = sensorPoints[s]!
                  .where((p) => p.dx >= minTime)
                  .toList();
            }

            return CustomPaint(
              painter: _SimplePainter(filtered, minTime, latestTime),
              size: Size.infinite,
            );
          },
        ),

        Positioned(
          top: 10,
          right: 10,
          child: ElevatedButton(
            onPressed: _openSensorSelector,
            child: const Text("Sensors"),
          ),
        ),
      ],
    );
  }
}

class _SimplePainter extends CustomPainter {
  final Map<int, List<Offset>> data;
  final double minTime;
  final double maxTime;

  _SimplePainter(this.data, this.minTime, this.maxTime);

  static const List<Color> colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.brown,
    Colors.indigo,
    Colors.pink,
    Colors.cyan,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width * 0.8;
    final double height = size.height;

    const double leftPad = 10;

    Offset scale(Offset p) {
      final x = leftPad + ((p.dx - minTime) / (maxTime - minTime)) * width;

      final y = height -
          ((p.dy - bfGaugeMin) / (bfGaugeMax - bfGaugeMin)) * height;

      return Offset(x, y);
    }

    int i = 0;

    // Draw lines
    for (final entry in data.entries) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final points = entry.value;
      if (points.length < 2) continue;

      final path = Path();
      final first = scale(points.first);
      path.moveTo(first.dx, first.dy);

      for (int j = 1; j < points.length; j++) {
        final p = scale(points[j]);
        path.lineTo(p.dx, p.dy);
      }

      canvas.drawPath(path, paint);
      i++;
    }

    // Legend
    double y = 20;
    i = 0;

    for (final s in data.keys) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = 3;

      canvas.drawLine(
        Offset(width + 20, y),
        Offset(width + 40, y),
        paint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: "S$s",
          style: const TextStyle(fontSize: 12, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(width + 45, y - 6));

      y += 20;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}