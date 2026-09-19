import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../providers/stock_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _categoryFilter = 'ALL';
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, bool> _togglingIds = {};

  static const _categories = ['ALL', 'COFFEE', 'NON-COFFEE', 'SNACK', 'MEALS'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final products = await ref.read(productServiceProvider).getProducts(all: true);
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleAvailability(Product product) async {
    if (_togglingIds[product.id] == true) return;
    setState(() => _togglingIds[product.id] = true);

    final updated = product.copyWith(isAvailable: !product.isAvailable);
    
    setState(() {
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = updated;
      }
    });

    try {
      await ref.read(productServiceProvider).updateProduct(updated);
    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _products.indexWhere((p) => p.id == product.id);
          if (index != -1) {
            _products[index] = product;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(product.id));
      }
    }
  }

  Future<void> _editStock(Product product, int currentStock) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _StockEditDialog(
        productName: product.name,
        initialValue: currentStock,
      ),
    );
    if (result != null) {
      await ref.read(stockProvider.notifier).setStock(product.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _products;
    if (_categoryFilter != 'ALL') {
      filtered = filtered.where((p) => p.category == _categoryFilter).toList();
    }
    filtered.sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Inventory Stok',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20, color: AppColors.primary),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories.map((cat) {
                  final active = _categoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _categoryFilter = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          cat == 'ALL' ? 'Semua' : cat,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          Container(height: 1, color: Colors.grey.shade200),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 48),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, style: const TextStyle(color: AppColors.textPrimary)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProducts,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.packageOpen, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada produk di kategori $_categoryFilter',
                                  style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Header row
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 48 + 12), // image + gap
                                    Expanded(
                                      flex: 5,
                                      child: Text('PRODUK', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text('HARGA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5), textAlign: TextAlign.left),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('STOK', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5), textAlign: TextAlign.center),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text('STATUS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5), textAlign: TextAlign.center),
                                    ),
                                  ],
                                ),
                              ),
                              Container(height: 1, color: Colors.grey.shade200),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filtered.length,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  itemBuilder: (context, index) {
                                    final product = filtered[index];
                                    return _buildRow(product);
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

  Widget _buildRow(Product product) {
    final stock = ref.watch(stockByIdProvider(product.id));
    final isOutOfStock = stock == 0;
    final isUnavailable = !product.isAvailable;
    final formatter = NumberFormat('#,###', 'id');
    
    Color bgColor = Colors.white;
    if (isOutOfStock && product.isAvailable) {
      bgColor = const Color(0xFFFFF5F5); // light red
    } else if (isUnavailable) {
      bgColor = const Color(0xFFF8F9FA); // light grey
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isOutOfStock && product.isAvailable) 
              ? AppColors.danger.withValues(alpha: 0.3) 
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: product.image != null && product.image!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: product.image!,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => Icon(LucideIcons.imageOff, size: 20, color: Colors.grey.shade400),
                    ),
                  )
                : Icon(LucideIcons.imageOff, size: 20, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 12),

          // Kolom: Nama & Kategori (flex 5)
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isUnavailable ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: isUnavailable ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  product.category,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Kolom: Harga (flex 3)
          Expanded(
            flex: 3,
            child: Text(
              'Rp ${formatter.format(product.price)}',
              style: GoogleFonts.spaceMono(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Kolom: Stok (flex 2)
          Expanded(
            flex: 2,
            child: Center(
              child: GestureDetector(
                onTap: () => _editStock(product, stock),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOutOfStock ? AppColors.danger.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOutOfStock ? AppColors.danger.withValues(alpha: 0.3) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$stock',
                        style: GoogleFonts.spaceMono(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isOutOfStock ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.edit2,
                        size: 11,
                        color: isOutOfStock ? AppColors.danger : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Kolom: Toggle (flex 3)
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_togglingIds[product.id] == true)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                else
                  Text(
                    product.isAvailable ? 'ON' : 'OFF',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: product.isAvailable ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(width: 2),
                Switch(
                  value: product.isAvailable,
                  onChanged: _togglingIds[product.id] == true ? null : (val) => _toggleAvailability(product),
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.success,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                  trackOutlineColor: WidgetStateProperty.resolveWith((states) => Colors.transparent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockEditDialog extends StatefulWidget {
  final String productName;
  final int initialValue;

  const _StockEditDialog({required this.productName, required this.initialValue});

  @override
  State<_StockEditDialog> createState() => _StockEditDialogState();
}

class _StockEditDialogState extends State<_StockEditDialog> {
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Stok tidak boleh kosong');
      return;
    }
    
    final value = int.tryParse(text);
    if (value == null || value < 0) {
      setState(() => _error = 'Masukkan angka >= 0');
      return;
    }
    
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Ubah Stok\n${widget.productName}',
        style: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.spaceMono(color: AppColors.textPrimary, fontSize: 18),
        autofocus: true,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          hintText: 'Jumlah stok',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          errorText: _error,
          errorStyle: const TextStyle(color: AppColors.danger),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Batal',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: Text(
            'Simpan',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
