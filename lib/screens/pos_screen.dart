import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import 'widgets/cart_panel.dart';
import 'widgets/skeleton_screens.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late AnimationController _staggerController;
  bool _staggerPlayed = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final products = ref.watch(filteredProductsProvider);
    final categories = ref.watch(categoriesProvider);
    final activeCategory = ref.watch(categoryFilterProvider);
    final sortBy = ref.watch(sortByProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final productsAsync = ref.watch(productsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: AppColors.posBg,
      body: SafeArea(
        child: isTablet
            ? _buildTabletLayout(auth, products, categories, activeCategory,
                sortBy, cartCount, productsAsync)
            : _buildPhoneLayout(auth, products, categories, activeCategory,
                sortBy, cartCount, productsAsync),
      ),
      endDrawer: isTablet ? null : const CartPanel(),
      floatingActionButton: !isTablet && cartCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              backgroundColor: AppColors.primary,
              icon: Badge(
                label: Text('$cartCount',
                    style: const TextStyle(fontSize: 10)),
                child:
                    const Icon(LucideIcons.shoppingBag, color: Colors.white, size: 20),
              ),
              label: Text(
                'Rp ${NumberFormat('#,###', 'id').format(ref.watch(cartTotalProvider))}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          : null,
    );
  }

  // ── Tablet: Content + Cart (NavRail handled by ShellRoute) ──
  Widget _buildTabletLayout(
    AuthState auth,
    List<Product> products,
    List<String> categories,
    String activeCategory,
    SortBy sortBy,
    int cartCount,
    AsyncValue<List<Product>> productsAsync,
  ) {
    return Row(
      children: [
        // Main Content
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildTabletHeader(auth),
              _buildFilters(categories, activeCategory, sortBy),
              Expanded(
                child: ClipRect(
                  child: productsAsync.when(
                    data: (_) => _buildProductGrid(products, isTablet: true),
                    loading: () => PosSkeleton(isTablet: true),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Cart Panel (always visible on tablet)
        const SizedBox(width: 380, child: CartPanel()),
      ],
    );
  }

  // ── Phone: Standard scaffold ──
  Widget _buildPhoneLayout(
    AuthState auth,
    List<Product> products,
    List<String> categories,
    String activeCategory,
    SortBy sortBy,
    int cartCount,
    AsyncValue<List<Product>> productsAsync,
  ) {
    return Column(
      children: [
        _buildPhoneHeader(auth, cartCount),
        _buildFilters(categories, activeCategory, sortBy),
        Expanded(
          child: ClipRect(
            child: productsAsync.when(
              data: (_) => _buildProductGrid(products, isTablet: false),
              loading: () => PosSkeleton(isTablet: false),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tablet Header ──
  Widget _buildTabletHeader(AuthState auth) {
    return Container(
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
              Text.rich(
                TextSpan(
                  style: GoogleFonts.spaceMono(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                  children: const [
                    TextSpan(text: '.', style: TextStyle(color: AppColors.reserve)),
                    TextSpan(text: 'NOL POS'),
                  ],
                ),
              ),
              Text(
                '${auth.branchName ?? ''} • ${auth.userName ?? ''}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.success, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('OPEN',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Phone Header ──
  Widget _buildPhoneHeader(AuthState auth, int cartCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.posCardBg,
        border: Border(bottom: BorderSide(color: AppColors.posDivider)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: AppColors.posBg, borderRadius: BorderRadius.circular(8)),
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                children: const [
                  TextSpan(text: '.', style: TextStyle(color: AppColors.reserve)),
                  TextSpan(text: 'NOL'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.spaceMono(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                    children: const [
                      TextSpan(text: '.', style: TextStyle(color: AppColors.reserve)),
                      TextSpan(text: 'NOL POS'),
                    ],
                  ),
                ),
                Text('${auth.branchName ?? ''} • ${auth.userName ?? ''}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
          if (cartCount > 0)
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => Scaffold.of(ctx).openEndDrawer(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.reserve,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shoppingBag,
                          color: Colors.black, size: 16),
                      const SizedBox(width: 6),
                      Text('$cartCount',
                          style: GoogleFonts.inter(
                              color: Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Filters ──
  Widget _buildFilters(
      List<String> categories, String activeCategory, SortBy sortBy) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search
          SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).set(v),
              decoration: InputDecoration(
                hintText: 'Cari menu...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white70),
                filled: true,
                fillColor: AppColors.posCardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.posDivider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.posDivider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.reserve, width: 1.5),
                ),
              ),
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          // Sort + Categories row
          SizedBox(
            height: 30,
            child: Row(
              children: [
                _sortChip('A-Z', SortBy.name, sortBy),
                const SizedBox(width: 6),
                _sortChip('Murah', SortBy.priceAsc, sortBy),
                const SizedBox(width: 6),
                _sortChip('Mahal', SortBy.priceDesc, sortBy),
                const SizedBox(width: 12),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final isActive = cat == activeCategory;
                      return GestureDetector(
                        onTap: () => ref
                            .read(categoryFilterProvider.notifier)
                            .set(cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                isActive ? AppColors.reserve : AppColors.posCardBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isActive
                                  ? Colors.black
                                  : AppColors.posDivider,
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                            child: Text(
                              cat,
                              style: GoogleFonts.spaceMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: isActive
                                    ? Colors.black
                                    : Colors.white70,
                              ),
                            ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, SortBy value, SortBy current) {
    final isActive = current == value;
    return GestureDetector(
      onTap: () => ref.read(sortByProvider.notifier).set(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.reserve : AppColors.posCardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.reserve : AppColors.posDivider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: isActive ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  // ── Product Grid (Responsive + Staggered) ──
  Widget _buildProductGrid(List<Product> products, {required bool isTablet}) {
    if (products.isEmpty) {
      final searchQuery = ref.read(searchQueryProvider);
      final activeCategory = ref.read(categoryFilterProvider);
      final hasFilter = searchQuery.isNotEmpty || activeCategory != 'ALL';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasFilter ? LucideIcons.searchX : LucideIcons.coffee,
                size: 48, color: Colors.white30),
            const SizedBox(height: 12),
            Text(hasFilter ? 'Tidak ada produk yang cocok' : 'Belum ada produk',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.white54)),
            if (hasFilter) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(searchQueryProvider.notifier).set('');
                  ref.read(categoryFilterProvider.notifier).set('ALL');
                  _searchController.clear();
                },
                child: Text('Reset filter',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.reserve)),
              ),
            ],
          ],
        ),
      );
    }

    // Trigger stagger animation
    if (!_staggerPlayed) {
      _staggerPlayed = true;
      _staggerController.forward(from: 0);
    }
    // Reset on data change
    ref.listen(productsProvider, (prev, next) {
      if (next.hasValue) {
        _staggerPlayed = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _staggerPlayed = true;
            _staggerController.forward(from: 0);
          }
        });
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (isTablet) {
          crossAxisCount = constraints.maxWidth > 1100 ? 6 : 5;
        } else {
          crossAxisCount = 3;
        }

        final disableAnim = MediaQuery.disableAnimationsOf(context);

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            if (disableAnim) {
              return _ProductCard(product: products[index]);
            }

            final start = (index * 0.06).clamp(0.0, 0.6);
            final end = (start + 0.4).clamp(0.0, 1.0);
            final opacity = Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: _staggerController,
                curve: Interval(start, end, curve: Curves.easeOut),
              ),
            );
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _staggerController,
                curve: Interval(start, end, curve: Curves.easeOut),
              ),
            );

            return AnimatedBuilder(
              animation: _staggerController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: opacity,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
              child: _ProductCard(product: products[index]),
            );
          },
        );
      },
    );
  }
}

// ── Product Card ──
class _ProductCard extends ConsumerStatefulWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  double _scale = 1.0;
  bool _isPressed = false;

  void _onTap() {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    if (widget.product.hasCustomization) {
      _showCustomizationSheet(context, ref);
    } else {
      ref.read(cartProvider.notifier).addItem(widget.product);
      if (!disableAnim) {
        setState(() => _scale = 0.93);
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) setState(() => _scale = 1.0);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qtyInCart = ref.watch(cartProductQtyProvider(widget.product.id));

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.posCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.posDivider),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.product.image != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.product.image!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(
                                    color: AppColors.posBg,
                                    child: const Center(
                                        child: Icon(LucideIcons.coffee,
                                            color: Colors.white30, size: 24)),
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    color: AppColors.posBg,
                                    child: const Center(
                                        child: Icon(LucideIcons.coffee,
                                            color: Colors.white30, size: 24)),
                                  ),
                                )
                              : Container(
                                  color: AppColors.posBg,
                                  child: const Center(
                                      child: Icon(LucideIcons.coffee,
                                          color: Colors.white30, size: 24)),
                                ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            color: _isPressed 
                                ? AppColors.reserve.withValues(alpha: 0.25) 
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.product.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.reserve,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(widget.product.price / 1000).toStringAsFixed(0)}K',
                              style: GoogleFonts.spaceMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Cart badge with AnimatedSwitcher
              Positioned(
                top: 4,
                right: 4,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: qtyInCart > 0
                      ? Container(
                          key: ValueKey(qtyInCart),
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.reserve,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$qtyInCart',
                              style: GoogleFonts.spaceMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey(0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomizationSheet(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,###', 'id');
    final product = widget.product;
    String? selectedTemp =
        product.customizationOptions?.temps.isNotEmpty == true
            ? product.customizationOptions!.temps.first
            : null;
    String? selectedSize =
        product.customizationOptions?.sizes.isNotEmpty == true
            ? product.customizationOptions!.sizes.first
            : 'REGULAR';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.posCartBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Rp ${formatter.format(product.price)}',
                      style: GoogleFonts.spaceMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 20),
                  if (product.customizationOptions?.temps.isNotEmpty == true) ...[
                    Text('Temperature',
                        style:
                            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: product.customizationOptions!.temps.map((t) {
                        final isSelected = selectedTemp == t;
                        return GestureDetector(
                          onTap: () => setState(() => selectedTemp = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (t == 'ICE'
                                      ? AppColors.reserve
                                      : AppColors.danger)
                                  : AppColors.posCardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? (t == 'ICE'
                                        ? AppColors.reserve
                                        : AppColors.danger)
                                    : AppColors.posDivider,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  t == 'ICE'
                                      ? LucideIcons.snowflake
                                      : LucideIcons.flame,
                                  size: 16,
                                  color: isSelected
                                      ? (t == 'ICE'
                                          ? Colors.black
                                          : Colors.white)
                                      : Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t,
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    color: isSelected
                                        ? (t == 'ICE'
                                            ? Colors.black
                                            : Colors.white)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (product.customizationOptions?.sizes.isNotEmpty == true) ...[
                    Text('Size',
                        style:
                            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: product.customizationOptions!.sizes.map((s) {
                        final isSelected = selectedSize == s;
                        return GestureDetector(
                          onTap: () => setState(() => selectedSize = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.reserve.withValues(alpha: 0.2)
                                  : AppColors.posCardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.reserve
                                    : AppColors.posDivider,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              s,
                              style: GoogleFonts.spaceMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: isSelected
                                    ? Colors.black
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).addItem(
                              product,
                              temp: selectedTemp,
                              size: selectedSize,
                            );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.reserve,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('ADD TO CART',
                          style: GoogleFonts.spaceMono(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
