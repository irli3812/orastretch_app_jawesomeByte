// ignore_for_file: use_build_context_synchronously

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/save_session.dart';
import '../widgets/spatial_bite_force.dart';
import '../main.dart';

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

  List<double> _extractSensorMaxes(Map<dynamic, dynamic> map) {
    final values = List<double>.filled(20, 0.0);
    for (int i = 0; i < 20; i++) {
      final key = 'strain_gauge_${(i + 1).toString().padLeft(2, '0')}_max';
      final raw = map[key];
      values[i] = raw is num ? raw.toDouble() : 0.0;
    }
    return values;
  }

  Widget _sensorLegend({double textScale = 1.0}) {
    return Column(
      children: [
        Container(
          height: (12 * textScale).clamp(10.0, 18.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFCC79A7),
                Color(0xFFE69F00),
                Color(0xFF009E73),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${bfMin.toStringAsFixed(0)} N',
              style: TextStyle(fontSize: (14 * textScale).clamp(12.0, 20.0)),
            ),
            Text(
              '${((bfMin + bfMax) / 2).toStringAsFixed(0)} N',
              style: TextStyle(fontSize: (14 * textScale).clamp(12.0, 20.0)),
            ),
            Text(
              '${bfMax.toStringAsFixed(0)} N',
              style: TextStyle(fontSize: (14 * textScale).clamp(12.0, 20.0)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sensorRow(
    List<double> values,
    List<int> labels, {
    required bool isTop,
    double textScale = 1.0,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const int count = 10;
        final gap = (constraints.maxWidth * 0.006).clamp(1.0, 4.0);
        final toothWidth =
            (constraints.maxWidth - (gap * (count - 1))) / count;
        final toothHeight = toothWidth * 1.65;
        final curvePeak = toothHeight * 0.16;
        final rowHeight = toothHeight + curvePeak;
        final labelFont =
          (toothWidth * 0.30 * textScale).clamp(9.0, 14.0);
        final valueFont =
          (toothWidth * 0.45 * textScale).clamp(12.0, 20.0);

        return SizedBox(
          height: rowHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final v = values[i];
              final norm = ((i - 4.5).abs()) / 4.5;
              final curve = (1 - norm * norm) * curvePeak;
              final yOffset = isTop ? -curve : curve;

              return Padding(
                padding: EdgeInsets.only(right: i == count - 1 ? 0 : gap),
                child: Transform.translate(
                  offset: Offset(0, yOffset),
                  child: Container(
                    width: toothWidth,
                    height: toothHeight,
                    padding: EdgeInsets.symmetric(
                      vertical: toothHeight * 0.07,
                      horizontal: toothWidth * 0.06,
                    ),
                    decoration: BoxDecoration(
                      color: SpatialBiteForce.valueToColor(v),
                      borderRadius: BorderRadius.circular(toothWidth * 0.20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${labels[i]}',
                          style: TextStyle(
                            fontSize: labelFont,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: toothHeight * 0.02),
                        Text(
                          v.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: valueFont,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildStaticMeterCard({
    required String title,
    required double value,
    required double min,
    required double max,
    required int decimals,
    double textScale = 1.0,
    String? infoMessage,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: (17 * textScale).clamp(14.0, 22.0),
                  ),
                ),
                if (infoMessage != null) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 1,
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final button = context.findRenderObject() as RenderBox?;
                        final overlay = Overlay.of(context)
                            .context
                            .findRenderObject() as RenderBox?;
                        if (button == null || overlay == null) return;

                        final buttonTopLeft = button.localToGlobal(
                          Offset.zero,
                          ancestor: overlay,
                        );
                        final buttonRect = Rect.fromLTWH(
                          buttonTopLeft.dx,
                          buttonTopLeft.dy,
                          button.size.width,
                          button.size.height,
                        );

                        showMenu<void>(
                          context: context,
                          position: RelativeRect.fromRect(
                            buttonRect,
                            Offset.zero & overlay.size,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          color: Colors.white,
                          items: [
                            PopupMenuItem<void>(
                              enabled: false,
                              padding: const EdgeInsets.all(10),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 260),
                                child: Text(
                                  infoMessage,
                                  style: TextStyle(
                                    fontSize: (14 * textScale).clamp(12.0, 20.0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: const Icon(Icons.info_outline, size: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 1.8,
            child: CustomPaint(
              painter: _StaticSessionGaugePainter(
                value: value,
                min: min,
                max: max,
                decimals: decimals,
              ),
            ),
          ),
        ],
      ),
    );
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
    required double maxSmartAvgValue,
    required double maxMioValue,
    required List<double> sensorMaxes,
    required String? startTime,
    required String? endTime,
    required String? startTimePrecise,
    required String? endTimePrecise,
  }) {
    final dateStr = _formatDate(createdAt);
    final durationText = _durationFromTimes(startTimePrecise, endTimePrecise);
    final title = '$dateStr - Session $sessionNumber';
    final popupScale = (MediaQuery.of(context).size.width / 430)
      .clamp(0.90, 1.15)
        .toDouble();
    String editableName = name;
    bool isEditingName = false;
    final TextEditingController nameController = TextEditingController(
      text: name,
    );
    final FocusNode nameFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> commitNameEdit() async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                setDialogState(() {
                  nameController.text = editableName;
                  isEditingName = false;
                });
                return;
              }

              if (newName != editableName) {
                final historyBox = Hive.box(SaveSessionService.boxName);
                final dynamic existing = historyBox.get(sessionKey);
                if (existing is Map) {
                  final updated = Map<String, dynamic>.from(
                    existing.cast<dynamic, dynamic>(),
                  );
                  updated['name'] = newName;
                  await historyBox.put(sessionKey, updated);
                  editableName = newName;
                  if (mounted) setState(() {});
                }
              }

              setDialogState(() {
                isEditingName = false;
              });
            }

            return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: (22 * popupScale).clamp(18.0, 28.0),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 1,
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        if (isEditingName) {
                          await commitNameEdit();
                        } else {
                          setDialogState(() {
                            isEditingName = true;
                          });
                          Future.microtask(() {
                            if (nameFocusNode.canRequestFocus) {
                              nameFocusNode.requestFocus();
                              nameController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: nameController.text.length,
                              );
                            }
                          });
                        }
                      },
                      child: Icon(
                        isEditingName ? Icons.check : Icons.edit,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isEditingName ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isEditingName
                            ? Border.all(color: const Color(0xFFE5E7EB))
                            : null,
                      ),
                      child: isEditingName
                          ? TextField(
                              controller: nameController,
                              focusNode: nameFocusNode,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) async {
                                await commitNameEdit();
                              },
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : Text(
                              editableName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: (18 * popupScale).clamp(16.0, 26.0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Start: ${startTime ?? '--'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: (17 * popupScale).clamp(14.0, 22.0),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'End: ${endTime ?? '--'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: (17 * popupScale).clamp(14.0, 22.0),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Duration: $durationText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: (17 * popupScale).clamp(14.0, 22.0),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.90,
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 560;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Maximums Summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (17 * popupScale).clamp(14.0, 22.0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isNarrow)
                        Column(
                          children: [
                            _buildStaticMeterCard(
                              title: 'Max Bite Force (N)',
                              value: maxSmartAvgValue,
                              min: bfMin,
                              max: bfMax,
                              decimals: 1,
                              textScale: popupScale,
                              infoMessage:
                                  'Max of overall top 5 teeth averages for the session, or max of the upper quartile averages',
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, thickness: 1),
                            const SizedBox(height: 10),
                            _buildStaticMeterCard(
                              title: 'Max Mouth Opening (mm)',
                              value: maxMioValue,
                              min: mioMin,
                              max: mioMax,
                              decimals: 1,
                              textScale: popupScale,
                            ),
                          ],
                        )
                      else
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStaticMeterCard(
                                  title: 'Max Overall Bite Force (N)',
                                  value: maxSmartAvgValue,
                                  min: bfMin,
                                  max: bfMax,
                                  decimals: 1,
                                  textScale: popupScale,
                                  infoMessage:
                                      'Max of overall top 5 teeth averages for the session, or max of the upper quartile averages',
                                ),
                              ),
                              const SizedBox(width: 10),
                              const VerticalDivider(width: 1, thickness: 1),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStaticMeterCard(
                                  title: 'Max Mouth Opening (mm)',
                                  value: maxMioValue,
                                  min: mioMin,
                                  max: mioMax,
                                  decimals: 1,
                                  textScale: popupScale,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 12),
                      Text(
                        'Max Per Bite Force Sensor (N)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (17 * popupScale).clamp(14.0, 22.0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _sensorRow(
                        sensorMaxes.sublist(0, 10),
                        List<int>.generate(10, (i) => i + 4),
                        isTop: true,
                        textScale: popupScale,
                      ),
                      const SizedBox(height: 8),
                      _sensorLegend(textScale: popupScale),
                      const SizedBox(height: 8),
                      _sensorRow(
                        sensorMaxes.sublist(10, 20),
                        List<int>.generate(10, (i) => 29 - i),
                        isTop: false,
                        textScale: popupScale,
                      ),
                    ],
                  );
                },
              ),
            ),
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
              label: Text(
                'Delete',
                style: TextStyle(
                  fontSize: (16 * popupScale).clamp(14.0, 20.0),
                ),
              ),
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
              label: Text(
                'Close',
                style: TextStyle(fontSize: (16 * popupScale).clamp(14.0, 20.0)),
              ),
            ),
          ],
        );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      nameFocusNode.dispose();
    });
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
                    final maxSmartAvgValue =
                        (map['max_bite_force'] as num?)?.toDouble() ?? 0.0;
                    final maxMioValue =
                        (map['max_mouth_opening'] as num?)?.toDouble() ?? 0.0;
                    final sensorMaxes = _extractSensorMaxes(map);
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
                            maxSmartAvgValue: maxSmartAvgValue,
                            maxMioValue: maxMioValue,
                            sensorMaxes: sensorMaxes,
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

class _StaticSessionGaugePainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final int decimals;

  _StaticSessionGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.decimals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final radius = size.width * 0.43;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    arcPaint.shader = const SweepGradient(
      startAngle: pi,
      endAngle: 2 * pi,
      colors: [
        Color(0xFFCC79A7),
        Color(0xFFE69F00),
        Color(0xFF009E73),
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(arcRect);
    canvas.drawArc(arcRect, pi, pi, false, arcPaint);

    final clamped = value.clamp(min, max).toDouble();
    final normalized = (clamped - min) / (max - min);
    final angle = pi + normalized * pi;

    final tickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;
    final tickStart = Offset(
      center.dx + cos(angle) * radius * 0.90,
      center.dy + sin(angle) * radius * 0.90,
    );
    final tickEnd = Offset(
      center.dx + cos(angle) * radius * 1.05,
      center.dy + sin(angle) * radius * 1.05,
    );
    canvas.drawLine(tickStart, tickEnd, tickPaint);

    final needlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;
    final needleEnd = Offset(
      center.dx + cos(angle) * radius * 0.88,
      center.dy + sin(angle) * radius * 0.88,
    );
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 3.5, Paint()..color = Colors.black);

    final label = clamped.toStringAsFixed(decimals);
    final labelFontSize = (size.width * 0.09).clamp(12.0, 22.0);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: labelFontSize,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Place label inside dial space (not on the colored arc) and offset away
    // from the arm so it remains readable.
    const double arcStrokeWidth = 16.0;
    final innerRadius = radius - (arcStrokeWidth / 2) - 6.0;
    final dir = Offset(cos(angle), sin(angle));
    final normal = Offset(-dir.dy, dir.dx);
    final preferredCenter = Offset(
      center.dx + dir.dx * (innerRadius * 0.60) + normal.dx * 10.0,
      center.dy + dir.dy * (innerRadius * 0.60) + normal.dy * 10.0,
    );

    final topBound = center.dy - innerRadius + 2.0;
    final bottomBound = center.dy - tp.height - 2.0;
    final safeTop = topBound > bottomBound ? bottomBound : topBound;
    final safeBottom = topBound > bottomBound ? topBound : bottomBound;

    final labelX = (preferredCenter.dx - tp.width / 2)
        .clamp(2.0, size.width - tp.width - 2.0)
        .toDouble();
    final labelY = (preferredCenter.dy - tp.height / 2)
        .clamp(safeTop, safeBottom)
        .toDouble();
    final labelPos = Offset(labelX, labelY);
    tp.paint(canvas, labelPos);
  }

  @override
  bool shouldRepaint(covariant _StaticSessionGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.decimals != decimals;
  }
}
