// lib/Dashbaord/settings/settings.dart
import 'package:dating_app/Auth/changepassword/changepassword.dart';
import 'package:dating_app/Dashbaord/settingspages/accountsetting/accountsetting.dart';
import 'package:dating_app/Dashbaord/settingspages/billingsettings/billingsettings.dart';
import 'package:dating_app/Dashbaord/settingspages/manageyoursubscription.dart';
import 'package:dating_app/Dashbaord/settingspages/notificationsettings.dart';
import 'package:dating_app/Dashbaord/settingspages/privacypolicy/privacypolicy.dart';
import 'package:dating_app/Dashbaord/settingspages/profilesettings/profilesettings.dart';
import 'package:dating_app/Dashbaord/settingspages/suggestions/suggestionui.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../themesfolder/logout/logoutalert.dart';
import '../dashboard/Dashboard.dart';
import '../settingspages/Deactivate/deactivateaccount.dart';
import '../settingspages/deleteaccount/deleteaccount.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Image.asset('assets/the_pairup_logo_black.png', height: 80),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          _buildSettingsItem(
            context,
            icon: Icons.person_outline,
            title: "Profile Setting",
            onTap: () {
              Get.to(
                    () => const EditProfileScreen(),
                id: settingsNavId, // <— push inside Settings tab
              );
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.account_box,
            title: "Account setting",
            onTap: () {
              Get.to(
                    () => const ChangeAccountSettingScreen(),
                id: settingsNavId,
              );
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.notifications_outlined,
            title: "Notification Setting",
            onTap: () {
              Get.to(
                    () => const NotificationSettingsScreen(),
                id: settingsNavId,
              );
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.settings_suggest_outlined,
            title: "My suggestions",
            onTap: () {
              Get.to(
                    () => const SuggestionSettingsScreen(),
                id: settingsNavId,
              );
            },
          ),
          // _buildSettingsItem(
          //   context,
          //   icon: Icons.subscriptions_outlined,
          //   title: "Manage Your Subscription",
          //   onTap: () {
          //     Get.to(
          //           () => const ManageSubscriptionScreen(),
          //       id: settingsNavId,
          //     );
          //   },
          // ),
          _buildSettingsItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            onTap: () {
              Get.to(
                    () => const PrivacyPolicyScreen(),
                id: settingsNavId,
              );
            },
          ),


          _buildSettingsItem(
            context,
            icon: Icons.history_outlined,
            title: "Billing History",
            onTap: () {
              Get.to(
                    () => const BillingHistoryScreen(),
                id: settingsNavId,
              );
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.power_settings_new_outlined,
            title: "Deactivate Account",
            onTap: () {
              Get.to(
                    () => const DeactivateNumberScreen(),
                id: settingsNavId,
              );
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.delete_outline,
            title: "Delete Account",
            onTap: () {
              Get.to(
                    () => const DeleteNumberScreen(),
                id: settingsNavId,
              );
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.logout,
            title: "Logout",
            onTap: () {
              showLogoutConfirm(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          horizontalTitleGap: 10,
          minLeadingWidth: 0,
          leading: Icon(icon, color: Colors.black87, size: 18),
          title: Text(
            title,
            style: AppTheme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFF111827),
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.black45),
          onTap: onTap,
        ),
        const Divider(thickness: 0.6, height: 0, color: Colors.black12),
      ],
    );
  }
}
