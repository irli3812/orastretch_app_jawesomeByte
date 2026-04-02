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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _metricColumn(
                          heading: 'Bite Force',
                          maxValue: '$maxBiteForce N',
                          avgValue: '${avgBiteForce.toStringAsFixed(1)} N',
                          isMobile: isMobile,
                        ),
                      ),
                      SizedBox(width: isMobile ? 20 : 28),
                      Expanded(
                        child: _metricColumn(
                          heading: 'Mouth Opening',
                          maxValue: '$maxMio mm',
                          avgValue: '${avgMio.toStringAsFixed(1)} mm',
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
                              Icon(Icons.delete, color: Colors.black, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Delete Session',
                                style: TextStyle(
                                  color: Colors.black,
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
                              Icon(Icons.save, color: Colors.black, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Save Session',
                                style: TextStyle(
                                  color: Colors.black,
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

  static Widget _metricColumn({
    required String heading,
    required String maxValue,
    required String avgValue,
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
        SizedBox(height: isMobile ? 12 : 14),
        Text(
          'Average',
          style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: isMobile ? 4 : 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            avgValue,
            style: TextStyle(fontSize: valueSize, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
