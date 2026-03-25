import 'package:flutter/material.dart';
import '../services/session_data_service.dart';


class EndSessionPopup extends StatelessWidget {
  EndSessionPopup({super.key});

  final SessionDataService _session = SessionDataService();

  void _deleteSession(BuildContext context) {
    _session.stop();
    _session.clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _session.rows;
    final bool hasData = rows.isNotEmpty;

    final int maxBiteForce = hasData
        ? rows.map((r) => r.biteForce).reduce((a, b) => a > b ? a : b).toInt()
        : 0;

    final double avgBiteForce = hasData
        ? rows.map((r) => r.biteForce).reduce((a, b) => a + b) / rows.length
        : 0;

    final int maxMouthOpening = hasData
        ? rows.map((r) => r.mouthOpening).reduce((a, b) => a > b ? a : b).toInt()
        : 0;

    final double avgMouthOpening = hasData
        ? rows.map((r) => r.mouthOpening).reduce((a, b) => a + b) / rows.length
        : 0;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Session Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return to Recording'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow(
                  'Max Bite Force',
                  '${maxBiteForce.toStringAsFixed(0)} lpf',
                ),
                _summaryRow(
                  'Avg Bite Force',
                  '${avgBiteForce.toStringAsFixed(1)} lpf',
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  'Max Mouth Opening',
                  '${maxMouthOpening.toStringAsFixed(0)} mm',
                ),
                _summaryRow(
                  'Avg Mouth Opening',
                  '${avgMouthOpening.toStringAsFixed(1)} mm',
                ),
                const SizedBox(height: 16),
                Text(
                  'Deleting session will permanently remove the recorded data.',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _deleteSession(context),
                    child: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete, color: scheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Delete Session',
                            style: TextStyle(
                              color: scheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  color: scheme.outline,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Save Session',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
