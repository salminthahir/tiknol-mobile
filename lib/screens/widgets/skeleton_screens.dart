import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'skeleton.dart';

/// Skeleton loading for POS screen (product grid) — dark theme
class PosSkeleton extends StatelessWidget {
  final bool isTablet;
  const PosSkeleton({super.key, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header skeleton
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.posCardBg,
            border: Border(bottom: BorderSide(color: AppColors.posDivider)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Skeleton(width: 80, height: 18, borderRadius: 4, isDark: true),
                  const SizedBox(height: 4),
                  const Skeleton(width: 140, height: 12, borderRadius: 4, isDark: true),
                ],
              ),
              const Spacer(),
              const Skeleton(width: 60, height: 24, borderRadius: 8, isDark: true),
            ],
          ),
        ),
        // Filter chips skeleton
        Container(
          color: AppColors.posBg,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              const Skeleton(width: 50, height: 28, borderRadius: 14, isDark: true),
              const SizedBox(width: 6),
              const Skeleton(width: 60, height: 28, borderRadius: 14, isDark: true),
              const SizedBox(width: 6),
              const Skeleton(width: 70, height: 28, borderRadius: 14, isDark: true),
              const SizedBox(width: 6),
              const Skeleton(width: 55, height: 28, borderRadius: 14, isDark: true),
            ],
          ),
        ),
        // Product grid skeleton
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTablet ? 4 : 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: isTablet ? 8 : 6,
            itemBuilder: (context, index) => _ProductCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.posCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.posDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF25252D),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(width: double.infinity, height: 14, borderRadius: 4, isDark: true),
                const SizedBox(height: 6),
                const Skeleton(width: 60, height: 12, borderRadius: 4, isDark: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading for History screen (order list)
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header skeleton
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 140, height: 22, borderRadius: 4),
                    const SizedBox(height: 4),
                    Skeleton(width: 120, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              Skeleton(width: 32, height: 32, borderRadius: 8),
              const SizedBox(width: 4),
              Skeleton(width: 32, height: 32, borderRadius: 8),
            ],
          ),
        ),
        // Filter pills skeleton
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Skeleton(width: 40, height: 24, borderRadius: 12),
              const SizedBox(width: 6),
              Skeleton(width: 50, height: 24, borderRadius: 12),
              const SizedBox(width: 6),
              Skeleton(width: 60, height: 24, borderRadius: 12),
              const SizedBox(width: 6),
              Skeleton(width: 50, height: 24, borderRadius: 12),
              const SizedBox(width: 6),
              Skeleton(width: 70, height: 24, borderRadius: 12),
            ],
          ),
        ),
        // Order list skeleton
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 8,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HistoryCardSkeleton(),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Skeleton(width: 40, height: 18, borderRadius: 4),
              const SizedBox(width: 10),
              Expanded(child: Skeleton(width: double.infinity, height: 14, borderRadius: 4)),
              const SizedBox(width: 10),
              Skeleton(width: 50, height: 18, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 100, height: 13, borderRadius: 4),
                    const SizedBox(height: 4),
                    Skeleton(width: 80, height: 11, borderRadius: 4),
                  ],
                ),
              ),
              Skeleton(width: 80, height: 16, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading for Printer settings screen
class PrinterSkeleton extends StatelessWidget {
  const PrinterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connection card skeleton
            SkeletonCard(
              children: [
                Skeleton(width: 140, height: 16, borderRadius: 4),
                const SizedBox(height: 12),
                Skeleton(width: double.infinity, height: 40, borderRadius: 8),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Skeleton(width: double.infinity, height: 36, borderRadius: 8)),
                    const SizedBox(width: 8),
                    Expanded(child: Skeleton(width: double.infinity, height: 36, borderRadius: 8)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Header card skeleton
            SkeletonCard(
              children: [
                Skeleton(width: 100, height: 16, borderRadius: 4),
                const SizedBox(height: 12),
                Skeleton(width: double.infinity, height: 44, borderRadius: 8),
                const SizedBox(height: 10),
                Skeleton(width: double.infinity, height: 44, borderRadius: 8),
                const SizedBox(height: 10),
                Skeleton(width: double.infinity, height: 44, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 16),
            // Body card skeleton
            SkeletonCard(
              children: [
                Skeleton(width: 80, height: 16, borderRadius: 4),
                const SizedBox(height: 12),
                Skeleton(width: double.infinity, height: 80, borderRadius: 8),
                const SizedBox(height: 10),
                Skeleton(width: double.infinity, height: 44, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 16),
            // Footer card skeleton
            SkeletonCard(
              children: [
                Skeleton(width: 90, height: 16, borderRadius: 4),
                const SizedBox(height: 12),
                Skeleton(width: double.infinity, height: 44, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 16),
            // Visibility card skeleton
            SkeletonCard(
              children: [
                Skeleton(width: 110, height: 16, borderRadius: 4),
                const SizedBox(height: 12),
                ...List.generate(6, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Skeleton(width: double.infinity, height: 12, borderRadius: 4)),
                      const SizedBox(width: 8),
                      Skeleton(width: 36, height: 20, borderRadius: 10),
                    ],
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
