// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/session_data_service.dart';
import 'end_popup.dart';

class Footer extends StatefulWidget {
  final bool isActive;
  final VoidCallback onStartSession;

  const Footer({
    super.key,
    required this.isActive,
    required this.onStartSession,
  });

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  final SessionDataService _session = SessionDataService();

  Future<void> _startSession() async {
    await _session.start();
    widget.onStartSession();
  }

  void _confirmEndSession() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EndSessionPopup(),
    );
  }

  String _formatTime(int ms) {
    final minutes = (ms ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final milliseconds = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds:$milliseconds';
  }

  @override
  Widget build(BuildContext context) {
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
    final platformScale = isDesktop ? 1.0 : 0.94;
    double scale(double base) => base * screenScale * platformScale;
    final padding = isMobile ? 8.0 : 16.0;
    final fontSize = scale(18.0);
    final largeFontSize = scale(28.0);
    final buttonFontSize = scale(20.0);
    final buttonWidth = isMobile ? double.infinity : scale(300.0);
    final vertGap = scale(8.0);

    return ValueListenableBuilder(
      valueListenable: Hive.box('appBox').listenable(),
      builder: (_, __, ___) {
        final elapsed = _session.elapsedMs;
        final isRunning = _session.isRunning;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.blue)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Recording Time Elapsed",
                  style: TextStyle(fontSize: fontSize),
                ),
                Text(
                  _formatTime(elapsed),
                  style: TextStyle(
                    fontSize: largeFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: vertGap),
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton.icon(
                    onPressed: widget.isActive
                        ? (isRunning ? _confirmEndSession : _startSession)
                        : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(0, scale(56)),
                      padding: EdgeInsets.symmetric(
                        horizontal: scale(14),
                        vertical: scale(8),
                      ),
                    ),
                    icon: Icon(
                      isRunning ? Icons.stop : Icons.play_arrow,
                      size: scale(22),
                    ),
                    label: Text(
                      isRunning ? 'End Session' : 'Start Session',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
