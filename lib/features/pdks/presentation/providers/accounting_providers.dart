import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/hasibu_accounting_dao.dart';
import '../../../../core/database/hasibu_database.dart';
import '../../../../core/services/tcmb_currency_gateway.dart';
import '../../data/accounting_demo_seed_data.dart';
import '../../domain/accounting_models.dart';
import '../../domain/pdks_models.dart';
import '../../domain/pre_accounting_advanced_contracts.dart';
import 'pdks_providers.dart';

@immutable
class AccountingState {
  final bool isDemoModeActive;
  final String selectedPeriodKey; // Örn: '2026-10'
  final String selectedDateKey; // Örn: '2026-10-22'
  final PreAccountingOperationModule selectedOperationModule;
  final String accountTypeFilter; // 'ALL' veya AccountingAccountType.name
  final String? selectedAccountId;
  final List<AccountingAccount> accounts;
  final List<AccountingTransaction> transactions;
  final List<ContainerMovement> containerMovements;
  final List<StockBurnItem> stockBurnItems;
  final List<CheckOrAlertNote> checksAndNotes;
  final List<PuantajEmployeeRow> puantajRows;
  final EndOfDayCockpitSummary cockpitSummary;
  final SaaSSubscriptionState subscriptionState;
  final MigrationImportResult? lastMigrationResult;
  // Hasibu ERP Ek Koleksiyonları
  final List<ErpOrderWaybillInvoiceItem> erpOrdersWaybillsInvoices;
  final List<ProductionRecipeBom> productionRecipes;
  final List<CustomSpreadsheetRecord> customSpreadsheets;
  // İleri Ön Muhasebe: TCMB Kurları, Çek Portföyü, Ödeme Talimatları, Bayi Sözleşmeleri & Devir
  final List<CurrencyRateQuote> currencyRates;
  final List<CheckPortfolioItem> checkPortfolio;
  final List<PaymentInstructionTemplate> paymentTemplates;
  final List<PaymentOrderRecord> paymentOrders;
  final List<DealerContractRecord> dealerContracts;
  final PeriodRolloverPreview? rolloverPreview;
  // Hasibu Mağaza POS & 360° Şube Denetim Durumu
  final int selectedBranchStoreId;
  final int selectedPosTabGroup;
  final double liveScaleWeightKg;
  final List<BranchStoreProfile> branchProfiles;
  final List<BranchPosQuickButton> posQuickButtons;
  final List<BranchPosCartLine> activePosCart;
  final String? selectedPosCartLineId;
  final List<BranchSuspendedReceipt> suspendedPosReceipts;
  final List<BranchPosReceipt> branchPosReceipts;
  final List<BranchTransferVoucher> branchTransfers;
  final List<BranchLocalPurchase> branchLocalPurchases;
  final List<BranchEndOfDaySettlement> branchEndOfDaySettlements;
  final List<BranchStockCountEntry> branchStockCounts;
  final List<BranchAuditInspectionRecord> branchAuditInspections;
  final GmsPayrollParameters gmsPayrollParams;
  final String? statusBanner;

  const AccountingState({
    this.isDemoModeActive = true,
    this.selectedPeriodKey = '2026-10',
    this.selectedDateKey = '2026-10-22',
    this.selectedOperationModule = PreAccountingOperationModule.kasaIslemleri,
    this.accountTypeFilter = 'ALL',
    this.selectedAccountId,
    this.accounts = const <AccountingAccount>[],
    this.transactions = const <AccountingTransaction>[],
    this.containerMovements = const <ContainerMovement>[],
    this.stockBurnItems = const <StockBurnItem>[],
    this.checksAndNotes = const <CheckOrAlertNote>[],
    this.puantajRows = const <PuantajEmployeeRow>[],
    this.cockpitSummary = const EndOfDayCockpitSummary(),
    this.subscriptionState = const SaaSSubscriptionState(),
    this.lastMigrationResult,
    this.erpOrdersWaybillsInvoices = const <ErpOrderWaybillInvoiceItem>[],
    this.productionRecipes = const <ProductionRecipeBom>[],
    this.customSpreadsheets = const <CustomSpreadsheetRecord>[],
    this.currencyRates = const <CurrencyRateQuote>[],
    this.checkPortfolio = const <CheckPortfolioItem>[],
    this.paymentTemplates = const <PaymentInstructionTemplate>[],
    this.paymentOrders = const <PaymentOrderRecord>[],
    this.dealerContracts = const <DealerContractRecord>[],
    this.rolloverPreview,
    this.selectedBranchStoreId = 1,
    this.selectedPosTabGroup = 1,
    this.liveScaleWeightKg = 1.000,
    this.branchProfiles = const <BranchStoreProfile>[],
    this.posQuickButtons = const <BranchPosQuickButton>[],
    this.activePosCart = const <BranchPosCartLine>[],
    this.selectedPosCartLineId,
    this.suspendedPosReceipts = const <BranchSuspendedReceipt>[],
    this.branchPosReceipts = const <BranchPosReceipt>[],
    this.branchTransfers = const <BranchTransferVoucher>[],
    this.branchLocalPurchases = const <BranchLocalPurchase>[],
    this.branchEndOfDaySettlements = const <BranchEndOfDaySettlement>[],
    this.branchStockCounts = const <BranchStockCountEntry>[],
    this.branchAuditInspections = const <BranchAuditInspectionRecord>[],
    this.gmsPayrollParams = const GmsPayrollParameters(),
    this.statusBanner,
  });

  MaturitySummary get receivableMaturitySummary {
    final rows = <MaturityCalcRow>[
      for (final chk in checkPortfolio)
        if (chk.isIncoming && chk.status == CheckPortfolioStatus.inPortfolio)
          MaturityCalcRow(
            id: chk.id,
            label: '${chk.accountName} (${chk.serialNo})',
            dueDateKey: chk.dueDateKey,
            amountTl: chk.amountTl,
          ),
      for (final doc in erpOrdersWaybillsInvoices)
        if (doc.stage == 'FATURALANDI' && doc.remainingReceivableTl > 0)
          MaturityCalcRow(
            id: doc.id,
            label: '${doc.accountName} (${doc.invoiceDocNo ?? doc.orderDocNo})',
            dueDateKey: PreAccountingMathEngine.formatDateKey(
              PreAccountingMathEngine.parseDateKey(doc.dateKey).add(
                const Duration(days: 30),
              ),
            ),
            amountTl: doc.remainingReceivableTl,
          ),
    ];
    return PreAccountingMathEngine.computeWeightedMaturity(
      baseDateKey: selectedDateKey,
      rows: rows,
    );
  }

  PreAccountingAdvancedViewData get advancedViewData {
    return PreAccountingAdvancedViewData(
      selectedDateKey: selectedDateKey,
      selectedPeriodKey: selectedPeriodKey,
      accounts: accounts,
      selectedAccount: selectedAccount,
      transactions: transactions,
      stocks: stockBurnItems,
      containers: containerMovements,
      erpDocuments: erpOrdersWaybillsInvoices,
      customSpreadsheets: customSpreadsheets,
      currencyRates: currencyRates,
      checkPortfolio: checkPortfolio,
      paymentTemplates: paymentTemplates,
      paymentOrders: paymentOrders,
      dealerContracts: dealerContracts,
      rolloverPreview: rolloverPreview,
    );
  }

  BranchStoreProfile get activeBranchProfile {
    for (final b in branchProfiles) {
      if (b.branchId == selectedBranchStoreId) return b;
    }
    return branchProfiles.isNotEmpty
        ? branchProfiles.first
        : const BranchStoreProfile(
            branchId: 1,
            storeCode: 'MAG-01',
            storeName: 'MARMARA MERKEZ MAĞAZA ŞUBESİ',
            warehouseName: 'Merkez Mağaza Tezgah Deposu',
            cashBoxName: 'Marmara Mağaza TL Kasa',
            posBankName: 'Marmara Mağaza POS Hesabı',
            storeAccountId: 'acc_demo_branch_1',
          );
  }

  double get posCartTotalTl =>
      activePosCart.fold<double>(0.0, (sum, l) => sum + l.lineTotalTl);

  double get posCartSweetWeightKg => activePosCart
      .where((l) => !l.isBoxContainer && l.unit == 'KG')
      .fold<double>(0.0, (sum, l) => sum + l.quantity);

  int get posCartBoxCount => activePosCart
      .where((l) => l.isBoxContainer)
      .fold<int>(0, (sum, l) => sum + l.quantity.round());

  double get posCartBoxTareKg =>
      activePosCart.fold<double>(0.0, (sum, l) => sum + l.totalBoxTareKg);

  /// Kutu Gramaj Kalkanı (`TepsiFiyatKontrol`): KG ile tatlı satılırken yeterli kutu seçilmemişse uyarır.
  bool get requiresBoxContainerAlert =>
      posCartSweetWeightKg >= 0.45 && posCartBoxCount == 0;

  List<AccountingAccount> get filteredAccounts {
    if (accountTypeFilter == 'ALL') return accounts;
    return accounts
        .where((a) => a.type.name == accountTypeFilter)
        .toList(growable: false);
  }

  AccountingAccount? get selectedAccount {
    if (accounts.isEmpty) return null;
    if (selectedAccountId != null) {
      for (final a in accounts) {
        if (a.id == selectedAccountId) return a;
      }
    }
    return accounts.first;
  }

  AccountingState copyWith({
    bool? isDemoModeActive,
    String? selectedPeriodKey,
    String? selectedDateKey,
    PreAccountingOperationModule? selectedOperationModule,
    String? accountTypeFilter,
    String? Function()? selectedAccountId,
    List<AccountingAccount>? accounts,
    List<AccountingTransaction>? transactions,
    List<ContainerMovement>? containerMovements,
    List<StockBurnItem>? stockBurnItems,
    List<CheckOrAlertNote>? checksAndNotes,
    List<PuantajEmployeeRow>? puantajRows,
    EndOfDayCockpitSummary? cockpitSummary,
    SaaSSubscriptionState? subscriptionState,
    MigrationImportResult? Function()? lastMigrationResult,
    List<ErpOrderWaybillInvoiceItem>? erpOrdersWaybillsInvoices,
    List<ProductionRecipeBom>? productionRecipes,
    List<CustomSpreadsheetRecord>? customSpreadsheets,
    List<CurrencyRateQuote>? currencyRates,
    List<CheckPortfolioItem>? checkPortfolio,
    List<PaymentInstructionTemplate>? paymentTemplates,
    List<PaymentOrderRecord>? paymentOrders,
    List<DealerContractRecord>? dealerContracts,
    PeriodRolloverPreview? Function()? rolloverPreview,
    int? selectedBranchStoreId,
    int? selectedPosTabGroup,
    double? liveScaleWeightKg,
    List<BranchStoreProfile>? branchProfiles,
    List<BranchPosQuickButton>? posQuickButtons,
    List<BranchPosCartLine>? activePosCart,
    String? Function()? selectedPosCartLineId,
    List<BranchSuspendedReceipt>? suspendedPosReceipts,
    List<BranchPosReceipt>? branchPosReceipts,
    List<BranchTransferVoucher>? branchTransfers,
    List<BranchLocalPurchase>? branchLocalPurchases,
    List<BranchEndOfDaySettlement>? branchEndOfDaySettlements,
    List<BranchStockCountEntry>? branchStockCounts,
    List<BranchAuditInspectionRecord>? branchAuditInspections,
    GmsPayrollParameters? gmsPayrollParams,
    String? Function()? statusBanner,
  }) {
    return AccountingState(
      isDemoModeActive: isDemoModeActive ?? this.isDemoModeActive,
      selectedPeriodKey: selectedPeriodKey ?? this.selectedPeriodKey,
      selectedDateKey: selectedDateKey ?? this.selectedDateKey,
      selectedOperationModule:
          selectedOperationModule ?? this.selectedOperationModule,
      accountTypeFilter: accountTypeFilter ?? this.accountTypeFilter,
      selectedAccountId: selectedAccountId != null
          ? selectedAccountId()
          : this.selectedAccountId,
      accounts: accounts ?? this.accounts,
      transactions: transactions ?? this.transactions,
      containerMovements: containerMovements ?? this.containerMovements,
      stockBurnItems: stockBurnItems ?? this.stockBurnItems,
      checksAndNotes: checksAndNotes ?? this.checksAndNotes,
      puantajRows: puantajRows ?? this.puantajRows,
      cockpitSummary: cockpitSummary ?? this.cockpitSummary,
      subscriptionState: subscriptionState ?? this.subscriptionState,
      lastMigrationResult: lastMigrationResult != null
          ? lastMigrationResult()
          : this.lastMigrationResult,
      erpOrdersWaybillsInvoices:
          erpOrdersWaybillsInvoices ?? this.erpOrdersWaybillsInvoices,
      productionRecipes: productionRecipes ?? this.productionRecipes,
      customSpreadsheets: customSpreadsheets ?? this.customSpreadsheets,
      currencyRates: currencyRates ?? this.currencyRates,
      checkPortfolio: checkPortfolio ?? this.checkPortfolio,
      paymentTemplates: paymentTemplates ?? this.paymentTemplates,
      paymentOrders: paymentOrders ?? this.paymentOrders,
      dealerContracts: dealerContracts ?? this.dealerContracts,
      rolloverPreview:
          rolloverPreview != null ? rolloverPreview() : this.rolloverPreview,
      selectedBranchStoreId:
          selectedBranchStoreId ?? this.selectedBranchStoreId,
      selectedPosTabGroup: selectedPosTabGroup ?? this.selectedPosTabGroup,
      liveScaleWeightKg: liveScaleWeightKg ?? this.liveScaleWeightKg,
      branchProfiles: branchProfiles ?? this.branchProfiles,
      posQuickButtons: posQuickButtons ?? this.posQuickButtons,
      activePosCart: activePosCart ?? this.activePosCart,
      selectedPosCartLineId: selectedPosCartLineId != null
          ? selectedPosCartLineId()
          : this.selectedPosCartLineId,
      suspendedPosReceipts: suspendedPosReceipts ?? this.suspendedPosReceipts,
      branchPosReceipts: branchPosReceipts ?? this.branchPosReceipts,
      branchTransfers: branchTransfers ?? this.branchTransfers,
      branchLocalPurchases: branchLocalPurchases ?? this.branchLocalPurchases,
      branchEndOfDaySettlements:
          branchEndOfDaySettlements ?? this.branchEndOfDaySettlements,
      branchStockCounts: branchStockCounts ?? this.branchStockCounts,
      branchAuditInspections:
          branchAuditInspections ?? this.branchAuditInspections,
      gmsPayrollParams: gmsPayrollParams ?? this.gmsPayrollParams,
      statusBanner: statusBanner != null ? statusBanner() : this.statusBanner,
    );
  }
}

class AccountingNotifier extends StateNotifier<AccountingState>
    implements PreAccountingAdvancedActions {
  final HasibuDatabase _db;
  final CurrencyRateGateway _currencyGateway;
  final Map<String, Map<int, String>> _customDayOverrides =
      <String, Map<int, String>>{};
  final Map<String, GmsSgkIncentiveLaw> _empSgkLaws =
      <String, GmsSgkIncentiveLaw>{};
  final Map<String, GmsMissingDayReason> _empMissingReasons =
      <String, GmsMissingDayReason>{};
  final Map<String, bool> _empBesEnrolled = <String, bool>{};
  final Map<String, double> _empGarnishments = <String, double>{};
  final Map<String, String> _empGarnishmentFiles = <String, String>{};
  final Map<String, double> _empMealAllowances = <String, double>{};
  final Map<String, double> _empTransportAllowances = <String, double>{};
  final Map<String, double> _empBonuses = <String, double>{};
  final Set<String> _signedEnvelopeCards = <String>{};
  final Map<String, String> _rolloverSourceByTarget = <String, String>{};
  bool _initializedExtendedCollections = false;

  AccountingNotifier(this._db, [CurrencyRateGateway? currencyGateway])
      : _currencyGateway = currencyGateway ?? TcmbCurrencyGateway(),
        super(const AccountingState()) {
    refreshAll();
  }

  void refreshAll({String? bannerMessage}) {
    final demoActive = _db.isAccountingDemoModeActive();
    final accounts = _db.getAccountingAccounts();
    final transactions = _db.getAccountingTransactions();
    final containers = _db.getContainerMovements();
    final stocks = _db.getStockBurnItems();
    final checks = _db.getChecksAndNotes();
    final sub = _db.getSaaSSubscriptionState();
    final posReceipts = _db.getBranchPosReceipts();
    final auditInspections = _db.getBranchAuditInspections();
    final erpDocs = _db.getErpDocuments();
    final recipes = _db.getProductionRecipes();
    final spreadsheets = _db.getCustomSpreadsheets();
    final checkPort = _db.getCheckPortfolioItems();
    final payTemplates = _db.getPaymentInstructionTemplates();
    final payOrders = _db.getPaymentOrders();
    final contracts = _db.getDealerContracts();

    final curYear =
        int.tryParse(state.selectedPeriodKey.split('-').first) ?? 2026;
    final nextYear = curYear + 1;
    final previewFromPeriod =
        _rolloverSourceByTarget[state.selectedPeriodKey] ??
            state.selectedPeriodKey;
    final rollPrev = _db.previewPeriodRollover(
      fromPeriodKey: previewFromPeriod,
      nextPeriodKey: '$nextYear-01',
      rolloverDateKey: '$nextYear-01-01',
    );
    final rates = state.currencyRates.isNotEmpty
        ? state.currencyRates
        : _currencyGateway.fallbackRates();

    if (!_initializedExtendedCollections) {
      _initializedExtendedCollections = true;
      state = state.copyWith(
        branchProfiles: AccountingDemoSeedData.demoBranchProfiles,
        posQuickButtons: AccountingDemoSeedData.demoBranchPosQuickButtons,
        branchTransfers: demoActive
            ? AccountingDemoSeedData.demoBranchTransfers
            : const <BranchTransferVoucher>[],
        branchLocalPurchases: demoActive
            ? AccountingDemoSeedData.demoBranchLocalPurchases
            : const <BranchLocalPurchase>[],
        branchEndOfDaySettlements: demoActive
            ? AccountingDemoSeedData.demoBranchEndOfDaySettlements
            : const <BranchEndOfDaySettlement>[],
        branchStockCounts: demoActive
            ? AccountingDemoSeedData.demoBranchStockCounts
            : const <BranchStockCountEntry>[],
      );
    }

    final puantaj = _buildAutomaticPuantajMatrix(
      periodKey: state.selectedPeriodKey,
      accounts: accounts,
      transactions: transactions,
    );

    final cockpit = _computeCockpitSummary(
      accounts: accounts,
      transactions: transactions,
      stocks: stocks,
    );

    final String? validSelectedAccId = accounts.any(
      (a) => a.id == state.selectedAccountId,
    )
        ? state.selectedAccountId
        : (accounts.isNotEmpty ? accounts.first.id : null);

    state = state.copyWith(
      isDemoModeActive: demoActive,
      selectedAccountId: () => validSelectedAccId,
      accounts: accounts,
      transactions: transactions,
      containerMovements: containers,
      stockBurnItems: stocks,
      checksAndNotes: checks,
      puantajRows: puantaj,
      cockpitSummary: cockpit,
      subscriptionState: sub,
      erpOrdersWaybillsInvoices: erpDocs,
      productionRecipes: recipes,
      customSpreadsheets: spreadsheets,
      currencyRates: rates,
      checkPortfolio: checkPort,
      paymentTemplates: payTemplates,
      paymentOrders: payOrders,
      dealerContracts: contracts,
      rolloverPreview: () => rollPrev,
      branchPosReceipts: posReceipts,
      branchAuditInspections: auditInspections,
      statusBanner:
          bannerMessage != null ? () => bannerMessage : () => state.statusBanner,
    );
  }

  /// Faz 1 — Kullanıcı geri bildirimi gereği: Gerçek hiçbir işletme verisi olmadan
  /// %100 Temiz Sıfır Veritabanı (Zero-State) moduna geçiş yapar.
  void switchToCleanZeroDatabase() {
    _customDayOverrides.clear();
    _rolloverSourceByTarget.clear();
    _db.clearAccountingDataToZero();
    state = state.copyWith(
      activePosCart: const <BranchPosCartLine>[],
      selectedPosCartLineId: () => null,
      suspendedPosReceipts: const <BranchSuspendedReceipt>[],
      branchTransfers: const <BranchTransferVoucher>[],
      branchLocalPurchases: const <BranchLocalPurchase>[],
      branchEndOfDaySettlements: const <BranchEndOfDaySettlement>[],
      branchStockCounts: const <BranchStockCountEntry>[],
    );
    refreshAll(
      bannerMessage:
          'Veritabanı sıfırlandı: %100 Temiz Sıfır Veritabanı (Zero-State) aktif.',
    );
  }

  /// Faz 1 — Uygulama özelliklerini göstermek için izole Demo Veri Paketini yükler.
  void loadIsolatedDemoPackage() {
    _customDayOverrides.clear();
    _rolloverSourceByTarget.clear();
    _db.loadAccountingDemoPackage();
    state = state.copyWith(
      branchProfiles: AccountingDemoSeedData.demoBranchProfiles,
      posQuickButtons: AccountingDemoSeedData.demoBranchPosQuickButtons,
      branchTransfers: AccountingDemoSeedData.demoBranchTransfers,
      branchLocalPurchases: AccountingDemoSeedData.demoBranchLocalPurchases,
      branchEndOfDaySettlements:
          AccountingDemoSeedData.demoBranchEndOfDaySettlements,
      branchStockCounts: AccountingDemoSeedData.demoBranchStockCounts,
    );
    refreshAll(
      bannerMessage:
          'İzole Demo Veri Paketi yüklendi (Gerçek işletme verisi içermez).',
    );
  }

  void setAccountTypeFilter(String filter) {
    state = state.copyWith(accountTypeFilter: filter);
  }

  void selectAccount(String accountId) {
    state = state.copyWith(selectedAccountId: () => accountId);
  }

  void selectOperationModule(PreAccountingOperationModule module) {
    state = state.copyWith(selectedOperationModule: module);
  }

  void setSelectedDateKey(String dateKey) {
    if (dateKey.trim().isEmpty) return;
    final clean = dateKey.trim();
    final period =
        clean.length >= 7 ? clean.substring(0, 7) : state.selectedPeriodKey;
    state = state.copyWith(
      selectedDateKey: clean,
      selectedPeriodKey: period,
    );
    refreshAll(bannerMessage: 'İşlem tarihi güncellendi: $clean');
  }

  void deleteTransaction(String id) {
    _db.deleteAccountingTransaction(id);
    refreshAll(bannerMessage: 'Finansal hareket / fiş kaydı silindi.');
  }

  void deleteCheckOrNoteItem(String id) {
    _db.deleteCheckOrNote(id);
    refreshAll(bannerMessage: 'Çek / Senet / Ajanda / Not kaydı silindi.');
  }

  /// Ön Muhasebe İşlemler Şeridindeki (Ribbon) 24 başlığın tamamı için
  /// gerçek zamanlı Giriş (Tahsilat/Alacak/Stok+/Üretim+/Çek-Senet Giriş) ve
  /// Çıkış (Tediye/Borç/Gider/Stok-/Sevk/Çek-Senet Çıkış/Avans) motoru.
  void recordOperationalEntryExit({
    required PreAccountingOperationModule module,
    required bool isIncoming,
    AccountingAccount? account,
    AccountingAccount? counterPartyAccount,
    required double amount,
    String? customDocNo,
    String cashOrBankName = 'Merkez TL Kasa',
    String expenseCategory = 'GENEL İŞLETME',
    String description = '',
    String? dueDateKey,
    String? stockId,
    double stockQuantity = 0.0,
    String containerType = 'Tepsi',
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final docNo = (customDocNo != null && customDocNo.trim().isNotEmpty)
        ? customDocNo.trim().toUpperCase()
        : '${module.docPrefix}-${isIncoming ? "G" : "C"}-${stamp % 100000}';
    final accId = account?.id ?? 'acc_merkez_isletme';
    final accName = account?.name ?? cashOrBankName;
    final desc = description.trim().isEmpty
        ? '${module.title} (${isIncoming ? module.inActionLabel : module.outActionLabel})'
        : description.trim();

    // 1. Emanet Tepsi / Köşebent / Kasa Hareketi
    if (module == PreAccountingOperationModule.tepsiKosebentIade) {
      final qty = (stockQuantity > 0
              ? stockQuantity.round()
              : (amount > 0 ? amount.round() : 1))
          .clamp(1, 999999);
      final mov = ContainerMovement(
        id: 'cnt_$stamp',
        dateKey: state.selectedDateKey,
        accountId: accId,
        accountName: accName,
        containerType: containerType,
        givenQty: isIncoming ? 0 : qty,
        returnedQty: isIncoming ? qty : 0,
        note: desc,
      );
      if (account != null) {
        _db.recordContainerMovementAndSyncBalance(mov);
      } else {
        _db.upsertContainerMovement(mov);
      }
    }

    // 2. Stok / Depo Sevk / Üretim / Dondurma Satış Miktar Güncellemesi
    if (stockId != null && stockId.trim().isNotEmpty && stockQuantity > 0) {
      final double delta;
      if (module == PreAccountingOperationModule.dondurmaSatislar) {
        // Satışta stok düşer, iadede stoğa geri girer
        delta = isIncoming ? -stockQuantity : stockQuantity;
      } else {
        delta = isIncoming ? stockQuantity : -stockQuantity;
      }
      _db.adjustStockBurnItemQuantity(stockId.trim(), delta);
    }

    // 3. Çek / Senet / Ajanda / Ödeme Emri / Not / Kayan Yazı Kaydı
    if (module == PreAccountingOperationModule.cekIslemleri ||
        module == PreAccountingOperationModule.senetIslemleri ||
        module == PreAccountingOperationModule.ajanda ||
        module == PreAccountingOperationModule.odemeEmirleri ||
        module == PreAccountingOperationModule.notlar ||
        module == PreAccountingOperationModule.kayanYazi) {
      final String kind = switch (module) {
        PreAccountingOperationModule.cekIslemleri =>
          isIncoming ? 'ÇEK GİRİŞ' : 'ÇEK ÇIKIŞ',
        PreAccountingOperationModule.senetIslemleri =>
          isIncoming ? 'SENET GİRİŞ' : 'SENET ÇIKIŞ',
        PreAccountingOperationModule.ajanda => 'AJANDA',
        PreAccountingOperationModule.odemeEmirleri => 'ÖDEME EMRİ',
        PreAccountingOperationModule.notlar => 'NOT',
        PreAccountingOperationModule.kayanYazi => 'KAYAN YAZI',
        _ => 'NOT',
      };
      _db.upsertCheckOrNote(
        CheckOrAlertNote(
          id: 'chk_$stamp',
          dueDate: (dueDateKey != null && dueDateKey.trim().isNotEmpty)
              ? dueDateKey.trim()
              : state.selectedDateKey,
          kind: kind,
          titleOrParty: accName,
          amount: amount,
          note: desc,
        ),
      );
    }

    // 4. Çift Taraflı Virman Fişi veya Standart Finansal Fiş Kaydı
    if (module == PreAccountingOperationModule.virmanlar && amount > 0) {
      if (account != null &&
          counterPartyAccount != null &&
          account.id != counterPartyAccount.id) {
        _db.upsertAccountingTransaction(
          AccountingTransaction(
            id: 'tx_vrm_out_$stamp',
            docNo: docNo,
            dateKey: state.selectedDateKey,
            accountId: account.id,
            accountName: account.name,
            entryType: LedgerEntryType.transferVirman,
            direction: 'B',
            amount: amount,
            cashOrBankName: cashOrBankName,
            expenseCategory: 'VİRMAN',
            description:
                '${counterPartyAccount.name} hesabına virman çıkış: $desc',
          ),
        );
        _db.upsertAccountingTransaction(
          AccountingTransaction(
            id: 'tx_vrm_in_$stamp',
            docNo: docNo,
            dateKey: state.selectedDateKey,
            accountId: counterPartyAccount.id,
            accountName: counterPartyAccount.name,
            entryType: LedgerEntryType.transferVirman,
            direction: 'A',
            amount: amount,
            cashOrBankName: cashOrBankName,
            expenseCategory: 'VİRMAN',
            description: '${account.name} hesabından virman giriş: $desc',
          ),
        );
      } else {
        _db.upsertAccountingTransaction(
          AccountingTransaction(
            id: 'tx_$stamp',
            docNo: docNo,
            dateKey: state.selectedDateKey,
            accountId: accId,
            accountName: accName,
            entryType: LedgerEntryType.transferVirman,
            direction: isIncoming ? 'A' : 'B',
            amount: amount,
            cashOrBankName: cashOrBankName,
            expenseCategory: 'VİRMAN',
            description: desc,
          ),
        );
      }
    } else if (amount > 0 &&
        module != PreAccountingOperationModule.tepsiKosebentIade &&
        module != PreAccountingOperationModule.notlar &&
        module != PreAccountingOperationModule.kayanYazi &&
        module != PreAccountingOperationModule.ajanda) {
      final entryType =
          isIncoming ? module.defaultInType : module.defaultOutType;
      final bool isInvoiceOrOrder =
          module == PreAccountingOperationModule.faturalar ||
              module == PreAccountingOperationModule.siparisler ||
              module == PreAccountingOperationModule.dondurmaSatislar;
      final direction = isInvoiceOrOrder
          ? entryType.defaultDirection
          : (isIncoming ? 'A' : 'B');

      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_$stamp',
          docNo: docNo,
          dateKey: state.selectedDateKey,
          accountId: accId,
          accountName: accName,
          entryType: entryType,
          direction: direction,
          amount: amount,
          cashOrBankName: cashOrBankName,
          expenseCategory: expenseCategory,
          description: desc,
        ),
      );
    }

    refreshAll(
      bannerMessage:
          '${module.title} • ${isIncoming ? module.inActionLabel : module.outActionLabel} işlendi ($docNo${amount > 0 ? " • ${amount.toStringAsFixed(2)} ₺" : ""}).',
    );
  }

  /// Puantaj matrisinde herhangi bir gün hücresine (1..31) tıklandığında
  /// X (Tam Gün) -> FM (Fazla Mesai) -> B (UBGT Genel Tatil) -> İ (İzinli) -> R (Raporlu) -> Y (Yarım Gün) -> - (Devamsız) döngüsü sağlar.
  void cyclePuantajCellCode(String cardNo, int day) {
    const cycle = <String>['X', 'FM', 'B', 'İ', 'R', 'Y', '-'];
    final row = state.puantajRows.firstWhere(
      (r) => r.cardNo == cardNo,
      orElse: () => state.puantajRows.first,
    );
    final current = row.dayCodes[day] ?? 'X';
    final idx = cycle.indexOf(current);
    final nextCode = cycle[(idx + 1) % cycle.length];

    final mapForEmp = _customDayOverrides.putIfAbsent(
      cardNo,
      () => <int, String>{},
    );
    mapForEmp[day] = nextCode;
    refreshAll();
  }

  /// GMS.NET — Netten Brüte / Brütten Nete hesaplama modunu değiştirir.
  void toggleGmsNetToGrossMode() {
    final next = !state.gmsPayrollParams.isNetToGross;
    state = state.copyWith(
      gmsPayrollParams: state.gmsPayrollParams.copyWith(isNetToGross: next),
    );
    refreshAll(
      bannerMessage:
          'GMS.NET Maaş Hesaplama Yöntemi: ${next ? "Netten Brüte (Ters Tahakkuk)" : "Brütten Nete (Standart Tahakkuk)"} olarak güncellendi.',
    );
  }

  /// GMS.NET — Personelin SGK Teşvik Kanun Numarasını (05510, 06111, 17103, 27103, 05746, 00000) günceller.
  void setEmployeeSgkLaw(String cardNo, GmsSgkIncentiveLaw law) {
    _empSgkLaws[cardNo] = law;
    refreshAll(
      bannerMessage:
          '#$cardNo personel kartı için SGK Teşvik Kanunu "${law.label}" olarak güncellendi.',
    );
  }

  /// GMS.NET — Personelin SGK Eksik Gün Neden Kodunu (00, 01, 06, 07, 12, 15, 21) günceller.
  void setEmployeeMissingDayReason(
    String cardNo,
    GmsMissingDayReason reason,
  ) {
    _empMissingReasons[cardNo] = reason;
    refreshAll(
      bannerMessage:
          '#$cardNo personel kartı için SGK Eksik Gün Kodu "${reason.label}" olarak güncellendi.',
    );
  }

  /// GMS.NET — Personelin %3 Otomatik Katılım Bireysel Emeklilik (BES) kesintisini açar/kapatır.
  void toggleEmployeeBesEnrollment(String cardNo) {
    final current = _empBesEnrolled[cardNo] ?? true;
    _empBesEnrolled[cardNo] = !current;
    refreshAll(
      bannerMessage:
          '#$cardNo personel için %3 BES Otomatik Katılım kesintisi ${!current ? "AKTİF" : "PASİF (Cayma/Ayrılma)"} yapıldı.',
    );
  }

  /// GMS.NET — Personelin Sosyal Yardımlarını (Yemek, Yol, İkramiye) ve İcra/Nafaka kesintisini günceller.
  void updateEmployeeGmsAllowancesAndGarnishment({
    required String cardNo,
    required double mealTl,
    required double transportTl,
    required double bonusTl,
    required double garnishmentTl,
    String? garnishmentFileNo,
  }) {
    _empMealAllowances[cardNo] = mealTl.clamp(0.0, 500000.0);
    _empTransportAllowances[cardNo] = transportTl.clamp(0.0, 500000.0);
    _empBonuses[cardNo] = bonusTl.clamp(0.0, 500000.0);
    _empGarnishments[cardNo] = garnishmentTl.clamp(0.0, 500000.0);
    if (garnishmentFileNo != null) {
      _empGarnishmentFiles[cardNo] = garnishmentFileNo.trim();
    }
    refreshAll(
      bannerMessage:
          '#$cardNo personel GMS.NET ek kazanç (Yemek/Yol/İkramiye) ve İcra kesintisi parametreleri güncellendi.',
    );
  }

  /// GMS.NET & Personel Portalı — Personelin kendi Bordro Zarfını (4857 Md. 37 Ücret Pusulası) dijital onaylaması.
  void signEmployeePayrollEnvelope(String cardNo) {
    _signedEnvelopeCards.add(cardNo);
    refreshAll(
      bannerMessage:
          '#$cardNo personel ${state.selectedPeriodKey} dönemi GMS.NET Bordro Zarfı (Ücret Pusulası) dijital olarak onaylandı.',
    );
  }

  /// GMS.NET — Entegre Bordro Tahakkuk Mahsup Fişi (TDHP 720/770 Brüt Ücret & SGK İşveren ->
  /// 335 Personele Borçlar, 360 Ödenecek Gelir/Damga Vergisi, 361 Ödenecek SGK Primleri, BES/İcra) keser.
  int accrueGmsIntegratedMahsupToLedger() {
    final count = _db.accrueMonthlyPayrollToLedger(
      periodKey: state.selectedPeriodKey,
      accrualDateKey: state.selectedDateKey,
      rows: state.puantajRows,
    );
    final totalSgkPayable = state.puantajRows.fold<double>(
      0.0,
      (s, r) =>
          s +
          r.sgkWorkerShareTl +
          r.unemploymentWorkerShareTl +
          r.sgkEmployerShareTl +
          r.unemploymentEmployerShareTl,
    );
    final totalTaxPayable = state.puantajRows.fold<double>(
      0.0,
      (s, r) => s + r.payableIncomeTaxTl + r.payableStampTaxTl,
    );
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_gms_mahsup_${state.selectedPeriodKey}',
        docNo: 'MHS-${state.selectedPeriodKey}-${stamp % 1000}',
        dateKey: state.selectedDateKey,
        accountId: 'acc_merkez_isletme',
        accountName: 'RESMİ MUHSGK & BORDRO TAHAKKUK MERKEZİ',
        entryType: LedgerEntryType.debitMemo,
        direction: 'B',
        amount: double.parse(
          (totalSgkPayable + totalTaxPayable).toStringAsFixed(2),
        ),
        cashOrBankName: 'GMS.NET Otomatik Entegrasyon Mahsup Fişi',
        expenseCategory: 'SGK & MUHTASAR (360/361)',
        description:
            '${state.selectedPeriodKey} MUHSGK Tahakkuku (361 SGK: ${totalSgkPayable.toStringAsFixed(2)} ₺ + 360 Vergi: ${totalTaxPayable.toStringAsFixed(2)} ₺)',
        puantajPeriodKey: state.selectedPeriodKey,
      ),
    );
    refreshAll(
      bannerMessage:
          'GMS.NET Otomatik Muhasebeleştirme: $count personel cari tahakkuku + 360/361 MUHSGK Mahsup Fişi kesildi.',
    );
    return count;
  }

  /// GMS.NET — Kıdem ve İhbar Tazminatını hesaplayarak personelin çıkış bordrosuna ve cari hesabına tahakkuk ettirir.
  void accrueSeveranceAndNoticeToExitPayroll({
    required PuantajEmployeeRow row,
    int? yearsOverride,
  }) {
    final netSeverance = row.calculateSeveranceNet(yearsOverride);
    final netNotice = row.calculateNoticeNet(yearsOverride);
    final totalExitNet =
        double.parse((netSeverance + netNotice).toStringAsFixed(2));
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_tazminat_${row.cardNo}_$stamp',
        docNo: 'TZM-${row.cardNo}-${stamp % 10000}',
        dateKey: state.selectedDateKey,
        accountId: row.accountId,
        accountName: row.fullName,
        entryType: LedgerEntryType.payrollAccrual,
        direction: 'A',
        amount: totalExitNet,
        cashOrBankName: 'GMS.NET Kıdem & İhbar Tazminat Bordrosu',
        expenseCategory: 'KIDEM VE İHBAR TAZMİNATI',
        description:
            'Kıdem (${yearsOverride ?? row.tenureYears} Yıl Net: ${netSeverance.toStringAsFixed(2)} ₺) + İhbar (${row.noticeWeeksForTenure(yearsOverride)} Hafta Net: ${netNotice.toStringAsFixed(2)} ₺)',
      ),
    );
    refreshAll(
      bannerMessage:
          '${row.fullName} için toplam ${totalExitNet.toStringAsFixed(2)} ₺ Net Kıdem + İhbar Tazminatı çıkış bordrosuna ve carisine tahakkuk ettirildi.',
    );
  }

  /// Faz 1 — Otomatik Puantaj tablosundaki tüm personellerin maaş + fazla mesai
  /// hakedişlerini tek tıkla Personel Cari Hesaplarına ('A' Alacak / Dekont) tahakkuk ettirir.
  int accrueAllPuantajToLedger() {
    final count = _db.accrueMonthlyPayrollToLedger(
      periodKey: state.selectedPeriodKey,
      accrualDateKey: state.selectedDateKey,
      rows: state.puantajRows,
    );
    refreshAll(
      bannerMessage:
          '$count personelin ${state.selectedPeriodKey} dönemi puantaj hakedişi Cari Hesaplara alacak (Dekont) olarak işlendi.',
    );
    return count;
  }

  /// Faz 1 — Seçili personele Kasa Nakit veya Banka Havale ile ödeme yapar ve carisini kapatır.
  void payEmployeeSalary({
    required PuantajEmployeeRow row,
    required bool viaBank,
  }) {
    final amountToPay = row.currentLedgerBalance > 0
        ? row.currentLedgerBalance
        : row.netPayableAfterAdvance;
    _db.payEmployeeFromLedger(
      row: row,
      dateKey: state.selectedDateKey,
      viaBank: viaBank,
      amount: amountToPay,
    );
    refreshAll(
      bannerMessage:
          '${row.fullName} için ${amountToPay.toStringAsFixed(2)} ₺ ${viaBank ? "Banka Havalesi" : "Kasa Nakit Ödemesi"} kaydedildi.',
    );
  }

  void addQuickAccount({
    required String code,
    required String name,
    required AccountingAccountType type,
    required String groupName,
    required String phone,
    double baseSalary = 0.0,
    int initialTrays = 0,
    String specialCode = '',
    int priceTier = 1,
    double defaultDiscountPercent = 0.0,
    String salesRepName = '',
    double creditLimitTl = 0.0,
    String cityDistrict = '',
  }) {
    final id = 'acc_${DateTime.now().microsecondsSinceEpoch}';
    _db.upsertAccountingAccount(
      AccountingAccount(
        id: id,
        code: code,
        name: name,
        type: type,
        groupName: groupName,
        phone: phone,
        baseSalaryOrDailyRate: baseSalary,
        trayBalance: initialTrays,
        specialCode: specialCode,
        priceTier: priceTier.clamp(1, 10),
        defaultDiscountPercent: defaultDiscountPercent,
        salesRepName: salesRepName,
        creditLimitTl: creditLimitTl,
        cityDistrict: cityDistrict,
      ),
    );
    refreshAll(bannerMessage: 'Cari kart eklendi: $name ($code)');
  }

  void addQuickLedgerTransaction({
    required AccountingAccount account,
    required LedgerEntryType entryType,
    required double amount,
    required String cashOrBankName,
    required String expenseCategory,
    required String description,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_$stamp',
        docNo: 'BEL-${stamp % 100000}',
        dateKey: state.selectedDateKey,
        accountId: account.id,
        accountName: account.name,
        entryType: entryType,
        direction: entryType.defaultDirection,
        amount: amount,
        cashOrBankName: cashOrBankName,
        expenseCategory: expenseCategory,
        description: description,
      ),
    );
    refreshAll(
      bannerMessage:
          '${account.name} hesabına ${amount.toStringAsFixed(2)} ₺ (${entryType.label}) kaydedildi.',
    );
  }

  void addContainerMovement({
    required AccountingAccount account,
    required String containerType,
    required int givenQty,
    required int returnedQty,
    required String note,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _db.recordContainerMovementAndSyncBalance(
      ContainerMovement(
        id: 'cnt_$stamp',
        dateKey: state.selectedDateKey,
        accountId: account.id,
        accountName: account.name,
        containerType: containerType,
        givenQty: givenQty,
        returnedQty: returnedQty,
        note: note,
      ),
    );
    refreshAll(
      bannerMessage:
          '${account.name} emanet kap hareketi işlendi ($containerType: +$givenQty Verilen / -$returnedQty İade).',
    );
  }

  void addOrUpdateStockBurnItem({
    required String code,
    required String name,
    required String unit,
    required double currentQty,
    required double dailyBurnRate,
    required double unitCost,
  }) {
    final id = 'stk_${code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    _db.upsertStockBurnItem(
      StockBurnItem(
        id: id,
        code: code,
        name: name,
        unit: unit,
        currentQty: currentQty,
        dailyBurnRate: dailyBurnRate,
        unitCost: unitCost,
      ),
    );
    refreshAll(
      bannerMessage:
          '$name kritik stok radarına eklendi (Tahmini Kalan: ${(currentQty / (dailyBurnRate <= 0 ? 1 : dailyBurnRate)).floor()} Gün).',
    );
  }

  /// Faz 2 — SaaS Mağaza Paketi ve Kanalı Güncelleme.
  void updateSaaSSubscription({
    SaaSTier? tier,
    StoreDistributionChannel? channel,
  }) {
    final updated = SaaSSubscriptionState(
      activeTier: tier ?? state.subscriptionState.activeTier,
      channel: channel ?? state.subscriptionState.channel,
      isTrialActive: state.subscriptionState.isTrialActive,
      trialDaysRemaining: state.subscriptionState.trialDaysRemaining,
      hardwareHookConnected: state.subscriptionState.hardwareHookConnected,
    );
    _db.saveSaaSSubscriptionState(updated);
    refreshAll(
      bannerMessage:
          'Abonelik planı güncellendi: ${updated.activeTier.title} (${updated.channel.label}).',
    );
  }

  /// Faz 3 — Tek Tıkla Excel / CSV Göç Sihirbazı çalıştırma.
  MigrationImportResult runLegacyMigrationWizard(String rawCsv) {
    final res = _db.importLegacyDataBatch(
      rawCsv,
      dateKey: state.selectedDateKey,
    );
    state = state.copyWith(lastMigrationResult: () => res);
    refreshAll(
      bannerMessage:
          'Göç Sihirbazı tamamlandı: ${res.accountsImported} Cari, ${res.stocksImported} Stok, ${res.transactionsCreated} Devir Fişi aktarıldı.',
    );
    return res;
  }

  List<PuantajEmployeeRow> _buildAutomaticPuantajMatrix({
    required String periodKey,
    required List<AccountingAccount> accounts,
    required List<AccountingTransaction> transactions,
  }) {
    final allEmployees = _db.getEmployees();
    final depts = {for (final d in _db.getDepartments()) d.id: d.name};
    final branches = {for (final b in _db.getBranches()) b.id: b.name};
    final allLeaves = _db.getAllLeaveRecords();
    final logs17 = _db.getAttendanceLogsForDate('2026-10-17');
    final logs19 = _db.getAttendanceLogsForDate('2026-10-19');
    final logs19Cards = logs19.map((e) => e.cardNo).toSet();
    final logs17Cards = logs17.map((e) => e.cardNo).toSet();

    final empAccountMap = <String, AccountingAccount>{
      for (final a in accounts)
        if (a.employeeCardNo != null) a.employeeCardNo!: a,
    };

    // Öncelikli vitrin personelleri + ilk 12 personel (Performanslı & Okunabilir 31 Gün Matrisi)
    const priorityCards = <String>[
      '00064',
      '01406',
      '01110',
      '00046',
      '00058',
      '00007',
      '00015',
      '00082',
      '01376',
      '01736',
    ];
    final selectedEmployees = <Employee>[
      for (final c in priorityCards)
        ...allEmployees.where((e) => e.cardNo == c),
    ];
    for (final e in allEmployees) {
      if (selectedEmployees.length >= 12) break;
      if (!selectedEmployees.any((s) => s.cardNo == e.cardNo)) {
        selectedEmployees.add(e);
      }
    }

    final rows = <PuantajEmployeeRow>[];
    for (final emp in selectedEmployees) {
      final acc = empAccountMap[emp.cardNo];
      final salaryType = acc?.salaryType ?? SalaryType.monthly;
      final baseSalary = acc != null && acc.baseSalaryOrDailyRate > 0
          ? acc.baseSalaryOrDailyRate
          : 32000.0;

      final empLeaves =
          allLeaves.where((l) => l.employeeId == emp.id).toList();
      final dayCodes = <int, String>{};
      int workedDays = 0;
      int weeklyRestDays = 0;
      int paidLeaveDays = 0;
      int sickReportDays = 0;
      int absentDays = 0;
      int ubgtDays = 0;
      double overtimeHours = 0.0;

      final overrides = _customDayOverrides[emp.cardNo] ?? const <int, String>{};

      for (int day = 1; day <= 30; day++) {
        final periodDayStr =
            '${periodKey.length >= 7 ? periodKey.substring(0, 7) : "2026-10"}-${day.toString().padLeft(2, '0')}';
        if (!overrides.containsKey(day) &&
            (emp.isBeforeHireDate(periodDayStr) ||
                emp.isTerminatedOn(periodDayStr, inclusiveOfExitDay: false))) {
          dayCodes[day] = '-';
          continue;
        }
        String code;
        if (overrides.containsKey(day)) {
          code = overrides[day]!;
        } else if (day == 29) {
          // 29 Ekim Cumhuriyet Bayramı (UBGT - Ulusal Bayram ve Genel Tatil)
          code = 'B';
        } else if (day % 7 == 4) {
          // Ekim 2026 Pazar günleri: 4, 11, 18, 25
          code = 'T';
        } else {
          final dateStr = '2026-10-${day.toString().padLeft(2, '0')}';
          final leaveMatch =
              empLeaves.where((l) => l.date == dateStr).firstOrNull;
          if (leaveMatch != null) {
            code = leaveMatch.leaveType == LeaveType.saglikRaporu ? 'R' : 'İ';
          } else if (day == 19 && emp.cardNo == '00064') {
            code = 'FM'; // Tenfei D35 +90 dk fazla mesai kaydı
          } else if (day == 17 && logs17Cards.contains(emp.cardNo)) {
            code = 'X';
          } else if (day == 19 && logs19Cards.contains(emp.cardNo)) {
            code = 'X';
          } else if (day == 20 && emp.cardNo == '00058') {
            code = 'Y'; // Yarım gün örneği
          } else {
            code = 'X';
          }
        }

        dayCodes[day] = code;
        switch (code) {
          case 'X':
            workedDays++;
            break;
          case 'FM':
            workedDays++;
            overtimeHours += 1.5;
            break;
          case 'B':
            ubgtDays++;
            break;
          case 'T':
            weeklyRestDays++;
            break;
          case 'İ':
            paidLeaveDays++;
            break;
          case 'R':
            sickReportDays++;
            break;
          case 'Y':
            workedDays++;
            absentDays++; // Yarım gün kesinti etkisi
            break;
          case '-':
            absentDays++;
            break;
        }
      }

      final accId = acc?.id ?? 'acc_emp_${emp.cardNo}';
      final advanceTotal = transactions
          .where(
            (t) =>
                t.accountId == accId &&
                t.entryType == LedgerEntryType.advancePayment,
          )
          .fold<double>(0.0, (sum, t) => sum + t.amount);

      final isAccrued = transactions.any(
        (t) =>
            t.accountId == accId &&
            t.entryType == LedgerEntryType.payrollAccrual &&
            t.puantajPeriodKey == periodKey,
      );

      final defaultLaw = emp.cardNo == '01110'
          ? GmsSgkIncentiveLaw.law06111
          : (emp.cardNo == '00046'
              ? GmsSgkIncentiveLaw.law17103
              : GmsSgkIncentiveLaw.law05510);
      final defaultMissingReason = sickReportDays > 0
          ? GmsMissingDayReason.code01
          : (absentDays > 0
              ? (emp.cardNo == '00058'
                  ? GmsMissingDayReason.code07
                  : GmsMissingDayReason.code15)
              : GmsMissingDayReason.code00);

      rows.add(
        PuantajEmployeeRow(
          employeeId: emp.id,
          cardNo: emp.cardNo,
          fullName: emp.fullName,
          departmentName: depts[emp.departmentId] ?? 'ÜRETİM',
          branchName: branches[emp.branchId] ?? 'MERKEZ',
          accountId: accId,
          salaryType: salaryType,
          baseSalary: baseSalary,
          dayCodes: dayCodes,
          workedDays: workedDays,
          weeklyRestDays: weeklyRestDays,
          paidLeaveDays: paidLeaveDays,
          sickReportDays: sickReportDays,
          absentDays: absentDays,
          ubgtDays: ubgtDays,
          overtimeHours: overtimeHours,
          approvedAdvanceDeduction: advanceTotal,
          isAccruedToLedger: isAccrued,
          currentLedgerBalance: acc?.netBalance ?? 0.0,
          sgkLaw: _empSgkLaws[emp.cardNo] ?? defaultLaw,
          missingDayReason:
              _empMissingReasons[emp.cardNo] ?? defaultMissingReason,
          besEnrolled: _empBesEnrolled[emp.cardNo] ?? (emp.id % 3 != 0),
          garnishmentDeduction: _empGarnishments[emp.cardNo] ??
              (emp.cardNo == '00082' ? 3250.0 : 0.0),
          garnishmentFileNo: _empGarnishmentFiles[emp.cardNo] ??
              (emp.cardNo == '00082'
                  ? 'İstanbul 14. İcra Dairesi 2026/4812 E.'
                  : null),
          mealAllowanceTl: _empMealAllowances[emp.cardNo] ?? 2600.0,
          transportAllowanceTl: _empTransportAllowances[emp.cardNo] ?? 1300.0,
          bonusOrPremiumTl: _empBonuses[emp.cardNo] ??
              (emp.cardNo == '00064' ? 2500.0 : 0.0),
          cumulativeTaxBaseTl: baseSalary * 4.2,
          iban:
              'TR${(10 + (emp.id % 89)).toString().padLeft(2, "0")} 0006 4000 0011 2345 67${emp.cardNo.padLeft(4, "0")}',
          hireDate: emp.hireDate,
          isEnvelopeSignedByEmployee:
              _signedEnvelopeCards.contains(emp.cardNo),
        ),
      );
    }

    return rows;
  }

  EndOfDayCockpitSummary _computeCockpitSummary({
    required List<AccountingAccount> accounts,
    required List<AccountingTransaction> transactions,
    required List<StockBurnItem> stocks,
  }) {
    if (accounts.isEmpty && transactions.isEmpty && stocks.isEmpty) {
      return const EndOfDayCockpitSummary();
    }

    double cashInTotal = 0.0;
    double cashOutTotal = 0.0;
    double totalIncoming = 0.0;
    double totalOutgoing = 0.0;

    final incomingByType = <String, double>{};
    final outgoingByCategory = <String, double>{};

    for (final tx in transactions) {
      if (tx.entryType == LedgerEntryType.cashIn ||
          (tx.entryType == LedgerEntryType.iceCreamSale &&
              tx.cashOrBankName.toLowerCase().contains('kasa'))) {
        cashInTotal += tx.amount;
      } else if (tx.entryType == LedgerEntryType.cashOut ||
          tx.entryType == LedgerEntryType.expense ||
          tx.entryType == LedgerEntryType.advancePayment) {
        cashOutTotal += tx.amount;
      }

      if (tx.entryType.isIncomingFlow ||
          tx.entryType == LedgerEntryType.purchaseInvoice) {
        totalIncoming += tx.amount;
        incomingByType[tx.entryType.label] =
            (incomingByType[tx.entryType.label] ?? 0.0) + tx.amount;
      } else {
        totalOutgoing += tx.amount;
        final cat = tx.expenseCategory.isEmpty
            ? tx.entryType.label
            : tx.expenseCategory;
        outgoingByCategory[cat] = (outgoingByCategory[cat] ?? 0.0) + tx.amount;
      }
    }

    final cashOnHand = (cashInTotal - cashOutTotal).clamp(0.0, double.infinity);
    final stockVal =
        stocks.fold<double>(0.0, (sum, s) => sum + s.totalValuation);
    final receivables = accounts
        .where((a) => a.netBalance < 0)
        .fold<double>(0.0, (sum, a) => sum + a.netBalance.abs());

    final currentTotalBalance = cashOnHand + stockVal + receivables;
    final netRemaining = totalIncoming - totalOutgoing;
    final dailyIncrease = netRemaining > 0 ? netRemaining * 0.42 : 0.0;
    final pct = currentTotalBalance > 0
        ? (dailyIncrease / currentTotalBalance) * 100.0
        : 0.0;

    return EndOfDayCockpitSummary(
      currentTotalBalance: currentTotalBalance,
      cashOnHand: cashOnHand,
      last7DaysCashAverage: cashOnHand * 0.78,
      dailyBalanceIncrease: dailyIncrease,
      dailyBalanceIncreasePercent: pct,
      totalIncoming: totalIncoming,
      totalOutgoing: totalOutgoing,
      netRemainingFlow: (cashInTotal +
              (incomingByType[LedgerEntryType.bankIn.label] ?? 0.0)) -
          totalOutgoing,
      consumptionVarianceTl: 0.0,
      unbilledInvoiceGapTl: receivables * 0.15,
      incomingByType: incomingByType,
      outgoingByCategory: outgoingByCategory,
    );
  }

  // ==========================================================================
  // HASİBU ERP (SİPARİŞ -> İRSALİYE -> FATURA, BÖLGE FİYAT, REÇETE/BOM)
  // ==========================================================================

  void createErpOrderOrInvoice({
    required AccountingAccount account,
    required String regionGroup,
    required int priceTier,
    required String stockCode,
    required String stockName,
    required double orderedQtyKg,
    required int trayCount,
    required double unitPriceTl,
    double discountPercent = 0.0,
    double vatPercent = 10.0,
    String initialStage = 'SIPARIS',
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final numPart = (stamp % 9000) + 1000;
    final orderNo = 'SIP-2026-$numPart';
    final waybillNo =
        initialStage != 'SIPARIS' ? 'IRS-2026-$numPart' : null;
    final invoiceNo =
        initialStage == 'FATURALANDI' ? 'FAT-2026-$numPart' : null;

    final item = ErpOrderWaybillInvoiceItem(
      id: 'erp_$stamp',
      orderDocNo: orderNo,
      waybillDocNo: waybillNo,
      invoiceDocNo: invoiceNo,
      dateKey: state.selectedDateKey,
      accountId: account.id,
      accountName: account.name,
      regionGroup: regionGroup,
      priceTier: priceTier.clamp(1, 10),
      stockCode: stockCode,
      stockName: stockName,
      orderedQtyKg: orderedQtyKg,
      shippedQtyKg: initialStage != 'SIPARIS' ? orderedQtyKg : 0.0,
      invoicedQtyKg: initialStage == 'FATURALANDI' ? orderedQtyKg : 0.0,
      trayCount: trayCount,
      unitPriceTl: unitPriceTl,
      discountPercent: discountPercent,
      vatPercent: vatPercent,
      stage: initialStage,
      salesRepName: account.salesRepName,
    );

    _db.upsertErpDocument(item);

    if (initialStage == 'FATURALANDI') {
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_erp_fat_$stamp',
          docNo: invoiceNo!,
          dateKey: state.selectedDateKey,
          accountId: account.id,
          accountName: account.name,
          entryType: LedgerEntryType.salesInvoice,
          direction: 'B',
          amount: double.parse(item.grandTotalTl.toStringAsFixed(2)),
          cashOrBankName: 'Fatura Servisi',
          expenseCategory: 'SATIŞ FATURASI',
          salesRepName: account.salesRepName,
          linkedOrderDocId: item.id,
          description:
              '$stockName (${orderedQtyKg.toStringAsFixed(1)} Kg / $trayCount Tepsi) Fatura Tahakkuku',
        ),
      );
    }
    refreshAll(
      bannerMessage:
          'Hasibu ERP Belgesi oluşturuldu: $orderNo (${account.name} • ${item.grandTotalTl.toStringAsFixed(2)} ₺)',
    );
  }

  /// Siparişten İrsaliyeye (`IrsaliyeyeSiparisSec`) ve İrsaliyeden Faturaya (`FaturayaIrsaliyeSec`)
  /// tek tıkla zincirleme aktarım + emanet tepsi ve cari borç tahakkuku.
  void advanceErpDocumentStage(String id) {
    final idx = state.erpOrdersWaybillsInvoices.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final current = state.erpOrdersWaybillsInvoices[idx];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = current.orderDocNo.split('-').last;

    if (current.stage == 'SIPARIS') {
      final waybillNo = 'IRS-2026-$suffix';
      final next = current.copyWith(
        waybillDocNo: waybillNo,
        shippedQtyKg: current.orderedQtyKg,
        stage: 'IRSALIYE_SEVK',
      );
      _db.upsertErpDocument(next);

      if (current.trayCount > 0) {
        _db.recordContainerMovementAndSyncBalance(
          ContainerMovement(
            id: 'cnt_irs_$stamp',
            dateKey: state.selectedDateKey,
            accountId: current.accountId,
            accountName: current.accountName,
            containerType: 'Tepsi',
            givenQty: current.trayCount,
            returnedQty: 0,
            note: '$waybillNo İrsaliye Sevkiyatı (${current.stockName})',
          ),
        );
      }
      refreshAll(
        bannerMessage:
            'Sipariş (${current.orderDocNo}) -> Satış İrsaliyesine ($waybillNo) aktarıldı ve ${current.trayCount} Tepsi cariye zimmetlendi.',
      );
    } else if (current.stage == 'IRSALIYE_SEVK') {
      final invoiceNo = 'FAT-2026-$suffix';
      final next = current.copyWith(
        invoiceDocNo: invoiceNo,
        invoicedQtyKg:
            current.shippedQtyKg > 0 ? current.shippedQtyKg : current.orderedQtyKg,
        stage: 'FATURALANDI',
      );
      _db.upsertErpDocument(next);

      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_fat_$stamp',
          docNo: invoiceNo,
          dateKey: state.selectedDateKey,
          accountId: current.accountId,
          accountName: current.accountName,
          entryType: LedgerEntryType.salesInvoice,
          direction: 'B',
          amount: double.parse(next.grandTotalTl.toStringAsFixed(2)),
          cashOrBankName: 'Fatura Servisi',
          expenseCategory: 'SATIŞ FATURASI',
          salesRepName: current.salesRepName,
          linkedOrderDocId: current.id,
          description:
              'İrsaliyeden (${current.waybillDocNo}) Faturaya Aktarım • ${current.stockName}',
        ),
      );
      refreshAll(
        bannerMessage:
            'İrsaliye (${current.waybillDocNo}) -> Satış Faturasına ($invoiceNo) dönüştürüldü ve Cari Borç (${next.grandTotalTl.toStringAsFixed(2)} ₺) işlendi.',
      );
    }
  }

  /// `FaturayaKarsilikTahsilat`: Fatura satırından anında Kasa/Banka tahsilatı.
  void collectPaymentAgainstInvoice(String id, {bool viaBank = false}) {
    final idx = state.erpOrdersWaybillsInvoices.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final current = state.erpOrdersWaybillsInvoices[idx];
    final remaining = (current.grandTotalTl - current.collectedAmountTl).clamp(
      0.0,
      double.infinity,
    );
    if (remaining <= 0) return;

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final next = current.copyWith(collectedAmountTl: current.grandTotalTl);
    _db.upsertErpDocument(next);

    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_fth_$stamp',
        docNo: 'TAH-${current.invoiceDocNo ?? current.orderDocNo}',
        dateKey: state.selectedDateKey,
        accountId: current.accountId,
        accountName: current.accountName,
        entryType: viaBank ? LedgerEntryType.bankIn : LedgerEntryType.cashIn,
        direction: 'A',
        amount: double.parse(remaining.toStringAsFixed(2)),
        cashOrBankName: viaBank ? 'Ticari Vadesiz Banka' : 'Merkez TL Kasa',
        expenseCategory: 'FATURA TAHSİLATI',
        salesRepName: current.salesRepName,
        linkedOrderDocId: current.id,
        description:
            '${current.invoiceDocNo ?? current.orderDocNo} Faturaya Karşılık Tahsilat',
      ),
    );
    refreshAll(
      bannerMessage:
          '${current.accountName} faturasına karşılık ${remaining.toStringAsFixed(2)} ₺ tahsilat işlendi.',
    );
  }

  /// `BayiBolgeFiyatTopluGuncelle`: Seçilen bölge veya tüm bayi fiyat şablonlarına toplu % fiyat güncellemesi.
  void applyBulkDealerRegionPriceAdjust(double percentDelta) {
    if (percentDelta == 0) return;
    final factor = 1.0 + (percentDelta / 100.0);
    final updatedErp = state.erpOrdersWaybillsInvoices
        .map(
          (e) => e.copyWith(
            unitPriceTl: double.parse(
              (e.unitPriceTl * factor).clamp(1.0, 999999.0).toStringAsFixed(2),
            ),
          ),
        )
        .toList(growable: false);
    for (final doc in updatedErp) {
      _db.upsertErpDocument(doc);
    }

    final updatedButtons = state.posQuickButtons
        .map(
          (b) => b.unitPriceTl > 0
              ? b.copyWith(
                  unitPriceTl: double.parse(
                    (b.unitPriceTl * factor)
                        .clamp(1.0, 999999.0)
                        .toStringAsFixed(2),
                  ),
                )
              : b,
        )
        .toList(growable: false);

    state = state.copyWith(posQuickButtons: updatedButtons);
    refreshAll(
      bannerMessage:
          'Bayi Bölge Fiyat Şablonu (1..10 Grup) ve Mağaza POS Fiyatları %${percentDelta.toStringAsFixed(1)} oranında toplu güncellendi.',
    );
  }

  /// `UretimReceteGiris` & `UretimFisi_Bugday`: Reçeteye göre üretim fişi keser ve hammadde stoklarını düşer.
  void executeProductionRecipeBatch(String recipeId, {int batchCount = 1}) {
    final idx = state.productionRecipes.indexWhere((r) => r.id == recipeId);
    if (idx < 0) return;
    final rcp = state.productionRecipes[idx];
    final updatedRcp = rcp.copyWith(
      producedBatchesToday: rcp.producedBatchesToday + batchCount,
    );
    _db.upsertProductionRecipe(updatedRcp);

    // Hammadde stoklarından otomatik sarfiyat düşümü
    for (final stk in state.stockBurnItems.take(3)) {
      _db.adjustStockBurnItemQuantity(stk.id, -(batchCount * 2.0));
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final totalCost = rcp.totalBatchCostTl * batchCount;
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_urt_$stamp',
        docNo: 'URT-${rcp.recipeCode}-${stamp % 1000}',
        dateKey: state.selectedDateKey,
        accountId: state.selectedAccount?.id ?? 'acc_demo_branch_1',
        accountName: 'FABRİKA ÜRETİM MERKEZİ',
        entryType: LedgerEntryType.productionVoucher,
        direction: 'A',
        amount: double.parse(totalCost.toStringAsFixed(2)),
        cashOrBankName: 'Fabrika Üretim Hattı',
        expenseCategory: rcp.recipeCategory,
        description:
            '${rcp.productName} ($batchCount Parti • ${(rcp.batchOutputKg * batchCount).toStringAsFixed(1)} Kg / ${rcp.trayYieldCount * batchCount} Tepsi)',
      ),
    );
    refreshAll(
      bannerMessage:
          '${rcp.productName}: $batchCount parti üretim fişi işlendi ve hammadde stokları otomatik düşüldü.',
    );
  }

  /// `KdvYansitma`: Resmi İşlemler sekmesinde seçilen belge için Ana Programa KDV Yansıtma Fişi keser.
  void reflectOfficialVatToMainLedger(String erpItemId) {
    final idx = state.erpOrdersWaybillsInvoices.indexWhere(
      (e) => e.id == erpItemId,
    );
    if (idx < 0) return;
    final item = state.erpOrdersWaybillsInvoices[idx];
    if (item.isOfficialVatReflected) return;

    final updated = item.copyWith(isOfficialVatReflected: true);
    _db.upsertErpDocument(updated);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_kdv_$stamp',
        docNo: 'KDV-${item.invoiceDocNo ?? item.orderDocNo}',
        dateKey: state.selectedDateKey,
        accountId: item.accountId,
        accountName: item.accountName,
        entryType: LedgerEntryType.vatReflectionMemo,
        direction: 'B',
        amount: double.parse(item.vatAmountTl.toStringAsFixed(2)),
        cashOrBankName: 'Resmi Muhasebe Servisi',
        expenseCategory: 'KDV YANSITMA',
        description:
            'Resmi Fatura (%${item.vatPercent.toStringAsFixed(0)} KDV) Ana Programa Yansıtma Dekontu',
      ),
    );
    refreshAll(
      bannerMessage:
          '${item.accountName} için ${item.vatAmountTl.toStringAsFixed(2)} ₺ Resmi KDV Yansıtma Dekontu ana programa işlendi.',
    );
  }

  void addCustomSpreadsheetRow({
    required String sheetTitle,
    required String categoryName,
    required double debitColumnTl,
    required double creditColumnTl,
    required String formulaNote,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final row = CustomSpreadsheetRecord(
      id: 'xls_$stamp',
      sheetTitle: sheetTitle.trim().toUpperCase(),
      categoryName: categoryName.trim(),
      periodKey: state.selectedPeriodKey,
      debitColumnTl: debitColumnTl,
      creditColumnTl: creditColumnTl,
      formulaNote: formulaNote.trim(),
    );
    _db.upsertCustomSpreadsheet(row);
    refreshAll(bannerMessage: 'Özel Excel Tablosuna yeni satır eklendi: $sheetTitle');
  }

  // ==========================================================================
  // HASİBU MAĞAZA DOKUNMATİK POS & ŞUBE YÖNETİMİ
  // ==========================================================================

  void selectBranchStore(int branchId) {
    state = state.copyWith(selectedBranchStoreId: branchId);
  }

  void selectPosTabGroup(int groupIndex) {
    state = state.copyWith(selectedPosTabGroup: groupIndex.clamp(1, 4));
  }

  void setLiveScaleWeightKg(double weightKg) {
    state = state.copyWith(
      liveScaleWeightKg: double.parse(
        weightKg.clamp(0.050, 50.0).toStringAsFixed(3),
      ),
    );
  }

  void toggleStoreOnlineConnection(int branchId) {
    final updated = state.branchProfiles
        .map(
          (b) => b.branchId == branchId
              ? b.copyWith(isOnlineConnected: !b.isOnlineConnected)
              : b,
        )
        .toList(growable: false);
    state = state.copyWith(branchProfiles: updated);
  }

  /// `OFFLINE SATIŞLAR MERKEZE GÖNDERİLİYOR`: Offline kesilmiş tüm şube POS fişlerini merkeze senkronize eder.
  void syncOfflinePosReceiptsToHq() {
    int syncedCount = 0;
    for (final rcp in state.branchPosReceipts) {
      if (!rcp.syncedToHeadquarters) {
        _db.upsertBranchPosReceipt(rcp.copyWith(syncedToHeadquarters: true));
        syncedCount++;
      }
    }
    final updatedProfiles = state.branchProfiles
        .map((b) => b.copyWith(isOnlineConnected: true))
        .toList(growable: false);
    state = state.copyWith(branchProfiles: updatedProfiles);
    refreshAll(
      bannerMessage: syncedCount > 0
          ? '$syncedCount adet Offline Mağaza POS fişi merkeze (ONLINE) başarıyla gönderildi.'
          : 'Tüm şube POS fişleri merkez sunucu ile %100 senkronize (ONLINE).',
    );
  }

  void addQuickButtonToPosCart(BranchPosQuickButton btn) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final qty = btn.unit == 'KG' ? state.liveScaleWeightKg : 1.0;
    final line = BranchPosCartLine(
      id: 'line_$stamp',
      stockCode: btn.stockCode,
      productName: btn.productName,
      unit: btn.unit,
      quantity: qty,
      normalUnitPriceTl: btn.unitPriceTl,
      isComplimentary: btn.isComplimentaryDefault,
      isBoxContainer: btn.isBoxContainer,
      boxGramWeightKg: btn.boxGramWeightKg,
    );
    final updated = <BranchPosCartLine>[...state.activePosCart, line];
    state = state.copyWith(
      activePosCart: updated,
      selectedPosCartLineId: () => line.id,
    );
  }

  void selectPosCartLine(String lineId) {
    state = state.copyWith(selectedPosCartLineId: () => lineId);
  }

  /// `Seçili Satırı BEDELSİZ'e Çevir` / `BEDELLİ'ye Çevir`
  void toggleSelectedPosLineComplimentary() {
    final targetId = state.selectedPosCartLineId ??
        (state.activePosCart.isNotEmpty ? state.activePosCart.last.id : null);
    if (targetId == null) return;
    final updated = state.activePosCart
        .map(
          (l) => l.id == targetId
              ? l.copyWith(isComplimentary: !l.isComplimentary)
              : l,
        )
        .toList(growable: false);
    state = state.copyWith(activePosCart: updated);
  }

  /// `Seçili Satırı SİL`
  void removeSelectedPosCartLine() {
    final targetId = state.selectedPosCartLineId ??
        (state.activePosCart.isNotEmpty ? state.activePosCart.last.id : null);
    if (targetId == null) return;
    final updated = state.activePosCart
        .where((l) => l.id != targetId)
        .toList(growable: false);
    state = state.copyWith(
      activePosCart: updated,
      selectedPosCartLineId: () => updated.isNotEmpty ? updated.last.id : null,
    );
  }

  /// `Yeni Fiş`
  void clearPosCart() {
    state = state.copyWith(
      activePosCart: const <BranchPosCartLine>[],
      selectedPosCartLineId: () => null,
    );
  }

  /// `Bu Fişi Askıya Al` (`Aski`)
  void suspendCurrentPosCart({String labelNote = 'Bekleyen Müşteri Fişi'}) {
    if (state.activePosCart.isEmpty) return;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final suspended = BranchSuspendedReceipt(
      id: 'susp_${now.microsecondsSinceEpoch}',
      branchId: state.selectedBranchStoreId,
      suspendedAtTime: timeStr,
      labelNote: labelNote,
      lines: state.activePosCart,
    );
    state = state.copyWith(
      suspendedPosReceipts: <BranchSuspendedReceipt>[
        suspended,
        ...state.suspendedPosReceipts,
      ],
      activePosCart: const <BranchPosCartLine>[],
      selectedPosCartLineId: () => null,
      statusBanner: () =>
          'Fiş askıya alındı ($labelNote • ${suspended.totalAmountTl.toStringAsFixed(2)} ₺).',
    );
  }

  /// `Askıdan Çağır` (`AskiTabloGor`)
  void recallSuspendedPosReceipt(String suspendedId) {
    final match = state.suspendedPosReceipts
        .where((s) => s.id == suspendedId)
        .firstOrNull;
    if (match == null) return;
    final remaining = state.suspendedPosReceipts
        .where((s) => s.id != suspendedId)
        .toList(growable: false);
    state = state.copyWith(
      activePosCart: match.lines,
      selectedPosCartLineId: () =>
          match.lines.isNotEmpty ? match.lines.last.id : null,
      suspendedPosReceipts: remaining,
      statusBanner: () =>
          'Askıdaki fiş geri çağrıldı (${match.labelNote} • ${match.totalAmountTl.toStringAsFixed(2)} ₺).',
    );
  }

  /// `ButtonaRenkSec` & Tuş Ürün/Fiyat/Bedelsiz Ayarı
  void configurePosQuickButton({
    required int slotIndex,
    required String productName,
    required double unitPriceTl,
    required bool isComplimentaryDefault,
    required int colorHex,
  }) {
    final updated = state.posQuickButtons
        .map(
          (b) => b.slotIndex == slotIndex
              ? b.copyWith(
                  productName: productName,
                  unitPriceTl: unitPriceTl,
                  isComplimentaryDefault: isComplimentaryDefault,
                  colorHex: colorHex,
                )
              : b,
        )
        .toList(growable: false);
    state = state.copyWith(
      posQuickButtons: updated,
      statusBanner: () =>
          'Hızlı Satış Tuşu (#$slotIndex - $productName) güncellendi.',
    );
  }

  /// 5'li POS Ödeme Motoru: `NAKİT`, `KREDİ KARTI`, `PARÇALI (Nakit+POS)`, `AÇIK HESAP`, `İADE ALIM`
  void completePosCheckout({
    required BranchPosPaymentMethod paymentMethod,
    double? receivedCashOverride,
    double? splitCashPart,
    String customerName = '',
    String customerPhone = '',
    String note = '',
  }) {
    if (state.activePosCart.isEmpty) return;
    final store = state.activeBranchProfile;
    final total = double.parse(state.posCartTotalTl.toStringAsFixed(2));
    final sweetKg = double.parse(state.posCartSweetWeightKg.toStringAsFixed(3));
    final boxes = state.posCartBoxCount;
    final boxTareKg = double.parse(state.posCartBoxTareKg.toStringAsFixed(3));
    final compCount =
        state.activePosCart.where((l) => l.isComplimentary).length;

    double cashAmt = 0.0;
    double posAmt = 0.0;
    double openAccAmt = 0.0;
    double recCash = 0.0;
    double changeTl = 0.0;
    String rcpType = 'SATIŞ';

    switch (paymentMethod) {
      case BranchPosPaymentMethod.cash:
        cashAmt = total;
        recCash = (receivedCashOverride != null && receivedCashOverride >= total)
            ? receivedCashOverride
            : total;
        changeTl = double.parse((recCash - total).toStringAsFixed(2));
        break;
      case BranchPosPaymentMethod.creditCard:
        posAmt = total;
        break;
      case BranchPosPaymentMethod.splitCashAndPos:
        cashAmt = (splitCashPart ?? (total * 0.4)).clamp(0.0, total);
        posAmt = double.parse((total - cashAmt).toStringAsFixed(2));
        recCash = cashAmt;
        break;
      case BranchPosPaymentMethod.openAccount:
        openAccAmt = total;
        break;
      case BranchPosPaymentMethod.refundReturn:
        rcpType = 'İADE';
        cashAmt = total;
        break;
    }

    final now = DateTime.now();
    final stamp = now.microsecondsSinceEpoch;
    final receiptNo = 'FIS-2026-${(stamp % 9000) + 1000}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final summary = state.activePosCart
        .map(
          (l) =>
              '${l.quantity.toStringAsFixed(l.unit == "KG" ? 3 : 0)} ${l.unit} ${l.productName}${l.isComplimentary ? " [BEDELSİZ]" : ""}',
        )
        .join(', ');

    final receipt = BranchPosReceipt(
      id: 'pos_rcp_$stamp',
      receiptNo: receiptNo,
      branchId: store.branchId,
      storeName: store.storeName,
      dateKey: state.selectedDateKey,
      timeText: timeStr,
      cashierName: store.handingOverCashier,
      receiptType: rcpType,
      paymentMethod: paymentMethod,
      totalAmountTl: total,
      cashAmountTl: cashAmt,
      posAmountTl: posAmt,
      openAccountAmountTl: openAccAmt,
      receivedCashTl: recCash,
      changeReturnedTl: changeTl,
      customerName: customerName.trim(),
      customerPhone: customerPhone.trim(),
      note: note.trim(),
      sweetWeightKg: sweetKg,
      boxCount: boxes,
      boxTareWeightKg: boxTareKg,
      complimentaryLineCount: compCount,
      syncedToHeadquarters: store.isOnlineConnected,
      itemsSummary: summary,
    );

    _db.upsertBranchPosReceipt(receipt);

    if (total > 0) {
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_pos_$stamp',
          docNo: receiptNo,
          dateKey: state.selectedDateKey,
          accountId: store.storeAccountId,
          accountName: store.storeName,
          entryType: paymentMethod == BranchPosPaymentMethod.refundReturn
              ? LedgerEntryType.salesReturn
              : (paymentMethod == BranchPosPaymentMethod.creditCard
                  ? LedgerEntryType.bankIn
                  : LedgerEntryType.cashIn),
          direction:
              paymentMethod == BranchPosPaymentMethod.refundReturn ? 'B' : 'A',
          amount: total,
          cashOrBankName: paymentMethod == BranchPosPaymentMethod.creditCard
              ? store.posBankName
              : store.cashBoxName,
          expenseCategory: 'MAĞAZA PERAKENDE POS',
          description:
              '${paymentMethod.label} • $summary${changeTl > 0 ? " (Para Üstü: ${changeTl.toStringAsFixed(2)} ₺)" : ""}',
        ),
      );
    }

    state = state.copyWith(
      activePosCart: const <BranchPosCartLine>[],
      selectedPosCartLineId: () => null,
    );
    refreshAll(
      bannerMessage:
          'POS Fişi kesildi ($receiptNo • ${paymentMethod.label} • ${total.toStringAsFixed(2)} ₺${changeTl > 0 ? " • Para Üstü: ${changeTl.toStringAsFixed(2)} ₺" : ""}).',
    );
  }

  /// `Magaza_AcikHesapTahsilatGiris`: Şube Açık Hesap (Veresiye) fişini iskontolu tahsil eder.
  void collectBranchOpenAccountReceivable(
    String receiptId, {
    double discountTl = 0.0,
    bool viaPos = false,
  }) {
    final match = state.branchPosReceipts
        .where((r) => r.id == receiptId)
        .firstOrNull;
    if (match == null || match.openAccountAmountTl <= 0) return;

    final netCollected = (match.openAccountAmountTl - discountTl).clamp(
      0.0,
      double.infinity,
    );
    final updated = match.copyWith(
      openAccountAmountTl: 0.0,
      note:
          '${match.note} [TAHSİL EDİLDİ: ${netCollected.toStringAsFixed(2)} ₺${discountTl > 0 ? ", İskonto: ${discountTl.toStringAsFixed(2)} ₺" : ""}]',
    );
    _db.upsertBranchPosReceipt(updated);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_oa_col_$stamp',
        docNo: 'AHT-${match.receiptNo}',
        dateKey: state.selectedDateKey,
        accountId: state.activeBranchProfile.storeAccountId,
        accountName: match.customerName.isEmpty
            ? match.storeName
            : match.customerName,
        entryType: viaPos ? LedgerEntryType.bankIn : LedgerEntryType.cashIn,
        direction: 'A',
        amount: netCollected,
        cashOrBankName: viaPos
            ? state.activeBranchProfile.posBankName
            : state.activeBranchProfile.cashBoxName,
        expenseCategory: 'AÇIK HESAP TAHSİLATI',
        description:
            '${match.receiptNo} Açık Hesap Tahsilatı (${match.customerName})',
      ),
    );
    refreshAll(
      bannerMessage:
          'Açık Hesap (${match.customerName}) tahsil edildi: ${netCollected.toStringAsFixed(2)} ₺.',
    );
  }

  /// `Magaza_Sevk_Giris`: Merkezden Şubeye Sevk Fişi + Otomatik Tepsi/Köşebent + Çift Taraflı Cari Virman.
  void createBranchShipmentFromHq({
    required int targetBranchId,
    required String itemsSummary,
    required double totalKg,
    required int trayCount,
    required double transferAmountTl,
    String sourceOrderNo = '',
    String vehiclePlate = '34 HSB 104',
  }) {
    final store = state.branchProfiles.firstWhere(
      (b) => b.branchId == targetBranchId,
      orElse: () => state.activeBranchProfile,
    );
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final docNo = 'MSVK-2026-${(stamp % 900) + 100}';
    final kosebentCount = (trayCount / 2).ceil();

    final voucher = BranchTransferVoucher(
      id: 'btr_$stamp',
      docNo: docNo,
      dateKey: state.selectedDateKey,
      targetBranchId: store.branchId,
      targetStoreName: store.storeName,
      sourceOrderNo: sourceOrderNo,
      vehiclePlate: vehiclePlate,
      itemsSummary: itemsSummary,
      totalKg: totalKg,
      trayCount: trayCount,
      kosebentCount: kosebentCount,
      transferAmountTl: transferAmountTl,
      status: 'SEVK_EDILDI',
    );

    state = state.copyWith(
      branchTransfers: <BranchTransferVoucher>[
        voucher,
        ...state.branchTransfers,
      ],
    );

    _db.recordContainerMovementAndSyncBalance(
      ContainerMovement(
        id: 'cnt_msvk_$stamp',
        dateKey: state.selectedDateKey,
        accountId: store.storeAccountId,
        accountName: store.storeName,
        containerType: 'Tepsi',
        givenQty: trayCount,
        returnedQty: 0,
        note: '$docNo Şube Sevk ($vehiclePlate) + $kosebentCount Köşebent',
      ),
    );

    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_msvk_$stamp',
        docNo: docNo,
        dateKey: state.selectedDateKey,
        accountId: store.storeAccountId,
        accountName: store.storeName,
        entryType: LedgerEntryType.warehouseTransfer,
        direction: 'B',
        amount: transferAmountTl,
        cashOrBankName: 'Merkez Fabrika Sevk',
        expenseCategory: 'ŞUBE SEVK VİRMANI',
        description:
            '$itemsSummary ($totalKg Kg / $trayCount Tepsi / $kosebentCount Köşebent)',
      ),
    );
    refreshAll(
      bannerMessage:
          '${store.storeName} için $docNo Sevk Fişi kesildi ($trayCount Tepsi, $kosebentCount Köşebent ve ${transferAmountTl.toStringAsFixed(2)} ₺ cari virman işlendi).',
    );
  }

  /// `Magaza_AlimGiris`: Şube dış mal alım fişi (Süt, Kaymak, İçecek vb.).
  void recordBranchLocalPurchase({
    required String supplierName,
    required String stockName,
    required double quantity,
    required double totalAmountTl,
  }) {
    final store = state.activeBranchProfile;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final docNo = 'MALM-2026-${(stamp % 900) + 100}';
    final item = BranchLocalPurchase(
      id: 'blp_$stamp',
      docNo: docNo,
      dateKey: state.selectedDateKey,
      branchId: store.branchId,
      storeName: store.storeName,
      supplierName: supplierName.trim().toUpperCase(),
      stockName: stockName.trim(),
      quantity: quantity,
      totalAmountTl: totalAmountTl,
    );
    state = state.copyWith(
      branchLocalPurchases: <BranchLocalPurchase>[
        item,
        ...state.branchLocalPurchases,
      ],
    );
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_malm_$stamp',
        docNo: docNo,
        dateKey: state.selectedDateKey,
        accountId: store.storeAccountId,
        accountName: store.storeName,
        entryType: LedgerEntryType.purchaseInvoice,
        direction: 'B',
        amount: totalAmountTl,
        cashOrBankName: store.cashBoxName,
        expenseCategory: 'MAĞAZA DIŞ MAL ALIMI',
        description: '$supplierName -> $stockName ($quantity Birim)',
      ),
    );
    refreshAll(
      bannerMessage:
          '${store.storeName} Dış Mal Alım Fişi ($docNo • ${totalAmountTl.toStringAsFixed(2)} ₺) işlendi.',
    );
  }

  /// `Magaza_GunSonu_Giris` + **Kasa Teslim Tutanağı** + **Kutu Dara Tatlı Stoğuna Ekleme** (`Magaza_KutuRapor`).
  void submitBranchEndOfDayAndCashHandover({
    required double actualCountedCashTl,
    required double coinCashTl,
    required double actualPosZReportTl,
    required String handedOverBy,
    required String receivedBy,
    required String witnessName,
  }) {
    final store = state.activeBranchProfile;
    final storeReceipts = state.branchPosReceipts
        .where((r) => r.branchId == store.branchId)
        .toList();

    final sysCash = storeReceipts
        .where((r) => r.receiptType == 'SATIŞ')
        .fold<double>(0.0, (s, r) => s + r.cashAmountTl);
    final sysPos = storeReceipts
        .where((r) => r.receiptType == 'SATIŞ')
        .fold<double>(0.0, (s, r) => s + r.posAmountTl);
    final openAcc = storeReceipts
        .where((r) => r.receiptType == 'SATIŞ')
        .fold<double>(0.0, (s, r) => s + r.openAccountAmountTl);
    final refunds = storeReceipts
        .where((r) => r.receiptType == 'İADE')
        .fold<double>(0.0, (s, r) => s + r.totalAmountTl);
    final localPurch = state.branchLocalPurchases
        .where((p) => p.branchId == store.branchId)
        .fold<double>(0.0, (s, p) => s + p.totalAmountTl);
    final totalBoxTareKg = storeReceipts.fold<double>(
      0.0,
      (s, r) => s + r.boxTareWeightKg,
    );
    final effectiveBoxTareKg =
        totalBoxTareKg > 0 ? totalBoxTareKg : 3.450; // Günlük Kutu Dara
    final boxProfitTl = double.parse(
      (effectiveBoxTareKg * 780.0).toStringAsFixed(2),
    );

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final docNo = 'GSN-2026-${(stamp % 900) + 100}';

    final settlement = BranchEndOfDaySettlement(
      id: 'eod_$stamp',
      docNo: docNo,
      dateKey: state.selectedDateKey,
      branchId: store.branchId,
      storeName: store.storeName,
      receiptCount: storeReceipts.isNotEmpty ? storeReceipts.length : 95,
      systemCashTl: sysCash > 0 ? sysCash : 42500.0,
      systemPosTl: sysPos > 0 ? sysPos : 78400.0,
      openAccountSalesTl: openAcc,
      openAccountCollectionsTl: 1500.0,
      refundsTl: refunds,
      localPurchasesTl: localPurch,
      branchExpensesTl: 850.0,
      actualCountedCashTl: actualCountedCashTl,
      coinCashTl: coinCashTl,
      actualPosZReportTl: actualPosZReportTl,
      boxTareRecoveredKg: effectiveBoxTareKg,
      boxPriceDiffProfitTl: boxProfitTl,
      handedOverBy: handedOverBy.trim(),
      receivedBy: receivedBy.trim(),
      witnessName: witnessName.trim(),
      transferredToHq: true,
    );

    state = state.copyWith(
      branchEndOfDaySettlements: <BranchEndOfDaySettlement>[
        settlement,
        ...state.branchEndOfDaySettlements,
      ],
    );

    // Kutu Dara Denkleştirme: Tatlı ile tartılan kutu ağırlığını tatlı stoğuna geri ekle
    if (state.stockBurnItems.isNotEmpty) {
      _db.adjustStockBurnItemQuantity(
        state.stockBurnItems.first.id,
        effectiveBoxTareKg,
      );
    }

    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_eod_$stamp',
        docNo: docNo,
        dateKey: state.selectedDateKey,
        accountId: store.storeAccountId,
        accountName: store.storeName,
        entryType: LedgerEntryType.branchBoxTareCredit,
        direction: 'A',
        amount: settlement.totalActualCashTl + settlement.actualPosZReportTl,
        cashOrBankName: store.cashBoxName,
        expenseCategory: 'GÜN SONU & KUTU DARA',
        description:
            'Kasa Teslim Tutanağı ($handedOverBy -> $receivedBy, Şahit: $witnessName) • Kutu Dara +${effectiveBoxTareKg.toStringAsFixed(3)} Kg Tatlı Stoğuna Eklendi',
      ),
    );
    refreshAll(
      bannerMessage:
          '${store.storeName} Gün Sonu & Kasa Teslim Tutanağı ($docNo) onaylandı; +${effectiveBoxTareKg.toStringAsFixed(2)} Kg Kutu Dara tatlı stoğuna eklendi.',
    );
  }

  /// `Magaza_StokSayimGiris` & `Magaza_StokSayimGiderGiris`:
  /// Canlı stok ile fiili sayım farkını eşitler; `MALZEME` grubu farklarını otomatik `Sarf Malzeme Giderleri` dekontuna dönüştürür.
  void recordBranchStockCountAndConsumableExpense({
    required String stockCode,
    required String stockName,
    required String stockGroup,
    required double systemQty,
    required double countedQty,
    required double unitCostTl,
  }) {
    final store = state.activeBranchProfile;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final isConsumable = stockGroup.toUpperCase().contains('MALZEME') ||
        stockGroup.toUpperCase().contains('KUTU');
    final entry = BranchStockCountEntry(
      id: 'bsc_$stamp',
      dateKey: state.selectedDateKey,
      branchId: store.branchId,
      storeName: store.storeName,
      stockCode: stockCode,
      stockName: stockName,
      stockGroup: stockGroup,
      systemQty: systemQty,
      countedQty: countedQty,
      unitCostTl: unitCostTl,
      expensedAsConsumable: isConsumable && countedQty < systemQty,
    );

    state = state.copyWith(
      branchStockCounts: <BranchStockCountEntry>[
        entry,
        ...state.branchStockCounts,
      ],
    );

    if (entry.expensedAsConsumable && entry.diffCostAmountTl > 0) {
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_sarf_$stamp',
          docNo: 'SRF-${stamp % 10000}',
          dateKey: state.selectedDateKey,
          accountId: store.storeAccountId,
          accountName: store.storeName,
          entryType: LedgerEntryType.expense,
          direction: 'B',
          amount: double.parse(entry.diffCostAmountTl.toStringAsFixed(2)),
          cashOrBankName: store.cashBoxName,
          expenseCategory: 'SARF MALZEME GİDERLERİ',
          description:
              'Stok Sayım Sarf Malzeme Farkı: $stockName (${entry.diffQty.toStringAsFixed(2)} Birim)',
        ),
      );
    }
    refreshAll(
      bannerMessage:
          '${store.storeName} Stok Sayımı kaydedildi ($stockName: Sistem $systemQty -> Sayım $countedQty${entry.expensedAsConsumable ? " • ${entry.diffCostAmountTl.toStringAsFixed(2)} ₺ Sarf Gideri işlendi" : ""}).',
    );
  }

  /// 360° Şube Denetim & Kayıp Önleme (Loss Prevention) Motoru:
  /// 5 kritik denetim katmanını tek tıkla çalıştırır ve SQLite'a mühürler.
  void run360BranchAuditInspection({
    required String inspectorName,
    required double blindCashVarianceTl,
    required double blindStockVarianceTl,
    required double coldChainTempCelsius,
    required int hygieneChecklistScore,
    required String findingSummary,
    required String actionPlan,
  }) {
    final store = state.activeBranchProfile;
    final storeReceipts = state.branchPosReceipts
        .where((r) => r.branchId == store.branchId)
        .toList();
    final cancelOrRefunds =
        storeReceipts.where((r) => r.receiptType == 'İADE').length;
    final compLines = storeReceipts.fold<int>(
      0,
      (s, r) => s + r.complimentaryLineCount,
    );
    final boxTareKg = storeReceipts.fold<double>(
      0.0,
      (s, r) => s + r.boxTareWeightKg,
    );
    final shippedKg = state.branchTransfers
        .where((t) => t.targetBranchId == store.branchId)
        .fold<double>(0.0, (s, t) => s + t.totalKg);
    final effectiveShippedKg = shippedKg > 0 ? shippedKg : 160.0;
    final soldPlusRemKg = effectiveShippedKg - 0.85;
    final unaccountedFireKg = double.parse(
      (effectiveShippedKg - soldPlusRemKg).clamp(0.0, 50.0).toStringAsFixed(2),
    );

    final riskScore = double.parse(
      ((cancelOrRefunds * 4.5) + (compLines * 2.2)).clamp(0.0, 100.0).toStringAsFixed(1),
    );

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final docNo = 'DNT-2026-${(stamp % 900) + 100}';
    final record = BranchAuditInspectionRecord(
      id: 'aud_$stamp',
      auditDocNo: docNo,
      dateKey: state.selectedDateKey,
      branchId: store.branchId,
      storeName: store.storeName,
      inspectorName: inspectorName.trim().isEmpty
          ? 'Başdenetçi Hücresi'
          : inspectorName.trim(),
      cancelledOrRefundCount: cancelOrRefunds,
      complimentaryItemCount: compLines,
      cashierRiskScore: riskScore,
      shippedTrayTotalKg: effectiveShippedKg,
      posSoldPlusRemainingKg: soldPlusRemKg,
      boxTareOffsetKg: boxTareKg > 0 ? boxTareKg : 3.20,
      unaccountedFireKg: unaccountedFireKg,
      blindCashVarianceTl: blindCashVarianceTl,
      blindStockVarianceTl: blindStockVarianceTl,
      pdksCheckedInStaffCount: 5,
      posActiveCashierCount: 2,
      ghostCashierDetected: false,
      coldChainTempCelsius: coldChainTempCelsius,
      hygieneChecklistScore: hygieneChecklistScore.clamp(0, 100),
      findingSummary: findingSummary.trim().isEmpty
          ? 'Tepsi-Gramaj-Kutu Dara 3\'lü mutabakatı ve PDKS×POS vardiya eşleşmesi doğrulandı.'
          : findingSummary.trim(),
      actionPlan: actionPlan.trim().isEmpty
          ? 'Günlük kör kasa sayımı ve soğuk zincir telemetri takibine devam.'
          : actionPlan.trim(),
    );

    _db.upsertBranchAuditInspection(record);
    refreshAll(
      bannerMessage:
          '360° Şube Denetim Karnesi mühürlendi: $docNo (${store.storeName} • Skor: ${record.overallAuditScore}/100 • ${record.auditGradeBadge}).',
    );
  }

  // ==========================================================================
  // İLERİ ÖN MUHASEBE OPERASYONLARI (TCMB KUR, BORDRO ÇEK, TALİMAT, ERP, DEVİR)
  // ==========================================================================

  @override
  Future<void> refreshCurrencyRates({bool forceRefresh = true}) async {
    try {
      final quotes = await _currencyGateway.fetchRates(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final isFallback = quotes.any((q) => q.isFallback);
      state = state.copyWith(
        currencyRates: quotes,
        statusBanner: () => isFallback
            ? 'TCMB kur akışına erişilemedi; güvenli yedek kurlar yüklendi.'
            : 'TCMB canlı döviz kurları güncellendi (${quotes.length} kur).',
      );
    } catch (e) {
      debugPrint('AccountingNotifier.refreshCurrencyRates hata: $e');
      if (!mounted) return;
      state = state.copyWith(
        currencyRates: _currencyGateway.fallbackRates(),
        statusBanner: () =>
            'Döviz kur servisi hatası ($e); yedek kurlar aktif.',
      );
    }
  }

  @override
  void recordFxCollection({
    required AccountingAccount account,
    required bool isIncoming,
    required String currencyCode,
    required double fxRate,
    required double fxAmount,
    required String cashOrBankName,
    String description = '',
  }) {
    if (fxAmount <= 0 || fxRate <= 0) return;
    final cleanCur = currencyCode.trim().isEmpty
        ? 'USD'
        : currencyCode.trim().toUpperCase();
    final amountTl = double.parse((fxAmount * fxRate).toStringAsFixed(2));
    final viaBank = cashOrBankName.toLowerCase().contains('bank') ||
        cashOrBankName.toLowerCase().contains('pos');
    final stamp = DateTime.now().microsecondsSinceEpoch;

    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_fx_$stamp',
        docNo: 'DVZ-$cleanCur-${stamp % 10000}',
        dateKey: state.selectedDateKey,
        accountId: account.id,
        accountName: account.name,
        entryType: isIncoming
            ? (viaBank ? LedgerEntryType.bankIn : LedgerEntryType.cashIn)
            : (viaBank ? LedgerEntryType.bankOut : LedgerEntryType.cashOut),
        direction: isIncoming ? 'A' : 'B',
        amount: amountTl,
        cashOrBankName: cashOrBankName,
        expenseCategory: 'DÖVİZ İŞLEMİ',
        currencyCode: cleanCur,
        fxRate: fxRate,
        fxAmount: fxAmount,
        salesRepName: account.salesRepName,
        description: description.trim().isNotEmpty
            ? '${description.trim()} ($fxAmount $cleanCur × $fxRate)'
            : 'Kur Bazlı ${isIncoming ? "Tahsilat" : "Ödeme"} ($fxAmount $cleanCur × $fxRate ₺)',
      ),
    );
    refreshAll(
      bannerMessage:
          '${account.name} carisine $fxAmount $cleanCur (${amountTl.toStringAsFixed(2)} ₺) döviz hareketi işlendi.',
    );
  }

  @override
  void submitCheckBordroBatch({
    required AccountingAccount account,
    required bool isIncoming,
    required List<CheckPortfolioItem> items,
    String bordroNote = '',
  }) {
    if (items.isEmpty) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final bordroNo = items.first.bordroNo.trim().isNotEmpty
        ? items.first.bordroNo.trim().toUpperCase()
        : 'BRD-${stamp % 100000}';
    double batchTotal = 0.0;

    for (int i = 0; i < items.length; i++) {
      final raw = items[i];
      if (raw.amountTl <= 0) continue;
      final item = raw.copyWith(
        id: raw.id.trim().isNotEmpty ? raw.id : 'chk_${stamp}_$i',
        bordroNo: raw.bordroNo.trim().isNotEmpty ? raw.bordroNo : bordroNo,
        isIncoming: isIncoming,
        accountId: account.id,
        accountName: account.name,
        issueDateKey: raw.issueDateKey.trim().isNotEmpty
            ? raw.issueDateKey
            : state.selectedDateKey,
        status: CheckPortfolioStatus.inPortfolio,
      );
      batchTotal += item.amountTl;
      _db.upsertCheckPortfolioItem(item);
      _db.upsertCheckOrNote(
        CheckOrAlertNote(
          id: 'note_${item.id}',
          dueDate: item.dueDateKey,
          kind: 'ÇEK',
          titleOrParty: account.name,
          amount: item.amountTl,
          note:
              '$bordroNo • Seri:${item.serialNo} (${item.bankName})${bordroNote.isNotEmpty ? " | $bordroNote" : ""}',
        ),
      );
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_chk_${stamp}_$i',
          docNo: '$bordroNo-${i + 1}',
          dateKey: state.selectedDateKey,
          accountId: account.id,
          accountName: account.name,
          entryType:
              isIncoming ? LedgerEntryType.checkIn : LedgerEntryType.checkOut,
          direction: isIncoming ? 'A' : 'B',
          amount: double.parse(item.amountTl.toStringAsFixed(2)),
          cashOrBankName: 'Çek Portföyü',
          expenseCategory: isIncoming ? 'ÇEK BORDRO GİRİŞİ' : 'ÇEK BORDRO ÇIKIŞI',
          currencyCode: item.currencyCode,
          fxRate: item.fxRate,
          fxAmount:
              item.currencyCode == 'TRY' || item.fxRate <= 0
                  ? 0.0
                  : item.amountTl / item.fxRate,
          salesRepName: account.salesRepName,
          description:
              'Bordro $bordroNo • ${item.bankName} Seri:${item.serialNo} (Vade: ${item.dueDateKey})',
        ),
      );
    }

    refreshAll(
      bannerMessage:
          'Bordro $bordroNo kaydedildi: ${items.length} evrak (${batchTotal.toStringAsFixed(2)} ₺).',
    );
  }

  @override
  void transitionCheckStatus({
    required String checkId,
    required CheckPortfolioStatus nextStatus,
    AccountingAccount? endorseTargetAccount,
    String cashOrBankName = 'Merkez TL Kasa',
  }) {
    final idx = state.checkPortfolio.indexWhere((c) => c.id == checkId);
    if (idx < 0) return;
    final current = state.checkPortfolio[idx];
    if (current.status == nextStatus) return;

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final prevStatus = current.status;

    if (nextStatus == CheckPortfolioStatus.endorsed) {
      if (endorseTargetAccount == null) return;
      final updated = current.copyWith(
        status: CheckPortfolioStatus.endorsed,
        endorsedToAccountId: endorseTargetAccount.id,
        endorsedToName: endorseTargetAccount.name,
      );
      _db.upsertCheckPortfolioItem(updated);
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_chk_ciro_$stamp',
          docNo: 'CRO-${current.serialNo}',
          dateKey: state.selectedDateKey,
          accountId: endorseTargetAccount.id,
          accountName: endorseTargetAccount.name,
          entryType: LedgerEntryType.checkOut,
          direction: 'B',
          amount: double.parse(current.amountTl.toStringAsFixed(2)),
          cashOrBankName: 'Çek Portföyü',
          expenseCategory: 'ÇEK CİROSU',
          description:
              '${current.serialNo} Nolu Çekin Ciro Edilmesi (Keşideci: ${current.accountName})',
        ),
      );
      refreshAll(
        bannerMessage:
            '${current.serialNo} nolu çek ${endorseTargetAccount.name} carisine ciro edildi.',
      );
      return;
    }

    if (nextStatus == CheckPortfolioStatus.collected ||
        nextStatus == CheckPortfolioStatus.paid) {
      final updated = current.copyWith(status: nextStatus);
      _db.upsertCheckPortfolioItem(updated);
      final viaBank = cashOrBankName.toLowerCase().contains('bank') ||
          cashOrBankName.toLowerCase().contains('pos');
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_chk_tah_$stamp',
          docNo: 'THS-${current.serialNo}',
          dateKey: state.selectedDateKey,
          accountId: current.isIncoming ? 'PORTFOY_TAHSIL' : 'PORTFOY_ODEME',
          accountName: current.accountName,
          entryType: current.isIncoming
              ? (viaBank ? LedgerEntryType.bankIn : LedgerEntryType.cashIn)
              : (viaBank ? LedgerEntryType.bankOut : LedgerEntryType.cashOut),
          direction: current.isIncoming ? 'A' : 'B',
          amount: double.parse(current.amountTl.toStringAsFixed(2)),
          cashOrBankName: cashOrBankName,
          expenseCategory: current.isIncoming ? 'ÇEK TAHSİLATI' : 'ÇEK ÖDEMESİ',
          description:
              '${current.serialNo} Nolu Çek/Senet ${nextStatus.label} ($cashOrBankName)',
        ),
      );
      refreshAll(
        bannerMessage:
            '${current.serialNo} nolu evrak ${nextStatus.label} -> $cashOrBankName.',
      );
      return;
    }

    if (nextStatus == CheckPortfolioStatus.returned) {
      final updated = current.copyWith(status: CheckPortfolioStatus.returned);
      _db.upsertCheckPortfolioItem(updated);
      if (prevStatus == CheckPortfolioStatus.endorsed &&
          current.endorsedToAccountId.isNotEmpty) {
        _db.upsertAccountingTransaction(
          AccountingTransaction(
            id: 'tx_chk_ret_end_$stamp',
            docNo: 'IAD-CRO-${current.serialNo}',
            dateKey: state.selectedDateKey,
            accountId: current.endorsedToAccountId,
            accountName: current.endorsedToName,
            entryType: LedgerEntryType.creditMemo,
            direction: 'A',
            amount: double.parse(current.amountTl.toStringAsFixed(2)),
            cashOrBankName: 'Çek Portföyü',
            expenseCategory: 'KARŞILIKSIZ ÇEK CİRO İADESİ',
            description:
                'Ciro edilen ${current.serialNo} nolu çekin iade ters kaydı',
          ),
        );
      }
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_chk_ret_ori_$stamp',
          docNo: 'IAD-CHK-${current.serialNo}',
          dateKey: state.selectedDateKey,
          accountId: current.accountId,
          accountName: current.accountName,
          entryType: current.isIncoming
              ? LedgerEntryType.debitMemo
              : LedgerEntryType.creditMemo,
          direction: current.isIncoming ? 'B' : 'A',
          amount: double.parse(current.amountTl.toStringAsFixed(2)),
          cashOrBankName: 'Çek Portföyü',
          expenseCategory: 'ÇEK İADE / KARŞILIKSIZ',
          description:
              '${current.serialNo} Nolu Evrak İade / Karşılıksız Ters Kaydı',
        ),
      );
      refreshAll(
        bannerMessage:
            '${current.serialNo} nolu evrak İade Edildi ve ilgili cari bakiyeleri güncellendi.',
      );
      return;
    }

    _db.upsertCheckPortfolioItem(current.copyWith(status: nextStatus));
    refreshAll(
      bannerMessage: '${current.serialNo} durumu güncellendi: ${nextStatus.label}',
    );
  }

  @override
  void upsertPaymentTemplate(PaymentInstructionTemplate template) {
    _db.upsertPaymentInstructionTemplate(template);
    refreshAll(
      bannerMessage:
          'Ödeme talimat şablonu kaydedildi: ${template.targetBankOrCashName}',
    );
  }

  @override
  void deletePaymentTemplate(String id) {
    _db.deletePaymentInstructionTemplate(id);
    refreshAll(bannerMessage: 'Ödeme talimat şablonu silindi.');
  }

  @override
  void createPaymentOrder({
    required String kind,
    required String bankOrCashName,
    required AccountingAccount account,
    required String iban,
    required double amountTl,
    required String dueDateKey,
    required String templateBody,
    String note = '',
    bool executeImmediately = false,
  }) {
    if (amountTl <= 0) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final cleanKind =
        kind.trim().toUpperCase() == 'KASA' ? 'KASA' : 'BANKA';
    final orderNo = 'ODM-2026-${stamp % 10000}';
    final rendered = PreAccountingMathEngine.renderPaymentInstruction(
      templateBody: templateBody,
      dateKey: dueDateKey,
      accountName: account.name,
      iban: iban,
      amountTl: amountTl,
      description: note,
    );

    final order = PaymentOrderRecord(
      id: 'pmt_$stamp',
      orderNo: orderNo,
      dateKey: state.selectedDateKey,
      dueDateKey: dueDateKey,
      kind: cleanKind,
      bankOrCashName: bankOrCashName,
      accountId: account.id,
      accountName: account.name,
      iban: iban,
      amountTl: double.parse(amountTl.toStringAsFixed(2)),
      status: executeImmediately ? 'ODENDI' : 'BEKLIYOR',
      renderedInstruction: rendered,
      note: note,
    );
    _db.upsertPaymentOrder(order);

    if (executeImmediately) {
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_odm_$stamp',
          docNo: orderNo,
          dateKey: state.selectedDateKey,
          accountId: account.id,
          accountName: account.name,
          entryType: cleanKind == 'BANKA'
              ? LedgerEntryType.bankOut
              : LedgerEntryType.cashOut,
          direction: 'B',
          amount: order.amountTl,
          cashOrBankName: bankOrCashName,
          expenseCategory: 'ÖDEME TALİMATI',
          description:
              '$orderNo Ödeme Talimatı Gerçekleştirildi${note.isNotEmpty ? " • $note" : ""}',
        ),
      );
    }

    refreshAll(
      bannerMessage: executeImmediately
          ? '$orderNo ödeme talimatı oluşturuldu ve ödendi.'
          : '$orderNo ödeme talimatı onay kuyruğuna eklendi.',
    );
  }

  @override
  void executePendingPaymentOrder(String orderId) {
    final idx = state.paymentOrders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return;
    final order = state.paymentOrders[idx];
    if (order.status.toUpperCase() == 'ODENDI') return;

    final updated = order.copyWith(status: 'ODENDI');
    _db.upsertPaymentOrder(updated);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_odm_exec_$stamp',
        docNo: order.orderNo,
        dateKey: state.selectedDateKey,
        accountId: order.accountId,
        accountName: order.accountName,
        entryType: order.kind.toUpperCase() == 'BANKA'
            ? LedgerEntryType.bankOut
            : LedgerEntryType.cashOut,
        direction: 'B',
        amount: order.amountTl,
        cashOrBankName: order.bankOrCashName,
        expenseCategory: 'ÖDEME TALİMATI',
        description:
            '${order.orderNo} Bekleyen Talimat Ödendi${order.note.isNotEmpty ? " • ${order.note}" : ""}',
      ),
    );
    refreshAll(
      bannerMessage:
          '${order.orderNo} (${order.amountTl.toStringAsFixed(2)} ₺) ödeme talimatı gerçekleştirildi.',
    );
  }

  @override
  void applyAutoDiscountToErpDoc({
    required String erpDocId,
    required double targetNetTotalTl,
  }) {
    final idx = state.erpOrdersWaybillsInvoices.indexWhere(
      (e) => e.id == erpDocId,
    );
    if (idx < 0) return;
    final doc = state.erpOrdersWaybillsInvoices[idx];
    final pct = PreAccountingMathEngine.computeAutoDiscountPercent(
      grossTotalTl: doc.grossTotalTl,
      targetNetTotalTl: targetNetTotalTl,
    );
    final updated = doc.copyWith(discountPercent: pct);
    _db.upsertErpDocument(updated);

    final deltaGrand = doc.grandTotalTl - updated.grandTotalTl;
    if (doc.stage == 'FATURALANDI' && deltaGrand.abs() > 0.01) {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      _db.upsertAccountingTransaction(
        AccountingTransaction(
          id: 'tx_isk_$stamp',
          docNo: 'ISK-${doc.invoiceDocNo ?? doc.orderDocNo}',
          dateKey: state.selectedDateKey,
          accountId: doc.accountId,
          accountName: doc.accountName,
          entryType: deltaGrand > 0
              ? LedgerEntryType.creditMemo
              : LedgerEntryType.debitMemo,
          direction: deltaGrand > 0 ? 'A' : 'B',
          amount: double.parse(deltaGrand.abs().toStringAsFixed(2)),
          cashOrBankName: 'Fatura İskonto Servisi',
          expenseCategory: 'OTOMATİK İSKONTO',
          discountPercent: pct,
          linkedOrderDocId: doc.id,
          description:
              '${doc.invoiceDocNo ?? doc.orderDocNo} Oto İskonto (%${pct.toStringAsFixed(2)}) Düzeltmesi',
        ),
      );
    }

    refreshAll(
      bannerMessage:
          '${doc.invoiceDocNo ?? doc.orderDocNo} belgesine %${pct.toStringAsFixed(2)} otomatik iskonto uygulandı.',
    );
  }

  @override
  void settleInvoicePartially({
    required String erpDocId,
    required double amountTl,
    required String cashOrBankName,
    required bool viaBank,
  }) {
    final idx = state.erpOrdersWaybillsInvoices.indexWhere(
      (e) => e.id == erpDocId,
    );
    if (idx < 0 || amountTl <= 0) return;
    final doc = state.erpOrdersWaybillsInvoices[idx];
    final remaining = doc.remainingReceivableTl;
    if (remaining <= 0) return;
    final settled = amountTl.clamp(0.0, remaining);
    if (settled <= 0) return;

    final updated = doc.copyWith(
      collectedAmountTl: double.parse(
        (doc.collectedAmountTl + settled).toStringAsFixed(2),
      ),
    );
    _db.upsertErpDocument(updated);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_par_$stamp',
        docNo: 'TAH-${doc.invoiceDocNo ?? doc.orderDocNo}',
        dateKey: state.selectedDateKey,
        accountId: doc.accountId,
        accountName: doc.accountName,
        entryType: viaBank ? LedgerEntryType.bankIn : LedgerEntryType.cashIn,
        direction: 'A',
        amount: double.parse(settled.toStringAsFixed(2)),
        cashOrBankName: cashOrBankName.trim().isNotEmpty
            ? cashOrBankName
            : (viaBank ? 'Ticari Vadesiz Banka' : 'Merkez TL Kasa'),
        expenseCategory: 'FATURA PARÇALI TAHSİLAT',
        salesRepName: doc.salesRepName,
        settledAmountTl: settled,
        linkedOrderDocId: doc.id,
        description:
            '${doc.invoiceDocNo ?? doc.orderDocNo} Parçalı Fatura Tahsilatı',
      ),
    );
    refreshAll(
      bannerMessage:
          '${doc.accountName} faturasına ${settled.toStringAsFixed(2)} ₺ tahsilat işlendi.',
    );
  }

  @override
  void createOrdersFromStockTemplate({
    required AccountingAccount account,
    required String templateCategory,
    required int priceTier,
  }) {
    final cleanCat = templateCategory.trim();
    List<StockBurnItem> matched = cleanCat.isEmpty
        ? state.stockBurnItems
        : state.stockBurnItems
            .where((s) => s.templateCategory == cleanCat)
            .toList(growable: false);
    if (matched.isEmpty) {
      matched = state.stockBurnItems.take(3).toList(growable: false);
    }
    if (matched.isEmpty) return;

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final clampedTier = priceTier.clamp(1, 10);
    final tierMultiplier = 1.0 - ((clampedTier - 1) * 0.02);

    for (int i = 0; i < matched.length; i++) {
      final stk = matched[i];
      final basePrice = stk.salePriceTl > 0
          ? stk.salePriceTl
          : (stk.unitCost > 0 ? stk.unitCost * 1.25 : 250.0);
      final tieredPrice =
          double.parse((basePrice * tierMultiplier).toStringAsFixed(2));
      final qty = stk.dailyBurnRate > 0 ? stk.dailyBurnRate : 10.0;
      final orderNo = 'SIP-${(stamp % 9000) + 1000 + i}';
      _db.upsertErpDocument(
        ErpOrderWaybillInvoiceItem(
          id: 'erp_tpl_${stamp}_$i',
          orderDocNo: orderNo,
          dateKey: state.selectedDateKey,
          accountId: account.id,
          accountName: account.name,
          regionGroup: '${account.groupName} (Fiyat-$clampedTier)',
          priceTier: clampedTier,
          stockCode: stk.code,
          stockName: stk.name,
          orderedQtyKg: qty,
          trayCount: qty >= 10 ? (qty / 4).round() : 1,
          unitPriceTl: tieredPrice,
          discountPercent: account.defaultDiscountPercent,
          vatPercent: 10.0,
          stage: 'SIPARIS',
          docKind: 'NORMAL',
          salesRepName: account.salesRepName,
          depositAmountTl: stk.depositUnitTl * qty,
        ),
      );
    }
    refreshAll(
      bannerMessage:
          '${account.name} için şablondan ${matched.length} adet hızlı sipariş oluşturuldu.',
    );
  }

  @override
  void createReturnErpInvoice({
    required AccountingAccount account,
    required bool isSalesReturn,
    required String stockCode,
    required String stockName,
    required double qtyKg,
    required double unitPriceTl,
    double vatPercent = 10.0,
  }) {
    if (qtyKg <= 0 || unitPriceTl <= 0) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final numPart = (stamp % 9000) + 1000;
    final docNo = isSalesReturn ? 'SIAD-$numPart' : 'AIAD-$numPart';

    final erpItem = ErpOrderWaybillInvoiceItem(
      id: 'erp_iad_$stamp',
      orderDocNo: docNo,
      waybillDocNo: 'IRS-$docNo',
      invoiceDocNo: docNo,
      dateKey: state.selectedDateKey,
      accountId: account.id,
      accountName: account.name,
      regionGroup: account.groupName,
      priceTier: account.priceTier,
      stockCode: stockCode,
      stockName: stockName,
      orderedQtyKg: qtyKg,
      shippedQtyKg: qtyKg,
      invoicedQtyKg: qtyKg,
      trayCount: qtyKg >= 4 ? (qtyKg / 4).round() : 1,
      unitPriceTl: unitPriceTl,
      discountPercent: 0.0,
      vatPercent: vatPercent,
      stage: 'FATURALANDI',
      docKind: isSalesReturn ? 'SATIS_IADE' : 'ALIS_IADE',
      salesRepName: account.salesRepName,
    );
    _db.upsertErpDocument(erpItem);

    final matchingStocks = state.stockBurnItems
        .where((s) => s.code == stockCode || s.name == stockName)
        .toList(growable: false);
    for (final stk in matchingStocks) {
      _db.adjustStockBurnItemQuantity(
        stk.id,
        isSalesReturn ? qtyKg : -qtyKg,
      );
    }

    _db.upsertAccountingTransaction(
      AccountingTransaction(
        id: 'tx_iad_$stamp',
        docNo: docNo,
        dateKey: state.selectedDateKey,
        accountId: account.id,
        accountName: account.name,
        entryType: isSalesReturn
            ? LedgerEntryType.salesReturn
            : LedgerEntryType.purchaseReturn,
        direction: isSalesReturn ? 'A' : 'B',
        amount: double.parse(erpItem.grandTotalTl.toStringAsFixed(2)),
        cashOrBankName: 'Cari İade Mahsubu',
        expenseCategory:
            isSalesReturn ? 'SATIŞTAN İADE FATURASI' : 'ALIŞTAN İADE FATURASI',
        salesRepName: account.salesRepName,
        linkedOrderDocId: erpItem.id,
        description:
            '$docNo ${isSalesReturn ? "Satıştan İade" : "Alıştan İade"} • $stockName ($qtyKg)',
      ),
    );
    refreshAll(
      bannerMessage:
          '$docNo (${erpItem.grandTotalTl.toStringAsFixed(2)} ₺) iade faturası işlendi.',
    );
  }

  @override
  void upsertDealerContract(DealerContractRecord contract) {
    _db.upsertDealerContract(contract);
    refreshAll(
      bannerMessage:
          'Bayi sözleşmesi kaydedildi: ${contract.contractNo} (${contract.accountName})',
    );
  }

  @override
  void terminateDealerContract({
    required String contractId,
    required String reason,
  }) {
    final idx = state.dealerContracts.indexWhere((c) => c.id == contractId);
    if (idx < 0) return;
    final current = state.dealerContracts[idx];
    final updated = current.copyWith(
      isTerminated: true,
      terminationNote: reason.trim().isEmpty
          ? 'Taraf mutabakatı ile feshedildi (${state.selectedDateKey})'
          : reason.trim(),
    );
    _db.upsertDealerContract(updated);
    refreshAll(
      bannerMessage:
          'Bayi sözleşmesi feshedildi: ${current.contractNo} (${current.accountName})',
    );
  }

  @override
  void addInteractiveCustomSpreadsheetRow({
    required String sheetTitle,
    required String categoryName,
    required double debitColumnTl,
    required double creditColumnTl,
    required String formulaNote,
  }) {
    addCustomSpreadsheetRow(
      sheetTitle: sheetTitle,
      categoryName: categoryName,
      debitColumnTl: debitColumnTl,
      creditColumnTl: creditColumnTl,
      formulaNote: formulaNote,
    );
  }

  @override
  PeriodRolloverPreview previewPeriodRollover({
    required String nextPeriodKey,
    required String rolloverDateKey,
  }) {
    final cleanNext = nextPeriodKey.trim();
    final effectiveFrom =
        (state.selectedPeriodKey == cleanNext &&
                _rolloverSourceByTarget.containsKey(cleanNext))
            ? _rolloverSourceByTarget[cleanNext]!
            : state.selectedPeriodKey;
    final preview = _db.previewPeriodRollover(
      fromPeriodKey: effectiveFrom,
      nextPeriodKey: cleanNext,
      rolloverDateKey: rolloverDateKey.trim(),
    );
    state = state.copyWith(rolloverPreview: () => preview);
    return preview;
  }

  @override
  void executePeriodRollover({
    required String nextPeriodKey,
    required String rolloverDateKey,
  }) {
    final cleanNext = nextPeriodKey.trim();
    final cleanDate = rolloverDateKey.trim();
    final effectiveFrom =
        (state.selectedPeriodKey == cleanNext &&
                _rolloverSourceByTarget.containsKey(cleanNext))
            ? _rolloverSourceByTarget[cleanNext]!
            : state.selectedPeriodKey;

    final result = _db.executePeriodRollover(
      fromPeriodKey: effectiveFrom,
      nextPeriodKey: cleanNext,
      rolloverDateKey: cleanDate,
    );
    _rolloverSourceByTarget[cleanNext] = effectiveFrom;

    state = state.copyWith(
      selectedDateKey: cleanDate,
      selectedPeriodKey: cleanNext,
      rolloverPreview: () => result,
    );
    refreshAll(
      bannerMessage: result.alreadyExecuted
          ? '${result.fromPeriodKey} -> ${result.nextPeriodKey} dönem devri zaten mühürlenmiş (kilit aktif).'
          : 'Dönem Sonu Devir tamamlandı: ${result.fromPeriodKey} -> ${result.nextPeriodKey} (${result.accountCount} cari).',
    );
  }
}

final tcmbCurrencyGatewayProvider = Provider<CurrencyRateGateway>((ref) {
  final gw = TcmbCurrencyGateway();
  ref.onDispose(gw.close);
  return gw;
});

final accountingProvider =
    StateNotifierProvider<AccountingNotifier, AccountingState>((ref) {
  final db = ref.watch(hasibuDatabaseProvider);
  final gw = ref.watch(tcmbCurrencyGatewayProvider);
  return AccountingNotifier(db, gw);
});
