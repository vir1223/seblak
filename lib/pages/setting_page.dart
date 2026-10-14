import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/theme/app_theme.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  static const String _defaultStoreName = 'Kasir Seblak';

  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _qrisBase64;
  bool _isLoading = true;
  bool _isSavingName = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final name = await DatabaseHelper.instance.getSetting('store_name');
    final qris = await DatabaseHelper.instance.getSetting('qris_image_base64');
    if (!mounted) return;
    setState(() {
      _nameController.text = (name != null && name.trim().isNotEmpty) ? name : _defaultStoreName;
      _qrisBase64 = (qris != null && qris.isNotEmpty) ? qris : null;
      _isLoading = false;
    });
  }

  Future<void> _saveStoreName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama toko tidak boleh kosong.')),
      );
      return;
    }
    setState(() => _isSavingName = true);
    await DatabaseHelper.instance.setSetting('store_name', newName);
    if (!mounted) return;
    setState(() => _isSavingName = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nama toko berhasil disimpan.')),
    );
  }

  Future<void> _pickQrisImage() async {
    setState(() => _isPickingImage = true);
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 85,
      );
      if (file == null) {
        setState(() => _isPickingImage = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      await DatabaseHelper.instance.setSetting('qris_image_base64', base64Str);
      if (!mounted) return;
      setState(() {
        _qrisBase64 = base64Str;
        _isPickingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QRIS berhasil disimpan.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
    }
  }

  Future<void> _removeQrisImage() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus QRIS?'),
            content: const Text('Gambar QRIS akan dihapus dan tidak akan tampil lagi di halaman pembayaran "Lainnya".'),
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

    if (!confirmed) return;
    await DatabaseHelper.instance.deleteSetting('qris_image_base64');
    if (!mounted) return;
    setState(() => _qrisBase64 = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QRIS berhasil dihapus.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------------- NAMA TOKO ----------------
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_outlined, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Nama Toko', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tampil di bagian atas halaman utama.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Nama Toko'),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSavingName ? null : _saveStoreName,
                            child: _isSavingName
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Simpan Nama Toko'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ---------------- QRIS ----------------
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('QRIS Pembayaran', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Akan ditampilkan di halaman Bayar saat metode "Lainnya" dipilih.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.background,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _qrisBase64 != null
                                ? Image.memory(base64Decode(_qrisBase64!), fit: BoxFit.contain)
                                : const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.qr_code_2_outlined, size: 56, color: AppColors.textSecondary),
                                        SizedBox(height: 8),
                                        Text('Belum ada QRIS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isPickingImage ? null : _pickQrisImage,
                            icon: _isPickingImage
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload_rounded),
                            label: Text(_qrisBase64 != null ? 'Ganti QRIS' : 'Upload QRIS'),
                          ),
                        ),
                        if (_qrisBase64 != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _removeQrisImage,
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              label: const Text('Hapus QRIS', style: TextStyle(color: AppColors.danger)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
