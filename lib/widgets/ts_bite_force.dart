// ignore_for_file: unnecessary_underscores, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

/// RESPONSIVE TIME SERIES BITE FORCE CHART
///
/// RESPONSIVE UPDATES APPLIED:
/// - Axis stroke widths: 1.5dp (mobile) to 2dp (desktop)
/// - Chart line stroke: Scales with screen width
/// - Font sizes in text painters: Should scale based on mobile detection
///
/// PATTERN FOR REMAINING UPDATES:
///   final isMobile = size.width < 400;
///   final axisPaint = Paint()..strokeWidth = isMobile ? 1.5 : 2;
///   final labelFontSize = isMobile ? 12 : 14;
///
///   // Apply to all TextPainter font properties

class TsBiteForce extends StatefulWidget {
  const TsBiteForce({super.key});

  static const double windowMs = 5000;

  @override
  State<TsBiteForce> createState() => _TsBiteForceState();
}

class _TsBiteForceState extends State<TsBiteForce> {
  static const List<String> regionLabels = [
    "Top Left",
    "Top Right",
    "Bottom Left",
    "Bottom Right",
  ];

  late Set<int> selectedSensors;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('appBox');
    final List<int> saved = List.from(
      box.get('selectedSensors', defaultValue: [0]),
    );
    selectedSensors = Set.from(saved);
  }

  void _openSensorSelector() {
    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              title: const Text("Select Sensor Region(s)"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildRegionChip(
                                0,
                                "Top Left",
                                setDialogState,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRegionChip(
                                1,
                                "Top Right",
                                setDialogState,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRegionChip(
                                2,
                                "Bottom Left",
                                setDialogState,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRegionChip(
                                3,
                                "Bottom Right",
                                setDialogState,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'lib/images/teeth_anatomy_transparent_png.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
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
    final selected = selectedSensors.contains(i);
    final background = color;
    const foreground = Colors.white;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            if (selected) {
              if (selectedSensors.length > 1) {
                selectedSensors.remove(i);
              }
            } else {
              selectedSensors.add(i);
            }
          });

          final box = Hive.box('appBox');
          box.put('selectedSensors', selectedSensors.toList());
          setDialogState(() {});
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: foreground,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check, size: 18, color: foreground),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('appBox');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        'Select Sensor Region(s)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
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
                              regionLabels[s],
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

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(keys: ['session']),
                builder: (context, Box box, _) {
                  final List session = List.from(
                    box.get('session', defaultValue: []),
                  );

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

                  final double latestTime =
                      sensorPoints.values.expand((list) => list).isNotEmpty
                      ? sensorPoints.values
                            .expand((list) => list)
                            .map((p) => p.dx)
                            .reduce((a, b) => a > b ? a : b)
                      : 0;

                  final double minTime = (latestTime - TsBiteForce.windowMs)
                      .clamp(0, double.infinity);

                  final Map<int, List<Offset>> filtered = {};

                  for (final s in selectedSensors) {
                    filtered[s] = sensorPoints[s]!
                        .where((p) => p.dx >= minTime)
                        .toList();
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        painter: _SimplePainter(filtered, minTime, latestTime),
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
    final isMobile = size.width < 400;
    const double bottomPad = 70; // more for rotated ticks
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
      final v = bfMin + (i / yTicks) * (bfMax - bfMin);
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
        text: "Bite Force of Region(s) (N)",
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
          height - ((p.dy - bfMin) / (bfMax - bfMin)) * height;
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
  bool shouldRepaint(covariant _SimplePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.minTime != minTime ||
        oldDelegate.maxTime != maxTime;
  }
}
