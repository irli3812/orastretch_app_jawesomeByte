// ignore_for_file: unnecessary_underscores

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';
import '../widgets/ts_mouth_opening.dart';

enum ViewMode { meter, timeseries }

class RecordMouthOpening extends StatefulWidget {
  final bool isBluetoothConnected;

  const RecordMouthOpening({super.key, required this.isBluetoothConnected});

  @override
  State<RecordMouthOpening> createState() => _RecordMouthOpeningState();
}

class _RecordMouthOpeningState extends State<RecordMouthOpening> {
  ViewMode _viewMode = ViewMode.meter;

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
          // ===== Title + buttons =====
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _viewMode == ViewMode.meter
                        ? 'Latest Mouth Opening Distance (mm)'
                        : 'Current Mouth Opening Distance and Time',
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
                      'Select Mode',
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

          // ===== METER =====
          Expanded(
            flex: 3,
            child: _viewMode == ViewMode.meter
                ? ValueListenableBuilder(
                    valueListenable: box.listenable(
                      keys: [
                        'mouth_opening_current_series',
                        'mouth_opening_max_series',
                        'mouth_opening_avg_series',
                        'resetSignal',
                        'startSignal',
                      ],
                    ),
                    builder: (context, _, __) {
                      final List currentSeries = List.from(
                        box.get(
                          'mouth_opening_current_series',
                          defaultValue: [],
                        ),
                      );

                      final double value = currentSeries.isEmpty
                          ? 0
                          : (currentSeries.last as num).toDouble();

                      return SizedBox.expand(
                        child: CustomPaint(
                          painter: _SemiGaugePainter(value: value),
                        ),
                      );
                    },
                  )
                : const TsMouthOpening(),
          ),

          const SizedBox(height: 16),

          // ===== METRICS =====
          ValueListenableBuilder(
            valueListenable: box.listenable(
              keys: [
                'mouth_opening_current_series',
                'mouth_opening_avg_series',
                'mouth_opening_max_series',
                'mouth_opening_max_series',
                'resetSignal',
                'startSignal',
              ],
            ),
            builder: (context, _, __) {
              final List currentSeries = List.from(
                box.get('mouth_opening_current_series', defaultValue: []),
              );
              final List avgSeries = List.from(
                box.get('mouth_opening_avg_series', defaultValue: []),
              );
              final List maxSeries = List.from(
                box.get('mouth_opening_max_series', defaultValue: []),
              );

              final double value = currentSeries.isEmpty
                  ? 0
                  : (currentSeries.last as num).toDouble();

              final double avg = avgSeries.isEmpty
                  ? 0
                  : (avgSeries.last as num).toDouble();

              final double maxValue = maxSeries.isEmpty
                  ? 0
                  : (maxSeries.last as num).toDouble();

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Latest',
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
                            'Max',
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
                            'Average',
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
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$value',
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: metricValueSize),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$maxValue',
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: metricValueSize),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            avg.toStringAsFixed(1),
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
                    'millimeters',
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

/// ===== Semi-circle gauge painter =====
class _SemiGaugePainter extends CustomPainter {
  final double value;

  _SemiGaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    // Responsive sizing
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

    // ===== Tick marks & labels (every 5 mm) =====
    final tickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = isMobile ? 1.5 : 2;

    for (int step = 0; step <= minorDivisions; step++) {
      final double val =
          gaugeMin + (step / minorDivisions) * (gaugeMax - gaugeMin);

      final double t = (val - gaugeMin) / (gaugeMax - gaugeMin);
      final double angle = pi + t * pi;

      final bool major = step % majorDivisions == 0;

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
            text: val.round().toString(),
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
    final double clamped = value.clamp(gaugeMin, gaugeMax).toDouble();
    final double normalized = (clamped - gaugeMin) / (gaugeMax - gaugeMin);
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
  bool shouldRepaint(_SemiGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
