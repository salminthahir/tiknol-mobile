import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme.dart';
import '../models/receipt_template.dart';
import '../providers/printer_settings_provider.dart';
import '../services/printer_service.dart';
import '../services/receipt_template_service.dart';
import '../services/receipt_service.dart';
import 'widgets/skeleton_screens.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final _printerService = PrinterService();
  ReceiptTemplate _template = const ReceiptTemplate();
  ReceiptTemplate _savedTemplate = const ReceiptTemplate(); // For dirty check
  bool _isLoading = true;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isPrinting = false;
  bool _isSaving = false;
  bool _showAllDevices = false;
  List<Map<String, dynamic>> _devices = [];

  // Controllers
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storeContactController = TextEditingController();
  final _thankYouController = TextEditingController();

  bool get _isDirty => _template.toJsonString() != _savedTemplate.toJsonString();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _printerService.requestPermissions();
    } catch (e) {
      debugPrint('Permission error: $e');
    }

    // Check Bluetooth ON — with error handling
    try {
      final isOn = await _printerService.isBluetoothOn();
      if (!isOn && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth mati. Menyalakan...'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
        await _printerService.enableBluetooth();
      }
    } catch (e) {
      debugPrint('Bluetooth check error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bluetooth error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }

    final template = await ReceiptTemplateService.load();
    setState(() {
      _template = template;
      _savedTemplate = template;
      _storeNameController.text = template.storeName;
      _storeAddressController.text = template.storeAddress;
      _storeContactController.text = template.storeContact;
      _thankYouController.text = template.thankYouText;
      _isLoading = false;
    });

    // Load bonded devices immediately (no scan needed)
    try {
      final bonded = await _printerService.getBondedDevices(filterPrinter: !_showAllDevices);
      if (mounted && bonded.isNotEmpty) {
        setState(() => _devices = bonded);
      }
    } catch (e) {
      debugPrint('Bonded devices error: $e');
    }

    // Try reconnect saved device silently (only if not already connected)
    if (template.savedDeviceId != null && !_printerService.isConnected) {
      try {
        await _printerService.reconnectToSaved();
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Reconnect error: $e');
      }
    }
  }

  @override
  void dispose() {
    _printerService.stopScan();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storeContactController.dispose();
    _thankYouController.dispose();
    super.dispose();
  }

  void _updateTemplateFromControllers() {
    setState(() {
      _template = _template.copyWith(
        storeName: _storeNameController.text,
        storeAddress: _storeAddressController.text,
        storeContact: _storeContactController.text,
        thankYouText: _thankYouController.text,
      );
    });
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      final devices = await _printerService.scanAllDevices(
        timeout: const Duration(seconds: 8),
        filterPrinter: !_showAllDevices,
      );
      if (mounted) {
        setState(() => _devices = devices);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connect(Map<String, dynamic> device) async {
    setState(() => _isConnecting = true);
    final type = device['type'] as String;
    final name = device['name'] as String;
    final id = device['id'] as String;
    bool ok = false;

    if (type == 'ble' && device['device'] is BluetoothDevice) {
      ok = await _printerService.connectBle(device['device'] as BluetoothDevice);
    } else if (type == 'classic') {
      ok = await _printerService.connectClassic(id, name);
    }

    setState(() {
      _isConnecting = false;
      if (ok) {
        _template = _template.copyWith(
          savedDeviceId: id,
          savedDeviceName: name,
        );
        _savedTemplate = _template; // Sync dirty state
        // Persist immediately so saved device is available on next page visit
        ReceiptTemplateService.save(_template);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Terhubung ke $name' : 'Gagal terhubung'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _printerService.disconnect();
    await _printerService.clearSavedDevice();
    setState(() {
      _template = _template.copyWith(
        savedDeviceId: null,
        savedDeviceName: null,
      );
      _savedTemplate = _template;
    });
    await ReceiptTemplateService.save(_template);
  }

  Future<void> _testPrint() async {
    if (!_printerService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer belum terhubung'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final bytes = await ReceiptGenerator.generateEscPosBytes(
        orderId: 'TEST-001',
        items: const [],
        subtotal: 50000,
        discount: 5000,
        total: 45000,
        paymentType: 'CASH',
        cashierName: 'Test',
        branchName: 'Cabang Test',
        customerName: 'Pelanggan',
        template: _template,
      );
      await _printerService.sendBytes(bytes.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print terkirim'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal test print: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _template = _template.copyWith(logoPath: result.files.single.path);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    _updateTemplateFromControllers();
    await ReceiptTemplateService.save(_template);
    setState(() {
      _isSaving = false;
      _savedTemplate = _template; // Update saved template
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template disimpan'), backgroundColor: AppColors.success),
      );
    }
  }

  String get _asciiPreview {
    return ReceiptGenerator.generateAsciiPreview(
      orderId: 'INV-12345',
      items: const [],
      subtotal: 50000,
      discount: 5000,
      total: 45000,
      paymentType: 'CASH',
      cashierName: 'Budi',
      branchName: 'Cabang Pusat',
      customerName: 'Andi',
      template: _template,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const PrinterSkeleton();
    }

    // Sync dirty state to global provider so ShellScreen can check before nav
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerDirtyProvider.notifier).setValue(_isDirty);
    });

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth > 900;

    final navigator = Navigator.of(context);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldSave = await _showUnsavedDialog();
        if (shouldSave == true) {
          await _save();
          if (mounted) navigator.pop();
        } else if (shouldSave == false) {
          // Discard and pop
          if (mounted) navigator.pop();
        }
        // If null (Cancel), stay on page
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        floatingActionButton: _isLoading
            ? null
            : FloatingActionButton.extended(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.save, color: _isDirty ? Colors.white : Colors.grey.shade300),
                label: Text(
                  _isSaving ? 'Menyimpan...' : (_isDirty ? 'Simpan Perubahan' : 'Tersimpan'),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _isDirty ? Colors.white : Colors.grey.shade300,
                  ),
                ),
                backgroundColor: _isDirty ? AppColors.success : Colors.grey.shade400,
                elevation: _isDirty ? 6 : 2,
              ),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildSettingsList()),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 2, child: _buildPreviewPanel()),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildConnectionCard(),
                    const SizedBox(height: 16),
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildBodyCard(),
                    const SizedBox(height: 16),
                    _buildFooterCard(),
                    const SizedBox(height: 16),
                    _buildVisibilityCard(),
                    const SizedBox(height: 16),
                    _buildPreviewCard(),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 80),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSettingsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildConnectionCard(),
        const SizedBox(height: 16),
        _buildHeaderCard(),
        const SizedBox(height: 16),
        _buildBodyCard(),
        const SizedBox(height: 16),
        _buildFooterCard(),
        const SizedBox(height: 16),
        _buildVisibilityCard(),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Future<bool?> _showUnsavedDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Text('Perubahan Belum Tersimpan', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'Anda memiliki perubahan pada pengaturan printer yang belum disimpan.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // Discard
            child: Text('Buang', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, null), // Cancel (stay)
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), // Save
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('💾 Simpan', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview, size: 18),
              const SizedBox(width: 8),
              Text('Live Preview', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: _buildPreviewCard(),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDisconnectConfirmation() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
            const SizedBox(width: 10),
            Text('Putuskan Printer?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'Yakin mau memutuskan koneksi printer?\n\nPrinter harus dihubungkan kembali untuk mencetak struk.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Putuskan', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return StreamBuilder<bool>(
      stream: _printerService.connectionState,
      initialData: _printerService.isConnected,
      builder: (context, snapshot) {
        final connected = snapshot.data ?? false;
        final savedName = _template.savedDeviceName ?? 'Belum dipilih';

        return _card(
          title: 'Koneksi Printer',
          icon: LucideIcons.bluetooth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: connected ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: connected ? AppColors.success : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connected ? 'Terhubung: $savedName' : 'Tidak terhubung',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: connected ? AppColors.success : AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (connected)
                      TextButton(
                        onPressed: () async {
                          final confirm = await _showDisconnectConfirmation();
                          if (confirm == true) _disconnect();
                        },
                        child: const Text('Putuskan', style: TextStyle(color: AppColors.danger)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: _isScanning
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search, size: 16),
                  label: Text(_isScanning ? 'Mencari...' : 'Scan Perangkat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: (_isPrinting || !connected) ? null : _testPrint,
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Test Print'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Toggle: show all devices vs printer-only
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tampilkan Semua Perangkat',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Switch(
                value: _showAllDevices,
                onChanged: (v) {
                  setState(() => _showAllDevices = v);
                  // Refresh bonded devices immediately
                  _printerService.getBondedDevices(filterPrinter: !v).then((bonded) {
                    if (mounted) setState(() => _devices = bonded);
                  });
                },
              ),
            ],
          ),
          if (_devices.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(
                  'Perangkat Ditemukan (${_devices.length})',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                leading: const Icon(Icons.devices, size: 20, color: AppColors.primary),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _devices.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = _devices[i];
                        final isSaved = _template.savedDeviceId == d['id'];
                        final isClassic = d['type'] == 'classic';
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isSaved ? LucideIcons.checkCircle : (isClassic ? LucideIcons.cpu : LucideIcons.bluetooth),
                            color: isSaved ? AppColors.success : Colors.grey,
                          ),
                          title: Text(d['name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isClassic ? Colors.orange.shade100 : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isClassic ? 'CLASSIC' : 'BLE',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: isClassic ? Colors.orange.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(d['id'] ?? '', style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                          trailing: _isConnecting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : ElevatedButton(
                                  onPressed: () => _connect(d),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  child: const Text('Connect'),
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
      },
    );
  }

  Widget _buildHeaderCard() {
    return _card(
      title: 'Header Struk',
      icon: LucideIcons.store,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField('Nama Toko', _storeNameController),
          const SizedBox(height: 10),
          _textField('Alamat', _storeAddressController),
          const SizedBox(height: 10),
          _textField('Kontak', _storeContactController),
          const SizedBox(height: 12),
          // Logo picker
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _template.logoPath != null ? 'Logo: ${_template.logoPath!.split('/').last}' : 'Belum ada logo',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.image, size: 16),
                label: const Text('Browse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                ),
              ),
              if (_template.logoPath != null)
                IconButton(
                  onPressed: () => setState(() => _template = _template.copyWith(logoPath: null)),
                  icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _toggleRow('Tampilkan Logo', _template.showLogo, (v) => setState(() => _template = _template.copyWith(showLogo: v))),
          _toggleRow('Tampilkan Nama Toko', _template.showStoreName, (v) => setState(() => _template = _template.copyWith(showStoreName: v))),
          _toggleRow('Tampilkan Alamat', _template.showStoreAddress, (v) => setState(() => _template = _template.copyWith(showStoreAddress: v))),
          _toggleRow('Tampilkan Kontak', _template.showStoreContact, (v) => setState(() => _template = _template.copyWith(showStoreContact: v))),
        ],
      ),
    );
  }

  Widget _buildBodyCard() {
    return _card(
      title: 'Body Struk',
      icon: LucideIcons.type,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ukuran Font', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          _chipGroup(
            values: ReceiptFontSize.values,
            selected: _template.fontSize,
            label: (v) => v.name.toUpperCase(),
            onSelected: (v) => setState(() => _template = _template.copyWith(fontSize: v)),
          ),
          const SizedBox(height: 12),
          Text('Alignment', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          _chipGroup(
            values: ReceiptAlignment.values,
            selected: _template.alignment,
            label: (v) => v.name.toUpperCase(),
            onSelected: (v) => setState(() => _template = _template.copyWith(alignment: v)),
          ),
          const SizedBox(height: 12),
          Text('Format Item', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          _chipGroup(
            values: ReceiptItemFormat.values,
            selected: _template.itemFormat,
            label: (v) => v == ReceiptItemFormat.qtyXprice ? 'Qty x Harga' : 'Qty x Harga = Total',
            onSelected: (v) => setState(() => _template = _template.copyWith(itemFormat: v)),
          ),
          const SizedBox(height: 12),
          _toggleRow('Bold', _template.bold, (v) => setState(() => _template = _template.copyWith(bold: v))),
        ],
      ),
    );
  }

  Widget _buildFooterCard() {
    return _card(
      title: 'Footer Struk',
      icon: LucideIcons.messageSquare,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _thankYouController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Terima kasih...',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 8),
          Text('Gunakan baris baru dengan Enter', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          _toggleRow('Tampilkan Footer', _template.showThankYou, (v) => setState(() => _template = _template.copyWith(showThankYou: v))),
        ],
      ),
    );
  }

  Widget _buildVisibilityCard() {
    return _card(
      title: 'Tampilkan Field',
      icon: LucideIcons.eye,
      child: Column(
        children: [
          _toggleRow('Nomor Order', _template.showOrderId, (v) => setState(() => _template = _template.copyWith(showOrderId: v))),
          _toggleRow('Tanggal', _template.showDate, (v) => setState(() => _template = _template.copyWith(showDate: v))),
          _toggleRow('Nama Kasir', _template.showCashier, (v) => setState(() => _template = _template.copyWith(showCashier: v))),
          _toggleRow('Nama Pelanggan', _template.showCustomer, (v) => setState(() => _template = _template.copyWith(showCustomer: v))),
          _toggleRow('Subtotal', _template.showSubtotal, (v) => setState(() => _template = _template.copyWith(showSubtotal: v))),
          _toggleRow('Diskon', _template.showDiscount, (v) => setState(() => _template = _template.copyWith(showDiscount: v))),
          _toggleRow('Total', _template.showTotal, (v) => setState(() => _template = _template.copyWith(showTotal: v))),
          _toggleRow('Metode Bayar', _template.showPaymentType, (v) => setState(() => _template = _template.copyWith(showPaymentType: v))),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview ASCII', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              _asciiPreview,
              style: GoogleFonts.spaceMono(fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      onChanged: (_) => _updateTemplateFromControllers(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _chipGroup<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      children: values.map((v) {
        final isSelected = v == selected;
        return ChoiceChip(
          label: Text(label(v)),
          selected: isSelected,
          onSelected: (_) => onSelected(v),
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primary : Colors.grey.shade700,
            fontSize: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
          ),
        );
      }).toList(),
    );
  }
}
