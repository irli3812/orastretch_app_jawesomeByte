// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
//import 'package:permission_handler/permission_handler.dart';

// --- OraStretch UUIDs (Matching your Arduino Sketch) ---
const String SERVICE_UUID = "4fafc201-1fb5-459e-8acb-c74c965c4013";
const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

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
        const SnackBar(content: Text('Already connected to device')),
      );
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
    // Responsive logic for button sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return ElevatedButton(
      onPressed: () => _handleConnect(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0072B2),
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        elevation: 2,
        minimumSize: isMobile ? const Size(44, 44) : const Size(48, 48),
      ),
      child: Icon(
        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
        size: isMobile ? 22 : 24,
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
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _errorMessage;

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initBluetoothSequence();
  }

  /// Simplified Strategy: Let the library handle the OS prompt during the scan.
  Future<void> _initBluetoothSequence() async {
    // We removed the manual Permission.bluetooth.status check here
    // because it can trigger the error message before the iOS popup appears.

    // We still wait for the adapter to be ready
    final state = await FlutterBluePlus.adapterState.first;

    if (state != BluetoothAdapterState.on) {
      // We only show an error if it is explicitly OFF (User disabled it in Control Center)
      if (state == BluetoothAdapterState.off) {
        setState(() => _errorMessage = "Bluetooth is turned off in Settings.");
        return;
      }
      // Otherwise, we wait a moment for it to initialize (common on app cold-start)
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _startScan();
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _errorMessage = null;
    });

    try {
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          _scanResults = results
              .where(
                (r) =>
                    r.device.platformName.contains("OraStretch") ||
                    r.advertisementData.advName.contains("OraStretch") ||
                    r.device.platformName.contains("ArduinoBLEData"),
              )
              .toList();
        });
      });

      // FIX 1: Wrap the String in Guid.parse() and ensure the method matches the library
      // If 'systemDevicesWithServices' is still red, try 'systemDevices' if your version is older,
      // but for 1.33.0+, it must be:
      // Use 'systemDevices' instead of 'systemDevicesWithServices'
      // Note: The old version does NOT take arguments like [Guid(SERVICE_UUID)]
      List<BluetoothDevice> system = await FlutterBluePlus.systemDevices([
        Guid(SERVICE_UUID),
      ]);

      for (var d in system) {
        debugPrint("System device found: ${d.platformName}");

        if (d.platformName.contains("OraStretch") ||
            d.platformName.contains("ArduinoBLEData")) {
          setState(() {
            bool alreadyInList = _scanResults.any(
              (r) => r.device.remoteId == d.remoteId,
            );
            if (!alreadyInList) {
              _scanResults.add(
                ScanResult(
                  device: d,
                  advertisementData: AdvertisementData(
                    advName: d.platformName,
                    txPowerLevel: null,
                    connectable: true,
                    manufacturerData: {},
                    serviceData: {},
                    serviceUuids: [
                      Guid(SERVICE_UUID),
                    ], // Keep the Guid fix here as requested
                    appearance: null,
                  ),
                  rssi: -50,
                  timeStamp: DateTime.now(),
                ),
              );
            }
          });
        }
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Scan Error: $e");
    } finally {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _isScanning = false);
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isConnecting = true);

    try {
      // 1. Connect
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      // 2. iOS Delay (Crucial for GATT discovery stability)
      if (Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // 3. Discover Services
      List<BluetoothService> services = await device.discoverServices();

      // Look for your specific OraStretch Service
      bool foundTarget = services.any(
        (s) => s.uuid.str.toUpperCase() == SERVICE_UUID.toUpperCase(),
      );

      if (foundTarget) {
        widget.onDeviceConnected(true, device);
        if (mounted) Navigator.of(context).pop();
      } else {
        throw Exception("Target service not found on this device.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = "Connection Failed: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final popupButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1F2937),
      disabledBackgroundColor: const Color(0xFFF3F4F6),
      disabledForegroundColor: const Color(0xFF9CA3AF),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      elevation: 1,
    );

    return AlertDialog(
      title: const Text('Connect OraStretch'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isConnecting
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Negotiating with ESP32..."),
                ],
              )
            : _errorMessage != null
            ? Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              )
            : _scanResults.isEmpty && !_isScanning
            ? const Text("No OraStretch devices found nearby.")
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: _scanResults.map((result) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SizedBox(
                      width: double.maxFinite,
                      child: ElevatedButton(
                        style: popupButtonStyle,
                        onPressed: () => _connectToDevice(result.device),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 260;

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result.device.platformName.isEmpty
                                        ? "Unknown"
                                        : result.device.platformName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    result.device.remoteId.str,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    result.device.platformName.isEmpty
                                        ? "Unknown"
                                        : result.device.platformName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  result.device.remoteId.str,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
      actions: [
        ElevatedButton(
          style: popupButtonStyle,
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        if (!_isScanning && !_isConnecting)
          ElevatedButton(
            style: popupButtonStyle,
            onPressed: _startScan,
            child: const Text("Rescan"),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
