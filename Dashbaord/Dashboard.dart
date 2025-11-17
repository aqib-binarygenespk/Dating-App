// lib/Dashbaord/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:dating_app/Dashbaord/chat/chat.dart';
import 'package:dating_app/Dashbaord/pairupscreens/pairup/pairup.dart';
import 'package:dating_app/Dashbaord/profile/profile.dart';
import 'package:dating_app/Dashbaord/search/search.dart';
import 'package:dating_app/Dashbaord/settings/settings.dart';

/// Shared nested navigator ids
const int chatNavId = 7;
const int settingsNavId = 8; // <— NEW

class DashboardScreen extends StatefulWidget {
  final int selectedIndex;
  final Widget? detailScreen;

  const DashboardScreen({Key? key, this.selectedIndex = 0, this.detailScreen})
      : super(key: key);

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late int _currentIndex;
  late PageController _pageController;

  Widget _currentSearchScreen = SearchScreen();
  Widget _currentPairUpScreen = const PairUp();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _pageController = PageController(initialPage: _currentIndex);

    Get.put(this);

    if (widget.selectedIndex == 1 && widget.detailScreen != null) {
      _currentSearchScreen = widget.detailScreen!;
    }
    if (widget.selectedIndex == 2 && widget.detailScreen != null) {
      _currentPairUpScreen = widget.detailScreen!;
    }

    // If starting on Chat tab with a detail screen, push it into the nested navigator
    if (widget.selectedIndex == 3 && widget.detailScreen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = Get.nestedKey(chatNavId)?.currentState;
        nav?.push(MaterialPageRoute(builder: (_) => widget.detailScreen!));
      });
    }

    // If starting on Settings tab with a detail screen, push it into the nested navigator
    if (widget.selectedIndex == 4 && widget.detailScreen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = Get.nestedKey(settingsNavId)?.currentState;
        nav?.push(MaterialPageRoute(builder: (_) => widget.detailScreen!));
      });
    }
  }

  void updateSearchScreen(Widget screen) {
    setState(() => _currentSearchScreen = screen);
  }

  void updatePairUpScreen(Widget screen) {
    setState(() => _currentPairUpScreen = screen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,

      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ProfileScreen(),
          _currentSearchScreen,
          _currentPairUpScreen,

          // ---------------- CHAT TAB (nested nav) ----------------
          WillPopScope(
            onWillPop: () async {
              final nav = Get.nestedKey(chatNavId)?.currentState;
              if (nav != null && nav.canPop()) {
                nav.pop();
                return false;
              }
              return true;
            },
            child: Navigator(
              key: Get.nestedKey(chatNavId),
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => const ChatScreen(),
              ),
            ),
          ),

          // ---------------- SETTINGS TAB (nested nav) ----------------
          WillPopScope(
            onWillPop: () async {
              final nav = Get.nestedKey(settingsNavId)?.currentState;
              if (nav != null && nav.canPop()) {
                nav.pop();
                return false;
              }
              return true;
            },
            child: Navigator(
              key: Get.nestedKey(settingsNavId),
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => const SettingsScreen(), // root of settings tab
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _pageController.jumpToPage(index);

              if (index == 1) _currentSearchScreen = SearchScreen();
              if (index == 2) _currentPairUpScreen = const PairUp();
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black87,
          unselectedItemColor: Colors.grey,
          backgroundColor: const Color(0xFFFFEFEF),
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: "Search"),
            BottomNavigationBarItem(icon: ImageIcon(AssetImage('assets/pairupbottom.png')), label: "PairUp"),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
          ],
        ),
      ),
    );
  }
}
