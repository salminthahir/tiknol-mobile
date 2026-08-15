import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/cash_ledger_entry.dart';
import '../../providers/shift_provider.dart';

class ManualCashEntryDialog extends ConsumerStatefulWidget {
  const ManualCashEntryDialog({super.key});

  @override
  ConsumerState<ManualCashEntryDialog> createState() => _ManualCashEntryDialogState();
}

class _ManualCashEntryDialogState extends ConsumerState<ManualCashEntryDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  CashLedgerType _selectedType = CashLedgerType.cashOut;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  Future<void> _submit() async {
    if (_amount <= 0 || _noteController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final entry = await ref.read(shiftProvider.notifier).recordManualCash(
      type: _selectedType,
      amount: _amount,
      note: _noteController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (entry != null) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kas berhasil dicatat: ${entry.typeLabel} Rp ${NumberFormat('#,###', 'id').format(_amount)}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mencatat kas. Pastikan shift aktif.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,###', 'id');

    return AlertDialog(
      backgroundColor: AppColors.posCartBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: AppColors.reserve, size: 22),
          const SizedBox(width: 10),
          Text(
            'Catat Kas',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jenis Transaksi',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _typeChip(
                    label: 'Kas Keluar',
                    type: CashLedgerType.cashOut,
                    icon: Icons.arrow_upward,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _typeChip(
                    label: 'Kas Masuk',
                    type: CashLedgerType.cashInOther,
                    icon: Icons.arrow_downward,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: GoogleFonts.inter(color: Colors.white70, fontSize: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: '0',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_amount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_selectedType == CashLedgerType.cashOut ? 'Kas Keluar' : 'Kas Masuk'}: Rp ${f.format(_amount)}',
                  style: GoogleFonts.inter(
                    color: _selectedType == CashLedgerType.cashOut ? AppColors.danger : AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Catatan',
                labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                hintText: 'Wajib diisi',
                hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Batal', style: GoogleFonts.inter(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _amount > 0 && _noteController.text.trim().isNotEmpty && !_isLoading
              ? _submit
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.reserve,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppColors.reserve.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Simpan', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _typeChip({
    required String label,
    required CashLedgerType type,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : AppColors.posBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.white54),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? color : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
