import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'COFFEE';
  String? _imageUrl;
  File? _imageFile;
  bool _hasCustomization = false;
  bool _isIce = true;
  bool _isHot = true;
  bool _isRegular = true;
  bool _isMedium = false;
  bool _isLarge = false;
  bool _isSaving = false;
  bool _isUploading = false;

  static const _categories = ['COFFEE', 'NON-COFFEE', 'SNACK', 'MEALS'];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.product!;
      _nameController.text = p.name;
      _priceController.text = p.price.toString();
      _descriptionController.text = p.description ?? '';
      _category = p.category.toUpperCase();
      _imageUrl = p.image;
      _hasCustomization = p.hasCustomization;
      if (p.customizationOptions != null) {
        _isIce = p.customizationOptions!.temps.contains('ICE');
        _isHot = p.customizationOptions!.temps.contains('HOT');
        _isRegular = p.customizationOptions!.sizes.contains('REGULAR');
        _isMedium = p.customizationOptions!.sizes.contains('MEDIUM');
        _isLarge = p.customizationOptions!.sizes.contains('LARGE');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _imageFile = File(result.files.first.path!);
          _imageUrl = null;
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

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;
    setState(() => _isUploading = true);
    try {
      final service = ref.read(productServiceProvider);
      final url = await service.uploadImage(_imageFile!);
      setState(() => _isUploading = false);
      return url;
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload: $e'), backgroundColor: AppColors.danger),
        );
      }
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final service = ref.read(productServiceProvider);
      final price = int.tryParse(_priceController.text.replaceAll('.', '')) ?? 0;

      String? imageUrl = _imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage();
        if (imageUrl == null) {
          setState(() => _isSaving = false);
          return;
        }
      }

      CustomizationOptions? customOptions;
      if (_hasCustomization) {
        final temps = <String>[];
        if (_isIce) temps.add('ICE');
        if (_isHot) temps.add('HOT');
        final sizes = <String>[];
        if (_isRegular) sizes.add('REGULAR');
        if (_isMedium) sizes.add('MEDIUM');
        if (_isLarge) sizes.add('LARGE');
        customOptions = CustomizationOptions(temps: temps, sizes: sizes);
      }

      if (_isEditing) {
        final updated = widget.product!.copyWith(
          name: _nameController.text.trim(),
          price: price,
          category: _category,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          image: imageUrl,
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
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Produk diupdate' : 'Produk ditambahkan'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Produk' : 'Tambah Produk',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Simpan', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageSection(),
            const SizedBox(height: 16),
            _buildBasicInfoSection(),
            const SizedBox(height: 16),
            _buildCustomizationSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gambar Produk',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : _imageUrl != null && _imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: _imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => _buildImagePlaceholder(),
                              ),
                            )
                          : _buildImagePlaceholder(),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Tap untuk upload gambar (max 2MB)',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400)),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.imagePlus, size: 32, color: Colors.grey.shade300),
        const SizedBox(height: 4),
        Text('Upload Gambar',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informasi Dasar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _textField('Nama Produk', _nameController, 'Contoh: Americano'),
          const SizedBox(height: 12),
          _textField('Harga (Rp)', _priceController, 'Contoh: 25000',
              keyboardType: TextInputType.number, isPrice: true),
          const SizedBox(height: 12),
          Text('Kategori',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _categories.map((cat) {
              final active = _category == cat;
              return GestureDetector(
                onTap: () => setState(() => _category = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(cat,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('Deskripsi (opsional)',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Deskripsi singkat produk...',
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            style: GoogleFonts.inter(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Opsi Kustomisasi',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Ice/Hot & Ukuran',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Switch(
                value: _hasCustomization,
                onChanged: (v) => setState(() => _hasCustomization = v),
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          if (_hasCustomization) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('Suhu',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                _tempChip('ICE', LucideIcons.snowflake, _isIce, () => setState(() => _isIce = !_isIce)),
                const SizedBox(width: 8),
                _tempChip('HOT', LucideIcons.flame, _isHot, () => setState(() => _isHot = !_isHot)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Ukuran',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                _sizeChip('REGULAR', _isRegular, () => setState(() => _isRegular = !_isRegular)),
                const SizedBox(width: 8),
                _sizeChip('MEDIUM', _isMedium, () => setState(() => _isMedium = !_isMedium)),
                const SizedBox(width: 8),
                _sizeChip('LARGE', _isLarge, () => setState(() => _isLarge = !_isLarge)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tempChip(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? (label == 'ICE' ? const Color(0xFFE0F7FA) : const Color(0xFFFFEBEE))
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? (label == 'ICE' ? const Color(0xFF00838F) : const Color(0xFFD32F2F))
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: active
                    ? (label == 'ICE' ? const Color(0xFF00838F) : const Color(0xFFD32F2F))
                    : Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? (label == 'ICE' ? const Color(0xFF00838F) : const Color(0xFFD32F2F))
                        : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _sizeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.2) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent : Colors.grey.shade200,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.primary : Colors.grey.shade500)),
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller, String hint,
      {TextInputType keyboardType = TextInputType.text, bool isPrice = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
            if (isPrice && int.tryParse(v.replaceAll('.', '')) == null) return 'Format harga tidak valid';
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
            prefixText: isPrice ? 'Rp ' : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          style: GoogleFonts.inter(fontSize: 12),
        ),
      ],
    );
  }
}
