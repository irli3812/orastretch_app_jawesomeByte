// ignore_for_file: constant_identifier_names, non_constant_identifier_names, unused_field

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive/hive.dart';

/// ─────────────────────────────────────────────
/// Data row (3 columns only)
/// ─────────────────────────────────────────────
class SessionRow {
  final int elapsedMs;
  final int biteForce;
  final int mouthOpening;

  SessionRow({
    required this.elapsedMs,
    required this.biteForce,
    required this.mouthOpening,
  });
}

/// ─────────────────────────────────────────────
/// Session data service (singleton)
/// ─────────────────────────────────────────────
class SessionDataService extends ChangeNotifier {

// Hive keys
static const _timeKey = 'time_series';

static const _IOcurrentSeriesKey = 'mouth_opening_current_series';
static const _IOavgSeriesKey = 'mouth_opening_avg_series';
static const _IOmaxSeriesKey = 'mouth_opening_max_series';

static const _biteCurrentSeriesKey = 'bite_forces_current_series';
static const _biteAvgSeriesKey = 'bite_force_avg_series';
static const _biteMaxSeriesKey = 'bite_force_max_series';

static const _batteryKey = 'batteryPercent';
static const _sessionStartTimeKey = 'session_start_time';

  // Singleton
  static final SessionDataService _instance =
      SessionDataService._internal();
  factory SessionDataService() => _instance;
  SessionDataService._internal();

  final Box _box = Hive.box('appBox');

  /// BLE
  BluetoothCharacteristic? _dataCharacteristic;
  //BluetoothCharacteristic? _commandCharacteristic;

  StreamSubscription<List<int>>? _bleSub;

  int? _firstDeviceMillis;

  bool get isRunning =>
      _box.get('is_recording', defaultValue: false) as bool;

  int get elapsedMs {
    final List times =
        List.from(_box.get('time_series', defaultValue: []));
    return times.isEmpty ? 0 : (times.last as num).toInt();
  }

  List<SessionRow> get rows {
    final List raw =
        List.from(_box.get('session', defaultValue: []));

    return raw.map<SessionRow>((e) {
      return SessionRow(
        elapsedMs: (e['time_ms'] as num).toInt(),
        biteForce: ((e['avg_bite_force'] ?? 0) as num).toInt(),
        mouthOpening: (e['mouth_opening'] as num).toInt(),
      );
    }).toList(growable: false);
  }

  /// ─────────────────────────────────────────────
  /// BLE hookup
  /// ─────────────────────────────────────────────
  void attachBleCharacteristics(
  BluetoothCharacteristic dataCharacteristic,
  //BluetoothCharacteristic commandCharacteristic,
) {
  _dataCharacteristic = dataCharacteristic;
  /*_commandCharacteristic = commandCharacteristic;*/

  debugPrint('🔵 BLE characteristics attached');
  //debugPrint('DATA UUID: ${_dataCharacteristic?.uuid}');
  /*debugPrint('CMD  UUID: ${_commandCharacteristic?.uuid}');*/

  _bleSub?.cancel();

  _bleSub = dataCharacteristic.lastValueStream.listen(_onBleData);

  dataCharacteristic.setNotifyValue(true);
}

  /// ─────────────────────────────────────────────
  /// BLE data handler
  /// ─────────────────────────────────────────────
  void _onBleData(List<int> value) {
    if (!isRunning) return;
    if (value.isEmpty) return;

    final raw = utf8.decode(value).trim();
    debugPrint('📥 decoded: $raw');

    final parts = raw.split(',');
    if (parts.length != 27) return;

    final int? deviceMillis = int.tryParse(parts[0]);
    final double? angle = double.tryParse(parts[1]);

    if (deviceMillis == null || angle == null) return;

    final List<double> bites = [];
    for (int i = 2; i < 22; i++) {
      final b = double.tryParse(parts[i]);
      if (b == null) return;
      bites.add(b);
    }

    final double? avgAngle = double.tryParse(parts[22]);
    final double? maxAngle = double.tryParse(parts[23]);
    final double? avgBite = double.tryParse(parts[24]);
    final double? maxBite = double.tryParse(parts[25]);
    final double? battery = double.tryParse(parts[26]);

    if (avgAngle == null ||
        maxAngle == null ||
        avgBite == null ||
        maxBite == null ||
        battery == null) {
      return;
    }

    _firstDeviceMillis ??= deviceMillis;

    final int elapsed = deviceMillis - _firstDeviceMillis!;
    if (elapsed < 0) return;

    final List times =
        List.from(_box.get(_timeKey, defaultValue: []));
    times.add(elapsed);
    _box.put(_timeKey, times);

    final List IOcurrentSeries =
        List.from(_box.get(_IOcurrentSeriesKey, defaultValue: []));
    final List avgSeries =
        List.from(_box.get(_IOavgSeriesKey, defaultValue: []));
    final List maxSeries =
        List.from(_box.get(_IOmaxSeriesKey, defaultValue: []));

    IOcurrentSeries.add(angle);
    avgSeries.add(avgAngle);
    maxSeries.add(maxAngle);

    _box.put(_IOcurrentSeriesKey, IOcurrentSeries);
    _box.put(_IOavgSeriesKey, avgSeries);
    _box.put(_IOmaxSeriesKey, maxSeries);

    final List biteCurrentSeries =
        List.from(_box.get(_biteCurrentSeriesKey, defaultValue: []));
    final List avgBites =
        List.from(_box.get(_biteAvgSeriesKey, defaultValue: []));
    final List maxBites =
        List.from(_box.get(_biteMaxSeriesKey, defaultValue: []));

    biteCurrentSeries.add(bites);
    avgBites.add(avgBite);
    maxBites.add(maxBite);

    _box.put(_biteCurrentSeriesKey, biteCurrentSeries);
    _box.put(_biteAvgSeriesKey, avgBites);
    _box.put(_biteMaxSeriesKey, maxBites);

    final List session =
        List.from(_box.get('session', defaultValue: []));

    session.add({
      'time_ms': elapsed,
      'avg_bite_force': avgBite,
      'max_bite_force': maxBite,
      'mouth_opening': angle,
      'avg_mouth_opening': avgAngle,
      'max_mouth_opening': maxAngle,
      'battery': battery,
      'bites': List.from(bites),
    });

    _box.put('session', session);
    _box.put(_batteryKey, battery);

    notifyListeners();

    debugPrint("angle=$angle avgBite=$avgBite maxBite=$maxBite");
  }

  /// ─────────────────────────────────────────────
  /// Controls
  /// ─────────────────────────────────────────────
  Future<void> start() async {
    debugPrint('🟢 start() called');

    /*if (_commandCharacteristic == null) {
      debugPrint('❌ Cannot start — command characteristic missing');
      return;
    }

    await _commandCharacteristic!.write(
      utf8.encode("RESET"),
      withoutResponse: true,
    );*/

    _firstDeviceMillis = null;
    _box.put(_timeKey, []);
    _box.put(_IOcurrentSeriesKey, []);
    _box.put(_IOavgSeriesKey, []);
    _box.put(_IOmaxSeriesKey, []);
    _box.put(_biteCurrentSeriesKey, []);
    _box.put(_biteAvgSeriesKey, []);
    _box.put(_biteMaxSeriesKey, []);
    _box.put('session', []);
    _box.put(_sessionStartTimeKey, _formatTimeOfDay(DateTime.now()));

    _box.put('is_recording', true);

    notifyListeners();
  }

  void stop() {
    _box.put('is_recording', false);
    notifyListeners();
  }

  void clear() {
    _firstDeviceMillis = null;
    _box.delete(_timeKey);
    _box.delete(_IOcurrentSeriesKey);
    _box.delete(_IOavgSeriesKey);
    _box.delete(_IOmaxSeriesKey);
    _box.delete(_biteCurrentSeriesKey);
    _box.delete(_biteAvgSeriesKey);
    _box.delete(_biteMaxSeriesKey);
    _box.delete(_sessionStartTimeKey);
    _box.put('is_recording', false);
    notifyListeners();
  }

  String _formatTimeOfDay(DateTime dt) {
    final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String minutes = dt.minute.toString().padLeft(2, '0');
    final String suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString()}:$minutes$suffix';
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    super.dispose();
  }
}