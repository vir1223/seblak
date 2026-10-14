import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/theme/app_theme.dart';
import 'detail_resi_page.dart';

class ResiPage extends StatefulWidget {
  const ResiPage({super.key});

  @override
  State<ResiPage> createState() => _ResiPageState();
}

class _ResiPageState extends State<ResiPage> {
  final rupiahFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = DatabaseHelper.instance.getOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => _loadOrders(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Center(child: Text('Belum ada transaksi tercatat.', style: TextStyle(color: AppColors.textSecondary))),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final orderId = order['id'] as int;
                final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                final amountPaid = (order['amount_paid'] as num?)?.toDouble() ?? 0.0;

                final orderDateRaw = order['order_date'] as String?;
                final orderDate = orderDateRaw != null
                    ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(orderDateRaw))
                    : 'Tanggal Tidak Diketahui';

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentLight,
                      child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
                    ),
                    title: Text('Order #$orderId', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orderDate, style: const TextStyle(color: AppColors.textSecondary)),
                        Text(
                          'Total: ${rupiahFormatter.format(totalAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    trailing: Text(
                      'Bayar\n${rupiahFormatter.format(amountPaid)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DetailResiPage(orderId: orderId)));
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
