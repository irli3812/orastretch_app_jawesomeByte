// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/save_session.dart';
import '../services/session_data_service.dart';

class EndSessionPopup extends StatelessWidget {
  EndSessionPopup({super.key});

  final SessionDataService _session = SessionDataService();
  final SaveSessionService _saveSessionService = SaveSessionService();

  void _deleteSession(BuildContext context) {
    _session.stop();
    _session.clear();
    Navigator.of(context).pop();
  }

  Future<void> _saveSession(BuildContext context) async {
    final String defaultName = await _saveSessionService
        .defaultSessionNameWithSessionNumber();
    final TextEditingController controller = TextEditingController(
      text: defaultName,
    );

    final String? sessionName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save Session Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Session Name',
              hintText: 'mm_dd_yy_(#)',
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (sessionName == null) {
      return;
    }

    await _saveSessionService.saveSessionShell(name: sessionName);
    _session.stop();

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const deleteColor = Color(0xFFCC79A7);
    const saveColor = Color(0xFF0072B2);
    final rows = _session.rows;
    final bool hasData = rows.isNotEmpty;

    final int maxBiteForce = hasData
        ? rows.map((r) => r.biteForce).reduce((a, b) => a > b ? a : b).toInt()
        : 0;

    final double avgBiteForce = hasData
        ? rows.map((r) => r.biteForce).reduce((a, b) => a + b) / rows.length
        : 0;

    final int maxMio = hasData
        ? rows.map((r) => r.mio).reduce((a, b) => a > b ? a : b).toInt()
        : 0;

    final double avgMio = hasData
        ? rows.map((r) => r.mio).reduce((a, b) => a + b) / rows.length
        : 0;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
                  _summaryRow('Max bite', '$maxBiteForce N', 14, 16),
                  _summaryRow(
                    'Avg bite',
                    avgBiteForce.toStringAsFixed(1),
                    14,
                    16,
                  ),
                  _summaryRow('Max mouth', '$maxMio mm', 14, 16),
                  _summaryRow('Avg mouth', avgMio.toStringAsFixed(1), 14, 16),
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
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: deleteColor,
                      child: InkWell(
                        onTap: () => _deleteSession(context),
                        child: Container(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.delete, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Delete Session',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: Colors.white),
                  Expanded(
                    child: Material(
                      color: saveColor,
                      child: InkWell(
                        onTap: () => _saveSession(context),
                        child: Container(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.save, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Save Session',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _summaryRow(
    String label,
    String value,
    double labelSize,
    double valueSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: labelSize)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: valueSize),
          ),
        ],
      ),
    );
  }
}
