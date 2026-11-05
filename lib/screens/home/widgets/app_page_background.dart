import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDCEFE4), Color(0xFFEAF4ED)],
            ),
          ),
        ),
        Positioned(
          top: -145,
          right: -115,
          child: Container(
            width: 430,
            height: 430,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryGreen.withValues(alpha: 0.16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.22),
                  blurRadius: 110,
                  spreadRadius: 55,
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
