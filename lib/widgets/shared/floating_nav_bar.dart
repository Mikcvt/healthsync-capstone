import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';

/// One destination in [FloatingNavBar].
class NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Renders the signed-in user's initials instead of an icon.
  final bool isAvatar;

  /// Shows an unread count badge, as the alerts tab does.
  final int badgeCount;

  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isAvatar = false,
    this.badgeCount = 0,
  });
}

/// A floating pill navigation bar.
///
/// Sits above the content rather than occupying a fixed strip, so the list
/// behind it keeps its full height. Callers must add bottom padding to their
/// scroll views ([FloatingNavBar.contentPadding]) or the last row hides beneath
/// it.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavDestination> destinations;

  /// Tint for the selected pill — blue for patients, green for caregivers.
  final Color accent;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
    required this.accent,
  });

  /// Bottom inset a scrolling child needs so its last item clears the bar.
  static const double contentPadding = 104;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            // Light, as the app was before: the floating shape is the change,
            // not the palette.
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppColors.borderGray),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(destinations.length, (index) {
              return _NavItem(
                destination: destinations[index],
                selected: index == currentIndex,
                accent: accent,
                onTap: () => onTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavDestination destination;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = destination.isAvatar
        ? _Avatar(selected: selected, accent: accent)
        : Icon(
            selected ? destination.activeIcon : destination.icon,
            size: 25,
            color: selected ? accent : AppColors.textSecondary,
          );

    return Expanded(
      child: Semantics(
        label: destination.label,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                // The selected pill, as in the reference: a lighter capsule
                // behind the active icon rather than a colour change alone.
                color: selected
                    ? accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(23),
              ),
              child: Center(
                child: destination.badgeCount > 0
                    ? _Badged(count: destination.badgeCount, child: child)
                    : child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The unread count, positioned like a notification badge.
class _Badged extends StatelessWidget {
  final int count;
  final Widget child;

  const _Badged({required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -3,
          right: -7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
            constraints: const BoxConstraints(minWidth: 15),
            decoration: BoxDecoration(
              color: AppColors.missedRed,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.cardWhite, width: 1.5),
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The profile tab: the user's initials rather than a generic person icon, so
/// a caregiver managing several accounts can see at a glance who is signed in.
class _Avatar extends StatelessWidget {
  final bool selected;
  final Color accent;

  const _Avatar({required this.selected, required this.accent});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUserModel;
    final initials = _initialsOf(user?.fullName ?? '');

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static String _initialsOf(String name) {
    final parts = name.split(' ').where((p) => p.trim().isNotEmpty).take(2);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).join();
  }
}
