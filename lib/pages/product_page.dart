import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  TextEditingController namaController = TextEditingController();
  TextEditingController hargaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgoround color orange
      appBar: AppBar(
        title: Text('Product Page'),
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
                  subtitle: Text('Harga: ${product['harga']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.orange),
                        onPressed: () {
                          namaController.text = product['nama'];
                          hargaController.text = product['harga'].toString();
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('Edit Product'),
                                content: Column(
                                  children: [
                                    TextFormField(
                                      controller: namaController,
                                      decoration: InputDecoration(
                                        labelText: 'Nama product/bahan',
                                      ),
                                    ),
                                    TextFormField(
                                      keyboardType: TextInputType.number,
                                      controller: hargaController,
                                      decoration: InputDecoration(
                                        labelText: 'Harga',
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
                                        int harga = int.parse(
                                          hargaController.text,
                                        );
                                        FirebaseFirestore.instance
                                            .collection('products')
                                            .doc(product.id)
                                            .update({
                                              'nama': namaController.text,
                                              'harga': harga,
                                            });
                                        setState(() {
                                          namaController.clear();
                                          hargaController.clear();
                                        });
                                      } catch (e) {
                                        if (e is FormatException) {
                                          // Tampilkan pesan kesalahan jika input bukan angka valid
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Hanya masukkan bilangan bulat (angka) untuk harga.',
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
                                        .delete();
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Add Product'),
                content: Column(
                  children: [
                    TextFormField(
                      controller: namaController,
                      decoration: InputDecoration(
                        labelText: 'Nama product/bahan',
                      ),
                    ),
                    TextFormField(
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Stok tidak boleh kosong.';
                        }
                        // Penting: Validasi apakah input adalah angka valid
                        if (int.tryParse(value) == null) {
                          return 'Hanya masukkan bilangan bulat (angka).';
                        }
                        return null;
                      },
                      controller: hargaController,
                      decoration: InputDecoration(labelText: 'Harga'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                          namaController.clear();
                          hargaController.clear();
                        });
                      Navigator.of(context).pop();
                    },
                    child: Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      try {
                        int harga = int.parse(hargaController.text);
                        FirebaseFirestore.instance.collection('products').add({
                          'nama': namaController.text,
                          'harga': harga,
                          'stock': 0,
                          'created_at': Timestamp.now(),
                        });
                        setState(() {
                          namaController.clear();
                          hargaController.clear();
                        });
                      } catch (e) {
                        if (e is FormatException) {
                          // Tampilkan pesan kesalahan jika input bukan angka valid
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Hanya masukkan bilangan bulat (angka) untuk harga.',
                              ),
                            ),
                          );
                        } else {
                          // Tangani kesalahan lainnya jika perlu
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Terjadi kesalahan: $e')),
                          );
                        }
                      }

                      Navigator.pop(context);
                    },
                    child: Text('Add'),
                  ),
                ],
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
