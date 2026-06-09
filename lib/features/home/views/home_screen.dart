import 'dart:async';
import 'package:flutter/services.dart';
import 'package:car_washing_service_app/features/home/views/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_washing_service_app/features/home/providers/bookmark_provider.dart';
import 'package:toastification/toastification.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import 'service_detail_screen.dart';
import 'offers_screen.dart';
import 'category_services_screen.dart';
import 'categories_screen.dart';
import '../widgets/location_selector_sheet.dart';
import '../viewmodels/category_provider.dart';
import '../viewmodels/service_provider.dart';
import 'package:car_washing_service_app/features/home/providers/discount_provider.dart';
import 'package:car_washing_service_app/features/home/models/discount_model.dart';
import 'package:car_washing_service_app/features/home/widgets/service_rating_row.dart';
import '../models/service_model.dart';
import '../viewmodels/notification_provider.dart';
import 'package:car_washing_service_app/core/providers/mode_provider.dart';
import 'package:car_washing_service_app/core/providers/connectivity_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  final PageController _bannerController = PageController();
  int _currentPage = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _searchLayerLink = LayerLink();
  OverlayEntry? _searchOverlayEntry;
  List<String> _filteredServices = [];

  // 🎨 Class-level constants for consistency
  static const primaryColor = Color(0xFF2029C5);

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        _hideSearchOverlay();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bannerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _hideSearchOverlay();
    super.dispose();
  }

  void _showSearchOverlay() {
    if (_searchOverlayEntry != null) return;

    _searchOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 40,
        left: 20, // Align with the search bar padding
        top: 0, // Follower handles vertical position relative to target
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 55),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: _filteredServices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No services found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredServices.length,
                      itemBuilder: (context, index) {
                        final serviceName = _filteredServices[index];
                        // Find the actual service model to get more details
                        final allServices =
                            ref.read(servicesProvider).value ?? [];
                        final service = allServices.firstWhere(
                          (s) => s.name == serviceName,
                          orElse: () => ServiceModel(
                            id: '',
                            name: serviceName,
                            image: 'images/services/car_wash_service.png',
                            rating: 4.8,
                            reviews: 120,
                            price: '99',
                            oldPrice: '150',
                            category: '',
                            categoryId: '',
                            shortDescription: '',
                            longDescription: '',
                            status: 'Active',
                            whatsIncluded: [],
                            whatsNotIncluded: [],
                          ),
                        );

                        return ListTile(
                          leading: const Icon(
                            Icons.search,
                            color: Color(0xFF2029C5),
                            size: 18,
                          ),
                          title: Text(
                            service.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () {
                            _searchController.text = service.name;
                            _hideSearchOverlay();

                            if (service.status.toLowerCase() == 'inactive' ||
                                service.status.toLowerCase() == 'deactivated') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('Service Unavailable'),
                                    ],
                                  ),
                                  content: Text(
                                    'The "${service.name}" service is temporarily unavailable. Please check back later!',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        'OK',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ServiceDetailScreen(service: service),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  void _hideSearchOverlay() {
    if (_searchOverlayEntry != null) {
      _searchOverlayEntry?.remove();
      _searchOverlayEntry = null;
    }
  }

  void _filterServices(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredServices = [];
      });
      _hideSearchOverlay();
      return;
    }

    final allServices = ref.read(servicesProvider).value ?? [];
    setState(() {
      _filteredServices = allServices
          .map((s) => s.name)
          .where((s) => s.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });

    if (_searchOverlayEntry != null) {
      _searchOverlayEntry!.markNeedsBuild();
    } else if (_filteredServices.isNotEmpty || query.isNotEmpty) {
      _showSearchOverlay();
    }
  }

  void _showLocationSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationSelectorSheet(),
    );
  }

  bool _offlineDialogShown = false;
  bool _wasOffline = false;

  void _showOfflineDialog() {
    if (_offlineDialogShown || !mounted) return;

    _offlineDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.wifi_off_rounded, color: Color(0xFFD32F2F)),
            SizedBox(width: 10),
            Expanded(child: Text('You are currently offline')),
          ],
        ),
        content: const Text(
          'Turn on your internet to access all the features of the app.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep servicesProvider active to enable searching in real-time
    ref.watch(servicesProvider);
    final isOfflineMode = ref.watch(modeProvider).value ?? false;
    final isConnected = ref.watch(connectivityProvider).value ?? true;
    final isOffline = isOfflineMode || !isConnected;

    if (!isOffline && _wasOffline && _offlineDialogShown) {
      // Internet came back online, close the dialog
      Navigator.of(context).pop();
      _offlineDialogShown = false;
      _wasOffline = false;
    } else if (isOffline) {
      _wasOffline = true;
      if (!_offlineDialogShown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showOfflineDialog();
          }
        });
      }
    } else {
      _wasOffline = false;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          backgroundColor: Colors.white,
          onRefresh: () async {
            // ignore: unused_result
            ref.refresh(servicesProvider);
            // ignore: unused_result
            ref.refresh(categoriesProvider);
            // ignore: unused_result
            ref.refresh(discountProvider);
            // ignore: unused_result
            ref.refresh(userDataProvider);
            await Future.delayed(const Duration(milliseconds: 1000));
          },
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              _hideSearchOverlay();
            },
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📱 Custom Premium Header
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Location & Notifications Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _hideSearchOverlay();
                                  _showLocationSelector(context);
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Location',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: Color(0xFFFFB800),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: ref
                                              .watch(userDataProvider)
                                              .when(
                                                data: (userData) {
                                                  final fullLocation =
                                                      userData?['location'] ??
                                                      'Set Location';
                                                  String location =
                                                      fullLocation;
                                                  if (fullLocation !=
                                                      'Set Location') {
                                                    final parts = fullLocation
                                                        .split(',');
                                                    final cleanParts = parts
                                                        .map((p) {
                                                          return p
                                                              .replaceAll(
                                                                RegExp(
                                                                  r'\b\d{6}\b',
                                                                ),
                                                                '',
                                                              )
                                                              .trim();
                                                        })
                                                        .where((p) {
                                                          final lp = p
                                                              .toLowerCase();
                                                          return p.isNotEmpty &&
                                                              !p.contains(
                                                                '+',
                                                              ) &&
                                                              lp != 'india';
                                                        })
                                                        .toList();

                                                    if (cleanParts.isNotEmpty) {
                                                      location =
                                                          cleanParts.length > 1
                                                          ? '${cleanParts[0]}, ${cleanParts[1]}'
                                                          : cleanParts[0];
                                                    }
                                                  }
                                                  return Text(
                                                    location,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  );
                                                },
                                                loading: () =>
                                                    _buildSkeletonContainer(
                                                      height: 15,
                                                      width: 120,
                                                      borderRadius: 4,
                                                    ),
                                                error: (e, st) => const Text(
                                                  'Set Location',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _hideSearchOverlay();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationsScreen(),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: 54,
                                height: 54,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Rounded Square Button Container
                                    Positioned(
                                      left: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.notifications_none_rounded,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Red Notification Badge Dot
                                    if (ref.watch(
                                          unreadNotificationsCountProvider,
                                        ) >
                                        0)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          height: 12,
                                          width: 12,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        // Search Bar
                        CompositedTransformTarget(
                          link: _searchLayerLink,
                          child: GestureDetector(
                            onTap: () {
                              _searchFocusNode.requestFocus();
                            },
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF9CA3AF),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      onChanged: _filterServices,
                                      decoration: const InputDecoration(
                                        hintText: 'Search',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 15,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 📱 Promo Carousel Section Header
                  ref
                      .watch(discountProvider)
                      .when(
                        data: (discounts) {
                          final activeDiscounts = discounts
                              .where(
                                (d) => d.status == 'active' && !d.isExpired,
                              )
                              .toList();
                          if (activeDiscounts.isEmpty)
                            return const SizedBox.shrink();

                          return Column(
                            children: [
                              // 📱 Promo Carousel Section Header
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 210,
                                child: PageView.builder(
                                  controller: _pageController,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                  },
                                  itemCount: activeDiscounts.length,
                                  itemBuilder: (context, index) {
                                    return PromoCard(
                                      discount: activeDiscounts[index],
                                      themeColor: const Color(0xFF2029C5),
                                      skeleton: _buildSkeletonContainer,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  activeDiscounts.length,
                                  (index) {
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      margin: const EdgeInsets.only(right: 5),
                                      height: 8,
                                      width: _currentPage == index ? 20 : 8,
                                      decoration: BoxDecoration(
                                        color: _currentPage == index
                                            ? const Color(0xFF2029C5)
                                            : Colors.grey.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => Column(
                          children: [
                            // Header Skeleton
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSkeletonContainer(
                                    height: 20,
                                    width: 120,
                                    borderRadius: 4,
                                  ),
                                  _buildSkeletonContainer(
                                    height: 20,
                                    width: 60,
                                    borderRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 200,
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSkeletonContainer(
                                    height: 12,
                                    width: 80,
                                    borderRadius: 10,
                                  ),
                                  const SizedBox(height: 15),
                                  _buildSkeletonContainer(
                                    height: 20,
                                    width: 180,
                                    borderRadius: 4,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildSkeletonContainer(
                                    height: 30,
                                    width: 120,
                                    borderRadius: 4,
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildSkeletonContainer(
                                        height: 10,
                                        width: 140,
                                        borderRadius: 4,
                                      ),
                                      _buildSkeletonContainer(
                                        height: 40,
                                        width: 90,
                                        borderRadius: 25,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        error: (err, stack) => const SizedBox.shrink(),
                      ),
                  const SizedBox(height: 10),
                  // Padding for sections
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 📱 Categories Section
                        const CategorySection(),
                        const SizedBox(height: 30),
                        // 📱 Popular Services Section
                        const PopularServicesSection(
                          title: 'Popular Car Services',
                          categoryName: 'Car',
                        ),
                        const SizedBox(height: 30),
                        const PopularServicesSection(
                          title: 'Popular Electrical Services',
                          categoryName: 'Electrical',
                        ),
                        const SizedBox(height: 30),
                        const PopularServicesSection(
                          title: 'Popular Bike Services',
                          categoryName: 'Bike',
                        ),
                        const SizedBox(height: 30),
                        // 📱 Coming Soon Carousel
                        SizedBox(
                          height: 160,
                          child: PageView.builder(
                            itemCount: 3,
                            itemBuilder: (context, index) {
                              final subtitles = [
                                'More exciting services\nare on the way!',
                                'More subscription based\nservices are on the way.',
                                'Hourly based services\non the way.',
                              ];
                              return ComingSoonCard(subtitle: subtitles[index]);
                            },
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildSkeletonContainer({
  required double height,
  required double width,
  double borderRadius = 12,
  Color? color,
}) {
  return Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: color ?? Colors.grey.shade200,
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade200,
                  Colors.grey.shade100,
                  Colors.grey.shade200,
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class CardBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE0F2FE).withOpacity(0.6),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.35,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CategoryItem extends ConsumerStatefulWidget {
  final CategoryModel category;
  final bool isSelected;

  const CategoryItem({
    super.key,
    required this.category,
    this.isSelected = false,
  });

  @override
  ConsumerState<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends ConsumerState<CategoryItem> {
  bool _isImageLoaded = false;
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    if (widget.category.iconUrl.isNotEmpty) {
      _imageProvider = NetworkImage(widget.category.iconUrl);
      _listenToImage();
    } else {
      _isImageLoaded = true;
    }
  }

  void _listenToImage() {
    _imageProvider!
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener(
            (info, synchronousCall) {
              if (mounted) setState(() => _isImageLoaded = true);
            },
            onError: (exception, stackTrace) {
              if (mounted) setState(() => _isImageLoaded = true);
            },
          ),
        );
  }

  Widget _buildIconStack() {
    const primaryColor = Color(0xFF2029C5);
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor.withOpacity(0.1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(widget.category.fallbackIcon, color: primaryColor, size: 40),
          if (widget.category.name.toLowerCase().contains('bike')) ...[
            Positioned(
              top: 14,
              right: 14,
              child: Icon(
                Icons.star_rounded,
                color: primaryColor.withOpacity(0.6),
                size: 8,
              ),
            ),
            Positioned(
              bottom: 18,
              left: 12,
              child: Icon(
                Icons.star_rounded,
                color: primaryColor.withOpacity(0.6),
                size: 6,
              ),
            ),
            Positioned(
              bottom: 14,
              right: 20,
              child: Icon(
                Icons.star_rounded,
                color: primaryColor.withOpacity(0.6),
                size: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);

    if (!_isImageLoaded) {
      return _buildSkeletonContainer(
        height: 210,
        width: double.infinity,
        borderRadius: 20,
      );
    }

    return GestureDetector(
      onTap: () {
        if (widget.category.status.toLowerCase() == 'inactive' ||
            widget.category.status.toLowerCase() == 'deactivated') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor),
                  SizedBox(width: 10),
                  Text('Category Unavailable'),
                ],
              ),
              content: Text(
                'The "${widget.category.name}" category is temporarily deactivated for maintenance. Please check back later!',
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CategoryServicesScreen(categoryName: widget.category.name),
          ),
        );
      },
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Curved Soft Blue Background
              Positioned.fill(
                child: CustomPaint(painter: CardBackgroundPainter()),
              ),

              // Top Right Chevron Button
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
              ),

              // Content Column
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 16.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 8), // Spacer to push circle down
                    // Icon/Image Section
                    Center(
                      child: widget.category.iconUrl.isNotEmpty
                          ? SizedBox(
                              width: 86,
                              height: 86,
                              child: Image(
                                image: _imageProvider!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildIconStack(),
                              ),
                            )
                          : _buildIconStack(),
                    ),

                    // Category Title
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${widget.category.name} Services',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),

                    // Explore Services Pill Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1043DF),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1043DF).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Explore Services',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PopularServicesSection extends ConsumerWidget {
  final String title;
  final String categoryName;

  const PopularServicesSection({
    super.key,
    required this.title,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textPrimary = Color(0xFF111827);
    const primaryColor = Color(0xFF2029C5);

    final categories = ref.watch(categoriesProvider).value ?? [];
    final currentCategory = categories.firstWhere(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => CategoryModel(
        id: '',
        name: '',
        iconUrl: '',
        fallbackIcon: Icons.category,
        status: 'active',
      ),
    );

    if (currentCategory.status.toLowerCase() == 'inactive' ||
        currentCategory.status.toLowerCase() == 'deactivated') {
      return const SizedBox.shrink();
    }

    return ref
        .watch(servicesByCategoryProvider(categoryName))
        .when(
          skipLoadingOnReload: true,
          data: (services) => AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryServicesScreen(
                              categoryName: categoryName,
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Text(
                            'See All',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryColor,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                services.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 20,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'images/icons/icon-1.png',
                              width: 70,
                              height: 70,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No services available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'We are working on adding exciting $categoryName services for you. Stay tuned!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 370,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          clipBehavior: Clip.none,
                          itemCount: services.length,
                          itemBuilder: (context, index) =>
                              PopularServiceCard(service: services[index]),
                        ),
                      ),
              ],
            ),
          ),
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSkeletonContainer(
                    height: 22,
                    width: 180,
                    borderRadius: 4,
                  ),
                  _buildSkeletonContainer(
                    height: 18,
                    width: 60,
                    borderRadius: 4,
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 370,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  itemBuilder: (context, index) => Container(
                    width: MediaQuery.of(context).size.width - 40,
                    margin: const EdgeInsets.only(right: 20, bottom: 10),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSkeletonContainer(
                          height: 180,
                          width: double.infinity,
                          borderRadius: 20,
                        ),
                        const SizedBox(height: 14),
                        _buildSkeletonContainer(
                          height: 15,
                          width: 120,
                          borderRadius: 6,
                        ),
                        const SizedBox(height: 10),
                        _buildSkeletonContainer(
                          height: 18,
                          width: 180,
                          borderRadius: 4,
                        ),
                        const SizedBox(height: 8),
                        _buildSkeletonContainer(
                          height: 12,
                          width: 220,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          error: (err, stack) => const SizedBox.shrink(),
        );
  }
}

class PopularServiceCard extends ConsumerStatefulWidget {
  final ServiceModel service;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const PopularServiceCard({
    super.key,
    required this.service,
    this.width,
    this.margin,
  });

  @override
  ConsumerState<PopularServiceCard> createState() => _PopularServiceCardState();
}

class _PopularServiceCardState extends ConsumerState<PopularServiceCard> {
  bool _isImageLoaded = false;
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    if (widget.service.image.startsWith('http')) {
      _imageProvider = NetworkImage(widget.service.image);
      _listenToImage();
    } else {
      _isImageLoaded = true;
    }
  }

  void _listenToImage() {
    _imageProvider!
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener(
            (info, synchronousCall) {
              if (mounted) setState(() => _isImageLoaded = true);
            },
            onError: (exception, stackTrace) {
              if (mounted) setState(() => _isImageLoaded = true);
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    final screenWidth = MediaQuery.of(context).size.width;
    final isBookmarked = ref
        .watch(bookmarksProvider)
        .maybeWhen(
          data: (bookmarks) =>
              bookmarks.any((s) => s['title'] == widget.service.name),
          orElse: () => false,
        );

    String discountStr = '';
    if (widget.service.oldPrice.isNotEmpty) {
      final oldP = double.tryParse(widget.service.oldPrice) ?? 0;
      final currP = double.tryParse(widget.service.price) ?? 0;
      if (oldP > currP && oldP > 0) {
        final discount = ((oldP - currP) / oldP * 100).round();
        discountStr = '$discount% OFF';
      }
    }

    return GestureDetector(
      onTap: () {
        final categories = ref.read(categoriesProvider).value ?? [];
        final currentCategory = categories.firstWhere(
          (c) => c.name.toLowerCase() == widget.service.category.toLowerCase(),
          orElse: () => CategoryModel(
            id: '',
            name: '',
            iconUrl: '',
            fallbackIcon: Icons.category,
            status: 'active',
          ),
        );

        if (widget.service.status.toLowerCase() == 'inactive' ||
            widget.service.status.toLowerCase() == 'deactivated') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor),
                  SizedBox(width: 10),
                  Text('Service Unavailable'),
                ],
              ),
              content: Text(
                'The "${widget.service.name}" service is temporarily unavailable. Please check back later!',
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }

        if (currentCategory.status.toLowerCase() == 'inactive' ||
            currentCategory.status.toLowerCase() == 'deactivated') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor),
                  SizedBox(width: 10),
                  Text('Category Unavailable'),
                ],
              ),
              content: Text(
                'This service is temporarily unavailable because the "${widget.service.category}" category is deactivated for maintenance.',
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailScreen(service: widget.service),
          ),
        );
      },
      child: Container(
        width: widget.width ?? (screenWidth - 40),
        margin: widget.margin ?? const EdgeInsets.only(bottom: 20, right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image on top with overlaid tags
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _isImageLoaded && _imageProvider != null
                        ? Image(
                            image: _imageProvider!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.grey.shade200),
                          )
                        : Container(color: Colors.grey.shade100),

                    // Top Left Badges (Overlaid)
                    if (discountStr.isNotEmpty)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                discountStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Top Right Favorite Button (Overlaid)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () async {
                          final cardData = {
                            'title': widget.service.name,
                            'imagePath': widget.service.image,
                            'price': int.tryParse(widget.service.price) ?? 0,
                            'oldPrice':
                                int.tryParse(widget.service.oldPrice) ?? 0,
                          };

                          final isCurrentlyBookmarked = ref
                              .read(bookmarksProvider)
                              .maybeWhen(
                                data: (bookmarks) => bookmarks.any(
                                  (s) => s['title'] == widget.service.name,
                                ),
                                orElse: () => false,
                              );

                          await BookmarkService.toggleBookmark(cardData);

                          if (!context.mounted) return;
                          toastification.show(
                            context: context,
                            type: isCurrentlyBookmarked
                                ? ToastificationType.info
                                : ToastificationType.success,
                            style: ToastificationStyle.flatColored,
                            title: Text(
                              isCurrentlyBookmarked
                                  ? 'Removed from Bookmarks'
                                  : 'Saved to Bookmarks',
                            ),
                            autoCloseDuration: const Duration(seconds: 2),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isBookmarked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isBookmarked
                                ? Colors.red
                                : const Color(0xFF111827),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Content Details Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating Row
                    ServiceRatingRow(serviceName: widget.service.name),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      widget.service.name,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Short Description
                    Text(
                      widget.service.shortDescription.isNotEmpty
                          ? widget.service.shortDescription
                          : 'Complete cleaning with foam wash, polishing, chain cleaning & premium finishing.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Price & Action Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price section
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD1FAE5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${widget.service.price}',
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (widget.service.oldPrice.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₹${widget.service.oldPrice}',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (discountStr.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    discountStr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Action Button (View Details / View)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategorySection extends ConsumerStatefulWidget {
  const CategorySection({super.key});

  @override
  ConsumerState<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<CategorySection> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);

    return ref
        .watch(categoriesProvider)
        .when(
          data: (categories) {
            // Group categories in pairs of 2
            final List<List<CategoryModel>> pages = [];
            for (var i = 0; i < categories.length; i += 2) {
              final List<CategoryModel> page = [categories[i]];
              if (i + 1 < categories.length) {
                page.add(categories[i + 1]);
              }
              pages.add(page);
            }

            if (pages.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoriesScreen(),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Text(
                            'See All',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryColor,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pageController,
                    clipBehavior: Clip.none,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final pageItems = pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CategoryItem(category: pageItems[0]),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: pageItems.length > 1
                                  ? CategoryItem(category: pageItems[1])
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (pages.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        height: 6,
                        width: _currentPage == index ? 24 : 12,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF1043DF)
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
              ],
            );
          },
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSkeletonContainer(
                    height: 24,
                    width: 100,
                    borderRadius: 4,
                  ),
                  _buildSkeletonContainer(
                    height: 18,
                    width: 60,
                    borderRadius: 4,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 220,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSkeletonContainer(
                        height: 210,
                        width: double.infinity,
                        borderRadius: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSkeletonContainer(
                        height: 210,
                        width: double.infinity,
                        borderRadius: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          error: (err, stack) => const SizedBox.shrink(),
        );
  }
}

class PromoCard extends StatefulWidget {
  final DiscountModel discount;
  final Color themeColor;
  final Widget Function({
    required double height,
    required double width,
    double borderRadius,
    Color? color,
  })
  skeleton;

  const PromoCard({
    super.key,
    required this.discount,
    required this.themeColor,
    required this.skeleton,
  });

  @override
  State<PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends State<PromoCard> {
  bool _isImageLoaded = false;
  late ImageProvider _imageProvider;

  @override
  void initState() {
    super.initState();
    _imageProvider = NetworkImage(widget.discount.imageUrl);
    _precache();
  }

  void _precache() {
    _imageProvider
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener(
            (info, synchronousCall) {
              if (mounted) {
                setState(() {
                  _isImageLoaded = true;
                });
              }
            },
            onError: (exception, stackTrace) {
              if (mounted) {
                setState(() {
                  _isImageLoaded = true;
                });
              }
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImageLoaded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 210,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.skeleton(height: 12, width: 80, borderRadius: 10),
            const SizedBox(height: 15),
            widget.skeleton(height: 20, width: 180, borderRadius: 4),
            const SizedBox(height: 10),
            widget.skeleton(height: 30, width: 120, borderRadius: 4),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                widget.skeleton(height: 10, width: 140, borderRadius: 4),
                widget.skeleton(height: 40, width: 90, borderRadius: 25),
              ],
            ),
          ],
        ),
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.themeColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image(
                  image: _imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.discount.displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.discount.displaySubtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Code: ${widget.discount.code} | T&C Applied',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.discount.code),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Promo code "${widget.discount.code}" copied!',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF2563EB),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Claim Now',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComingSoonCard extends StatelessWidget {
  final String subtitle;
  const ComingSoonCard({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Subtle background stars
          const Positioned(
            left: 20,
            bottom: 25,
            child: Icon(Icons.star_rounded, color: Colors.white, size: 12),
          ),
          const Positioned(
            right: 80,
            bottom: 15,
            child: Icon(Icons.star_rounded, color: Colors.white, size: 8),
          ),

          // Top right decorative element
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 55,
              height: 55,
              decoration: const BoxDecoration(
                color: Color(0xFFBFDBFE),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(25),
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          Row(
            children: [
              // Gift Image
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 15),
                child: Image.asset(
                  'images/icons/02.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.card_giftcard_rounded,
                      size: 60,
                      color: Color(0xFF3B82F6),
                    );
                  },
                ),
              ),
              // Text Column
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMING SOON',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
