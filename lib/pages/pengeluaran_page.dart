import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/theme/app_theme.dart';

enum ExpensePeriod { today, week, month, all }

class PengeluaranPage extends StatefulWidget {
  const PengeluaranPage({super.key});

  @override
  State<PengeluaranPage> createState() => _PengeluaranPageState();
}

class _PengeluaranPageState extends State<PengeluaranPage> {
  static const List<String> _categories = ['Bahan Baku', 'Operasional', 'Gaji', 'Lainnya'];

  final rupiahFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedCategory = _categories.first;

  ExpensePeriod _selectedPeriod = ExpensePeriod.today;

  late Future<List<Map<String, dynamic>>> _expensesFuture;
  late Future<double> _totalFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  DateTime? _getStartDate(ExpensePeriod period) {
    final now = DateTime.now();
    switch (period) {
      case ExpensePeriod.today:
        return DateTime(now.year, now.month, now.day);
      case ExpensePeriod.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(start.year, start.month, start.day);
      case ExpensePeriod.month:
        return DateTime(now.year, now.month, 1);
      case ExpensePeriod.all:
        return null;
    }
  }

  void _loadData() {
    final startDate = _getStartDate(_selectedPeriod);
    final endDate = startDate != null ? DateTime.now().add(const Duration(days: 1)) : null;

    setState(() {
      _expensesFuture = DatabaseHelper.instance.getExpenses(startDate: startDate, endDate: endDate);
      _totalFuture = DatabaseHelper.instance.getTotalExpenses(startDate: startDate, endDate: endDate);
    });
  }

  void _showAddDialog() {
    _descController.clear();
    _amountController.clear();
    _selectedCategory = _categories.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Catat Pengeluaran'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Jumlah', prefixText: 'Rp '),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => _selectedCategory = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () async {
                    final desc = _descController.text.trim();
                    final amount = double.tryParse(_amountController.text);
                    if (desc.isEmpty || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Isi keterangan dan jumlah yang valid.')),
                      );
                      return;
                    }
                    await DatabaseHelper.instance.insertExpense(
                      description: desc,
                      amount: amount,
                      category: _selectedCategory,
                    );
                    if (context.mounted) Navigator.pop(context);
                    _loadData();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(String desc) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Pengeluaran?'),
            content: Text('Yakin ingin menghapus catatan "$desc"?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'Bahan Baku':
        return AppColors.accentDark;
      case 'Operasional':
        return AppColors.primary;
      case 'Gaji':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    const periodLabels = {
      ExpensePeriod.today: 'Hari Ini',
      ExpensePeriod.week: 'Minggu Ini',
      ExpensePeriod.month: 'Bulan Ini',
      ExpensePeriod.all: 'Semua',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Pengeluaran')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FutureBuilder<double>(
              future: _totalFuture,
              builder: (context, snapshot) {
                final total = snapshot.data ?? 0.0;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Pengeluaran (${periodLabels[_selectedPeriod]})',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.accentDark)),
                      Text(
                        rupiahFormatter.format(total),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accentDark),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                children: ExpensePeriod.values.map((period) {
                  final selected = _selectedPeriod == period;
                  return ChoiceChip(
                    label: Text(periodLabels[period]!),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                    onSelected: (_) {
                      setState(() => _selectedPeriod = period);
                      _loadData();
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _expensesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final expenses = snapshot.data ?? [];
                if (expenses.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada pengeluaran pada periode ini.', style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    final id = expense['id'] as int;
                    final desc = expense['description'] as String;
                    final amount = (expense['amount'] as num).toDouble();
                    final category = expense['category'] as String?;
                    final createdAt = DateTime.parse(expense['created_at'] as String);

                    return Dismissible(
                      key: ValueKey('expense_$id'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(desc),
                      onDismissed: (_) async {
                        await DatabaseHelper.instance.deleteExpense(id);
                        _loadData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Pengeluaran "$desc" dihapus.')),
                          );
                        }
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(14)),
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
                          leading: CircleAvatar(
                            backgroundColor: _categoryColor(category).withOpacity(0.15),
                            child: Icon(Icons.receipt_long_outlined, color: _categoryColor(category)),
                          ),
                          title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('dd MMM yyyy, HH:mm').format(createdAt), style: const TextStyle(color: AppColors.textSecondary)),
                              if (category != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _categoryColor(category).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(fontSize: 11, color: _categoryColor(category), fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: category != null,
                          trailing: Text(
                            '- ${rupiahFormatter.format(amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
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
