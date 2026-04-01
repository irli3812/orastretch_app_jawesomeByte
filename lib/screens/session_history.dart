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
    return name.trim() == _defaultNameForDate(createdAt);
  }

  Map<dynamic, int> _sessionNumbersByKey(List<MapEntry<dynamic, dynamic>> entries) {
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
      final map = entry.value is Map ? entry.value as Map : <dynamic, dynamic>{};
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

  void _showSessionDetails(
    BuildContext context, {
    required String name,
    required DateTime createdAt,
    required int sessionNumber,
    required String? startTime,
    required String? endTime,
  }) {
    final dateStr = _formatDate(createdAt);
    final useDefaultTitle = _isDefaultSessionName(name, createdAt);
    final title = useDefaultTitle
        ? '$dateStr - Session $sessionNumber'
        : '$name - $dateStr - Session $sessionNumber';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Start: ${startTime ?? '--'}',
                      style: const TextStyle(
                        fontSize: 13,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: const Text('Session details view coming soon.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
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
    final nameSize = isMobile ? 14.0 : 16.0;
    final metricSize = isMobile ? 15.0 : 18.0;
    final buttonPadding = isMobile ? 10.0 : 14.0;
    final buttonHeight = isMobile ? 76.0 : 88.0;
    final actionButtonHeight = isMobile ? 34.0 : 38.0;
    final actionButtonFont = isMobile ? 12.0 : 13.0;
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
                  icon: Icon(_selectionMode ? Icons.close : Icons.checklist, size: 16),
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
                        fontSize: isMobile ? 14 : 16,
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
                  final aMs = (aMap['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
                  final bMs = (bMap['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
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

                    final name = (map['name'] as String?)?.trim().isNotEmpty == true
                        ? map['name'] as String
                        : 'Unnamed Session';

                    final createdMs = (map['created_at_epoch_ms'] as num?)?.toInt() ?? 0;
                    final createdAt = createdMs > 0
                        ? DateTime.fromMillisecondsSinceEpoch(createdMs)
                        : DateTime.now();
                    final sessionNumber = sessionNumsByKey[entries[index].key] ?? 1;

                    final maxBite = _metricValue(map['max_bite_force'], 'N');
                    final maxMouth = _metricValue(map['max_mouth_opening'], 'mm');
                    final startTime = map['start_time'] as String?;
                    final endTime = map['end_time'] as String?;
                    final displayName = '${name}_($sessionNumber)';

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
                            name: name,
                            createdAt: createdAt,
                            sessionNumber: sessionNumber,
                            startTime: startTime,
                            endTime: endTime,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: buttonPadding,
                            vertical: buttonPadding * 0.8,
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
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  maxBite,
                                  style: TextStyle(
                                    fontSize: metricSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: isMobile ? 2 : 4),
                                Text(
                                  maxMouth,
                                  style: TextStyle(
                                    fontSize: metricSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectionMode) ...[
                              const SizedBox(width: 8),
                              Checkbox(
                                value: _selectedKeys.contains(entries[index].key),
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
