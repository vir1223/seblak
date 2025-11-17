import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'detail_resi_page.dart'; // Import halaman detail resi

class ResiPage extends StatelessWidget {
   ResiPage({super.key});

  final rupiahFormatter =  NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Transaksi'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('orderDate', descending: true) // Urutkan dari yang terbaru
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada transaksi tercatat.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final orderDoc = snapshot.data!.docs[index];
              final data = orderDoc.data() as Map<String, dynamic>;
              
              final orderId = orderDoc.id;
              final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
              final amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
              
              // Ambil orderDate dan format
              final orderDateTimestamp = data['orderDate'] as Timestamp?;
              final orderDate = orderDateTimestamp != null
                  ? DateFormat('dd MMM yyyy, HH:mm').format(orderDateTimestamp.toDate())
                  : 'Tanggal Tidak Diketahui';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: ListTile(
                  title: Text(
                    'Order ID: #${orderId.substring(0, 8)}...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tanggal: $orderDate'),
                      Text(
                        'Total: ${rupiahFormatter.format(totalAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  trailing: Text(
                    'Bayar: ${rupiahFormatter.format(amountPaid)}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    // Navigasi ke halaman detail resi
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailResiPage(orderId: orderId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}