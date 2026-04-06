import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String arduinoDeviceName = 'ArduinoBLEData';

class BluetoothButton extends StatelessWidget {
  final bool isConnected;
  final ValueChanged<bool> onConnectionChange;
  final ValueChanged<BluetoothDevice?>? onDeviceSelected;

  const BluetoothButton({
    super.key,
    required this.isConnected,
    required this.onConnectionChange,
    this.onDeviceSelected,
  });

  Future<void> _handleConnect(BuildContext context) async {
    if (isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already connected to device'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DeviceSelectionDialog(
          onDeviceConnected: (connected, device) {
            onConnectionChange(connected);
            if (onDeviceSelected != null) {
              onDeviceSelected!(device);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _handleConnect(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0072B2),
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
        maximumSize: const Size(48, 48),
      ),
      child: Icon(
        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
        size: 24,
      ),
    );
  }
}

class DeviceSelectionDialog extends StatefulWidget {
  final void Function(bool connected, BluetoothDevice? device)
  onDeviceConnected;

  const DeviceSelectionDialog({super.key, required this.onDeviceConnected});

  @override
  State<DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<DeviceSelectionDialog> {
  BluetoothDevice? _device;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  String? _errorMessage;
  String? _connectingDeviceId;

  StreamSubscription<BluetoothAdapterState>? _stateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  String get _statusText {
    if (_errorMessage != null) return _errorMessage!;
    if (_adapterState != BluetoothAdapterState.on) {
      return 'Bluetooth adapter is ${_adapterState.name.toUpperCase()}. Please turn it ON.';
    }
    if (_isScanning) return 'Scanning for devices...';
    if (_connectionState == BluetoothConnectionState.connected &&
        _device != null) {
      final name = _device!.platformName.isEmpty
          ? _device!.remoteId.str
          : _device!.platformName;
      return 'Connected to $name';
    }
    if (_connectionState == BluetoothConnectionState.connecting) {
      return 'Connecting...';
    }
    if (_scanResults.isNotEmpty) {
      return 'Scan finished. Select your device.';
    }
    return 'Ready to scan';
  }

  @override
  void initState() {
    super.initState();
    _listenToAdapterState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
    _connectionSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _listenToAdapterState() {
    _stateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      setState(() {
        _adapterState = state;
      });

      if (state != BluetoothAdapterState.on) {
        _stopScan();
        if (mounted) {
          setState(() {
            _connectionState = BluetoothConnectionState.disconnected;
            _connectingDeviceId = null;
            _device = null;
            _scanResults.clear();
            _errorMessage =
                'Bluetooth is ${state.name.toUpperCase()}. Please turn it ON.';
          });
        }
      } else if (!_isScanning &&
          _connectionState != BluetoothConnectionState.connected) {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      }
    });
  }

  Future<bool> _ensurePermissions() async {
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.status;
      if (status.isGranted) return true;

      final requestStatus = await Permission.bluetooth.request();
      if (requestStatus.isGranted) return true;

      if (mounted) {
        setState(() {
          _errorMessage =
              'Please grant Bluetooth permissions in device Settings.';
        });
      }
      return false;
    }

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final denied = statuses.values.any((s) => !s.isGranted);
      if (!denied) return true;

      if (mounted) {
        setState(() {
          _errorMessage =
              'Please grant Bluetooth permissions in device Settings.';
        });
      }
      return false;
    }

    return true;
  }

  Future<void> _startScan() async {
    final hasPermission = await _ensurePermissions();
    if (!hasPermission) return;

    final adapterState = _adapterState != BluetoothAdapterState.unknown
        ? _adapterState
        : await FlutterBluePlus.adapterState.firstWhere(
            (s) => s != BluetoothAdapterState.unknown,
            orElse: () => BluetoothAdapterState.unknown,
          );

    if (adapterState != BluetoothAdapterState.on) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Bluetooth adapter is ${adapterState.name.toUpperCase()}. Please turn it ON.';
        });
      }
      return;
    }

    await _stopScan();

    if (!mounted) return;
    setState(() {
      _errorMessage = null;
      _scanResults.clear();
      _isScanning = true;
    });

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;

      final filtered = results.where((r) {
        final name = r.device.platformName;
        final advName = r.advertisementData.advName;
        return name.contains(arduinoDeviceName) ||
            advName.contains(arduinoDeviceName) ||
            name.contains('OraStretch') ||
            advName.contains('OraStretch');
      }).toList();

      filtered.sort(
        (a, b) => a.device.platformName.compareTo(b.device.platformName),
      );

      setState(() {
        _scanResults = filtered;
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    await FlutterBluePlus.isScanning.where((s) => s == false).first;

    await _stopScan();
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (!mounted) return;
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    await _stopScan();

    if (!mounted) return;
    setState(() {
      _device = device;
      _connectionState = BluetoothConnectionState.connecting;
      _connectingDeviceId = device.remoteId.str;
      _errorMessage = null;
    });

    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (!mounted) return;
        setState(() {
          _connectionState = state;
          if (state == BluetoothConnectionState.disconnected) {
            _connectingDeviceId = null;
          }
        });
      });

      await Future.delayed(const Duration(milliseconds: 500));

      widget.onDeviceConnected(true, device);

      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.platformName}'),
            backgroundColor: scheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      setState(() {
        _connectionState = BluetoothConnectionState.disconnected;
        _connectingDeviceId = null;
        _errorMessage = 'Connection failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Select BLE Device'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _connectionState == BluetoothConnectionState.connected
                    ? Colors.green.shade50
                    : _isScanning
                    ? Colors.blue.shade50
                    : _adapterState == BluetoothAdapterState.on
                    ? Colors.grey.shade100
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _connectionState == BluetoothConnectionState.connected
                      ? Colors.green.shade900
                      : _isScanning
                      ? Colors.blue.shade900
                      : _adapterState == BluetoothAdapterState.on
                      ? scheme.onSurface
                      : Colors.red.shade900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _isScanning && _scanResults.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _scanResults.isEmpty
                  ? const Center(
                      child: Text(
                        'No devices found. Tap Rescan.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        final result = _scanResults[index];
                        final device = result.device;
                        final isConnecting =
                            _connectingDeviceId == device.remoteId.str &&
                            _connectionState ==
                                BluetoothConnectionState.connecting;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(
                              device.platformName.isEmpty
                                  ? 'Unknown Device'
                                  : device.platformName,
                            ),
                            subtitle: Text(
                              'ID: ${device.remoteId.str} | RSSI: ${result.rssi}',
                            ),
                            trailing: isConnecting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: isConnecting
                                ? null
                                : () => _connectDevice(device),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _connectionState == BluetoothConnectionState.connecting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isScanning ? null : _startScan,
          child: Text(_isScanning ? 'Scanning...' : 'Rescan'),
        ),
      ],
    );
  }
}
