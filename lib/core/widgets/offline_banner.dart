import 'package:flutter/material.dart';
import 'package:nari_suraksha/providers/connectivity_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OfflineBanner
// ─────────────────────────────────────────────────────────────────────────────

/// Compact animated banner shown at the top of the screen when offline.
///
/// - Reads [ConnectivityProvider.isOffline] automatically.
/// - Slides in/out smoothly when connectivity changes.
/// - NEVER prevents SOS access — pure informational UI.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOffline = context.select<ConnectivityProvider, bool>(
      (p) => p.isOffline,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: isOffline
          ? const _BannerContent(key: ValueKey('offline_banner'))
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB45309), Color(0xFFD97706)],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Offline Mode — Emergency SMS still available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
