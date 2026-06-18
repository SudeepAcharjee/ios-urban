import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'worker_home_screen.dart';
import 'worker_tasks_screen.dart';
import 'worker_chat_screen.dart';
import 'worker_profile_screen.dart';
import 'worker_payment_details.dart';


class WorkerMainScreen extends ConsumerStatefulWidget {
  const WorkerMainScreen({super.key});

  @override
  ConsumerState<WorkerMainScreen> createState() => _WorkerMainScreenState();
}

class _WorkerMainScreenState extends ConsumerState<WorkerMainScreen> {
  int _selectedIndex = 0;

  List<Widget> _getScreens() {
    return [
      const WorkerHomeScreen(),
      const WorkerTasksScreen(),
      const WorkerPaymentDetailsScreen(showBackButton: false),
      const WorkerChatScreen(),
      const WorkerProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    final screens = _getScreens();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _selectedIndex != 1 ? null : AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _getPageTitle(),
          style: const TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: const [
          SizedBox(width: 48),
        ],
      ),
      body: screens[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Home';
      case 1: return 'My Tasks';
      case 2: return 'Payments';
      case 3: return 'Messages';
      case 4: return 'Profile';
      default: return 'Worker Panel';
    }
  }
}
