import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:seblak/pages/bayar_page.dart';

// Ganti class ini dengan kode KasirPage Anda yang dimodifikasi
class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  // ... (Variabel _cart, _cartDetails, _totalPrice, _qtyController, rupiahFormatter tetap sama) ...
  final Map<String, int> _cart = {};
  final Map<String, Map<String, dynamic>> _cartDetails = {};
  double _totalPrice = 0.0;
  final TextEditingController _qtyController = TextEditingController();
  final rupiahFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }
  
  // Fungsi update, edit, remove dan calculate tetap sama
  void _calculateTotal() {
    double total = 0.0;
    _cart.forEach((productId, quantity) {
      final price = _cartDetails[productId]?['price'] ?? 0;
      total += (price * quantity);
    });
    setState(() {
      _totalPrice = total;
    });
  }

  void _updateCart(String productId, String name, int price, int availableStock, int quantityToAdd) {
    if (quantityToAdd <= 0) return;

    setState(() {
      int currentQty = _cart[productId] ?? 0;
      int newQty = currentQty + quantityToAdd;

      if (newQty <= availableStock) {
        _cart[productId] = newQty;
        _cartDetails[productId] = {'name': name, 'price': price, 'stock': availableStock};
      } else {
        Get.snackbar('', 'Hanya bisa menambahkan ${availableStock - currentQty} item lagi.');
      }
      _calculateTotal();
    });
  }

  void _editCartItemQuantity(String productId, int newQuantity) {
    setState(() {
      final detail = _cartDetails[productId]!;
      int availableStock = detail['stock'];
      
      if (newQuantity <= 0) {
        _cart.remove(productId);
        _cartDetails.remove(productId);
      } else if (newQuantity <= availableStock) {
        _cart[productId] = newQuantity;
      } else {
        Get.snackbar('', 'Maksimum stok ${detail['name']} adalah $availableStock.');
      }
      _calculateTotal();
    });
  }
  
  void _removeCartItem(String productId) {
    setState(() {
      _cart.remove(productId);
      _cartDetails.remove(productId);
      _calculateTotal();
    });
  }
  
  void _showQuantityDialog(String productId, String name, int price, int stock) {
    // ... (Logika Quantity Dialog tetap sama) ...
    _qtyController.text = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Tambah $name'),
          content: TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jumlah (Max $stock)',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(_qtyController.text) ?? 0;
                if (qty > 0) {
                  _updateCart(productId, name, price, stock, qty);
                  Get.back();
                } else {
                  Get.snackbar('', 'Masukkan jumlah yang valid.');
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  // MODIFIKASI: Tombol Bayar dipindahkan ke dalam dialog ini
  void _showCartDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Keranjang Belanja'),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_cart.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('Keranjang Anda kosong.'),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _cart.length,
                          itemBuilder: (context, index) {
                            String productId = _cart.keys.elementAt(index);
                            int quantity = _cart[productId]!;
                            var detail = _cartDetails[productId]!;
                            int price = detail['price'];

                            return ListTile(
                              title: Text(detail['name']),
                              subtitle: Text(
                                  '${rupiahFormatter.format(price)} x $quantity = ${rupiahFormatter.format(price * quantity)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () {
                                      setModalState(() {
                                        _editCartItemQuantity(productId, quantity - 1);
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setModalState(() {
                                        _removeCartItem(productId);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(rupiahFormatter.format(_totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Tutup'),
            ),
            // TOMBOL BAYAR DIPINDAHKAN KE SINI
            ElevatedButton.icon(
              onPressed: _cart.isNotEmpty ? () {
                Get.back(); // Tutup dialog keranjang
                // NAVIGASI KE HALAMAN PEMBAYARAN
                _navigateToPayment();
              } : null,
              icon: const Icon(Icons.payment),
              label: const Text('Bayar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Fungsi navigasi ke halaman Bayar
  void _navigateToPayment() async {
    // Siapkan data keranjang yang akan dikirim
    Map<String, int> cartToProcess = Map.from(_cart);
    Map<String, Map<String, dynamic>> detailsToProcess = Map.from(_cartDetails);
    double totalAmount = _totalPrice;
    
    // Pindah ke BayarPage dan tunggu hasil transaksi
    final result = await Get.to(() => BayarPage(
      cart: cartToProcess,
      cartDetails: detailsToProcess,
      total: totalAmount,
      rupiahFormatter: rupiahFormatter,
    ));

    // Jika transaksi berhasil (result = true), reset state keranjang
    if (result == true) {
      setState(() {
        _cart.clear();
        _cartDetails.clear();
        _totalPrice = 0.0;
      });
      Get.snackbar('', 'Pembayaran berhasil! Stok diperbarui.');
    }
  }


  // --- WIDGET BUILD ---
  
  @override
  Widget build(BuildContext context) {
    int totalItems = _cart.values.fold(0, (sum, element) => sum + element);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halaman Kasir'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('nama')
            .snapshots(),
        builder: (context, snapshot) {
          // ... (Logika loading/error/empty state tetap sama) ...
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Tidak ada produk tersedia.'));
          }

          final products = snapshot.data!.docs;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              String productId = product.id;
              String nama = product['nama'];
              int harga = product['harga'] as int;
              int stock = product['stock'] as int? ?? 0; 
              
              bool isProductInCart = _cart.containsKey(productId);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 1,
                child: ListTile(
                  title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Harga: ${rupiahFormatter.format(harga)} | Stok: $stock'),
                  trailing: stock > 0
                      ? ElevatedButton.icon(
                          onPressed: () {
                            // Panggil Quantity Dialog
                            _showQuantityDialog(productId, nama, harga, stock);
                          },
                          icon: isProductInCart
                              ? const Icon(Icons.edit_note)
                              : const Icon(Icons.add_shopping_cart),
                          label: Text(
                            isProductInCart 
                              ? 'Edit Qty (${_cart[productId]})' 
                              : 'Tambah',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isProductInCart ? Colors.blue : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        )
                      : const Text('HABIS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),

      // --- Bottom Navigation Bar hanya untuk Tombol Cart ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black26, width: 1.0)),
        ),
        child: ElevatedButton.icon(
          onPressed: _showCartDialog,
          icon: const Icon(Icons.shopping_cart),
          label: Text(
            'Cart (${rupiahFormatter.format(_totalPrice)}) ($totalItems Item)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }
}