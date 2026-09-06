import 'package:flutter/material.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/utils/initials_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InitialsAvatarWidget / CircularAvatarWidget
// ─────────────────────────────────────────────────────────────────────────────

/// A clean, circular avatar that renders dynamic user initials using [InitialsHelper].
///
/// Rules:
/// - "Hrushikesh Bhoir" → "HB"
/// - "Priya Sharma" → "PS"
/// - "Rahul" → "R"
/// - "A B" → "AB"
/// - Fallback to "U" if name is null, empty, or whitespace-only.
///
/// Supports an optional [badge] (e.g. an online-indicator dot) overlaid
/// at the bottom-right corner.
///
/// ```dart
/// InitialsAvatarWidget(name: 'Hrushikesh Bhoir', radius: 24)
/// ```
class CircularAvatarWidget extends StatelessWidget {
  const CircularAvatarWidget({
    super.key,
    this.name,
    this.radius = 24.0,
    this.badge,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
    this.onTap,
  });

  /// The user's name used to generate initials.
  final String? name;

  /// Avatar radius (default 24 dp).
  final double radius;

  /// Small widget overlaid at the bottom-right corner (e.g., status dot).
  final Widget? badge;

  /// Avatar background colour — defaults to `colorScheme.primaryContainer`.
  final Color? backgroundColor;

  /// Initials colour — defaults to `colorScheme.onPrimaryContainer`.
  final Color? foregroundColor;

  /// Optional custom text style for initials.
  final TextStyle? textStyle;

  /// Optional tap callback.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = backgroundColor ?? cs.primaryContainer;
    final Color fg = foregroundColor ?? cs.onPrimaryContainer;

    final String initials = InitialsHelper.getInitials(name);

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initials,
        style: textStyle ??
            AppTextStyles.titleMedium.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.65,
            ),
      ),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    if (badge == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: badge!,
        ),
      ],
    );
  }
}

/// Type alias allowing both `InitialsAvatarWidget` and `CircularAvatarWidget`
/// to be used interchangeably across the app.
typedef InitialsAvatarWidget = CircularAvatarWidget;
