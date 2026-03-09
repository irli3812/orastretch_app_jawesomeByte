import 'package:flutter/material.dart';
import 'pages.dart';
import 'widgets/bluetooth_button.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'services/session_data_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('appBox');
  runApp(const MyApp());
}

/// Global Meter Gauge Limits RECORD MOUTH OPENING
const double gaugeMin = -180.0;
const double gaugeMax = 180.0;
const int minorDivisions = 12;
const int majorDivisions = 2;

/// Global Meter Gauge Limits RECORD BITE FORCE (BF)
const double bfGaugeMin = -180.0;
const double bfGaugeMax = 180.0;
const int bfMinorDivisions = 12;
const int bfMajorDivisions = 2;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isBluetoothConnected = false;

  @override
  Widget build(BuildContext context) { 
    return MaterialApp(
      title: 'Bitefeedback',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
            title: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                        Text(
                          'Bitefeedback', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'OraStretch Companion',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 186, 221, 250),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: BluetoothButton(
                    isConnected: isBluetoothConnected,
                    onConnectionChange: (isConnected) {
                      setState(() {
                        isBluetoothConnected = isConnected;
                      });
                    },
                    onDeviceSelected: (device) async {
                      if (device == null) return;
                      try {
                        final services = await device.discoverServices();
                        BluetoothCharacteristic? chosen;
                        for (final s in services) {
                          for (final c in s.characteristics) {
                            if (c.properties.notify) {
                              chosen = c;
                              break;
                            }
                          }
                          if (chosen != null) break;
                        }
                        if (chosen == null) {
                          for (final s in services) {
                            if (s.characteristics.isNotEmpty) {
                              chosen = s.characteristics.first;
                              break;
                            }
                          }
                        }
                        if (chosen != null) {
                          SessionDataService().attachBleCharacteristic(chosen);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No notifiable characteristic found on device.'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error discovering characteristics: ${e.toString()}'),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(16),
              child: Container(),
            )
          ),
        body: MyPage(isBluetoothConnected: isBluetoothConnected),
      ),
    );
  }
}

class PageItem {
  final String id;
  final String title;
  final Widget Function() builder;

  PageItem({
    required this.id,
    required this.title,
    required this.builder,
  });
}

class PageNavigation extends StatefulWidget {
  final List<PageItem> pages;
  final int currentPageIndex;
  final Function(int) onPageChange;

  const PageNavigation({
    super.key,
    required this.pages,
    required this.currentPageIndex,
    required this.onPageChange,
  });

  @override
  State<PageNavigation> createState() => _PageNavigationState();
}

class _PageNavigationState extends State<PageNavigation> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFBFDBFE)),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(widget.pages.length, (index) {
            final bool isActive = index == widget.currentPageIndex;
            return TextButton(
              onPressed: () => widget.onPageChange(index),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor: isActive
                    ? const Color(0xFFEFF6FF)
                    : Colors.transparent,
                foregroundColor: isActive
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF374151),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.pages[index].title,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF374151),
                    ),
                  ),
                  if (isActive)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      height: 2,
                      width: 40,
                      color: const Color(0xFF2563EB),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}