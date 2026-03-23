// ignore_for_file: unused_field, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BLEdata extends StatefulWidget {
  const BLEdata({super.key});

  @override
  State<BLEdata> createState() => _BLEdataState();
}

class _BLEdataState extends State<BLEdata> {
  final Box _box = Hive.box('appBox');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          /// ───────────────────────── LEFT TABLE ─────────────────────────
          /// Time + Mouth Opening
          Expanded(
            flex: 3,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Time (ms)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      Expanded(
                        child: Text(
                          'Mouth Opening',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _box.listenable(),
                    builder: (context, Box box, _) {
                      final List session = List.from(
                        box.get('session', defaultValue: []),
                      );

                      if (session.isEmpty) {
                        return const Center(child: Text("No session data"));
                      }

                      return ListView.builder(
                        itemCount: session.length,
                        itemBuilder: (_, index) {
                          final row = session[index];

                          final int time = (row['time_ms'] ?? 0) as int;
                          final double mouth = (row['mouth_opening'] ?? 0)
                              .toDouble();

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(time.toString())),
                                Expanded(child: Text(mouth.toStringAsFixed(2))),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          /// ───────────────────────── RIGHT TABLE ─────────────────────────
          /// Time + Avg Bite + Max Bite
          Expanded(
            flex: 4,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Time (ms)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      Expanded(
                        child: Text(
                          'B1 (N)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      Expanded(
                        child: Text(
                          'Avg Bite',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      Expanded(
                        child: Text(
                          'Max Bite',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _box.listenable(),
                    builder: (context, Box box, _) {
                      final List session = List.from(
                        box.get('session', defaultValue: []),
                      );

                      if (session.isEmpty) {
                        return const Center(child: Text("No session data"));
                      }

                      return ListView.builder(
                        itemCount: session.length,
                        itemBuilder: (_, index) {
                          final row = session[index];

                          final int time = (row['time_ms'] ?? 0) as int;

                          double b1 = 0;
                          if (row['bites'] != null) {
                            final List bites = List.from(row['bites']);
                            if (bites.isNotEmpty) {
                              b1 = (bites[0] as num).toDouble();
                            }
                          }

                          final double avg = (row['avg_bite_force'] ?? 0)
                              .toDouble();

                          final double max = (row['max_bite_force'] ?? 0)
                              .toDouble();

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(time.toString())),
                                Expanded(child: Text(b1.toStringAsFixed(2))),
                                Expanded(child: Text(avg.toStringAsFixed(2))),
                                Expanded(child: Text(max.toStringAsFixed(2))),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
