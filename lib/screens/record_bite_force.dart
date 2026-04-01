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

  Widget _modeButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          height: 40,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              foregroundColor: selected ? scheme.primary : Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Icon(icon, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? scheme.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('appBox');
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Title + mode buttons =====
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Mode',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      _modeButton(
                        context: context,
                        icon: Icons.view_week,
                        label: 'Map',
                        selected: _viewMode == ViewMode.spatial,
                        onPressed: () =>
                            setState(() => _viewMode = ViewMode.spatial),
                      ),
                      _modeButton(
                        context: context,
                        icon: Icons.speed,
                        label: 'Meter',
                        selected: _viewMode == ViewMode.meter,
                        onPressed: () => setState(() => _viewMode = ViewMode.meter),
                      ),
                      _modeButton(
                        context: context,
                        icon: Icons.show_chart,
                        label: 'Graph',
                        selected: _viewMode == ViewMode.timeseries,
                        onPressed: () =>
                            setState(() => _viewMode = ViewMode.timeseries),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 3),

          Center(
            child: _viewMode == ViewMode.meter
                ? const Text(
                    'Latest Bite Force (N)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  )
                : _viewMode == ViewMode.spatial
                    ? const Text(
                        'Colored Teeth Force Map',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      )
                    : const Text(
                        'Current Bite Force and Time',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
          ),

          const SizedBox(height: 3),

          // ===== MAIN VIEW (fills middle space) =====
          Expanded(
            flex: 3,
            child: _viewMode == ViewMode.meter
                ? ValueListenableBuilder(
                    valueListenable: box.listenable(
                      keys: ['session', 'startSignal'],
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
                    'Newtons (N)',
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
    final isMobile = size.width < 400;
    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = size.width * (isMobile ? 0.38 : 0.45);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMobile ? 10 : 14
      ..strokeCap = StrokeCap.round;

    // ===== Colored arcs =====
    arcPaint.color = Color(0xFF009E73); // teal (low)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi / 3,
      false,
      arcPaint,
    );

    arcPaint.color = Color(0xFFE69F00); // orange (medium)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi / 3,
      pi / 3,
      false,
      arcPaint,
    );

    arcPaint.color = Color(0xFFCC79A7); // purple (high)
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
      ..strokeWidth = isMobile ? 1.5 : 2;

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
      ..strokeWidth = isMobile ? 2 : 3;

    final needleEnd = Offset(
      center.dx + cos(angle) * radius * 0.8,
      center.dy + sin(angle) * radius * 0.8,
    );

    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, isMobile ? 4 : 6, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_BiteForceGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
