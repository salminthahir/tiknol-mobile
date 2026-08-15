import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../providers/shift_provider.dart';
import '../providers/auth_provider.dart';
import '../services/shift_service.dart' as shift_svc;
import '../models/cash_ledger_entry.dart';
import '../models/shift.dart';
import 'widgets/denomination_input.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _step = 1;
  int _expectedCash = 0;
  int _difference = 0;
  int _physicalCountStep1 = 0;
  final _notesController = TextEditingController();

  // Rekap data
  ShiftLedger? _ledger;
  bool _ledgerLoading = false;
  String? _ledgerError;

  // Summary data
  ShiftSummary? _summary;
  bool _summaryLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLedger();
      _loadSummary();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLedger() async {
    final shiftState = ref.read(shiftProvider);
    if (!shiftState.hasActiveShift || shiftState.currentShift == null) return;
    setState(() { _ledgerLoading = true; _ledgerError = null; });
    try {
      final svc = ref.read(shift_svc.shiftServiceProvider);
      final ledger = await svc.getShiftLedger(shiftState.currentShift!.id);
      if (mounted) setState(() { _ledger = ledger; _ledgerLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _ledgerError = e.toString(); _ledgerLoading = false; });
    }
  }

  Future<void> _loadSummary() async {
    final shiftState = ref.read(shiftProvider);
    if (!shiftState.hasActiveShift || shiftState.currentShift == null) return;
    setState(() { _summaryLoading = true; });
    try {
      final svc = ref.read(shift_svc.shiftServiceProvider);
      final summary = await svc.getShiftSummary(shiftState.currentShift!.id);
      if (mounted) setState(() { _summary = summary; _summaryLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _summaryLoading = false; });
    }
  }

  Future<void> _submitStep1() async {
    final result = await ref.read(shiftProvider.notifier).closeShift(
      physicalCount: _physicalCountStep1,
      step: 1,
    );
    setState(() {
      _step = 2;
      _expectedCash = result.expectedCash ?? 0;
      _difference = result.difference ?? 0;
    });
  }

  Future<void> _confirmClose() async {
    final physicalCount = _expectedCash + _difference;
    final result = await ref.read(shiftProvider.notifier).closeShift(
      physicalCount: physicalCount,
      step: 2,
      closingNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );
    final isFlagged = result.isFlagged ?? false;
    final diff = result.difference ?? 0;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.posCartBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isFlagged ? Icons.warning_amber_rounded : Icons.check_circle,
              color: isFlagged ? AppColors.accent : AppColors.success,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isFlagged ? 'Shift Ditutup (Selisih)' : 'Shift Ditutup',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFlagged) ...[
              Text(
                'Selisih: Rp ${NumberFormat('#,###', 'id').format(diff.abs())}',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent),
              ),
              const SizedBox(height: 8),
              Text(
                'Shift ditutup dengan selisih melebihi toleransi. Manager perlu review.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ] else
              Text(
                'Shift berhasil ditutup tanpa selisih.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/pos');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final auth = ref.watch(authProvider);
    final f = NumberFormat('#,###', 'id');

    return Scaffold(
      backgroundColor: AppColors.posBg,
      appBar: AppBar(
        backgroundColor: AppColors.posBg,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'SHIFT',
          style: GoogleFonts.spaceMono(fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.reserve,
          labelColor: AppColors.reserve,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Rekap Shift'),
            Tab(text: 'Tutup Shift'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ── Tab 1: Rekap ──
          _buildRekapTab(shiftState, auth, f),
          // ── Tab 2: Tutup Shift ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _step == 1
                  ? _buildStep1(f, auth, shiftState)
                  : _buildStep2(f, shiftState),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Tab 1: Rekap Shift
  // ─────────────────────────────────────────────
  Widget _buildRekapTab(ShiftState shiftState, AuthState auth, NumberFormat f) {
    if (!shiftState.hasActiveShift) {
      return Center(
        child: Text('Tidak ada shift aktif.',
            style: GoogleFonts.inter(color: Colors.white54)),
      );
    }

    final shift = shiftState.currentShift!;
    final now = DateTime.now();
    final duration = now.difference(shift.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadLedger();
        await _loadSummary();
      },
      color: AppColors.reserve,
      backgroundColor: AppColors.posCardBg,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Info header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.posCardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.reserve.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.wallet, color: AppColors.reserve, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.userName ?? 'Staff',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          Text(
                            'Mulai: ${DateFormat('HH:mm, dd MMM', 'id').format(shift.startTime)}',
                            style: GoogleFonts.inter(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${hours}j ${minutes}m',
                        style: GoogleFonts.spaceMono(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cash summary cards
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  label: 'Modal Awal',
                  value: 'Rp ${f.format(shift.startCash)}',
                  icon: Icons.account_balance_wallet,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  label: 'Expected Kas',
                  value: 'Rp ${f.format(shiftState.expectedCash)}',
                  icon: Icons.trending_up,
                  color: AppColors.reserve,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryCard(
            label: 'Omzet Kas Bersih',
            value: 'Rp ${f.format(shiftState.expectedCash - shift.startCash)}',
            icon: Icons.payments,
            color: AppColors.success,
            wide: true,
          ),

          // Transaction summary (Gap 3)
          const SizedBox(height: 20),
          Text(
            'Rekap Transaksi',
            style: GoogleFonts.inter(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (_summaryLoading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.reserve, strokeWidth: 2),
            ))
          else if (_summary == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.posCardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('Gagal memuat rekap transaksi.',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    label: 'Jumlah Transaksi',
                    value: '${_summary!.totalTransactions}',
                    icon: Icons.receipt_long,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    label: 'Total Omzet',
                    value: 'Rp ${f.format(_summary!.totalOmzet)}',
                    icon: Icons.trending_up,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    label: 'Omzet Cash',
                    value: 'Rp ${f.format(_summary!.totalCash)}',
                    icon: Icons.money,
                    color: AppColors.reserve,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    label: 'Omzet QRIS',
                    value: 'Rp ${f.format(_summary!.totalQris)}',
                    icon: Icons.qr_code,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ],

          // Ledger entries
          const SizedBox(height: 20),
          Text(
            'Riwayat Kas',
            style: GoogleFonts.inter(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 10),

          if (_ledgerLoading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.reserve, strokeWidth: 2),
            ))
          else if (_ledgerError != null)
            Center(
              child: Column(
                children: [
                  Text('Gagal memuat riwayat.',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadLedger,
                    child: const Text('Coba lagi', style: TextStyle(color: AppColors.reserve)),
                  ),
                ],
              ),
            )
          else if (_ledger == null || _ledger!.entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.posCardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Belum ada mutasi kas manual.',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.posCardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _ledger!.entries.asMap().entries.map((e) {
                  final i = e.key;
                  final entry = e.value;
                  final isLast = i == _ledger!.entries.length - 1;
                  final isOut = entry.type == CashLedgerType.cashOut;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: (isOut ? AppColors.danger : AppColors.success)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isOut ? Icons.arrow_upward : Icons.arrow_downward,
                                color: isOut ? AppColors.danger : AppColors.success,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.note ?? entry.typeLabel,
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    DateFormat('HH:mm', 'id').format(entry.createdAt),
                                    style: GoogleFonts.inter(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isOut ? '-' : '+'}Rp ${f.format(entry.amount)}',
                              style: GoogleFonts.inter(
                                color: isOut ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, color: Colors.white10, indent: 60),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          // CTA pindah ke tab tutup shift
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.logout, size: 16),
              label: Text('Lanjut Tutup Shift',
                  style: GoogleFonts.spaceMono(
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool wide = false,
  }) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.posCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (wide) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.inter(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
          ),
          if (!wide) Icon(icon, color: color.withValues(alpha: 0.6), size: 18),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Tab 2: Step 1 — Hitung Fisik
  // ─────────────────────────────────────────────
  Widget _buildStep1(NumberFormat f, AuthState auth, ShiftState shiftState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.posCardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.reserve, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hitung fisik uang di laci kasir tanpa melihat sistem.',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Hitung fisik kas Anda:',
          style: GoogleFonts.inter(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.posCardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DenominationInput(
              onTotalChanged: (total) {
                _physicalCountStep1 = total;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _submitStep1,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.reserve,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'LIHAT SELISIH',
              style: GoogleFonts.spaceMono(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Tab 2: Step 2 — Review & Konfirmasi
  // ─────────────────────────────────────────────
  Widget _buildStep2(NumberFormat f, ShiftState shiftState) {
    final isOver = _difference > 0;
    final isUnder = _difference < 0;
    final diffColor = isOver
        ? AppColors.success
        : isUnder
            ? AppColors.danger
            : AppColors.reserve;

    return Column(
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _step = 1),
            icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white54),
            label: Text('Hitung ulang',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.posCardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _reviewRow('Modal Awal', f.format(shiftState.currentShift?.startCash ?? 0)),
                const Divider(color: Colors.white12),
                _reviewRow('Kas Sistem (Expected)', f.format(_expectedCash),
                    color: Colors.white70),
                const Divider(color: Colors.white12),
                _reviewRow('Kas Fisik (Hitung)', f.format(_expectedCash + _difference),
                    color: Colors.white70),
                const Divider(color: Colors.white12, thickness: 1.5),
                _reviewRow('SELISIH', f.format(_difference.abs()),
                    color: diffColor, isBold: true),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOver
                            ? Icons.arrow_upward
                            : isUnder
                                ? Icons.arrow_downward
                                : Icons.check_circle,
                        color: diffColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isOver
                              ? 'Kas LEBIH ${f.format(_difference)} dari expected'
                              : isUnder
                                  ? 'Kas KURANG ${f.format(_difference.abs())} dari expected'
                                  : 'Kas SESUAI expected',
                          style: GoogleFonts.inter(
                              color: diffColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Catatan penutupan (opsional)',
            hintStyle: GoogleFonts.inter(color: Colors.white30),
            filled: true,
            fillColor: AppColors.posCardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _confirmClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'KONFIRMASI TUTUP SHIFT',
              style: GoogleFonts.spaceMono(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
          Text(
            'Rp $value',
            style: GoogleFonts.inter(
              color: color ?? Colors.white,
              fontSize: 16,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
