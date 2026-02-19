import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class NavigationItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final int badgeCount;
  const NavigationItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

class ResponsiveScaffold extends StatelessWidget {
  final List<NavigationItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final Widget body;

  const ResponsiveScaffold({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1024) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSideNav(
              tabs: tabs,
              currentIndex: currentIndex,
              onTabSelected: onTabSelected,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    if (width >= 768) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onTabSelected,
              labelType: NavigationRailLabelType.none,
              destinations: _buildRailDestinations(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTabSelected,
        destinations: _buildBarDestinations(),
      ),
    );
  }

  Widget _badgeIcon(NavigationItem t, {bool selected = false}) {
    final icon = selected && t.selectedIcon != null ? t.selectedIcon! : t.icon;
    if (t.badgeCount > 0) {
      return Badge(
        label: Text('${t.badgeCount}'),
        child: Icon(icon),
      );
    }
    return Icon(icon);
  }

  List<NavigationRailDestination> _buildRailDestinations() {
    return tabs.map((t) {
      return NavigationRailDestination(
        icon: _badgeIcon(t),
        selectedIcon: _badgeIcon(t, selected: true),
        label: Text(t.label),
      );
    }).toList();
  }

  List<NavigationDestination> _buildBarDestinations() {
    return tabs.map((t) {
      return NavigationDestination(
        icon: _badgeIcon(t),
        selectedIcon: _badgeIcon(t, selected: true),
        label: t.label,
      );
    }).toList();
  }
}

/// Custom desktop side navigation with prominent active item styling.
class _DesktopSideNav extends StatelessWidget {
  final List<NavigationItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const _DesktopSideNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: BorderDirectional(
          start: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // App branding
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'مواعيد',
                  style: TextStyle(
                    fontFamily: 'ReadexPro',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Nav items
          ...tabs.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            final isSelected = i == currentIndex;
            return _NavItem(
              icon: isSelected && t.selectedIcon != null ? t.selectedIcon! : t.icon,
              label: t.label,
              isSelected: isSelected,
              badgeCount: t.badgeCount,
              onTap: () => onTabSelected(i),
            );
          }),
          const Spacer(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : _hovering
                      ? AppColors.primary.withValues(alpha: 0.04)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              children: [
                // Active indicator bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 3,
                  height: isSelected ? 24 : 0,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: isSelected ? 10 : 13),
                // Icon with optional badge
                _buildIcon(),
                const SizedBox(width: 12),
                // Label
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'ReadexPro',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final icon = Icon(
      widget.icon,
      size: 22,
      color: widget.isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
    );

    if (widget.badgeCount > 0) {
      return Badge(
        label: Text('${widget.badgeCount}'),
        child: icon,
      );
    }
    return icon;
  }
}
