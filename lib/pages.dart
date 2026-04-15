import 'package:flutter/material.dart';
import 'screens/record_bite_force.dart';
import 'screens/session_history.dart';
import 'screens/record_mouth_opening.dart';
import 'widgets/footer.dart' as footer_widget;
import 'services/session_data_service.dart';
import 'main.dart';

class MyPage extends StatefulWidget {
  final bool isBluetoothConnected;

  const MyPage({super.key, required this.isBluetoothConnected});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  int currentIndex = 0;
  late PageController _pageController;
  late final List<PageItem> pages;

  final SessionDataService _session = SessionDataService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: currentIndex);

    pages = [
      //PageItem(id: 'ble', title: 'Raw', builder: () => const BLEdata()),
      PageItem(
        id: 'mouth',
        title: 'Mouth Opening',
        builder: () => RecordMouthOpening(
          isBluetoothConnected: widget.isBluetoothConnected,
        ),
      ),
      PageItem(
        id: 'bite',
        title: 'Bite Force',
        builder: () =>
            RecordBiteForce(isBluetoothConnected: widget.isBluetoothConnected),
      ),
      PageItem(
        id: 'sesh',
        title: 'History',
        builder: () => const SessionHistory(),
      ),
      /*PageItem(
        id: 'stats',
        title: 'Trends',
        builder: () => const HistoricalStatistics(),
      ),*/
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    //_session.dispose();
    super.dispose();
  }

  bool get _shouldShowFooterButton {
    return ['mouth', 'bite', 'ble'].contains(pages[currentIndex].id);
  }

  void _onTabTapped(int index) {
    setState(() => currentIndex = index);

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageSwiped(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageNavigation(
          pages: pages,
          currentPageIndex: currentIndex,
          onPageChange: _onTabTapped,
          pageController: _pageController,
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageSwiped,
            children: pages.map((page) => page.builder()).toList(),
          ),
        ),
        if (_shouldShowFooterButton)
          footer_widget.Footer(
            isActive: widget.isBluetoothConnected,
            onStartSession: _session.start,
          ),
      ],
    );
  }
}
