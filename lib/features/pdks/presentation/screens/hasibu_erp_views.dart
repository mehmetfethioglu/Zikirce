import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/accounting_models.dart';
import '../../domain/pre_accounting_advanced_contracts.dart';
import '../providers/accounting_providers.dart';
import 'pre_accounting_analytics_and_devir_views.dart';
import 'pre_accounting_finance_tools_views.dart';

/// Mimar Sinan 60/120 FPS Hasibu ERP Görünümü:
/// Sipariş -> İrsaliye -> Fatura -> Tahsilat Zinciri, Bayi Bölge Fiyat (1..10 Grup),
/// Genel + Buğday/Bulgur Üretim Reçeteleri (BOM) ve Resmi İşlemler / KDV Yansıtma.
class HasibuErpOrderInvoiceAndProductionView extends ConsumerWidget {
  const HasibuErpOrderInvoiceAndProductionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final erpDocs = ref.watch(
      accountingProvider.select((s) => s.erpOrdersWaybillsInvoices),
    );
    final recipes = ref.watch(
      accountingProvider.select((s) => s.productionRecipes),
    );
    final accounts = ref.watch(accountingProvider.select((s) => s.accounts));
    final advData = ref.watch(
      accountingProvider.select((s) => s.advancedViewData),
    );
    final statusBanner = ref.watch(
      accountingProvider.select((s) => s.statusBanner),
    );
    final notifier = ref.read(accountingProvider.notifier);

    final totalOrderedKg = erpDocs.fold<double>(
      0.0,
      (s, d) => s + d.orderedQtyKg,
    );
    final totalInvoicedKg = erpDocs.fold<double>(
      0.0,
      (s, d) => s + d.invoicedQtyKg,
    );
    final totalTrays = erpDocs.fold<int>(0, (s, d) => s + d.trayCount);
    final totalGrandTl = erpDocs.fold<double>(
      0.0,
      (s, d) => s + d.grandTotalTl,
    );
    final totalVatTl = erpDocs.fold<double>(0.0, (s, d) => s + d.vatAmountTl);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (statusBanner != null && statusBanner.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: Color(0xFF047857),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusBanner,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Üst KPI ve Hasibu ERP Hızlı Aksiyon Barı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HASİBU ERP • SİPARİŞ -> İRSALİYE -> FATURA & REÇETE MERKEZİ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Siparişten İrsaliyeye • İrsaliyeden Faturaya • Bayi Bölge Fiyat (1..10) • Buğday/Bulgur & Baklava Reçete • KDV Yansıtma',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showNewErpOrderDialog(
                          context,
                          notifier,
                          accounts,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                        ),
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('Yeni Sipariş / İrsaliye / Fatura'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            notifier.applyBulkDealerRegionPriceAdjust(5.0),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.price_change_outlined, size: 16),
                        label: const Text('Bayi Bölge Fiyat +5% Güncelle'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ErpMetricBadge(
                    label: 'Sipariş / Faturalanan Kg',
                    value:
                        '${totalOrderedKg.toStringAsFixed(0)} / ${totalInvoicedKg.toStringAsFixed(0)} Kg',
                    sub: 'Sipariş-Fatura Kontrolü',
                    color: const Color(0xFF38BDF8),
                  ),
                  _ErpMetricBadge(
                    label: 'Tepsi Genel Toplamı',
                    value: '$totalTrays Tepsi',
                    sub: 'Sevk & İade Takibi',
                    color: const Color(0xFFFBBF24),
                  ),
                  _ErpMetricBadge(
                    label: 'Toplam Fatura / Sipariş',
                    value: '${totalGrandTl.toStringAsFixed(2)} ₺',
                    sub: '1..10 Fiyat Grubu Dahil',
                    color: const Color(0xFF34D399),
                  ),
                  _ErpMetricBadge(
                    label: 'Resmi KDV Yansıtma Havuzu',
                    value: '${totalVatTl.toStringAsFixed(2)} ₺',
                    sub: 'Ana Programa KDV Hesabı',
                    color: const Color(0xFFC084FC),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Sipariş -> İrsaliye -> Fatura Zinciri Tablosu
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Sipariş • İrsaliye • Fatura Zinciri & Sipariş-Faturalama Kontrolü (IrsaliyeyeSiparisSec / FaturayaIrsaliyeSec)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Siparişleri tek tıkla Satış İrsaliyesine (otomatik tepsi zimmeti ile), İrsaliyeleri Faturaya ve Faturayı Kasa/Banka Tahsilatına dönüştürün.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                if (erpDocs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Kayıtlı sipariş/irsaliye/fatura bulunmuyor.'),
                  )
                else
                  ...erpDocs.map(
                    (doc) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 280,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _StageChip(stage: doc.stage),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${doc.orderDocNo}${doc.waybillDocNo != null ? " → ${doc.waybillDocNo}" : ""}${doc.invoiceDocNo != null ? " → ${doc.invoiceDocNo}" : ""}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doc.accountName,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${doc.regionGroup} • Fiyat-${doc.priceTier} • ${doc.stockName}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sipariş: ${doc.orderedQtyKg.toStringAsFixed(1)} Kg | Sevk: ${doc.shippedQtyKg.toStringAsFixed(1)} Kg | Fatura: ${doc.invoicedQtyKg.toStringAsFixed(1)} Kg',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Tepsi: ${doc.trayCount} Adet • Birim: ${doc.unitPriceTl.toStringAsFixed(2)} ₺ (-%${doc.discountPercent.toStringAsFixed(0)})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                Text(
                                  'Genel Toplam: ${doc.grandTotalTl.toStringAsFixed(2)} ₺ (KDV: ${doc.vatAmountTl.toStringAsFixed(2)} ₺)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (doc.stage == 'SIPARIS')
                                FilledButton.tonalIcon(
                                  onPressed: () =>
                                      notifier.advanceErpDocumentStage(doc.id),
                                  icon: const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 15,
                                  ),
                                  label: const Text('İrsaliyeye Aktar'),
                                ),
                              if (doc.stage == 'IRSALIYE_SEVK')
                                FilledButton.icon(
                                  onPressed: () =>
                                      notifier.advanceErpDocumentStage(doc.id),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                  ),
                                  icon: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 15,
                                  ),
                                  label: const Text('Faturaya Dönüştür'),
                                ),
                              if (doc.stage == 'FATURALANDI' &&
                                  doc.collectedAmountTl < doc.grandTotalTl)
                                OutlinedButton.icon(
                                  onPressed: () => notifier
                                      .collectPaymentAgainstInvoice(doc.id),
                                  icon: const Icon(
                                    Icons.payments_outlined,
                                    size: 15,
                                  ),
                                  label: const Text('Tahsilat Al'),
                                ),
                              if (!doc.isOfficialVatReflected)
                                OutlinedButton.icon(
                                  onPressed: () => notifier
                                      .reflectOfficialVatToMainLedger(doc.id),
                                  icon: const Icon(
                                    Icons.account_balance_outlined,
                                    size: 15,
                                  ),
                                  label: const Text('KDV Yansıt'),
                                )
                              else
                                const Chip(
                                  label: Text(
                                    'Resmi KDV Yansıtıldı',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Üretim Reçeteleri (Genel Baklava + Buğday/Bulgur Reçetesi + Resmi Reçete)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Üretim Reçeteleri (UretimReceteler) • Buğday/Bulgur Üretim Fişi (UretimFisi_Bugday) & Resmi Reçete',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hasibu BOM motoru: Her üretim partisinde mamul stoğunu artırır, reçetedeki hammadde sarfiyatını ve fire yüzdesini otomatik düşer.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                ...recipes.map(
                  (rcp) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 320,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${rcp.recipeCode} • ${rcp.productName}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                rcp.ingredientsSummary,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parti Çıktısı: ${rcp.batchOutputKg.toStringAsFixed(0)} Kg (${rcp.trayYieldCount} Tepsi) • Fire: %${rcp.fireWastePercent}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Kg Maliyet: ${rcp.unitCostPerKgTl.toStringAsFixed(2)} ₺ | Tepsi Maliyet: ${rcp.unitCostPerTrayTl.toStringAsFixed(2)} ₺',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              Text(
                                'Bugün Üretilen: ${rcp.producedBatchesToday} Parti',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              notifier.executeProductionRecipeBatch(rcp.id),
                          icon: const Icon(
                            Icons.precision_manufacturing_outlined,
                            size: 16,
                          ),
                          label: const Text('+1 Parti Üretim Fişi Kes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        HasibuErpAdvancedControlsPanel(data: advData, actions: notifier),
      ],
    );
  }

  void _showNewErpOrderDialog(
    BuildContext context,
    AccountingNotifier notifier,
    List<AccountingAccount> accounts,
  ) {
    final stockCtrl = TextEditingController(
      text: 'FISTIKLI KARE BAKLAVA (TEPSİ)',
    );
    final qtyCtrl = TextEditingController(text: '120');
    final trayCtrl = TextEditingController(text: '30');
    final priceCtrl = TextEditingController(text: '640');
    AccountingAccount selectedAcc = accounts.isNotEmpty
        ? accounts.first
        : const AccountingAccount(
            id: 'acc_demo_cust_1',
            code: 'MŞT-101',
            name: 'EGE BÖLGE KURUMSAL DAĞITIM A.Ş.',
            type: AccountingAccountType.customer,
          );
    int priceTier = 2;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Yeni Hasibu ERP Sipariş / İrsaliye / Fatura'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (accounts.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedAcc.id,
                      decoration: const InputDecoration(
                        labelText: 'Cari Kart (Müşteri / Bayi / Şube)',
                      ),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem<String>(
                              value: a.id,
                              child: Text(
                                '${a.name} (${a.code})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() {
                          selectedAcc = accounts.firstWhere((a) => a.id == v);
                        });
                      },
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: priceTier,
                    decoration: const InputDecoration(
                      labelText: 'Bayi Satış Fiyat Grubu (1..10)',
                    ),
                    items: List.generate(
                      10,
                      (i) => DropdownMenuItem<int>(
                        value: i + 1,
                        child: Text('Satış Fiyat Grubu - ${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => setModalState(() => priceTier = v ?? 2),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stockCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Stok / Mamul Adı',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Miktar (Kg)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: trayCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tepsi Adedi',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Birim Fiyat (₺)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                stockCtrl.dispose();
                qtyCtrl.dispose();
                trayCtrl.dispose();
                priceCtrl.dispose();
                Navigator.of(ctx).pop();
              },
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                notifier.createErpOrderOrInvoice(
                  account: selectedAcc,
                  regionGroup: 'Bayi Bölge Grubu (Fiyat-$priceTier)',
                  priceTier: priceTier,
                  stockCode: 'BKL-00$priceTier',
                  stockName: stockCtrl.text.trim(),
                  orderedQtyKg: double.tryParse(qtyCtrl.text) ?? 100.0,
                  trayCount: int.tryParse(trayCtrl.text) ?? 25,
                  unitPriceTl: double.tryParse(priceCtrl.text) ?? 640.0,
                );
                stockCtrl.dispose();
                qtyCtrl.dispose();
                trayCtrl.dispose();
                priceCtrl.dispose();
                Navigator.of(ctx).pop();
              },
              child: const Text('Siparişi Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hasibu Raporlar, Defterler (Kasa/Banka Defteri, Borç/Alacak, Ortalama Vade,
/// Envanter, Fire, Plasiyer, Depozito), Özel Excel Tabloları ve Belge Dizayn (`.repx`) Merkezi.
class HasibuReportsAndLedgersView extends ConsumerWidget {
  const HasibuReportsAndLedgersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountingProvider.select((s) => s.accounts));
    final transactions = ref.watch(
      accountingProvider.select((s) => s.transactions),
    );
    final stocks = ref.watch(
      accountingProvider.select((s) => s.stockBurnItems),
    );
    final MaturitySummary maturity = ref.watch(
      accountingProvider.select((s) => s.receivableMaturitySummary),
    );
    final advData = ref.watch(
      accountingProvider.select((s) => s.advancedViewData),
    );
    final notifier = ref.read(accountingProvider.notifier);

    final kasaTx = transactions
        .where(
          (t) =>
              t.entryType == LedgerEntryType.cashIn ||
              t.entryType == LedgerEntryType.cashOut ||
              t.entryType == LedgerEntryType.expense,
        )
        .toList();
    final bankaTx = transactions
        .where(
          (t) =>
              t.entryType == LedgerEntryType.bankIn ||
              t.entryType == LedgerEntryType.bankOut,
        )
        .toList();

    final totalReceivables = accounts
        .where((a) => a.netBalance < 0)
        .fold<double>(0.0, (s, a) => s + a.netBalance.abs());
    final totalPayables = accounts
        .where((a) => a.netBalance > 0)
        .fold<double>(0.0, (s, a) => s + a.netBalance);
    final totalStockValuation = stocks.fold<double>(
      0.0,
      (s, i) => s + i.totalValuation,
    );
    final totalTraysInField = accounts.fold<int>(
      0,
      (s, a) => s + a.trayBalance,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        // 1. Hasibu 16'lı Rapor & Defter Özeti
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HASİBU RAPORLAR • DEFTERLER • ÖZEL TABLOLAR & BELGE DİZAYN (.REPX)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Genel Durum • Dönemsel Faaliyet • Borç-Alacak • Ortalama Vade • Kasa/Banka Defteri • Envanter • Fire • Plasiyer • Depozito/Tepsi',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ErpMetricBadge(
                    label: 'Borç / Alacak Raporu (Alacaklar)',
                    value: '${totalReceivables.toStringAsFixed(2)} ₺',
                    sub:
                        'Ort. Vade: ${maturity.weightedDays.toStringAsFixed(1)} Gün (${maturity.averageDueDateKey})',
                    color: const Color(0xFF38BDF8),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.calculate_outlined,
                      size: 16,
                      color: Color(0xFF38BDF8),
                    ),
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    label: const Text(
                      'Adat / Vade Hesapla',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () => showHasibuWeightedMaturityDialog(
                      context,
                      initialSummary: maturity,
                    ),
                  ),
                  _ErpMetricBadge(
                    label: 'Tedarikçi & Personel Borçları',
                    value: '${totalPayables.toStringAsFixed(2)} ₺',
                    sub: 'Vade Hatırlatıcı Aktif',
                    color: const Color(0xFFF43F5E),
                  ),
                  _ErpMetricBadge(
                    label: 'Dönem Sonu Maliyetli Envanter',
                    value: '${totalStockValuation.toStringAsFixed(2)} ₺',
                    sub: '${stocks.length} Aktif Stok Kalemi',
                    color: const Color(0xFF34D399),
                  ),
                  _ErpMetricBadge(
                    label: 'Depozito & Sahadaki Tepsi',
                    value: '$totalTraysInField Tepsi',
                    sub: 'Tepsi Satış & İade Raporu',
                    color: const Color(0xFFFBBF24),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Kasa Defteri & Banka Defteri Yan Yana
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kasa Defteri (KasaDefter • Giren / Çıkan / Kalan)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...kasaTx.take(5).map(
                        (t) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${t.docNo} • ${t.accountName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${t.dateKey} • ${t.cashOrBankName} • ${t.description}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            '${t.direction == "A" ? "+" : "-"}${t.amount.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: t.direction == 'A'
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Banka Defteri (BankaDefter • Yatırılan / Çekilen)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...bankaTx.take(5).map(
                        (t) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${t.docNo} • ${t.accountName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${t.dateKey} • ${t.cashOrBankName} • ${t.description}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            '${t.direction == "A" ? "+" : "-"}${t.amount.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: t.direction == 'A'
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Kümülatif Kasa / Banka Defterleri + Analitik Raporlar, Özel Tablo, .REPX & Dönem Sonu Devir
        HasibuCumulativeCashBankLedgersCard(data: advData),
        const SizedBox(height: 16),
        HasibuAnalyticalReportsAndRepxPanel(
          data: advData,
          actions: notifier,
        ),
      ],
    );
  }
}

class _ErpMetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _ErpMetricBadge({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 215,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  final String stage;
  const _StageChip({required this.stage});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String text) = switch (stage) {
      'SIPARIS' => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          'SİPARİŞ',
        ),
      'IRSALIYE_SEVK' => (
          const Color(0xFFDBEAFE),
          const Color(0xFF1E40AF),
          'İRSALİYE SEVK',
        ),
      _ => (
          const Color(0xFFD1FAE5),
          const Color(0xFF065F46),
          'FATURALANDI',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
