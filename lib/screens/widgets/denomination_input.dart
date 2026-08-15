import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';

class DenominationEntry {
  final int value;
  final String label;
  int count;

  DenominationEntry(this.value, this.label, {this.count = 0});

  int get subtotal => value * count;
}

class DenominationInput extends StatefulWidget {
  final void Function(int total) onTotalChanged;

  const DenominationInput({super.key, required this.onTotalChanged});

  @override
  State<DenominationInput> createState() => _DenominationInputState();
}

class _DenominationInputState extends State<DenominationInput> {
  static final _f = NumberFormat('#,###');

  static final _denominations = [
    DenominationEntry(100000, '100.000'),
    DenominationEntry(50000, '50.000'),
    DenominationEntry(20000, '20.000'),
    DenominationEntry(10000, '10.000'),
    DenominationEntry(5000, '5.000'),
    DenominationEntry(2000, '2.000'),
    DenominationEntry(1000, '1.000'),
    DenominationEntry(500, '500'),
    DenominationEntry(200, '200'),
    DenominationEntry(100, '100'),
  ];

  int get _total => _denominations.fold(0, (sum, d) => sum + d.subtotal);

  void _notifyTotal() {
    widget.onTotalChanged(_total);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._denominations.map((d) => _buildRow(d)),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.posCardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Rp ${_f.format(_total)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(DenominationEntry d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              d.label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text('x', style: TextStyle(color: Colors.white38)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              controller: TextEditingController(
                text: d.count > 0 ? d.count.toString() : '',
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.reserve, width: 1.5),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  d.count = int.tryParse(val) ?? 0;
                });
                _notifyTotal();
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '= Rp ${_f.format(d.subtotal)}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
