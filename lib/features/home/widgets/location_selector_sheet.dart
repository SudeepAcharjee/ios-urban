import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../views/add_address_screen.dart';
import '../providers/address_provider.dart';
import '../../../../core/services/location_service.dart';

class LocationSelectorSheet extends ConsumerStatefulWidget {
  const LocationSelectorSheet({super.key});

  @override
  ConsumerState<LocationSelectorSheet> createState() => _LocationSelectorSheetState();
}

class _LocationSelectorSheetState extends ConsumerState<LocationSelectorSheet> {
  static const primaryColor = Color(0xFF2029C5);

  late final TextEditingController locationSearchController;
  Timer? debounceTimer;
  List<Map<String, dynamic>> searchResults = [];
  bool isSearchingLocation = false;
  bool isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    locationSearchController = TextEditingController();
  }

  @override
  void dispose() {
    locationSearchController.dispose();
    debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Location',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: locationSearchController,
                    onChanged: (value) {
                      if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();
                      debounceTimer = Timer(const Duration(milliseconds: 500), () async {
                        if (value.trim().isEmpty) {
                          if (mounted) {
                            setState(() {
                              searchResults = [];
                              isSearchingLocation = false;
                            });
                          }
                          return;
                        }
                        if (mounted) {
                          setState(() {
                            isSearchingLocation = true;
                          });
                        }
                        final results = await LocationService.searchLocations(value);
                        if (mounted) {
                          setState(() {
                            searchResults = results;
                            isSearchingLocation = false;
                          });
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search for area, street name...',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                      icon: const Icon(
                        Icons.search_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                      suffixIcon: locationSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                              onPressed: () {
                                locationSearchController.clear();
                                if (mounted) {
                                  setState(() {
                                    searchResults = [];
                                    isSearchingLocation = false;
                                  });
                                }
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: isSearchingLocation
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: primaryColor,
                        ),
                      ),
                    )
                  : locationSearchController.text.isNotEmpty
                      ? searchResults.isEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.location_off_rounded,
                                    size: 48,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No locations found',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SEARCH RESULTS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF9CA3AF),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...searchResults.map((result) {
                                  return _buildLocationOption(
                                    icon: Icons.location_on_rounded,
                                    title: result['displayAddress'],
                                    subtitle: 'Tap to select location',
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.bookmark_add_outlined,
                                        color: primaryColor,
                                        size: 24,
                                      ),
                                      onPressed: () {
                                        _showSaveAddressDialog(context, result);
                                      },
                                    ),
                                    onTap: () async {
                                      await ref
                                          .read(authViewModelProvider.notifier)
                                          .updateProfile({
                                        'location': result['displayAddress'],
                                        'latitude': result['latitude'],
                                        'longitude': result['longitude'],
                                      });
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  );
                                }).toList(),
                              ],
                            )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLocationOption(
                              icon: isLoadingLocation
                                  ? Icons.hourglass_empty
                                  : Icons.my_location_rounded,
                              title: isLoadingLocation
                                  ? 'Fetching Location...'
                                  : 'Use Current Location',
                              subtitle: isLoadingLocation
                                  ? 'Please wait a moment'
                                  : 'Enable location for better accuracy',
                              color: primaryColor,
                              trailing: isLoadingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: primaryColor,
                                      ),
                                    )
                                  : null,
                              onTap: isLoadingLocation
                                  ? () {}
                                  : () async {
                                      if (mounted) {
                                        setState(() => isLoadingLocation = true);
                                      }
                                      try {
                                        final position = await LocationService.getCurrentPosition();
                                        if (position != null) {
                                          final address = await LocationService.getAddressFromLatLng(position);
                                          if (address != null) {
                                            await ref
                                                .read(authViewModelProvider.notifier)
                                                .updateProfile({
                                              'location': address,
                                              'latitude': position.latitude,
                                              'longitude': position.longitude,
                                            });
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                            }
                                            return;
                                          }
                                        }
                                        throw 'Could not retrieve location. Please try again.';
                                      } catch (e) {
                                        if (context.mounted) {
                                          if (mounted) {
                                            setState(() => isLoadingLocation = false);
                                          }
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                              backgroundColor: Colors.redAccent,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (context.mounted && isLoadingLocation) {
                                          if (mounted) {
                                            setState(() => isLoadingLocation = false);
                                          }
                                        }
                                      }
                                    },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              child: Divider(color: Color(0xFFF3F4F6)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'SAVED ADDRESSES',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF9CA3AF),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AddAddressScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    '+ Add New',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ref.watch(addressesProvider).when(
                              data: (addresses) {
                                if (addresses.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 30),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.location_off_rounded,
                                          size: 48,
                                          color: Colors.grey[300],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No saved addresses yet',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return Column(
                                  children: addresses.map((addr) {
                                    final String houseNumber = addr['houseNumber'] ?? '';
                                    final String streetAddress = addr['address'] ?? '';
                                    final String displayAddress = houseNumber.isNotEmpty
                                        ? '$houseNumber, $streetAddress'
                                        : streetAddress;

                                    return _buildLocationOption(
                                      icon: addr['type'] == 'Home'
                                          ? Icons.home_rounded
                                          : addr['type'] == 'Work'
                                              ? Icons.work_rounded
                                              : Icons.location_on_rounded,
                                      title: addr['type'] ?? 'Address',
                                      subtitle: displayAddress,
                                      onTap: () {
                                        ref
                                            .read(authViewModelProvider.notifier)
                                            .updateProfile({
                                          'location': displayAddress,
                                          'latitude': addr['latitude'],
                                          'longitude': addr['longitude'],
                                        });
                                        Navigator.pop(context);
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(30.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              error: (err, stack) => Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  'Error loading addresses',
                                  style: TextStyle(color: Colors.red[400]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSaveAddressDialog(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => _SaveAddressDialog(result: result),
    );
  }

  Widget _buildLocationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (color ?? const Color(0xFFE5E7EB)).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color ?? const Color(0xFF4B5563),
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

class _SaveAddressDialog extends StatefulWidget {
  final Map<String, dynamic> result;
  const _SaveAddressDialog({required this.result});

  @override
  State<_SaveAddressDialog> createState() => _SaveAddressDialogState();
}

class _SaveAddressDialogState extends State<_SaveAddressDialog> {
  static const primaryColor = Color(0xFF2029C5);
  String selectedType = 'Home';
  late final TextEditingController otherLabelController;
  late final TextEditingController houseNumberController;
  bool isSavingAddress = false;

  @override
  void initState() {
    super.initState();
    otherLabelController = TextEditingController();
    houseNumberController = TextEditingController(text: widget.result['houseNumber']);
  }

  @override
  void dispose() {
    otherLabelController.dispose();
    houseNumberController.dispose();
    super.dispose();
  }

  Widget _buildDialogTypeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogTextFieldReadOnly(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.bookmark_add_rounded, color: primaryColor),
          SizedBox(width: 10),
          Text('Save Address', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Address Label',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildDialogTypeChip(
                  label: 'Home',
                  icon: Icons.home_rounded,
                  isSelected: selectedType == 'Home',
                  onTap: () => setState(() => selectedType = 'Home'),
                ),
                const SizedBox(width: 10),
                _buildDialogTypeChip(
                  label: 'Work',
                  icon: Icons.work_rounded,
                  isSelected: selectedType == 'Work',
                  onTap: () => setState(() => selectedType == 'Work'),
                ),
                const SizedBox(width: 10),
                _buildDialogTypeChip(
                  label: 'Other',
                  icon: Icons.location_on_rounded,
                  isSelected: selectedType == 'Other',
                  onTap: () => setState(() => selectedType == 'Other'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (selectedType == 'Other') ...[
              _buildDialogTextField('Custom Label', 'e.g. Apartment, Gym', otherLabelController),
              const SizedBox(height: 15),
            ],
            if (selectedType != 'Work') ...[
              _buildDialogTextField('House / Flat / Block No.', 'e.g. 123/A', houseNumberController),
              const SizedBox(height: 15),
            ],
            _buildDialogTextFieldReadOnly('Address', widget.result['address'] ?? widget.result['displayAddress']),
          ],
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isSavingAddress
              ? null
              : () async {
                  setState(() => isSavingAddress = true);
                  try {
                    final addressData = {
                      'type': selectedType == 'Other'
                          ? (otherLabelController.text.trim().isNotEmpty
                              ? otherLabelController.text.trim()
                              : 'Other')
                          : selectedType,
                      'houseNumber': houseNumberController.text.trim(),
                      'address': widget.result['address'] ?? widget.result['displayAddress'],
                      'city': widget.result['city'] ?? '',
                      'state': widget.result['state'] ?? '',
                      'zip': widget.result['zip'] ?? '',
                      'latitude': widget.result['latitude'],
                      'longitude': widget.result['longitude'],
                    };
                    await AddressService.addAddress(addressData);
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      toastification.show(
                        context: context,
                        type: ToastificationType.success,
                        style: ToastificationStyle.flatColored,
                        title: const Text('Address saved successfully!'),
                        autoCloseDuration: const Duration(seconds: 3),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        style: ToastificationStyle.flatColored,
                        title: Text('Error: $e'),
                        autoCloseDuration: const Duration(seconds: 3),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => isSavingAddress = false);
                    }
                  }
                },
          child: isSavingAddress
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
