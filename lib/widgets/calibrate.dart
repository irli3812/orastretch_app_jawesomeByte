import 'dart:convert'; // Provides UTF-8 encoding utilities.

import 'package:flutter/material.dart'; // Imports Flutter Material Design widgets.
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Imports Bluetooth types and APIs.

class CalibrationScreen extends StatefulWidget { // Defines a stateful calibration screen widget.
  final bool isBluetoothConnected; // Stores whether Bluetooth is currently connected.
  final BluetoothCharacteristic? characteristic; // Stores the writable Bluetooth characteristic, if available.

  const CalibrationScreen({ // Creates the calibration screen widget.
    super.key, // Passes the widget key to the parent class.
    required this.isBluetoothConnected, // Requires Bluetooth connection status.
    required this.characteristic, // Requires the Bluetooth characteristic reference.
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState(); // Creates the mutable state for this screen.
}

class _CalibrationScreenState extends State<CalibrationScreen> { // Holds the UI state and logic for the screen.
  bool _isSending = false; // Tracks whether a calibration message is being sent.

  Future<void> _sendCalibration() async { // Sends the calibration signal over Bluetooth.
    if (_isSending) return; // Prevents duplicate sends while one is already in progress.
    if (widget.characteristic == null) { // Checks whether a writable characteristic exists.
      ScaffoldMessenger.of(context).showSnackBar( // Shows a temporary message to the user.
        const SnackBar(content: Text('No writable characteristic found.')), // Displays the missing-characteristic warning.
      );
      return; // Stops execution if no characteristic is available.
    }

    setState(() { // Triggers a UI update.
      _isSending = true; // Marks sending as active.
    });

    String message; // Holds the success or error message to show afterward.
    try { // Starts the Bluetooth write attempt.
      List<int> bytes = utf8.encode('C'); // Converts the calibration text into UTF-8 bytes.
      final char = widget.characteristic!; // Gets the non-null Bluetooth characteristic.
      // Use withoutResponse only if char supports WRITE_NR but NOT Write With Response
      final withoutResponse = // Determines whether to write without waiting for a response.
          char.properties.writeWithoutResponse && !char.properties.write; // Uses write-without-response only when regular write is unavailable.
      debugPrint( // Prints diagnostic information to the debug console.
        '[Calibrate] Writing to ${char.uuid} | ' // Logs the target characteristic UUID.
        'write=${char.properties.write} ' // Logs whether normal write is supported.
        'writeNR=${char.properties.writeWithoutResponse} ' // Logs whether write-without-response is supported.
        'withoutResponse=$withoutResponse', // Logs the chosen write mode.
      );
      await char.write(bytes, withoutResponse: withoutResponse); // Sends the bytes to the Bluetooth device.
      message = 'Calibration signal sent.'; // Stores the success message.
    } catch (e) { // Catches any error during the write operation.
      message = 'Failed to send calibration signal: $e'; // Stores the failure message.
    }

    if (!mounted) return; // Stops if the widget was removed before completion.
    setState(() { // Triggers another UI update.
      _isSending = false; // Marks sending as finished.
    });

    ScaffoldMessenger.of(context).showSnackBar( // Shows the final result message.
      SnackBar(content: Text(message)), // Displays either success or failure text.
    );
  }

  @override
  Widget build(BuildContext context) { // Builds the screen UI.
    return Scaffold( // Provides the page structure.
      appBar: AppBar( // Creates the top app bar.
        title: const Text('Calibration'), // Sets the app bar title.
      ),
      body: Center( // Centers the page content.
        child: Padding( // Adds spacing around the content.
          padding: const EdgeInsets.all(20), // Applies 20 pixels of padding on all sides.
          child: Column( // Arranges widgets vertically.
            mainAxisSize: MainAxisSize.min, // Makes the column only as tall as its children.
            children: [ // Lists the widgets shown in the column.
              const Text( // Displays the main instruction text.
                'Send a calibration signal to the connected device.', // Explains the screen purpose.
                textAlign: TextAlign.center, // Centers the text horizontally.
              ),
              const SizedBox(height: 6), // Adds vertical spacing.
              Text( // Shows the Bluetooth connection status.
                widget.isBluetoothConnected // Checks whether Bluetooth is connected.
                    ? 'Device connected' // Shows connected status text.
                    : 'Connect to a device to enable calibration.', // Shows disconnected status text.
                style: TextStyle( // Styles the status text.
                  color: widget.isBluetoothConnected // Chooses status color based on connection state.
                      ? Colors.green.shade700 // Uses green when connected.
                      : Colors.red.shade700, // Uses red when disconnected.
                  fontWeight: FontWeight.w600, // Makes the text semi-bold.
                ),
                textAlign: TextAlign.center, // Centers the status text.
              ),
              if (widget.characteristic != null) ...[ // Conditionally shows characteristic details if available.
                const SizedBox(height: 4), // Adds a little spacing before the UUID.
                Text( // Displays the characteristic UUID.
                  'UUID: ${widget.characteristic!.uuid}', // Shows the UUID string.
                  style: const TextStyle(fontSize: 11, color: Colors.grey), // Styles the UUID text smaller and gray.
                  textAlign: TextAlign.center, // Centers the UUID text.
                ),
              ],
              const SizedBox(height: 14), // Adds spacing before the button.
              ElevatedButton.icon( // Creates a button with an icon and label.
                onPressed: (!_isSending && widget.isBluetoothConnected) // Enables the button only when ready to send and connected.
                    ? _sendCalibration // Calls the send function when pressed.
                    : null, // Disables the button otherwise.
                icon: const Icon(Icons.tune), // Shows a tuning icon on the button.
                label: Text( // Displays the button text.
                  _isSending ? 'Sending...' : 'Send Calibration Signal', // Changes label based on sending state.
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
