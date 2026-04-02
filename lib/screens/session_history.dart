// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/save_session.dart';

class SessionHistory extends StatefulWidget {
  const SessionHistory({super.key});

  @override
  State<SessionHistory> createState() => _SessionHistoryState();
}

class _SessionHistoryState extends State<SessionHistory> {
  bool _selectionMode = false;
  final Set<dynamic> _selectedKeys = <dynamic>{};

  String _formatDate(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    return '$mm/$dd/$yy';
  }

  String _defaultNameForDate(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    return '${mm}_${dd}_$yy';
  }

  bool _isDefaultSessionName(String name, DateTime createdAt) {
    final trimmed = name.trim();
    final base = _defaultNameForDate(createdAt);
    if (trimmed == base) return true;
    return RegExp('^${RegExp.escape(base)}_\\(\\d+\\)\$').hasMatch(trimmed);
  }

  Map<dynamic, int> _sessionNumbersByKey(
    List<MapEntry<dynamic, dynamic>> entries,
  ) {
    final sortedAsc = List<MapEntry<dynamic, dynamic>>.from(entries)
      ..sort((a, b) {
        final aMap = a.value is Map ? a.value as Map : <dynamic, dynamic>{};
        final bMap = b.value is Map ? b.value as Map : <dynamic, dynamic>{};
        final aMs = (aMap['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
        final bMs = (bMap['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
        if (aMs == bMs) {
          return (a.key as int).compareTo(b.key as int);
        }
        return aMs.compareTo(bMs);
      });

    final Map<String, int> perDayCounter = {};
    final Map<dynamic, int> result = {};

    for (final entry in sortedAsc) {
      final map = entry.value is Map
          ? entry.value as Map
          : <dynamic, dynamic>{};
      final createdMs = (map['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
      final createdAt = createdMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdMs)
          : DateTime.now();
      final dayKey = '${createdAt.year}-${createdAt.month}-${createdAt.day}';
      final count = (perDayCounter[dayKey] ?? 0) + 1;
      perDayCounter[dayKey] = count;
      result[entry.key] = count;
    }

    return result;
  }

  String _metricValue(dynamic raw, String unit) {
    if (raw == null) return '--';
    if (raw is num) {
      if (unit == 'N') {
        return '${raw.toStringAsFixed(0)}$unit';
      }
      return '${raw.toStringAsFixed(1)}$unit';
    }
    return '--';
  }

  String _formatBiteForceForDetails(dynamic raw) {
    if (raw == null) return '--';
    if (raw is! num) return '--';

    final formatted = raw
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '${formatted}N';
  }

  int? _secondsSinceMidnight(String? value) {
    if (value == null) return null;

    final raw = value.trim().toUpperCase();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?(AM|PM)$',
    ).firstMatch(raw);
    if (match == null) return null;

    final hourRaw = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final second = int.tryParse(match.group(3) ?? '0');
    final meridiem = match.group(4)!;

    if (hourRaw == null || minute == null || second == null) return null;
    if (hourRaw < 1 || hourRaw > 12 || minute < 0 || minute > 59) return null;
    if (second < 0 || second > 59) return null;

    var hour24 = hourRaw % 12;
    if (meridiem == 'PM') {
      hour24 += 12;
    }

    return (hour24 * 3600) + (minute * 60) + second;
  }

  String _durationFromTimes(String? startTimePrecise, String? endTimePrecise) {
    final startSeconds = _secondsSinceMidnight(startTimePrecise);
    final endSeconds = _secondsSinceMidnight(endTimePrecise);
    if (startSeconds == null || endSeconds == null) return '--:--';

    var deltaSeconds = endSeconds - startSeconds;
    if (deltaSeconds < 0) {
      deltaSeconds += 24 * 3600;
    }

    final minutes = (deltaSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (deltaSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSessionDetails(
    BuildContext context, {
    required dynamic sessionKey,
    required String name,
    required DateTime createdAt,
    required int sessionNumber,
    required String maxBiteForDetails,
    required String? startTime,
    required String? endTime,
    required String? startTimePrecise,
    required String? endTimePrecise,
  }) {
    final dateStr = _formatDate(createdAt);
    final useDefaultTitle = _isDefaultSessionName(name, createdAt);
    final durationText = _durationFromTimes(startTimePrecise, endTimePrecise);
    final title = '$dateStr - Session $sessionNumber';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!useDefaultTitle) ...[
                const SizedBox(height: 8),
                Text(
                  'Custom name: $name',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Start: ${startTime ?? '--'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'End: ${endTime ?? '--'}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Duration: $durationText',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Max bite force: $maxBiteForDetails',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          content: const Text(
            'Session details view coming soon.',
            style: TextStyle(fontSize: 18),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                final box = Hive.box(SaveSessionService.boxName);
                await box.delete(sessionKey);

                if (!mounted) return;
                setState(() {
                  _selectedKeys.remove(sessionKey);
                });

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session deleted')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.delete_outline, size: 22),
              label: const Text('Delete', style: TextStyle(fontSize: 18)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.close, size: 22),
              label: const Text('Close', style: TextStyle(fontSize: 18)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty) return;

    final box = Hive.box(SaveSessionService.boxName);
    for (final key in _selectedKeys) {
      await box.delete(key);
    }

    if (!mounted) return;
    setState(() {
      _selectedKeys.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 12.0 : 16.0;
    final nameSize = isMobile ? 18.0 : 24.0;
    final metricSize = isMobile ? 18.0 : 24.0;
    final buttonPadding = isMobile ? 10.0 : 14.0;
    final buttonHeight = isMobile ? 78.0 : 92.0;
    final actionButtonHeight = isMobile ? 46.0 : 54.0;
    final actionButtonFont = isMobile ? 16.0 : 20.0;
    final box = Hive.box(SaveSessionService.boxName);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_selectionMode)
                SizedBox(
                  height: actionButtonHeight,
                  child: ElevatedButton.icon(
                    onPressed: _selectedKeys.isEmpty ? null : _deleteSelected,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(
                      'Delete',
                      style: TextStyle(fontSize: actionButtonFont),
                    ),
                  ),
                ),
              if (_selectionMode) const SizedBox(width: 8),
              SizedBox(
                height: actionButtonHeight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectionMode = !_selectionMode;
                      if (!_selectionMode) {
                        _selectedKeys.clear();
                      }
                    });
                  },
                  icon: Icon(
                    _selectionMode ? Icons.close : Icons.checklist,
                    size: 16,
                  ),
                  label: Text(
                    _selectionMode ? 'Done' : 'Select',
                    style: TextStyle(fontSize: actionButtonFont),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 10),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<dynamic> historyBox, _) {
                final entries = historyBox.toMap().entries.toList();

                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'No sessions recorded yet',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 26,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                final sessionNumsByKey = _sessionNumbersByKey(entries);

                entries.sort((a, b) {
                  final dynamic aRaw = a.value;
                  final dynamic bRaw = b.value;
                  final aMap = aRaw is Map ? aRaw : <dynamic, dynamic>{};
                  final bMap = bRaw is Map ? bRaw : <dynamic, dynamic>{};
                  final aMs =
                      (aMap['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
                  final bMs =
                      (bMap['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
                  if (aMs == bMs) {
                    return (b.key as int).compareTo(a.key as int);
                  }
                  return bMs.compareTo(aMs);
                });

                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, separatorIndex) =>
                      SizedBox(height: isMobile ? 8 : 10),
                  itemBuilder: (context, index) {
                    final dynamic raw = entries[index].value;
                    final map = raw is Map ? raw : <dynamic, dynamic>{};

                    final name =
                        (map['name'] as String?)?.trim().isNotEmpty == true
                        ? map['name'] as String
                        : 'Unnamed Session';

                    final createdMs =
                        (map['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
                    final createdAt = createdMs > 0
                        ? DateTime.fromMillisecondsSinceEpoch(createdMs)
                        : DateTime.now();
                    final sessionNumber =
                        sessionNumsByKey[entries[index].key] ?? 1;

                    final maxBite = _metricValue(map['max_bite_force'], 'N');
                    final maxBiteForDetails = _formatBiteForceForDetails(
                      map['max_bite_force'],
                    );
                    final maxMio = _metricValue(map['max_mouth_opening'], 'mm');
                    final startTime = map['start_time'] as String?;
                    final endTime = map['end_time'] as String?;
                    final startTimePrecise =
                        map['start_time_precise'] as String?;
                    final endTimePrecise = map['end_time_precise'] as String?;
                    final displayName = name;
                    final metricText = '$maxBite/$maxMio';

                    return SizedBox(
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_selectionMode) {
                            setState(() {
                              final key = entries[index].key;
                              if (_selectedKeys.contains(key)) {
                                _selectedKeys.remove(key);
                              } else {
                                _selectedKeys.add(key);
                              }
                            });
                            return;
                          }

                          _showSessionDetails(
                            context,
                            sessionKey: entries[index].key,
                            name: name,
                            createdAt: createdAt,
                            sessionNumber: sessionNumber,
                            maxBiteForDetails: maxBiteForDetails,
                            startTime: startTime,
                            endTime: endTime,
                            startTimePrecise: startTimePrecise,
                            endTimePrecise: endTimePrecise,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: buttonPadding,
                            vertical: buttonPadding * 0.45,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: nameSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              metricText,
                              style: TextStyle(
                                fontSize: metricSize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_selectionMode) ...[
                              const SizedBox(width: 8),
                              Checkbox(
                                value: _selectedKeys.contains(
                                  entries[index].key,
                                ),
                                onChanged: (_) {
                                  setState(() {
                                    final key = entries[index].key;
                                    if (_selectedKeys.contains(key)) {
                                      _selectedKeys.remove(key);
                                    } else {
                                      _selectedKeys.add(key);
                                    }
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
