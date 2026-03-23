// DEFAULT METER MODE

// ignore_for_file: unnecessary_underscores

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';
import '../widgets/ts_bite_force.dart';
import '../widgets/spatial_bite_force.dart';

enum ViewMode { spatial, meter, timeseries }

class RecordBiteForce extends StatefulWidget {
  final bool isBluetoothConnected;

  const RecordBiteForce({super.key, required this.isBluetoothConnected});

  @override
  State<RecordBiteForce> createState() => _RecordBiteForceState();
}

class _RecordBiteForceState extends State<RecordBiteForce> {
  int? _lastResetSignal;
  int? _lastStartSignal;
  ViewMode _viewMode = ViewMode.spatial;

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('appBox');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Title + mode buttons =====
          Row(
            children: [
              const Text(
                'Record Bite Force',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),

              IconButton(
                icon: const Icon(Icons.view_week), // spatial teeth map
                color: _viewMode == ViewMode.spatial
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                onPressed: () => setState(() {
                  _viewMode = ViewMode.spatial;
                }),
              ),
              IconButton(
                icon: const Icon(Icons.speed),
                color: _viewMode == ViewMode.meter
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                onPressed: () => setState(() {
                  _viewMode = ViewMode.meter;
                }),
              ),
              IconButton(
                icon: const Icon(Icons.show_chart),
                color: _viewMode == ViewMode.timeseries
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                onPressed: () => setState(() {
                  _viewMode = ViewMode.timeseries;
                }),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ===== MAIN VIEW (fills middle space) =====
          Expanded(
            flex: 3,
            child: _viewMode == ViewMode.meter
                ? ValueListenableBuilder(
                    valueListenable: box.listenable(
                      keys: [
                        'session',
                        'startSignal',
                      ],
                    ),
                    builder: (context, _, __) {
                      final int? resetSignal = box.get('resetSignal');
                      final int? startSignal = box.get('startSignal');

                      if (resetSignal != null &&
                          resetSignal != _lastResetSignal) {
                        _lastResetSignal = resetSignal;
                      }

                      if (startSignal != null &&
                          startSignal != _lastStartSignal) {
                        _lastStartSignal = startSignal;
                      }

                      final List avgSeries = box.get(
                        'bite_force_avg_series',
                        defaultValue: [],
                      );

                      final avg = avgSeries.isEmpty
                          ? 0.0
                          : (avgSeries.last as num).toDouble();

                      return SizedBox.expand(
                        child: CustomPaint(
                          painter: _BiteForceGaugePainter(value: avg),
                        ),
                      );
                    },
                  )
                : _viewMode == ViewMode.spatial
                ? const SpatialBiteForce()
                : const TsBiteForce(),
          ),

          const SizedBox(height: 16),

          // ===== METRICS =====
          ValueListenableBuilder(
            // rebuild when the underlying series update or control signals change
            valueListenable: box.listenable(
              keys: [
                'session',
                'bite_force_avg_series',
                'bite_force_max_series',
                'resetSignal',
                'startSignal',
              ],
            ),
            builder: (context, _, __) {
              final int? resetSignal = box.get('resetSignal');
              final int? startSignal = box.get('startSignal');

              if (resetSignal != null && resetSignal != _lastResetSignal) {
                _lastResetSignal = resetSignal;
              }

              if (startSignal != null && startSignal != _lastStartSignal) {
                _lastStartSignal = startSignal;
              }
              // the average series holds the per‑sample averages coming from BLE
              final List avgSeries = box.get(
                'bite_force_avg_series',
                defaultValue: [],
              );

              // "latest" should reflect the most recent averaged value
              final double latest = avgSeries.isNotEmpty
                  ? (avgSeries.last as num).toDouble()
                  : 0.0;

              // compute an overall average of all entries in the avgSeries
              double avg = 0.0;
              if (avgSeries.isNotEmpty) {
                final sum = avgSeries.fold<double>(
                  0.0,
                  (p, e) => p + (e as num).toDouble(),
                );
                avg = sum / avgSeries.length;
              }

              final List maxSeries = box.get(
                'bite_force_max_series',
                defaultValue: [],
              );

              double max = 0;
              if (maxSeries.isNotEmpty) {
                max = (maxSeries.last as num).toDouble();
              }

              return Column(
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'Latest',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Max',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Average',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          latest.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          max.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          avg.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Newtons',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ===== Semi-circle gauge painter (0–150 N) =====
class _BiteForceGaugePainter extends CustomPainter {
  final double value;

  _BiteForceGaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = size.width * 0.45;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // ===== Colored arcs =====
    arcPaint.color = Colors.red;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi / 3,
      false,
      arcPaint,
    );

    arcPaint.color = Colors.yellow;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi / 3,
      pi / 3,
      false,
      arcPaint,
    );

    arcPaint.color = Colors.green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + 2 * pi / 3,
      pi / 3,
      false,
      arcPaint,
    );

    // ===== Tick marks & labels (every 10 N) =====
    final tickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    for (int step = 0; step <= bfMinorDivisions; step++) {
      final double valueTick =
          bfGaugeMin + (step / bfMinorDivisions) * (bfGaugeMax - bfGaugeMin);

      final double t = (valueTick - bfGaugeMin) / (bfGaugeMax - bfGaugeMin);
      final double angle = pi + t * pi;

      final bool major = step % bfMajorDivisions == 0;

      final double startR = radius * (major ? 0.75 : 0.82);
      final double endR = radius * 0.9;

      final Offset start = Offset(
        center.dx + cos(angle) * startR,
        center.dy + sin(angle) * startR,
      );

      final Offset end = Offset(
        center.dx + cos(angle) * endR,
        center.dy + sin(angle) * endR,
      );

      canvas.drawLine(start, end, tickPaint);

      if (major) {
        final tp = TextPainter(
          text: TextSpan(
            text: valueTick.round().toString(),
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final double labelRadius = radius * 0.95;
        final Offset pos = Offset(
          center.dx + cos(angle) * labelRadius - tp.width / 2,
          center.dy + sin(angle) * labelRadius - tp.height / 2,
        );

        tp.paint(canvas, pos);
      }
    }

    // ===== Needle =====
    final double clamped = (value.clamp(bfGaugeMin, bfGaugeMax)).toDouble();
    final double normalized =
        (clamped - bfGaugeMin) / (bfGaugeMax - bfGaugeMin);
    final double angle = pi + normalized * pi;

    final needlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3;

    final needleEnd = Offset(
      center.dx + cos(angle) * radius * 0.8,
      center.dy + sin(angle) * radius * 0.8,
    );

    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 6, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_BiteForceGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
