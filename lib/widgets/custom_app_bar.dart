import 'package:flutter/material.dart';
import 'package:pulchowkx_app/cards/logo.dart';
import 'package:pulchowkx_app/pages/home_page.dart';
import 'package:pulchowkx_app/pages/clubs.dart';
import 'package:pulchowkx_app/pages/dashboard.dart';
import 'package:pulchowkx_app/pages/events.dart';
import 'package:pulchowkx_app/pages/map.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isHomePage;

  const CustomAppBar({super.key, this.isHomePage = false});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.shade200, height: 1),
      ),
      titleSpacing: 6,
      title: InkWell(
        onTap: () {
          if (isHomePage) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              const LogoCard(width: 35, height: 35),

              const SizedBox(width: 5),
              // Brand Name
              const Text(
                'PulchowkX',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _NavBarItem(
          title: 'Clubs',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClubsPage()),
            );
          },
        ),
        _NavBarItem(
          title: 'Events',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EventsPage()),
            );
          },
        ),
        _NavBarItem(
          title: 'Map',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MapPage()),
            );
          },
        ),
        _NavBarItem(
          title: 'Dashboard',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
            );
          },
        ),
      ],
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NavBarItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF374151),
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
