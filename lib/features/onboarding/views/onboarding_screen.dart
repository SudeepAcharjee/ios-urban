import 'package:flutter/material.dart';
import '../../auth/views/login_screen.dart';
import '../../../core/services/preference_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      image: 'images/onboarding/4.png',
      title: 'Choose Your\nService',
      subtitle: 'Select from a wide range of premium\ncar and bike wash services.',
    ),
    OnboardingData(
      image: 'images/onboarding/5.png',
      title: 'Clean car/bike\nat doorstep',
      subtitle: 'Professional care for your vehicle,\nright where you are.',
    ),
    OnboardingData(
      image: 'images/onboarding/1.png',
      title: 'Service Your\nVehicle',
      subtitle: 'Expert detailing and maintenance\nto keep your ride in top shape.',
    ),
    OnboardingData(
      image: 'images/onboarding/3.png',
      title: 'Loyalty That\nRewards',
      subtitle: 'Earn points on every service and\nenjoy exclusive member benefits.',
    ),
  ];

  void _onNext() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() async {
    await PreferenceService.setOnboardingComplete();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double screenHeight = size.height;
    final double screenWidth = size.width;
    
    // Scale factor based on standard height (812.0)
    final double hScale = screenHeight / 812.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Content PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return OnboardingPage(data: _onboardingData[index]);
            },
          ),

          // Header: Logo & Skip (Pinned to Top)
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.01,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'images/logo/Urban Services-2.png',
                    height: screenHeight * 0.1,
                    fit: BoxFit.contain,
                  ),
                  TextButton(
                    onPressed: _navigateToLogin,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: const Color(0xFF2029C5),
                        fontSize: 16 * hScale.clamp(0.8, 1.2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer: Indicators & Button (Pinned to Bottom)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: screenWidth * 0.08,
            right: screenWidth * 0.08,
            child: Column(
              children: [
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _onboardingData.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? const Color(0xFF2029C5)
                            : const Color(0xFF2029C5).withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                
                // Get Started / Next Button
                SizedBox(
                  width: double.infinity,
                  height: (screenHeight * 0.07).clamp(50, 65),
                  child: ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2029C5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF2029C5).withOpacity(0.4),
                    ),
                    child: Text(
                      _currentPage == _onboardingData.length - 1 ? 'Get Started' : 'Next',
                      style: TextStyle(
                        fontSize: 18 * hScale.clamp(0.9, 1.1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double screenHeight = size.height;
    
    // Scale factor based on standard height (812.0)
    final double hScale = screenHeight / 812.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Top Spacer for Header
          SizedBox(height: screenHeight * 0.18),
          
          // Text Content Centered
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32 * hScale.clamp(0.8, 1.2),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF001449),
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16 * hScale.clamp(0.9, 1.1),
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: screenHeight * 0.04),
          
          // Illustration Image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Image.asset(
              data.image,
              height: screenHeight * 0.35,
              fit: BoxFit.contain,
            ),
          ),
          
          // Bottom Spacer to avoid overlapping with footer
          SizedBox(height: screenHeight * 0.2),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String image;
  final String title;
  final String subtitle;

  OnboardingData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}
