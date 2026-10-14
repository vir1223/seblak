import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/pages/detail_resi_page.dart';
import 'package:seblak/theme/app_theme.dart';

class BayarPage extends StatefulWidget {
  final Map<int, int> cart;
  final Map<int, Map<String, dynamic>> cartDetails;
  final double total;
  final NumberFormat rupiahFormatter;

  const BayarPage({
    super.key,
    required this.cart,
    required this.cartDetails,
    required this.total,
    required this.rupiahFormatter,
  });

  @override
  State<BayarPage> createState() => _BayarPageState();
}

class _BayarPageState extends State<BayarPage> {
  final TextEditingController _bayarController = TextEditingController();
  double _nominalBayar = 0.0;
  String _metodeBayar = 'Cash';
  double _kembalian = 0.0;
  bool _isProcessing = false;
  String? _qrisBase64;

  @override
  void initState() {
    super.initState();
    _nominalBayar = widget.total;
    _bayarController.text = _nominalBayar.toStringAsFixed(0);
    _calculateKembalian();
    _loadQris();
  }

  Future<void> _loadQris() async {
    final qris = await DatabaseHelper.instance.getSetting('qris_image_base64');
    if (!mounted) return;
    setState(() => _qrisBase64 = (qris != null && qris.isNotEmpty) ? qris : null);
  }

  @override
  void dispose() {
    _bayarController.dispose();
    super.dispose();
  }

  void _calculateKembalian() {
    setState(() {
      _kembalian = _nominalBayar < widget.total ? -1 : _nominalBayar - widget.total;
    });
  }

  void _onBayarInputChanged(String value) {
    setState(() {
      _nominalBayar = double.tryParse(value) ?? 0.0;
      _calculateKembalian();
    });
  }

  Future<void> _processCheckout() async {
    if (_nominalBayar < widget.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal Bayar tidak mencukupi!')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final orderId = await DatabaseHelper.instance.checkout(
        cart: widget.cart,
        cartDetails: widget.cartDetails,
        totalAmount: widget.total,
        amountPaid: _nominalBayar,
        changeAmount: _kembalian,
        paymentMethod: _metodeBayar,
      );
      if (mounted) _showResultDialog(true, orderId);
    } catch (e) {
      if (mounted) _showResultDialog(false, null, e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(bool success, int? orderId, [String? errorMessage]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(success ? 'Pembayaran Sukses!' : 'Pembayaran Gagal!'),
          content: success
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 50),
                    const SizedBox(height: 10),
                    Text('Total Bayar: ${widget.rupiahFormatter.format(widget.total)}'),
                    Text('Nominal Diterima: ${widget.rupiahFormatter.format(_nominalBayar)}'),
                    const Divider(),
                    Text(
                      'Kembalian: ${widget.rupiahFormatter.format(_kembalian)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.success),
                    ),
                  ],
                )
              : Text('Terjadi Kesalahan: ${errorMessage ?? "Error tidak diketahui"}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (success) Navigator.of(context).pop(true);
              },
              child: const Text('Selesai'),
            ),
            if (success)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DetailResiPage(orderId: orderId!)));
                },
                icon: const Icon(Icons.receipt),
                label: const Text('Lihat Resi'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentDark),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: EdgeInsets.zero,
              color: AppColors.dangerLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide.none),
              child: ListTile(
                title: const Text('TOTAL YANG HARUS DIBAYAR', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  widget.rupiahFormatter.format(widget.total),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Metode Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Cash'),
                    value: 'Cash',
                    groupValue: _metodeBayar,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _metodeBayar = val!;
                        _nominalBayar = widget.total;
                        _bayarController.text = _nominalBayar.toStringAsFixed(0);
                        _calculateKembalian();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Lainnya'),
                    value: 'Other',
                    groupValue: _metodeBayar,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _metodeBayar = val!;
                        _nominalBayar = widget.total;
                        _bayarController.text = '';
                        _calculateKembalian();
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_metodeBayar == 'Other') ...[
              const SizedBox(height: 8),
              if (_qrisBase64 != null)
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.memory(base64Decode(_qrisBase64!), fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Minta pelanggan scan QRIS di atas',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.accentDark),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'QRIS belum di-upload. Atur di menu Setting pada halaman utama.',
                          style: TextStyle(fontSize: 12, color: AppColors.accentDark),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _bayarController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Masukkan Nominal Uang Diterima',
                prefixText: 'Rp ',
                enabled: _metodeBayar == 'Cash',
                fillColor: _metodeBayar == 'Other' ? AppColors.border.withOpacity(0.4) : AppColors.surface,
              ),
              onChanged: _onBayarInputChanged,
            ),
            const SizedBox(height: 16),
            if (_kembalian >= 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
                    Text(
                      widget.rupiahFormatter.format(_kembalian),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'Nominal bayar masih kurang',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing || _kembalian < 0 ? null : _processCheckout,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_isProcessing ? 'Memproses...' : 'Selesaikan Pembayaran', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
