import 'package:flutter/material.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  
  final List<String> _categories = ['All', 'Booking', 'Payment', 'Services', 'Account'];
  
  final List<Map<String, String>> _faqs = [
    {
      'category': 'Booking',
      'question': 'How do I book a car wash?',
      'answer': 'You can book a car wash by selecting a service from the home screen, choosing your preferred date and time, and confirming your location.'
    },
    {
      'category': 'Payment',
      'question': 'What payment methods are accepted?',
      'answer': 'We accept all major credit/debit cards, UPI, and net banking. You can manage your payment methods in the profile section.'
    },
    {
      'category': 'Services',
      'question': 'What is included in Premium Wash?',
      'answer': 'Our Premium Wash includes exterior foam wash, tire dressing, interior vacuuming, dashboard polishing, and window cleaning.'
    },
    {
      'category': 'Account',
      'question': 'How can I change my phone number?',
      'answer': 'Go to Profile > Edit Profile to update your personal information, including your phone number and email address.'
    },
    {
      'category': 'Booking',
      'question': 'Can I cancel my booking?',
      'answer': 'Yes, you can cancel your booking up to 2 hours before the scheduled time for a full refund.'
    },
    {
      'category': 'Payment',
      'question': 'Is my payment information secure?',
      'answer': 'Absolutely. We use industry-standard encryption to protect your payment details and never store your full card information.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF64748B);

    List<Map<String, String>> filteredFaqs = _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'All' || faq['category'] == _selectedCategory;
      final matchesSearch = faq['question']!.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                            faq['answer']!.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
          ),
        ),
        title: const Text(
          'FAQ',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search for questions...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // 🏷️ Categories
          SizedBox(
            height: 45,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 📚 FAQ List
          Expanded(
            child: filteredFaqs.isEmpty
              ? _buildNoResults()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredFaqs.length,
                  itemBuilder: (context, index) {
                    final faq = filteredFaqs[index];
                    return _buildFaqItem(faq, primaryColor, textPrimary, textSecondary);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(Map<String, String> faq, Color primaryColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(
          faq['question']!,
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        trailing: Icon(Icons.add, color: primaryColor, size: 20),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            faq['answer']!,
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text(
            'No results found',
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
