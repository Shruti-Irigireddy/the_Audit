import 'package:flutter/material.dart';

import 'package:the_audit/core/utils/theme.dart';

class NavBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBack;
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
      backgroundColor: AppColors.deepBlue,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: AppColors.snowWhite),
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
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.snowWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (showProfileButton)
                GestureDetector(
                  onTap: onProfileTap,
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

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
