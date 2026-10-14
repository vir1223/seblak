import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/pages/hutang_page.dart';
import 'package:seblak/pages/kasir_page.dart';
import 'package:seblak/pages/lapor_page.dart';
import 'package:seblak/pages/login_page.dart';
import 'package:seblak/pages/pengeluaran_page.dart';
import 'package:seblak/pages/product_page.dart';
import 'package:seblak/pages/resi_page.dart';
import 'package:seblak/pages/setting_page.dart';
import 'package:seblak/pages/stock_page.dart';
import 'package:seblak/theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _defaultStoreName = 'Kasir Seblak';
  static const int _lowStockThreshold = 5;

  String _storeName = _defaultStoreName;

  final rupiahFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  late Future<double> _dailyIncomeFuture;
  late Future<List<Map<String, dynamic>>> _lowStockFuture;
  late Future<List<Map<String, dynamic>>> _monthlySalesFuture;

  @override
  void initState() {
    super.initState();
    _loadStoreName();
    _refreshDailyIncome();
    _refreshLowStock();
    _refreshMonthlySales();
  }

  Future<void> _loadStoreName() async {
    final saved = await DatabaseHelper.instance.getSetting('store_name');
    if (!mounted) return;
    setState(() {
      _storeName = (saved != null && saved.trim().isNotEmpty) ? saved : _defaultStoreName;
    });
  }

  void _refreshDailyIncome() {
    setState(() {
      _dailyIncomeFuture = _calculateDailyIncome();
    });
  }

  void _refreshLowStock() {
    setState(() {
      _lowStockFuture = DatabaseHelper.instance.getLowStockProducts(threshold: _lowStockThreshold);
    });
  }

  void _refreshMonthlySales() {
    setState(() {
      _monthlySalesFuture = DatabaseHelper.instance.getMonthlySales(monthsBack: 6);
    });
  }

  Future<double> _calculateDailyIncome() async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      final orders = await DatabaseHelper.instance.getOrders(startDate: startDate, endDate: endDate);
      double sum = 0.0;
      for (var order in orders) {
        sum += (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
      return sum;
    } catch (e) {
      return 0.0;
    }
  }

  void _openSettingPage() async {
    await Get.to(() => const SettingPage());
    _loadStoreName();
  }

  String _formatCompactRupiah(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.soup_kitchen_rounded, size: 28),
        title: Text(_storeName),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // ---------------- GRAFIK PENJUALAN BULANAN ----------------
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Penjualan 6 Bulan Terakhir',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _monthlySalesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }
                          final monthlyData = snapshot.data ?? [];
                          if (monthlyData.isEmpty) {
                            return const Center(child: Text('Belum ada data penjualan.'));
                          }

                          final spots = List.generate(
                            monthlyData.length,
                            (i) => FlSpot(i.toDouble(), (monthlyData[i]['total'] as num).toDouble()),
                          );

                          return LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) =>
                                    FlLine(color: AppColors.border, strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 26,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= monthlyData.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final monthDate = monthlyData[index]['monthDate'] as DateTime;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          DateFormat('MMM').format(monthDate),
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) => Text(
                                      _formatCompactRupiah(value),
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 0,
                              maxX: (monthlyData.length - 1).toDouble(),
                              minY: 0,
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      return LineTooltipItem(
                                        rupiahFormatter.format(spot.y),
                                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: AppColors.primary,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.primary.withOpacity(0.12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ---------------- QUICK ACTION: STOK HAMPIR HABIS ----------------
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _lowStockFuture,
                    builder: (context, snapshot) {
                      final lowStockItems = snapshot.data ?? [];
                      final count = lowStockItems.length;
                      final isLoading = snapshot.connectionState == ConnectionState.waiting;

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: isLoading
                            ? null
                            : () async {
                                await Get.to(() => const StockPage());
                                _refreshLowStock();
                              },
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: count > 0 ? AppColors.dangerLight : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isLoading
                                    ? Icons.hourglass_empty
                                    : (count > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                                color: count > 0 ? AppColors.danger : AppColors.success,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isLoading
                                      ? 'Mengecek stok...'
                                      : (count > 0 ? '$count produk stok hampir habis' : 'Semua stok aman'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: count > 0 ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                              ),
                              if (!isLoading && count > 0)
                                const Icon(Icons.chevron_right, color: AppColors.danger),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: AppColors.primary),
                          onPressed: () => Get.offAll(() => const LoginPage()),
                        ),
                      ),
                      FutureBuilder<double>(
                        future: _dailyIncomeFuture,
                        builder: (context, snapshot) {
                          String label;
                          Color textColor = AppColors.primary;
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            label = 'Loading...';
                          } else if (snapshot.hasError) {
                            label = 'Error';
                            textColor = AppColors.danger;
                          } else {
                            label = 'Pendapatan Hari Ini: ${rupiahFormatter.format(snapshot.data ?? 0.0)}';
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      children: [
                        _buildMenuButton(
                          icon: Icons.point_of_sale_rounded,
                          label: 'Kasir',
                          onTap: () async {
                            await Get.to(() => const KasirPage());
                            _refreshDailyIncome();
                            _refreshLowStock();
                            _refreshMonthlySales();
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.shopping_bag_rounded,
                          label: 'Produk',
                          onTap: () => Get.to(() => const ProductPage()),
                        ),
                        _buildMenuButton(
                          icon: Icons.inventory_2_rounded,
                          label: 'Stock',
                          onTap: () async {
                            await Get.to(() => const StockPage());
                            _refreshLowStock();
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Transaksi',
                          onTap: () async {
                            await Get.to(() => const ResiPage());
                            _refreshDailyIncome();
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.bar_chart_rounded,
                          label: 'Laporan',
                          onTap: () => Get.to(() => const LaporPage()),
                        ),
                        _buildMenuButton(
                          icon: Icons.request_quote_outlined,
                          label: 'Hutang',
                          onTap: () => Get.to(() => const HutangPage()),
                        ),
                        _buildMenuButton(
                          icon: Icons.payments_outlined,
                          label: 'Pengeluaran',
                          onTap: () => Get.to(() => const PengeluaranPage()),
                        ),
                        _buildMenuButton(
                          icon: Icons.settings_rounded,
                          label: 'Setting',
                          onTap: _openSettingPage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: AppColors.primaryDark),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
