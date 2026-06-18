import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_detail_screen.dart';
import '../models/service_model.dart';
import '../viewmodels/service_provider.dart';
import 'package:car_washing_service_app/features/home/widgets/service_rating_row.dart';
import '../viewmodels/category_provider.dart';
import 'package:car_washing_service_app/features/home/views/home_screen.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const CategoriesScreen({super.key, this.showBackButton = true});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _searchLayerLink = LayerLink();
  OverlayEntry? _searchOverlayEntry;
  
  // 🔍 Filter State
  RangeValues _currentRangeValues = const RangeValues(0, 20000);
  String _selectedFilter = 'Most Popular';
  String _selectedCategory = 'All';
  final List<String> _filterOptions = ['Most Popular', 'Price: Low to High', 'Price: High to Low', 'Top Rated'];

  List<ServiceModel> _searchOverlayResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    _hideSearchOverlay();
    super.dispose();
  }

  void _showSearchOverlay(List<ServiceModel> allServices) {
    if (_searchOverlayEntry != null) return;

    _searchOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 40,
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 55),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(15),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.white,
              ),
              child: _searchOverlayResults.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No services found', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _searchOverlayResults.length,
                    itemBuilder: (context, index) {
                      final service = _searchOverlayResults[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: service.image.startsWith('http')
                            ? Image.network(service.image, width: 35, height: 35, fit: BoxFit.cover)
                            : Image.asset(service.image, width: 35, height: 35, fit: BoxFit.cover),
                        ),
                        title: Text(service.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('₹${service.price}', style: const TextStyle(color: Color(0xFF2029C5), fontSize: 12)),
                        onTap: () {
                          final categories = ref.read(categoriesProvider).value ?? [];
                          final currentCategory = categories.firstWhere(
                            (c) => c.name.toLowerCase() == service.category.toLowerCase(),
                            orElse: () => CategoryModel(id: '', name: '', iconUrl: '', fallbackIcon: Icons.category, status: 'active'),
                          );

                          if (currentCategory.status.toLowerCase() == 'inactive' || 
                              currentCategory.status.toLowerCase() == 'deactivated') {
                            _hideSearchOverlay();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Color(0xFF2029C5)),
                                    const SizedBox(width: 10),
                                    const Text('Service Unavailable'),
                                  ],
                                ),
                                content: Text(
                                  'This service is temporarily unavailable because the "${service.category}" category is deactivated for maintenance.',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2029C5))),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          _searchController.text = service.name;
                          _hideSearchOverlay();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ServiceDetailScreen(
                                service: service,
                              ),
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
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
  }

  void _filterBySearch(String query, List<ServiceModel> allServices) {
    if (query.isEmpty) {
      _hideSearchOverlay();
      return;
    }

    setState(() {
      _searchOverlayResults = allServices
          .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });

    if (_searchOverlayEntry != null) {
      _searchOverlayEntry!.markNeedsBuild();
    } else {
      _showSearchOverlay(allServices);
    }
  }

  // 🎚️ Filter Bottom Sheet
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).padding.bottom;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: EdgeInsets.fromLTRB(25, 30, 25, 30 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              
              // Select Category
              const Text('Select Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ref.watch(categoriesProvider).when(
                data: (categories) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((category) {
                      final isSelected = _selectedCategory == category.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            if (category.status.toLowerCase() == 'inactive' || 
                                category.status.toLowerCase() == 'deactivated') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Color(0xFF2029C5)),
                                      const SizedBox(width: 10),
                                      const Text('Category Unavailable'),
                                    ],
                                  ),
                                  content: Text(
                                    'The "${category.name}" category is temporarily deactivated for maintenance. Please check back later!',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2029C5))),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            setSheetState(() => _selectedCategory = category.name);
                            setState(() => _selectedCategory = category.name);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2029C5) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFF2029C5) : Colors.grey.shade200),
                            ),
                            child: Text(
                              category.name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                loading: () => Row(
                  children: List.generate(3, (index) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildSkeletonContainer(height: 40, width: 80, borderRadius: 12),
                  )),
                ),
                error: (e, st) => const Text('Error loading categories'),
              ),
              const SizedBox(height: 30),
              
              // Price Range
              const Text('Price Range', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              RangeSlider(
                values: _currentRangeValues,
                min: 0,
                max: 20000,
                divisions: 100,
                activeColor: const Color(0xFF2029C5),
                inactiveColor: const Color(0xFFE5E7EB),
                labels: RangeLabels(
                  '₹${_currentRangeValues.start.round()}',
                  '₹${_currentRangeValues.end.round()}',
                ),
                onChanged: (values) {
                  setSheetState(() => _currentRangeValues = values);
                  setState(() => _currentRangeValues = values);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('₹${_currentRangeValues.start.round()}', style: const TextStyle(color: Colors.grey)),
                  Text('₹${_currentRangeValues.end.round()}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Sort By
              const Text('Sort By', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _filterOptions.map((option) {
                  final isSelected = _selectedFilter == option;
                  return GestureDetector(
                    onTap: () {
                      setSheetState(() => _selectedFilter = option);
                      setState(() => _selectedFilter = option);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2029C5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? const Color(0xFF2029C5) : Colors.grey.shade300),
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 40),
              
              // Apply Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2029C5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Apply Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton ? IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
          ),
        ) : null,
        title: const Text(
          'All Services',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ref.watch(servicesProvider).when(
        data: (allServices) {
          // Apply Filtering
          List<ServiceModel> displayedServices = allServices.where((service) {
            final matchesSearch = service.name.toLowerCase().contains(_searchController.text.toLowerCase());
            final price = int.tryParse(service.price) ?? 0;
            final matchesPrice = price >= _currentRangeValues.start && price <= _currentRangeValues.end;
            final matchesCategory = _selectedCategory == 'All' ||
                service.category.trim().toLowerCase() == _selectedCategory.trim().toLowerCase() ||
                service.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
                _selectedCategory.toLowerCase().contains(service.category.toLowerCase()) ||
                (service.category.toLowerCase().contains('ac') && _selectedCategory.toLowerCase().contains('ac'));
            return matchesSearch && matchesPrice && matchesCategory;
          }).toList();

          // Apply Sorting
          if (_selectedFilter == 'Price: Low to High') {
            displayedServices.sort((a, b) => (int.tryParse(a.price) ?? 0).compareTo(int.tryParse(b.price) ?? 0));
          } else if (_selectedFilter == 'Price: High to Low') {
            displayedServices.sort((a, b) => (int.tryParse(b.price) ?? 0).compareTo(int.tryParse(a.price) ?? 0));
          } else if (_selectedFilter == 'Top Rated') {
            displayedServices.sort((a, b) => b.rating.compareTo(a.rating));
          }

          return SafeArea(
            child: Column(
              children: [
                // 🔍 Search & Filter Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: CompositedTransformTarget(
                          link: _searchLayerLink,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade100, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => _filterBySearch(val, allServices),
                              decoration: const InputDecoration(
                                hintText: 'Search Services...',
                                hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                                prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey.shade100, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.tune, color: textPrimary, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🏷️ Dynamic Category Chips
                ref.watch(categoriesProvider).when(
                  data: (categories) => Container(
                    height: 45,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) {
                        final categoryName = index == 0 ? 'All' : categories[index - 1].name;
                        final isSelected = _selectedCategory == categoryName;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              if (categoryName != 'All') {
                                final currentCategory = categories.firstWhere(
                                  (c) => c.name == categoryName,
                                  orElse: () => CategoryModel(id: '', name: '', iconUrl: '', fallbackIcon: Icons.category, status: 'active'),
                                );

                                if (currentCategory.status.toLowerCase() == 'inactive' || 
                                    currentCategory.status.toLowerCase() == 'deactivated') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: Row(
                                        children: [
                                          const Icon(Icons.info_outline, color: Color(0xFF2029C5)),
                                          const SizedBox(width: 10),
                                          const Text('Category Unavailable'),
                                        ],
                                      ),
                                      content: Text(
                                        'The "$categoryName" category is temporarily deactivated for maintenance. Please check back later!',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2029C5))),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }
                              }
                              setState(() => _selectedCategory = categoryName);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2029C5) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2029C5) : Colors.grey.shade100,
                                  width: 1.5,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: const Color(0xFF2029C5).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ] : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  categoryName,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  loading: () => Container(
                    height: 45,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildSkeletonContainer(height: 45, width: 80, borderRadius: 14),
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // 📋 Services List
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF2029C5),
                    backgroundColor: Colors.white,
                    onRefresh: () async {
                      // ignore: unused_result
                      ref.refresh(servicesProvider);
                      // ignore: unused_result
                      ref.refresh(categoriesProvider);
                      await Future.delayed(const Duration(milliseconds: 1000));
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                      double horizontalPadding = constraints.maxWidth > 600 ? 40.0 : 20.0;
                      
                      if (displayedServices.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
                                _selectedCategory.toLowerCase() == 'all' 
                                  ? 'We are working on adding exciting services for you. Stay tuned!'
                                  : 'We are working on adding exciting $_selectedCategory services for you. Stay tuned!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      int crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
                      double childAspectRatio = constraints.maxWidth > 700 ? 0.95 : 0.85;

                      if (crossAxisCount == 1) {
                        return ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                          itemCount: displayedServices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 20),
                          itemBuilder: (context, index) {
                            return _buildServiceCard(context, displayedServices[index]);
                          },
                        );
                      }

                      return GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: displayedServices.length,
                        itemBuilder: (context, index) {
                          return _buildServiceCard(context, displayedServices[index]);
                        },
                      );
                    },
                  ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSkeletonContainer(height: 50, width: double.infinity, borderRadius: 15),
                    ),
                    const SizedBox(width: 15),
                    _buildSkeletonContainer(height: 50, width: 50, borderRadius: 15),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: 3,
                  separatorBuilder: (context, index) => const SizedBox(height: 20),
                  itemBuilder: (context, index) => _buildSkeletonCard(),
                ),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSkeletonContainer({
    required double height,
    required double width,
    required double borderRadius,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
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
                    Colors.grey.shade100,
                    Colors.grey.shade50,
                    Colors.grey.shade100,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonContainer(height: 180, width: double.infinity, borderRadius: 20),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSkeletonContainer(height: 12, width: 60, borderRadius: 4),
                    _buildSkeletonContainer(height: 12, width: 50, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSkeletonContainer(height: 14, width: 100, borderRadius: 4),
                const SizedBox(height: 12),
                _buildSkeletonContainer(height: 18, width: 180, borderRadius: 4),
                const SizedBox(height: 8),
                _buildSkeletonContainer(height: 12, width: 220, borderRadius: 4),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSkeletonContainer(height: 25, width: 80, borderRadius: 4),
                    _buildSkeletonContainer(height: 40, width: 90, borderRadius: 25),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, ServiceModel service) {
    return PopularServiceCard(
      service: service,
      width: double.infinity,
      margin: EdgeInsets.zero,
    );
  }
}
