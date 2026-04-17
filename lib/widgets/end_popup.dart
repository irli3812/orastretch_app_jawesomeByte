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
    final isMobile = MediaQuery.of(context).size.width < 600;
    const deleteColor = Color(0xFFCC79A7);
    const saveColor = Color(0xFF0072B2);
    final rows = _session.rows;
    final bool hasData = rows.isNotEmpty;

    final int maxBiteForce = hasData
        ? rows.map((r) => r.biteForce).reduce((a, b) => a > b ? a : b).toInt()
        : 0;

    final int maxMio = hasData
        ? rows.map((r) => r.mio).reduce((a, b) => a > b ? a : b).toInt()
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
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Return to Recording',
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _metricColumn(
                          heading: 'Bite Force',
                          maxValue: '$maxBiteForce N',
                          isMobile: isMobile,
                        ),
                      ),
                      SizedBox(width: isMobile ? 20 : 28),
                      Expanded(
                        child: _metricColumn(
                          heading: 'Mouth Opening',
                          maxValue: '$maxMio mm',
                          isMobile: isMobile,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 18 : 22),
                  Text(
                    'Deleting session will permanently remove the recorded data.',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _deleteSession(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deleteColor,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                      elevation: 4,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _saveSession(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: saveColor,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                      elevation: 4,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  static Widget _metricColumn({
    required String heading,
    required String maxValue,
    required bool isMobile,
  }) {
    final headingSize = isMobile ? 22.0 : 28.0;
    final labelSize = isMobile ? 17.0 : 21.0;
    final valueSize = isMobile ? 34.0 : 46.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          heading,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: headingSize, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: isMobile ? 10 : 12),
        Text(
          'Maximum',
          style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: isMobile ? 4 : 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            maxValue,
            style: TextStyle(fontSize: valueSize, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
