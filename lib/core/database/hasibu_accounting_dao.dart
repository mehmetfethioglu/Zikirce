import 'package:flutter/foundation.dart';

import '../../features/pdks/data/accounting_demo_seed_data.dart';
import '../../features/pdks/domain/accounting_models.dart';
import 'hasibu_database.dart';
import 'hasibu_pre_accounting_ext_dao.dart';

export 'hasibu_pre_accounting_ext_dao.dart';

/// Cezeri-Piri Yüksek Hızlı Ön Muhasebe, Otomatik Puantaj-Cari Hakediş,
/// Emanet Kap (Tepsi/Kasa), Kritik Stok ("Kalan Gün") ve Göç Sihirbazı SQLite Katmanı.
extension HasibuAccountingDatabaseExt on HasibuDatabase {
  void initAccountingSchema() {
    rawDb.execute('''
      CREATE TABLE IF NOT EXISTS accounting_accounts (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        group_name TEXT NOT NULL DEFAULT 'Genel',
        phone TEXT NOT NULL DEFAULT '',
        tax_office_and_no TEXT NOT NULL DEFAULT '',
        employee_card_no TEXT,
        salary_type TEXT NOT NULL DEFAULT 'monthly',
        base_salary_or_daily_rate REAL NOT NULL DEFAULT 0.0,
        tray_balance INTEGER NOT NULL DEFAULT 0,
        crate_balance INTEGER NOT NULL DEFAULT 0
      );

      CREATE INDEX IF NOT EXISTS idx_acc_accounts_emp_card
        ON accounting_accounts(employee_card_no);

      CREATE TABLE IF NOT EXISTS accounting_transactions (
        id TEXT PRIMARY KEY,
        doc_no TEXT NOT NULL,
        date_key TEXT NOT NULL,
        account_id TEXT NOT NULL,
        account_name TEXT NOT NULL,
        entry_type TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0.0,
        cash_or_bank_name TEXT NOT NULL DEFAULT 'Merkez TL Kasa',
        expense_category TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        puantaj_period_key TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_acc_tx_account_date
        ON accounting_transactions(account_id, date_key);

      CREATE INDEX IF NOT EXISTS idx_acc_tx_period
        ON accounting_transactions(puantaj_period_key);

      CREATE TABLE IF NOT EXISTS container_movements (
        id TEXT PRIMARY KEY,
        date_key TEXT NOT NULL,
        account_id TEXT NOT NULL,
        account_name TEXT NOT NULL,
        container_type TEXT NOT NULL,
        given_qty INTEGER NOT NULL DEFAULT 0,
        returned_qty INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT ''
      );

      CREATE INDEX IF NOT EXISTS idx_container_mov_acc
        ON container_movements(account_id, date_key);

      CREATE TABLE IF NOT EXISTS stock_burn_items (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        current_qty REAL NOT NULL DEFAULT 0.0,
        daily_burn_rate REAL NOT NULL DEFAULT 1.0,
        unit_cost REAL NOT NULL DEFAULT 0.0
      );

      CREATE TABLE IF NOT EXISTS checks_and_notes (
        id TEXT PRIMARY KEY,
        due_date TEXT NOT NULL,
        kind TEXT NOT NULL,
        title_or_party TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0.0,
        note TEXT NOT NULL DEFAULT ''
      );

      CREATE TABLE IF NOT EXISTS saas_subscription (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        active_tier TEXT NOT NULL DEFAULT 'proKobi',
        channel TEXT NOT NULL DEFAULT 'microsoftStoreDirect',
        is_trial_active INTEGER NOT NULL DEFAULT 1,
        trial_days_remaining INTEGER NOT NULL DEFAULT 14,
        hardware_hook_connected INTEGER NOT NULL DEFAULT 1,
        is_demo_mode_active INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE IF NOT EXISTS branch_pos_receipts (
        id TEXT PRIMARY KEY,
        receipt_no TEXT NOT NULL,
        branch_id INTEGER NOT NULL,
        store_name TEXT NOT NULL,
        date_key TEXT NOT NULL,
        time_text TEXT NOT NULL,
        cashier_name TEXT NOT NULL,
        receipt_type TEXT NOT NULL DEFAULT 'SATIŞ',
        payment_method TEXT NOT NULL,
        total_amount_tl REAL NOT NULL DEFAULT 0.0,
        cash_amount_tl REAL NOT NULL DEFAULT 0.0,
        pos_amount_tl REAL NOT NULL DEFAULT 0.0,
        open_account_amount_tl REAL NOT NULL DEFAULT 0.0,
        received_cash_tl REAL NOT NULL DEFAULT 0.0,
        change_returned_tl REAL NOT NULL DEFAULT 0.0,
        customer_name TEXT NOT NULL DEFAULT '',
        customer_phone TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        sweet_weight_kg REAL NOT NULL DEFAULT 0.0,
        box_count INTEGER NOT NULL DEFAULT 0,
        box_tare_weight_kg REAL NOT NULL DEFAULT 0.0,
        complimentary_line_count INTEGER NOT NULL DEFAULT 0,
        synced_to_hq INTEGER NOT NULL DEFAULT 1,
        items_summary TEXT NOT NULL DEFAULT ''
      );

      CREATE INDEX IF NOT EXISTS idx_branch_pos_receipts_branch_date
        ON branch_pos_receipts(branch_id, date_key);

      CREATE TABLE IF NOT EXISTS branch_audit_inspections (
        id TEXT PRIMARY KEY,
        audit_doc_no TEXT NOT NULL,
        date_key TEXT NOT NULL,
        branch_id INTEGER NOT NULL,
        store_name TEXT NOT NULL,
        inspector_name TEXT NOT NULL,
        cancelled_or_refund_count INTEGER NOT NULL DEFAULT 0,
        complimentary_item_count INTEGER NOT NULL DEFAULT 0,
        cashier_risk_score REAL NOT NULL DEFAULT 0.0,
        shipped_tray_total_kg REAL NOT NULL DEFAULT 0.0,
        pos_sold_plus_remaining_kg REAL NOT NULL DEFAULT 0.0,
        box_tare_offset_kg REAL NOT NULL DEFAULT 0.0,
        unaccounted_fire_kg REAL NOT NULL DEFAULT 0.0,
        blind_cash_variance_tl REAL NOT NULL DEFAULT 0.0,
        blind_stock_variance_tl REAL NOT NULL DEFAULT 0.0,
        pdks_checked_in_staff_count INTEGER NOT NULL DEFAULT 0,
        pos_active_cashier_count INTEGER NOT NULL DEFAULT 0,
        ghost_cashier_detected INTEGER NOT NULL DEFAULT 0,
        cold_chain_temp_celsius REAL NOT NULL DEFAULT -18.0,
        hygiene_checklist_score INTEGER NOT NULL DEFAULT 95,
        finding_summary TEXT NOT NULL DEFAULT '',
        action_plan TEXT NOT NULL DEFAULT ''
      );

      CREATE INDEX IF NOT EXISTS idx_branch_audit_branch_date
        ON branch_audit_inspections(branch_id, date_key);
    ''');
    initPreAccountingExtSchema();
  }

  void seedAccountingIfEmpty() {
    final subCount = rawDb
            .select('SELECT COUNT(*) AS cnt FROM saas_subscription')
            .first['cnt'] as int? ??
        0;
    if (subCount == 0) {
      if (kDebugMode) {
        rawDb.execute('''
          INSERT INTO saas_subscription
          (id, active_tier, channel, is_trial_active, trial_days_remaining, hardware_hook_connected, is_demo_mode_active)
          VALUES (1, 'proKobi', 'microsoftStoreDirect', 1, 14, 1, 1)
        ''');
        loadAccountingDemoPackage();
      } else {
        rawDb.execute('''
          INSERT INTO saas_subscription
          (id, active_tier, channel, is_trial_active, trial_days_remaining, hardware_hook_connected, is_demo_mode_active)
          VALUES (1, 'proKobi', 'microsoftStoreDirect', 1, 14, 1, 0)
        ''');
      }
    } else if (kDebugMode && isAccountingDemoModeActive()) {
      seedPreAccountingExtDemoData();
    }
  }

  bool isAccountingDemoModeActive() {
    final rows = rawDb.select(
      'SELECT is_demo_mode_active FROM saas_subscription WHERE id = 1',
    );
    if (rows.isEmpty) return true;
    return (rows.first['is_demo_mode_active'] as int? ?? 1) == 1;
  }

  /// Ön Muhasebe tablolarını tamamen temizleyerek %100 Temiz Sıfır Veritabanı (Zero-State) moduna geçirir.
  void clearAccountingDataToZero() {
    rawDb.execute('BEGIN TRANSACTION;');
    try {
      rawDb.execute('DELETE FROM accounting_transactions;');
      rawDb.execute('DELETE FROM container_movements;');
      rawDb.execute('DELETE FROM accounting_accounts;');
      rawDb.execute('DELETE FROM stock_burn_items;');
      rawDb.execute('DELETE FROM checks_and_notes;');
      rawDb.execute('DELETE FROM branch_pos_receipts;');
      rawDb.execute('DELETE FROM branch_audit_inspections;');
      clearPreAccountingExtTables();
      rawDb.execute(
        'UPDATE saas_subscription SET is_demo_mode_active = 0 WHERE id = 1;',
      );
      rawDb.execute('COMMIT;');
    } catch (_) {
      rawDb.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Gerçek işletme verisi içermeyen, uygulama kullanımını gösteren %100 izole Demo Veri Paketini yükler.
  void loadAccountingDemoPackage() {
    rawDb.execute('BEGIN TRANSACTION;');
    try {
      rawDb.execute('DELETE FROM accounting_transactions;');
      rawDb.execute('DELETE FROM container_movements;');
      rawDb.execute('DELETE FROM accounting_accounts;');
      rawDb.execute('DELETE FROM stock_burn_items;');
      rawDb.execute('DELETE FROM checks_and_notes;');
      rawDb.execute('DELETE FROM branch_pos_receipts;');
      rawDb.execute('DELETE FROM branch_audit_inspections;');

      for (final acc in AccountingDemoSeedData.demoAccounts) {
        upsertAccountingAccount(acc);
      }
      for (final tx in AccountingDemoSeedData.demoTransactions) {
        upsertAccountingTransaction(tx);
      }
      for (final mov in AccountingDemoSeedData.demoContainerMovements) {
        upsertContainerMovement(mov);
      }
      for (final stk in AccountingDemoSeedData.demoStockItems) {
        upsertStockBurnItem(stk);
      }
      for (final chk in AccountingDemoSeedData.demoChecksAndNotes) {
        upsertCheckOrNote(chk);
      }
      for (final rcp in AccountingDemoSeedData.demoBranchPosReceipts) {
        upsertBranchPosReceipt(rcp);
      }
      for (final aud in AccountingDemoSeedData.demoBranchAuditInspections) {
        upsertBranchAuditInspection(aud);
      }
      clearPreAccountingExtTables();
      seedPreAccountingExtDemoData();
      rawDb.execute(
        'UPDATE saas_subscription SET is_demo_mode_active = 1 WHERE id = 1;',
      );
      rawDb.execute('COMMIT;');
    } catch (_) {
      rawDb.execute('ROLLBACK;');
      rethrow;
    }
  }

  String _safeReadString(
    Map<String, Object?> row,
    String key, [
    String fallback = '',
  ]) {
    try {
      if (!row.containsKey(key)) return fallback;
      final val = row[key];
      return val is String ? val : fallback;
    } catch (e) {
      debugPrint('HasibuAccountingDao: Sütun okuma hatası ($key): $e');
      return fallback;
    }
  }

  int _safeReadInt(
    Map<String, Object?> row,
    String key, [
    int fallback = 0,
  ]) {
    try {
      if (!row.containsKey(key)) return fallback;
      final val = row[key];
      return val is num ? val.toInt() : fallback;
    } catch (e) {
      debugPrint('HasibuAccountingDao: Tamsayı sütun okuma hatası ($key): $e');
      return fallback;
    }
  }

  double _safeReadDouble(
    Map<String, Object?> row,
    String key, [
    double fallback = 0.0,
  ]) {
    try {
      if (!row.containsKey(key)) return fallback;
      final val = row[key];
      return val is num ? val.toDouble() : fallback;
    } catch (e) {
      debugPrint('HasibuAccountingDao: Ondalık sütun okuma hatası ($key): $e');
      return fallback;
    }
  }

  /// 300+ satır korele alt sorgu darboğazını tek geçişli GROUP BY
  /// JOIN ile <4ms'de çözen yüksek hızlı Cari Kart + Bakiye + Emanet Kap sorgusu.
  List<AccountingAccount> getAccountingAccounts() {
    final rows = rawDb.select('''
      SELECT
        a.*,
        COALESCE(SUM(CASE WHEN t.direction = 'A' THEN t.amount ELSE 0.0 END), 0.0) AS calc_credit,
        COALESCE(SUM(CASE WHEN t.direction = 'B' THEN t.amount ELSE 0.0 END), 0.0) AS calc_debit
      FROM accounting_accounts a
      LEFT JOIN accounting_transactions t ON t.account_id = a.id
      GROUP BY a.id
      ORDER BY a.type ASC, a.name ASC
    ''');

    return rows
        .map(
          (r) => AccountingAccount(
            id: r['id'] as String,
            code: r['code'] as String,
            name: r['name'] as String,
            type: AccountingAccountType.fromName(r['type'] as String?),
            groupName: r['group_name'] as String? ?? 'Genel',
            phone: r['phone'] as String? ?? '',
            taxOfficeAndNo: r['tax_office_and_no'] as String? ?? '',
            employeeCardNo: r['employee_card_no'] as String?,
            salaryType: SalaryType.fromName(r['salary_type'] as String?),
            baseSalaryOrDailyRate:
                (r['base_salary_or_daily_rate'] as num? ?? 0).toDouble(),
            creditTotal: (r['calc_credit'] as num? ?? 0).toDouble(),
            debitTotal: (r['calc_debit'] as num? ?? 0).toDouble(),
            trayBalance: r['tray_balance'] as int? ?? 0,
            crateBalance: r['crate_balance'] as int? ?? 0,
            specialCode: _safeReadString(r, 'special_code'),
            priceTier: _safeReadInt(r, 'price_tier', 1),
            defaultDiscountPercent:
                _safeReadDouble(r, 'default_discount_percent'),
            salesRepName: _safeReadString(r, 'sales_rep_name'),
            creditLimitTl: _safeReadDouble(r, 'credit_limit_tl'),
            cityDistrict: _safeReadString(r, 'city_district'),
          ),
        )
        .toList(growable: false);
  }

  void upsertAccountingAccount(AccountingAccount acc) {
    try {
      final stmt = rawDb.prepare('''
        INSERT OR REPLACE INTO accounting_accounts
        (id, code, name, type, group_name, phone, tax_office_and_no, employee_card_no, salary_type, base_salary_or_daily_rate, tray_balance, crate_balance, special_code, price_tier, default_discount_percent, sales_rep_name, credit_limit_tl, city_district)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        stmt.execute([
          acc.id.trim(),
          acc.code.trim().toUpperCase(),
          acc.name.trim().toUpperCase(),
          acc.type.name,
          acc.groupName.trim(),
          acc.phone.trim(),
          acc.taxOfficeAndNo.trim(),
          acc.employeeCardNo?.trim(),
          acc.salaryType.name,
          acc.baseSalaryOrDailyRate,
          acc.trayBalance,
          acc.crateBalance,
          acc.specialCode.trim().toUpperCase(),
          acc.priceTier,
          acc.defaultDiscountPercent,
          acc.salesRepName.trim(),
          acc.creditLimitTl,
          acc.cityDistrict.trim(),
        ]);
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      debugPrint(
        'HasibuAccountingDao.upsertAccountingAccount: Genişletilmiş şema hatası, temel sütunlara düşülüyor: $e',
      );
      final legacyStmt = rawDb.prepare('''
        INSERT OR REPLACE INTO accounting_accounts
        (id, code, name, type, group_name, phone, tax_office_and_no, employee_card_no, salary_type, base_salary_or_daily_rate, tray_balance, crate_balance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        legacyStmt.execute([
          acc.id.trim(),
          acc.code.trim().toUpperCase(),
          acc.name.trim().toUpperCase(),
          acc.type.name,
          acc.groupName.trim(),
          acc.phone.trim(),
          acc.taxOfficeAndNo.trim(),
          acc.employeeCardNo?.trim(),
          acc.salaryType.name,
          acc.baseSalaryOrDailyRate,
          acc.trayBalance,
          acc.crateBalance,
        ]);
      } finally {
        legacyStmt.dispose();
      }
    }
  }

  List<AccountingTransaction> getAccountingTransactions({String? accountId}) {
    final rows = (accountId != null && accountId.trim().isNotEmpty)
        ? rawDb.select(
            'SELECT * FROM accounting_transactions WHERE account_id = ? ORDER BY date_key DESC, id DESC',
            [accountId.trim()],
          )
        : rawDb.select(
            'SELECT * FROM accounting_transactions ORDER BY date_key DESC, id DESC',
          );

    return rows
        .map(
          (r) => AccountingTransaction(
            id: r['id'] as String,
            docNo: r['doc_no'] as String,
            dateKey: r['date_key'] as String,
            accountId: r['account_id'] as String,
            accountName: r['account_name'] as String,
            entryType: LedgerEntryType.fromName(r['entry_type'] as String?),
            direction: r['direction'] as String? ?? 'A',
            amount: (r['amount'] as num? ?? 0).toDouble(),
            cashOrBankName:
                r['cash_or_bank_name'] as String? ?? 'Merkez TL Kasa',
            expenseCategory: r['expense_category'] as String? ?? '',
            description: r['description'] as String? ?? '',
            puantajPeriodKey: r['puantaj_period_key'] as String?,
            currencyCode: _safeReadString(r, 'currency_code', 'TRY'),
            fxRate: _safeReadDouble(r, 'fx_rate', 1.0),
            fxAmount: _safeReadDouble(r, 'fx_amount'),
            discountPercent: _safeReadDouble(r, 'discount_percent'),
            salesRepName: _safeReadString(r, 'sales_rep_name'),
            settledAmountTl: _safeReadDouble(r, 'settled_amount_tl'),
            linkedOrderDocId: _safeReadString(r, 'linked_order_doc_id'),
          ),
        )
        .toList(growable: false);
  }

  void upsertAccountingTransaction(AccountingTransaction tx) {
    final cleanCurrency = tx.currencyCode.trim().isEmpty
        ? 'TRY'
        : tx.currencyCode.trim().toUpperCase();
    final cleanFxRate = tx.fxRate <= 0 ? 1.0 : tx.fxRate;

    try {
      final stmt = rawDb.prepare('''
        INSERT OR REPLACE INTO accounting_transactions
        (id, doc_no, date_key, account_id, account_name, entry_type, direction, amount, cash_or_bank_name, expense_category, description, puantaj_period_key, currency_code, fx_rate, fx_amount, discount_percent, sales_rep_name, settled_amount_tl, linked_order_doc_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        stmt.execute([
          tx.id.trim(),
          tx.docNo.trim().toUpperCase(),
          tx.dateKey.trim(),
          tx.accountId.trim(),
          tx.accountName.trim().toUpperCase(),
          tx.entryType.name,
          tx.direction.trim().toUpperCase(),
          tx.amount,
          tx.cashOrBankName.trim(),
          tx.expenseCategory.trim().toUpperCase(),
          tx.description.trim(),
          tx.puantajPeriodKey?.trim(),
          cleanCurrency,
          cleanFxRate,
          tx.fxAmount,
          tx.discountPercent,
          tx.salesRepName.trim(),
          tx.settledAmountTl,
          tx.linkedOrderDocId.trim(),
        ]);
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      debugPrint(
        'HasibuAccountingDao.upsertAccountingTransaction: Genişletilmiş şema hatası, temel sütunlara düşülüyor: $e',
      );
      final legacyStmt = rawDb.prepare('''
        INSERT OR REPLACE INTO accounting_transactions
        (id, doc_no, date_key, account_id, account_name, entry_type, direction, amount, cash_or_bank_name, expense_category, description, puantaj_period_key)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        legacyStmt.execute([
          tx.id.trim(),
          tx.docNo.trim().toUpperCase(),
          tx.dateKey.trim(),
          tx.accountId.trim(),
          tx.accountName.trim().toUpperCase(),
          tx.entryType.name,
          tx.direction.trim().toUpperCase(),
          tx.amount,
          tx.cashOrBankName.trim(),
          tx.expenseCategory.trim().toUpperCase(),
          tx.description.trim(),
          tx.puantajPeriodKey?.trim(),
        ]);
      } finally {
        legacyStmt.dispose();
      }
    }
  }

  void deleteAccountingTransaction(String id) {
    final stmt = rawDb.prepare(
      'DELETE FROM accounting_transactions WHERE id = ?',
    );
    stmt.execute([id.trim()]);
    stmt.dispose();
  }

  List<ContainerMovement> getContainerMovements({String? accountId}) {
    final rows = (accountId != null && accountId.trim().isNotEmpty)
        ? rawDb.select(
            'SELECT * FROM container_movements WHERE account_id = ? ORDER BY date_key DESC, id DESC',
            [accountId.trim()],
          )
        : rawDb.select(
            'SELECT * FROM container_movements ORDER BY date_key DESC, id DESC',
          );

    return rows
        .map(
          (r) => ContainerMovement(
            id: r['id'] as String,
            dateKey: r['date_key'] as String,
            accountId: r['account_id'] as String,
            accountName: r['account_name'] as String,
            containerType: r['container_type'] as String? ?? 'Tepsi',
            givenQty: r['given_qty'] as int? ?? 0,
            returnedQty: r['returned_qty'] as int? ?? 0,
            note: r['note'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertContainerMovement(ContainerMovement mov) {
    final stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO container_movements
      (id, date_key, account_id, account_name, container_type, given_qty, returned_qty, note)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      mov.id.trim(),
      mov.dateKey.trim(),
      mov.accountId.trim(),
      mov.accountName.trim().toUpperCase(),
      mov.containerType.trim(),
      mov.givenQty,
      mov.returnedQty,
      mov.note.trim(),
    ]);
    stmt.dispose();
  }

  /// Cariye yeni emanet kap (Tepsi / Kasa) hareketi ekler ve cari kartın emanet bakiyesini günceller.
  void recordContainerMovementAndSyncBalance(ContainerMovement mov) {
    rawDb.execute('BEGIN TRANSACTION;');
    try {
      upsertContainerMovement(mov);
      final delta = mov.givenQty - mov.returnedQty;
      final isTray = mov.containerType.toLowerCase().contains('tepsi');
      final col = isTray ? 'tray_balance' : 'crate_balance';
      final upd = rawDb.prepare(
        'UPDATE accounting_accounts SET $col = $col + ? WHERE id = ?',
      );
      upd.execute([delta, mov.accountId]);
      upd.dispose();
      rawDb.execute('COMMIT;');
    } catch (_) {
      rawDb.execute('ROLLBACK;');
      rethrow;
    }
  }

  List<StockBurnItem> getStockBurnItems() {
    final rows = rawDb.select('SELECT * FROM stock_burn_items ORDER BY id ASC');
    final items = rows
        .map(
          (r) => StockBurnItem(
            id: r['id'] as String,
            code: r['code'] as String,
            name: r['name'] as String,
            unit: r['unit'] as String,
            currentQty: (r['current_qty'] as num? ?? 0).toDouble(),
            dailyBurnRate: (r['daily_burn_rate'] as num? ?? 1).toDouble(),
            unitCost: (r['unit_cost'] as num? ?? 0).toDouble(),
            salePriceTl: _safeReadDouble(r, 'sale_price_tl'),
            depositUnitTl: _safeReadDouble(r, 'deposit_unit_tl'),
            templateCategory: _safeReadString(r, 'template_category'),
            priceHistoryJson: _safeReadString(r, 'price_history_json', '[]'),
          ),
        )
        .toList();
    items.sort((a, b) => a.remainingDays.compareTo(b.remainingDays));
    return items;
  }

  void upsertStockBurnItem(StockBurnItem item) {
    final cleanHistory = item.priceHistoryJson.trim().isEmpty
        ? '[]'
        : item.priceHistoryJson.trim();

    try {
      final stmt = rawDb.prepare('''
        INSERT OR REPLACE INTO stock_burn_items
        (id, code, name, unit, current_qty, daily_burn_rate, unit_cost, sale_price_tl, deposit_unit_tl, template_category, price_history_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        stmt.execute([
          item.id.trim(),
          item.code.trim().toUpperCase(),
          item.name.trim().toUpperCase(),
          item.unit.trim().toUpperCase(),
          item.currentQty,
          item.dailyBurnRate <= 0 ? 1.0 : item.dailyBurnRate,
          item.unitCost,
          item.salePriceTl,
          item.depositUnitTl,
          item.templateCategory.trim(),
          cleanHistory,
        ]);
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      debugPrint(
        'HasibuAccountingDao.upsertStockBurnItem: Genişletilmiş şema hatası, temel sütunlara düşülüyor: $e',
      );
      final legacyStmt = rawDb.prepare('''
        INSERT OR REPLACE INTO stock_burn_items
        (id, code, name, unit, current_qty, daily_burn_rate, unit_cost)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        legacyStmt.execute([
          item.id.trim(),
          item.code.trim().toUpperCase(),
          item.name.trim().toUpperCase(),
          item.unit.trim().toUpperCase(),
          item.currentQty,
          item.dailyBurnRate <= 0 ? 1.0 : item.dailyBurnRate,
          item.unitCost,
        ]);
      } finally {
        legacyStmt.dispose();
      }
    }
  }

  void adjustStockBurnItemQuantity(String stockId, double deltaQty) {
    final stmt = rawDb.prepare('''
      UPDATE stock_burn_items
      SET current_qty = CASE WHEN current_qty + ? < 0 THEN 0.0 ELSE current_qty + ? END
      WHERE id = ?
    ''');
    stmt.execute([deltaQty, deltaQty, stockId.trim()]);
    stmt.dispose();
  }

  List<CheckOrAlertNote> getChecksAndNotes() {
    final rows = rawDb.select(
      'SELECT * FROM checks_and_notes ORDER BY due_date ASC, id ASC',
    );
    return rows
        .map(
          (r) => CheckOrAlertNote(
            id: r['id'] as String,
            dueDate: r['due_date'] as String,
            kind: r['kind'] as String? ?? 'ÇEK',
            titleOrParty: r['title_or_party'] as String,
            amount: (r['amount'] as num? ?? 0).toDouble(),
            note: r['note'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertCheckOrNote(CheckOrAlertNote item) {
    final stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO checks_and_notes
      (id, due_date, kind, title_or_party, amount, note)
      VALUES (?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      item.id.trim(),
      item.dueDate.trim(),
      item.kind.trim().toUpperCase(),
      item.titleOrParty.trim().toUpperCase(),
      item.amount,
      item.note.trim(),
    ]);
    stmt.dispose();
  }

  void deleteCheckOrNote(String id) {
    final stmt = rawDb.prepare('DELETE FROM checks_and_notes WHERE id = ?');
    stmt.execute([id.trim()]);
    stmt.dispose();
  }

  /// Faz 1 — Otomatik Puantaj tablosundaki personel hakedişlerini tek tıkla
  /// `accounting_transactions` tablosuna Dekont / Alacak ('A') olarak tahakkuk ettirir.
  int accrueMonthlyPayrollToLedger({
    required String periodKey,
    required String accrualDateKey,
    required List<PuantajEmployeeRow> rows,
  }) {
    int count = 0;
    rawDb.execute('BEGIN TRANSACTION;');
    try {
      final delStmt = rawDb.prepare('''
        DELETE FROM accounting_transactions
        WHERE entry_type = 'payrollAccrual' AND puantaj_period_key = ?
      ''');
      delStmt.execute([periodKey.trim()]);
      delStmt.dispose();

      for (final row in rows) {
        if (row.grossAccrualPay <= 0) continue;
        final accId = 'acc_emp_${row.cardNo}';
        final existing = rawDb.select(
          'SELECT id FROM accounting_accounts WHERE id = ?',
          [accId],
        );
        if (existing.isEmpty) {
          upsertAccountingAccount(
            AccountingAccount(
              id: accId,
              code: 'PRS-${row.cardNo}',
              name: row.fullName,
              type: AccountingAccountType.employee,
              groupName: row.departmentName,
              employeeCardNo: row.cardNo,
              salaryType: row.salaryType,
              baseSalaryOrDailyRate: row.baseSalary,
            ),
          );
        }

        upsertAccountingTransaction(
          AccountingTransaction(
            id: 'tx_puantaj_${periodKey}_${row.cardNo}',
            docNo: 'DEK-$periodKey-${row.cardNo}',
            dateKey: accrualDateKey,
            accountId: accId,
            accountName: row.fullName,
            entryType: LedgerEntryType.payrollAccrual,
            direction: 'A', // Personel Alacaklı
            amount: double.parse(row.grossAccrualPay.toStringAsFixed(2)),
            cashOrBankName: 'Puantaj Tahakkuk Dekontu',
            expenseCategory: 'PERSONEL GİDERLERİ',
            description:
                '$periodKey Puantaj Hakedişi (${row.payableDays} Gün + ${row.overtimeHours.toStringAsFixed(1)} Saat FM)',
            puantajPeriodKey: periodKey,
          ),
        );
        count++;
      }
      rawDb.execute('COMMIT;');
    } catch (_) {
      rawDb.execute('ROLLBACK;');
      rethrow;
    }
    return count;
  }

  /// Faz 1 — Puantaj veya Cari satırından seçili personele tek tıkla Kasa Nakit veya Banka Havale ödemesi yapar.
  void payEmployeeFromLedger({
    required PuantajEmployeeRow row,
    required String dateKey,
    required bool viaBank,
    required double amount,
  }) {
    if (amount <= 0) return;
    final accId = 'acc_emp_${row.cardNo}';
    final existing = rawDb.select(
      'SELECT id FROM accounting_accounts WHERE id = ?',
      [accId],
    );
    if (existing.isEmpty) {
      upsertAccountingAccount(
        AccountingAccount(
          id: accId,
          code: 'PRS-${row.cardNo}',
          name: row.fullName,
          type: AccountingAccountType.employee,
          groupName: row.departmentName,
          employeeCardNo: row.cardNo,
          salaryType: row.salaryType,
          baseSalaryOrDailyRate: row.baseSalary,
        ),
      );
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_pay_${row.cardNo}_$stamp',
        docNo: '${viaBank ? "BNK" : "KAS"}-${row.cardNo}-${stamp % 10000}',
        dateKey: dateKey,
        accountId: accId,
        accountName: row.fullName,
        entryType: viaBank ? LedgerEntryType.bankOut : LedgerEntryType.cashOut,
        direction: 'B', // Personel Cari Borçlanır (Alacağı Kapanır)
        amount: double.parse(amount.toStringAsFixed(2)),
        cashOrBankName: viaBank ? 'Ticari Vadesiz Banka' : 'Merkez TL Kasa',
        expenseCategory: 'PERSONEL GİDERLERİ',
        description: viaBank
            ? 'Bankadan Personel Maaş/Hakediş Havalesi'
            : 'Kasadan Personel Nakit Maaş/Hakediş Ödemesi',
      ),
    );
  }

  /// Faz 2 — Mağaza (App Store / Play Store / Microsoft Store) SaaS Abonelik durumu.
  SaaSSubscriptionState getSaaSSubscriptionState() {
    final rows = rawDb.select('SELECT * FROM saas_subscription WHERE id = 1');
    if (rows.isEmpty) return const SaaSSubscriptionState();
    final r = rows.first;
    return SaaSSubscriptionState(
      activeTier: SaaSTier.fromName(r['active_tier'] as String?),
      channel: StoreDistributionChannel.fromName(r['channel'] as String?),
      isTrialActive: (r['is_trial_active'] as int? ?? 1) == 1,
      trialDaysRemaining: r['trial_days_remaining'] as int? ?? 14,
      hardwareHookConnected: (r['hardware_hook_connected'] as int? ?? 1) == 1,
    );
  }

  void saveSaaSSubscriptionState(SaaSSubscriptionState state) {
    final demoActive = isAccountingDemoModeActive() ? 1 : 0;
    final stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO saas_subscription
      (id, active_tier, channel, is_trial_active, trial_days_remaining, hardware_hook_connected, is_demo_mode_active)
      VALUES (1, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      state.activeTier.name,
      state.channel.name,
      state.isTrialActive ? 1 : 0,
      state.trialDaysRemaining,
      state.hardwareHookConnected ? 1 : 0,
      demoActive,
    ]);
    stmt.dispose();
  }

  /// Faz 3 — Tek Tıkla Excel / CSV Göç Sihirbazı (Zero-Friction Onboarding).
  MigrationImportResult importLegacyDataBatch(
    String rawCsv, {
    required String dateKey,
  }) {
    int accountsImported = 0;
    int stocksImported = 0;
    int transactionsCreated = 0;
    final warnings = <String>[];

    final lines = rawCsv
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    rawDb.execute('BEGIN TRANSACTION;');
    try {
      for (int i = 0; i < lines.length; i++) {
        final parts = lines[i].split(';').map((e) => e.trim()).toList();
        if (parts.length < 3) {
          warnings.add('Satır ${i + 1}: Eksik sütun sayısı (${lines[i]})');
          continue;
        }
        final kind = parts[0].toUpperCase();
        if (kind == 'CARI') {
          final code = parts[1].isEmpty ? 'GOC-${i + 1}' : parts[1];
          final name = parts[2];
          final typeRaw = parts.length > 3 ? parts[3] : 'customer';
          final credit =
              parts.length > 4 ? (double.tryParse(parts[4]) ?? 0.0) : 0.0;
          final debit =
              parts.length > 5 ? (double.tryParse(parts[5]) ?? 0.0) : 0.0;
          final trays = parts.length > 6 ? (int.tryParse(parts[6]) ?? 0) : 0;
          final salary =
              parts.length > 7 ? (double.tryParse(parts[7]) ?? 0.0) : 0.0;

          final accId =
              'acc_mig_${code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
          upsertAccountingAccount(
            AccountingAccount(
              id: accId,
              code: code,
              name: name,
              type: AccountingAccountType.fromName(typeRaw),
              groupName: 'Göç Sihirbazı Aktarımı',
              baseSalaryOrDailyRate: salary,
              trayBalance: trays,
            ),
          );
          accountsImported++;

          if (credit > 0) {
            upsertAccountingTransaction(
              AccountingTransaction(
                id: 'tx_mig_c_${accId}_$i',
                docNo: 'DVR-A-$code',
                dateKey: dateKey,
                accountId: accId,
                accountName: name,
                entryType: LedgerEntryType.cashIn,
                direction: 'A',
                amount: credit,
                cashOrBankName: 'Açılış Devir Fişi',
                description: 'Göç Sihirbazı Alacak Devri',
              ),
            );
            transactionsCreated++;
          }
          if (debit > 0) {
            upsertAccountingTransaction(
              AccountingTransaction(
                id: 'tx_mig_d_${accId}_$i',
                docNo: 'DVR-B-$code',
                dateKey: dateKey,
                accountId: accId,
                accountName: name,
                entryType: LedgerEntryType.salesOrder,
                direction: 'B',
                amount: debit,
                cashOrBankName: 'Açılış Devir Fişi',
                description: 'Göç Sihirbazı Borç Devri',
              ),
            );
            transactionsCreated++;
          }
        } else if (kind == 'STOK') {
          final code = parts[1].isEmpty ? 'STK-${i + 1}' : parts[1];
          final name = parts[2];
          final unit = parts.length > 3 ? parts[3] : 'ADET';
          final qty =
              parts.length > 4 ? (double.tryParse(parts[4]) ?? 0.0) : 0.0;
          final burn =
              parts.length > 5 ? (double.tryParse(parts[5]) ?? 1.0) : 1.0;
          final cost =
              parts.length > 6 ? (double.tryParse(parts[6]) ?? 0.0) : 0.0;

          final stkId =
              'stk_mig_${code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
          upsertStockBurnItem(
            StockBurnItem(
              id: stkId,
              code: code,
              name: name,
              unit: unit,
              currentQty: qty,
              dailyBurnRate: burn,
              unitCost: cost,
            ),
          );
          stocksImported++;
        } else {
          warnings.add('Satır ${i + 1}: Bilinmeyen kayıt türü "$kind"');
        }
      }
      rawDb.execute('COMMIT;');
    } catch (_) {
      rawDb.execute('ROLLBACK;');
      rethrow;
    }

    return MigrationImportResult(
      accountsImported: accountsImported,
      stocksImported: stocksImported,
      transactionsCreated: transactionsCreated,
      warnings: warnings,
    );
  }

  List<BranchPosReceipt> getBranchPosReceipts({int? branchId}) {
    final rows = branchId != null
        ? rawDb.select(
            'SELECT * FROM branch_pos_receipts WHERE branch_id = ? ORDER BY date_key DESC, id DESC',
            [branchId],
          )
        : rawDb.select(
            'SELECT * FROM branch_pos_receipts ORDER BY date_key DESC, id DESC',
          );
    return rows
        .map(
          (r) => BranchPosReceipt(
            id: r['id'] as String,
            receiptNo: r['receipt_no'] as String,
            branchId: r['branch_id'] as int? ?? 1,
            storeName: r['store_name'] as String? ?? '',
            dateKey: r['date_key'] as String? ?? '',
            timeText: r['time_text'] as String? ?? '',
            cashierName: r['cashier_name'] as String? ?? '',
            receiptType: r['receipt_type'] as String? ?? 'SATIŞ',
            paymentMethod: BranchPosPaymentMethod.fromName(
              r['payment_method'] as String?,
            ),
            totalAmountTl: (r['total_amount_tl'] as num? ?? 0).toDouble(),
            cashAmountTl: (r['cash_amount_tl'] as num? ?? 0).toDouble(),
            posAmountTl: (r['pos_amount_tl'] as num? ?? 0).toDouble(),
            openAccountAmountTl:
                (r['open_account_amount_tl'] as num? ?? 0).toDouble(),
            receivedCashTl: (r['received_cash_tl'] as num? ?? 0).toDouble(),
            changeReturnedTl:
                (r['change_returned_tl'] as num? ?? 0).toDouble(),
            customerName: r['customer_name'] as String? ?? '',
            customerPhone: r['customer_phone'] as String? ?? '',
            note: r['note'] as String? ?? '',
            sweetWeightKg: (r['sweet_weight_kg'] as num? ?? 0).toDouble(),
            boxCount: r['box_count'] as int? ?? 0,
            boxTareWeightKg:
                (r['box_tare_weight_kg'] as num? ?? 0).toDouble(),
            complimentaryLineCount:
                r['complimentary_line_count'] as int? ?? 0,
            syncedToHeadquarters: (r['synced_to_hq'] as int? ?? 1) == 1,
            itemsSummary: r['items_summary'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertBranchPosReceipt(BranchPosReceipt rcp) {
    final stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO branch_pos_receipts
      (id, receipt_no, branch_id, store_name, date_key, time_text, cashier_name, receipt_type, payment_method, total_amount_tl, cash_amount_tl, pos_amount_tl, open_account_amount_tl, received_cash_tl, change_returned_tl, customer_name, customer_phone, note, sweet_weight_kg, box_count, box_tare_weight_kg, complimentary_line_count, synced_to_hq, items_summary)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      rcp.id.trim(),
      rcp.receiptNo.trim().toUpperCase(),
      rcp.branchId,
      rcp.storeName.trim(),
      rcp.dateKey.trim(),
      rcp.timeText.trim(),
      rcp.cashierName.trim(),
      rcp.receiptType.trim(),
      rcp.paymentMethod.name,
      rcp.totalAmountTl,
      rcp.cashAmountTl,
      rcp.posAmountTl,
      rcp.openAccountAmountTl,
      rcp.receivedCashTl,
      rcp.changeReturnedTl,
      rcp.customerName.trim(),
      rcp.customerPhone.trim(),
      rcp.note.trim(),
      rcp.sweetWeightKg,
      rcp.boxCount,
      rcp.boxTareWeightKg,
      rcp.complimentaryLineCount,
      rcp.syncedToHeadquarters ? 1 : 0,
      rcp.itemsSummary.trim(),
    ]);
    stmt.dispose();
  }

  List<BranchAuditInspectionRecord> getBranchAuditInspections({int? branchId}) {
    final rows = branchId != null
        ? rawDb.select(
            'SELECT * FROM branch_audit_inspections WHERE branch_id = ? ORDER BY date_key DESC, id DESC',
            [branchId],
          )
        : rawDb.select(
            'SELECT * FROM branch_audit_inspections ORDER BY date_key DESC, id DESC',
          );
    return rows
        .map(
          (r) => BranchAuditInspectionRecord(
            id: r['id'] as String,
            auditDocNo: r['audit_doc_no'] as String,
            dateKey: r['date_key'] as String? ?? '',
            branchId: r['branch_id'] as int? ?? 1,
            storeName: r['store_name'] as String? ?? '',
            inspectorName: r['inspector_name'] as String? ?? '',
            cancelledOrRefundCount:
                r['cancelled_or_refund_count'] as int? ?? 0,
            complimentaryItemCount:
                r['complimentary_item_count'] as int? ?? 0,
            cashierRiskScore:
                (r['cashier_risk_score'] as num? ?? 0).toDouble(),
            shippedTrayTotalKg:
                (r['shipped_tray_total_kg'] as num? ?? 0).toDouble(),
            posSoldPlusRemainingKg:
                (r['pos_sold_plus_remaining_kg'] as num? ?? 0).toDouble(),
            boxTareOffsetKg:
                (r['box_tare_offset_kg'] as num? ?? 0).toDouble(),
            unaccountedFireKg:
                (r['unaccounted_fire_kg'] as num? ?? 0).toDouble(),
            blindCashVarianceTl:
                (r['blind_cash_variance_tl'] as num? ?? 0).toDouble(),
            blindStockVarianceTl:
                (r['blind_stock_variance_tl'] as num? ?? 0).toDouble(),
            pdksCheckedInStaffCount:
                r['pdks_checked_in_staff_count'] as int? ?? 0,
            posActiveCashierCount:
                r['pos_active_cashier_count'] as int? ?? 0,
            ghostCashierDetected:
                (r['ghost_cashier_detected'] as int? ?? 0) == 1,
            coldChainTempCelsius:
                (r['cold_chain_temp_celsius'] as num? ?? -18.0).toDouble(),
            hygieneChecklistScore:
                r['hygiene_checklist_score'] as int? ?? 95,
            findingSummary: r['finding_summary'] as String? ?? '',
            actionPlan: r['action_plan'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertBranchAuditInspection(BranchAuditInspectionRecord aud) {
    final stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO branch_audit_inspections
      (id, audit_doc_no, date_key, branch_id, store_name, inspector_name, cancelled_or_refund_count, complimentary_item_count, cashier_risk_score, shipped_tray_total_kg, pos_sold_plus_remaining_kg, box_tare_offset_kg, unaccounted_fire_kg, blind_cash_variance_tl, blind_stock_variance_tl, pdks_checked_in_staff_count, pos_active_cashier_count, ghost_cashier_detected, cold_chain_temp_celsius, hygiene_checklist_score, finding_summary, action_plan)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      aud.id.trim(),
      aud.auditDocNo.trim().toUpperCase(),
      aud.dateKey.trim(),
      aud.branchId,
      aud.storeName.trim(),
      aud.inspectorName.trim(),
      aud.cancelledOrRefundCount,
      aud.complimentaryItemCount,
      aud.cashierRiskScore,
      aud.shippedTrayTotalKg,
      aud.posSoldPlusRemainingKg,
      aud.boxTareOffsetKg,
      aud.unaccountedFireKg,
      aud.blindCashVarianceTl,
      aud.blindStockVarianceTl,
      aud.pdksCheckedInStaffCount,
      aud.posActiveCashierCount,
      aud.ghostCashierDetected ? 1 : 0,
      aud.coldChainTempCelsius,
      aud.hygieneChecklistScore,
      aud.findingSummary.trim(),
      aud.actionPlan.trim(),
    ]);
    stmt.dispose();
  }
}
