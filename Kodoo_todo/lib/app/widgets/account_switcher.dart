import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/login_controller.dart';
import '../models/account_model.dart';

class AccountSwitcher extends StatelessWidget {
  final AuthController _authController = Get.find<AuthController>();

   AccountSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final accounts = _authController.savedAccounts;
      final activeAccount = _authController.activeAccount.value;

      if (accounts.isEmpty) {
        return const SizedBox.shrink();
      }

      // ✅ If only one account, show simple info card
      if (accounts.length == 1) {
        return _buildSingleAccountView(activeAccount!);
      }

      // ✅ Multiple accounts - show dropdown style
      return _buildDropdownAccountSwitcher(context, accounts, activeAccount);
    });
  }

  /// Single Account View - Clean & Simple
  Widget _buildSingleAccountView(AccountModel account) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildAccountAvatar(account, true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name ?? account.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (account.email != null && account.name != null)
                  Text(
                    account.email!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                Text(
                  account.database,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _authController.addNewAccount(),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text("Add"),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6C5B7B),
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown Account Switcher - Modern Collapsible UI
  Widget _buildDropdownAccountSwitcher(
      BuildContext context,
      List<AccountModel> accounts,
      AccountModel? activeAccount,
      ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: _buildAccountAvatar(activeAccount!, true),
          title: Text(
            activeAccount.name ?? activeAccount.username,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            activeAccount.database,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  "Active",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
            ],
          ),
          children: [
            const Divider(height: 1),

            // Other Accounts List
            ...accounts.where((acc) => acc.id != activeAccount.id).map((account) {
              return InkWell(
                onTap: () => _showSwitchConfirmation(context, account),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildAccountAvatar(account, false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name ?? account.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (account.email != null && account.name != null)
                              Text(
                                account.email!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            Text(
                              account.database,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
                        onSelected: (value) {
                          if (value == 'switch') {
                            _showSwitchConfirmation(context, account);
                          } else if (value == 'remove') {
                            _showRemoveConfirmation(context, account);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'switch',
                            child: Row(
                              children: [
                                Icon(Icons.swap_horiz, size: 18),
                                SizedBox(width: 8),
                                Text("Switch", style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text("Remove", style: TextStyle(color: Colors.red, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Add Account & Logout All Buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _authController.addNewAccount(),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text("Add Account"),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6C5B7B),
                      ),
                    ),
                  ),
                  if (accounts.length > 1)
                    TextButton.icon(
                      onPressed: () => _showLogoutAllConfirmation(context),
                      icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                      label: const Text("Logout All"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSwitchConfirmation(BuildContext context, AccountModel account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Switch Account"),
        content: Text(
          "Switch to ${account.username}?\n\n"
              "This will reload all data for this account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _authController.switchAccount(account);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5B7B),
            ),
            child: const Text(
              "Switch",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context, AccountModel account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Account"),
        content: Text(
          "Remove ${account.username} from saved accounts?\n\n"
              "You can always add it back later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _authController.removeAccount(account);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              "Remove",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout All Accounts"),
        content: const Text(
          "This will log out all saved accounts and clear all data.\n\n"
              "Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _authController.logoutAllAccounts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              "Logout All",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

// REPLACE the entire _buildAccountAvatar method with this:

  Widget _buildAccountAvatar(AccountModel account, bool isActive) {
    // ✅ Check if image exists and is valid
    if (account.image1920 != null &&
        account.image1920 != false &&
        account.image1920!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(account.image1920!);
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: MemoryImage(imageBytes),
              fit: BoxFit.cover,
            ),
            border: Border.all(
              color:  Colors.grey.shade300,
              width: 2,
            ),
          ),
        );
      } catch (e) {
        print("❌ Error decoding avatar image: $e");
        // Fall through to default avatar
      }
    }

    // ✅ Fallback: Show first letter of username
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF6C5B7B)
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? const Color(0xFF6C5B7B) : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          account.username[0].toUpperCase(),
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}