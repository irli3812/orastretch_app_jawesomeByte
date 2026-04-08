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
  final int mio;

  SessionRow({
    required this.elapsedMs,
    required this.biteForce,
    required this.mio,
  });
}

/// ─────────────────────────────────────────────
/// Session data service (singleton)
/// ─────────────────────────────────────────────
class SessionDataService extends ChangeNotifier {
  // Hive keys
  static const _timeKey = 'time_series';

  static const _IOcurrentSeriesKey = 'mouth_opening_current_series';

  static const _biteCurrentSeriesKey = 'bite_forces_current_series';
  static const _biteAvgSeriesKey = 'bite_force_avg_series';
  static const _bitePacketCurrentMaxSeriesKey =
      'bite_force_current_packet_max_series';
  static const _biteSensorRunningMaxKey = 'bite_sensor_running_max';

  static const _batteryKey = 'batteryPercent';
  static const _sessionStartTimeKey = 'session_start_time';
  static const _sessionStartTimePreciseKey = 'session_start_time_precise';

  // Singleton
  static final SessionDataService _instance = SessionDataService._internal();
  factory SessionDataService() => _instance;
  SessionDataService._internal();

  final Box _box = Hive.box('appBox');

  /// BLE
  BluetoothCharacteristic? _dataCharacteristic;
  //BluetoothCharacteristic? _commandCharacteristic;

  StreamSubscription<List<int>>? _bleSub;

  int? _firstDeviceMillis;

  bool get isRunning => _box.get('is_recording', defaultValue: false) as bool;

  int get elapsedMs {
    final List times = List.from(_box.get('time_series', defaultValue: []));
    return times.isEmpty ? 0 : (times.last as num).toInt();
  }

  List<SessionRow> get rows {
    final List raw = List.from(_box.get('session', defaultValue: []));

    return raw
        .map<SessionRow>((e) {
          return SessionRow(
            elapsedMs: (e['time_ms'] as num).toInt(),
            biteForce: ((e['avg_bite_force'] ?? 0) as num).toInt(),
            mio: (e['mouth_opening'] as num).toInt(),
          );
        })
        .toList(growable: false);
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
    debugPrint('📊 DATA UUID: ${_dataCharacteristic?.uuid}');
    /*debugPrint('CMD  UUID: ${_commandCharacteristic?.uuid}');*/

    _bleSub?.cancel();

    _bleSub = dataCharacteristic.lastValueStream.listen(_onBleData);

    // Enable notifications with retry logic for iOS stability
    _setNotifyValueWithRetry(dataCharacteristic);
  }

  /// Set notify value with retry logic (iOS-friendly).
  /// iOS can fail on first attempt due to GATT operation timing.
  Future<void> _setNotifyValueWithRetry(BluetoothCharacteristic char) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await char.setNotifyValue(true);
        debugPrint('✅ Notifications enabled on attempt ${attempt + 1}');
        return;
      } catch (e) {
        debugPrint('⚠️  Notify attempt ${attempt + 1} failed: $e');
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          debugPrint('❌ Failed to enable notifications: $e');
        }
      }
    }
  }

  /// ─────────────────────────────────────────────
  /// BLE data handler
  /// ─────────────────────────────────────────────
  double _findPacketBiteForceMax(List<double> bites) {
    if (bites.isEmpty) return 0.0;

    double packetMax = bites.first;
    for (final value in bites) {
      if (value > packetMax) {
        packetMax = value;
      }
    }
    return packetMax;
  }

  void _onBleData(List<int> value) {
    if (!isRunning) return;
    if (value.isEmpty) return;

    final raw = utf8.decode(value).trim();
    debugPrint('📥 decoded: $raw');

    final parts = raw.split(',');
    if (parts.length != 24) return;

    // Parse CSV format: timestamp, mouthDistance, bite1-bite20, smartBFAverage, battery
    final int? timestamp = int.tryParse(parts[0]);
    final double? mouthDistance = double.tryParse(parts[1]);

    if (timestamp == null || mouthDistance == null) return;

    // Parse 20 bite force sensors (indices 2-21)
    final List<double> bites = [];
    for (int i = 2; i < 22; i++) {
      final b = double.tryParse(parts[i]);
      if (b == null) return;
      bites.add(b);
    }

    // Parse smart bite force average and battery
    final double? smartBFAverage = double.tryParse(parts[22]);
    final double? battery = double.tryParse(parts[23]);

    if (smartBFAverage == null || battery == null) {
      return;
    }

    _firstDeviceMillis ??= timestamp;

    final int elapsed = timestamp - _firstDeviceMillis!;
    if (elapsed < 0) return;

    final List times = List.from(_box.get(_timeKey, defaultValue: []));
    times.add(elapsed);
    _box.put(_timeKey, times);

    // Store mouth opening (current distance only)
    final List IOcurrentSeries = List.from(
      _box.get(_IOcurrentSeriesKey, defaultValue: []),
    );
    IOcurrentSeries.add(mouthDistance);
    _box.put(_IOcurrentSeriesKey, IOcurrentSeries);

    // Store bite force series
    final List biteCurrentSeries = List.from(
      _box.get(_biteCurrentSeriesKey, defaultValue: []),
    );
    final List smartAvgBites = List.from(
      _box.get(_biteAvgSeriesKey, defaultValue: []),
    );
    final List packetMaxBites = List.from(
      _box.get(_bitePacketCurrentMaxSeriesKey, defaultValue: []),
    );
    
    final double packetMaxBite = _findPacketBiteForceMax(bites);

    biteCurrentSeries.add(bites);
    smartAvgBites.add(smartBFAverage);
    packetMaxBites.add(packetMaxBite);

    _box.put(_biteCurrentSeriesKey, biteCurrentSeries);
    _box.put(_biteAvgSeriesKey, smartAvgBites);
    _box.put(_bitePacketCurrentMaxSeriesKey, packetMaxBites);

    final List session = List.from(_box.get('session', defaultValue: []));

    session.add({
      'time_ms': elapsed,
      'mouth_opening': mouthDistance,
      'battery': battery,
      'bites': List.from(bites),
    });

    _box.put('session', session);

    final List<dynamic> runningMaxRaw = List<dynamic>.from(
      _box.get(
        _biteSensorRunningMaxKey,
        defaultValue: List<double>.filled(20, double.negativeInfinity),
      ),
    );
    if (runningMaxRaw.length != 20) {
      runningMaxRaw
        ..clear()
        ..addAll(List<double>.filled(20, double.negativeInfinity));
    }

    for (int i = 0; i < 20; i++) {
      final current = runningMaxRaw[i] is num
          ? (runningMaxRaw[i] as num).toDouble()
          : double.negativeInfinity;
      if (bites[i] > current) {
        runningMaxRaw[i] = bites[i];
      }
    }
    _box.put(_biteSensorRunningMaxKey, runningMaxRaw);

    _box.put(_batteryKey, battery);

    notifyListeners();

    debugPrint("mouthDistance=$mouthDistance smartBFAverage=$smartBFAverage packetMaxBite=$packetMaxBite battery=$battery");
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
    _box.put(_biteCurrentSeriesKey, []);
    _box.put(_biteAvgSeriesKey, []);
    _box.put(_bitePacketCurrentMaxSeriesKey, []);
    _box.put(
      _biteSensorRunningMaxKey,
      List<double>.filled(20, double.negativeInfinity),
    );
    _box.put('session', []);
    final now = DateTime.now();
    _box.put(_sessionStartTimeKey, _formatTimeOfDay(now));
    _box.put(_sessionStartTimePreciseKey, _formatTimeOfDayWithSeconds(now));

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
    _box.delete(_biteCurrentSeriesKey);
    _box.delete(_biteAvgSeriesKey);
    _box.delete(_bitePacketCurrentMaxSeriesKey);
    _box.delete(_biteSensorRunningMaxKey);
    _box.delete(_sessionStartTimeKey);
    _box.delete(_sessionStartTimePreciseKey);
    _box.put('is_recording', false);
    notifyListeners();
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

  @override
  void dispose() {
    _bleSub?.cancel();
    super.dispose();
  }
}
