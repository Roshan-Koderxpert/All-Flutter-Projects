import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_main_app_bar.dart';
import 'profile_tab_view.dart';
import '../../../core/utils/responsive.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppMainAppBar(title: 'Account & Settings'),
      body: ResponsiveBody(child: ProfileTabView()),
    );
  }
}
