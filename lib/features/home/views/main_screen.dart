import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:car_washing_service_app/core/providers/connectivity_provider.dart';
import 'package:car_washing_service_app/core/providers/mode_provider.dart';
import 'home_screen.dart';
import 'categories_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'messages_list_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoriesScreen(showBackButton: false),
    const BookingsScreen(showBackButton: false),
    const MessagesListScreen(showBackButton: false),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Listen for auth changes to automatically logout
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      if (previous != null &&
          previous.value != null &&
          next.value == null &&
          !next.isLoading) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    });

    final isOfflineMode = ref.watch(modeProvider).value ?? false;
    final isConnected = ref.watch(connectivityProvider).value ?? true;
    final isOffline = isOfflineMode || !isConnected;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(child: _screens[_currentIndex]),
          if (isOffline)
            Positioned.fill(
              child: Container(color: Colors.white.withOpacity(0.7)),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isOffline ? Colors.grey.shade100 : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  0,
                  Icons.home,
                  Icons.home_outlined,
                  'Home',
                  isOffline,
                ),
                _buildNavItem(
                  1,
                  Icons.grid_view_rounded,
                  Icons.grid_view_rounded,
                  'Services',
                  isOffline,
                ),
                _buildNavItem(
                  2,
                  Icons.event_note_rounded,
                  Icons.event_note_rounded,
                  'Bookings',
                  isOffline,
                ),
                _buildNavItem(
                  3,
                  Icons.chat,
                  Icons.chat_outlined,
                  'Message',
                  isOffline,
                ),
                _buildNavItem(
                  4,
                  Icons.person,
                  Icons.person_outline,
                  'Profile',
                  isOffline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData selectedIcon,
    IconData inactiveIcon,
    String label,
    bool isOffline,
  ) {
    const primaryColor = Color(0xFF2029C5);
    const inactiveColor = Color(0xFF6B7280);
    final isSelected = _currentIndex == index;
    final itemColor = isOffline
        ? Colors.grey.shade400
        : (isSelected ? primaryColor : inactiveColor);

    return Expanded(
      child: InkWell(
        onTap: isOffline ? null : () => setState(() => _currentIndex = index),
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : inactiveIcon,
              color: itemColor,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
