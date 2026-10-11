import 'package:flutter/material.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/widgets/offline_banner.dart';
import 'package:nari_suraksha/features/home/screens/dashboard_screen.dart';
import 'package:nari_suraksha/features/sos/screens/sos_screen.dart';
import 'package:nari_suraksha/features/emergency_contacts/screens/contacts_screen.dart';
import 'package:nari_suraksha/features/profile/screens/profile_page.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/dashboard_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';
import 'package:provider/provider.dart';

/// Home / Dashboard shell for authenticated users.
///
/// Acts as the bottom-navigation host. The first tab now hosts the
/// full [DashboardScreen]. The remaining tabs keep placeholder bodies
/// until their feature screens are implemented.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  /// Called by child screens (e.g. SosScreen) to switch the active tab.
  void switchToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    // Subscribe ContactProvider and DashboardProvider alerts on mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<UserProvider>().currentUid;
      if (uid != null) {
        context.read<ContactProvider>().subscribe(uid);
        context.read<DashboardProvider>().refreshAlerts(uid);
      }
    });
  }

  static const List<_TabItem> _tabs = [
    _TabItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _TabItem(
      label: 'SOS',
      icon: Icons.gpp_maybe_outlined,
      activeIcon: Icons.gpp_maybe_rounded,
    ),
    _TabItem(
      label: 'Contacts',
      icon: Icons.people_outline,
      activeIcon: Icons.people_rounded,
    ),
    _TabItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Offline mode indicator (slides in/out when connectivity changes) ──
          const OfflineBanner(),
          // ── Tab content ─────────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                // Tab 0 — Dashboard
                const DashboardScreen(),
                // Tab 1 — SOS screen (passes onSosSuccess to return to Dashboard)
                SosScreen(onSosSuccess: () => switchToTab(0)),
                // Tab 2 — Emergency contacts
                const ContactsScreen(),
                // Tab 3 — Profile
                const ProfilePage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryContainer,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: Icon(_tabs[0].icon),
            selectedIcon: Icon(_tabs[0].activeIcon, color: AppColors.primary),
            label: _tabs[0].label,
          ),
          // SOS tab gets a distinct red colour to signal urgency
          NavigationDestination(
            icon: const Icon(Icons.gpp_maybe_outlined,
                color: Color(0xFFEF4444)),
            selectedIcon: const Icon(Icons.gpp_maybe_rounded,
                color: Color(0xFFEF4444)),
            label: _tabs[1].label,
          ),
          NavigationDestination(
            icon: Icon(_tabs[2].icon),
            selectedIcon: Icon(_tabs[2].activeIcon, color: AppColors.primary),
            label: _tabs[2].label,
          ),
          NavigationDestination(
            icon: Icon(_tabs[3].icon),
            selectedIcon: Icon(_tabs[3].activeIcon, color: AppColors.primary),
            label: _tabs[3].label,
          ),
        ],
      ),
    );
  }
}

// ── Private helpers ──────────────────────────────────────────────────────────

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
