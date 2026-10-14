import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seblak/db/database_helper.dart';
import 'package:seblak/pages/login_page.dart';
import 'package:seblak/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Membuka (dan otomatis membuat jika belum ada) database SQLite
  // beserta tabel-tabelnya sebelum aplikasi berjalan.
  await DatabaseHelper.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginPage(),
    );
  }
}
