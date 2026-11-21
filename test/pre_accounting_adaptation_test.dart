import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hasibu/core/database/hasibu_accounting_dao.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/core/services/tcmb_currency_gateway.dart';
import 'package:hasibu/features/pdks/domain/accounting_models.dart';
import 'package:hasibu/features/pdks/domain/pre_accounting_advanced_contracts.dart';
import 'package:hasibu/features/pdks/presentation/providers/accounting_providers.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/features/pdks/presentation/screens/hasibu_accounting_views.dart';
import 'package:hasibu/features/pdks/presentation/screens/pre_accounting_analytics_and_devir_views.dart';
import 'package:hasibu/features/pdks/presentation/screens/pre_accounting_finance_tools_views.dart';

class _FakeCurrencyRateGateway implements CurrencyRateGateway {
  @override
  List<CurrencyRateQuote> fallbackRates() => const <CurrencyRateQuote>[
        CurrencyRateQuote(
          code: 'USD',
          label: 'ABD Doları',
          buyingTl: 34.10,
          sellingTl: 34.25,
          updatedAtIso: '2026-10-21T10:00:00',
          isFallback: false,
        ),
        CurrencyRateQuote(
          code: 'EUR',
          label: 'Euro',
          buyingTl: 37.05,
          sellingTl: 37.22,
          updatedAtIso: '2026-10-21T10:00:00',
          isFallback: false,
        ),
        CurrencyRateQuote(
          code: 'GBP',
          label: 'İngiliz Sterlini',
          buyingTl: 44.30,
          sellingTl: 44.55,
          updatedAtIso: '2026-10-21T10:00:00',
          isFallback: false,
        ),
      ];

  @override
  Future<List<CurrencyRateQuote>> fetchRates({
    bool forceRefresh = false,
  }) async {
    return fallbackRates();
  }
}

class _OfflineRejectAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Offline test ortamı',
    );
  }
}

void main() {
  group('Hasibu Ön Muhasebe İleri Matematik ve Kur Motoru', () {
    test('Ağırlıklı ortalama vade ve sıfır tutar bölme koruması doğru çalışır', () {
      final summary = PreAccountingMathEngine.computeWeightedMaturity(
        baseDateKey: '2026-10-01',
        rows: const <MaturityCalcRow>[
          MaturityCalcRow(
            id: 'r1',
            label: '1. Çek',
            dueDateKey: '2026-10-11',
            amountTl: 10000.0,
          ),
          MaturityCalcRow(
            id: 'r2',
            label: '2. Çek',
            dueDateKey: '2026-10-31',
            amountTl: 30000.0,
          ),
        ],
      );

      // (10000*10 + 30000*30) / 40000 = 25.0 gün -> 2026-10-26
      expect(summary.totalAmountTl, closeTo(40000.0, 0.01));
      expect(summary.weightedDays, closeTo(25.0, 0.01));
      expect(summary.averageDueDateKey, '2026-10-26');

      final zeroSummary = PreAccountingMathEngine.computeWeightedMaturity(
        baseDateKey: '2026-10-01',
        rows: const <MaturityCalcRow>[
          MaturityCalcRow(
            id: 'z1',
            label: 'Sıfır Satır',
            dueDateKey: '2026-10-25',
            amountTl: 0.0,
          ),
        ],
      );
      expect(zeroSummary.totalAmountTl, 0.0);
      expect(zeroSummary.weightedDays, 0.0);
      expect(zeroSummary.averageDueDateKey, '2026-10-01');
    });

    test('Otomatik iskonto, yazıyla Türkçe tutar ve talimat şablonu render edilir',
        () {
      final pct = PreAccountingMathEngine.computeAutoDiscountPercent(
        grossTotalTl: 10000.0,
        targetNetTotalTl: 8500.0,
      );
      expect(pct, closeTo(15.0, 0.001));

      final words = PreAccountingMathEngine.amountToTurkishWords(125450.75);
      expect(
        words,
        '#Yalnız Yüz Yirmi Beş Bin Dört Yüz Elli Türk Lirası Yetmiş Beş Kuruştur#',
      );

      final rendered = PreAccountingMathEngine.renderPaymentInstruction(
        templateBody:
            'Tarih:@TalimatTarihi Unvan:@Unvan IBAN:@IBAN Tutar:@Tutar (@YaziylaTutar) Not:@Aciklama',
        dateKey: '2026-10-25',
        accountName: 'TRAKYA UN A.Ş.',
        iban: 'TR330006',
        amountTl: 125000.0,
        description: 'Un alımı',
      );
      expect(rendered, contains('2026-10-25'));
      expect(rendered, contains('TRAKYA UN A.Ş.'));
      expect(rendered, contains('TR330006'));
      expect(
        rendered,
        contains('#Yalnız Yüz Yirmi Beş Bin Türk Lirası\'dır#'),
      );
      expect(rendered, contains('Un alımı'));
    });

    test('TcmbCurrencyGateway XML parse ve ağ hatasında deterministik fallback çalışır',
        () async {
      const sampleXml = '''
<Tarih_Date Date="10/21/2026">
  <Currency CurrencyCode="USD">
    <ForexBuying>34.1000</ForexBuying>
    <ForexSelling>34.1600</ForexSelling>
    <BanknoteBuying>34.1500</BanknoteBuying>
    <BanknoteSelling>34.2800</BanknoteSelling>
  </Currency>
  <Currency CurrencyCode="EUR">
    <ForexBuying>37.0500</ForexBuying>
    <ForexSelling>37.1900</ForexSelling>
    <BanknoteBuying></BanknoteBuying>
    <BanknoteSelling></BanknoteSelling>
  </Currency>
  <Currency CurrencyCode="GBP">
    <ForexBuying>44.3000</ForexBuying>
    <ForexSelling>44.5200</ForexSelling>
    <BanknoteBuying>44.3500</BanknoteBuying>
    <BanknoteSelling>44.6000</BanknoteSelling>
  </Currency>
</Tarih_Date>
''';
      final parsed = TcmbCurrencyGateway.parseTcmbXml(
        sampleXml,
        now: DateTime(2026, 10, 21, 12, 0),
      );
      expect(parsed.length, 3);
      final usd = parsed.firstWhere((q) => q.code == 'USD');
      final eur = parsed.firstWhere((q) => q.code == 'EUR');
      expect(usd.buyingTl, closeTo(34.15, 0.001));
      expect(usd.sellingTl, closeTo(34.28, 0.001));
      expect(usd.isFallback, isFalse);
      expect(eur.buyingTl, closeTo(37.05, 0.001));
      expect(eur.sellingTl, closeTo(37.19, 0.001));

      final offlineDio = Dio()..httpClientAdapter = _OfflineRejectAdapter();
      final gw = TcmbCurrencyGateway(dio: offlineDio);
      addTearDown(gw.close);

      final fallback = await gw.fetchRates(forceRefresh: true);
      expect(fallback.length, 3);
      expect(fallback.every((q) => q.isFallback), isTrue);
    });
  });

  group('Çek Bordrosu, Kümülatif Ekstre, SQLite Kalıcılık ve Dönem Devri', () {
    test('Çoklu çek bordrosu ve Portföy->Ciro->Tahsil/İade bakiye etkisi doğrudur',
        () {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
      final notifier = AccountingNotifier(db, _FakeCurrencyRateGateway());
      addTearDown(notifier.dispose);

      notifier.switchToCleanZeroDatabase();
      notifier.addQuickAccount(
        code: 'MUS-01',
        name: 'DENİZ MARKET',
        type: AccountingAccountType.customer,
        groupName: 'Müşteri',
        phone: '02320000001',
        creditLimitTl: 500000.0,
      );
      notifier.addQuickAccount(
        code: 'TED-01',
        name: 'ANADOLU UN',
        type: AccountingAccountType.supplier,
        groupName: 'Tedarikçi',
        phone: '03120000002',
      );

      final accounts = notifier.state.accounts;
      final customer = accounts.firstWhere((a) => a.code == 'MUS-01');
      final supplier = accounts.firstWhere((a) => a.code == 'TED-01');

      notifier.submitCheckBordroBatch(
        account: customer,
        isIncoming: true,
        bordroNote: '2li müşteri çek bordrosu',
        items: const <CheckPortfolioItem>[
          CheckPortfolioItem(
            id: 'c_batch_1',
            bordroNo: 'BRD-900',
            isIncoming: true,
            accountId: '',
            accountName: '',
            bankName: 'İş Bankası',
            serialNo: 'SERI-101',
            issueDateKey: '2026-10-20',
            dueDateKey: '2026-11-10',
            amountTl: 50000.0,
          ),
          CheckPortfolioItem(
            id: 'c_batch_2',
            bordroNo: 'BRD-900',
            isIncoming: true,
            accountId: '',
            accountName: '',
            bankName: 'Garanti',
            serialNo: 'SERI-102',
            issueDateKey: '2026-10-20',
            dueDateKey: '2026-11-25',
            amountTl: 30000.0,
          ),
        ],
      );

      var custAfterBordro =
          notifier.state.accounts.firstWhere((a) => a.id == customer.id);
      expect(custAfterBordro.creditTotal, closeTo(80000.0, 0.01));
      expect(notifier.state.checkPortfolio.length, 2);

      // 1. çeki tedarikçiye ciro et -> tedarikçi borcu (+50.000) artmalı
      notifier.transitionCheckStatus(
        checkId: 'c_batch_1',
        nextStatus: CheckPortfolioStatus.endorsed,
        endorseTargetAccount: supplier,
      );
      var suppAfterEndorse =
          notifier.state.accounts.firstWhere((a) => a.id == supplier.id);
      expect(suppAfterEndorse.debitTotal, closeTo(50000.0, 0.01));

      // 2. çeki bankaya tahsil et -> müşterinin bakiyesi ikinci kez değişmemeli,
      // banka tahsil hareketi PORTFOY_TAHSIL üzerinden işlenmeli
      notifier.transitionCheckStatus(
        checkId: 'c_batch_2',
        nextStatus: CheckPortfolioStatus.collected,
        cashOrBankName: 'Ticari Vadesiz Banka',
      );
      final custAfterCollect =
          notifier.state.accounts.firstWhere((a) => a.id == customer.id);
      expect(custAfterCollect.creditTotal, closeTo(80000.0, 0.01));
      expect(
        notifier.state.transactions.any(
          (t) =>
              t.accountId == 'PORTFOY_TAHSIL' &&
              t.entryType == LedgerEntryType.bankIn &&
              t.amount == 30000.0,
        ),
        isTrue,
      );

      // Ciro edilen 1. çeki karşılıksız/iade yap -> her iki caride ters kayıt
      notifier.transitionCheckStatus(
        checkId: 'c_batch_1',
        nextStatus: CheckPortfolioStatus.returned,
      );
      final suppAfterReturn =
          notifier.state.accounts.firstWhere((a) => a.id == supplier.id);
      final custAfterReturn =
          notifier.state.accounts.firstWhere((a) => a.id == customer.id);
      expect(suppAfterReturn.netBalance, closeTo(0.0, 0.01));
      expect(custAfterReturn.debitTotal, closeTo(50000.0, 0.01));
      expect(custAfterReturn.netBalance, closeTo(30000.0, 0.01));
    });

    test('Cari DEVREDEN BAKİYE kümülatif ekstresi ve Net Durum özeti doğru hesaplanır',
        () {
      const acc = AccountingAccount(
        id: 'acc_1',
        code: 'C-01',
        name: 'ÖRNEK BAYİ A.Ş.',
        type: AccountingAccountType.customer,
        trayBalance: 10,
      );
      const txs = <AccountingTransaction>[
        AccountingTransaction(
          id: 't0',
          docNo: 'FAT-01',
          dateKey: '2026-09-15',
          accountId: 'acc_1',
          accountName: 'ÖRNEK BAYİ A.Ş.',
          entryType: LedgerEntryType.salesInvoice,
          direction: 'B',
          amount: 10000.0,
          cashOrBankName: 'Fatura',
        ),
        AccountingTransaction(
          id: 't1',
          docNo: 'TAH-01',
          dateKey: '2026-10-05',
          accountId: 'acc_1',
          accountName: 'ÖRNEK BAYİ A.Ş.',
          entryType: LedgerEntryType.cashIn,
          direction: 'A',
          amount: 4000.0,
          cashOrBankName: 'Merkez TL Kasa',
        ),
      ];

      final ledger = PreAccountingMathEngine.buildCumulativeLedger(
        transactions: txs,
        accountId: 'acc_1',
        startDateKey: '2026-10-01',
        endDateKey: '2026-10-31',
      );
      expect(ledger.openingBalanceTl, closeTo(-10000.0, 0.01));
      expect(ledger.rows.length, 1);
      expect(ledger.rows.first.runningBalanceTl, closeTo(-6000.0, 0.01));

      final netStatus = PreAccountingMathEngine.computeCariNetStatus(
        account: acc,
        transactions: txs,
        erpDocs: const <ErpOrderWaybillInvoiceItem>[
          ErpOrderWaybillInvoiceItem(
            id: 'erp_o1',
            orderDocNo: 'SIP-1',
            dateKey: '2026-10-12',
            accountId: 'acc_1',
            accountName: 'ÖRNEK BAYİ A.Ş.',
            regionGroup: 'Merkez',
            priceTier: 1,
            stockCode: 'S1',
            stockName: 'Ürün',
            orderedQtyKg: 10.0,
            unitPriceTl: 100.0,
            vatPercent: 0.0,
            stage: 'SIPARIS',
          ),
        ],
        checks: const <CheckPortfolioItem>[
          CheckPortfolioItem(
            id: 'ck1',
            bordroNo: 'B1',
            isIncoming: true,
            accountId: 'acc_1',
            accountName: 'ÖRNEK BAYİ A.Ş.',
            bankName: 'Banka',
            serialNo: 'S-1',
            issueDateKey: '2026-10-01',
            dueDateKey: '2026-11-01',
            amountTl: 2500.0,
            status: CheckPortfolioStatus.inPortfolio,
          ),
        ],
        stocks: const <StockBurnItem>[
          StockBurnItem(
            id: 'st1',
            code: 'S1',
            name: 'Stok',
            unit: 'KG',
            currentQty: 50,
            dailyBurnRate: 5,
            unitCost: 100,
            depositUnitTl: 200.0,
          ),
        ],
      );
      expect(netStatus.ledgerClosingBalanceTl, closeTo(-6000.0, 0.01));
      expect(netStatus.openOrderExposureTl, closeTo(1000.0, 0.01));
      expect(netStatus.portfolioCheckExposureTl, closeTo(2500.0, 0.01));
      expect(netStatus.depositExposureTl, closeTo(2000.0, 0.01));
      // -6000 - 1000 + 2500 - 2000 = -6500
      expect(netStatus.consolidatedNetPositionTl, closeTo(-6500.0, 0.01));
    });

    test('ERP, reçete, özel tablo, ödeme emri ve bayi sözleşmeleri SQLite kalıcılığı korunur',
        () {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
      final notifier1 = AccountingNotifier(db, _FakeCurrencyRateGateway());
      addTearDown(notifier1.dispose);

      final customer = notifier1.state.accounts.firstWhere(
        (a) => a.type == AccountingAccountType.customer,
      );

      notifier1.createErpOrderOrInvoice(
        account: customer,
        regionGroup: 'Test Bölgesi',
        priceTier: 2,
        stockCode: 'TST-01',
        stockName: 'ÖZEL FISTIKLI BAKLAVA',
        orderedQtyKg: 50.0,
        trayCount: 12,
        unitPriceTl: 600.0,
        initialStage: 'FATURALANDI',
      );
      final createdDoc = notifier1.state.erpOrdersWaybillsInvoices.firstWhere(
        (d) => d.stockCode == 'TST-01',
      );
      notifier1.applyAutoDiscountToErpDoc(
        erpDocId: createdDoc.id,
        targetNetTotalTl: 27000.0,
      );
      notifier1.settleInvoicePartially(
        erpDocId: createdDoc.id,
        amountTl: 10000.0,
        cashOrBankName: 'Merkez TL Kasa',
        viaBank: false,
      );

      final recipe = notifier1.state.productionRecipes.first;
      final batchesBefore = recipe.producedBatchesToday;
      notifier1.executeProductionRecipeBatch(recipe.id, batchCount: 2);

      notifier1.addInteractiveCustomSpreadsheetRow(
        sheetTitle: 'KALICILIK ANALİZ TABLOSU',
        categoryName: 'Denetim',
        debitColumnTl: 12000.0,
        creditColumnTl: 18500.0,
        formulaNote: '=SUM(Kasa)',
      );

      notifier1.createPaymentOrder(
        kind: 'BANKA',
        bankOrCashName: 'Ticari Vadesiz Banka',
        account: customer,
        iban: 'TR1100010002',
        amountTl: 4200.0,
        dueDateKey: '2026-10-30',
        templateBody: '@Unvan hesabına @Tutar (@YaziylaTutar)',
        note: 'Kalıcılık talimatı',
      );

      notifier1.upsertDealerContract(
        DealerContractRecord(
          id: 'dlr_test_1',
          contractNo: 'SZL-TEST-99',
          dateKey: '2026-10-21',
          durationMonths: 12,
          collateralAmountTl: 150000.0,
          collateralType: 'Teminat Mektubu',
          accountId: customer.id,
          accountName: customer.name,
          regionName: 'Ege',
          priceTier: 2,
          dealerMarginPercent: 12.0,
        ),
      );

      notifier1.createOrdersFromStockTemplate(
        account: customer,
        templateCategory: 'GUNLUK_SEVK',
        priceTier: 2,
      );
      notifier1.createReturnErpInvoice(
        account: customer,
        isSalesReturn: true,
        stockCode: 'IAD-01',
        stockName: 'İADE ÜRÜN',
        qtyKg: 5.0,
        unitPriceTl: 400.0,
      );

      // Yeni bir Notifier örneği oluşturulduğunda tüm veriler SQLite'tan gelmeli
      final notifier2 = AccountingNotifier(db, _FakeCurrencyRateGateway());
      addTearDown(notifier2.dispose);

      final reloadedDoc = notifier2.state.erpOrdersWaybillsInvoices.firstWhere(
        (d) => d.id == createdDoc.id,
      );
      expect(reloadedDoc.discountPercent, closeTo(10.0, 0.01));
      expect(reloadedDoc.collectedAmountTl, closeTo(10000.0, 0.01));
      expect(
        notifier2.state.productionRecipes
            .firstWhere((r) => r.id == recipe.id)
            .producedBatchesToday,
        batchesBefore + 2,
      );
      expect(
        notifier2.state.customSpreadsheets
            .any((s) => s.sheetTitle == 'KALICILIK ANALİZ TABLOSU'),
        isTrue,
      );
      expect(
        notifier2.state.paymentOrders.any((p) => p.note == 'Kalıcılık talimatı'),
        isTrue,
      );
      expect(
        notifier2.state.dealerContracts.any((c) => c.id == 'dlr_test_1'),
        isTrue,
      );
      expect(
        notifier2.state.erpOrdersWaybillsInvoices
            .any((d) => d.docKind == 'SATIS_IADE' && d.stockCode == 'IAD-01'),
        isTrue,
      );
    });

    test('Atomik ve idempotent Dönem Sonu Devir bakiyeleri korur ve çift çalışmayı engeller',
        () {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);
      final notifier = AccountingNotifier(db, _FakeCurrencyRateGateway());
      addTearDown(notifier.dispose);

      final preRolloverBalances = <String, double>{
        for (final acc in notifier.state.accounts) acc.id: acc.netBalance,
      };
      final nonZeroCountBefore = notifier.state.accounts
          .where((a) => a.netBalance.abs() >= 0.005)
          .length;

      notifier.executePeriodRollover(
        nextPeriodKey: '2027-01',
        rolloverDateKey: '2027-01-01',
      );
      expect(notifier.state.selectedPeriodKey, '2027-01');
      expect(notifier.state.selectedDateKey, '2027-01-01');

      final rolloverTxCountFirst = notifier.state.transactions
          .where((t) => t.expenseCategory == 'DÖNEM DEVİR')
          .length;
      expect(rolloverTxCountFirst, nonZeroCountBefore * 2);

      // Kapanış + açılış fişleri net bakiyeyi birebir korumalı
      for (final acc in notifier.state.accounts) {
        expect(
          acc.netBalance,
          closeTo(preRolloverBalances[acc.id] ?? 0.0, 0.05),
        );
      }

      // Aynı dönem için ikinci devir çağrısı kilitli ve idempotent olmalı
      final secondDbPreview = db.executePeriodRollover(
        fromPeriodKey: '2026-10',
        nextPeriodKey: '2027-01',
        rolloverDateKey: '2027-01-01',
      );
      expect(secondDbPreview.alreadyExecuted, isTrue);

      notifier.executePeriodRollover(
        nextPeriodKey: '2027-01',
        rolloverDateKey: '2027-01-01',
      );
      final rolloverTxCountSecond = notifier.state.transactions
          .where((t) => t.expenseCategory == 'DÖNEM DEVİR')
          .length;
      expect(rolloverTxCountSecond, rolloverTxCountFirst);
    });

    test('lib ve test kodunda harici marka sızıntısı bulunmaz', () {
      final forbiddenPattern = RegExp('lo' 'ft', caseSensitive: false);
      final offendingFiles = <String>[];
      for (final dirName in const ['lib', 'test']) {
        final dir = Directory(dirName);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            final content = entity.readAsStringSync();
            if (forbiddenPattern.hasMatch(content)) {
              offendingFiles.add(entity.path);
            }
          }
        }
      }
      expect(offendingFiles, isEmpty);
    });
  });

  group('Hasibu Ön Muhasebe İleri UI Widget Duman Testleri', () {
    testWidgets(
        'HasibuFinanceToolsPanel ve HasibuAnalyticsAndDevirPanel masaüstü ve mobilde taşmasız açılır',
        (WidgetTester tester) async {
      final db = HasibuDatabase.inMemory();
      addTearDown(db.dispose);

      Future<void> verifyViewport(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hasibuDatabaseProvider.overrideWithValue(db),
              tcmbCurrencyGatewayProvider.overrideWithValue(
                _FakeCurrencyRateGateway(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final advData = ref.watch(
                      accountingProvider.select((s) => s.advancedViewData),
                    );
                    final actions = ref.read(accountingProvider.notifier);
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        HasibuFinanceToolsPanel(
                          data: advData,
                          actions: actions,
                        ),
                        const SizedBox(height: 16),
                        HasibuAnalyticsAndDevirPanel(
                          data: advData,
                          actions: actions,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await verifyViewport(const Size(1440, 900));
      expect(find.textContaining('FİNANS, DÖVİZ'), findsOneWidget);

      await verifyViewport(const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasibuDatabaseProvider.overrideWithValue(db),
            tcmbCurrencyGatewayProvider.overrideWithValue(
              _FakeCurrencyRateGateway(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AccountingCockpitAndActionCenterView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
