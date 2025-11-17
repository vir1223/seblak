import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  TextEditingController namaController = TextEditingController();
  TextEditingController stockController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgoround color orange
      appBar: AppBar(
        title: Text('Stock Page'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('created_at')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No products available'));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final products = snapshot.data!.docs;
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  tileColor: Colors.white,
                  title: Text(product['nama']),
                  subtitle: Text('Stock: ${product['stock']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.orange),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('Tambah Stock'),
                                content: Column(
                                  children: [
                                    TextFormField(
                                      keyboardType: TextInputType.number,
                                      controller: stockController,
                                      decoration: InputDecoration(
                                        labelText: 'Jumlah Stock',
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Close'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      try {
                                        num stock = num.parse(
                                          stockController.text,
                                        );
                                        stock = product['stock'] + stock;
                                        FirebaseFirestore.instance
                                            .collection('products')
                                            .doc(product.id)
                                            .update({
                                              'stock': stock,
                                            });
                                        setState(() {
                                          namaController.clear();
                                          stockController.clear();
                                        });
                                      } catch (e) {
                                        if (e is FormatException) {
                                          // Tampilkan pesan kesalahan jika input bukan angka valid
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Hanya masukkan bilangan bulat (angka) untuk stock.',
                                              ),
                                            ),
                                          );
                                        } else {
                                          // Tangani kesalahan lainnya jika perlu
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Terjadi kesalahan: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      Navigator.pop(context);
                                    },
                                    child: Text('Update'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.remove, color: Colors.orange),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('Tambah Stock'),
                                content: Column(
                                  children: [
                                    TextFormField(
                                      keyboardType: TextInputType.number,
                                      controller: stockController,
                                      decoration: InputDecoration(
                                        labelText: 'Jumlah Stock',
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Close'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      try {
                                        num stock = num.parse(
                                          stockController.text,
                                        );
                                        stock = product['stock'] - stock;
                                        FirebaseFirestore.instance
                                            .collection('products')
                                            .doc(product.id)
                                            .update({
                                              'stock': stock,
                                            });
                                        setState(() {
                                          namaController.clear();
                                          stockController.clear();
                                        });
                                      } catch (e) {
                                        if (e is FormatException) {
                                          // Tampilkan pesan kesalahan jika input bukan angka valid
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Hanya masukkan bilangan bulat (angka) untuk stock.',
                                              ),
                                            ),
                                          );
                                        } else {
                                          // Tangani kesalahan lainnya jika perlu
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Terjadi kesalahan: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      Navigator.pop(context);
                                    },
                                    child: Text('Update'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(context: context, builder: (context) {
                            return AlertDialog(
                              title: Text('Hapus Produk'),
                              content: Text(
                                'Apakah Anda yakin ingin menghapus stock produk ini?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    FirebaseFirestore.instance
                                        .collection('products')
                                        .doc(product.id)
                                        .update(
                                          {'stock': 0},
                                        );
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Hapus'),
                                ),
                              ],
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
