import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../providers/shift_provider.dart';
import '../../providers/auth_provider.dart';
import 'denomination_input.dart';

/// Show the Buka Shift bottom sheet. Returns true when shift opened successfully.
Future<bool> showOpenShiftSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _OpenShiftSheet(),
  );
  return result == true;
}

class _OpenShiftSheet extends ConsumerStatefulWidget {
  const _OpenShiftSheet();

  @override
  ConsumerState<_OpenShiftSheet> createState() => _OpenShiftSheetState();
}

class _OpenShiftSheetState extends ConsumerState<_OpenShiftSheet> {
  final _simpleController = TextEditingController();
  bool _useDenomination = false;
  int _denominationTotal = 0;

  @override
  void dispose() {
    _simpleController.dispose();
    super.dispose();
  }

  int get _startCash {
    if (_useDenomination) return _denominationTotal;
    return int.tryParse(_simpleController.text.replaceAll(',', '')) ?? 0;
  }

  Future<void> _openShift() async {
    final success = await ref.read(shiftProvider.notifier).openShift(_startCash);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka shift. Coba lagi.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final auth = ref.watch(authProvider);
    final f = NumberFormat('#,###', 'id');
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.posBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.reserve,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (auth.branchCode ?? 'XXX').toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BUKA SHIFT',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.reserve,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    auth.userName ?? 'Staff',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Mode toggle
          Text(
            'Modal Awal Kas',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: Text('Input Manual', style: GoogleFonts.inter(fontSize: 12)),
                selected: !_useDenomination,
                onSelected: (_) => setState(() => _useDenomination = false),
                selectedColor: AppColors.reserve,
                backgroundColor: AppColors.posCardBg,
                labelStyle: TextStyle(
                  color: !_useDenomination ? Colors.black : Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Pecahan', style: GoogleFonts.inter(fontSize: 12)),
                selected: _useDenomination,
                onSelected: (_) => setState(() => _useDenomination = true),
                selectedColor: AppColors.reserve,
                backgroundColor: AppColors.posCardBg,
                labelStyle: TextStyle(
                  color: _useDenomination ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Input area
          if (!_useDenomination) ...[
            TextField(
              controller: _simpleController,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                  color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: GoogleFonts.inter(
                    color: Colors.black54, fontSize: 20, fontWeight: FontWeight.w600),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.reserve, width: 2),
                ),
                hintText: '0',
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey[400], fontWeight: FontWeight.w600),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_simpleController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Rp ${f.format(_startCash)}',
                style: GoogleFonts.inter(
                  color: AppColors.reserve,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ] else ...[
            SizedBox(
              height: 300,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.posCardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DenominationInput(
                  onTotalChanged: (total) {
                    setState(() => _denominationTotal = total);
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: shiftState.isLoading ? null : _openShift,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.reserve,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: AppColors.reserve.withValues(alpha: 0.3),
              ),
              child: shiftState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      'BUKA SHIFT',
                      style: GoogleFonts.spaceMono(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Pastikan modal awal sesuai dengan uang fisik di kasir',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
