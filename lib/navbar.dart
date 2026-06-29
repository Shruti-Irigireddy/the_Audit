import 'package:flutter/material.dart';
import 'package:the_audit/theme.dart';

class NavBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onProfileTap;
  
  const NavBar({super.key, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.deepBlue,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final logoHeight = (constraints.maxHeight * 0.6).clamp(28.0, 40.0);
          final avatarRadius = (constraints.maxHeight * 0.4).clamp(16.0, 20.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: logoHeight,
                  ),
                ],
              ),
              GestureDetector(
                onTap: onProfileTap,
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: AppColors.snowWhite,
                  child: const Icon(
                    Icons.person,
                    color: AppColors.deepBlue,
                  ),
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