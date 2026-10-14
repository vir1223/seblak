import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/theme/app_theme.dart';

enum ReportPeriod { today, week, month }

class TransactionSummary {
  final int id;
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

  DateTime _getStartDate(ReportPeriod period) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case ReportPeriod.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case ReportPeriod.week:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case ReportPeriod.month:
        startDate = DateTime(now.year, now.month, 1);
        break;
    }
    return startDate;
  }

  // Query ke SQLite via DatabaseHelper.getOrders(startDate, endDate),
  // menggantikan query Firestore .where('orderDate', ...).
  Future<void> _fetchData(ReportPeriod period) async {
    try {
      setState(() {
        _isLoading = true;
        _transactions = [];
        _totalSales = 0.0;
      });

      final startDate = _getStartDate(period);
      final endDate = DateTime.now().add(const Duration(days: 1));

      final orders = await DatabaseHelper.instance.getOrders(
        startDate: startDate,
        endDate: endDate,
      );

      double sum = 0;
      final List<TransactionSummary> loadedTransactions = [];

      for (var order in orders) {
        final orderDateRaw = order['order_date'] as String?;
        if (orderDateRaw == null) continue;
        final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;

        loadedTransactions.add(TransactionSummary(
          id: order['id'] as int,
          date: DateTime.parse(orderDateRaw),
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

  Future<void> _exportToExcel() async {
    if (_transactions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data transaksi untuk diexport.')),
        );
      }
      return;
    }

    try {
      final status = await Permission.storage.request();

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin penyimpanan ditolak. Tidak dapat menyimpan file.')),
          );
        }
        return;
      }

      final excel.Workbook workbook = excel.Workbook();
      final excel.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Laporan Penjualan';

      final periodText = _selectedPeriod.toString().split('.').last.toUpperCase();
      final headerRange = sheet.getRangeByName('A1:C1');
      headerRange.setText('LAPORAN PENJUALAN - $periodText');
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.fontSize = 14;
      headerRange.merge();

      sheet.getRangeByName('A3').setText('TANGGAL');
      sheet.getRangeByName('B3').setText('ORDER ID');
      sheet.getRangeByName('C3').setText('JUMLAH PENJUALAN');
      sheet.getRangeByName('A3:C3').cellStyle.bold = true;

      int rowIndex = 4;
      for (var trx in _transactions) {
        sheet.getRangeByIndex(rowIndex, 1).setText(DateFormat('dd MMM yyyy, HH:mm').format(trx.date));
        sheet.getRangeByIndex(rowIndex, 2).setText('#${trx.id}');
        sheet.getRangeByIndex(rowIndex, 3).numberFormat = 'Rp #,##0';
        sheet.getRangeByIndex(rowIndex, 3).setNumber(trx.totalAmount);
        rowIndex++;
      }

      sheet.getRangeByIndex(rowIndex + 1, 2).setText('TOTAL KESELURUHAN');
      sheet.getRangeByIndex(rowIndex + 1, 2).cellStyle.bold = true;
      sheet.getRangeByIndex(rowIndex + 1, 3).numberFormat = 'Rp #,##0';
      sheet.getRangeByIndex(rowIndex + 1, 3).setNumber(_totalSales);
      sheet.getRangeByIndex(rowIndex + 1, 3).cellStyle.bold = true;

      sheet.getRangeByName('A:C').autoFitColumns();

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await ExternalPath.getExternalStoragePublicDirectory("Download");

      final fileName =
          'LaporanPenjualan_${periodText}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File(path.join(directory, fileName));

      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laporan berhasil disimpan di: ${file.path}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export Excel: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _transactions.isEmpty && !_isLoading ? null : _exportToExcel,
            tooltip: 'Export ke Excel',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                DropdownButton<ReportPeriod>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  onChanged: (ReportPeriod? newValue) {
                    if (newValue != null) _fetchData(newValue);
                  },
                  items: ReportPeriod.values.map((ReportPeriod period) {
                    const labels = {
                      ReportPeriod.today: 'Hari Ini',
                      ReportPeriod.week: 'Minggu Ini',
                      ReportPeriod.month: 'Bulan Ini',
                    };
                    return DropdownMenuItem<ReportPeriod>(
                      value: period,
                      child: Text(
                        labels[period]!,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Card(
            color: AppColors.successLight,
            child: ListTile(
              title: const Text('TOTAL PENJUALAN', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
              trailing: Text(
                _isLoading ? '...' : rupiahFormatter.format(_totalSales),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.success),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _transactions.isEmpty
                    ? Center(child: Text('Tidak ada transaksi pada periode ${DateFormat('dd MMM').format(_getStartDate(_selectedPeriod))}'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final trx = _transactions[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_outlined, color: AppColors.primary),
                              title: Text('Order #${trx.id}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                DateFormat('dd MMM yyyy, HH:mm').format(trx.date),
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              trailing: Text(
                                rupiahFormatter.format(trx.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
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
