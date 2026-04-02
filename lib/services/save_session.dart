import 'package:hive_flutter/hive_flutter.dart';

class SaveSessionService {
  static const String boxName = 'savedSessionsBox';
  static const String appBoxName = 'appBox';
  static const String sessionStartTimeKey = 'session_start_time';
  static const String sessionStartTimePreciseKey = 'session_start_time_precise';
  static const String biteSensorRunningMaxKey = 'bite_sensor_running_max';

  String defaultSessionName() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');
    return '${mm}_${dd}_$yy';
  }

  Future<String> defaultSessionNameWithSessionNumber() async {
    final now = DateTime.now();
    final String base = defaultSessionName();

    final box = Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);

    int sessionsToday = 0;
    for (final dynamic raw in box.values) {
      if (raw is! Map) continue;
      final createdMs = (raw['created_at_epoch_ms'] as num?)?.toInt();
      if (createdMs == null || createdMs <= 0) continue;

      final createdAt = DateTime.fromMillisecondsSinceEpoch(createdMs);
      final isSameDay =
          createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
      if (isSameDay) {
        sessionsToday++;
      }
    }

    final sessionNumber = sessionsToday + 1;
    return '${base}_($sessionNumber)';
  }

  Future<void> saveSessionShell({required String name}) async {
    final String trimmedName = name.trim().isEmpty
        ? await defaultSessionNameWithSessionNumber()
        : name.trim();
    final DateTime now = DateTime.now();
    final String endTime = _formatTimeOfDay(now);
    final String endTimePrecise = _formatTimeOfDayWithSeconds(now);

    final box = Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);

    final appBox = Hive.isBoxOpen(appBoxName)
        ? Hive.box(appBoxName)
        : await Hive.openBox(appBoxName);
    final dynamic savedStart = appBox.get(sessionStartTimeKey);
    final dynamic savedStartPrecise = appBox.get(sessionStartTimePreciseKey);
    final String? startTime = savedStart is String ? savedStart : null;
    final String? startTimePrecise = savedStartPrecise is String
        ? savedStartPrecise
        : null;

    final List<dynamic> runningMaxRaw = List<dynamic>.from(
      appBox.get(
        biteSensorRunningMaxKey,
        defaultValue: List<double>.filled(20, double.negativeInfinity),
      ),
    );
    final sensorMaxes = List<double>.filled(20, double.negativeInfinity);
    for (int i = 0; i < 20 && i < runningMaxRaw.length; i++) {
      final v = runningMaxRaw[i];
      if (v is num) {
        sensorMaxes[i] = v.toDouble();
      }
    }

    final validMaxes = sensorMaxes
        .where((v) => v.isFinite && v != double.negativeInfinity)
        .toList(growable: false);
    final double? avgOfSensorMaxes = validMaxes.length == 20
        ? validMaxes.reduce((a, b) => a + b) / 20.0
        : null;

    final List<dynamic> mioMaxSeries = List<dynamic>.from(
      appBox.get('mouth_opening_max_series', defaultValue: <dynamic>[]),
    );
    final dynamic latestMioMaxRaw = mioMaxSeries.isNotEmpty
        ? mioMaxSeries.last
        : null;
    final double? latestMioMax = latestMioMaxRaw is num
        ? latestMioMaxRaw.toDouble()
        : null;

    final Map<String, dynamic> row = {
      'name': trimmedName,
      'created_at_epoch_ms': now.millisecondsSinceEpoch,
      'start_time': startTime,
      'end_time': endTime,
      'start_time_precise': startTimePrecise,
      'end_time_precise': endTimePrecise,
      'max_bite_force': avgOfSensorMaxes,
      'max_mouth_opening': latestMioMax,
      'strain_gauge_01_max': null,
      'strain_gauge_02_max': null,
      'strain_gauge_03_max': null,
      'strain_gauge_04_max': null,
      'strain_gauge_05_max': null,
      'strain_gauge_06_max': null,
      'strain_gauge_07_max': null,
      'strain_gauge_08_max': null,
      'strain_gauge_09_max': null,
      'strain_gauge_10_max': null,
      'strain_gauge_11_max': null,
      'strain_gauge_12_max': null,
      'strain_gauge_13_max': null,
      'strain_gauge_14_max': null,
      'strain_gauge_15_max': null,
      'strain_gauge_16_max': null,
      'strain_gauge_17_max': null,
      'strain_gauge_18_max': null,
      'strain_gauge_19_max': null,
      'strain_gauge_20_max': null,
    };

    await box.add(row);
    await appBox.delete(biteSensorRunningMaxKey);
  }

  String _formatTimeOfDay(DateTime dt) {
    final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String minutes = dt.minute.toString().padLeft(2, '0');
    final String suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString()}:$minutes$suffix';
  }

  String _formatTimeOfDayWithSeconds(DateTime dt) {
    final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String minutes = dt.minute.toString().padLeft(2, '0');
    final String seconds = dt.second.toString().padLeft(2, '0');
    final String suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString()}:$minutes:$seconds$suffix';
  }
}
