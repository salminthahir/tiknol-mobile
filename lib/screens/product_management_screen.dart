import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../services/product_service.dart';

class ProductManagementScreen extends ConsumerStatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  ConsumerState<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends ConsumerState<ProductManagementScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  Product? _selectedProduct;
  String _searchQuery = '';
  String _activeCategory = 'ALL';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isNewProduct = false;
  String? _error;

  // Form controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _branchPriceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'COFFEE';
  String? _imageUrl;
  File? _imageFile;
  bool _hasCustomization = false;
  bool _isIce = true;
  bool _isHot = true;
  bool _isSizeM = true;
  bool _isSizeL = false;
  bool _isAvailable = true;

  static const _categories = ['ALL', 'COFFEE', 'NON-COFFEE', 'SNACK', 'MEALS'];
  static const _formCategories = ['COFFEE', 'NON-COFFEE', 'SNACK', 'MEALS'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _branchPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = ref.read(productServiceProvider);
      final products = await service.getProducts(all: true);
      setState(() {
        _products = products;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredProducts = _products.where((p) {
        final matchCat = _activeCategory == 'ALL' ||
            p.category.toUpperCase() == _activeCategory;
        final matchSearch = _searchQuery.isEmpty ||
            p.name.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchCat && matchSearch;
      }).toList();
    });
  }

  void _selectProduct(Product? product) {
    if (_isDirty) {
      _showUnsavedDialog(() {
        _doSelect(product);
      });
    } else {
      _doSelect(product);
    }
  }

  void _doSelect(Product? product) {
    setState(() {
      _selectedProduct = product;
      _isDirty = false;
      _isNewProduct = product == null;
      if (product != null) {
        _nameController.text = product.name;
        _priceController.text = product.price.toString();
        _branchPriceController.text = product.branchPrice?.toString() ?? '';
        _descriptionController.text = product.description ?? '';
        _category = product.category.toUpperCase();
        _imageUrl = product.image;
        _imageFile = null;
        _hasCustomization = product.hasCustomization;
        _isAvailable = product.isAvailable;
        if (product.customizationOptions != null) {
          _isIce = product.customizationOptions!.temps.contains('ICE');
          _isHot = product.customizationOptions!.temps.contains('HOT');
          _isSizeM = product.customizationOptions!.sizes.contains('M');
          _isSizeL = product.customizationOptions!.sizes.contains('L');
        } else {
          _isIce = true;
          _isHot = true;
          _isSizeM = true;
          _isSizeL = false;
        }
      } else {
        _nameController.clear();
        _priceController.clear();
        _branchPriceController.clear();
        _descriptionController.clear();
        _category = 'COFFEE';
        _imageUrl = null;
        _imageFile = null;
        _hasCustomization = false;
        _isAvailable = true;
        _isIce = true;
        _isHot = true;
        _isSizeM = true;
        _isSizeL = false;
      }
    });
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  void _showUnsavedDialog(VoidCallback onDiscard) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Text('Perubahan Belum Tersimpan', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
        content: Text('Ada perubahan yang belum disimpan. Simpan dulu?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); onDiscard(); },
            child: Text('Buang', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _save(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _imageFile = File(result.files.first.path!);
          _imageUrl = null;
          _markDirty();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal pilih gambar: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama produk wajib diisi'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final service = ref.read(productServiceProvider);
      final price = int.tryParse(_priceController.text.replaceAll('.', '')) ?? 0;
      final branchPriceText = _branchPriceController.text.replaceAll('.', '').trim();
      final branchPrice = branchPriceText.isNotEmpty ? int.tryParse(branchPriceText) : null;

      String? imageUrl = _imageUrl;
      if (_imageFile != null) {
        imageUrl = await service.uploadImage(_imageFile!);
      }

      CustomizationOptions? customOptions;
      if (_hasCustomization) {
        final temps = <String>[];
        if (_isIce) temps.add('ICE');
        if (_isHot) temps.add('HOT');
        final sizes = <String>[];
        if (_isSizeM) sizes.add('M');
        if (_isSizeL) sizes.add('L');
        customOptions = CustomizationOptions(temps: temps, sizes: sizes);
      }

      if (_selectedProduct != null) {
        final updated = _selectedProduct!.copyWith(
          name: _nameController.text.trim(),
          price: price,
          branchPrice: branchPrice,
          category: _category,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          image: imageUrl,
          isAvailable: _isAvailable,
          hasCustomization: _hasCustomization,
          customizationOptions: customOptions,
        );
        await service.updateProduct(updated);
      } else {
        await service.createProduct(
          name: _nameController.text.trim(),
          price: price,
          category: _category,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          image: imageUrl,
          hasCustomization: _hasCustomization,
          customizationOptions: customOptions,
          isAvailable: _isAvailable,
          branchPrice: branchPrice,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_selectedProduct != null ? 'Produk diupdate' : 'Produk ditambahkan'), backgroundColor: AppColors.success),
        );
        setState(() {
          _isDirty = false;
          _isNewProduct = false;
        });
        await _loadProducts();
        await Future.delayed(const Duration(milliseconds: 300));
        ref.invalidate(productsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal simpan: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Produk', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Yakin ingin menghapus "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final service = ref.read(productServiceProvider);
      await service.deleteProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} dihapus'), backgroundColor: AppColors.success),
        );
        if (_selectedProduct?.id == product.id) _doSelect(null);
        await _loadProducts();
        await Future.delayed(const Duration(milliseconds: 300));
        ref.invalidate(productsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal hapus: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : Row(
                    children: [
                      // LEFT: Product list
                      SizedBox(
                        width: 340,
                        child: _buildLeftPanel(),
                      ),
                      const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
                      // RIGHT: Detail / Edit form
                      Expanded(child: _buildRightPanel()),
                    ],
                  ),
      ),
      floatingActionButton: (_selectedProduct == null && !_isNewProduct)
          ? FloatingActionButton.extended(
              onPressed: () => _doSelect(null),
              backgroundColor: AppColors.primary,
              icon: const Icon(LucideIcons.plus, color: Colors.white),
              label: const Text('Produk Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            )
          : null,
    );
  }

  // ── LEFT PANEL: Catalog List ──
  Widget _buildLeftPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Katalog Produk', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                      Text('${_products.length} produk', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _loadProducts,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(LucideIcons.refreshCw, size: 14, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _doSelect(null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(LucideIcons.plus, size: 14, color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) { _searchQuery = v; _applyFilter(); },
              decoration: InputDecoration(
                hintText: 'Cari...',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                prefixIcon: Icon(LucideIcons.search, size: 16, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
          // Category chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: _categories.map((cat) {
                final active = _activeCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () { _activeCategory = cat; _applyFilter(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(cat == 'ALL' ? 'Semua' : cat, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Product list
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(child: Text('Tidak ada produk', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, i) => _buildListTile(_filteredProducts[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(Product product) {
    final selected = _selectedProduct?.id == product.id;
    final formatter = NumberFormat('#,###', 'id');
    return GestureDetector(
      onTap: () => _selectProduct(product),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: AppColors.primary.withValues(alpha: 0.2)) : null,
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: product.image != null && product.image!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: product.image!, fit: BoxFit.cover,
                        errorWidget: (c, u, e) => Icon(LucideIcons.imageOff, size: 16, color: Colors.grey.shade300)),
                    )
                  : Icon(LucideIcons.imageOff, size: 16, color: Colors.grey.shade300),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${product.category} • Rp ${formatter.format(product.price)}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
            // Availability dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: product.isAvailable ? AppColors.success : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── RIGHT PANEL: Detail / Edit Form ──
  Widget _buildRightPanel() {
    if (!_isNewProduct && _selectedProduct == null && !_isDirty) {
      return _buildEmptyState();
    }
    return _buildForm();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.packageSearch, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text('Pilih produk untuk edit', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade400, fontSize: 14)),
          const SizedBox(height: 4),
          Text('atau tap + untuk tambah baru', style: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedProduct != null ? 'Edit: ${_selectedProduct!.name}' : 'Produk Baru',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
                if (_selectedProduct != null)
                  GestureDetector(
                    onTap: () => _deleteProduct(_selectedProduct!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.trash2, size: 13, color: AppColors.danger),
                          const SizedBox(width: 4),
                          Text('Hapus', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.save, size: 14, color: Colors.white),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Simpan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDirty ? AppColors.success : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Image + Customization
                  SizedBox(
                    width: 240,
                    child: Column(
                      children: [
                        _buildImageSection(),
                        const SizedBox(height: 16),
                        _buildCustomizationSection(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right: Info fields
                  Expanded(child: _buildInfoSection()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gambar Produk', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: _imageFile != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_imageFile!, fit: BoxFit.cover))
                  : _imageUrl != null && _imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(imageUrl: _imageUrl!, fit: BoxFit.cover, errorWidget: (c, u, e) => _buildImagePlaceholder()),
                        )
                      : _buildImagePlaceholder(),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: Text('Tap untuk ganti gambar', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400))),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.imagePlus, size: 28, color: Colors.grey.shade300),
        const SizedBox(height: 4),
        Text('Upload', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informasi Produk', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _formField('Nama Produk', _nameController, 'Contoh: Americano'),
          const SizedBox(height: 10),
          _formField('Harga (Rp)', _priceController, 'Contoh: 25000', isPrice: true),
          const SizedBox(height: 10),
          _formField('Harga Cabang (opsional)', _branchPriceController, 'Kosong = gunakan harga dasar', isPrice: true),
          const SizedBox(height: 4),
          Text('Kosongkan jika harga sama dengan harga dasar', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade400)),
          const SizedBox(height: 10),
          Text('Kategori', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _formCategories.map((cat) {
              final active = _category == cat;
              return GestureDetector(
                onTap: () { setState(() => _category = cat); _markDirty(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: active ? AppColors.primary : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                  child: Text(cat, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Tersedia', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              Switch(
                value: _isAvailable,
                onChanged: (v) { setState(() => _isAvailable = v); _markDirty(); },
                activeTrackColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Deskripsi', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionController,
            onChanged: (_) => _markDirty(),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Deskripsi singkat...',
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 11),
              filled: true, fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
            style: GoogleFonts.inter(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kustomisasi', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary)),
                    Text('Ice/Hot & Ukuran', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Switch(
                value: _hasCustomization,
                onChanged: (v) { setState(() => _hasCustomization = v); _markDirty(); },
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          if (_hasCustomization) ...[
            const Divider(height: 16),
            Text('Suhu', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                _chipToggle('ICE', LucideIcons.snowflake, _isIce, const Color(0xFFE0F7FA), const Color(0xFF00838F), () { setState(() => _isIce = !_isIce); _markDirty(); }),
                const SizedBox(width: 6),
                _chipToggle('HOT', LucideIcons.flame, _isHot, const Color(0xFFFFEBEE), const Color(0xFFD32F2F), () { setState(() => _isHot = !_isHot); _markDirty(); }),
              ],
            ),
            const SizedBox(height: 10),
            Text('Ukuran', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  _chipToggle('M', null, _isSizeM, AppColors.accent.withValues(alpha: 0.2), AppColors.primary, () { setState(() => _isSizeM = !_isSizeM); _markDirty(); }),
                  _chipToggle('L', null, _isSizeL, AppColors.accent.withValues(alpha: 0.2), AppColors.primary, () { setState(() => _isSizeL = !_isSizeL); _markDirty(); }),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _chipToggle(String label, IconData? icon, bool active, Color activeBg, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? activeBg : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? activeColor : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: active ? activeColor : Colors.grey.shade400),
              const SizedBox(width: 3),
            ],
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: active ? activeColor : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _formField(String label, TextEditingController controller, String hint, {bool isPrice = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          onChanged: (_) => _markDirty(),
          keyboardType: isPrice ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 11),
            prefixText: isPrice ? 'Rp ' : null,
            filled: true, fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.alertCircle, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Gagal memuat produk', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _loadProducts, icon: const Icon(LucideIcons.refreshCw, size: 14), label: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}
