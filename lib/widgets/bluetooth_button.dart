import 'dart:async'; // Provides StreamSubscription and Future utilities
import 'dart:io' show Platform; // Exposes Platform for iOS vs Android detection

import 'package:flutter/material.dart'; // Flutter core UI widgets and Material Design components
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // BLE scanning, device, and connection API
import 'package:permission_handler/permission_handler.dart'; // Runtime permission request handling

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

class BluetoothButton extends StatelessWidget { // Stateless button widget that triggers BLE connection UI
  final bool isConnected; // Whether a device is currently connected
  final ValueChanged<bool> onConnectionChange; // Callback fired when connection state changes
  final ValueChanged<BluetoothDevice?>? onDeviceSelected; // Optional callback with the connected device object

  const BluetoothButton({ // Constructor with required connection state and callbacks
    super.key, // Passes widget key to the parent StatelessWidget
    required this.isConnected, // Must supply current connection status
    required this.onConnectionChange, // Must supply connection change handler
    this.onDeviceSelected, // Optional handler to receive the device object after connection
  });

  Future<void> _handleConnect(BuildContext context) async { // Decides whether to notify "already connected" or open the scan dialog
    if (isConnected) { // Already connected: show informational snackbar instead of opening dialog
      ScaffoldMessenger.of(context).showSnackBar( // Display snackbar on the nearest Scaffold
        const SnackBar(
          content: Text('Already connected to device'), // Message informing user the device is already paired
          duration: Duration(seconds: 1), // Auto-dismiss after 1 second
        ),
      );
      await Future.delayed(const Duration(seconds: 1)); // Wait for snackbar to clear before returning
    } else { // Not connected: open the device scan and selection dialog
      await _showDeviceSelectionDialog(context); // Launch the BLE scan dialog
    }
  }

  Future<void> _showDeviceSelectionDialog(BuildContext context) async { // Opens the DeviceSelectionDialog as a modal
    showDialog( // Displays a modal dialog over the current route
      context: context, // Provide surrounding build context for theming and navigation
      barrierDismissible: false, // Prevent dismissal by tapping outside the dialog
      builder: (dialogContext) { // Builder receives a dialog-scoped context
        return DeviceSelectionDialog( // The dialog widget that handles scanning and connecting
          onDeviceConnected: (connected, device) { // Called by dialog when a device is successfully connected
            onConnectionChange(connected); // Bubble connection boolean up to the parent widget
            if (onDeviceSelected != null) { // Only invoke if an optional device handler was provided
              onDeviceSelected!(device); // Pass the connected BluetoothDevice up to the parent
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) { // Builds the circular Bluetooth icon button shown in the app bar
    return ElevatedButton( // Circular elevated button serving as the Bluetooth toggle
      onPressed: () => _handleConnect(context), // Tap triggers connection logic
      style: ElevatedButton.styleFrom( // Custom visual styling for the circular button
        backgroundColor: Colors.white, // White background to contrast with the blue app bar
        foregroundColor: const Color(0xFF0072B2), // Blue icon color matching brand palette
        shape: const CircleBorder(), // Makes the button perfectly circular
        padding: EdgeInsets.zero, // Remove default padding so the icon fills the circle
        minimumSize: const Size(48, 48), // Minimum 48×48 tap target for accessibility
        maximumSize: const Size(48, 48), // Fixed size keeps the button uniformly circular
      ),
      child: Icon(
        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, // Swap icon based on connection state
        size: 24, // Icon size in logical pixels
      ),
    );
  }
}

class DeviceSelectionDialog extends StatefulWidget { // Stateful dialog that scans for and connects to BLE devices
  final void Function(bool connected, BluetoothDevice? device)
  onDeviceConnected; // Callback providing the connection result and the connected device

  const DeviceSelectionDialog({super.key, required this.onDeviceConnected}); // Requires a connection result callback

  @override
  State<DeviceSelectionDialog> createState() => _DeviceSelectionDialogState(); // Creates the mutable state object for this dialog
}

class _DeviceSelectionDialogState extends State<DeviceSelectionDialog> { // Manages scan state, found devices, and connection flow
  List<BluetoothDevice> _devicesFound = []; // BLE devices discovered that match the "OraStretch" name
  bool _isScanning = true; // Whether a BLE scan is currently in progress
  bool _isConnecting = false; // Whether a connection attempt is in progress for any device
  String? _connectingDeviceId; // Remote ID string of the device currently being connected to
  String? _errorMessage; // Non-null when an error should be shown instead of scan results

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown; // Cached latest state of the Bluetooth adapter
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription; // Listens for Bluetooth adapter on/off/unauthorized changes
  StreamSubscription<List<ScanResult>>? _scanSubscription; // Listens for batched BLE scan result updates

  @override
  void initState() { // Called once when the dialog's state object is first created
    super.initState(); // Initialize the parent State
    _listenToAdapterState(); // Begin watching Bluetooth adapter state changes before scanning
    _startScan(); // Immediately kick off a BLE scan for OraStretch devices
  }

  void _listenToAdapterState() { // Subscribes to the adapter state stream to react when BT is toggled
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) { // Receive every adapter state change event
      _adapterState = state; // Cache the latest adapter state for use in _startScan
      if (!mounted) return; // Guard against calling setState after the widget is disposed

      if (state != BluetoothAdapterState.on) { // Bluetooth is off, unauthorized, or unavailable
        setState(() { // Update UI to show the error
          _errorMessage =
              'Bluetooth is ${state.name.toUpperCase()}. Please turn it ON.'; // Human-readable description of the adapter state
          _isScanning = false; // Stop showing the spinner since scan cannot proceed
        });
      } else { // Bluetooth just turned on (or was already on)
        setState(() { // Clear any previous Bluetooth-off error
          _errorMessage = null; // Remove error so results or spinner can be shown
        });

        // If we just became poweredOn, try scanning again.
        if (!_isScanning) { // Only restart if not already in a scan
          _startScan(); // Resume scanning now that Bluetooth is available
        }
      }
    });
  }

  Future<bool> _ensurePermissions() async { // Requests and verifies the necessary Bluetooth permissions for the current platform
    if (Platform.isIOS) { // iOS only requires the single generic Bluetooth permission
      final status = await Permission.bluetooth.status; // Check whether Bluetooth permission is already granted
      if (!status.isGranted) { // Permission has not been granted yet; ask the user
        final requestStatus = await Permission.bluetooth.request(); // Show the system Bluetooth permission dialog
        if (!requestStatus.isGranted) { // User denied the permission request
          setState(() { // Update UI to show an error prompting the user to open Settings
            _errorMessage =
                'Please grant Bluetooth permissions in device Settings.'; // Instruction for the denied permission
          });
          return false; // Signal that permissions were not obtained; scanning should not proceed
        }
      }
      return true; // iOS Bluetooth permission is granted; safe to scan
    }

    if (Platform.isAndroid) { // Android requires separate scan and connect permissions
      final statuses = await [ // Request all required Android BLE permissions in one call
        Permission.bluetoothScan, // Needed to discover nearby BLE devices
        Permission.bluetoothConnect, // Needed to establish a GATT connection
      ].request(); // Displays the system permission dialogs for each missing permission

      final denied = statuses.entries.where((entry) => !entry.value.isGranted); // Collect any permissions that were denied
      if (denied.isNotEmpty) { // At least one required permission was not granted
        setState(() { // Update UI to direct user to grant permissions in Settings
          _errorMessage =
              'Please grant Bluetooth permissions in device Settings.'; // Instruction for denied permissions
        });
        return false; // Signal that permissions were not obtained; scanning should not proceed
      }
      return true; // All required Android BLE permissions are granted
    }

    return true; // Non-iOS/Android platforms (desktop/web) assumed to not require runtime permissions
  }

  void _startScan() async { // Orchestrates the full BLE scan flow: permissions → adapter check → scan
    setState(() { // Reset UI to show scanning spinner with empty results
      _isScanning = true; // Show the scanning spinner
      _devicesFound.clear(); // Remove any devices found in a previous scan
      _errorMessage = null; // Clear any previous error message
    });

    // On iOS, CBManagerState stays .unknown until Bluetooth permission is
    // granted. Request permissions FIRST so the adapter state resolves.
    final hasPermission = await _ensurePermissions(); // Request permissions before checking adapter state (critical for iOS)
    if (!hasPermission) { // Permissions were denied; cannot proceed with scan
      if (mounted) { // Widget is still in the tree
        setState(() { // Stop the scanning spinner
          _isScanning = false; // Scanning cannot proceed without permissions
        });
      }
      return; // Exit early without starting the scan
    }

    // After permissions are granted the adapter state will be known.
    final preState = _adapterState != BluetoothAdapterState.unknown // Use the cached state if it has already resolved
        ? _adapterState // Cached state is valid; use it directly
        : await FlutterBluePlus.adapterState.firstWhere( // Wait for the first non-unknown state event from the stream
            (state) => state != BluetoothAdapterState.unknown, // Accept any resolved state
            orElse: () => BluetoothAdapterState.unknown, // Fallback if the stream closes without resolving
          );

    if (preState != BluetoothAdapterState.on) { // Bluetooth is not enabled; cannot start a scan
      if (mounted) { // Widget is still in the tree
        setState(() { // Update UI to show the Bluetooth-off error
          _isScanning = false; // Stop the spinning indicator
          _errorMessage =
              'Bluetooth is ${preState.name.toUpperCase()}. Please turn it ON.'; // Tell the user to enable Bluetooth
        });
      }
      return; // Exit early without starting the scan
    }

    try { // Attempt to start BLE scan and collect matching results
      // Listen to scan results.
      // Check both platformName and advName because on iOS the advertisement
      // local name is surfaced via advName before the device is cached.
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) { // Receive the latest batch of scan results
        if (!mounted) return; // Skip processing if the widget was disposed during the scan
        final oraDevices = results // Filter the full result list to only OraStretch devices
            .where(
              (r) =>
                  r.device.platformName.contains('OraStretch') || // Match on the OS-cached platform name
                  r.advertisementData.advName.contains('OraStretch'), // Match on the BLE advertisement local name (needed on iOS before caching)
            )
            .map((r) => r.device) // Extract the BluetoothDevice object from each matching ScanResult
            .toList(); // Convert the lazy iterable to a concrete list for setState

        setState(() { // Refresh the device list shown in the dialog
          _devicesFound = oraDevices; // Replace previous results with the latest filtered list
        });
      });

      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)); // Begin BLE scan; plugin auto-stops after 5 seconds

      // Wait for scan to finish (in case stopScan is delayed)
      await Future.delayed(const Duration(seconds: 5)); // Allow the full 5-second window for scan results to arrive
      await FlutterBluePlus.stopScan(); // Explicitly stop the scan after the delay to free resources
    } catch (e) { // Scan failed (e.g., adapter turned off mid-scan)
      if (mounted) { // Widget is still in the tree
        setState(() { // Show the scan failure message in the dialog
          _errorMessage = 'Scan failed: ${e.toString()}'; // Surface the exception message to the user
        });
      }
    } finally { // Always runs after try/catch whether scan succeeded or failed
      if (mounted) { // Widget is still in the tree
        setState(() { // Stop the scanning spinner
          _isScanning = false; // Mark scanning as complete
        });
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async { // Initiates a GATT connection to the selected BLE device
    setState(() { // Mark this specific device as being connected to
      _isConnecting = true; // Show the connecting spinner in the list tile
      _connectingDeviceId = device.remoteId.str; // Track which device is being connected so the correct tile shows the spinner
    });

    try { // Attempt to connect and verify the resulting connection state
      await device.connect(timeout: const Duration(seconds: 10)); // Request a GATT connection; times out after 10 seconds

      final connectionState = await device.connectionState.first; // Read the first emitted value from the connection state stream
      if (connectionState == BluetoothConnectionState.connected) { // Verify the GATT connection is fully established
        // iOS: Add delay for MTU negotiation and GATT database discovery.
        // Critical for reliable service/characteristic discovery on iOS.
        if (Platform.isIOS) { // iOS-specific: GATT stack needs extra time after connect()
          await Future.delayed(const Duration(milliseconds: 500)); // Allow 500ms for MTU exchange and GATT cache to settle
        }

        widget.onDeviceConnected(true, device); // Notify the parent widget that connection succeeded, passing the device

        if (mounted) { // Widget is still in the tree before showing UI feedback
          final scheme = Theme.of(context).colorScheme; // Retrieve current theme colors for snackbar styling
          ScaffoldMessenger.of(context).showSnackBar( // Show success message on the parent Scaffold
            SnackBar(
              content: Text('Connected to ${device.platformName}'), // Include device name in the success message
              backgroundColor: scheme.primaryContainer, // Theme primary container color signals success
              behavior: SnackBarBehavior.floating, // Floating style so it does not push content
              duration: const Duration(seconds: 2), // Auto-dismiss after 2 seconds
            ),
          );
          Navigator.of(context).pop(); // Close the device selection dialog after successful connection
        }
      } else { // Device reported a non-connected state after connect() returned
        throw Exception('Failed to connect'); // Force into the catch block with a descriptive error
      }
    } catch (e) { // Connection attempt failed or timed out
      if (mounted) { // Widget is still in the tree
        final scheme = Theme.of(context).colorScheme; // Retrieve current theme colors for snackbar styling
        ScaffoldMessenger.of(context).showSnackBar( // Show failure message on the parent Scaffold
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'), // Display the reason for failure
            backgroundColor: scheme.error, // Theme error color signals failure
            behavior: SnackBarBehavior.floating, // Floating style so it does not push content
            duration: const Duration(seconds: 3), // Longer duration so user can read the error
          ),
        );
        setState(() { // Reset connecting state so the user can retry
          _isConnecting = false; // Remove the connecting spinner
          _connectingDeviceId = null; // Clear the tracked device ID
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) { // Renders the dialog content: error, scanning, empty, or device list states
    final scheme = Theme.of(context).colorScheme; // Cache theme colors for reuse throughout the build method
    return AlertDialog( // Material dialog wrapper with title, content, and action buttons
      title: const Text('Select OraStretch Device'), // Dialog title displayed at the top
      content: SizedBox( // Wraps content to constrain dialog width
        width: double.maxFinite, // Expand content to take as much width as the dialog allows
        child: _errorMessage != null // Priority 1: show error state if any error is present
            ? Column( // Error state layout: icon above message
                mainAxisSize: MainAxisSize.min, // Shrink column height to fit its children
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error), // Large error icon for visual emphasis
                  const SizedBox(height: 16), // Vertical spacing between icon and message
                  Text(_errorMessage!, textAlign: TextAlign.center), // Display the error message centered
                ],
              )
            : _isScanning // Priority 2: show scanning spinner if scan is in progress
            ? const Column( // Scanning state layout: spinner above label
                mainAxisSize: MainAxisSize.min, // Shrink column height to fit its children
                children: [
                  CircularProgressIndicator(), // Animated spinner while BLE scan runs
                  SizedBox(height: 16), // Vertical spacing between spinner and label
                  Text('Scanning for OraStretch devices...'), // Status label shown during scan
                ],
              )
            : _devicesFound.isEmpty // Priority 3: show empty state if scan finished with no results
            ? Column( // Empty state layout: muted icon above guidance text
                mainAxisSize: MainAxisSize.min, // Shrink column height to fit its children
                children: [
                  Icon(
                    Icons.bluetooth_disabled, // Icon signaling no device was found
                    size: 48, // Large icon for visual emphasis
                    color: scheme.onSurfaceVariant, // Muted color for an inactive/empty state
                  ),
                  const SizedBox(height: 16), // Vertical spacing between icon and primary text
                  const Text(
                    'No OraStretch devices found', // Primary empty-state message
                    textAlign: TextAlign.center, // Center for visual balance
                  ),
                  const SizedBox(height: 8), // Vertical spacing between primary and secondary text
                  Text(
                    'Make sure your device is powered on and in range', // Secondary guidance for the user
                    textAlign: TextAlign.center, // Center for visual balance
                    style: TextStyle(
                      fontSize: 12, // Smaller font to visually de-emphasize secondary guidance
                      color: scheme.onSurfaceVariant, // Muted color for secondary text
                    ),
                  ),
                ],
              )
            : ListView.builder( // Results state: scrollable list of discovered OraStretch devices
                shrinkWrap: true, // Size the ListView to its content inside the dialog's SizedBox
                itemCount: _devicesFound.length, // One tile per discovered device
                itemBuilder: (context, index) { // Builder called once per item in _devicesFound
                  final device = _devicesFound[index]; // The BluetoothDevice for this list tile
                  final isConnecting =
                      _isConnecting &&
                      _connectingDeviceId == device.remoteId.str; // True only for the specific device being connected

                  return Card( // Card container adds elevation and rounded corners per tile
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8, // Horizontal inset from the dialog edge
                      vertical: 4, // Vertical spacing between adjacent cards
                    ),
                    child: ListTile( // Standard Material list tile with leading icon, title, subtitle, and trailing
                      leading: Icon(
                        Icons.bluetooth_connected, // Bluetooth icon to signify a connectable device
                        color: scheme.primary, // Themed primary blue color
                      ),
                      title: Text(
                        device.platformName.isEmpty // Fall back to generic label if device name is absent
                            ? 'Unknown Device' // Shown when the OS has not cached a name for the device
                            : device.platformName, // Show the BLE-advertised device name
                        style: TextStyle(
                          fontWeight: FontWeight.w500, // Medium weight for device name readability
                          color: scheme.onSurface, // Themed on-surface text color
                        ),
                      ),
                      subtitle: Text('ID: ${device.remoteId.str}'), // Display MAC address or UUID for identification
                      trailing: isConnecting // Show spinner while this device is being connected; otherwise show chevron
                          ? const SizedBox(
                              width: 20, // Constrain spinner to a small fixed width
                              height: 20, // Constrain spinner to a small fixed height
                              child: CircularProgressIndicator(strokeWidth: 2), // Thin spinner while connection is pending
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16), // Chevron indicating the tile is tappable
                      onTap: isConnecting // Disable tap while a connection is in progress for this tile
                          ? null // Null disables the tap callback entirely
                          : () => _connectToDevice(device), // Initiate GATT connection when tile is tapped
                    ),
                  );
                },
              ),
      ),
      actions: [ // Dialog action buttons rendered at the bottom
        ElevatedButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(), // Disable Cancel while a connection is in progress
          child: const Text('Cancel'), // Cancel button label
        ),
        if (!_isScanning && _devicesFound.isEmpty && _errorMessage == null) // Show Rescan only when idle with no results and no error
          ElevatedButton(onPressed: _startScan, child: const Text('Rescan')), // Rescan button restarts the full scan flow
      ],
    );
  }

  @override
  void dispose() { // Cleans up stream subscriptions when the dialog is removed from the widget tree
    _scanSubscription?.cancel(); // Cancel BLE scan results listener to prevent memory leaks
    _adapterSubscription?.cancel(); // Cancel adapter state listener to prevent memory leaks
    super.dispose(); // Call parent dispose to complete standard cleanup
  }
}
