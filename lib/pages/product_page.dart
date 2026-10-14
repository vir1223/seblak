import 'package:flutter/material.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/theme/app_theme.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final TextEditingController namaController = TextEditingController();
  final TextEditingController hargaController = TextEditingController();

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
    namaController.dispose();
    hargaController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete(String nama) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Hapus Produk?'),
              content: Text('Yakin ingin menghapus "$nama"? Tindakan ini tidak bisa dibatalkan.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  child: const Text('Hapus'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showEditDialog(Map<String, dynamic> product) {
    namaController.text = product['nama'];
    hargaController.text = product['harga'].toString();
    final productId = product['id'] as int;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama product/bahan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                keyboardType: TextInputType.number,
                controller: hargaController,
                decoration: const InputDecoration(labelText: 'Harga'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                try {
                  int harga = int.parse(hargaController.text);
                  await DatabaseHelper.instance.updateProduct(productId, nama: namaController.text, harga: harga);
                  namaController.clear();
                  hargaController.clear();
                  if (context.mounted) Navigator.pop(context);
                  _loadProducts();
                } catch (e) {
                  final message = e is FormatException
                      ? 'Hanya masukkan bilangan bulat (angka) untuk harga.'
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

  void _showAddDialog() {
    namaController.clear();
    hargaController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama product/bahan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                keyboardType: TextInputType.number,
                controller: hargaController,
                decoration: const InputDecoration(labelText: 'Harga'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                namaController.clear();
                hargaController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  int harga = int.parse(hargaController.text);
                  await DatabaseHelper.instance.insertProduct(namaController.text, harga);
                  namaController.clear();
                  hargaController.clear();
                  if (context.mounted) Navigator.pop(context);
                  _loadProducts();
                } catch (e) {
                  final message = e is FormatException
                      ? 'Hanya masukkan bilangan bulat (angka) untuk harga.'
                      : 'Terjadi kesalahan: $e';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
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
                    'Geser produk ke kiri untuk menghapus',
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

                    return Dismissible(
                      key: ValueKey('product_$productId'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(nama),
                      onDismissed: (_) async {
                        await DatabaseHelper.instance.deleteProduct(productId);
                        _loadProducts();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"$nama" berhasil dihapus.')),
                          );
                        }
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
                            Icon(Icons.delete_outline, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Harga: Rp ${product['harga']}',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                            onPressed: () => _showEditDialog(product),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
