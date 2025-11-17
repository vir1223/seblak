import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seblak/pages/detail_resi_page.dart';

class BayarPage extends StatefulWidget {
  final Map<String, int> cart;
  final Map<String, Map<String, dynamic>> cartDetails;
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

  @override
  void initState() {
    super.initState();
    // Inisialisasi nominal bayar dengan total jika cash
    _nominalBayar = widget.total;
    _bayarController.text = _nominalBayar.toStringAsFixed(0);
    _calculateKembalian();
  }

  void _calculateKembalian() {
    setState(() {
      // Pastikan nominal bayar tidak kurang dari total
      if (_nominalBayar < widget.total) {
        _kembalian = -1; // Indikasi kurang bayar
      } else {
        _kembalian = _nominalBayar - widget.total;
      }
    });
  }

  void _onBayarInputChanged(String value) {
    setState(() {
      _nominalBayar = double.tryParse(value) ?? 0.0;
      _calculateKembalian();
    });
  }

  // Fungsi Checkout
  Future<void> _processCheckout() async {
    if (_nominalBayar < widget.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal Bayar tidak mencukupi!')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      
      // 1. Persiapan: Ambil ID semua produk yang ada di keranjang
      List<String> productIds = widget.cart.keys.toList();
      
      // 2. Baca Stok Saat Ini (dalam satu query untuk efisiensi)
      // Walaupun tidak se-aman runTransaction, ini cukup untuk single-user
      final productsQuery = await firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: productIds)
          .get();
          
      Map<String, DocumentSnapshot> productSnaps = {
        for (var doc in productsQuery.docs) doc.id: doc
      };

      // 3. Pengecekan Stok & Logika Bisnis (Manual)
      // Jika ada satu saja produk yang stoknya kurang, seluruh proses dibatalkan
      for (var entry in widget.cart.entries) {
        String productId = entry.key;
        int quantity = entry.value;
        DocumentSnapshot? productSnap = productSnaps[productId];

        if (productSnap == null || !productSnap.exists) {
          throw Exception("Produk tidak ditemukan: ID $productId.");
        }

        // Penanganan Tipe Data Defensif (untuk menghindari breakpoint)
        final data = productSnap.data() as Map<String, dynamic>?;
        if (data == null) throw Exception("Data produk kosong untuk ID $productId.");
        
        final stockValue = data['stock'];
        if (stockValue == null || stockValue is! int) throw Exception("Field 'stock' hilang atau salah tipe pada produk ID $productId.");
        int currentStock = stockValue;
        
        final namaValue = data['nama'];
        String namaProduk = namaValue ?? "Produk Tanpa Nama"; // Tambahkan default jika nama null
        
        if (currentStock < quantity) {
          throw Exception("Gagal: Stok untuk $namaProduk tidak cukup. Tersisa: $currentStock");
        }
      }
      
      // 4. Buat Batch Write
      WriteBatch batch = firestore.batch();
      DocumentReference orderRef = firestore.collection('orders').doc();
      List<Map<String, dynamic>> orderItems = [];

      // 5. Populate Batch dengan Operasi Tulis
      for (var entry in widget.cart.entries) {
        String productId = entry.key;
        int quantity = entry.value;
        DocumentSnapshot productSnap = productSnaps[productId]!;
        Map<String, dynamic> data = productSnap.data() as Map<String, dynamic>;

        DocumentReference productRef = firestore.collection('products').doc(productId);
        int currentStock = data['stock'] as int;
        int priceAtOrder = data['harga'] as int;
        String namaProduk = data['nama'] as String;

        // Operasi A: Pengurangan Stok
        batch.update(productRef, {
          'stock': currentStock - quantity,
        });

        // Siapkan item untuk Order
        orderItems.add({
          'productId': productId,
          'name': namaProduk,
          'quantity': quantity,
          'priceAtOrder': priceAtOrder, 
          'subtotal': priceAtOrder * quantity,
        });
      }

      // Operasi B: Pembuatan Dokumen Order
      batch.set(orderRef, {
        'orderItems': orderItems,
        'totalAmount': widget.total,
        'amountPaid': _nominalBayar,
        'change': _kembalian,
        'paymentMethod': _metodeBayar,
        'orderDate': FieldValue.serverTimestamp(),
        'status': 'Completed',
      });
      
      // 6. Commit Batch
      await batch.commit();

      // Transaksi berhasil, tampilkan dialog hasil
      if (mounted) {
        _showResultDialog(true, orderRef.id); // Kirim orderRef.id yang baru dibuat
      }
    } catch (e) {
      if (mounted) {
        // Menangkap exception dari pengecekan manual stok/tipe data
        _showResultDialog(false, e.toString()); 
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showResultDialog(bool success, String? orderId, [String? errorMessage]) {
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
                    const Icon(Icons.check_circle, color: Colors.green, size: 50),
                    const SizedBox(height: 10),
                    // ... (Ringkasan pembayaran tetap sama) ...
                    Text('Total Bayar: ${widget.rupiahFormatter.format(widget.total)}'),
                    Text('Nominal Diterima: ${widget.rupiahFormatter.format(_nominalBayar)}'),
                    const Divider(),
                    Text('Kembalian: ${widget.rupiahFormatter.format(_kembalian)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                )
              : Text('Terjadi Kesalahan: ${errorMessage ?? "Error tidak diketahui"}'),
          actions: [
            // Tombol 1: Selesai (Kembali ke KasirPage)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog hasil
                if (success) {
                  Navigator.of(context).pop(true); // Kembali ke KasirPage dengan hasil true (reset cart)
                }
              },
              child: const Text('Selesai'),
            ),

            // Tombol 2: Lihat Resi (Hanya muncul jika sukses)
            if (success)
              ElevatedButton.icon(
                onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
                Navigator.of(context).pop(); // Kembali ke KasirPage
                Navigator.push(context, MaterialPageRoute(builder: (context) => DetailResiPage(orderId: orderId!))); 
              },
                icon: const Icon(Icons.receipt),
                label: const Text('Lihat Resi'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Yang Harus Dibayar
            Card(
              elevation: 4,
              color: Colors.red[50],
              child: ListTile(
                title: const Text('TOTAL YANG HARUS DIBAYAR', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  widget.rupiahFormatter.format(widget.total),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Divider(),
            const Text('Metode Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            
            // Opsi Pembayaran (Cash/Lainnya)
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Cash'),
                    value: 'Cash',
                    groupValue: _metodeBayar,
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
            
            

            const SizedBox(height: 20),
            
            // Input Nominal Bayar (Hanya aktif untuk Cash)
            TextField(
              controller: _bayarController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Masukkan Nominal Uang Diterima',
                prefixText: 'Rp ',
                border: const OutlineInputBorder(),
                enabled: _metodeBayar == 'Cash', // Hanya bisa diinput jika Cash
                fillColor: _metodeBayar == 'Other' ? Colors.grey[200] : Colors.white,
                filled: true,
              ),
              onChanged: _onBayarInputChanged,
            ),

            const SizedBox(height: 70),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing || _kembalian < 0
                    ? null // Nonaktif jika sedang proses atau kurang bayar
                    : _processCheckout,
                icon: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
                label: Text(
                  _isProcessing ? 'Memproses...' : 'Selesaikan Pembayaran',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}