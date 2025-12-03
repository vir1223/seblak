# TODO: Migrate Navigation and Snack Bars to GetX

## Overview
Replace all Flutter navigation (Navigator.push, Navigator.pop, etc.) and snack bars (ScaffoldMessenger.showSnackBar) with GetX equivalents across all pages.

## Affected Pages
- home_page.dart
- login_page.dart
- kasir_page.dart
- product_page.dart
- stock_page.dart
- resi_page.dart
- detail_resi_page.dart
- lapor_page.dart
- bayar_page.dart

## Changes Needed
- Add 'import 'package:get/get.dart';' to each page if not present.
- Replace Navigator.push with Get.to(() => Page())
- Replace Navigator.pushReplacement with Get.off(() => Page())
- Replace Navigator.pop with Get.back()
- Replace Navigator.pop(result) with Get.back(result: result)
- Replace ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('msg'))) with Get.snackbar('', 'msg')

## Steps
- [ ] Update home_page.dart
- [ ] Update login_page.dart
- [ ] Update kasir_page.dart
- [ ] Update product_page.dart
- [ ] Update stock_page.dart
- [ ] Update resi_page.dart
- [ ] Update detail_resi_page.dart
- [ ] Update lapor_page.dart
- [ ] Update bayar_page.dart
