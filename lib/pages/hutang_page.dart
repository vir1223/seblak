import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/theme/app_theme.dart';

class HutangPage extends StatefulWidget {
  const HutangPage({super.key});

  @override
  State<HutangPage> createState() => _HutangPageState();
}

class _HutangPageState extends State<HutangPage> {
  final rupiahFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _onlyUnpaid = true;

  late Future<List<Map<String, dynamic>>> _debtsFuture;
  late Future<double> _totalUnpaidFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _debtsFuture = DatabaseHelper.instance.getDebts(onlyUnpaid: _onlyUnpaid);
      _totalUnpaidFuture = DatabaseHelper.instance.getTotalUnpaidDebt();
    });
  }

  void _showAddDialog() {
    _nameController.clear();
    _amountController.clear();
    _noteController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Catat Hutang Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Pelanggan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah Hutang', prefixText: 'Rp '),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                final amount = double.tryParse(_amountController.text);
                if (name.isEmpty || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Isi nama pelanggan dan jumlah hutang yang valid.')),
                  );
                  return;
                }
                await DatabaseHelper.instance.insertDebt(
                  customerName: name,
                  amount: amount,
                  note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
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
  }

  Future<bool> _confirmDelete(String nama) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Catatan Hutang?'),
            content: Text('Yakin ingin menghapus catatan hutang "$nama"?'),
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

  Future<void> _confirmMarkPaid(int id, String nama) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tandai Lunas?'),
            content: Text('Tandai hutang "$nama" sebagai sudah lunas?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: const Text('Lunas'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await DatabaseHelper.instance.markDebtAsPaid(id);
      _loadData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$nama" ditandai lunas.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hutang Pelanggan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FutureBuilder<double>(
              future: _totalUnpaidFuture,
              builder: (context, snapshot) {
                final total = snapshot.data ?? 0.0;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Belum Lunas', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
                      Text(
                        rupiahFormatter.format(total),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.danger),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Belum Lunas'),
                  selected: _onlyUnpaid,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: _onlyUnpaid ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                  onSelected: (_) {
                    setState(() => _onlyUnpaid = true);
                    _loadData();
                  },
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: !_onlyUnpaid,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: !_onlyUnpaid ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                  onSelected: (_) {
                    setState(() => _onlyUnpaid = false);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _debtsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final debts = snapshot.data ?? [];
                if (debts.isEmpty) {
                  return Center(
                    child: Text(
                      _onlyUnpaid ? 'Tidak ada hutang yang belum lunas.' : 'Belum ada catatan hutang.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  itemCount: debts.length,
                  itemBuilder: (context, index) {
                    final debt = debts[index];
                    final id = debt['id'] as int;
                    final nama = debt['customer_name'] as String;
                    final amount = (debt['amount'] as num).toDouble();
                    final note = debt['note'] as String?;
                    final isPaid = (debt['is_paid'] as int) == 1;
                    final createdAt = DateTime.parse(debt['created_at'] as String);

                    return Dismissible(
                      key: ValueKey('debt_$id'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(nama),
                      onDismissed: (_) async {
                        await DatabaseHelper.instance.deleteDebt(id);
                        _loadData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Catatan hutang "$nama" dihapus.')),
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
                            backgroundColor: isPaid ? AppColors.successLight : AppColors.dangerLight,
                            child: Icon(
                              isPaid ? Icons.check_rounded : Icons.person_outline,
                              color: isPaid ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          title: Text(
                            nama,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isPaid ? TextDecoration.lineThrough : null,
                              color: isPaid ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('dd MMM yyyy').format(createdAt), style: const TextStyle(color: AppColors.textSecondary)),
                              if (note != null && note.isNotEmpty) Text(note, style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                          isThreeLine: note != null && note.isNotEmpty,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                rupiahFormatter.format(amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? AppColors.textSecondary : AppColors.danger,
                                ),
                              ),
                              if (!isPaid)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _confirmMarkPaid(id, nama),
                                  child: const Text('Tandai Lunas', style: TextStyle(fontSize: 12, color: AppColors.success)),
                                ),
                            ],
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
