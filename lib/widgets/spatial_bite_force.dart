// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

/// RESPONSIVE SPATIAL BITE FORCE VISUALIZATION
///
/// RESPONSIVE UPDATES APPLIED:
/// - Container padding: Scales based on screen width
/// - Box sizing: Responsive constraints (min/max values)
/// - Font sizing: Scales proportionally with box width
///
/// PATTERN USED:
///   final screenWidth = MediaQuery.of(context).size.width;
///   final isMobile = screenWidth < 400;
///   final boxWidth = (availableWidth / vals.length).clamp(
///     isMobile ? 25.0 : 35.0,
///     isMobile ? 50.0 : 75.0,
///   );
///
/// For label legend text:
///   Text('Label', style: TextStyle(fontSize: isMobile ? 14 : 18))

class SpatialBiteForce extends StatelessWidget {
  const SpatialBiteForce({super.key});

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
                valueListenable: box.listenable(keys: ['session']),
                builder: (context, Box box, _) {
                  final List session = List.from(
                    box.get('session', defaultValue: []),
                  );

                  final List<double> values = List.generate(20, (i) {
                    if (session.isEmpty) return 0.0;

                    final row = session.last;
                    List bites = [];

                    if (row['bites'] != null) {
                      bites = List.from(row['bites']);
                    }

                    if (bites.length > i) {
                      return (bites[i] as num).toDouble();
                    }

                    return 0.0;
                  });

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildArch(values.sublist(0, 10), isTop: true),
                      const SizedBox(height: 6),
                      _buildLegend(context),
                      const SizedBox(height: 6),
                      _buildArch(values.sublist(10, 20), isTop: false),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Column(
      children: [
        Container(
          height: isMobile ? 16 : 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.orange, Colors.green],
            ),
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${bfGaugeMin.toStringAsFixed(0)} N',
              style: TextStyle(
                fontSize: isMobile ? 22 : 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${((bfGaugeMin + bfGaugeMax) / 2).toStringAsFixed(0)} N',
              style: TextStyle(
                fontSize: isMobile ? 22 : 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${bfGaugeMax.toStringAsFixed(0)} N',
              style: TextStyle(
                fontSize: isMobile ? 22 : 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== ARCH BUILDER (ELLIPTICAL TOUCHING BOXES - NO OVERLAP) =====
  Widget _buildArch(List<double> vals, {required bool isTop}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isVerySmall = screenWidth < 380;
        // Responsive sizing based on available width
        final availableWidth = constraints.maxWidth;
        final sideInset = isVerySmall
            ? 4.0
            : isMobile
            ? 8.0
            : 12.0;
        final spacing = isVerySmall
            ? 0.0
            : isMobile
            ? 0.25
            : 1.0;
        final fitWidth =
            (availableWidth - sideInset * 2 - spacing * (vals.length - 1)) /
            vals.length;
        final boxWidth = fitWidth.clamp(
          isVerySmall
              ? 18.0
              : isMobile
              ? 22.0
              : 32.0,
          isVerySmall
              ? 34.0
              : isMobile
              ? 38.0
              : 65.0,
        );
        final boxHeight = boxWidth * (isMobile ? 1.45 : 1.55);

        return LayoutBuilder(
          builder: (context, innerConstraints) {
            final totalWidth = vals.length * (boxWidth + spacing);

            // Calculate radius to fit boxes without hanging off edges
            // Account for half box width on each edge
            final maxHalfWidth = totalWidth / 2;
            final maxHalfHeight = innerConstraints.maxHeight / 2;

            // Calculate radius Y to create a smooth ellipse that contains all boxes
            // Use a more rounded curve (larger radius) by increasing the factor
            final radiusY =
                (boxHeight *
                        (isVerySmall
                            ? 0.50
                            : isMobile
                            ? 0.65
                            : 1.2))
                    .clamp(
                      isVerySmall
                          ? 26.0
                          : isMobile
                          ? 36.0
                          : 80.0,
                      maxHalfHeight *
                          (isVerySmall
                              ? 0.55
                              : isMobile
                              ? 0.68
                              : 0.9),
                    );

            final startX = max(
              sideInset,
              (innerConstraints.maxWidth - totalWidth) / 2,
            );

            return SizedBox(
              height: radiusY + boxHeight * (isMobile ? 0.78 : 1.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(vals.length, (i) {
                  final x = startX + i * (boxWidth + spacing);

                  final centerX = innerConstraints.maxWidth / 2;
                  final dx = (x + boxWidth / 2 - centerX) / (maxHalfWidth);

                  final ellipseY = sqrt(max(0, 1 - dx * dx)) * radiusY;

                  final y = isTop ? radiusY - ellipseY : ellipseY;

                  return Positioned(
                    left: x,
                    top: y,
                    child: _buildBox(i, vals[i], isTop, boxWidth, boxHeight),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }

  // ===== SINGLE SENSOR BOX =====
  Widget _buildBox(
    int index,
    double value,
    bool isTop,
    double boxWidth,
    double boxHeight,
  ) {
    final sensorNumber = isTop ? index + 1 : index + 11;

    final color = _valueToColor(value);
    const textColor = Colors.black;

    // Scale text sizes based on box dimensions
    final sensorFontSize = (boxWidth * 0.32).clamp(10.0, 24.0);
    final valueFontSize = (boxWidth * 0.40).clamp(13.0, 32.0);
    final unitFontSize = (boxWidth * 0.16).clamp(8.0, 14.0);

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: Colors.grey.shade300, end: color),
      duration: const Duration(milliseconds: 300),
      builder: (context, animatedColor, _) {
        return Container(
          width: boxWidth,
          height: boxHeight,
          decoration: BoxDecoration(
            color: animatedColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$sensorNumber',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: sensorFontSize,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 0.9,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value.toStringAsFixed(0),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 0.9,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
              const SizedBox(height: 0),
              Text(
                'N',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: unitFontSize,
                  color: textColor.withOpacity(0.85),
                  height: 0.9,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== COLOR SCALE =====
  Color _valueToColor(double value) {
    final normalized = ((value - bfGaugeMin) / (bfGaugeMax - bfGaugeMin)).clamp(
      0.0,
      1.0,
    );

    if (normalized < 0.5) {
      final t = normalized / 0.5;
      return Color.lerp(Colors.blue, Colors.orange, t)!;
    } else {
      final t = (normalized - 0.5) / 0.5;
      return Color.lerp(Colors.orange, Colors.green, t)!;
    }
  }
}
