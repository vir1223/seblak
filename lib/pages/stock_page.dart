import 'package:flutter/material.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/theme/app_theme.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController stockController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _productsFuture = DatabaseHelper.instance.getAllProducts();
    });
  }

  @override
  void dispose() {
    stockController.dispose();
    super.dispose();
  }

  // Catatan: di halaman Stock, "hapus" berarti mengatur ulang stok produk
  // ke 0 (bukan menghapus produknya dari katalog) -- perilaku ini sama
  // seperti versi sebelumnya, cuma sekarang dipicu lewat gesture geser.
  Future<bool> _confirmResetStock(String nama) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Reset Stok?'),
              content: Text('Stok "$nama" akan diatur ulang menjadi 0. Lanjutkan?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  child: const Text('Reset ke 0'),
                ),
              ],
            );
          },
        ) ??
        false;
    return confirmed;
  }

  void _showAdjustDialog({
    required int productId,
    required String nama,
    required int currentStock,
    required bool isAdding,
  }) {
    stockController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isAdding ? 'Tambah Stock' : 'Kurangi Stock'),
          content: TextFormField(
            keyboardType: TextInputType.number,
            controller: stockController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Jumlah Stock'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final amount = int.parse(stockController.text);
                  final newStock = isAdding ? currentStock + amount : currentStock - amount;
                  await DatabaseHelper.instance.updateStock(productId, newStock < 0 ? 0 : newStock);
                  stockController.clear();
                  if (context.mounted) Navigator.pop(context);
                  _loadProducts();
                } catch (e) {
                  final message = e is FormatException
                      ? 'Hanya masukkan bilangan bulat (angka) untuk stock.'
                      : 'Terjadi kesalahan: $e';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.accentLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.swipe_left_alt_rounded, size: 18, color: AppColors.accentDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Geser produk ke kiri untuk reset stok ke 0',
                    style: TextStyle(fontSize: 12, color: AppColors.accentDark.withOpacity(0.9)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(child: Text('No products available'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final productId = product['id'] as int;
                    final nama = product['nama'] as String;
                    final currentStock = product['stock'] as int;
                    final isLow = currentStock <= 5;

                    return Dismissible(
                      key: ValueKey('stock_$productId'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final confirmed = await _confirmResetStock(nama);
                        if (confirmed) {
                          await DatabaseHelper.instance.updateStock(productId, 0);
                          _loadProducts();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Stok "$nama" direset ke 0.')),
                            );
                          }
                        }
                        // Selalu false: produk tetap tampil di list (cuma stoknya berubah),
                        // bukan hilang dari daftar seperti penghapusan produk.
                        return false;
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restart_alt_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Reset ke 0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Stok: $currentStock',
                              style: TextStyle(
                                color: isLow ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                                onPressed: () => _showAdjustDialog(
                                  productId: productId,
                                  nama: nama,
                                  currentStock: currentStock,
                                  isAdding: false,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                                onPressed: () => _showAdjustDialog(
                                  productId: productId,
                                  nama: nama,
                                  currentStock: currentStock,
                                  isAdding: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
