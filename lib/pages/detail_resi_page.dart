// File: detail_resi_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart'; 
import 'dart:typed_data'; 

class DetailResiPage extends StatefulWidget {
  final String orderId;
  const DetailResiPage({super.key, required this.orderId});

  @override
  State<DetailResiPage> createState() => _DetailResiPageState();
}

class _DetailResiPageState extends State<DetailResiPage> {
  
  String? _selectedDeviceAddress; 
  String? _selectedDeviceName; 
  
  bool _isScanning = false;

  final rupiahFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
  }
  
  // Fungsi helper baru untuk membuat baris dengan teks kiri dan nilai kanan
  String _padLine(String left, String right, int totalWidth) {
    // Hitung berapa banyak spasi yang dibutuhkan
    int spacesNeeded = totalWidth - left.length - right.length;
    // Pastikan tidak ada nilai negatif untuk menghindari crash
    String padding = ' ' * (spacesNeeded > 0 ? spacesNeeded : 1); 
    return '$left$padding$right\n';
  }

  // Fungsi untuk memindai perangkat Bluetooth
  void _startScan(BuildContext context, Map<String, dynamic> data) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final List<CustomDevice> devices = [];

      // Menggunakan stream discovery untuk menemukan perangkat
      await for (final state in FlutterBluetoothPrinter.discovery) {
        if (state is DiscoveryResult) {
          devices.clear();
          devices.addAll(state.devices.map((d) =>
            CustomDevice(
              name: d.name ?? 'Unknown Device',
              address: d.address,
            )
          ));
          break; // Ambil hasil pertama dan hentikan
        }
      }

      setState(() {
        _isScanning = false;
      });

      if (devices.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada printer Bluetooth ditemukan.\nPastikan Bluetooth aktif.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Tampilkan dialog pilihan printer
      if (!mounted) return;

      final selected = await showDialog<CustomDevice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pilih Printer Termal'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.print, color: Colors.blue),
                  title: Text(devices[index].name),
                  subtitle: Text(devices[index].address),
                  onTap: () => Navigator.of(ctx).pop(devices[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal')
            ),
          ],
        ),
      );

      if (selected != null) {
        setState(() {
          _selectedDeviceAddress = selected.address;
          _selectedDeviceName = selected.name;
        });
        await _printReceipt(data); // Panggil cetak setelah device dipilih
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal pemindaian: $e')),
        );
      }
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Fungsi untuk mencetak resi ke printer thermal
  Future<void> _printReceipt(Map<String, dynamic> data) async {
    if (_selectedDeviceAddress == null) {
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pilih printer terlebih dahulu.')),
        );
      }
      return;
    }

    try {
      List<int> receiptDataList = _buildReceiptData(data); 
      // Konversi List<int> ke Uint8List (Diperlukan oleh API printBytes)
      Uint8List receiptData = Uint8List.fromList(receiptDataList); 

      final bool success = await FlutterBluetoothPrinter.printBytes(
        address: _selectedDeviceAddress!, 
        data: receiptData, 
        keepConnected: false, 
      );

      if (mounted) { 
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resi berhasil dicetak!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cetak Gagal: Koneksi/Printer bermasalah.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saat mencetak: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Fungsi helper untuk membuat data resi (raw bytes) - BAGIAN INI TELAH DIUBAH
  List<int> _buildReceiptData(Map<String, dynamic> data) {
    List<int> bytes = [];

    // ESC/POS Commands (Kode mentah untuk printer thermal)
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final change = (data['change'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = data['paymentMethod'] as String? ?? 'N/A';
    final orderItems = (data['orderItems'] as List<dynamic>?)
        ?.map((item) => item as Map<String, dynamic>)
        .toList() ?? [];

    final orderDateTimestamp = data['orderDate'] as Timestamp?;
    final orderDate = orderDateTimestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(orderDateTimestamp.toDate())
        : 'N/A';
    
    const int totalWidth = 32; // Lebar standar untuk struk thermal
    
    // --- ESC/POS COMMANDS ---
    
    // 1. Inisialisasi/Reset Printer
    bytes.add(0x1B); bytes.add(0x40); 

    // 2. Header (Center, Double Height)
    bytes.add(0x1B); bytes.add(0x61); bytes.add(0x01); // Align Center
    bytes.add(0x1D); bytes.add(0x21); bytes.add(0x01); // Double Height
    
    bytes.addAll('SEBLAK APP\n'.codeUnits); 
    
    bytes.add(0x1D); bytes.add(0x21); bytes.add(0x00); // Normal Font
    bytes.addAll('STRUK PEMBAYARAN\n'.codeUnits);
    bytes.addAll('================================\n'.codeUnits);
    
    // 3. Info Order (Left Align)
    bytes.add(0x1B); bytes.add(0x61); bytes.add(0x00); // Align Left
    bytes.addAll('Order ID: ${widget.orderId.substring(0, 12)}\n'.codeUnits);
    bytes.addAll('Tanggal : $orderDate\n'.codeUnits);
    bytes.addAll('Metode  : $paymentMethod\n'.codeUnits);
    bytes.addAll('================================\n'.codeUnits);
    
    // 4. Detail Items
    bytes.addAll('Item             Qty   Total\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);
    
    for (var item in orderItems) {
      final name = item['name'] as String? ?? 'Item';
      final qty = item['quantity'] as int? ?? 1;
      final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
      
      String itemName = name.length > 15 ? name.substring(0, 15) : name.padRight(15);
      String qtyStr = 'x$qty'.padLeft(4);
      String priceStr = _formatPrice(subtotal).padLeft(13);

      bytes.addAll('$itemName$qtyStr$priceStr\n'.codeUnits);
    }
    
    // 5. Summary
    bytes.addAll('================================\n'.codeUnits);

    // TOTAL (Bold) - Menggunakan padding untuk Right Align (Lebih stabil)
    bytes.add(0x1B); bytes.add(0x45); bytes.add(0x01); // Enable Bold
    
    String totalLine = _padLine('TOTAL :', _formatPrice(totalAmount), totalWidth);
    bytes.addAll(totalLine.codeUnits);
    
    bytes.add(0x1B); bytes.add(0x45); bytes.add(0x00); // Disable Bold

    // Bayar - URUTAN BENAR: Harus dicetak setelah TOTAL
    String bayarLine = _padLine(
        'Bayar ($paymentMethod):', 
        _formatPrice(amountPaid), 
        totalWidth
    );
    bytes.addAll(bayarLine.codeUnits);

    // KEMBALIAN (Bold) - URUTAN BENAR: Harus dicetak setelah Bayar
    bytes.add(0x1B); bytes.add(0x45); bytes.add(0x01); // Enable Bold
    
    String changeLine = _padLine(
        'KEMBALIAN :', 
        _formatPrice(change), 
        totalWidth
    );
    bytes.addAll(changeLine.codeUnits);
    
    bytes.add(0x1B); bytes.add(0x45); bytes.add(0x00); // Disable Bold

    bytes.addAll('================================\n'.codeUnits);

    // 6. Footer
    bytes.add(0x1B); bytes.add(0x61); bytes.add(0x01); // Align Center
    bytes.addAll('\nTerima Kasih!\nSelamat Menikmati\n'.codeUnits); 

    // 7. Line Feeds and Cut
    bytes.addAll('\n\n\n\n\n\n\n\n\n\n'.codeUnits); // 6 baris kosong untuk jarak potong
    bytes.add(0x1D); bytes.add(0x56); bytes.add(0x01); // Full Cut

    return bytes;
  }

  // Helper untuk format harga tanpa "Rp "
  String _formatPrice(double price) {
    return rupiahFormatter.format(price).replaceAll('Rp ', '');
  }
  
  @override
  Widget build(BuildContext context) {
    final isDeviceSelected = _selectedDeviceAddress != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Resi'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Resi tidak ditemukan.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
          final change = (data['change'] as num?)?.toDouble() ?? 0.0;
          final paymentMethod = data['paymentMethod'] as String? ?? 'N/A';
          final orderItems = (data['orderItems'] as List<dynamic>?)
              ?.map((item) => item as Map<String, dynamic>)
              .toList() ?? [];

          final orderDateTimestamp = data['orderDate'] as Timestamp?;
          final orderDate = orderDateTimestamp != null
              ? DateFormat('dd MMM yyyy, HH:mm').format(orderDateTimestamp.toDate())
              : 'N/A';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Card Header Resi
                Card(
                  elevation: 4,
                  color: Colors.teal[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'STRUK PEMBAYARAN',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[800],
                            ),
                          ),
                        ),
                        const Divider(thickness: 2),
                        const SizedBox(height: 10),
                        Text('Order ID: #${widget.orderId.substring(0, 12)}...'),
                        Text('Tanggal: $orderDate'),
                        Text('Metode: $paymentMethod'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Daftar Item Pesanan
                const Text(
                  'Detail Pesanan:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                
                ...orderItems.map((item) {
                  final name = item['name'] as String? ?? 'Item';
                  final qty = item['quantity'] as int? ?? 1;
                  final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text('Qty: $qty'),
                      trailing: Text(
                        rupiahFormatter.format(subtotal),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
                
                const SizedBox(height: 20),
                
                // Ringkasan Pembayaran
                Card(
                  elevation: 4,
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSummaryRow('TOTAL', rupiahFormatter.format(totalAmount), isBold: true),
                        const Divider(),
                        _buildSummaryRow('Bayar ($paymentMethod)', rupiahFormatter.format(amountPaid)),
                        const Divider(),
                        _buildSummaryRow('KEMBALIAN', rupiahFormatter.format(change), 
                            isBold: true, color: Colors.green),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Status Koneksi Printer
                Card(
                  color: isDeviceSelected ? Colors.green[50] : Colors.grey[100],
                  child: ListTile(
                    leading: Icon(
                      isDeviceSelected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isDeviceSelected ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    title: Text(
                      isDeviceSelected
                          ? 'Printer Terpilih: ${_selectedDeviceName ?? "Printer"}' 
                          : 'Belum ada printer terpilih',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isDeviceSelected
                          ? _selectedDeviceAddress ?? '' 
                          : 'Klik tombol cetak untuk memilih printer'
                    ),
                    trailing: isDeviceSelected
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _selectedDeviceAddress = null;
                                _selectedDeviceName = null;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pilihan printer direset')),
                                );
                              }
                            },
                            tooltip: 'Reset Pilihan',
                          )
                        : null,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Tombol Cetak Resi
                ElevatedButton.icon(
                  onPressed: _isScanning 
                      ? null 
                      : (isDeviceSelected 
                          ? () => _printReceipt(data) 
                          : () => _startScan(context, data)),
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        ) 
                      : const Icon(Icons.print, size: 28),
                  label: Text(
                    _isScanning ? 'Memindai Printer...' 
                        : (isDeviceSelected ? 'CETAK ULANG' : 'PILIH & CETAK RESI'),
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDeviceSelected ? Colors.teal : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Info tambahan
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tombol cetak akan memindai printer jika belum ada yang terpilih, atau langsung mencetak jika sudah ada.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // Helper widget untuk baris ringkasan
  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Tambahkan helper class untuk menampung device yang ditemukan
class CustomDevice {
  final String name;
  final String address;
  CustomDevice({required this.name, required this.address});
}