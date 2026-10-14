import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/pages/bayar_page.dart';
import 'package:seblak/theme/app_theme.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  final Map<int, int> _cart = {};
  final Map<int, Map<String, dynamic>> _cartDetails = {};
  double _totalPrice = 0.0;
  final TextEditingController _qtyController = TextEditingController();
  final rupiahFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _productsFuture = DatabaseHelper.instance.getAllProducts(orderBy: 'nama ASC');
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    double total = 0.0;
    _cart.forEach((productId, quantity) {
      final price = _cartDetails[productId]?['price'] ?? 0;
      total += (price * quantity);
    });
    setState(() => _totalPrice = total);
  }

  void _updateCart(int productId, String name, int price, int availableStock, int quantityToAdd) {
    if (quantityToAdd <= 0) return;
    setState(() {
      int currentQty = _cart[productId] ?? 0;
      int newQty = currentQty + quantityToAdd;
      if (newQty <= availableStock) {
        _cart[productId] = newQty;
        _cartDetails[productId] = {'name': name, 'price': price, 'stock': availableStock};
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hanya bisa menambahkan ${availableStock - currentQty} item lagi.')),
        );
      }
      _calculateTotal();
    });
  }

  void _editCartItemQuantity(int productId, int newQuantity) {
    setState(() {
      final detail = _cartDetails[productId]!;
      int availableStock = detail['stock'];
      if (newQuantity <= 0) {
        _cart.remove(productId);
        _cartDetails.remove(productId);
      } else if (newQuantity <= availableStock) {
        _cart[productId] = newQuantity;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maksimum stok ${detail['name']} adalah $availableStock.')),
        );
      }
      _calculateTotal();
    });
  }

  void _removeCartItem(int productId) {
    setState(() {
      _cart.remove(productId);
      _cartDetails.remove(productId);
      _calculateTotal();
    });
  }

  void _showQuantityDialog(int productId, String name, int price, int stock) {
    _qtyController.text = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Tambah $name'),
          content: TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Jumlah (Max $stock)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(_qtyController.text) ?? 0;
                if (qty > 0) {
                  _updateCart(productId, name, price, stock, qty);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Masukkan jumlah yang valid.')),
                  );
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

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
                        child: Text('Keranjang Anda kosong.', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _cart.length,
                          itemBuilder: (context, index) {
                            int productId = _cart.keys.elementAt(index);
                            int quantity = _cart[productId]!;
                            var detail = _cartDetails[productId]!;
                            int price = detail['price'];

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(detail['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${rupiahFormatter.format(price)} x $quantity = ${rupiahFormatter.format(price * quantity)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                                    onPressed: () => setModalState(() => _editCartItemQuantity(productId, quantity - 1)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                    onPressed: () => setModalState(() => _removeCartItem(productId)),
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
                        const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          rupiahFormatter.format(_totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
            ElevatedButton.icon(
              onPressed: _cart.isNotEmpty
                  ? () {
                      Navigator.of(context).pop();
                      _navigateToPayment();
                    }
                  : null,
              icon: const Icon(Icons.payment),
              label: const Text('Bayar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }

  void _navigateToPayment() async {
    Map<int, int> cartToProcess = Map.from(_cart);
    Map<int, Map<String, dynamic>> detailsToProcess = Map.from(_cartDetails);
    double totalAmount = _totalPrice;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BayarPage(
          cart: cartToProcess,
          cartDetails: detailsToProcess,
          total: totalAmount,
          rupiahFormatter: rupiahFormatter,
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _cart.clear();
        _cartDetails.clear();
        _totalPrice = 0.0;
      });
      _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran berhasil! Stok diperbarui.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = _cart.values.fold(0, (sum, element) => sum + element);

    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text('Tidak ada produk tersedia.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              int productId = product['id'] as int;
              String nama = product['nama'] as String;
              int harga = product['harga'] as int;
              int stock = product['stock'] as int? ?? 0;
              bool isProductInCart = _cart.containsKey(productId);

              return Card(
                child: ListTile(
                  title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: rupiahFormatter.format(harga),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: '  •  Stok: $stock', style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  trailing: stock > 0
                      ? ElevatedButton.icon(
                          onPressed: () => _showQuantityDialog(productId, nama, harga, stock),
                          icon: Icon(isProductInCart ? Icons.edit_note : Icons.add_shopping_cart, size: 18),
                          label: Text(
                            isProductInCart ? 'Qty (${_cart[productId]})' : 'Tambah',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isProductInCart ? AppColors.accentDark : AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('HABIS', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
          ),
          child: ElevatedButton.icon(
            onPressed: _showCartDialog,
            icon: const Icon(Icons.shopping_cart),
            label: Text(
              'Keranjang  •  ${rupiahFormatter.format(_totalPrice)}  •  $totalItems Item',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      ),
    );
  }
}
