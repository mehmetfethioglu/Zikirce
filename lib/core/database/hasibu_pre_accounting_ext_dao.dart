import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../features/pdks/domain/accounting_models.dart';
import '../../features/pdks/domain/pre_accounting_advanced_contracts.dart';
import 'hasibu_database.dart';

const Map<String, String> _extTableInfoPragmas = <String, String>{
  'accounting_accounts': 'PRAGMA table_info(accounting_accounts)',
  'accounting_transactions': 'PRAGMA table_info(accounting_transactions)',
  'stock_burn_items': 'PRAGMA table_info(stock_burn_items)',
};

const List<({String table, String column, String alterSql})>
    _extColumnMigrations = <({String table, String column, String alterSql})>[
  (
    table: 'accounting_accounts',
    column: 'special_code',
    alterSql:
        "ALTER TABLE accounting_accounts ADD COLUMN special_code TEXT NOT NULL DEFAULT ''",
  ),
  (
    table: 'accounting_accounts',
    column: 'price_tier',
    alterSql:
        'ALTER TABLE accounting_accounts ADD COLUMN price_tier INTEGER NOT NULL DEFAULT 1',
  ),
  (
    table: 'accounting_accounts',
    column: 'default_discount_percent',
    alterSql:
        'ALTER TABLE accounting_accounts ADD COLUMN default_discount_percent REAL NOT NULL DEFAULT 0.0',
  ),
  (
    table: 'accounting_accounts',
    column: 'sales_rep_name',
    alterSql:
        "ALTER TABLE accounting_accounts ADD COLUMN sales_rep_name TEXT NOT NULL DEFAULT ''",
  ),
  (
    table: 'accounting_accounts',
    column: 'credit_limit_tl',
    alterSql:
        'ALTER TABLE accounting_accounts ADD COLUMN credit_limit_tl REAL NOT NULL DEFAULT 0.0',
  ),
  (
    table: 'accounting_accounts',
    column: 'city_district',
    alterSql:
        "ALTER TABLE accounting_accounts ADD COLUMN city_district TEXT NOT NULL DEFAULT ''",
  ),
  (
    table: 'accounting_transactions',
    column: 'currency_code',
    alterSql:
        "ALTER TABLE accounting_transactions ADD COLUMN currency_code TEXT NOT NULL DEFAULT 'TRY'",
  ),
  (
    table: 'accounting_transactions',
    column: 'fx_rate',
    alterSql:
        'ALTER TABLE accounting_transactions ADD COLUMN fx_rate REAL NOT NULL DEFAULT 1.0',
  ),
  (
    table: 'accounting_transactions',
    column: 'fx_amount',
    alterSql:
        'ALTER TABLE accounting_transactions ADD COLUMN fx_amount REAL NOT NULL DEFAULT 0.0',
  ),
  (
    table: 'accounting_transactions',
    column: 'discount_percent',
    alterSql:
        'ALTER TABLE accounting_transactions ADD COLUMN discount_percent REAL NOT NULL DEFAULT 0.0',
  ),
  (
    table: 'accounting_transactions',
    column: 'sales_rep_name',
    alterSql:
        "ALTER TABLE accounting_transactions ADD COLUMN sales_rep_name TEXT NOT NULL DEFAULT ''",
  ),
  (
    table: 'accounting_transactions',
    column: 'settled_amount_tl',
    alterSql:
        'ALTER TABLE accounting_transactions ADD COLUMN settled_amount_tl REAL NOT NULL DEFAULT 0.0',
  ),
  (
    table: 'accounting_transactions',
    column: 'linked_order_doc_id',
    alterSql:
        "ALTER TABLE accounting_transactions ADD COLUMN linked_order_doc_id TEXT NOT NULL DEFAULT ''",
  ),
  (
    table: 'stock_burn_items',
    column: 'sale_price_tl',
    alterSql:
        'ALTER TABLE stock_burn_items ADD COLUMN sale_price_tl REAL NOT NULL DEFAULT 0.0',
  ),
  (
    table: 'stock_burn_items',
    column: 'deposit_unit_tl',
    alterSql:
        'ALTER TABLE stock_burn_items ADD COLUMN deposit_unit_tl REAL NOT NULL DEFAULT 0.0',
  ),
  (
    table: 'stock_burn_items',
    column: 'template_category',
    alterSql:
        "ALTER TABLE stock_burn_items ADD COLUMN template_category TEXT NOT NULL DEFAULT ''",
  ),
  (
    table: 'stock_burn_items',
    column: 'price_history_json',
    alterSql:
        "ALTER TABLE stock_burn_items ADD COLUMN price_history_json TEXT NOT NULL DEFAULT '[]'",
  ),
];

const String _createPreAccountingExtTablesSql = '''
  CREATE TABLE IF NOT EXISTS erp_documents (
    id TEXT PRIMARY KEY,
    order_doc_no TEXT NOT NULL,
    waybill_doc_no TEXT,
    invoice_doc_no TEXT,
    date_key TEXT NOT NULL,
    account_id TEXT NOT NULL,
    account_name TEXT NOT NULL,
    region_group TEXT NOT NULL DEFAULT 'Marmara Bayi (Fiyat-2)',
    price_tier INTEGER NOT NULL DEFAULT 2,
    stock_code TEXT NOT NULL,
    stock_name TEXT NOT NULL,
    ordered_qty_kg REAL NOT NULL DEFAULT 0.0,
    shipped_qty_kg REAL NOT NULL DEFAULT 0.0,
    invoiced_qty_kg REAL NOT NULL DEFAULT 0.0,
    tray_count INTEGER NOT NULL DEFAULT 1,
    unit_price_tl REAL NOT NULL DEFAULT 0.0,
    discount_percent REAL NOT NULL DEFAULT 0.0,
    vat_percent REAL NOT NULL DEFAULT 10.0,
    collected_amount_tl REAL NOT NULL DEFAULT 0.0,
    stage TEXT NOT NULL DEFAULT 'SIPARIS',
    is_official_vat_reflected INTEGER NOT NULL DEFAULT 0,
    doc_kind TEXT NOT NULL DEFAULT 'NORMAL',
    sales_rep_name TEXT NOT NULL DEFAULT '',
    deposit_amount_tl REAL NOT NULL DEFAULT 0.0
  );

  CREATE INDEX IF NOT EXISTS idx_erp_documents_account_date
    ON erp_documents(account_id, date_key);

  CREATE INDEX IF NOT EXISTS idx_erp_documents_stage
    ON erp_documents(stage);

  CREATE TABLE IF NOT EXISTS production_recipes (
    id TEXT PRIMARY KEY,
    recipe_code TEXT NOT NULL,
    product_name TEXT NOT NULL,
    recipe_category TEXT NOT NULL DEFAULT 'BAKLAVA_GENEL',
    batch_output_kg REAL NOT NULL DEFAULT 0.0,
    tray_yield_count INTEGER NOT NULL DEFAULT 10,
    ingredients_summary TEXT NOT NULL DEFAULT '',
    raw_material_cost_tl REAL NOT NULL DEFAULT 0.0,
    overhead_cost_tl REAL NOT NULL DEFAULT 450.0,
    fire_waste_percent REAL NOT NULL DEFAULT 3.2,
    produced_batches_today INTEGER NOT NULL DEFAULT 1
  );

  CREATE TABLE IF NOT EXISTS custom_spreadsheets (
    id TEXT PRIMARY KEY,
    sheet_title TEXT NOT NULL,
    category_name TEXT NOT NULL,
    period_key TEXT NOT NULL,
    debit_column_tl REAL NOT NULL DEFAULT 0.0,
    credit_column_tl REAL NOT NULL DEFAULT 0.0,
    formula_note TEXT NOT NULL DEFAULT ''
  );

  CREATE INDEX IF NOT EXISTS idx_custom_spreadsheets_period
    ON custom_spreadsheets(period_key);

  CREATE TABLE IF NOT EXISTS accounting_check_portfolio (
    id TEXT PRIMARY KEY,
    bordro_no TEXT NOT NULL,
    is_incoming INTEGER NOT NULL DEFAULT 1,
    account_id TEXT NOT NULL,
    account_name TEXT NOT NULL,
    bank_name TEXT NOT NULL,
    serial_no TEXT NOT NULL,
    issue_date_key TEXT NOT NULL,
    due_date_key TEXT NOT NULL,
    amount_tl REAL NOT NULL DEFAULT 0.0,
    currency_code TEXT NOT NULL DEFAULT 'TRY',
    fx_rate REAL NOT NULL DEFAULT 1.0,
    status TEXT NOT NULL DEFAULT 'inPortfolio',
    endorsed_to_account_id TEXT NOT NULL DEFAULT '',
    endorsed_to_name TEXT NOT NULL DEFAULT '',
    linked_invoice_doc_no TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT ''
  );

  CREATE INDEX IF NOT EXISTS idx_check_portfolio_account_due
    ON accounting_check_portfolio(account_id, due_date_key);

  CREATE INDEX IF NOT EXISTS idx_check_portfolio_status
    ON accounting_check_portfolio(status);

  CREATE TABLE IF NOT EXISTS payment_instruction_templates (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL DEFAULT 'BANKA',
    target_bank_or_cash_name TEXT NOT NULL,
    iban TEXT NOT NULL DEFAULT '',
    template_body TEXT NOT NULL DEFAULT ''
  );

  CREATE TABLE IF NOT EXISTS payment_orders (
    id TEXT PRIMARY KEY,
    order_no TEXT NOT NULL,
    date_key TEXT NOT NULL,
    due_date_key TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'BANKA',
    bank_or_cash_name TEXT NOT NULL,
    account_id TEXT NOT NULL,
    account_name TEXT NOT NULL,
    iban TEXT NOT NULL DEFAULT '',
    amount_tl REAL NOT NULL DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'BEKLIYOR',
    rendered_instruction TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT ''
  );

  CREATE INDEX IF NOT EXISTS idx_payment_orders_status_due
    ON payment_orders(status, due_date_key);

  CREATE TABLE IF NOT EXISTS dealer_contracts (
    id TEXT PRIMARY KEY,
    contract_no TEXT NOT NULL,
    date_key TEXT NOT NULL,
    duration_months INTEGER NOT NULL DEFAULT 12,
    collateral_amount_tl REAL NOT NULL DEFAULT 0.0,
    collateral_type TEXT NOT NULL DEFAULT 'Teminat Mektubu',
    account_id TEXT NOT NULL,
    account_name TEXT NOT NULL,
    region_name TEXT NOT NULL DEFAULT '',
    price_tier INTEGER NOT NULL DEFAULT 1,
    dealer_margin_percent REAL NOT NULL DEFAULT 0.0,
    is_terminated INTEGER NOT NULL DEFAULT 0,
    termination_note TEXT NOT NULL DEFAULT ''
  );

  CREATE INDEX IF NOT EXISTS idx_dealer_contracts_account
    ON dealer_contracts(account_id);

  CREATE TABLE IF NOT EXISTS period_rollover_locks (
    from_period_key TEXT PRIMARY KEY,
    next_period_key TEXT NOT NULL,
    rollover_date_key TEXT NOT NULL,
    summary_json TEXT NOT NULL,
    executed_at_iso TEXT NOT NULL
  );
''';

const List<ErpOrderWaybillInvoiceItem> _extDemoErpDocuments =
    <ErpOrderWaybillInvoiceItem>[
  ErpOrderWaybillInvoiceItem(
    id: 'erp_doc_1',
    orderDocNo: 'SIP-2026-801',
    waybillDocNo: 'IRS-2026-801',
    invoiceDocNo: 'FAT-2026-801',
    dateKey: '2026-10-21',
    accountId: 'acc_demo_cust_1',
    accountName: 'EGE BÖLGE KURUMSAL DAĞITIM A.Ş.',
    regionGroup: 'Ege Kurumsal Bayi (Fiyat-2)',
    priceTier: 2,
    stockCode: 'BKL-001',
    stockName: 'FISTIKLI KARE BAKLAVA (TEPSİ)',
    orderedQtyKg: 480.0,
    shippedQtyKg: 480.0,
    invoicedQtyKg: 480.0,
    trayCount: 120,
    unitPriceTl: 640.0,
    discountPercent: 5.0,
    vatPercent: 10.0,
    collectedAmountTl: 180000.0,
    stage: 'FATURALANDI',
    isOfficialVatReflected: true,
    docKind: 'NORMAL',
    salesRepName: 'Ahmet Kaya',
    depositAmountTl: 42000.0,
  ),
  ErpOrderWaybillInvoiceItem(
    id: 'erp_doc_2',
    orderDocNo: 'SIP-2026-802',
    waybillDocNo: 'IRS-2026-802',
    invoiceDocNo: null,
    dateKey: '2026-10-21',
    accountId: 'acc_demo_cust_2',
    accountName: 'BAŞKENT GIDA & PERAKENDE LTD.',
    regionGroup: 'İç Anadolu Bayi (Fiyat-3)',
    priceTier: 3,
    stockCode: 'BKL-002',
    stockName: 'CEVİZLİ EV BAKLAVASI (TEPSİ)',
    orderedQtyKg: 240.0,
    shippedQtyKg: 240.0,
    invoicedQtyKg: 0.0,
    trayCount: 60,
    unitPriceTl: 490.0,
    discountPercent: 3.0,
    vatPercent: 10.0,
    collectedAmountTl: 0.0,
    stage: 'IRSALIYE_SEVK',
    isOfficialVatReflected: false,
    docKind: 'NORMAL',
    salesRepName: 'Selin Demir',
    depositAmountTl: 21000.0,
  ),
  ErpOrderWaybillInvoiceItem(
    id: 'erp_doc_3',
    orderDocNo: 'SIP-2026-803',
    waybillDocNo: null,
    invoiceDocNo: null,
    dateKey: '2026-10-21',
    accountId: 'acc_demo_branch_1',
    accountName: 'MARMARA MERKEZ MAĞAZA ŞUBESİ',
    regionGroup: 'Şube Sevkiyat (Fiyat-1)',
    priceTier: 1,
    stockCode: 'BKL-003',
    stockName: 'SOĞUK BAKLAVA & FISTIK SARMA',
    orderedQtyKg: 160.0,
    shippedQtyKg: 0.0,
    invoicedQtyKg: 0.0,
    trayCount: 45,
    unitPriceTl: 580.0,
    discountPercent: 0.0,
    vatPercent: 10.0,
    collectedAmountTl: 0.0,
    stage: 'SIPARIS',
    isOfficialVatReflected: false,
    docKind: 'NORMAL',
    salesRepName: 'Merkez Ekip',
    depositAmountTl: 15750.0,
  ),
];

const List<ProductionRecipeBom> _extDemoProductionRecipes =
    <ProductionRecipeBom>[
  ProductionRecipeBom(
    id: 'rcp_demo_1',
    recipeCode: 'RCP-BKL-01',
    productName: 'ANTEP FISTIKLI KLASİK BAKLAVA (10 TEPSİ HARÇ)',
    recipeCategory: 'BAKLAVA_GENEL',
    batchOutputKg: 40.0,
    trayYieldCount: 10,
    ingredientsSummary:
        'Özel Baklavalık Un 14kg, Sade Tereyağı 7.5kg, Boz İç Fıstık 5.5kg, Kristal Şeker 13kg, Yumurta 45 Adet',
    rawMaterialCostTl: 12450.0,
    overheadCostTl: 850.0,
    fireWastePercent: 2.8,
    producedBatchesToday: 12,
  ),
  ProductionRecipeBom(
    id: 'rcp_demo_2',
    recipeCode: 'RCP-BGD-01',
    productName: 'TAŞ DEĞİRMEN BUĞDAY & BULGUR ÜRETİM REÇETESİ',
    recipeCategory: 'BUGDAY_BULGUR',
    batchOutputKg: 880.0,
    trayYieldCount: 35,
    ingredientsSummary:
        'Sert Durum Buğdayı 1000kg, Kaynatma Buhar & Kurutma, Kabuk Soyma ve Boylama Elek',
    rawMaterialCostTl: 16800.0,
    overheadCostTl: 1450.0,
    fireWastePercent: 12.0,
    producedBatchesToday: 3,
  ),
  ProductionRecipeBom(
    id: 'rcp_demo_3',
    recipeCode: 'RCP-RSM-01',
    productName: 'RESMİ MUHASEBE ENTEGRE BAKLAVA REÇETESİ (%10 KDV)',
    recipeCategory: 'RESMI_RECETE',
    batchOutputKg: 100.0,
    trayYieldCount: 25,
    ingredientsSummary:
        'Resmi Alış Faturalı Un 35kg, Faturalı Şeker 32kg, Faturalı Yağ 18kg, Faturalı Fıstık 15kg',
    rawMaterialCostTl: 29800.0,
    overheadCostTl: 1900.0,
    fireWastePercent: 2.5,
    producedBatchesToday: 5,
  ),
];

const List<CustomSpreadsheetRecord> _extDemoCustomSpreadsheets =
    <CustomSpreadsheetRecord>[
  CustomSpreadsheetRecord(
    id: 'xls_demo_1',
    sheetTitle: 'BAYİ KOTA & TEPSİ İADE MUTABAKAT TABLOSU',
    categoryName: 'Ege & Marmara Bayileri',
    periodKey: '2026-10',
    debitColumnTl: 865000.0,
    creditColumnTl: 1120000.0,
    formulaNote: '=SUM(C2:C18)-SUM(B2:B18) | Bayi prim iskontosu %4 düşüldü',
  ),
  CustomSpreadsheetRecord(
    id: 'xls_demo_2',
    sheetTitle: 'ŞUBELER KİRA, ENERJİ & SARF MALZEME KARŞILAŞTIRMASI',
    categoryName: 'Mağaza İşletme Giderleri',
    periodKey: '2026-10',
    debitColumnTl: 214500.0,
    creditColumnTl: 289000.0,
    formulaNote: '=AVERAGE(Gider/Ciro) -> Hedef %12.5 altında kaldı',
  ),
];

const List<CheckPortfolioItem> _extDemoCheckPortfolio = <CheckPortfolioItem>[
  CheckPortfolioItem(
    id: 'chk_port_1',
    bordroNo: 'BRD-2026-001',
    isIncoming: true,
    accountId: 'acc_demo_cust_1',
    accountName: 'EGE BÖLGE KURUMSAL DAĞITIM A.Ş.',
    bankName: 'Türkiye İş Bankası İzmir Ticari Şb.',
    serialNo: 'ISB-7845120',
    issueDateKey: '2026-10-18',
    dueDateKey: '2026-11-15',
    amountTl: 325000.0,
    currencyCode: 'TRY',
    fxRate: 1.0,
    status: CheckPortfolioStatus.inPortfolio,
    linkedInvoiceDocNo: 'FAT-2026-801',
    note: 'Ege bölge sevkiyat müşteri portföy çeki',
  ),
  CheckPortfolioItem(
    id: 'chk_port_2',
    bordroNo: 'BRD-2026-002',
    isIncoming: false,
    accountId: 'acc_demo_supp_1',
    accountName: 'TRAKYA UN & TAHIL SANAYİ A.Ş.',
    bankName: 'Ziraat Bankası Merkez Kurumsal Şb.',
    serialNo: 'ZRB-4402190',
    issueDateKey: '2026-10-20',
    dueDateKey: '2026-11-28',
    amountTl: 195000.0,
    currencyCode: 'TRY',
    fxRate: 1.0,
    status: CheckPortfolioStatus.inPortfolio,
    linkedInvoiceDocNo: 'FAT-2026-412',
    note: 'Un & nişasta alım borç çeki',
  ),
  CheckPortfolioItem(
    id: 'chk_port_3',
    bordroNo: 'BRD-2026-003',
    isIncoming: true,
    accountId: 'acc_demo_cust_2',
    accountName: 'BAŞKENT GIDA & PERAKENDE LTD.',
    bankName: 'Garanti BBVA Çankaya Şb.',
    serialNo: 'GAR-9912450',
    issueDateKey: '2026-10-05',
    dueDateKey: '2026-10-20',
    amountTl: 145000.0,
    currencyCode: 'TRY',
    fxRate: 1.0,
    status: CheckPortfolioStatus.collected,
    note: 'Vadesinde tahsil edildi',
  ),
];

const List<PaymentInstructionTemplate> _extDemoPaymentTemplates =
    <PaymentInstructionTemplate>[
  PaymentInstructionTemplate(
    id: 'pmt_tpl_1',
    kind: 'BANKA',
    targetBankOrCashName: 'Ticari Vadesiz Banka',
    iban: 'TR33 0006 1005 1978 6457 8413 26',
    templateBody:
        'Tarih: @TalimatTarihi | Sayın Yetkili, @Unvan (@IBAN) hesabına @Tutar (@YaziylaTutar) EFT/Havale yapılmasını rica ederiz. Açıklama: @Aciklama',
  ),
  PaymentInstructionTemplate(
    id: 'pmt_tpl_2',
    kind: 'KASA',
    targetBankOrCashName: 'Merkez TL Kasa',
    iban: '',
    templateBody:
        'Kasa Tediye Talimatı (@TalimatTarihi): @Unvan carisine @Tutar (@YaziylaTutar) nakit ödeme onaylanmıştır. Not: @Aciklama',
  ),
];

const List<PaymentOrderRecord> _extDemoPaymentOrders = <PaymentOrderRecord>[
  PaymentOrderRecord(
    id: 'pmt_ord_1',
    orderNo: 'ODM-2026-101',
    dateKey: '2026-10-21',
    dueDateKey: '2026-10-25',
    kind: 'BANKA',
    bankOrCashName: 'Ticari Vadesiz Banka',
    accountId: 'acc_demo_supp_1',
    accountName: 'TRAKYA UN & TAHIL SANAYİ A.Ş.',
    iban: 'TR48 0001 0002 4500 1234 5678 90',
    amountTl: 125000.0,
    status: 'BEKLIYOR',
    renderedInstruction:
        'Tarih: 2026-10-25 | Sayın Yetkili, TRAKYA UN & TAHIL SANAYİ A.Ş. (TR48 0001 0002 4500 1234 5678 90) hesabına 125.000,00 ₺ (#Yalnız Yüz Yirmi Beş Bin Türk Lirası\'dır#) EFT/Havale yapılmasını rica ederiz. Açıklama: Ekim 2. parti un faturası ödemesi',
    note: 'Ekim 2. parti un faturası ödemesi',
  ),
  PaymentOrderRecord(
    id: 'pmt_ord_2',
    orderNo: 'ODM-2026-102',
    dateKey: '2026-10-20',
    dueDateKey: '2026-10-21',
    kind: 'KASA',
    bankOrCashName: 'Merkez TL Kasa',
    accountId: 'acc_demo_supp_2',
    accountName: 'AKDENİZ AMBALAJ & KUTU SANAYİ',
    iban: '',
    amountTl: 34500.0,
    status: 'ODENDI',
    renderedInstruction:
        'Kasa Tediye Talimatı (2026-10-21): AKDENİZ AMBALAJ & KUTU SANAYİ carisine 34.500,00 ₺ (#Yalnız Otuz Dört Bin Beş Yüz Türk Lirası\'dır#) nakit ödeme onaylanmıştır. Not: Baskılı baklava kutusu teslimat ödemesi',
    note: 'Baskılı baklava kutusu teslimat ödemesi',
  ),
];

const List<DealerContractRecord> _extDemoDealerContracts =
    <DealerContractRecord>[
  DealerContractRecord(
    id: 'dlr_cnt_1',
    contractNo: 'BAY-SZL-2026-01',
    dateKey: '2026-01-15',
    durationMonths: 24,
    collateralAmountTl: 500000.0,
    collateralType: 'Banka Teminat Mektubu',
    accountId: 'acc_demo_cust_1',
    accountName: 'EGE BÖLGE KURUMSAL DAĞITIM A.Ş.',
    regionName: 'Ege Bölgesi',
    priceTier: 2,
    dealerMarginPercent: 14.5,
  ),
  DealerContractRecord(
    id: 'dlr_cnt_2',
    contractNo: 'BAY-SZL-2026-02',
    dateKey: '2026-03-01',
    durationMonths: 12,
    collateralAmountTl: 250000.0,
    collateralType: 'Teminat Senedi',
    accountId: 'acc_demo_cust_2',
    accountName: 'BAŞKENT GIDA & PERAKENDE LTD.',
    regionName: 'İç Anadolu Bölgesi',
    priceTier: 3,
    dealerMarginPercent: 11.0,
  ),
];

class _AccountCarryBalance {
  final String accountId;
  final String accountCode;
  final String accountName;
  final double netBalance;

  const _AccountCarryBalance({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.netBalance,
  });
}

class _StockCarryEntry {
  final String id;
  final String code;
  final String name;
  final String unit;
  final double currentQty;
  final double unitCost;
  final String priceHistoryJson;

  const _StockCarryEntry({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.currentQty,
    required this.unitCost,
    required this.priceHistoryJson,
  });

  double get valuationTl => currentQty * unitCost;
}

class _OpenCheckCarryEntry {
  final String id;
  final String bordroNo;
  final String serialNo;
  final String dueDateKey;
  final bool isIncoming;
  final double amountTl;

  const _OpenCheckCarryEntry({
    required this.id,
    required this.bordroNo,
    required this.serialNo,
    required this.dueDateKey,
    required this.isIncoming,
    required this.amountTl,
  });
}

class _RolloverComputedSnapshot {
  final String fromPeriodKey;
  final String nextPeriodKey;
  final String rolloverDateKey;
  final List<_AccountCarryBalance> nonZeroAccounts;
  final double totalReceivableCarryTl;
  final double totalPayableCarryTl;
  final List<_OpenCheckCarryEntry> openChecks;
  final double openCheckTotalTl;
  final List<_StockCarryEntry> stocks;
  final double stockValuationCarryTl;

  const _RolloverComputedSnapshot({
    required this.fromPeriodKey,
    required this.nextPeriodKey,
    required this.rolloverDateKey,
    required this.nonZeroAccounts,
    required this.totalReceivableCarryTl,
    required this.totalPayableCarryTl,
    required this.openChecks,
    required this.openCheckTotalTl,
    required this.stocks,
    required this.stockValuationCarryTl,
  });

  PeriodRolloverPreview toPreview({required bool alreadyExecuted}) {
    return PeriodRolloverPreview(
      fromPeriodKey: fromPeriodKey,
      nextPeriodKey: nextPeriodKey,
      rolloverDateKey: rolloverDateKey,
      accountCount: nonZeroAccounts.length,
      totalReceivableCarryTl:
          double.parse(totalReceivableCarryTl.toStringAsFixed(2)),
      totalPayableCarryTl:
          double.parse(totalPayableCarryTl.toStringAsFixed(2)),
      openCheckCount: openChecks.length,
      openCheckTotalTl: double.parse(openCheckTotalTl.toStringAsFixed(2)),
      stockItemCount: stocks.length,
      stockValuationCarryTl:
          double.parse(stockValuationCarryTl.toStringAsFixed(2)),
      alreadyExecuted: alreadyExecuted,
    );
  }
}

/// Hasibu İleri Ön Muhasebe Uzantı SQLite Katmanı (DAG uyumlu, parametreli SQL).
extension HasibuPreAccountingExtDao on HasibuDatabase {
  /// Mevcut temel tablolara yeni sütunları idempotent ekler ve 7+1 uzantı tablosunu kurar.
  void initPreAccountingExtSchema() {
    final columnsByTable = <String, Set<String>>{};
    for (final entry in _extTableInfoPragmas.entries) {
      final ResultSet infoRows = rawDb.select(entry.value);
      columnsByTable[entry.key] = <String>{
        for (final Row row in infoRows)
          if (row['name'] is String) row['name'] as String,
      };
    }

    for (final migration in _extColumnMigrations) {
      final cols = columnsByTable[migration.table];
      if (cols == null || cols.isEmpty) continue;
      if (!cols.contains(migration.column)) {
        rawDb.execute(migration.alterSql);
        cols.add(migration.column);
      }
    }

    rawDb.execute(_createPreAccountingExtTablesSql);
  }

  /// Uzantı tablolarını ve dönem devir kilitlerini atomik olarak temizler.
  void clearPreAccountingExtTables() {
    rawDb.execute('SAVEPOINT sp_pre_acc_ext_clear;');
    try {
      rawDb.execute('DELETE FROM erp_documents;');
      rawDb.execute('DELETE FROM production_recipes;');
      rawDb.execute('DELETE FROM custom_spreadsheets;');
      rawDb.execute('DELETE FROM accounting_check_portfolio;');
      rawDb.execute('DELETE FROM payment_instruction_templates;');
      rawDb.execute('DELETE FROM payment_orders;');
      rawDb.execute('DELETE FROM dealer_contracts;');
      rawDb.execute('DELETE FROM period_rollover_locks;');
      rawDb.execute('RELEASE SAVEPOINT sp_pre_acc_ext_clear;');
    } catch (_) {
      rawDb.execute('ROLLBACK TO SAVEPOINT sp_pre_acc_ext_clear;');
      rawDb.execute('RELEASE SAVEPOINT sp_pre_acc_ext_clear;');
      rethrow;
    }
  }

  /// Yalnızca boş olan uzantı tablolarına örnek Hasibu demo verilerini yükler.
  void seedPreAccountingExtDemoData() {
    rawDb.execute('SAVEPOINT sp_pre_acc_ext_seed;');
    try {
      if (_tableRowCount('SELECT COUNT(*) AS cnt FROM erp_documents') == 0) {
        for (final doc in _extDemoErpDocuments) {
          upsertErpDocument(doc);
        }
      }
      if (_tableRowCount('SELECT COUNT(*) AS cnt FROM production_recipes') ==
          0) {
        for (final recipe in _extDemoProductionRecipes) {
          upsertProductionRecipe(recipe);
        }
      }
      if (_tableRowCount('SELECT COUNT(*) AS cnt FROM custom_spreadsheets') ==
          0) {
        for (final sheet in _extDemoCustomSpreadsheets) {
          upsertCustomSpreadsheet(sheet);
        }
      }
      if (_tableRowCount(
              'SELECT COUNT(*) AS cnt FROM accounting_check_portfolio') ==
          0) {
        for (final chk in _extDemoCheckPortfolio) {
          upsertCheckPortfolioItem(chk);
        }
      }
      if (_tableRowCount(
              'SELECT COUNT(*) AS cnt FROM payment_instruction_templates') ==
          0) {
        for (final tpl in _extDemoPaymentTemplates) {
          upsertPaymentInstructionTemplate(tpl);
        }
      }
      if (_tableRowCount('SELECT COUNT(*) AS cnt FROM payment_orders') == 0) {
        for (final ord in _extDemoPaymentOrders) {
          upsertPaymentOrder(ord);
        }
      }
      if (_tableRowCount('SELECT COUNT(*) AS cnt FROM dealer_contracts') == 0) {
        for (final contract in _extDemoDealerContracts) {
          upsertDealerContract(contract);
        }
      }
      rawDb.execute('RELEASE SAVEPOINT sp_pre_acc_ext_seed;');
    } catch (_) {
      rawDb.execute('ROLLBACK TO SAVEPOINT sp_pre_acc_ext_seed;');
      rawDb.execute('RELEASE SAVEPOINT sp_pre_acc_ext_seed;');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // 1. ERP BELGELERİ (erp_documents)
  // --------------------------------------------------------------------------

  List<ErpOrderWaybillInvoiceItem> getErpDocuments({String? accountId}) {
    final cleanAccId = accountId?.trim() ?? '';
    final ResultSet rows = cleanAccId.isNotEmpty
        ? rawDb.select(
            'SELECT * FROM erp_documents WHERE account_id = ? ORDER BY date_key DESC, id DESC',
            <Object?>[cleanAccId],
          )
        : rawDb.select(
            'SELECT * FROM erp_documents ORDER BY date_key DESC, id DESC',
          );

    return rows
        .map(
          (Row r) => ErpOrderWaybillInvoiceItem(
            id: r['id'] as String,
            orderDocNo: r['order_doc_no'] as String? ?? '',
            waybillDocNo: r['waybill_doc_no'] as String?,
            invoiceDocNo: r['invoice_doc_no'] as String?,
            dateKey: r['date_key'] as String? ?? '',
            accountId: r['account_id'] as String? ?? '',
            accountName: r['account_name'] as String? ?? '',
            regionGroup:
                r['region_group'] as String? ?? 'Marmara Bayi (Fiyat-2)',
            priceTier: r['price_tier'] as int? ?? 2,
            stockCode: r['stock_code'] as String? ?? '',
            stockName: r['stock_name'] as String? ?? '',
            orderedQtyKg: (r['ordered_qty_kg'] as num? ?? 0).toDouble(),
            shippedQtyKg: (r['shipped_qty_kg'] as num? ?? 0).toDouble(),
            invoicedQtyKg: (r['invoiced_qty_kg'] as num? ?? 0).toDouble(),
            trayCount: r['tray_count'] as int? ?? 1,
            unitPriceTl: (r['unit_price_tl'] as num? ?? 0).toDouble(),
            discountPercent: (r['discount_percent'] as num? ?? 0).toDouble(),
            vatPercent: (r['vat_percent'] as num? ?? 10).toDouble(),
            collectedAmountTl:
                (r['collected_amount_tl'] as num? ?? 0).toDouble(),
            stage: r['stage'] as String? ?? 'SIPARIS',
            isOfficialVatReflected:
                (r['is_official_vat_reflected'] as int? ?? 0) == 1,
            docKind: r['doc_kind'] as String? ?? 'NORMAL',
            salesRepName: r['sales_rep_name'] as String? ?? '',
            depositAmountTl: (r['deposit_amount_tl'] as num? ?? 0).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  void upsertErpDocument(ErpOrderWaybillInvoiceItem doc) {
    final PreparedStatement stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO erp_documents (
        id, order_doc_no, waybill_doc_no, invoice_doc_no, date_key,
        account_id, account_name, region_group, price_tier, stock_code,
        stock_name, ordered_qty_kg, shipped_qty_kg, invoiced_qty_kg,
        tray_count, unit_price_tl, discount_percent, vat_percent,
        collected_amount_tl, stage, is_official_vat_reflected,
        doc_kind, sales_rep_name, deposit_amount_tl
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute(<Object?>[
        doc.id.trim(),
        doc.orderDocNo.trim().toUpperCase(),
        doc.waybillDocNo?.trim().toUpperCase(),
        doc.invoiceDocNo?.trim().toUpperCase(),
        doc.dateKey.trim(),
        doc.accountId.trim(),
        doc.accountName.trim().toUpperCase(),
        doc.regionGroup.trim(),
        doc.priceTier,
        doc.stockCode.trim().toUpperCase(),
        doc.stockName.trim().toUpperCase(),
        doc.orderedQtyKg,
        doc.shippedQtyKg,
        doc.invoicedQtyKg,
        doc.trayCount,
        doc.unitPriceTl,
        doc.discountPercent,
        doc.vatPercent,
        doc.collectedAmountTl,
        doc.stage.trim().toUpperCase(),
        doc.isOfficialVatReflected ? 1 : 0,
        doc.docKind.trim().toUpperCase(),
        doc.salesRepName.trim(),
        doc.depositAmountTl,
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deleteErpDocument(String id) {
    final PreparedStatement stmt = rawDb.prepare(
      'DELETE FROM erp_documents WHERE id = ?',
    );
    try {
      stmt.execute(<Object?>[id.trim()]);
    } finally {
      stmt.dispose();
    }
  }

  // --------------------------------------------------------------------------
  // 2. ÜRETİM REÇETELERİ / BOM (production_recipes)
  // --------------------------------------------------------------------------

  List<ProductionRecipeBom> getProductionRecipes() {
    final ResultSet rows = rawDb.select(
      'SELECT * FROM production_recipes ORDER BY recipe_code ASC, id ASC',
    );
    return rows
        .map(
          (Row r) => ProductionRecipeBom(
            id: r['id'] as String,
            recipeCode: r['recipe_code'] as String? ?? '',
            productName: r['product_name'] as String? ?? '',
            recipeCategory:
                r['recipe_category'] as String? ?? 'BAKLAVA_GENEL',
            batchOutputKg: (r['batch_output_kg'] as num? ?? 0).toDouble(),
            trayYieldCount: r['tray_yield_count'] as int? ?? 10,
            ingredientsSummary: r['ingredients_summary'] as String? ?? '',
            rawMaterialCostTl:
                (r['raw_material_cost_tl'] as num? ?? 0).toDouble(),
            overheadCostTl: (r['overhead_cost_tl'] as num? ?? 450).toDouble(),
            fireWastePercent:
                (r['fire_waste_percent'] as num? ?? 3.2).toDouble(),
            producedBatchesToday: r['produced_batches_today'] as int? ?? 1,
          ),
        )
        .toList(growable: false);
  }

  void upsertProductionRecipe(ProductionRecipeBom recipe) {
    final PreparedStatement stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO production_recipes (
        id, recipe_code, product_name, recipe_category, batch_output_kg,
        tray_yield_count, ingredients_summary, raw_material_cost_tl,
        overhead_cost_tl, fire_waste_percent, produced_batches_today
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute(<Object?>[
        recipe.id.trim(),
        recipe.recipeCode.trim().toUpperCase(),
        recipe.productName.trim().toUpperCase(),
        recipe.recipeCategory.trim().toUpperCase(),
        recipe.batchOutputKg,
        recipe.trayYieldCount,
        recipe.ingredientsSummary.trim(),
        recipe.rawMaterialCostTl,
        recipe.overheadCostTl,
        recipe.fireWastePercent,
        recipe.producedBatchesToday,
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deleteProductionRecipe(String id) {
    final PreparedStatement stmt = rawDb.prepare(
      'DELETE FROM production_recipes WHERE id = ?',
    );
    try {
      stmt.execute(<Object?>[id.trim()]);
    } finally {
      stmt.dispose();
    }
  }

  // --------------------------------------------------------------------------
  // 3. ÖZEL TABLOLAR (custom_spreadsheets)
  // --------------------------------------------------------------------------

  List<CustomSpreadsheetRecord> getCustomSpreadsheets({String? periodKey}) {
    final cleanPeriod = periodKey?.trim() ?? '';
    final ResultSet rows = cleanPeriod.isNotEmpty
        ? rawDb.select(
            'SELECT * FROM custom_spreadsheets WHERE period_key = ? ORDER BY sheet_title ASC, id ASC',
            <Object?>[cleanPeriod],
          )
        : rawDb.select(
            'SELECT * FROM custom_spreadsheets ORDER BY period_key DESC, sheet_title ASC, id ASC',
          );
    return rows
        .map(
          (Row r) => CustomSpreadsheetRecord(
            id: r['id'] as String,
            sheetTitle: r['sheet_title'] as String? ?? '',
            categoryName: r['category_name'] as String? ?? '',
            periodKey: r['period_key'] as String? ?? '',
            debitColumnTl: (r['debit_column_tl'] as num? ?? 0).toDouble(),
            creditColumnTl: (r['credit_column_tl'] as num? ?? 0).toDouble(),
            formulaNote: r['formula_note'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertCustomSpreadsheet(CustomSpreadsheetRecord record) {
    final PreparedStatement stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO custom_spreadsheets (
        id, sheet_title, category_name, period_key,
        debit_column_tl, credit_column_tl, formula_note
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute(<Object?>[
        record.id.trim(),
        record.sheetTitle.trim().toUpperCase(),
        record.categoryName.trim(),
        record.periodKey.trim(),
        record.debitColumnTl,
        record.creditColumnTl,
        record.formulaNote.trim(),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deleteCustomSpreadsheet(String id) {
    final PreparedStatement stmt = rawDb.prepare(
      'DELETE FROM custom_spreadsheets WHERE id = ?',
    );
    try {
      stmt.execute(<Object?>[id.trim()]);
    } finally {
      stmt.dispose();
    }
  }

  // --------------------------------------------------------------------------
  // 4. ÇEK / SENET PORTFÖYÜ (accounting_check_portfolio)
  // --------------------------------------------------------------------------

  List<CheckPortfolioItem> getCheckPortfolioItems({String? accountId}) {
    final cleanAccId = accountId?.trim() ?? '';
    final ResultSet rows = cleanAccId.isNotEmpty
        ? rawDb.select(
            'SELECT * FROM accounting_check_portfolio WHERE account_id = ? ORDER BY due_date_key ASC, id ASC',
            <Object?>[cleanAccId],
          )
        : rawDb.select(
            'SELECT * FROM accounting_check_portfolio ORDER BY due_date_key ASC, id ASC',
          );
    return rows
        .map(
          (Row r) => CheckPortfolioItem(
            id: r['id'] as String,
            bordroNo: r['bordro_no'] as String? ?? '',
            isIncoming: (r['is_incoming'] as int? ?? 1) == 1,
            accountId: r['account_id'] as String? ?? '',
            accountName: r['account_name'] as String? ?? '',
            bankName: r['bank_name'] as String? ?? '',
            serialNo: r['serial_no'] as String? ?? '',
            issueDateKey: r['issue_date_key'] as String? ?? '',
            dueDateKey: r['due_date_key'] as String? ?? '',
            amountTl: (r['amount_tl'] as num? ?? 0).toDouble(),
            currencyCode: r['currency_code'] as String? ?? 'TRY',
            fxRate: (r['fx_rate'] as num? ?? 1.0).toDouble(),
            status: CheckPortfolioStatus.fromName(r['status'] as String?),
            endorsedToAccountId: r['endorsed_to_account_id'] as String? ?? '',
            endorsedToName: r['endorsed_to_name'] as String? ?? '',
            linkedInvoiceDocNo: r['linked_invoice_doc_no'] as String? ?? '',
            note: r['note'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertCheckPortfolioItem(CheckPortfolioItem item) {
    final PreparedStatement stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO accounting_check_portfolio (
        id, bordro_no, is_incoming, account_id, account_name, bank_name,
        serial_no, issue_date_key, due_date_key, amount_tl, currency_code,
        fx_rate, status, endorsed_to_account_id, endorsed_to_name,
        linked_invoice_doc_no, note
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute(<Object?>[
        item.id.trim(),
        item.bordroNo.trim().toUpperCase(),
        item.isIncoming ? 1 : 0,
        item.accountId.trim(),
        item.accountName.trim().toUpperCase(),
        item.bankName.trim(),
        item.serialNo.trim().toUpperCase(),
        item.issueDateKey.trim(),
        item.dueDateKey.trim(),
        item.amountTl,
        item.currencyCode.trim().isEmpty
            ? 'TRY'
            : item.currencyCode.trim().toUpperCase(),
        item.fxRate <= 0 ? 1.0 : item.fxRate,
        item.status.name,
        item.endorsedToAccountId.trim(),
        item.endorsedToName.trim().toUpperCase(),
        item.linkedInvoiceDocNo.trim().toUpperCase(),
        item.note.trim(),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deleteCheckPortfolioItem(String id) {
    final PreparedStatement stmt = rawDb.prepare(
      'DELETE FROM accounting_check_portfolio WHERE id = ?',
    );
    try {
      stmt.execute(<Object?>[id.trim()]);
    } finally {
      stmt.dispose();
    }
  }

  // --------------------------------------------------------------------------
  // 5. ÖDEME TALİMAT ŞABLONLARI (payment_instruction_templates)
  // --------------------------------------------------------------------------

  List<PaymentInstructionTemplate> getPaymentInstructionTemplates() {
    final ResultSet rows = rawDb.select(
      'SELECT * FROM payment_instruction_templates ORDER BY kind ASC, target_bank_or_cash_name ASC, id ASC',
    );
    return rows
        .map(
          (Row r) => PaymentInstructionTemplate(
            id: r['id'] as String,
            kind: r['kind'] as String? ?? 'BANKA',
            targetBankOrCashName:
                r['target_bank_or_cash_name'] as String? ?? '',
            iban: r['iban'] as String? ?? '',
            templateBody: r['template_body'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertPaymentInstructionTemplate(PaymentInstructionTemplate template) {
    final PreparedStatement stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO payment_instruction_templates (
        id, kind, target_bank_or_cash_name, iban, template_body
      ) VALUES (?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute(<Object?>[
        template.id.trim(),
        template.kind.trim().toUpperCase(),
        template.targetBankOrCashName.trim(),
        template.iban.trim().toUpperCase(),
        template.templateBody.trim(),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deletePaymentInstructionTemplate(String id) {
    final PreparedStatement stmt = rawDb.prepare(
      'DELETE FROM payment_instruction_templates WHERE id = ?',
    );
    try {
      stmt.execute(<Object?>[id.trim()]);
    } finally {
      stmt.dispose();
    }
  }

  // --------------------------------------------------------------------------
  // 6. ÖDEME EMİRLERİ (payment_orders)
  // --------------------------------------------------------------------------

  List<PaymentOrderRecord> getPaymentOrders({String? status}) {
    final cleanStatus = status?.trim().toUpperCase() ?? '';
    final ResultSet rows = cleanStatus.isNotEmpty
        ? rawDb.select(
            'SELECT * FROM payment_orders WHERE status = ? ORDER BY due_date_key ASC, id DESC',
            <Object?>[cleanStatus],
          )
        : rawDb.select(
            'SELECT * FROM payment_orders ORDER BY due_date_key ASC, id DESC',
          );
    return rows
        .map(
          (Row r) => PaymentOrderRecord(
            id: r['id'] as String,
            orderNo: r['order_no'] as String? ?? '',
            dateKey: r['date_key'] as String? ?? '',
            dueDateKey: r['due_date_key'] as String? ?? '',
            kind: r['kind'] as String? ?? 'BANKA',
            bankOrCashName: r['bank_or_cash_name'] as String? ?? '',
            accountId: r['account_id'] as String? ?? '',
            accountName: r['account_name'] as String? ?? '',
            iban: r['iban'] as String? ?? '',
            amountTl: (r['amount_tl'] as num? ?? 0).toDouble(),
            status: r['status'] as String? ?? 'BEKLIYOR',
            renderedInstruction: r['rendered_instruction'] as String? ?? '',
            note: r['note'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertPaymentOrder(PaymentOrderRecord order) {
    final PreparedStatement stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO payment_orders (
        id, order_no, date_key, due_date_key, kind, bank_or_cash_name,
        account_id, account_name, iban, amount_tl, status,
        rendered_instruction, note
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute(<Object?>[
        order.id.trim(),
        order.orderNo.trim().toUpperCase(),
        order.dateKey.trim(),
        order.dueDateKey.trim(),
        order.kind.trim().toUpperCase(),
        order.bankOrCashName.trim(),
        order.accountId.trim(),
        order.accountName.trim().toUpperCase(),
        order.iban.trim().toUpperCase(),
        order.amountTl,
        order.status.trim().toUpperCase(),
        order.renderedInstruction.trim(),
        order.note.trim(),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deletePaymentOrder(String id) {
    final PreparedStatement stmt = rawDb.prepare(
      'DELETE FROM payment_orders WHERE id = ?',
    );
    try {
      stmt.execute(<Object?>[id.trim()]);
    } finally {
      stmt.dispose();
    }
  }

  // --------------------------------------------------------------------------
  // 7. BAYİ SÖZLEŞMELERİ (dealer_contracts)
  // --------------------------------------------------------------------------

  List<DealerContractRecord> getDealerContracts({String? accountId}) {
    final cleanAccId = accountId?.trim() ?? '';
    final ResultSet rows = cleanAccId.isNotEmpty
        ? rawDb.select(
            'SELECT * FROM dealer_contracts WHERE account_id = ? ORDER BY date_key DESC, id DESC',
            <Object?>[cleanAccId],
          )
        : rawDb.select(
            'SELECT * FROM dealer_contracts ORDER BY date_key DESC, id DESC',
          );
    return rows
        .map(
          (Row r) => DealerContractRecord(
            id: r['id'] as String,
            contractNo: r['contract_no'] as String? ?? '',
            dateKey: r['date_key'] as String? ?? '',
            durationMonths: r['duration_months'] as int? ?? 12,
            collateralAmountTl:
                (r['collateral_amount_tl'] as num? ?? 0).toDouble(),
            collateralType:
                r['collateral_type'] as String? ?? 'Teminat Mektubu',
            accountId: r['account_id'] as String? ?? '',
            accountName: r['account_name'] as String? ?? '',
            regionName: r['region_name'] as String? ?? '',
            priceTier: r['price_tier'] as int? ?? 1,
            dealerMarginPercent:
                (r['dealer_margin_percent'] as num? ?? 0).toDouble(),
            isTerminated: (r['is_terminated'] as int? ?? 0) == 1,
            terminationNote: r['termination_note'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  void upsertDealerContract(DealerContractRecord contract) {
    final PreparedStatement stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO dealer_contracts (
        id, contract_no, date_key, duration_months, collateral_amount_tl,
        collateral_type, account_id, account_name, region_name,
        price_tier, dealer_margin_percent, is_terminated, termination_note
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute(<Object?>[
        contract.id.trim(),
        contract.contractNo.trim().toUpperCase(),
        contract.dateKey.trim(),
        contract.durationMonths,
        contract.collateralAmountTl,
        contract.collateralType.trim(),
        contract.accountId.trim(),
        contract.accountName.trim().toUpperCase(),
        contract.regionName.trim(),
        contract.priceTier,
        contract.dealerMarginPercent,
        contract.isTerminated ? 1 : 0,
        contract.terminationNote.trim(),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deleteDealerContract(String id) {
    final PreparedStatement stmt = rawDb.prepare(
      'DELETE FROM dealer_contracts WHERE id = ?',
    );
    try {
      stmt.execute(<Object?>[id.trim()]);
    } finally {
      stmt.dispose();
    }
  }

  // --------------------------------------------------------------------------
  // 8. DÖNEM DEVİR MOTORU (previewPeriodRollover & executePeriodRollover)
  // --------------------------------------------------------------------------

  /// Dönem devri öncesi cari bakiye, açık çek/senet ve stok envanter özetini hesaplar.
  PeriodRolloverPreview previewPeriodRollover({
    String? fromPeriodKey,
    required String nextPeriodKey,
    required String rolloverDateKey,
  }) {
    final cleanNext = nextPeriodKey.trim();
    final cleanDate = rolloverDateKey.trim();
    final cleanFrom =
        _resolveFromPeriodKey(fromPeriodKey, cleanNext, cleanDate);

    final ResultSet lockRows = rawDb.select(
      'SELECT * FROM period_rollover_locks WHERE from_period_key = ?',
      <Object?>[cleanFrom],
    );
    if (lockRows.isNotEmpty) {
      return _previewFromLockRow(
        lockRows.first,
        fallbackFrom: cleanFrom,
        fallbackNext: cleanNext,
        fallbackDate: cleanDate,
      );
    }

    final snapshot = _computeRolloverSnapshot(
      fromPeriodKey: cleanFrom,
      nextPeriodKey: cleanNext,
      rolloverDateKey: cleanDate,
    );
    return snapshot.toPreview(alreadyExecuted: false);
  }

  /// Atomik ve idempotent dönem devrini uygular:
  /// 1) `period_rollover_locks` ile çift devri engeller,
  /// 2) Sıfır olmayan cari bakiyeler için kapanış + yeni dönem açılış `AccountingTransaction` oluşturur,
  /// 3) Stok miktar/maliyet değerlerini dönem devir geçmişine işler,
  /// 4) Açık portföy çek/senet taşıma özetini kalıcılaştırır.
  PeriodRolloverPreview executePeriodRollover({
    String? fromPeriodKey,
    required String nextPeriodKey,
    required String rolloverDateKey,
  }) {
    final cleanNext = nextPeriodKey.trim();
    final cleanDate = rolloverDateKey.trim();
    final cleanFrom =
        _resolveFromPeriodKey(fromPeriodKey, cleanNext, cleanDate);

    rawDb.execute('BEGIN IMMEDIATE;');
    try {
      final ResultSet lockRows = rawDb.select(
        'SELECT * FROM period_rollover_locks WHERE from_period_key = ?',
        <Object?>[cleanFrom],
      );
      if (lockRows.isNotEmpty) {
        final existingPreview = _previewFromLockRow(
          lockRows.first,
          fallbackFrom: cleanFrom,
          fallbackNext: cleanNext,
          fallbackDate: cleanDate,
        );
        rawDb.execute('COMMIT;');
        return existingPreview;
      }

      final snapshot = _computeRolloverSnapshot(
        fromPeriodKey: cleanFrom,
        nextPeriodKey: cleanNext,
        rolloverDateKey: cleanDate,
      );

      final closeDateKey = PreAccountingMathEngine.formatDateKey(
        PreAccountingMathEngine.parseDateKey(cleanDate)
            .subtract(const Duration(days: 1)),
      );

      if (snapshot.nonZeroAccounts.isNotEmpty) {
        final PreparedStatement insertTxStmt = rawDb.prepare('''
          INSERT OR REPLACE INTO accounting_transactions (
            id, doc_no, date_key, account_id, account_name,
            entry_type, direction, amount, cash_or_bank_name,
            expense_category, description, puantaj_period_key,
            currency_code, fx_rate, fx_amount, discount_percent,
            sales_rep_name, settled_amount_tl, linked_order_doc_id
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''');
        try {
          for (final acc in snapshot.nonZeroAccounts) {
            final absAmount =
                double.parse(acc.netBalance.abs().toStringAsFixed(2));
            final isCreditCarry = acc.netBalance > 0;
            final closeDirection = isCreditCarry ? 'B' : 'A';
            final openDirection = isCreditCarry ? 'A' : 'B';
            final closeEntryType = isCreditCarry
                ? LedgerEntryType.debitMemo.name
                : LedgerEntryType.creditMemo.name;
            final openEntryType = isCreditCarry
                ? LedgerEntryType.creditMemo.name
                : LedgerEntryType.debitMemo.name;
            final rolloverTag = 'ROLLOVER:$cleanFrom->$cleanNext';

            insertTxStmt.execute(<Object?>[
              'tx_rollover_close_${cleanFrom}_${cleanNext}_${acc.accountId}',
              'KPN-$cleanFrom-${acc.accountCode}'.toUpperCase(),
              closeDateKey,
              acc.accountId,
              acc.accountName.toUpperCase(),
              closeEntryType,
              closeDirection,
              absAmount,
              'Dönem Kapanış Mahsubu',
              'DÖNEM DEVİR',
              '$cleanFrom -> $cleanNext Dönem Kapanış Denkleştirme Fişi',
              cleanFrom,
              'TRY',
              1.0,
              0.0,
              0.0,
              '',
              0.0,
              rolloverTag,
            ]);

            insertTxStmt.execute(<Object?>[
              'tx_rollover_open_${cleanFrom}_${cleanNext}_${acc.accountId}',
              'DVR-$cleanNext-${acc.accountCode}'.toUpperCase(),
              cleanDate,
              acc.accountId,
              acc.accountName.toUpperCase(),
              openEntryType,
              openDirection,
              absAmount,
              'Dönem Açılış Devri',
              'DÖNEM DEVİR',
              '$cleanFrom -> $cleanNext Dönem Açılış Devir Fişi',
              cleanNext,
              'TRY',
              1.0,
              0.0,
              0.0,
              '',
              0.0,
              rolloverTag,
            ]);
          }
        } finally {
          insertTxStmt.dispose();
        }
      }

      if (snapshot.stocks.isNotEmpty) {
        final PreparedStatement updateStockStmt = rawDb.prepare(
          'UPDATE stock_burn_items SET price_history_json = ? WHERE id = ?',
        );
        try {
          for (final stock in snapshot.stocks) {
            final history = _decodePriceHistoryList(stock.priceHistoryJson);
            history.add(<String, dynamic>{
              'type': 'PERIOD_ROLLOVER',
              'fromPeriodKey': cleanFrom,
              'nextPeriodKey': cleanNext,
              'dateKey': cleanDate,
              'qty': double.parse(stock.currentQty.toStringAsFixed(4)),
              'unitCostTl': double.parse(stock.unitCost.toStringAsFixed(4)),
              'valuationTl': double.parse(stock.valuationTl.toStringAsFixed(2)),
            });
            const int maxHistoryEntries = 24;
            final boundedHistory = history.length > maxHistoryEntries
                ? history.sublist(history.length - maxHistoryEntries)
                : history;
            updateStockStmt.execute(<Object?>[
              jsonEncode(boundedHistory),
              stock.id,
            ]);
          }
        } finally {
          updateStockStmt.dispose();
        }
      }

      final preview = snapshot.toPreview(alreadyExecuted: true);
      final summaryPayload = <String, dynamic>{
        ...preview.toJson(),
        'carriedAccounts': snapshot.nonZeroAccounts
            .map(
              (_AccountCarryBalance a) => <String, dynamic>{
                'accountId': a.accountId,
                'code': a.accountCode,
                'name': a.accountName,
                'netBalanceTl': double.parse(a.netBalance.toStringAsFixed(2)),
              },
            )
            .toList(growable: false),
        'carriedStocks': snapshot.stocks
            .map(
              (_StockCarryEntry s) => <String, dynamic>{
                'stockId': s.id,
                'code': s.code,
                'qty': double.parse(s.currentQty.toStringAsFixed(4)),
                'unitCostTl': double.parse(s.unitCost.toStringAsFixed(4)),
                'valuationTl': double.parse(s.valuationTl.toStringAsFixed(2)),
              },
            )
            .toList(growable: false),
        'carriedOpenChecks': snapshot.openChecks
            .map(
              (_OpenCheckCarryEntry c) => <String, dynamic>{
                'checkId': c.id,
                'bordroNo': c.bordroNo,
                'serialNo': c.serialNo,
                'dueDateKey': c.dueDateKey,
                'isIncoming': c.isIncoming,
                'amountTl': double.parse(c.amountTl.toStringAsFixed(2)),
              },
            )
            .toList(growable: false),
      };

      final PreparedStatement lockStmt = rawDb.prepare('''
        INSERT INTO period_rollover_locks (
          from_period_key, next_period_key, rollover_date_key,
          summary_json, executed_at_iso
        ) VALUES (?, ?, ?, ?, ?)
      ''');
      try {
        lockStmt.execute(<Object?>[
          cleanFrom,
          cleanNext,
          cleanDate,
          jsonEncode(summaryPayload),
          DateTime.now().toIso8601String(),
        ]);
      } finally {
        lockStmt.dispose();
      }

      rawDb.execute('COMMIT;');
      return preview;
    } catch (_) {
      rawDb.execute('ROLLBACK;');
      rethrow;
    }
  }

  int _tableRowCount(String countSql) {
    final ResultSet rows = rawDb.select(countSql);
    if (rows.isEmpty) return 0;
    return rows.first['cnt'] as int? ?? 0;
  }

  String _resolveFromPeriodKey(
    String? explicitFromPeriodKey,
    String nextPeriodKey,
    String rolloverDateKey,
  ) {
    final explicit = explicitFromPeriodKey?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;

    final ymMatch = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(nextPeriodKey);
    if (ymMatch != null) {
      final year = int.parse(ymMatch.group(1)!);
      final month = int.parse(ymMatch.group(2)!);
      if (month > 1) {
        return '$year-${(month - 1).toString().padLeft(2, '0')}';
      }
      return '${year - 1}-12';
    }

    final yearMatch = RegExp(r'^(\d{4})$').firstMatch(nextPeriodKey);
    if (yearMatch != null) {
      return '${int.parse(yearMatch.group(1)!) - 1}';
    }

    final dt = PreAccountingMathEngine.parseDateKey(rolloverDateKey);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  _RolloverComputedSnapshot _computeRolloverSnapshot({
    required String fromPeriodKey,
    required String nextPeriodKey,
    required String rolloverDateKey,
  }) {
    final ResultSet accountRows = rawDb.select('''
      SELECT
        a.id AS id,
        a.code AS code,
        a.name AS name,
        COALESCE(SUM(CASE WHEN t.direction = 'A' THEN t.amount ELSE 0.0 END), 0.0) AS calc_credit,
        COALESCE(SUM(CASE WHEN t.direction = 'B' THEN t.amount ELSE 0.0 END), 0.0) AS calc_debit
      FROM accounting_accounts a
      LEFT JOIN accounting_transactions t ON t.account_id = a.id
      GROUP BY a.id
      ORDER BY a.id ASC
    ''');

    final nonZeroAccounts = <_AccountCarryBalance>[];
    double receivableCarry = 0.0;
    double payableCarry = 0.0;

    for (final Row r in accountRows) {
      final credit = (r['calc_credit'] as num? ?? 0).toDouble();
      final debit = (r['calc_debit'] as num? ?? 0).toDouble();
      final net = credit - debit;
      if (net.abs() <= 0.005) continue;
      if (net < 0) {
        receivableCarry += net.abs();
      } else {
        payableCarry += net;
      }
      nonZeroAccounts.add(
        _AccountCarryBalance(
          accountId: r['id'] as String,
          accountCode: r['code'] as String? ?? '',
          accountName: r['name'] as String? ?? '',
          netBalance: net,
        ),
      );
    }

    final ResultSet checkRows = rawDb.select(
      '''
      SELECT id, bordro_no, serial_no, due_date_key, is_incoming, amount_tl
      FROM accounting_check_portfolio
      WHERE status = ?
      ORDER BY due_date_key ASC, id ASC
      ''',
      <Object?>[CheckPortfolioStatus.inPortfolio.name],
    );

    final openChecks = <_OpenCheckCarryEntry>[];
    double openCheckTotal = 0.0;
    for (final Row r in checkRows) {
      final amt = (r['amount_tl'] as num? ?? 0).toDouble();
      openCheckTotal += amt;
      openChecks.add(
        _OpenCheckCarryEntry(
          id: r['id'] as String,
          bordroNo: r['bordro_no'] as String? ?? '',
          serialNo: r['serial_no'] as String? ?? '',
          dueDateKey: r['due_date_key'] as String? ?? '',
          isIncoming: (r['is_incoming'] as int? ?? 1) == 1,
          amountTl: amt,
        ),
      );
    }

    final ResultSet stockRows = rawDb.select('''
      SELECT id, code, name, unit, current_qty, unit_cost, price_history_json
      FROM stock_burn_items
      ORDER BY id ASC
    ''');

    final stocks = <_StockCarryEntry>[];
    double stockValuation = 0.0;
    for (final Row r in stockRows) {
      final qty = (r['current_qty'] as num? ?? 0).toDouble();
      final cost = (r['unit_cost'] as num? ?? 0).toDouble();
      stockValuation += qty * cost;
      stocks.add(
        _StockCarryEntry(
          id: r['id'] as String,
          code: r['code'] as String? ?? '',
          name: r['name'] as String? ?? '',
          unit: r['unit'] as String? ?? 'KG',
          currentQty: qty,
          unitCost: cost,
          priceHistoryJson: r['price_history_json'] as String? ?? '[]',
        ),
      );
    }

    return _RolloverComputedSnapshot(
      fromPeriodKey: fromPeriodKey,
      nextPeriodKey: nextPeriodKey,
      rolloverDateKey: rolloverDateKey,
      nonZeroAccounts: nonZeroAccounts,
      totalReceivableCarryTl: receivableCarry,
      totalPayableCarryTl: payableCarry,
      openChecks: openChecks,
      openCheckTotalTl: openCheckTotal,
      stocks: stocks,
      stockValuationCarryTl: stockValuation,
    );
  }

  PeriodRolloverPreview _previewFromLockRow(
    Row lockRow, {
    required String fallbackFrom,
    required String fallbackNext,
    required String fallbackDate,
  }) {
    final summaryRaw = (lockRow['summary_json'] as String?) ?? '';
    if (summaryRaw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(summaryRaw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          return PeriodRolloverPreview(
            fromPeriodKey:
                (map['fromPeriodKey'] as String?) ?? fallbackFrom,
            nextPeriodKey: (map['nextPeriodKey'] as String?) ??
                (lockRow['next_period_key'] as String?) ??
                fallbackNext,
            rolloverDateKey: (map['rolloverDateKey'] as String?) ??
                (lockRow['rollover_date_key'] as String?) ??
                fallbackDate,
            accountCount: (map['accountCount'] as num?)?.toInt() ?? 0,
            totalReceivableCarryTl:
                (map['totalReceivableCarryTl'] as num?)?.toDouble() ?? 0.0,
            totalPayableCarryTl:
                (map['totalPayableCarryTl'] as num?)?.toDouble() ?? 0.0,
            openCheckCount: (map['openCheckCount'] as num?)?.toInt() ?? 0,
            openCheckTotalTl:
                (map['openCheckTotalTl'] as num?)?.toDouble() ?? 0.0,
            stockItemCount: (map['stockItemCount'] as num?)?.toInt() ?? 0,
            stockValuationCarryTl:
                (map['stockValuationCarryTl'] as num?)?.toDouble() ?? 0.0,
            alreadyExecuted: true,
          );
        }
      } on FormatException catch (err) {
        return _computeRolloverSnapshot(
          fromPeriodKey: fallbackFrom,
          nextPeriodKey: err.message.isEmpty ? fallbackNext : fallbackNext,
          rolloverDateKey: fallbackDate,
        ).toPreview(alreadyExecuted: true);
      }
    }

    return _computeRolloverSnapshot(
      fromPeriodKey: fallbackFrom,
      nextPeriodKey: (lockRow['next_period_key'] as String?) ?? fallbackNext,
      rolloverDateKey:
          (lockRow['rollover_date_key'] as String?) ?? fallbackDate,
    ).toPreview(alreadyExecuted: true);
  }

  List<Map<String, dynamic>> _decodePriceHistoryList(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('[')) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList();
    } on FormatException catch (err) {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'CORRUPT_HISTORY_BACKUP',
          'error': err.message,
          'raw': trimmed,
        },
      ];
    }
  }
}
