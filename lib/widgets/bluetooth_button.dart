import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// RESPONSIVEBLUETOOTHBUTTON
///
/// RESPONSIVE UPDATES NEEDED:
/// - Button size: 44x44dp (mobile) to 48x48dp (desktop)
/// - Icon size: 20dp (mobile) to 24dp (desktop)
/// - Device selection dialog padding and font sizes
///
/// PATTERN TO APPLY:
///   final screenWidth = MediaQuery.of(context).size.width;
///   final isMobile = screenWidth < 600;
///   
///   minimumSize: isMobile ? const Size(44, 44) : const Size(48, 48),
///   child: Icon(..., size: isMobile ? 20 : 24)

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
      await Future.delayed(const Duration(seconds: 1));
    } else {
      await _showDeviceSelectionDialog(context);
    }
  }

  Future<void> _showDeviceSelectionDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
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
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
      ),
      child: Icon(
        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
        color: const Color(0xFF0072B2),
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
  List<BluetoothDevice> _devicesFound = [];
  bool _isScanning = true;
  bool _isConnecting = false;
  String? _connectingDeviceId;
  String? _errorMessage;

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAdapterState();
    _startScan();
  }

  void _listenToAdapterState() {
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (!mounted) return;

      if (state != BluetoothAdapterState.on) {
        setState(() {
          _errorMessage =
              'Bluetooth is ${state.name.toUpperCase()}. Please turn it ON.';
          _isScanning = false;
        });
      } else {
        setState(() {
          _errorMessage = null;
        });

        // If we just became poweredOn, try scanning again.
        if (!_isScanning) {
          _startScan();
        }
      }
    });
  }

  Future<bool> _ensurePermissions() async {
    if (Platform.isIOS) {
      final status = await Permission.bluetooth.status;
      if (!status.isGranted) {
        final requestStatus = await Permission.bluetooth.request();
        if (!requestStatus.isGranted) {
          setState(() {
            _errorMessage =
                'Please grant Bluetooth permissions in device Settings.';
          });
          return false;
        }
      }
      return true;
    }

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final denied = statuses.entries.where((entry) => !entry.value.isGranted);
      if (denied.isNotEmpty) {
        setState(() {
          _errorMessage =
              'Please grant Bluetooth permissions in device Settings.';
        });
        return false;
      }
      return true;
    }

    return true;
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _devicesFound.clear();
      _errorMessage = null;
    });

    // Use latest cached adapter state, or wait until known.
    final preState = _adapterState != BluetoothAdapterState.unknown
        ? _adapterState
        : await FlutterBluePlus.adapterState.firstWhere(
            (state) => state != BluetoothAdapterState.unknown,
            orElse: () => BluetoothAdapterState.unknown,
          );

    if (preState != BluetoothAdapterState.on) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage =
              'Bluetooth is ${preState.name.toUpperCase()}. Please turn it ON.';
        });
      }
      return;
    }

    final hasPermission = await _ensurePermissions();
    if (!hasPermission) {
      setState(() {
        _isScanning = false;
      });
      return;
    }

    try {
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (!mounted) return;
        final oraDevices = results
            .map((r) => r.device)
            .where((d) => d.platformName.contains('OraStretch'))
            .toList();

        setState(() {
          _devicesFound = oraDevices;
        });
      });

      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      // Wait for scan to finish (in case stopScan is delayed)
      await Future.delayed(const Duration(seconds: 5));
      await FlutterBluePlus.stopScan();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Scan failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _connectingDeviceId = device.remoteId.str;
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      final connectionState = await device.connectionState.first;
      if (connectionState == BluetoothConnectionState.connected) {
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
      } else {
        throw Exception('Failed to connect');
      }
    } catch (e) {
      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: scheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isConnecting = false;
          _connectingDeviceId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Select OraStretch Device'),
      content: SizedBox(
        width: double.maxFinite,
        child: _errorMessage != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                ],
              )
            : _isScanning
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for OraStretch devices...'),
                ],
              )
            : _devicesFound.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No OraStretch devices found',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure your device is powered on and in range',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _devicesFound.length,
                itemBuilder: (context, index) {
                  final device = _devicesFound[index];
                  final isConnecting =
                      _isConnecting &&
                      _connectingDeviceId == device.remoteId.str;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.bluetooth_connected,
                        color: scheme.primary,
                      ),
                      title: Text(
                        device.platformName.isEmpty
                            ? 'Unknown Device'
                            : device.platformName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      subtitle: Text('ID: ${device.remoteId.str}'),
                      trailing: isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: isConnecting
                          ? null
                          : () => _connectToDevice(device),
                    ),
                  );
                },
              ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_isScanning && _devicesFound.isEmpty && _errorMessage == null)
          ElevatedButton(onPressed: _startScan, child: const Text('Rescan')),
      ],
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();
    super.dispose();
  }
}
