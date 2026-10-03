import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/profile/presentation/profile_page.dart';

const _log = AppLogger('NavBar');

class NavBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  /// Overrides the profile button. By default it opens the Profile page
  /// from whatever page the NavBar is on.
  final VoidCallback? onProfileTap;
  final bool showProfileButton;
  final String title;

  const NavBar({
    super.key,
    this.showBackButton = false,
    this.onBack,
    this.onProfileTap,
    this.showProfileButton = true,
    this.title = 'The Audit',
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              onPressed: () {
                _log.d('back tapped');
                if (onBack != null) {
                  onBack!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
            )
          : null,
      titleSpacing: showBackButton ? 0 : NavigationToolbar.kMiddleSpacing,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final logoHeight = (constraints.maxHeight * 0.6).clamp(24.0, 36.0);
          final avatarRadius = (constraints.maxHeight * 0.4).clamp(16.0, 20.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    color: AppColors.snowWhite,
                    size: logoHeight,
                  ),
                  const SizedBox(width: 8),
                  Text(title, style: AppTextStyles.navTitle),
                ],
              ),
              if (showProfileButton)
                GestureDetector(
                  onTap: () {
                    _log.d('profile tapped');
                    if (onProfileTap != null) {
                      onProfileTap!();
                    } else {
                      _openProfile(context);
                    }
                  },
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: AppColors.snowWhite,
                    child: const Icon(Icons.person, color: AppColors.deepBlue),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Profile'),
        builder: (_) => ProfilePage(
          database: context.read<AppDatabase>(),
          authCubit: context.read<AuthCubit>(),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
