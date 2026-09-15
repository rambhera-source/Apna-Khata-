import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:accounting_app/database/database_helper.dart';
import 'package:accounting_app/models/account.dart';
import 'package:accounting_app/models/product.dart';
import 'package:accounting_app/models/order_model.dart';
import 'package:accounting_app/models/user_model.dart';

// ✅ Sub-folder screens import
import '../sales/sales_screen.dart';
import '../sales/sales_return_screen.dart';
import '../purchase/purchase_screen.dart';
import '../purchase/purchase_return_screen.dart';
import '../reports/ledger_screen.dart';
import '../order/orders_management_screen.dart';
import '../products/product_inventory_screen.dart';
import '../manufacturing_screen.dart';
import '../voucher/voucher_entry_screen.dart';
import '../setting/settings_screen.dart';
import '../login_screen.dart';
import '../account/add_account_screen.dart';
import '../account/parties_master_screen.dart';
import '../setting/backup_settings_screen.dart';
