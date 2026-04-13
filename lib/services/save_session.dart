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

    final List<dynamic> smartAvgRunningMaxSeries = List<dynamic>.from(
      appBox.get('bite_force_running_max_series', defaultValue: <dynamic>[]),
    );
    final dynamic latestSmartAvgMaxRaw = smartAvgRunningMaxSeries.isNotEmpty
      ? smartAvgRunningMaxSeries.last
      : null;
    final double? latestSmartAvgMax = latestSmartAvgMaxRaw is num
      ? latestSmartAvgMaxRaw.toDouble()
      : null;

    final List<dynamic> mioMaxSeries = List<dynamic>.from(
      appBox.get('mouth_opening_running_max_series', defaultValue: <dynamic>[]),
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
      'max_bite_force': latestSmartAvgMax,
      'max_mouth_opening': latestMioMax,
      'strain_gauge_01_max': sensorMaxes[0].isFinite &&
          sensorMaxes[0] != double.negativeInfinity
        ? sensorMaxes[0]
        : null,
      'strain_gauge_02_max': sensorMaxes[1].isFinite &&
          sensorMaxes[1] != double.negativeInfinity
        ? sensorMaxes[1]
        : null,
      'strain_gauge_03_max': sensorMaxes[2].isFinite &&
          sensorMaxes[2] != double.negativeInfinity
        ? sensorMaxes[2]
        : null,
      'strain_gauge_04_max': sensorMaxes[3].isFinite &&
          sensorMaxes[3] != double.negativeInfinity
        ? sensorMaxes[3]
        : null,
      'strain_gauge_05_max': sensorMaxes[4].isFinite &&
          sensorMaxes[4] != double.negativeInfinity
        ? sensorMaxes[4]
        : null,
      'strain_gauge_06_max': sensorMaxes[5].isFinite &&
          sensorMaxes[5] != double.negativeInfinity
        ? sensorMaxes[5]
        : null,
      'strain_gauge_07_max': sensorMaxes[6].isFinite &&
          sensorMaxes[6] != double.negativeInfinity
        ? sensorMaxes[6]
        : null,
      'strain_gauge_08_max': sensorMaxes[7].isFinite &&
          sensorMaxes[7] != double.negativeInfinity
        ? sensorMaxes[7]
        : null,
      'strain_gauge_09_max': sensorMaxes[8].isFinite &&
          sensorMaxes[8] != double.negativeInfinity
        ? sensorMaxes[8]
        : null,
      'strain_gauge_10_max': sensorMaxes[9].isFinite &&
          sensorMaxes[9] != double.negativeInfinity
        ? sensorMaxes[9]
        : null,
      'strain_gauge_11_max': sensorMaxes[10].isFinite &&
          sensorMaxes[10] != double.negativeInfinity
        ? sensorMaxes[10]
        : null,
      'strain_gauge_12_max': sensorMaxes[11].isFinite &&
          sensorMaxes[11] != double.negativeInfinity
        ? sensorMaxes[11]
        : null,
      'strain_gauge_13_max': sensorMaxes[12].isFinite &&
          sensorMaxes[12] != double.negativeInfinity
        ? sensorMaxes[12]
        : null,
      'strain_gauge_14_max': sensorMaxes[13].isFinite &&
          sensorMaxes[13] != double.negativeInfinity
        ? sensorMaxes[13]
        : null,
      'strain_gauge_15_max': sensorMaxes[14].isFinite &&
          sensorMaxes[14] != double.negativeInfinity
        ? sensorMaxes[14]
        : null,
      'strain_gauge_16_max': sensorMaxes[15].isFinite &&
          sensorMaxes[15] != double.negativeInfinity
        ? sensorMaxes[15]
        : null,
      'strain_gauge_17_max': sensorMaxes[16].isFinite &&
          sensorMaxes[16] != double.negativeInfinity
        ? sensorMaxes[16]
        : null,
      'strain_gauge_18_max': sensorMaxes[17].isFinite &&
          sensorMaxes[17] != double.negativeInfinity
        ? sensorMaxes[17]
        : null,
      'strain_gauge_19_max': sensorMaxes[18].isFinite &&
          sensorMaxes[18] != double.negativeInfinity
        ? sensorMaxes[18]
        : null,
      'strain_gauge_20_max': sensorMaxes[19].isFinite &&
          sensorMaxes[19] != double.negativeInfinity
        ? sensorMaxes[19]
        : null,
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
