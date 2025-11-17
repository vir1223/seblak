import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path/path.dart' as path; 

// --- ENUM UNTUK FILTER WAKTU ---
enum ReportPeriod { today, week, month }

class TransactionSummary {
  final String id;
  final DateTime date;
  final double totalAmount;

  TransactionSummary({required this.id, required this.date, required this.totalAmount});
}

class LaporPage extends StatefulWidget {
  const LaporPage({super.key});

  @override
  State<LaporPage> createState() => _LaporPageState();
}

class _LaporPageState extends State<LaporPage> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;
  List<TransactionSummary> _transactions = [];
  double _totalSales = 0.0;
  bool _isLoading = true;

  final rupiahFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchData(_selectedPeriod);
  }

  // --- LOGIKA PENGAMBILAN DATA DARI FIRESTORE ---
  DateTime _getStartDate(ReportPeriod period) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case ReportPeriod.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case ReportPeriod.week:
        // Mulai dari hari Senin
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case ReportPeriod.month:
        startDate = DateTime(now.year, now.month, 1);
        break;
    }
    return startDate;
  }

  Future<void> _fetchData(ReportPeriod period) async {
    try {
      setState(() {
        _isLoading = true;
        _transactions = [];
        _totalSales = 0.0;
      });

      final startDate = _getStartDate(period);
      // Tambahkan 1 hari untuk memastikan transaksi hari ini termasuk
      final endDate = DateTime.now().add(const Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderDate', isGreaterThanOrEqualTo: startDate)
          // isLessThan digunakan untuk menghindari timezone issues
          .where('orderDate', isLessThan: endDate)
          .orderBy('orderDate', descending: true)
          .get();

      double sum = 0;
      final List<TransactionSummary> loadedTransactions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['orderDate'] as Timestamp?;
        if (timestamp == null) continue; // Skip if no orderDate
        final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

        loadedTransactions.add(TransactionSummary(
          id: doc.id,
          date: timestamp.toDate(),
          totalAmount: total,
        ));
        sum += total;
      }

      setState(() {
        _transactions = loadedTransactions;
        _totalSales = sum;
        _selectedPeriod = period;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    }
  }

  // --- LOGIKA EXPORT KE EXCEL (Diperbarui dengan Permintaan Izin Manual) ---
  Future<void> _exportToExcel() async {
    if (_transactions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data transaksi untuk diexport.')),
        );
      }
      return;
    }
    
    // --- 1. MEMINTA IZIN PENYIMPANAN KHUSUS (MANAGE_EXTERNAL_STORAGE) ---
    // Izin ini diperlukan untuk menulis ke folder Download di Android 11+
    var status = await Permission.manageExternalStorage.request();
    
    // Jika izin belum diberikan, tampilkan panduan manual
    if (!status.isGranted) {
        if (mounted) {
            // Tampilkan dialog kustom untuk mengarahkan pengguna ke Pengaturan
            await showDialog(
                context: context,
                builder: (BuildContext context) {
                    return AlertDialog(
                        title: const Text('Izin Akses Penyimpanan Diperlukan'),
                        content: const Text(
                            'Untuk menyimpan laporan ke folder Download publik, kami memerlukan izin "Akses ke semua file". Harap izinkan melalui Pengaturan Aplikasi Anda setelah menekan tombol "Buka Pengaturan".',
                        ),
                        actions: <Widget>[
                            TextButton(
                                child: const Text('Batal'),
                                onPressed: () => Navigator.of(context).pop(),
                            ),
                            TextButton(
                                child: const Text('Buka Pengaturan'),
                                onPressed: () {
                                    Navigator.of(context).pop();
                                    openAppSettings(); // Buka halaman pengaturan izin aplikasi
                                },
                            ),
                        ],
                    );
                },
            );
        }
        // Setelah dialog ditutup, periksa lagi status izin
        status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Izin penyimpanan masih ditolak. Tidak dapat menyimpan file.')),
                );
            }
            return;
        }
    }


    try {
      // 2. Buat Workbook Excel 
      final excel.Workbook workbook = excel.Workbook();
      final excel.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Laporan Penjualan';

      // 3. Header Laporan
      final periodText = _selectedPeriod.toString().split('.').last.toUpperCase();
      final headerRange = sheet.getRangeByName('A1:C1'); 
      headerRange.setText('LAPORAN PENJUALAN - $periodText');
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.fontSize = 14;
      headerRange.merge();
      
      // 4. Header Kolom
      sheet.getRangeByName('A3').setText('TANGGAL');
      sheet.getRangeByName('B3').setText('ORDER ID');
      sheet.getRangeByName('C3').setText('JUMLAH PENJUALAN');
      sheet.getRangeByName('A3:C3').cellStyle.bold = true;
      
      // 5. Isi Data
      int rowIndex = 4;
      for (var trx in _transactions) {
        sheet.getRangeByIndex(rowIndex, 1).setText(DateFormat('dd MMM yyyy, HH:mm').format(trx.date));
        sheet.getRangeByIndex(rowIndex, 2).setText(trx.id);
        // Atur format angka ke Rupiah di Excel (opsional, untuk tampilan lebih baik)
        sheet.getRangeByIndex(rowIndex, 3).numberFormat = 'Rp #,##0'; 
        sheet.getRangeByIndex(rowIndex, 3).setNumber(trx.totalAmount);
        rowIndex++;
      }

      // 6. Baris Total (Sum)
      sheet.getRangeByIndex(rowIndex + 1, 2).setText('TOTAL KESELURUHAN');
      sheet.getRangeByIndex(rowIndex + 1, 2).cellStyle.bold = true;
      sheet.getRangeByIndex(rowIndex + 1, 3).numberFormat = 'Rp #,##0'; // Format Rupiah
      sheet.getRangeByIndex(rowIndex + 1, 3).setNumber(_totalSales);
      sheet.getRangeByIndex(rowIndex + 1, 3).cellStyle.bold = true;

      // Auto-fit kolom
      // PERBAIKAN ERROR: Mengganti getRangeByName('A:C').autoFitColumns() yang bermasalah 
      // dengan panggilan autoFitColumn individual (kolom 1, 2, 3).
      sheet.autoFitColumn(1); 
      sheet.autoFitColumn(2); 
      sheet.autoFitColumn(3); 
      // sheet.getRangeByName('A:C').autoFitColumns(); // Baris yang menyebabkan error
      

      // 7. Simpan File
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose(); 
// ... (lanjutkan sisa kode)
      // Dapatkan path penyimpanan Download
      final directory = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD); // Menggunakan konstanta yang lebih aman

      final fileName = 'LaporanPenjualan_${periodText}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File(path.join(directory, fileName));
      
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laporan berhasil disimpan di: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export Excel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (widget build tetap sama)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _transactions.isEmpty && !_isLoading ? null : _exportToExcel,
            tooltip: 'Export ke Excel',
          ),
        ],
      ),
      body: Column(
        children: [
          // --- FILTER WAKTU (Dropdown) ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<ReportPeriod>(
              value: _selectedPeriod,
              onChanged: (ReportPeriod? newValue) {
                if (newValue != null) {
                  _fetchData(newValue);
                }
              },
              items: ReportPeriod.values.map((ReportPeriod period) {
                return DropdownMenuItem<ReportPeriod>(
                  value: period,
                  child: Text(
                    period.toString().split('.').last.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),

          // --- RINGKASAN TOTAL PENJUALAN ---
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: Colors.indigo.shade50,
            child: ListTile(
              title: const Text('TOTAL PENJUALAN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
              trailing: Text(
                _isLoading ? '...' : rupiahFormatter.format(_totalSales),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green),
              ),
            ),
          ),
          
          const Divider(),

          // --- DAFTAR TRANSAKSI ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(child: Text('Tidak ada transaksi pada periode ${DateFormat('dd MMM').format(_getStartDate(_selectedPeriod))}'))
                    : ListView.builder(
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final trx = _transactions[index];
                          return ListTile(
                            title: Text('Order ID: ${trx.id.substring(0, 8)}...'),
                            subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(trx.date)),
                            trailing: Text(
                              rupiahFormatter.format(trx.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}