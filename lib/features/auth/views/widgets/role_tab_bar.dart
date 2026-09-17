import 'package:flutter/material.dart';

enum AuthRole { user, worker, shop }

class RoleTabBar extends StatelessWidget {
  final AuthRole selectedRole;
  final ValueChanged<AuthRole> onRoleChanged;

  const RoleTabBar({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildRoleTab(
            role: AuthRole.user,
            label: 'User',
            isSelected: selectedRole == AuthRole.user,
            primaryColor: primaryColor,
          ),
          _buildRoleTab(
            role: AuthRole.worker,
            label: 'Worker',
            isSelected: selectedRole == AuthRole.worker,
            primaryColor: primaryColor,
          ),
          _buildRoleTab(
            role: AuthRole.shop,
            label: 'Shop',
            isSelected: selectedRole == AuthRole.shop,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab({
    required AuthRole role,
    required String label,
    required bool isSelected,
    required Color primaryColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onRoleChanged(role),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? primaryColor : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
