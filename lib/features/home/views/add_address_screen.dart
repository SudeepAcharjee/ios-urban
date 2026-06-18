import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/address_provider.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  final String title;
  final bool showAddedAddressesFirst;

  const AddAddressScreen({
    super.key,
    this.title = 'Add New Address',
    this.showAddedAddressesFirst = false,
  });

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  String _selectedType = 'Home';
  final TextEditingController _otherLabelController = TextEditingController();
  final TextEditingController _houseNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  late bool _isAddingNew;
  bool _isSaving = false;
  int _selectedAddressIndex = 0;
  String? _editingAddressId;

  @override
  void initState() {
    super.initState();
    _isAddingNew = !widget.showAddedAddressesFirst;
  }

  @override
  void dispose() {
    _otherLabelController.dispose();
    _houseNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    const textPrimary = Color(0xFF111827);
    const backgroundColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            final addrAsync = ref.read(addressesProvider);
            final hasAddresses = addrAsync.maybeWhen(
              data: (list) => list.isNotEmpty,
              orElse: () => false,
            );

            if (_isAddingNew && hasAddresses) {
              setState(() {
                _isAddingNew = false;
                _editingAddressId = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 16),
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isAddingNew) ...[
                      const Text(
                        'Address Label',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _buildTypeChip('Home', Icons.home_rounded),
                          const SizedBox(width: 12),
                          _buildTypeChip('Work', Icons.work_rounded),
                          const SizedBox(width: 12),
                          _buildTypeChip('Other', Icons.location_on_rounded),
                        ],
                      ),
                      const SizedBox(height: 30),

                      if (_selectedType == 'Other') ...[
                        _buildTextField('Custom Label', 'e.g. Home 2, Office 2', _otherLabelController),
                        const SizedBox(height: 20),
                      ],
                      
                      if (_selectedType != 'Work') ...[
                        _buildTextField('House number', '123/A', _houseNumberController),
                        const SizedBox(height: 20),
                      ],
                      _buildTextField('Full Address', 'Street name, Apartment, Suite', _addressController),
                      const SizedBox(height: 20),
                      _buildTextField('City', 'Guwahati', _cityController),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('State', 'Assam', _stateController)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildTextField('Zip Code', '781111', _zipController)),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ] else ...[
                      ref.watch(addressesProvider).when(
                        loading: () => const Center(child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(),
                        )),
                        error: (err, stack) => Center(child: Text('Error: $err')),
                        data: (addresses) {
                          if (addresses.isNotEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recently Saved Addresses',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                const SizedBox(height: 20),
                                ...addresses.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final addr = entry.value;
                                  return _buildAddedAddressItem(addr, index, primaryColor);
                                }).toList(),
                              ],
                            );
                          } else {
                            return Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 100),
                                  Icon(Icons.location_off_outlined, size: 80, color: Colors.grey.shade300),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'No addresses saved yet',
                                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 🔘 Bottom Button Area
            Padding(
              padding: const EdgeInsets.all(25),
              child: _isAddingNew 
                ? SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () async {
                        if (_addressController.text.isNotEmpty && _cityController.text.isNotEmpty) {
                          try {
                            setState(() => _isSaving = true);
                            double? lat;
                            double? lng;
                            try {
                              final query = '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_stateController.text.trim()}';
                              final locations = await locationFromAddress(query);
                              if (locations.isNotEmpty) {
                                lat = locations.first.latitude;
                                lng = locations.first.longitude;
                              }
                            } catch (_) {
                              try {
                                final queryFallback = '${_addressController.text.trim()}, ${_cityController.text.trim()}';
                                final locationsFallback = await locationFromAddress(queryFallback);
                                if (locationsFallback.isNotEmpty) {
                                  lat = locationsFallback.first.latitude;
                                  lng = locationsFallback.first.longitude;
                                }
                              } catch (_) {}
                            }

                            final addressData = {
                              'type': _selectedType == 'Other' ? (_otherLabelController.text.trim().isNotEmpty ? _otherLabelController.text.trim() : 'Other') : _selectedType,
                              'houseNumber': _houseNumberController.text.trim(),
                              'address': _addressController.text.trim(),
                              'city': _cityController.text.trim(),
                              'state': _stateController.text.trim(),
                              'zip': _zipController.text.trim(),
                              'latitude': lat,
                              'longitude': lng,
                            };

                            if (_editingAddressId != null) {
                              await AddressService.updateAddress(_editingAddressId!, addressData);
                            } else {
                              await AddressService.addAddress(addressData);
                            }
                            
                            if (mounted) {
                              setState(() {
                                _isAddingNew = false;
                                _isSaving = false;
                                _editingAddressId = null;
                                _houseNumberController.clear();
                                _otherLabelController.clear();
                                _addressController.clear();
                                _cityController.clear();
                                _stateController.clear();
                                _zipController.clear();
                              });
                              
                              toastification.show(
                                context: context,
                                type: ToastificationType.success,
                                style: ToastificationStyle.flatColored,
                                title: Text(_editingAddressId == null ? 'Address Saved Successfully' : 'Address Updated Successfully'),
                                autoCloseDuration: const Duration(seconds: 3),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isSaving = false);
                              toastification.show(
                                context: context,
                                type: ToastificationType.error,
                                style: ToastificationStyle.flatColored,
                                title: Text('Error: $e'),
                                autoCloseDuration: const Duration(seconds: 3),
                              );
                            }
                          }
                        } else {
                          toastification.show(
                            context: context,
                            type: ToastificationType.warning,
                            style: ToastificationStyle.flatColored,
                            title: const Text('Please enter valid address details'),
                            autoCloseDuration: const Duration(seconds: 3),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        disabledBackgroundColor: primaryColor.withOpacity(0.7),
                      ),
                      child: _isSaving 
                        ? const SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(_editingAddressId != null ? 'Update Address' : 'Save Address', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() {
                        _isAddingNew = true;
                        _editingAddressId = null;
                      }),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 22),
                      label: const Text('Add New Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddedAddressItem(Map<String, dynamic> addr, int index, Color themeColor) {
    IconData icon = Icons.home_rounded;
    if (addr['type'] == 'Work') icon = Icons.work_rounded;
    if (addr['type'] == 'Other') icon = Icons.location_on_rounded;

    final isSelected = _selectedAddressIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedAddressIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey.shade100,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: themeColor, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            addr['type']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${addr['houseNumber'] != null && addr['houseNumber'].toString().isNotEmpty ? '${addr['houseNumber']}, ' : ''}${addr['address']!}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const SizedBox(width: 51), // Align with text
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAddingNew = true;
                      _editingAddressId = addr['id'];
                      final type = addr['type'] ?? 'Home';
                      if (type == 'Home' || type == 'Work') {
                        _selectedType = type;
                        _otherLabelController.clear();
                      } else {
                        _selectedType = 'Other';
                        _otherLabelController.text = type;
                      }
                      _houseNumberController.text = addr['houseNumber'] ?? '';
                      _addressController.text = addr['address']!;
                      _cityController.text = addr['city']!;
                      _stateController.text = addr['state'] ?? '';
                      _zipController.text = addr['zip'] ?? '';
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(color: Color(0xFF2029C5), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () async {
                    final addressId = addr['id'];
                    if (addressId != null) {
                      await AddressService.deleteAddress(addressId);
                      if (mounted) {
                        toastification.show(
                          context: context,
                          type: ToastificationType.info,
                          style: ToastificationStyle.flatColored,
                          title: const Text('Address Deleted'),
                          autoCloseDuration: const Duration(seconds: 2),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    const primaryColor = Color(0xFF2029C5);
    final isSelected = _selectedType == label;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedType = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2029C5), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ],
    );
  }
}
