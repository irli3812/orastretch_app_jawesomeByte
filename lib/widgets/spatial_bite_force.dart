// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

class SpatialBiteForce extends StatelessWidget {
  const SpatialBiteForce({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('appBox');

    return Column(
      children: [
        const SizedBox(height: 12),

        const Text(
          'Colored Force-Map',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 20),

        ValueListenableBuilder(
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

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // ===== TOP ARCH (1–10) =====
                  _buildArch(values.sublist(0, 10), isTop: true),

                  // ===== BOTTOM ARCH (11–20) =====
                  _buildArch(values.sublist(10, 20), isTop: false),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // ===== COLOR LEGEND =====
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Container(
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.orange, Colors.green],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bfGaugeMin.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    ((bfGaugeMin + bfGaugeMax) / 2).toStringAsFixed(0),
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    '${bfGaugeMax.toStringAsFixed(0)} N',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  // ===== ARCH BUILDER =====
  Widget _buildArch(List<double> vals, {required bool isTop}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: List.generate(vals.length, (i) {
          // Create curvature by vertical offset
          final index = i;
          final mid = (vals.length - 1) / 2;
          final curve = (index - mid).abs();

          final verticalOffset = curve * 8; // (isTop ? 4 : 4); // multiplier increase makes curve more pronounced

          return Padding(
            padding: EdgeInsets.only(
              top: isTop ? verticalOffset : 0,
              bottom: isTop ? 0 : verticalOffset,
            ),
            child: _buildBox(i, vals[i], isTop),
          );
        }),
      ),
    );
  }

  // ===== SINGLE SENSOR BOX =====
  Widget _buildBox(int index, double value, bool isTop) {
    final sensorNumber = isTop ? index + 1 : index + 11;

    final color = _valueToColor(value);
    const textColor = Colors.white;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: Colors.grey.shade300, end: color),
      duration: const Duration(milliseconds: 300),
      builder: (context, animatedColor, _) {
        return Container(
          width: 65,
          height: 95,
          decoration: BoxDecoration(
            color: animatedColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SENSOR #
              Text(
                '$sensorNumber',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 4),

              // VALUE
              Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 2),

              // UNIT
              Text(
                'N',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.85),
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
