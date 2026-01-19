import 'package:flutter/material.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class LogoCard extends StatelessWidget {
  final double width;
  final double height;
  const LogoCard({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.colored(AppColors.primary),
      ),
      child: Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: width * 0.55,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
