// ignore_for_file: unnecessary_underscores, deprecated_member_use

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
  final Set<int> selectedSensors = {0};

  void _openSensorSelector() {
    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Select Sensor Pair(s)"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildRegionChip(0, "Top Left", setDialogState),
                            const SizedBox(width: 8),
                            _buildRegionChip(1, "Top Right", setDialogState),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildRegionChip(2, "Bottom Left", setDialogState),
                            const SizedBox(width: 8),
                            _buildRegionChip(3, "Bottom Right", setDialogState),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: Image.asset(
                          'lib/images/teeth_anatomy_transparent_png.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRegionChip(int i, String label, Function setDialogState) {
    final color = _SimplePainter.colors[i];

    return FilterChip(
      label: Text(label),
      selected: selectedSensors.contains(i),
      selectedColor: color.withOpacity(0.6),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        fontSize: 16,
        color: selectedSensors.contains(i) ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide(color: color, width: 2),
      onSelected: (_) {
        setState(() {
          if (selectedSensors.contains(i)) {
            selectedSensors.remove(i);
          } else {
            selectedSensors.add(i);
          }
        });
        setDialogState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('appBox');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _openSensorSelector,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'lib/images/teeth_anatomy_transparent_png.png',
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Select Sensor Pair(s)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),

        ValueListenableBuilder(
          valueListenable: box.listenable(keys: ['session']),
          builder: (context, Box box, _) {
            final Set<int> activeSensors = selectedSensors;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: activeSensors.map((s) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 3,
                          color: _SimplePainter.colors[s],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$s",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 12), // ✅ space between legend and plot

        Expanded(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(keys: ['session']),
            builder: (context, Box box, _) {
              final List session = List.from(
                box.get('session', defaultValue: []),
              );

              if (session.isEmpty) {
                return const Center(child: Text("Waiting for data..."));
              }

              final Map<int, List<Offset>> sensorPoints = {
                for (int i = 0; i < 4; i++) i: [],
              };

              for (final row in session) {
                final int time = (row['time_ms'] ?? 0) as int;

                List bites = [];
                if (row['bites'] != null) {
                  bites = List.from(row['bites']);
                }

                final groups = [
                  [0, 1, 2, 3], // 1-4
                  [4, 5, 6, 7], // 5-8
                  [12, 13, 14, 15], // 13-16
                  [16, 17, 18, 19], // 17-20
                ];

                for (int g = 0; g < 4; g++) {
                  double sum = 0;
                  int count = 0;

                  for (final idx in groups[g]) {
                    if (bites.length > idx) {
                      sum += (bites[idx] as num).toDouble();
                      count++;
                    }
                  }

                  final avg = count == 0 ? 0.0 : sum / count;
                  sensorPoints[g]!.add(Offset(time.toDouble(), avg));
                }
              }

              final double latestTime = sensorPoints[1]!.isNotEmpty
                  ? sensorPoints[1]!.last.dx
                  : 0;

              final double minTime = (latestTime - TsBiteForce.windowMs).clamp(
                0,
                double.infinity,
              );

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
    Color(0xFF0072B2),
    Color(0xFFD55E00),
    Color(0xFF009E73),
    Color(0xFFCC79A7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const double bottomPad = 70; // more for rotated ticks
    final double height = size.height - bottomPad;

    const double leftPad = 130;
    final double width = size.width - leftPad - 10;

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

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
      final v = bfGaugeMin + (i / yTicks) * (bfGaugeMax - bfGaugeMin);
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
        text: "Average bite force of aligned sensors (Newtons)",
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
    yLabel.paint(canvas, Offset(-yLabel.width / 2, 0)); // centered
    canvas.restore();

    Offset scale(Offset p) {
      final x = leftPad + ((p.dx - minTime) / timeRange) * width;
      final y =
          height - ((p.dy - bfGaugeMin) / (bfGaugeMax - bfGaugeMin)) * height;
      return Offset(x, y);
    }

    for (final entry in data.entries) {
      final s = entry.key;

      final paint = Paint()
        ..color = colors[s]
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
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
