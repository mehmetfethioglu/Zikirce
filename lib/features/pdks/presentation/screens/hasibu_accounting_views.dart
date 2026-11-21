import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/accounting_models.dart';
import '../providers/accounting_providers.dart';
import 'hasibu_settings_view.dart';
import 'pre_accounting_analytics_and_devir_views.dart';
import 'pre_accounting_finance_tools_views.dart';

String _fmtTl(double val) {
  final isNeg = val < 0;
  final absVal = val.abs();
  final parts = absVal.toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) {
      buf.write('.');
    }
    buf.write(intPart[i]);
  }
  return '${isNeg ? "-" : ""}${buf.toString()},$decPart ₺';
}

// ============================================================================
// FAZ 1 (SEKME 1): ÖN MUHASEBE İŞLEMLER ŞERİDİ (RIBBON), GİRİŞ/ÇIKIŞ MERKEZİ
// VE YÖNETİCİ GÜN SONU KOKPİTİ
// ============================================================================
class AccountingCockpitAndActionCenterView extends ConsumerStatefulWidget {
  const AccountingCockpitAndActionCenterView({super.key});

  @override
  ConsumerState<AccountingCockpitAndActionCenterView> createState() =>
      _AccountingCockpitAndActionCenterViewState();
}

class _AccountingCockpitAndActionCenterViewState
    extends ConsumerState<AccountingCockpitAndActionCenterView> {
  bool _isIncoming = true;
  String? _selectedAccountId;
  String? _counterPartyAccountId;
  String _selectedCashOrBank = 'Merkez TL Kasa';
  String _selectedExpenseCat = 'GENEL İŞLETME';
  String? _selectedStockId;
  String _selectedContainerType = 'Tepsi';
  String _dueDateKey = '2026-10-30';

  late final TextEditingController _amountCtrl;
  late final TextEditingController _docNoCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _qtyCtrl;

  static const List<String> _cashBankOptions = <String>[
    'Merkez TL Kasa',
    'Şube Nakit Kasa',
    'POS Tahsilat Kasası',
    'Ziraat Ticari Banka',
    'Garanti BBVA Ticari',
    'Merkez Soğuk Hava Deposu',
    'Şube Tezgah Deposu',
  ];

  static const List<String> _expenseCategories = <String>[
    'GENEL İŞLETME',
    'HAMMADDE ALIMI',
    'PERSONEL GİDERLERİ',
    'LOJİSTİK & SEVKİYAT',
    'ENERJİ & KİRA',
    'VERGİ & SGK',
  ];

  static const List<String> _containerTypes = <String>[
    'Tepsi',
    'Köşebent',
    'Dondurma Küveti',
    'Kasa',
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '12500');
    _docNoCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _qtyCtrl = TextEditingController(text: '15');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _docNoCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  IconData _iconForModule(PreAccountingOperationModule mod) {
    return switch (mod) {
      PreAccountingOperationModule.cariTanimlari => Icons.contact_page_outlined,
      PreAccountingOperationModule.kasaIslemleri =>
        Icons.point_of_sale_outlined,
      PreAccountingOperationModule.bankaIslemleri =>
        Icons.account_balance_outlined,
      PreAccountingOperationModule.cekIslemleri =>
        Icons.request_quote_outlined,
      PreAccountingOperationModule.senetIslemleri =>
        Icons.description_outlined,
      PreAccountingOperationModule.dekontIslemleri =>
        Icons.receipt_long_outlined,
      PreAccountingOperationModule.virmanlar => Icons.swap_horiz_rounded,
      PreAccountingOperationModule.giderIslemleri =>
        Icons.money_off_csred_outlined,
      PreAccountingOperationModule.kurBazliTahsilat =>
        Icons.currency_exchange_outlined,
      PreAccountingOperationModule.siparisler =>
        Icons.shopping_bag_outlined,
      PreAccountingOperationModule.irsaliyeler =>
        Icons.local_shipping_outlined,
      PreAccountingOperationModule.faturalar => Icons.receipt_outlined,
      PreAccountingOperationModule.dondurmaSatislar =>
        Icons.icecream_outlined,
      PreAccountingOperationModule.bayiSozlesmeVeBolgeFiyat =>
        Icons.handshake_outlined,
      PreAccountingOperationModule.stokTanimlari =>
        Icons.inventory_2_outlined,
      PreAccountingOperationModule.stokFisleri => Icons.fact_check_outlined,
      PreAccountingOperationModule.tepsiKosebentIade =>
        Icons.layers_outlined,
      PreAccountingOperationModule.depoSevkFisleri =>
        Icons.local_shipping_outlined,
      PreAccountingOperationModule.uretimFisleri =>
        Icons.precision_manufacturing_outlined,
      PreAccountingOperationModule.uretimListesiVeHammaddeler =>
        Icons.schema_outlined,
      PreAccountingOperationModule.bulgurVeBugdayUretim =>
        Icons.agriculture_outlined,
      PreAccountingOperationModule.resmiAlisFaturaVeRecete =>
        Icons.gavel_outlined,
      PreAccountingOperationModule.personelKart => Icons.badge_outlined,
      PreAccountingOperationModule.puantaj => Icons.calendar_month_outlined,
      PreAccountingOperationModule.personelGirisler =>
        Icons.payments_outlined,
      PreAccountingOperationModule.ozelTablolar =>
        Icons.table_chart_outlined,
      PreAccountingOperationModule.ajanda => Icons.event_note_outlined,
      PreAccountingOperationModule.odemeEmirleri =>
        Icons.send_time_extension_outlined,
      PreAccountingOperationModule.notlar => Icons.sticky_note_2_outlined,
      PreAccountingOperationModule.kayanYazi => Icons.campaign_outlined,
      PreAccountingOperationModule.smsVeEpostaBildirim =>
        Icons.sms_outlined,
      PreAccountingOperationModule.donemDevirVeBulutYedek =>
        Icons.cloud_sync_outlined,
    };
  }

  Color _accentForGroup(PreAccountingRibbonGroup group) {
    return switch (group) {
      PreAccountingRibbonGroup.cariIslemler => const Color(0xFF0284C7),
      PreAccountingRibbonGroup.fatura => const Color(0xFF059669),
      PreAccountingRibbonGroup.stokIslemleri => const Color(0xFFD97706),
      PreAccountingRibbonGroup.personel => const Color(0xFF7C3AED),
      PreAccountingRibbonGroup.yardimcilar => const Color(0xFF0F766E),
    };
  }

  bool _usesStockOrQty(PreAccountingOperationModule mod) {
    return mod == PreAccountingOperationModule.stokTanimlari ||
        mod == PreAccountingOperationModule.stokFisleri ||
        mod == PreAccountingOperationModule.depoSevkFisleri ||
        mod == PreAccountingOperationModule.uretimFisleri ||
        mod == PreAccountingOperationModule.uretimListesiVeHammaddeler ||
        mod == PreAccountingOperationModule.dondurmaSatislar ||
        mod == PreAccountingOperationModule.tepsiKosebentIade;
  }

  bool _usesDueDate(PreAccountingOperationModule mod) {
    return mod == PreAccountingOperationModule.cekIslemleri ||
        mod == PreAccountingOperationModule.senetIslemleri ||
        mod == PreAccountingOperationModule.ajanda ||
        mod == PreAccountingOperationModule.odemeEmirleri;
  }

  Future<void> _pickOperationDate(
    BuildContext context,
    String currentDateKey,
  ) async {
    final parts = currentDateKey.split('-');
    DateTime initial = DateTime(2026, 10, 22);
    if (parts.length == 3) {
      initial = DateTime(
        int.tryParse(parts[0]) ?? 2026,
        int.tryParse(parts[1]) ?? 10,
        int.tryParse(parts[2]) ?? 22,
      );
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2032, 12, 31),
      helpText: 'ÖN MUHASEBE İŞLEM TARİHİ SEÇİN',
      cancelText: 'İPTAL',
      confirmText: 'SEÇ',
    );
    if (picked != null && mounted) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      ref
          .read(accountingProvider.notifier)
          .setSelectedDateKey('$y-$m-$d');
    }
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final parts = _dueDateKey.split('-');
    DateTime initial = DateTime(2026, 10, 30);
    if (parts.length == 3) {
      initial = DateTime(
        int.tryParse(parts[0]) ?? 2026,
        int.tryParse(parts[1]) ?? 10,
        int.tryParse(parts[2]) ?? 30,
      );
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'ÇEK / SENET / ÖDEME EMRİ VADE TARİHİ',
      cancelText: 'İPTAL',
      confirmText: 'VADE SEÇ',
    );
    if (picked != null && mounted) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _dueDateKey = '$y-$m-$d';
      });
    }
  }

  List<AccountingTransaction> _filterTransactionsForModule(
    PreAccountingOperationModule mod,
    List<AccountingTransaction> all,
  ) {
    return all.where((tx) {
      return switch (mod) {
        PreAccountingOperationModule.kasaIslemleri =>
          tx.entryType == LedgerEntryType.cashIn ||
              tx.entryType == LedgerEntryType.cashOut ||
              tx.entryType == LedgerEntryType.expense,
        PreAccountingOperationModule.bankaIslemleri =>
          tx.entryType == LedgerEntryType.bankIn ||
              tx.entryType == LedgerEntryType.bankOut,
        PreAccountingOperationModule.cekIslemleri =>
          tx.entryType == LedgerEntryType.checkIn ||
              tx.entryType == LedgerEntryType.checkOut,
        PreAccountingOperationModule.senetIslemleri =>
          tx.entryType == LedgerEntryType.promissoryIn ||
              tx.entryType == LedgerEntryType.promissoryOut,
        PreAccountingOperationModule.dekontIslemleri =>
          tx.entryType == LedgerEntryType.creditMemo ||
              tx.entryType == LedgerEntryType.debitMemo ||
              tx.entryType == LedgerEntryType.payrollAccrual,
        PreAccountingOperationModule.virmanlar =>
          tx.entryType == LedgerEntryType.transferVirman,
        PreAccountingOperationModule.siparisler =>
          tx.entryType == LedgerEntryType.salesOrder ||
              tx.entryType == LedgerEntryType.purchaseOrder,
        PreAccountingOperationModule.faturalar =>
          tx.entryType == LedgerEntryType.salesInvoice ||
              tx.entryType == LedgerEntryType.purchaseInvoice ||
              tx.entryType == LedgerEntryType.salesReturn ||
              tx.entryType == LedgerEntryType.salesOrder,
        PreAccountingOperationModule.dondurmaSatislar =>
          tx.entryType == LedgerEntryType.iceCreamSale ||
              tx.docNo.startsWith('DND'),
        PreAccountingOperationModule.stokTanimlari ||
        PreAccountingOperationModule.stokFisleri ||
        PreAccountingOperationModule.uretimListesiVeHammaddeler =>
          tx.entryType == LedgerEntryType.stockInVoucher ||
              tx.entryType == LedgerEntryType.stockOutVoucher,
        PreAccountingOperationModule.depoSevkFisleri =>
          tx.entryType == LedgerEntryType.warehouseTransfer ||
              tx.docNo.startsWith('SVK'),
        PreAccountingOperationModule.uretimFisleri =>
          tx.entryType == LedgerEntryType.productionVoucher ||
              tx.docNo.startsWith('URT'),
        PreAccountingOperationModule.personelKart ||
        PreAccountingOperationModule.puantaj ||
        PreAccountingOperationModule.personelGirisler =>
          tx.entryType == LedgerEntryType.payrollAccrual ||
              tx.entryType == LedgerEntryType.advancePayment ||
              tx.entryType == LedgerEntryType.personnelBonusOrDeduction ||
              tx.expenseCategory.contains('PERSONEL'),
        _ => true,
      };
    }).toList(growable: false);
  }

  void _showQuickCariModal(
    BuildContext context, {
    AccountingAccountType defaultType = AccountingAccountType.customer,
  }) {
    final codeCtrl = TextEditingController(
      text: defaultType == AccountingAccountType.employee
          ? 'PRS-${DateTime.now().millisecondsSinceEpoch % 1000}'
          : 'CARI-${DateTime.now().millisecondsSinceEpoch % 1000}',
    );
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salaryCtrl = TextEditingController(
      text: defaultType == AccountingAccountType.employee ? '34000' : '0',
    );
    final trayCtrl = TextEditingController(text: '0');
    final specialCodeCtrl = TextEditingController();
    final salesRepCtrl = TextEditingController();
    final priceTierCtrl = TextEditingController(text: '1');
    final creditLimitCtrl = TextEditingController(text: '0');
    AccountingAccountType selectedType = defaultType;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            selectedType == AccountingAccountType.employee
                ? 'Yeni Personel Cari & Maaş Kartı Tanımla'
                : 'Yeni Cari Kart Tanımla (Müşteri / Tedarikçi / Şube)',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AccountingAccountType>(
                    initialValue: selectedType,
                    items: [
                      for (final t in AccountingAccountType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedType = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Cari Kart Türü',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Cari Kodu'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cari Unvanı / Ad Soyad',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  const SizedBox(height: 8),
                  if (selectedType == AccountingAccountType.employee)
                    TextField(
                      controller: salaryCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Aylık Net Maaş / Yevmiye (₺)',
                      ),
                    )
                  else ...[
                    TextField(
                      controller: trayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Açılış Emanet Tepsi Adedi',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: specialCodeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Özel Kod',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: salesRepCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Plasiyer',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceTierCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Fiyat Grubu (1-10)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: creditLimitCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Risk / Kredi Limiti (₺)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  ref.read(accountingProvider.notifier).addQuickAccount(
                        code: codeCtrl.text,
                        name: nameCtrl.text,
                        type: selectedType,
                        groupName: selectedType.label,
                        phone: phoneCtrl.text,
                        baseSalary: double.tryParse(salaryCtrl.text) ?? 0.0,
                        initialTrays: int.tryParse(trayCtrl.text) ?? 0,
                        specialCode: specialCodeCtrl.text.trim(),
                        salesRepName: salesRepCtrl.text.trim(),
                        priceTier: int.tryParse(priceTierCtrl.text) ?? 1,
                        creditLimitTl:
                            double.tryParse(creditLimitCtrl.text) ?? 0.0,
                      );
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Cari Kartı Kaydet'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      codeCtrl.dispose();
      nameCtrl.dispose();
      phoneCtrl.dispose();
      salaryCtrl.dispose();
      trayCtrl.dispose();
      specialCodeCtrl.dispose();
      salesRepCtrl.dispose();
      priceTierCtrl.dispose();
      creditLimitCtrl.dispose();
    });
  }

  void _showQuickStockModal(BuildContext context) {
    final codeCtrl = TextEditingController(
      text: 'STK-${DateTime.now().millisecondsSinceEpoch % 1000}',
    );
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'KG');
    final qtyCtrl = TextEditingController(text: '100');
    final burnCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(text: '450');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Stok / Hammadde / Mamul Kartı Tanımla'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Stok Kodu'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Stok / Hammadde / Mamul Adı',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Birim (KG/ADET/TEPSİ)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Açılış Miktarı',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: burnCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Günlük Sarfiyat Hızı',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Birim Maliyet (₺)',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                ref.read(accountingProvider.notifier).addOrUpdateStockBurnItem(
                      code: codeCtrl.text,
                      name: nameCtrl.text,
                      unit: unitCtrl.text,
                      currentQty: double.tryParse(qtyCtrl.text) ?? 0.0,
                      dailyBurnRate: double.tryParse(burnCtrl.text) ?? 1.0,
                      unitCost: double.tryParse(costCtrl.text) ?? 0.0,
                    );
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Stok Kartını Kaydet'),
          ),
        ],
      ),
    ).whenComplete(() {
      codeCtrl.dispose();
      nameCtrl.dispose();
      unitCtrl.dispose();
      qtyCtrl.dispose();
      burnCtrl.dispose();
      costCtrl.dispose();
    });
  }

  void _executeCurrentOperation({
    required PreAccountingOperationModule selectedModule,
    required List<AccountingAccount> accounts,
    required List<StockBurnItem> stocks,
    BuildContext? popupContext,
  }) {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0.0;

    final selectedAcc = accounts
            .where((a) => a.id == _selectedAccountId)
            .firstOrNull ??
        (accounts.isNotEmpty ? accounts.first : null);
    final counterAcc = accounts
        .where((a) => a.id == _counterPartyAccountId)
        .firstOrNull;
    final effectiveStockId =
        _selectedStockId ?? (stocks.isNotEmpty ? stocks.first.id : null);

    ref.read(accountingProvider.notifier).recordOperationalEntryExit(
          module: selectedModule,
          isIncoming: _isIncoming,
          account: selectedAcc,
          counterPartyAccount: counterAcc,
          amount: amount,
          customDocNo: _docNoCtrl.text,
          cashOrBankName: _selectedCashOrBank,
          expenseCategory: _selectedExpenseCat,
          description: _descCtrl.text,
          dueDateKey: _dueDateKey,
          stockId: _usesStockOrQty(selectedModule) ? effectiveStockId : null,
          stockQuantity: qty,
          containerType: _selectedContainerType,
        );

    _docNoCtrl.clear();
    _descCtrl.clear();
    if (popupContext != null && Navigator.of(popupContext).canPop()) {
      Navigator.of(popupContext).pop();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              _isIncoming ? const Color(0xFF059669) : const Color(0xFFDC2626),
          content: Text(
            '${selectedModule.title} • ${_isIncoming ? selectedModule.inActionLabel : selectedModule.outActionLabel} başarıyla kaydedildi.',
          ),
        ),
      );
    }
  }

  void _openEntryExitPopup(
    BuildContext context, {
    PreAccountingOperationModule? initialModule,
    bool? initialIsIncoming,
  }) {
    if (initialModule != null) {
      ref
          .read(accountingProvider.notifier)
          .selectOperationModule(initialModule);
    }
    if (initialIsIncoming != null) {
      setState(() {
        _isIncoming = initialIsIncoming;
      });
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (popupCtx) {
        return StatefulBuilder(
          builder: (popupCtx, setPopupState) {
            final currentModule = ref.watch(
              accountingProvider.select((s) => s.selectedOperationModule),
            );
            final accounts =
                ref.watch(accountingProvider.select((s) => s.accounts));
            final stocks =
                ref.watch(accountingProvider.select((s) => s.stockBurnItems));
            final selectedDateKey =
                ref.watch(accountingProvider.select((s) => s.selectedDateKey));
            final pal = HasibuPalette.of(popupCtx);
            final screenSize = MediaQuery.sizeOf(popupCtx);
            final isMobile = screenSize.width < 680;
            final bottomInset = MediaQuery.viewInsetsOf(popupCtx).bottom;

            final effectiveAccountId =
                accounts.any((a) => a.id == _selectedAccountId)
                    ? _selectedAccountId
                    : (accounts.isNotEmpty ? accounts.first.id : null);
            final effectiveCounterAccountId =
                accounts.any((a) => a.id == _counterPartyAccountId)
                    ? _counterPartyAccountId
                    : (accounts.length > 1
                        ? accounts[1].id
                        : (accounts.isNotEmpty ? accounts.first.id : null));
            final effectiveStockId =
                stocks.any((s) => s.id == _selectedStockId)
                    ? _selectedStockId
                    : (stocks.isNotEmpty ? stocks.first.id : null);

            final activeAccent = _isIncoming
                ? const Color(0xFF059669)
                : const Color(0xFFDC2626);

            void syncState(VoidCallback fn) {
              setState(fn);
              setPopupState(() {});
            }

            return Dialog(
              key: const ValueKey('dialog_accounting_entry_exit'),
              backgroundColor: pal.card,
              surfaceTintColor: Colors.transparent,
              alignment:
                  isMobile ? Alignment.bottomCenter : Alignment.center,
              insetPadding: isMobile
                  ? EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: 24,
                      bottom: bottomInset > 0 ? bottomInset + 8 : 8,
                    )
                  : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 22 : 18),
                side: BorderSide(color: pal.border),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? screenSize.width : 620,
                  maxHeight: screenSize.height * (isMobile ? 0.90 : 0.86),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isMobile)
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(top: 10, bottom: 2),
                          decoration: BoxDecoration(
                            color: pal.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    // POPUP ÜST BAŞLIK
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        isMobile ? 12 : 18,
                        14,
                        12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _accentForGroup(currentModule.group)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _iconForModule(currentModule),
                              color: _accentForGroup(currentModule.group),
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Yeni Giriş / Çıkış İşlemi',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: pal.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${currentModule.group.title} • ${currentModule.subtitle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: pal.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('btn_close_entry_exit_popup'),
                            tooltip: 'Kapat',
                            onPressed: () => Navigator.of(popupCtx).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: pal.border),

                    // POPUP İÇERİK GÖVDESİ (SCROLLABLE)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. İŞLEM MODÜLÜ VE TARİH SEÇİMİ
                            if (isMobile) ...[
                              DropdownButtonFormField<
                                  PreAccountingOperationModule>(
                                key: const ValueKey('dropdown_popup_module'),
                                initialValue: currentModule,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'İşlem Modülü',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final mod
                                      in PreAccountingOperationModule.values)
                                    DropdownMenuItem(
                                      value: mod,
                                      child: Text(
                                        '${mod.group.title} • ${mod.title}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (mod) {
                                  if (mod != null) {
                                    ref
                                        .read(accountingProvider.notifier)
                                        .selectOperationModule(mod);
                                    setPopupState(() {});
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<
                                        PreAccountingOperationModule>(
                                      key: const ValueKey(
                                        'dropdown_popup_module',
                                      ),
                                      initialValue: currentModule,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'İşlem Modülü',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      items: [
                                        for (final mod
                                            in PreAccountingOperationModule
                                                .values)
                                          DropdownMenuItem(
                                            value: mod,
                                            child: Text(
                                              '${mod.group.title} • ${mod.title}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (mod) {
                                        if (mod != null) {
                                          ref
                                              .read(
                                                accountingProvider.notifier,
                                              )
                                              .selectOperationModule(mod);
                                          setPopupState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await _pickOperationDate(
                                        popupCtx,
                                        selectedDateKey,
                                      );
                                      setPopupState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 15,
                                    ),
                                    label: Text(selectedDateKey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],

                            // 2. GİRİŞ (+) / ÇIKIŞ (-) YÖN SEÇİCİ
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: pal.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: pal.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      key: const ValueKey('btn_mode_incoming'),
                                      borderRadius: BorderRadius.circular(9),
                                      onTap: () =>
                                          syncState(() => _isIncoming = true),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isIncoming
                                              ? const Color(0xFF059669)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.south_west_rounded,
                                              size: 16,
                                              color: _isIncoming
                                                  ? Colors.white
                                                  : const Color(0xFF059669),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Giriş • ${currentModule.inActionLabel}',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _isIncoming
                                                      ? Colors.white
                                                      : pal.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: InkWell(
                                      key: const ValueKey('btn_mode_outgoing'),
                                      borderRadius: BorderRadius.circular(9),
                                      onTap: () =>
                                          syncState(() => _isIncoming = false),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: !_isIncoming
                                              ? const Color(0xFFDC2626)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.north_east_rounded,
                                              size: 16,
                                              color: !_isIncoming
                                                  ? Colors.white
                                                  : const Color(0xFFDC2626),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Çıkış • ${currentModule.outActionLabel}',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: !_isIncoming
                                                      ? Colors.white
                                                      : pal.textPrimary,
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
                            ),
                            const SizedBox(height: 16),

                            // 3. CARİ HESAP SEÇİMİ + HIZLI CARİ EKLEME
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: effectiveAccountId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: currentModule ==
                                              PreAccountingOperationModule
                                                  .virmanlar
                                          ? 'Gönderen Cari Hesap'
                                          : 'Cari / Şube / Personel Hesabı',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      for (final acc in accounts)
                                        DropdownMenuItem(
                                          value: acc.id,
                                          child: Text(
                                            '${acc.name} (${acc.code}) • ${_fmtTl(acc.netBalance)}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) => syncState(
                                      () => _selectedAccountId = v,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  key: const ValueKey(
                                    'btn_quick_new_cari_from_workbench',
                                  ),
                                  onPressed: () => _showQuickCariModal(
                                    popupCtx,
                                    defaultType: currentModule.group ==
                                            PreAccountingRibbonGroup.personel
                                        ? AccountingAccountType.employee
                                        : AccountingAccountType.customer,
                                  ),
                                  icon: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 16,
                                  ),
                                  label: Text(isMobile ? 'Yeni' : '+ Yeni Cari'),
                                ),
                              ],
                            ),

                            if (currentModule ==
                                PreAccountingOperationModule.virmanlar) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: effectiveCounterAccountId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Alıcı (Karşı) Cari Hesap',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final acc in accounts)
                                    DropdownMenuItem(
                                      value: acc.id,
                                      child: Text(
                                        '${acc.name} (${acc.code}) • ${_fmtTl(acc.netBalance)}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => syncState(
                                  () => _counterPartyAccountId = v,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),

                            // 4. TUTAR & KASA/BANKA SEÇİMİ (MOBİLDE ALT ALTA, MASAÜSTÜNDE YAN YANA)
                            if (isMobile) ...[
                              TextField(
                                key: const ValueKey('input_op_amount'),
                                controller: _amountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Tutar (₺)',
                                  prefixIcon: Icon(
                                    Icons.currency_lira_rounded,
                                    size: 18,
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCashOrBank,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Kasa / Banka / Depo',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final cb in _cashBankOptions)
                                    DropdownMenuItem(
                                      value: cb,
                                      child: Text(cb),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    syncState(() => _selectedCashOrBank = v);
                                  }
                                },
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: const ValueKey('input_op_amount'),
                                      controller: _amountCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Tutar (₺)',
                                        prefixIcon: Icon(
                                          Icons.currency_lira_rounded,
                                          size: 18,
                                        ),
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedCashOrBank,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Kasa / Banka / Depo',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      items: [
                                        for (final cb in _cashBankOptions)
                                          DropdownMenuItem(
                                            value: cb,
                                            child: Text(cb),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          syncState(
                                            () => _selectedCashOrBank = v,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),

                            // 5. STOK / ÜRETİM / TEPSİ-KÖŞEBENT SEÇİCİSİ
                            if (_usesStockOrQty(currentModule)) ...[
                              Row(
                                children: [
                                  if (currentModule ==
                                      PreAccountingOperationModule
                                          .tepsiKosebentIade)
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _selectedContainerType,
                                        decoration: const InputDecoration(
                                          labelText: 'Emanet Kap Türü',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          for (final ct in _containerTypes)
                                            DropdownMenuItem(
                                              value: ct,
                                              child: Text(ct),
                                            ),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            syncState(
                                              () => _selectedContainerType = v,
                                            );
                                          }
                                        },
                                      ),
                                    )
                                  else
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: effectiveStockId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Stok / Mamul Kartı',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          for (final stk in stocks)
                                            DropdownMenuItem(
                                              value: stk.id,
                                              child: Text(
                                                '${stk.name} (${stk.currentQty.toStringAsFixed(0)} ${stk.unit})',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                        onChanged: (v) => syncState(
                                          () => _selectedStockId = v,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      key: const ValueKey('input_op_qty'),
                                      controller: _qtyCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: currentModule ==
                                                PreAccountingOperationModule
                                                    .tepsiKosebentIade
                                            ? 'Kap Adedi'
                                            : 'Miktar',
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  if (currentModule !=
                                      PreAccountingOperationModule
                                          .tepsiKosebentIade) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      key: const ValueKey(
                                        'btn_quick_new_stock_from_workbench',
                                      ),
                                      onPressed: () =>
                                          _showQuickStockModal(popupCtx),
                                      icon: const Icon(
                                        Icons.add_box_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        isMobile ? 'Stok' : '+ Stok Kartı',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],

                            // 6. GİDER GRUBU, BELGE NO & VADE TARİHİ
                            if (isMobile) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _selectedExpenseCat,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'İşlem / Gider Grubu',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final cat in _expenseCategories)
                                    DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    syncState(() => _selectedExpenseCat = v);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: const ValueKey('input_op_doc_no'),
                                      controller: _docNoCtrl,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Belge No (Oto: ${currentModule.docPrefix})',
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  if (_usesDueDate(currentModule)) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      key: const ValueKey('btn_pick_due_date'),
                                      onPressed: () async {
                                        await _pickDueDate(popupCtx);
                                        setPopupState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.event_available,
                                        size: 16,
                                      ),
                                      label: Text(_dueDateKey),
                                    ),
                                  ],
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedExpenseCat,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'İşlem / Gider Grubu',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      items: [
                                        for (final cat in _expenseCategories)
                                          DropdownMenuItem(
                                            value: cat,
                                            child: Text(cat),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          syncState(
                                            () => _selectedExpenseCat = v,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      key: const ValueKey('input_op_doc_no'),
                                      controller: _docNoCtrl,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Fiş / Belge No (Oto: ${currentModule.docPrefix})',
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  if (_usesDueDate(currentModule)) ...[
                                    const SizedBox(width: 10),
                                    OutlinedButton.icon(
                                      key: const ValueKey('btn_pick_due_date'),
                                      onPressed: () async {
                                        await _pickDueDate(popupCtx);
                                        setPopupState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.event_available,
                                        size: 16,
                                      ),
                                      label: Text('Vade: $_dueDateKey'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),

                            // 7. AÇIKLAMA
                            TextField(
                              key: const ValueKey('input_op_desc'),
                              controller: _descCtrl,
                              decoration: InputDecoration(
                                labelText:
                                    '${currentModule.title} Açıklaması / Notu',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),

                            if (currentModule ==
                                PreAccountingOperationModule.puantaj) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(accountingProvider.notifier)
                                        .accrueAllPuantajToLedger();
                                    Navigator.of(popupCtx).pop();
                                  },
                                  icon: const Icon(
                                    Icons.bolt_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    '30 Günlük PDKS Puantaj Hakedişlerini Tek Tıkla Cariye Tahakkuk Ettir',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: pal.border),

                    // POPUP ALT AKSİYON ÇUBUĞU
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(popupCtx).pop(),
                            child: const Text('Vazgeç'),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FilledButton.icon(
                              key: const ValueKey('btn_execute_op_entry_exit'),
                              style: FilledButton.styleFrom(
                                backgroundColor: activeAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _executeCurrentOperation(
                                selectedModule: currentModule,
                                accounts: accounts,
                                stocks: stocks,
                                popupContext: popupCtx,
                              ),
                              icon: Icon(
                                _isIncoming
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.outbox_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _isIncoming
                                    ? '${currentModule.inActionLabel} Kaydet'
                                    : '${currentModule.outActionLabel} Kaydet',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedModule = ref.watch(
      accountingProvider.select((s) => s.selectedOperationModule),
    );
    final accounts = ref.watch(accountingProvider.select((s) => s.accounts));
    final transactions = ref.watch(
      accountingProvider.select((s) => s.transactions),
    );
    final containerMovements = ref.watch(
      accountingProvider.select((s) => s.containerMovements),
    );
    final stocks = ref.watch(
      accountingProvider.select((s) => s.stockBurnItems),
    );
    final checksAndNotes = ref.watch(
      accountingProvider.select((s) => s.checksAndNotes),
    );

    final debtorAccounts = accounts
        .where((a) => a.netBalance != 0 || a.trayBalance > 0)
        .toList(growable: false);

    final moduleTransactions = _filterTransactionsForModule(
      selectedModule,
      transactions,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. SEÇİLİ MODÜLÜN CANLI HAREKET LİSTESİ (TAM GENİŞLİK + HIZLI İŞLEM BUTONU)
        _ModuleLiveHistoryPanel(
          selectedModule: selectedModule,
          transactions: moduleTransactions,
          containerMovements: containerMovements,
          checksAndNotes: checksAndNotes,
          onOpenOperationPopup: ({bool? isIncoming}) => _openEntryExitPopup(
            context,
            initialModule: selectedModule,
            initialIsIncoming: isIncoming,
          ),
        ),
        const SizedBox(height: 16),

        // 2. UYARI - AKSİYON MERKEZİ (Borç Bakiyeleri & Kritik Stok Kalan Gün)
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoCol = constraints.maxWidth >= 820;
            final leftPanel = _DebtorBalancesPanel(accounts: debtorAccounts);
            final rightPanel = _CriticalStockBurnPanel(stocks: stocks);
            if (isTwoCol) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftPanel),
                  const SizedBox(width: 14),
                  Expanded(child: rightPanel),
                ],
              );
            }
            return Column(
              children: [
                leftPanel,
                const SizedBox(height: 14),
                rightPanel,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        HasibuFinanceToolsPanel(
          data: ref.watch(accountingProvider.select((s) => s.advancedViewData)),
          actions: ref.read(accountingProvider.notifier),
        ),
      ],
    );
  }
}

// ============================================================================
// FAZ 1 (SEKME 2): GÜN SONU ÖZETİ & NAKİT / BAKİYE AKIŞI (BAĞIMSIZ BÖLÜM)
// ============================================================================
class AccountingEndOfDaySummaryView extends ConsumerWidget {
  const AccountingEndOfDaySummaryView({super.key});

  Future<void> _pickEndOfDayDate(
    BuildContext context,
    WidgetRef ref,
    String currentDateKey,
  ) async {
    final parts = currentDateKey.split('-');
    DateTime initial = DateTime(2026, 10, 22);
    if (parts.length == 3) {
      initial = DateTime(
        int.tryParse(parts[0]) ?? 2026,
        int.tryParse(parts[1]) ?? 10,
        int.tryParse(parts[2]) ?? 22,
      );
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2032, 12, 31),
      helpText: 'GÜN SONU ÖZETİ TARİHİ SEÇİN',
      cancelText: 'İPTAL',
      confirmText: 'SEÇ',
    );
    if (picked != null && context.mounted) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      ref.read(accountingProvider.notifier).setSelectedDateKey('$y-$m-$d');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cockpit = ref.watch(
      accountingProvider.select((s) => s.cockpitSummary),
    );
    final selectedDateKey = ref.watch(
      accountingProvider.select((s) => s.selectedDateKey),
    );
    final checksAndNotes = ref.watch(
      accountingProvider.select((s) => s.checksAndNotes),
    );
    final pal = HasibuPalette.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. GÜN SONU ÖZETİ ÜST BAŞLIK VE TARİH FİLTRESİ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 20,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gün Sonu Özeti & Nakit / Bakiye Akışı',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Güncel kasa, banka, gelen/giden işlem kırılımları, sarfiyat farkı ve resmi fatura açığı özeti.',
                          style: TextStyle(
                            fontSize: 12,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: const ValueKey('btn_eod_summary_pick_date'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onPressed: () =>
                    _pickEndOfDayDate(context, ref, selectedDateKey),
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: Text('Gün Sonu Tarihi: $selectedDateKey'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. ÖZET KPI KARTLARI (MOBİLDE 2 SÜTUN, MASAÜSTÜNDE 6 SÜTUN)
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 640;
            final isTablet =
                constraints.maxWidth >= 640 && constraints.maxWidth < 1180;
            final double cardWidth = isMobile
                ? (constraints.maxWidth - 10) / 2
                : (isTablet
                    ? (constraints.maxWidth - 20) / 3
                    : (constraints.maxWidth - 50) / 6);
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _CockpitKpiCard(
                  width: cardWidth,
                  title: 'GÜNCEL BAKİYE',
                  value: _fmtTl(cockpit.currentTotalBalance),
                  subtitle: 'Kasa + Banka + Stok + Alacaklar',
                  accentColor: const Color(0xFF0F172A),
                ),
                _CockpitKpiCard(
                  width: cardWidth,
                  title: 'KASADAKİ NAKİT',
                  value: _fmtTl(cockpit.cashOnHand),
                  subtitle:
                      'Son 7 Gün Ort: ${_fmtTl(cockpit.last7DaysCashAverage)}',
                  accentColor: const Color(0xFF059669),
                ),
                _CockpitKpiCard(
                  width: cardWidth,
                  title: 'BAKİYE ARTIŞI',
                  value: _fmtTl(cockpit.dailyBalanceIncrease),
                  subtitle:
                      '↑ + %${cockpit.dailyBalanceIncreasePercent.toStringAsFixed(2)} Günlük Trend',
                  accentColor: const Color(0xFF16A34A),
                ),
                _CockpitKpiCard(
                  width: cardWidth,
                  title: 'GELENLER TOPLAMI',
                  value: _fmtTl(cockpit.totalIncoming),
                  subtitle: 'Kasa + Banka + Satış/Sipariş',
                  accentColor: const Color(0xFF0284C7),
                ),
                _CockpitKpiCard(
                  width: cardWidth,
                  title: 'GİDENLER TOPLAMI',
                  value: _fmtTl(cockpit.totalOutgoing),
                  subtitle: 'Kasa-Banka Ödemeleri & Giderler',
                  accentColor: const Color(0xFFDC2626),
                ),
                _CockpitKpiCard(
                  width: cardWidth,
                  title: 'KALANLAR TOPLAMI',
                  value: _fmtTl(cockpit.netRemainingFlow),
                  subtitle: 'Net Nakit & Banka Akışı',
                  accentColor: const Color(0xFF7C3AED),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),

        // 3. SARFİYAT FARKI & FATURA AÇIĞI KARTLARI
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoCol = constraints.maxWidth >= 760;
            final cardWidth = isTwoCol
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _CockpitAlertBanner(
                    title: 'SARFİYAT FARKI (ÜRETİM REÇETE KONTROLÜ)',
                    value: _fmtTl(cockpit.consumptionVarianceTl),
                    subtitle:
                        'Standart reçete ile fiili hammadde sarfiyatı tam uyumlu',
                    color: const Color(0xFF059669),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _CockpitAlertBanner(
                    title: 'FATURA AÇIĞI (RESMİ FATURA KONTROL RADARI)',
                    value: _fmtTl(cockpit.unbilledInvoiceGapTl),
                    subtitle:
                        'İrsaliyesi sevk edilmiş, e-Faturası kesilecek bakiye',
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),

        // 4. GELEN İŞLEMLER vs GİDEN İŞLEMLER & ÇEKLER/NOTLAR
        _IncomingOutgoingAndChecksSection(
          cockpit: cockpit,
          checksAndNotes: checksAndNotes,
        ),
        const SizedBox(height: 14),
        HasibuEndOfDayAllFlowsPanel(
          data: ref.watch(accountingProvider.select((s) => s.advancedViewData)),
        ),
      ],
    );
  }
}

class _ModuleLiveHistoryPanel extends ConsumerWidget {
  final PreAccountingOperationModule selectedModule;
  final List<AccountingTransaction> transactions;
  final List<ContainerMovement> containerMovements;
  final List<CheckOrAlertNote> checksAndNotes;
  final void Function({bool? isIncoming}) onOpenOperationPopup;

  const _ModuleLiveHistoryPanel({
    required this.selectedModule,
    required this.transactions,
    required this.containerMovements,
    required this.checksAndNotes,
    required this.onOpenOperationPopup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);

    final double totalIn = transactions
        .where((t) => t.direction == 'A' || t.entryType.isIncomingFlow)
        .fold<double>(0.0, (s, t) => s + t.amount);
    final double totalOut = transactions
        .where((t) => t.direction == 'B' && !t.entryType.isIncomingFlow)
        .fold<double>(0.0, (s, t) => s + t.amount);

    final isContainerMod =
        selectedModule == PreAccountingOperationModule.tepsiKosebentIade;
    final isNoteOrAgendaMod =
        selectedModule == PreAccountingOperationModule.ajanda ||
            selectedModule == PreAccountingOperationModule.notlar ||
            selectedModule == PreAccountingOperationModule.kayanYazi ||
            selectedModule == PreAccountingOperationModule.odemeEmirleri;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '${selectedModule.title} • Son Hareketler',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: pal.bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: pal.border),
                    ),
                    child: Text(
                      isContainerMod
                          ? '${containerMovements.length} Kayıt'
                          : (isNoteOrAgendaMod
                              ? '${checksAndNotes.length} Kayıt'
                              : '${transactions.length} Fiş'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pal.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Giriş: ${_fmtTl(totalIn)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Çıkış: ${_fmtTl(totalOut)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('btn_open_entry_exit_popup'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => onOpenOperationPopup(isIncoming: true),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text('${selectedModule.title} Ekle'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18),
          if (isContainerMod) ...[
            if (containerMovements.isEmpty)
              Text(
                'Henüz tepsi / köşebent hareketi bulunmuyor.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              )
            else
              for (final cm in containerMovements.take(7))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${cm.dateKey} • ${cm.accountName} (${cm.containerType}) — ${cm.note}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'Çıkış: ${cm.givenQty} | İade: ${cm.returnedQty}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
          ] else if (isNoteOrAgendaMod) ...[
            if (checksAndNotes.isEmpty)
              Text(
                'Henüz vade / ajanda / not kaydı bulunmuyor.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              )
            else
              for (final chk in checksAndNotes.take(7))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${chk.kind} • ${chk.dueDate}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${chk.titleOrParty} — ${chk.note}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                      if (chk.amount > 0)
                        Text(
                          _fmtTl(chk.amount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
                          ),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        onPressed: () => ref
                            .read(accountingProvider.notifier)
                            .deleteCheckOrNoteItem(chk.id),
                      ),
                    ],
                  ),
                ),
          ] else ...[
            if (transactions.isEmpty)
              Text(
                'Bu işlem grubunda henüz kayıt bulunmuyor. Yeni Giriş / Çıkış İşlemi butonu ile kayıt ekleyebilirsiniz.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              )
            else
              for (final tx in transactions.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (tx.direction == 'A'
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626))
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tx.direction,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: tx.direction == 'A'
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tx.accountName} • ${tx.entryType.label} (${tx.description})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: pal.textPrimary,
                              ),
                            ),
                            Text(
                              '${tx.docNo} • ${tx.dateKey}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: pal.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmtTl(tx.amount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: tx.direction == 'A'
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'Fişi Sil',
                        icon: const Icon(Icons.delete_outline, size: 16),
                        onPressed: () => ref
                            .read(accountingProvider.notifier)
                            .deleteTransaction(tx.id),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _CockpitKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final double? width;

  const _CockpitKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      width: width ?? 235,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: pal.isDark ? Colors.white : accentColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: pal.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CockpitAlertBanner extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _CockpitAlertBanner({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.analytics_outlined, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pal.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: pal.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtorBalancesPanel extends StatelessWidget {
  final List<AccountingAccount> accounts;

  const _DebtorBalancesPanel({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Cari Borç & Emanet Bakiyeleri',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              Text(
                '${accounts.length} Kayıt',
                style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
              ),
            ],
          ),
          const Divider(height: 18),
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sıfır veritabanı aktif: Henüz cari bakiye kaydı bulunmuyor.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
            )
          else
            for (final acc in accounts.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                          if (acc.trayBalance > 0 || acc.crateBalance > 0)
                            Text(
                              'Emanet: ${acc.trayBalance} Tepsi • ${acc.crateBalance} Kasa/Köşebent',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _fmtTl(acc.netBalance),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: acc.netBalance < 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _CriticalStockBurnPanel extends StatelessWidget {
  final List<StockBurnItem> stocks;

  const _CriticalStockBurnPanel({required this.stocks});

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Kritik Stok Radarı (Kalan Gün)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              Text(
                '${stocks.length} Kalem',
                style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
              ),
            ],
          ),
          const Divider(height: 18),
          if (stocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sıfır veritabanı aktif: Henüz stok kartı bulunmuyor.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
            )
          else
            for (final stk in stocks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${stk.name} (${stk.currentQty.toStringAsFixed(0)} ${stk.unit})',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (stk.isCritical
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF059669))
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${stk.remainingDays} Gün',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: stk.isCritical
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _IncomingOutgoingAndChecksSection extends StatelessWidget {
  final EndOfDayCockpitSummary cockpit;
  final List<CheckOrAlertNote> checksAndNotes;

  const _IncomingOutgoingAndChecksSection({
    required this.cockpit,
    required this.checksAndNotes,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gelen / Giden İşlem Kırılımı & Vadeli Çek / Not Uyarıları',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          const Divider(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 700;
              final colWidth = isTwoCol
                  ? (constraints.maxWidth - 24) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GELEN İŞLEMLER',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final e in cockpit.incomingByType.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: pal.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  _fmtTl(e.value),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: pal.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GİDEN İŞLEMLER (ANA GİDER MERKEZLERİ)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final e in cockpit.outgoingByCategory.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: pal.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  _fmtTl(e.value),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: pal.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (checksAndNotes.isNotEmpty) ...[
            const Divider(height: 22),
            for (final item in checksAndNotes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: pal.chip,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${item.kind} • ${item.dueDate}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pal.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.titleOrParty} — ${item.note}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                    if (item.amount > 0)
                      Text(
                        _fmtTl(item.amount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// FAZ 1 (SEKME 2): 31 GÜNLÜK CANLI OTOMATİK PUANTAJ & GMS.NET BORDRO KÖPRÜSÜ
// ============================================================================
class AutoPuantajAndPayrollBridgeView extends ConsumerWidget {
  const AutoPuantajAndPayrollBridgeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(accountingProvider.select((s) => s.puantajRows));
    final periodKey = ref.watch(
      accountingProvider.select((s) => s.selectedPeriodKey),
    );
    final gmsParams = ref.watch(
      accountingProvider.select((s) => s.gmsPayrollParams),
    );
    final banner = ref.watch(accountingProvider.select((s) => s.statusBanner));
    final pal = HasibuPalette.of(context);

    final totalGross = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.grossTotalEarningsTl,
    );
    final totalStatutory = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.totalStatutoryDeductionsTl,
    );
    final totalSpecial = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.totalSpecialDeductionsTl,
    );
    final totalNetBank = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.gmsNetBankPayableTl,
    );
    final totalEmployerCost = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.totalEmployerCostTl,
    );
    final totalTreasurySubsidy = rows.fold<double>(
      0.0,
      (sum, r) => sum + r.sgkTreasurySubsidyTl,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GMS.NET Entegre 30/31 Günlük Puantaj, Tahakkuk, İcmal & Cari Köprüsü ($periodKey)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tenfei D35 (TCP 4370) + QR/GPS • SGK Kanun No (05510/06111/17103) • Eksik Gün (01/06/07) • GV/DV İstisnası • BES (%3) & İcra • X: Tam | FM: Mesai | B: UBGT | T: Tatil | İ: İzin | R: Rapor',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        key: const ValueKey('btn_gms_mahsup_accrue'),
                        onPressed: () => ref
                            .read(accountingProvider.notifier)
                            .accrueGmsIntegratedMahsupToLedger(),
                        icon: const Icon(
                          Icons.integration_instructions_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'GMS.NET Entegre Mahsup Fişi Kes (335/360/361)',
                        ),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('btn_accrue_puantaj_to_ledger'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => ref
                            .read(accountingProvider.notifier)
                            .accrueAllPuantajToLedger(),
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Toplam Ücretleri Personel Hesabına Yaz (Dekont)',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('btn_gms_toggle_net_gross'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => ref
                        .read(accountingProvider.notifier)
                        .toggleGmsNetToGrossMode(),
                    icon: const Icon(Icons.swap_vert_rounded, size: 16),
                    label: Text(
                      gmsParams.isNetToGross
                          ? 'Hesaplama: Netten Brüte (Aktif)'
                          : 'Hesaplama: Brütten Nete (Aktif)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('btn_gms_icmal_dialog'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showGmsIcmalAndMuhsgkDialog(
                      context,
                      periodKey: periodKey,
                      rows: rows,
                    ),
                    icon: const Icon(Icons.table_view_rounded, size: 16),
                    label: const Text(
                      'Bordro İcmal & MUHSGK (1003A/1003B)',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('btn_gms_bank_list_dialog'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showGmsBankSalaryListDialog(
                      context,
                      periodKey: periodKey,
                      rows: rows,
                    ),
                    icon: const Icon(Icons.account_balance_rounded, size: 16),
                    label: const Text(
                      'Banka Maaş & IBAN Ödeme Listesi',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('btn_gms_severance_dialog'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showGmsSeveranceAndNoticeDialog(
                      context,
                      ref,
                      rows: rows,
                    ),
                    icon: const Icon(Icons.gavel_rounded, size: 16),
                    label: const Text(
                      'Kıdem & İhbar Tazminatı Hesapla',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (banner != null && banner.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              banner,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pal.textPrimary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _CockpitKpiCard(
              title: 'PUANTAJ PERSONEL SAYISI',
              value: '${rows.length} Kişi',
              subtitle: '5510 / 6111 / 17103 SGK Kanun takipli',
              accentColor: const Color(0xFF0284C7),
            ),
            _CockpitKpiCard(
              title: 'BRÜT HAKEDİŞ TOPLAMI',
              value: _fmtTl(totalGross),
              subtitle: 'Normal + FM (%50) + UBGT + Yemek/Yol',
              accentColor: const Color(0xFF059669),
            ),
            _CockpitKpiCard(
              title: 'YASAL KESİNTİ (SGK+GV+DV)',
              value: _fmtTl(totalStatutory),
              subtitle: 'Asgari ücret vergi istisnası düşülmüş',
              accentColor: const Color(0xFFD97706),
            ),
            _CockpitKpiCard(
              title: 'ÖZEL KESİNTİ (BES+İCRA+AVANS)',
              value: _fmtTl(totalSpecial),
              subtitle: 'BES %3 + İcra Dairesi + Avans mahsubu',
              accentColor: const Color(0xFFDC2626),
            ),
            _CockpitKpiCard(
              title: 'AVANS DÜŞÜLMÜŞ NET ÖDENECEK',
              value: _fmtTl(totalNetBank),
              subtitle: 'Banka IBAN / Kasa net ödenecek bakiye',
              accentColor: const Color(0xFF7C3AED),
            ),
            _CockpitKpiCard(
              title: 'İŞVERENE TOPLAM MALİYET',
              value: _fmtTl(totalEmployerCost),
              subtitle:
                  'Hazine Teşvik İndirimi: ${_fmtTl(totalTreasurySubsidy)}',
              accentColor: const Color(0xFF0F172A),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final row in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: row.isAccruedToLedger
                    ? const Color(0xFF059669).withValues(alpha: 0.45)
                    : pal.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${row.fullName} (#${row.cardNo})',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: pal.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (row.isAccruedToLedger
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706))
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                row.isAccruedToLedger
                                    ? 'Cariye Tahakkuk Edildi'
                                    : 'Tahakkuk Bekliyor',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: row.isAccruedToLedger
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                            if (row.isEnvelopeSignedByEmployee) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'Portal Pusulası Onaylı',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${row.departmentName} • ${row.salaryType.label} • SGK Gün: ${row.sgkReportedDays}/30 (Eksik: ${row.sgkMissingDays}) | UBGT: ${row.ubgtDays} Gün | FM: ${row.overtimeHours.toStringAsFixed(1)} Saat • GV Dilimi: %${row.incomeTaxBracketPercent}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Brüt: ${_fmtTl(row.grossTotalEarningsTl)} • Net Ödenecek: ${_fmtTl(row.gmsNetBankPayableTl)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: Color(0xFF059669),
                              ),
                            ),
                            Text(
                              'SGK/Vergi: ${_fmtTl(row.totalStatutoryDeductionsTl)} • BES: ${_fmtTl(row.besDeductionTl)} • İcra: ${_fmtTl(row.garnishmentDeduction)} • Avans: ${_fmtTl(row.approvedAdvanceDeduction)}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: pal.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          key: ValueKey('btn_gms_envelope_${row.cardNo}'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => showGmsPayrollEnvelopeDialog(
                            context,
                            ref,
                            row: row,
                            periodKey: periodKey,
                          ),
                          icon: const Icon(Icons.receipt_long_rounded, size: 15),
                          label: const Text(
                            'Bordro Zarfı',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: ValueKey('btn_pay_cash_${row.cardNo}'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => ref
                              .read(accountingProvider.notifier)
                              .payEmployeeSalary(row: row, viaBank: false),
                          icon: const Icon(Icons.payments_outlined, size: 15),
                          label: const Text(
                            'Kasadan Nakit Öde',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: ValueKey('btn_pay_bank_${row.cardNo}'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => ref
                              .read(accountingProvider.notifier)
                              .payEmployeeSalary(row: row, viaBank: true),
                          icon: const Icon(
                            Icons.account_balance_outlined,
                            size: 15,
                          ),
                          label: const Text(
                            'Bankadan Havale',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // GMS.NET KANUN NO, EKSİK GÜN KODU, BES & EK KAZANÇ/İCRA ŞERİDİ
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PopupMenuButton<GmsSgkIncentiveLaw>(
                      tooltip: 'SGK Teşvik Kanun Numarası Seç',
                      onSelected: (law) => ref
                          .read(accountingProvider.notifier)
                          .setEmployeeSgkLaw(row.cardNo, law),
                      itemBuilder: (ctx) => [
                        for (final law in GmsSgkIncentiveLaw.values)
                          PopupMenuItem(
                            value: law,
                            child: Text(
                              law.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                const Color(0xFF0284C7).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'Kanun No: ${row.sgkLaw.code} (Teşvik: ${_fmtTl(row.sgkTreasurySubsidyTl)}) ▾',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<GmsMissingDayReason>(
                      tooltip: 'SGK Eksik Gün Neden Kodu Seç',
                      onSelected: (reason) => ref
                          .read(accountingProvider.notifier)
                          .setEmployeeMissingDayReason(row.cardNo, reason),
                      itemBuilder: (ctx) => [
                        for (final r in GmsMissingDayReason.values)
                          PopupMenuItem(
                            value: r,
                            child: Text(
                              r.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (row.hasSgkCode07AuditWarning
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (row.hasSgkCode07AuditWarning
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B))
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'Eksik Gün Kodu: ${row.missingDayReason.label}${row.hasSgkCode07AuditWarning ? " ⚠️ Kısmi Sözleşme Uyarısı" : ""} ▾',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: row.hasSgkCode07AuditWarning
                                ? const Color(0xFFDC2626)
                                : pal.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      key: ValueKey('chip_gms_bes_${row.cardNo}'),
                      onTap: () => ref
                          .read(accountingProvider.notifier)
                          .toggleEmployeeBesEnrollment(row.cardNo),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (row.besEnrolled
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF64748B))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          row.besEnrolled
                              ? 'BES %3 Aktif (${_fmtTl(row.besDeductionTl)})'
                              : 'BES Pasif (Cayma)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: row.besEnrolled
                                ? const Color(0xFF7C3AED)
                                : pal.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      key: ValueKey('btn_gms_edit_allowances_${row.cardNo}'),
                      onTap: () => _showEditGmsAllowancesDialog(
                        context,
                        ref,
                        row: row,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF059669).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Yemek/Yol/Prim: ${_fmtTl(row.socialBenefitsTotalTl)}${row.garnishmentDeduction > 0 ? " • İcra: ${_fmtTl(row.garnishmentDeduction)}" : ""} ✎',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int d = 1; d <= 30; d++)
                        _PuantajDayCell(
                          cardNo: row.cardNo,
                          day: d,
                          code: row.dayCodes[d] ?? 'X',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PuantajDayCell extends ConsumerWidget {
  final String cardNo;
  final int day;
  final String code;

  const _PuantajDayCell({
    required this.cardNo,
    required this.day,
    required this.code,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color c;
    switch (code) {
      case 'X':
        c = const Color(0xFF059669);
        break;
      case 'FM':
        c = const Color(0xFF7C3AED);
        break;
      case 'B':
        c = const Color(0xFFD97706);
        break;
      case 'T':
        c = const Color(0xFF64748B);
        break;
      case 'İ':
      case 'R':
        c = const Color(0xFF0284C7);
        break;
      default:
        c = const Color(0xFFDC2626);
    }

    return InkWell(
      key: ValueKey('puantaj_cell_${cardNo}_$day'),
      onTap: () => ref
          .read(accountingProvider.notifier)
          .cyclePuantajCellCode(cardNo, day),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 28,
        margin: const EdgeInsets.only(right: 3),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: c.withValues(alpha: 0.85),
              ),
            ),
            Text(
              code,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GMS.NET Resmi Bordro Zarfı (Ücret Pusulası — 4857 Md. 37) Diyaloğu.
void showGmsPayrollEnvelopeDialog(
  BuildContext context,
  WidgetRef ref, {
  required PuantajEmployeeRow row,
  required String periodKey,
}) {
  final pal = HasibuPalette.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('dialog_gms_payroll_envelope'),
      backgroundColor: pal.card,
      title: Text(
        'GMS.NET Resmi Bordro Zarfı (Ücret Pusulası) — $periodKey\n${row.fullName} (#${row.cardNo})',
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: pal.textPrimary,
        ),
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bölüm: ${row.departmentName} (${row.branchName}) • Kanun No: ${row.sgkLaw.code} • Eksik Gün: ${row.missingDayReason.label} • IBAN: ${row.iban}',
                style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
              ),
              const Divider(height: 18),
              _EnvelopeStatLine(
                'Normal Çalışma (${row.payableDays} Gün)',
                _fmtTl(row.baseEarnedPay),
              ),
              _EnvelopeStatLine(
                'Fazla Mesai (${row.overtimeHours.toStringAsFixed(1)} Saat - %50)',
                _fmtTl(row.overtimePay),
              ),
              _EnvelopeStatLine(
                'UBGT Genel Tatil Mesaisi (${row.ubgtDays} Gün)',
                _fmtTl(row.ubgtExtraPay),
              ),
              _EnvelopeStatLine(
                'Yemek + Yol + Prim/İkramiye Sosyal Haklar',
                _fmtTl(row.socialBenefitsTotalTl),
              ),
              _EnvelopeStatLine(
                'TOPLAM BRÜT KAZANÇ',
                _fmtTl(row.grossTotalEarningsTl),
                bold: true,
              ),
              const Divider(height: 16),
              _EnvelopeStatLine(
                'SGK Matrahı (SPEK) / SGK İşçi Payı (%14)',
                '${_fmtTl(row.sgkBaseTl)} / ${_fmtTl(row.sgkWorkerShareTl)}',
              ),
              _EnvelopeStatLine(
                'SGK İşsizlik İşçi Payı (%1)',
                _fmtTl(row.unemploymentWorkerShareTl),
              ),
              _EnvelopeStatLine(
                'Gelir Vergisi (%${row.incomeTaxBracketPercent}) - Asgari Ücret GV İstisnası',
                '${_fmtTl(row.calculatedIncomeTaxTl)} - ${_fmtTl(row.minWageIncomeTaxExemptionTl)} = ${_fmtTl(row.payableIncomeTaxTl)}',
              ),
              _EnvelopeStatLine(
                'Damga Vergisi (%0.759) - DV İstisnası',
                '${_fmtTl(row.calculatedStampTaxTl)} - ${_fmtTl(row.minWageStampTaxExemptionTl)} = ${_fmtTl(row.payableStampTaxTl)}',
              ),
              _EnvelopeStatLine(
                'Bireysel Emeklilik (BES %3) / İcra Kesintisi',
                '${_fmtTl(row.besDeductionTl)} / ${_fmtTl(row.garnishmentDeduction)}',
              ),
              _EnvelopeStatLine(
                'Onaylı Avans Mahsubu',
                _fmtTl(row.approvedAdvanceDeduction),
              ),
              const Divider(height: 16),
              _EnvelopeStatLine(
                'BANKA / KASA NET ÖDENECEK MAAŞ',
                _fmtTl(row.gmsNetBankPayableTl),
                bold: true,
              ),
              _EnvelopeStatLine(
                'SGK İşveren Payı (${row.sgkLaw.code} Teşvikli) / Toplam Maliyet',
                '${_fmtTl(row.sgkEmployerShareTl + row.unemploymentEmployerShareTl)} / ${_fmtTl(row.totalEmployerCostTl)}',
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!row.isEnvelopeSignedByEmployee)
          FilledButton.tonalIcon(
            key: const ValueKey('btn_sign_gms_envelope'),
            onPressed: () {
              ref
                  .read(accountingProvider.notifier)
                  .signEmployeePayrollEnvelope(row.cardNo);
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.verified_rounded, size: 16),
            label: const Text('Bordro Pusulasını Dijital Onayla'),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

class _EnvelopeStatLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _EnvelopeStatLine(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? pal.textPrimary : pal.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: bold ? const Color(0xFF059669) : pal.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

void _showEditGmsAllowancesDialog(
  BuildContext context,
  WidgetRef ref, {
  required PuantajEmployeeRow row,
}) {
  final mealCtrl =
      TextEditingController(text: row.mealAllowanceTl.toStringAsFixed(0));
  final transCtrl =
      TextEditingController(text: row.transportAllowanceTl.toStringAsFixed(0));
  final bonusCtrl =
      TextEditingController(text: row.bonusOrPremiumTl.toStringAsFixed(0));
  final garnCtrl =
      TextEditingController(text: row.garnishmentDeduction.toStringAsFixed(0));
  final fileCtrl = TextEditingController(text: row.garnishmentFileNo ?? '');

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${row.fullName} — GMS.NET Ek Kazanç & İcra Kesintisi'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mealCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Aylık Yemek Yardımı (₺)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: transCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Aylık Yol Yardımı (₺)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bonusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prim / İkramiye / Sosyal Yardım (₺)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: garnCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'İcra / Nafaka Kesintisi Tutarı (₺)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: fileCtrl,
              decoration: const InputDecoration(
                labelText: 'İcra Dairesi & Dosya No',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            ref
                .read(accountingProvider.notifier)
                .updateEmployeeGmsAllowancesAndGarnishment(
                  cardNo: row.cardNo,
                  mealTl: double.tryParse(mealCtrl.text) ?? row.mealAllowanceTl,
                  transportTl: double.tryParse(transCtrl.text) ??
                      row.transportAllowanceTl,
                  bonusTl:
                      double.tryParse(bonusCtrl.text) ?? row.bonusOrPremiumTl,
                  garnishmentTl: double.tryParse(garnCtrl.text) ??
                      row.garnishmentDeduction,
                  garnishmentFileNo: fileCtrl.text,
                );
            Navigator.of(ctx).pop();
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  ).whenComplete(() {
    mealCtrl.dispose();
    transCtrl.dispose();
    bonusCtrl.dispose();
    garnCtrl.dispose();
    fileCtrl.dispose();
  });
}

void _showGmsIcmalAndMuhsgkDialog(
  BuildContext context, {
  required String periodKey,
  required List<PuantajEmployeeRow> rows,
}) {
  final totalBrut =
      rows.fold<double>(0.0, (s, r) => s + r.grossTotalEarningsTl);
  final totalSgkMatrah = rows.fold<double>(0.0, (s, r) => s + r.sgkBaseTl);
  final totalSgkIsci = rows.fold<double>(
    0.0,
    (s, r) => s + r.sgkWorkerShareTl + r.unemploymentWorkerShareTl,
  );
  final totalSgkIsveren = rows.fold<double>(
    0.0,
    (s, r) => s + r.sgkEmployerShareTl + r.unemploymentEmployerShareTl,
  );
  final totalTesvik =
      rows.fold<double>(0.0, (s, r) => s + r.sgkTreasurySubsidyTl);
  final totalGv = rows.fold<double>(0.0, (s, r) => s + r.payableIncomeTaxTl);
  final totalDv = rows.fold<double>(0.0, (s, r) => s + r.payableStampTaxTl);
  final totalBes = rows.fold<double>(0.0, (s, r) => s + r.besDeductionTl);
  final totalNet = rows.fold<double>(0.0, (s, r) => s + r.gmsNetBankPayableTl);
  final totalMaliyet =
      rows.fold<double>(0.0, (s, r) => s + r.totalEmployerCostTl);

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('dialog_gms_icmal_muhsgk'),
      title: Text(
        'GMS.NET Genel Bordro İcmali & MUHSGK (1003A/1003B) Özeti — $periodKey',
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EnvelopeStatLine('Toplam Sigortalı Personel', '${rows.length} Kişi'),
              _EnvelopeStatLine('Toplam Brüt Tahakkuk (720/770)', _fmtTl(totalBrut), bold: true),
              _EnvelopeStatLine('Toplam SGK Matrahı (SPEK)', _fmtTl(totalSgkMatrah)),
              _EnvelopeStatLine('361 - SGK İşçi + İşsizlik Payı (%15)', _fmtTl(totalSgkIsci)),
              _EnvelopeStatLine('361 - SGK İşveren Payı (Teşvik Sonrası)', _fmtTl(totalSgkIsveren)),
              _EnvelopeStatLine('Hazine SGK Teşvik İndirimi (5510/6111/17103)', _fmtTl(totalTesvik)),
              _EnvelopeStatLine('360 - Ödenecek Gelir Vergisi (İstisna Sonrası)', _fmtTl(totalGv)),
              _EnvelopeStatLine('360 - Ödenecek Damga Vergisi (İstisna Sonrası)', _fmtTl(totalDv)),
              _EnvelopeStatLine('335 - BES (%3 Otomatik Katılım) Kesintisi', _fmtTl(totalBes)),
              _EnvelopeStatLine('335 - Personele Net Ödenecek (Banka/Kasa)', _fmtTl(totalNet), bold: true),
              _EnvelopeStatLine('İŞVERENE TOPLAM MALİYET', _fmtTl(totalMaliyet), bold: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

void _showGmsBankSalaryListDialog(
  BuildContext context, {
  required String periodKey,
  required List<PuantajEmployeeRow> rows,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('dialog_gms_bank_list'),
      title: Text(
        'GMS.NET Banka Maaş & IBAN Ödeme Listesi — $periodKey',
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in rows)
                _EnvelopeStatLine(
                  '${r.fullName} (#${r.cardNo}) • ${r.iban}',
                  _fmtTl(r.gmsNetBankPayableTl),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

void _showGmsSeveranceAndNoticeDialog(
  BuildContext context,
  WidgetRef ref, {
  required List<PuantajEmployeeRow> rows,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('dialog_gms_severance'),
      title: const Text(
        'GMS.NET Kıdem & İhbar Tazminatı Hesaplama Modülü (4857 Md. 14 & 17)',
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in rows.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.fullName} (#${r.cardNo}) • Kıdem: ${r.tenureYears} Yıl | İhbar: ${r.noticeWeeksForTenure()} Hafta',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Giydirilmiş Brüt: ${_fmtTl(r.dressedMonthlyGrossTl)} • Net Kıdem: ${_fmtTl(r.calculateSeveranceNet())} • Net İhbar: ${_fmtTl(r.calculateNoticeNet())}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        key: ValueKey('btn_accrue_severance_${r.cardNo}'),
                        onPressed: () {
                          ref
                              .read(accountingProvider.notifier)
                              .accrueSeveranceAndNoticeToExitPayroll(row: r);
                          Navigator.of(ctx).pop();
                        },
                        child: const Text(
                          'Çıkış Bordrosuna Yansıt',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

// ============================================================================
// FAZ 1 (SEKME 3): BİRLEŞİK CARİ KARTLAR, HAREKET DEFTERİ & EMANET KAP TAKİBİ
// ============================================================================
class UnifiedCariLedgerAndContainersView extends ConsumerWidget {
  const UnifiedCariLedgerAndContainersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(
      accountingProvider.select((s) => s.accountTypeFilter),
    );
    final accounts = ref.watch(
      accountingProvider.select((s) => s.filteredAccounts),
    );
    final selectedAcc = ref.watch(
      accountingProvider.select((s) => s.selectedAccount),
    );
    final transactions = ref.watch(
      accountingProvider.select((s) => s.transactions),
    );
    final containers = ref.watch(
      accountingProvider.select((s) => s.containerMovements),
    );
    final pal = HasibuPalette.of(context);

    final selectedTxs = selectedAcc == null
        ? transactions
        : transactions
            .where((t) => t.accountId == selectedAcc.id)
            .toList(growable: false);
    final selectedContainers = selectedAcc == null
        ? containers
        : containers
            .where((c) => c.accountId == selectedAcc.id)
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Tüm Cariler'),
                  selected: filter == 'ALL',
                  onSelected: (_) => ref
                      .read(accountingProvider.notifier)
                      .setAccountTypeFilter('ALL'),
                ),
                for (final t in AccountingAccountType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: filter == t.name,
                    onSelected: (_) => ref
                        .read(accountingProvider.notifier)
                        .setAccountTypeFilter(t.name),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('btn_add_cari_account'),
                  onPressed: () => _showAddCariDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: const Text('Yeni Cari Kart'),
                ),
                if (selectedAcc != null) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('btn_add_container_mov'),
                    onPressed: () =>
                        _showAddContainerDialog(context, ref, selectedAcc),
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('Emanet Tepsi/Kasa İşle'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('btn_add_ledger_tx'),
                    onPressed: () =>
                        _showAddTransactionDialog(context, ref, selectedAcc),
                    icon: const Icon(Icons.post_add_rounded, size: 16),
                    label: const Text('Kasa / Banka / Gider İşle'),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (accounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Text(
              'Kayıtlı cari kart bulunmuyor. "Yeni Cari Kart" ekleyebilir veya Gün Sonu sekmesinden Demo Veri Paketini yükleyebilirsiniz.',
              style: TextStyle(fontSize: 13, color: pal.textSecondary),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final listWidget = Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARİ KART LİSTESİ (${accounts.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: pal.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final acc in accounts)
                      Card(
                        elevation: 0,
                        color: selectedAcc?.id == acc.id
                            ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                            : Colors.transparent,
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          onTap: () => ref
                              .read(accountingProvider.notifier)
                              .selectAccount(acc.id),
                          title: Text(
                            '${acc.name} (${acc.code})',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: pal.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${acc.type.label} • Emanet: ${acc.trayBalance} Tepsi | ${acc.crateBalance} Kasa',
                            style: TextStyle(
                              fontSize: 11,
                              color: pal.textSecondary,
                            ),
                          ),
                          trailing: Text(
                            _fmtTl(acc.netBalance),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: acc.netBalance < 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );

              final detailWidget = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: selectedAcc == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedAcc.name} • CARİ HESAP ÖZETİ & EMANET DEFTERİ',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alacak (A): ${_fmtTl(selectedAcc.creditTotal)} • Borç (B): ${_fmtTl(selectedAcc.debitTotal)} • Net Bakiye: ${_fmtTl(selectedAcc.netBalance)} • Emanet Kalan: ${selectedAcc.trayBalance} Tepsi, ${selectedAcc.crateBalance} Kasa',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pal.textSecondary,
                            ),
                          ),
                          const Divider(height: 20),
                          Text(
                            'FINANSAL HAREKETLER (${selectedTxs.length})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: pal.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final tx in selectedTxs)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (tx.direction == 'A'
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFDC2626))
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${tx.direction} • ${tx.docNo}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: tx.direction == 'A'
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${tx.dateKey} • ${tx.entryType.label} — ${tx.description}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: pal.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _fmtTl(tx.amount),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: pal.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (selectedContainers.isNotEmpty) ...[
                            const Divider(height: 20),
                            Text(
                              'EMANET KAP (TEPSİ / KÖŞEBENT / KASA) HAREKETLERİ (${selectedContainers.length})',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final cm in selectedContainers)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${cm.dateKey} • ${cm.containerType} — ${cm.note}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: pal.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Verilen: ${cm.givenQty} | İade: ${cm.returnedQty} | Kalan: ${cm.netRemaining}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 360, child: listWidget),
                    const SizedBox(width: 14),
                    Expanded(child: detailWidget),
                  ],
                );
              }
              return Column(
                children: [
                  listWidget,
                  const SizedBox(height: 14),
                  detailWidget,
                ],
              );
            },
          ),
        const SizedBox(height: 16),
        HasibuCariCumulativeAndNetStatusPanel(
          data: ref.watch(accountingProvider.select((s) => s.advancedViewData)),
        ),
      ],
    );
  }

  void _showAddCariDialog(BuildContext context, WidgetRef ref) {
    final codeCtrl = TextEditingController(text: 'CARI-501');
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final trayCtrl = TextEditingController(text: '0');
    AccountingAccountType selectedType = AccountingAccountType.customer;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Yeni Cari Kart Ekle'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AccountingAccountType>(
                  initialValue: selectedType,
                  items: [
                    for (final t in AccountingAccountType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedType = v);
                  },
                  decoration: const InputDecoration(labelText: 'Cari Türü'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Cari Kodu'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('input_new_cari_name'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Cari Unvanı / Ad Soyad'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: trayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Açılış Emanet Tepsi Sayısı',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              key: const ValueKey('btn_confirm_new_cari'),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  ref.read(accountingProvider.notifier).addQuickAccount(
                        code: codeCtrl.text,
                        name: nameCtrl.text,
                        type: selectedType,
                        groupName: selectedType.label,
                        phone: phoneCtrl.text,
                        initialTrays: int.tryParse(trayCtrl.text) ?? 0,
                      );
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      codeCtrl.dispose();
      nameCtrl.dispose();
      phoneCtrl.dispose();
      trayCtrl.dispose();
    });
  }

  void _showAddTransactionDialog(
    BuildContext context,
    WidgetRef ref,
    AccountingAccount account,
  ) {
    final amountCtrl = TextEditingController(text: '15000');
    final descCtrl = TextEditingController(text: 'Cari Hesap İşlemi');
    LedgerEntryType selectedType = LedgerEntryType.cashIn;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('${account.name} • Hareket Ekle'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LedgerEntryType>(
                  initialValue: selectedType,
                  items: [
                    for (final e in LedgerEntryType.values)
                      DropdownMenuItem(value: e, child: Text(e.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedType = v);
                  },
                  decoration: const InputDecoration(labelText: 'İşlem Türü'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tutar (₺)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt > 0) {
                  ref
                      .read(accountingProvider.notifier)
                      .addQuickLedgerTransaction(
                        account: account,
                        entryType: selectedType,
                        amount: amt,
                        cashOrBankName: 'Merkez TL Kasa',
                        expenseCategory: 'GENEL İŞLETME',
                        description: descCtrl.text,
                      );
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      amountCtrl.dispose();
      descCtrl.dispose();
    });
  }

  void _showAddContainerDialog(
    BuildContext context,
    WidgetRef ref,
    AccountingAccount account,
  ) {
    final givenCtrl = TextEditingController(text: '25');
    final returnedCtrl = TextEditingController(text: '10');
    final noteCtrl = TextEditingController(text: 'Günlük Tepsi Devri');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${account.name} • Emanet Kap Hareketi'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: givenCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Verilen Tepsi Adedi'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: returnedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'İade Alınan Tepsi Adedi',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Açıklama'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(accountingProvider.notifier).addContainerMovement(
                    account: account,
                    containerType: 'Tepsi',
                    givenQty: int.tryParse(givenCtrl.text) ?? 0,
                    returnedQty: int.tryParse(returnedCtrl.text) ?? 0,
                    note: noteCtrl.text,
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ).whenComplete(() {
      givenCtrl.dispose();
      returnedCtrl.dispose();
      noteCtrl.dispose();
    });
  }
}

// ============================================================================
// FAZ 2 & FAZ 3 (SEKME 4): TEK TIKLA GÖÇ SİHİRBAZI & MAĞAZA SAAS ABONELİK
// ============================================================================
class MigrationWizardAndSaaSStoreView extends ConsumerStatefulWidget {
  const MigrationWizardAndSaaSStoreView({super.key});

  @override
  ConsumerState<MigrationWizardAndSaaSStoreView> createState() =>
      _MigrationWizardAndSaaSStoreViewState();
}

class _MigrationWizardAndSaaSStoreViewState
    extends ConsumerState<MigrationWizardAndSaaSStoreView> {
  late final TextEditingController _csvCtrl;

  @override
  void initState() {
    super.initState();
    _csvCtrl = TextEditingController(
      text:
          '# Format: CARI;KOD;AD;TIP(customer/supplier/branch/employee);ALACAK;BORC;TEPSI;MAAS\n'
          'CARI;GOC-101;KARADENİZ BÖLGE BAYİ LTD.;customer;45000;120000;35;0\n'
          'CARI;GOC-102;TOROSLAR GIDA TEDARİK A.Ş.;supplier;95000;15000;0;0\n'
          '# Format: STOK;KOD;AD;BIRIM;MIKTAR;GUNLUK_TUKETIM;MALIYET\n'
          'STOK;STK-901;FISTIK İÇİ EKSTRA;KG;180;20;1250',
    );
  }

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDemoMode = ref.watch(
      accountingProvider.select((s) => s.isDemoModeActive),
    );
    final banner = ref.watch(accountingProvider.select((s) => s.statusBanner));
    final sub = ref.watch(
      accountingProvider.select((s) => s.subscriptionState),
    );
    final lastMig = ref.watch(
      accountingProvider.select((s) => s.lastMigrationResult),
    );
    final pal = HasibuPalette.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // VERİTABANI MODU & DEMO VERİ PAKETİ YÖNETİMİ (Ayarlar Sayfasına Taşındı)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDemoMode
                  ? const Color(0xFF0284C7).withValues(alpha: 0.45)
                  : const Color(0xFF059669).withValues(alpha: 0.45),
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDemoMode
                        ? Icons.science_outlined
                        : Icons.verified_user_outlined,
                    color: isDemoMode
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF059669),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDemoMode
                              ? 'Aktif Mod: İzole Demo Veri Paketi (Gerçek İşletme Verisi İçermez)'
                              : 'Aktif Mod: %100 Temiz Sıfır Veritabanı (Zero-State)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: pal.textPrimary,
                          ),
                        ),
                        Text(
                          'Uygulama kullanımını test etmek için örnek demo paketiyle inceleyebilir veya tek tıkla sıfır veritabanına geçebilirsiniz.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('btn_switch_clean_zero_db'),
                    onPressed: () => ref
                        .read(accountingProvider.notifier)
                        .switchToCleanZeroDatabase(),
                    icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                    label: const Text('Sıfır Veritabanına Geç (Temizle)'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('btn_load_demo_package'),
                    onPressed: () => ref
                        .read(accountingProvider.notifier)
                        .loadIsolatedDemoPackage(),
                    icon: const Icon(Icons.dataset_outlined, size: 16),
                    label: const Text('Demo Veri Paketini Yükle'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (banner != null && banner.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF059669).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    banner,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // FAZ 3: TEK TIKLA EXCEL / CSV GÖÇ SİHİRBAZI
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAZ 3 • TEK TIKLA EXCEL / CSV GÖÇ SİHİRBAZI (ZERO-FRICTION ONBOARDING)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Eski masaüstü programınızdan (Excel, CSV, Zirve vb.) Cari Kartları, Açılış Bakiyelerini, Emanet Tepsi Sayılarını ve Stokları tek tıkla Hasibu SQLite motoruna aktarın.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('input_legacy_migration_csv'),
                controller: _csvCtrl,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Aktarılacak Cari & Stok Veri Blokları (; ile ayrılmış)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('btn_run_migration_wizard'),
                    onPressed: () => ref
                        .read(accountingProvider.notifier)
                        .runLegacyMigrationWizard(_csvCtrl.text),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Verileri Tek Tıkla Hasibu\'ya Aktar'),
                  ),
                  if (lastMig != null)
                    Text(
                      'Son Aktarım: ${lastMig.accountsImported} Cari, ${lastMig.stocksImported} Stok, ${lastMig.transactionsCreated} Devir Fişi oluşturuldu.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // FAZ 2: APP STORE / PLAY STORE / MICROSOFT STORE SAAS ABONELİK MERKEZİ
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAZ 2 • CROSS-PLATFORM MAĞAZA & SAAS ABONELİK MERKEZİ (DONANIM KANCASI MODELİ)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aktif Dağıtım Kanalı: ${sub.channel.label} (${sub.channel.commissionBadge}) • Donanım Kancası (TCP 4370): Aktif (${sub.trialDaysRemaining} Gün Pro Deneme)',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ch in StoreDistributionChannel.values)
                    ChoiceChip(
                      label: Text('${ch.label} • ${ch.commissionBadge}'),
                      selected: sub.channel == ch,
                      onSelected: (_) => ref
                          .read(accountingProvider.notifier)
                          .updateSaaSSubscription(channel: ch),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final tier in SaaSTier.values)
                    Container(
                      width: 290,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: sub.activeTier == tier
                            ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                            : pal.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sub.activeTier == tier
                              ? const Color(0xFF0284C7)
                              : pal.border,
                          width: sub.activeTier == tier ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tier.monthlyPriceTl == 0
                                ? '0 ₺ / Ay (Ömür Boyu Ücretsiz)'
                                : '${tier.monthlyPriceTl} ₺ / Ay',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tier.featuresSummary,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: pal.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: sub.activeTier == tier
                                ? FilledButton.icon(
                                    key: ValueKey(
                                      'btn_select_tier_${tier.name}',
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${tier.title} paketi halihazırda aktiftir.',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                    ),
                                    label: const Text('Aktif Paket'),
                                  )
                                : OutlinedButton(
                                    key: ValueKey(
                                      'btn_select_tier_${tier.name}',
                                    ),
                                    onPressed: () => ref
                                        .read(accountingProvider.notifier)
                                        .updateSaaSSubscription(tier: tier),
                                    child: const Text('Bu Pakete Geç'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
