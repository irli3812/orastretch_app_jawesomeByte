// DEFAULT METER MODE
// ignore_for_file: unnecessary_underscores

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/spatial_bite_force.dart';
import '../main.dart';
import '../widgets/ts_bite_force.dart';

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
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final shortestSide = media.size.shortestSide;
    final platform = Theme.of(context).platform;
    final isDesktop =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final isMobile = screenWidth < 600;
    final screenScale = (shortestSide / 400).clamp(0.85, 1.15);
    final platformScale = isDesktop ? 1.0 : 0.92;
    double scale(double base) => base * screenScale * platformScale;
    final metricLabelSize = scale(20);
    final metricValueSize = scale(28);
    final metricUnitSize = scale(18);
    final metricGap = scale(8);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Title + mode buttons =====
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _viewMode == ViewMode.meter
                        ? 'Current Avg of Top 5 Teeth (N)'
                        : _viewMode == ViewMode.spatial
                        ? 'Colored Teeth Force Map'
                        : 'Avg Bite Force per Region',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Select View',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
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
                          onPressed: () =>
                              setState(() => _viewMode = ViewMode.meter),
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
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ===== MAIN VIEW =====
          Expanded(
            flex: 3,
            child: _viewMode == ViewMode.meter
                ? ValueListenableBuilder(
                    valueListenable: box.listenable(
                      keys: [
                        'session',
                        'startSignal',
                        'bite_force_avg_series',
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

                      final List smartAvgSeries = box.get(
                        'bite_force_avg_series',
                        defaultValue: [],
                      );

                      final latest = smartAvgSeries.isEmpty
                          ? 0.0
                          : (smartAvgSeries.last as num).toDouble();

                      return SizedBox.expand(
                        child: CustomPaint(
                          painter: _BiteForceGaugePainter(value: latest),
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
            valueListenable: box.listenable(
              keys: [
                'session',
                'bite_force_avg_series',
                'bite_force_running_max_series',
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

              final List smartAvgSeries = box.get(
                'bite_force_avg_series',
                defaultValue: [],
              );
              final List runningMaxSeries = box.get(
                'bite_force_running_max_series',
                defaultValue: [],
              );

              final double latest = smartAvgSeries.isNotEmpty
                  ? (smartAvgSeries.last as num).toDouble()
                  : 0.0;
              final double maxValue = runningMaxSeries.isNotEmpty
                  ? (runningMaxSeries.last as num).toDouble()
                  : 0.0;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Current Avg of Top 5 Teeth',
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: metricLabelSize,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Overall Max So Far',
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: metricLabelSize,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: metricGap),
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: SpatialBiteForce.valueToColor(latest),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  latest.toStringAsFixed(1),
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: metricValueSize,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            maxValue.toStringAsFixed(1),
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: metricValueSize),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: metricGap),
                  Text(
                    'Newtons (N)',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: metricUnitSize,
                      fontStyle: FontStyle.italic,
                    ),
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
      ..strokeWidth = isMobile ? 30 : 42
      ..strokeCap = StrokeCap.butt;

    // ===== Smooth ombre arc =====
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    arcPaint.shader = const SweepGradient(
      startAngle: pi,
      endAngle: 2 * pi,
      colors: [
        Color(0xFFCC79A7), // pink (low)
        Color(0xFFE69F00), // orange (medium)
        Color(0xFF009E73), // green (high)
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(arcRect);
    canvas.drawArc(
      arcRect,
      pi,
      pi,
      false,
      arcPaint,
    );

    // ===== Tick marks (every 10 N) =====
    final tickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = isMobile ? 1.5 : 2;

    for (int step = 0; step <= bfMinorDivs; step++) {
      final double valueTick =
          bfMin + (step / bfMinorDivs) * (bfMax - bfMin);

      final double t = (valueTick - bfMin) / (bfMax - bfMin);
      final double angle = pi + t * pi;

      final bool major = step % bfMajorDivs == 0;

      // Draw ticks across the arc band so they sit on top of the meter colors.
      final double startR = radius * (major ? 0.88 : 0.92);
      final double endR = radius * (major ? 1.03 : 1.0);

      final Offset start = Offset(
        center.dx + cos(angle) * startR,
        center.dy + sin(angle) * startR,
      );

      final Offset end = Offset(
        center.dx + cos(angle) * endR,
        center.dy + sin(angle) * endR,
      );

      canvas.drawLine(start, end, tickPaint);
    }

    // ===== Needle =====
    final double clamped = (value.clamp(bfMin, bfMax)).toDouble();
    final double normalized =
        (clamped - bfMin) / (bfMax - bfMin);
    final double angle = pi + normalized * pi;

    final needlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = isMobile ? 2 : 3;

    final needleEnd = Offset(
      center.dx + cos(angle) * radius * 0.62,
      center.dy + sin(angle) * radius * 0.62,
    );

    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, isMobile ? 4 : 6, Paint()..color = Colors.black);

    // ===== Numeric labels right under tick marks =====
    for (int step = 0; step <= bfMinorDivs; step += bfMajorDivs) {
      final double valueTick =
          bfMin + (step / bfMinorDivs) * (bfMax - bfMin);
      final double t = step / bfMinorDivs;
      final double labelAngle = pi + t * pi;
      final tp = TextPainter(
        text: TextSpan(
          text: valueTick.round().toString(),
          style: TextStyle(
            fontSize: isMobile ? 16 : 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final double labelRadius = radius * 0.72;
      final Offset pos = Offset(
        center.dx + cos(labelAngle) * labelRadius - tp.width / 2,
        center.dy + sin(labelAngle) * labelRadius - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(_BiteForceGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
