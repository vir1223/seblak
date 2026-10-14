import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/theme/app_theme.dart';
import 'dart:typed_data';

class DetailResiPage extends StatefulWidget {
  final int orderId;
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

  late Future<Map<String, dynamic>?> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = _loadOrderDetail();
  }

  // Menggabungkan data header order ('orders') dan detail item
  // ('order_items') menjadi satu Map, supaya bentuknya mirip dengan
  // dokumen Firestore lama (memudahkan fungsi cetak & tampilan di
  // bawah tetap sama).
  Future<Map<String, dynamic>?> _loadOrderDetail() async {
    final order = await DatabaseHelper.instance.getOrderById(widget.orderId);
    if (order == null) return null;

    final items = await DatabaseHelper.instance.getOrderItems(widget.orderId);

    return {
      'totalAmount': order['total_amount'],
      'amountPaid': order['amount_paid'],
      'change': order['change_amount'],
      'paymentMethod': order['payment_method'],
      'orderDate': order['order_date'], // String ISO8601
      'orderItems': items
          .map((item) => {
                'name': item['name'],
                'quantity': item['quantity'],
                'subtotal': item['subtotal'],
              })
          .toList(),
    };
  }

  // Fungsi untuk memindai perangkat Bluetooth
  void _startScan(BuildContext context, Map<String, dynamic> data) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final List<CustomDevice> devices = [];

      await for (final state in FlutterBluetoothPrinter.discovery) {
        if (state is DiscoveryResult) {
          devices.clear();
          devices.addAll(state.devices.map((d) => CustomDevice(
                name: d.name ?? 'Unknown Device',
                address: d.address,
              )));
          break;
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
                  leading: const Icon(Icons.print, color: AppColors.primary),
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
              child: const Text('Batal'),
            ),
          ],
        ),
      );

      if (selected != null) {
        setState(() {
          _selectedDeviceAddress = selected.address;
          _selectedDeviceName = selected.name;
        });
        await _printReceipt(data);
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
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cetak Gagal: Koneksi/Printer bermasalah.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saat mencetak: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // Fungsi helper untuk membuat data resi (raw bytes)
  List<int> _buildReceiptData(Map<String, dynamic> data) {
    List<int> bytes = [];

    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final change = (data['change'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = data['paymentMethod'] as String? ?? 'N/A';
    final orderItems = (data['orderItems'] as List<dynamic>?)
            ?.map((item) => item as Map<String, dynamic>)
            .toList() ??
        [];

    final orderDateRaw = data['orderDate'] as String?;
    final orderDate = orderDateRaw != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(orderDateRaw))
        : 'N/A';

    // --- ESC/POS COMMANDS ---
    bytes.add(0x1B);
    bytes.add(0x40); // Inisialisasi/Reset Printer

    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x01); // Align Center
    bytes.add(0x1D);
    bytes.add(0x21);
    bytes.add(0x01); // Double Height
    bytes.addAll('SEBLAK APP\n'.codeUnits);

    bytes.add(0x1D);
    bytes.add(0x21);
    bytes.add(0x00); // Normal Font
    bytes.addAll('STRUK PEMBAYARAN\n\n'.codeUnits);

    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x00); // Align Left
    bytes.addAll('Order ID: #${widget.orderId}\n'.codeUnits);
    bytes.addAll('Tanggal : $orderDate\n'.codeUnits);
    bytes.addAll('Metode  : $paymentMethod\n'.codeUnits);
    bytes.addAll('================================\n'.codeUnits);

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

    bytes.addAll('================================\n'.codeUnits);

    bytes.add(0x1B);
    bytes.add(0x45);
    bytes.add(0x01); // Enable Bold
    bytes.addAll('TOTAL :'.padRight(20).codeUnits);
    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x02); // Align Right
    bytes.addAll('${_formatPrice(totalAmount)}\n'.codeUnits);
    bytes.add(0x1B);
    bytes.add(0x45);
    bytes.add(0x00); // Disable Bold
    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x00); // Align Left

    bytes.addAll('Bayar ($paymentMethod): '.padRight(32).codeUnits);
    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x02); // Align Right
    bytes.addAll('${_formatPrice(amountPaid)}\n'.codeUnits);
    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x00); // Align Left

    bytes.add(0x1B);
    bytes.add(0x45);
    bytes.add(0x01); // Enable Bold
    bytes.addAll('KEMBALIAN : '.padRight(32).codeUnits);
    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x02); // Align Right
    bytes.addAll('${_formatPrice(change)}\n'.codeUnits);
    bytes.add(0x1B);
    bytes.add(0x45);
    bytes.add(0x00); // Disable Bold
    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x00); // Align Left

    bytes.addAll('================================\n'.codeUnits);

    bytes.add(0x1B);
    bytes.add(0x61);
    bytes.add(0x01); // Align Center
    bytes.addAll('\nTerima Kasih!\nSelamat Menikmati\n\n'.codeUnits);

    bytes.addAll('\n\n\n\n'.codeUnits);
    bytes.add(0x1D);
    bytes.add(0x56);
    bytes.add(0x01); // Full Cut

    return bytes;
  }

  String _formatPrice(double price) {
    return rupiahFormatter.format(price).replaceAll('Rp ', '');
  }

  @override
  Widget build(BuildContext context) {
    final isDeviceSelected = _selectedDeviceAddress != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Resi'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Resi tidak ditemukan.'));
          }

          final data = snapshot.data!;
          final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
          final change = (data['change'] as num?)?.toDouble() ?? 0.0;
          final paymentMethod = data['paymentMethod'] as String? ?? 'N/A';
          final orderItems = (data['orderItems'] as List<dynamic>?)
                  ?.map((item) => item as Map<String, dynamic>)
                  .toList() ??
              [];

          final orderDateRaw = data['orderDate'] as String?;
          final orderDate = orderDateRaw != null
              ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(orderDateRaw))
              : 'N/A';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Card(
                  elevation: 4,
                  color: AppColors.accentLight,
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
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const Divider(thickness: 2),
                        const SizedBox(height: 10),
                        Text('Order ID: #${widget.orderId}'),
                        Text('Tanggal: $orderDate'),
                        Text('Metode: $paymentMethod'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                Card(
                  elevation: 4,
                  color: AppColors.successLight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSummaryRow('TOTAL', rupiahFormatter.format(totalAmount), isBold: true),
                        const Divider(),
                        _buildSummaryRow('Bayar ($paymentMethod)', rupiahFormatter.format(amountPaid)),
                        const Divider(),
                        _buildSummaryRow('KEMBALIAN', rupiahFormatter.format(change),
                            isBold: true, color: AppColors.success),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Card(
                  color: isDeviceSelected ? AppColors.successLight : AppColors.border.withOpacity(0.3),
                  child: ListTile(
                    leading: Icon(
                      isDeviceSelected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isDeviceSelected ? AppColors.success : AppColors.danger,
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
                          : 'Klik tombol cetak untuk memilih printer',
                    ),
                    trailing: isDeviceSelected
                        ? IconButton(
                            icon: const Icon(Icons.close, color: AppColors.danger),
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
                ElevatedButton.icon(
                  onPressed: _isScanning
                      ? null
                      : (isDeviceSelected ? () => _printReceipt(data) : () => _startScan(context, data)),
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.print, size: 28),
                  label: Text(
                    _isScanning ? 'Memindai Printer...' : (isDeviceSelected ? 'CETAK ULANG' : 'PILIH & CETAK RESI'),
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDeviceSelected ? AppColors.primaryDark : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: AppColors.accentLight,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: AppColors.accentDark, size: 20),
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

class CustomDevice {
  final String name;
  final String address;
  CustomDevice({required this.name, required this.address});
}
