import 'dart:math' as math;

import 'package:flutter/material.dart';

class FolderTab {
  const FolderTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Tab bar whose selected tab is filled with [color] and flows into a panel
/// of the same colour (like a folder tab), with curved inner corners.
///
/// Place [FolderTabPanel] directly below it with the same [color].
class FolderTabBar extends StatelessWidget {
  const FolderTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.color,
    required this.selectedForeground,
    required this.unselectedForeground,
    this.height = 52,
    this.radius = 18,
  });

  final List<FolderTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color color;
  final Color selectedForeground;
  final Color unselectedForeground;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selectedIndex.toDouble()),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        builder: (context, position, child) => CustomPaint(
          painter: _FolderTabPainter(
            position: position,
            count: tabs.length,
            color: color,
            radius: radius,
          ),
          child: child,
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) Expanded(child: _buildTab(i)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final tab = tabs[index];
    final selected = index == selectedIndex;
    final foreground = selected ? selectedForeground : unselectedForeground;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => onSelected(index),
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: foreground,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 20, color: foreground),
              const SizedBox(width: 6),
              Flexible(child: Text(tab.label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderTabPainter extends CustomPainter {
  _FolderTabPainter({
    required this.position,
    required this.count,
    required this.color,
    required this.radius,
  });

  /// Selected tab index; fractional while animating between tabs.
  final double position;
  final int count;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final tabWidth = size.width / count;
    final left = position * tabWidth;
    final right = left + tabWidth;
    final h = size.height;
    final r = math.min(radius, h / 2);
    // Inner (concave) corners shrink to nothing at the bar's edges.
    final flareLeft = math.min(r, left);
    final flareRight = math.min(r, size.width - right);

    final path = Path()
      ..moveTo(left - flareLeft, h)
      ..quadraticBezierTo(left, h, left, h - flareLeft)
      ..lineTo(left, r)
      ..arcToPoint(Offset(left + r, 0), radius: Radius.circular(r))
      ..lineTo(right - r, 0)
      ..arcToPoint(Offset(right, r), radius: Radius.circular(r))
      ..lineTo(right, h - flareRight)
      ..quadraticBezierTo(right, h, right + flareRight, h)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FolderTabPainter old) =>
      old.position != position ||
      old.count != count ||
      old.color != color ||
      old.radius != radius;
}

/// The content area under a [FolderTabBar]. The top corner under the
/// selected tab is square so the tab and panel join seamlessly.
class FolderTabPanel extends StatelessWidget {
  const FolderTabPanel({
    super.key,
    required this.selectedIndex,
    required this.tabCount,
    required this.color,
    required this.child,
    this.radius = 18,
  });

  final int selectedIndex;
  final int tabCount;
  final Color color;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final corner = Radius.circular(radius);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: selectedIndex == 0 ? Radius.zero : corner,
          topRight: selectedIndex == tabCount - 1 ? Radius.zero : corner,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
