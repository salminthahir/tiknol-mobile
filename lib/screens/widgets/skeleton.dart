import 'package:flutter/material.dart';

/// Reusable skeleton loading widget with shimmer effect.
/// Use [SkeletonCard] for card-like content and [SkeletonList] for list items.
///
/// Set [isDark] to true for dark-themed skeletons (e.g., POS, Kitchen).
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;
  final bool isDark;

  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.margin = EdgeInsets.zero,
    this.isDark = false,
  });

  const Skeleton.circle({
    super.key,
    required double size,
    this.margin = EdgeInsets.zero,
    this.isDark = false,
  })  : width = size,
        height = size,
        borderRadius = 1000;

  const Skeleton.text({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.margin = EdgeInsets.zero,
    this.isDark = false,
  }) : borderRadius = 4;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _colorAnimation = ColorTween(
      begin: widget.isDark ? const Color(0xFF2C2C35) : const Color(0xFFE8E8E8),
      end: widget.isDark ? const Color(0xFF3A3A45) : const Color(0xFFF5F5F5),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton list with multiple items
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Skeleton card container
class SkeletonCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isDark;

  const SkeletonCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C35) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A45) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
