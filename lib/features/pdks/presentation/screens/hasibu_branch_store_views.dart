import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/accounting_models.dart';
import '../providers/accounting_providers.dart';

/// Sekme 1: Hasibu Mağaza Dokunmatik POS, Canlı Terazi (`CAS ER JR-CB`),
/// 4 Grup Hızlı Tuşlar, Kutu Gramaj Kalkanı, Askıda Fiş, 5'li Ödeme ve Müşteri Ekranı.
class BranchPosTerminalView extends ConsumerWidget {
  const BranchPosTerminalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(
      accountingProvider.select((s) => s.activeBranchProfile),
    );
    final stores = ref.watch(
      accountingProvider.select((s) => s.branchProfiles),
    );
    final selectedGroup = ref.watch(
      accountingProvider.select((s) => s.selectedPosTabGroup),
    );
    final scaleKg = ref.watch(
      accountingProvider.select((s) => s.liveScaleWeightKg),
    );
    final buttons = ref.watch(
      accountingProvider.select((s) => s.posQuickButtons),
    );
    final cart = ref.watch(accountingProvider.select((s) => s.activePosCart));
    final selectedLineId = ref.watch(
      accountingProvider.select((s) => s.selectedPosCartLineId),
    );
    final suspended = ref.watch(
      accountingProvider.select((s) => s.suspendedPosReceipts),
    );
    final cartTotal = ref.watch(
      accountingProvider.select((s) => s.posCartTotalTl),
    );
    final sweetKg = ref.watch(
      accountingProvider.select((s) => s.posCartSweetWeightKg),
    );
    final boxCount = ref.watch(
      accountingProvider.select((s) => s.posCartBoxCount),
    );
    final boxTareKg = ref.watch(
      accountingProvider.select((s) => s.posCartBoxTareKg),
    );
    final boxAlert = ref.watch(
      accountingProvider.select((s) => s.requiresBoxContainerAlert),
    );
    final statusBanner = ref.watch(
      accountingProvider.select((s) => s.statusBanner),
    );
    final notifier = ref.read(accountingProvider.notifier);

    final groupButtons = buttons
        .where((b) => b.tabGroupIndex == selectedGroup)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (statusBanner != null && statusBanner.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Text(
              statusBanner,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF065F46),
              ),
            ),
          ),

        // Üst Şube Seçici, Terazi (COM2 9600 Baud) & ONLINE / OFFLINE Senkronizasyon Barı
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(
                    Icons.point_of_sale_rounded,
                    color: Color(0xFF2DD4BF),
                    size: 22,
                  ),
                  ...stores.map(
                    (b) => ChoiceChip(
                      selected: b.branchId == store.branchId,
                      label: Text('${b.storeCode} • ${b.storeName}'),
                      onSelected: (_) => notifier.selectBranchStore(b.branchId),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.scale_outlined,
                          size: 16,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${store.scaleModel} (${store.scaleComPort}/${store.scaleBaudRate}): ${scaleKg.toStringAsFixed(3)} KG',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...[0.500, 1.000, 1.500, 2.000].map(
                    (w) => ActionChip(
                      label: Text('${w.toStringAsFixed(1)} Kg'),
                      onPressed: () => notifier.setLiveScaleWeightKg(w),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        notifier.toggleStoreOnlineConnection(store.branchId),
                    style: FilledButton.styleFrom(
                      backgroundColor: store.isOnlineConnected
                          ? const Color(0xFF065F46)
                          : const Color(0xFF991B1B),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      store.isOnlineConnected
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      size: 15,
                    ),
                    label: Text(
                      store.isOnlineConnected ? 'ONLINE' : 'OFFLINE MOD',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: notifier.syncOfflinePosReceiptsToHq,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.sync, size: 15),
                    label: const Text('Merkeze Gönder'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Kutu Gramaj Kontrol Kalkanı (`TepsiFiyatKontrol`)
        if (boxAlert)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MAĞAZA KUTU GRAMAJ UYARISI (TepsiFiyatKontrol): Fişteki tatlı miktarı için yeterli kutu eklenmemiş! "3. KUTU & TEPSİ" sekmesinden tatlı kutusu ekleyerek kutu dara düşümünü kaydedin.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Sol: 4 Sekmeli Hızlı Tuş Matrisi | Sağ: Canlı POS Sepeti & 5'li Ödeme Motoru
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final leftPanel = _buildQuickButtonsPanel(
              context,
              notifier,
              selectedGroup,
              groupButtons,
            );
            final rightPanel = _buildPosCartAndCheckoutPanel(
              context,
              notifier,
              cart,
              selectedLineId,
              suspended,
              cartTotal,
              sweetKg,
              boxCount,
              boxTareKg,
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: leftPanel),
                  const SizedBox(width: 14),
                  Expanded(flex: 5, child: rightPanel),
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
      ],
    );
  }

  Widget _buildQuickButtonsPanel(
    BuildContext context,
    AccountingNotifier notifier,
    int selectedGroup,
    List<BranchPosQuickButton> groupButtons,
  ) {
    const groups = <(int, String)>[
      (1, '1. BAKLAVALAR'),
      (2, '2. DONDURMA & SÜTLÜ'),
      (3, '3. KUTU & TEPSİ (DARA)'),
      (4, '4. İÇECEK & YÖRESEL'),
    ];

    return Card(
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
              'Dokunmatik Hızlı Ürün Tuşları (4 Sekme × 36 = 144 Tuş • Renk & Bedelsiz Atama)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groups
                  .map(
                    (g) => ChoiceChip(
                      selected: selectedGroup == g.$1,
                      label: Text(g.$2),
                      onSelected: (_) => notifier.selectPosTabGroup(g.$1),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: groupButtons
                  .map(
                    (btn) => InkWell(
                      onTap: () => notifier.addQuickButtonToPosCart(btn),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 175,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(btn.colorHex),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '#${btn.slotIndex} • ${btn.stockCode}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                                if (btn.isComplimentaryDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '* Bedelsiz *',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              btn.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              btn.isComplimentaryDefault
                                  ? '0.00 ₺ (${btn.unit})'
                                  : '${btn.unitPriceTl.toStringAsFixed(2)} ₺ / ${btn.unit}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFDE68A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosCartAndCheckoutPanel(
    BuildContext context,
    AccountingNotifier notifier,
    List<BranchPosCartLine> cart,
    String? selectedLineId,
    List<BranchSuspendedReceipt> suspended,
    double cartTotal,
    double sweetKg,
    int boxCount,
    double boxTareKg,
  ) {
    return Card(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aktif Perakende Fişi & Müşteri Ekranı (FIS.repx)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                Text(
                  'TOPLAM: ${cartTotal.toStringAsFixed(2)} ₺',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tatlı: ${sweetKg.toStringAsFixed(3)} Kg • Kutu: $boxCount Adet • Kutu Dara: ${(boxTareKg * 1000).toStringAsFixed(0)} Gr',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const Divider(height: 16),

            if (cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    'Fiş boş — Sol paneldeki hızlı ürün tuşlarına dokunarak satış satırı ekleyin.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ...cart.map(
                (line) => InkWell(
                  onTap: () => notifier.selectPosCartLine(line.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: line.id == selectedLineId
                          ? const Color(0xFFE0F2FE)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: line.id == selectedLineId
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${line.productName} (${line.quantity.toStringAsFixed(line.unit == "KG" ? 3 : 0)} ${line.unit})${line.isComplimentary ? " [* BEDELSİZ *]" : ""}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${line.lineTotalTl.toStringAsFixed(2)} ₺',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),
            // Satır Aksiyonları & Askıda Fiş
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: notifier.toggleSelectedPosLineComplimentary,
                  icon: const Icon(Icons.card_giftcard, size: 15),
                  label: const Text('BEDELSİZ / BEDELLİ Çevir'),
                ),
                OutlinedButton.icon(
                  onPressed: notifier.removeSelectedPosCartLine,
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Seçili Satırı SİL'),
                ),
                OutlinedButton.icon(
                  onPressed: notifier.clearPosCart,
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Yeni Fiş'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => notifier.suspendCurrentPosCart(),
                  icon: const Icon(Icons.pause_circle_outline, size: 15),
                  label: Text('Fişi Askıya Al (${suspended.length})'),
                ),
                if (suspended.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        notifier.recallSuspendedPosReceipt(suspended.first.id),
                    icon: const Icon(Icons.play_circle_outline, size: 15),
                    label: const Text('Askıdan Çağır'),
                  ),
              ],
            ),
            const Divider(height: 20),

            // 5'li POS Ödeme Motoru
            const Text(
              '5\'li POS Ödeme Motoru (OdemeAL_NAKIT / KREDIKART / PARCALI / ACIKHESAP / IADE)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => notifier.completePosCheckout(
                    paymentMethod: BranchPosPaymentMethod.cash,
                    receivedCashOverride: cartTotal + 50.0,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('NAKİT ÖDEME'),
                ),
                FilledButton.icon(
                  onPressed: () => notifier.completePosCheckout(
                    paymentMethod: BranchPosPaymentMethod.creditCard,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  icon: const Icon(Icons.credit_card, size: 16),
                  label: const Text('KREDİ KARTI (POS)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => notifier.completePosCheckout(
                    paymentMethod: BranchPosPaymentMethod.splitCashAndPos,
                  ),
                  icon: const Icon(Icons.call_split, size: 16),
                  label: const Text('PARÇALI ÖDEME (Nakit+POS)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => notifier.completePosCheckout(
                    paymentMethod: BranchPosPaymentMethod.openAccount,
                    customerName: 'KURUMSAL MAĞAZA MÜŞTERİSİ',
                    customerPhone: '0532 000 00 00',
                    note: 'Veresiye / Açık Hesap Fişi',
                  ),
                  icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                  label: const Text('AÇIK HESAP (VERESİYE)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => notifier.completePosCheckout(
                    paymentMethod: BranchPosPaymentMethod.refundReturn,
                  ),
                  icon: const Icon(Icons.keyboard_return, size: 16),
                  label: const Text('İADE ALIM'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sekme 2: Canlı Mağaza Durumları (`Magaza_Canli_Liste`), Merkezden Şubeye Sevk (`Magaza_Sevk_Giris`),
/// Şube Dış Mal Alımı (`Magaza_AlimGiris`) ve Açık Hesap Tahsilatları (`Magaza_AcikHesapListe`).
class BranchLiveStatusAndLogisticsView extends ConsumerWidget {
  const BranchLiveStatusAndLogisticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(
      accountingProvider.select((s) => s.branchProfiles),
    );
    final receipts = ref.watch(
      accountingProvider.select((s) => s.branchPosReceipts),
    );
    final transfers = ref.watch(
      accountingProvider.select((s) => s.branchTransfers),
    );
    final purchases = ref.watch(
      accountingProvider.select((s) => s.branchLocalPurchases),
    );
    final notifier = ref.read(accountingProvider.notifier);

    final openAccountReceipts = receipts
        .where((r) => r.openAccountAmountTl > 0)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        // 1. Canlı Mağaza Durumları (`Magaza_Canli_Liste`)
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
                  '1. Canlı Mağaza Durumları (Magaza_Canli_Liste • Anlık Fiş, Nakit, POS, Açık Hesap & Net Satış)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...stores.map((st) {
                  final stReceipts = receipts
                      .where((r) => r.branchId == st.branchId)
                      .toList();
                  final cashSum = stReceipts.fold<double>(
                    0.0,
                    (s, r) => s + r.cashAmountTl,
                  );
                  final posSum = stReceipts.fold<double>(
                    0.0,
                    (s, r) => s + r.posAmountTl,
                  );
                  final oaSum = stReceipts.fold<double>(
                    0.0,
                    (s, r) => s + r.openAccountAmountTl,
                  );
                  final netSum = cashSum + posSum + oaSum;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          '${st.storeCode} • ${st.storeName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('Fiş: ${stReceipts.length} Adet'),
                        Text('Nakit: ${cashSum.toStringAsFixed(2)} ₺'),
                        Text('POS: ${posSum.toStringAsFixed(2)} ₺'),
                        Text('Açık Hesap: ${oaSum.toStringAsFixed(2)} ₺'),
                        Text(
                          'Net Satış: ${netSum.toStringAsFixed(2)} ₺',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Merkezden Şubeye Sevk (`Magaza_Sevk_Giris`) & Dış Mal Alımı (`Magaza_AlimGiris`)
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    const Text(
                      '2. Mağaza Sevk Fişleri (Magaza_Sevk_Giris • Otomatik Tepsi/Köşebent) & Dış Mal Alım',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => notifier.createBranchShipmentFromHq(
                            targetBranchId: 1,
                            itemsSummary:
                                '20 Tepsi Fıstıklı Baklava + 10 Tepsi Şöbiyet',
                            totalKg: 118.0,
                            trayCount: 30,
                            transferAmountTl: 68500.0,
                            sourceOrderNo: 'SIP-2026-803',
                          ),
                          icon: const Icon(
                            Icons.local_shipping_outlined,
                            size: 16,
                          ),
                          label: const Text('+ Siparişten Şubeye Sevk Kes'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => notifier.recordBranchLocalPurchase(
                            supplierName: 'TRAKYA GÜNLÜK SÜT & KAYMAK',
                            stockName: 'Kahvaltılık Kaymak & Süt',
                            quantity: 10.0,
                            totalAmountTl: 3600.0,
                          ),
                          icon: const Icon(
                            Icons.add_business_outlined,
                            size: 16,
                          ),
                          label: const Text('+ Şube Dış Mal Alımı'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...transfers.map(
                  (tr) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.local_shipping,
                      color: Color(0xFF0F766E),
                    ),
                    title: Text(
                      '${tr.docNo} → ${tr.targetStoreName} (${tr.vehiclePlate})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${tr.itemsSummary} • ${tr.totalKg} Kg • ${tr.trayCount} Tepsi / ${tr.kosebentCount} Köşebent',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: Text(
                      '${tr.transferAmountTl.toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ),
                if (purchases.isNotEmpty) const Divider(),
                ...purchases.map(
                  (p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.shopping_basket_outlined,
                      color: Color(0xFFB45309),
                    ),
                    title: Text(
                      '${p.docNo} • ${p.supplierName} (${p.storeName})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text('${p.stockName} • ${p.quantity} Birim'),
                    trailing: Text(
                      '${p.totalAmountTl.toStringAsFixed(2)} ₺',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Mağaza Açık Hesap Listesi & İskontolu Tahsilat (`Magaza_AcikHesapTahsilatGiris`)
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
                  '3. Mağaza Açık Hesap (Veresiye) Alacakları & İskontolu Tahsilat (Magaza_AcikHesapTahsilatGiris)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (openAccountReceipts.isEmpty)
                  const Text(
                    'Tahsil bekleyen açık hesap mağaza fişi bulunmuyor.',
                  )
                else
                  ...openAccountReceipts.map(
                    (rcp) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${rcp.receiptNo} • ${rcp.customerName.isEmpty ? "Açık Hesap Müşterisi" : rcp.customerName} (${rcp.customerPhone})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text('${rcp.storeName} • ${rcp.itemsSummary}'),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => notifier
                            .collectBranchOpenAccountReceivable(
                              rcp.id,
                              discountTl: 120.0,
                            ),
                        icon: const Icon(Icons.payments_outlined, size: 15),
                        label: Text(
                          'Tahsil Et (${rcp.openAccountAmountTl.toStringAsFixed(0)} ₺)',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sekme 3: Mağaza Gün Sonu İşlemi (`Magaza_GunSonu_Giris`), Kasa Teslim Tutanağı
/// ve Kutu Gramaj / Kutu Dara Denkleştirme (`Magaza_KutuRapor`).
class BranchEndOfDayAndBoxTareView extends ConsumerWidget {
  const BranchEndOfDayAndBoxTareView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(
      accountingProvider.select((s) => s.activeBranchProfile),
    );
    final settlements = ref.watch(
      accountingProvider.select((s) => s.branchEndOfDaySettlements),
    );
    final notifier = ref.read(accountingProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${store.storeName} • Gün Sonu Kasa Teslim Tutanağı & Kutu Dara Denkleştirme',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Mağaza Kasa Teslim Tutanağı (Teslim Eden / Teslim Alan / Şahit) + Tatlı ile tartılan kutu darasını tatlı stoğuna geri ekleme.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          notifier.submitBranchEndOfDayAndCashHandover(
                        actualCountedCashTl: 43100.0,
                        coinCashTl: 450.0,
                        actualPosZReportTl: 78400.0,
                        handedOverBy: store.handingOverCashier,
                        receivedBy: store.receivingManager,
                        witnessName: store.witnessName,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                      ),
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: const Text(
                        'Gün Sonu & Kasa Teslim Tutanağını Onayla',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...settlements.map(
                  (eod) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'KASA TESLİM TUTANAĞI • ${eod.docNo} (${eod.dateKey}) — ${eod.storeName}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Chip(
                              label: Text(
                                eod.transferredToHq
                                    ? 'MERKEZE AKTARILDI'
                                    : 'BEKLİYOR',
                                style: const TextStyle(fontSize: 10.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 18,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Beklenen Kasa: ${eod.expectedDrawerCashTl.toStringAsFixed(2)} ₺',
                            ),
                            Text(
                              'Fiili Nakit + Bozuk Para: ${eod.totalActualCashTl.toStringAsFixed(2)} ₺',
                            ),
                            Text(
                              'Nakit Farkı: ${eod.cashVarianceTl.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: eod.cashVarianceTl >= 0
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFB91C1C),
                              ),
                            ),
                            Text(
                              'POS Z Raporu: ${eod.actualPosZReportTl.toStringAsFixed(2)} ₺ (Fark: ${eod.posVarianceTl.toStringAsFixed(2)} ₺)',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: Color(0xFF047857),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Kutu Gramaj / Dara Denkleştirme (Magaza_KutuRapor): Tatlı ile tartılan +${eod.boxTareRecoveredKg.toStringAsFixed(3)} Kg kutu darası tatlı stoğuna geri eklendi (Kutu Fiyat Farkı Katkısı: +${eod.boxPriceDiffProfitTl.toStringAsFixed(2)} ₺).',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'İmzalar — Teslim Eden: ${eod.handedOverBy} | Teslim Alan: ${eod.receivedBy} | Şahit: ${eod.witnessName}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sekme 4: Mağaza Stok Sayım (`Magaza_StokSayimGiris`), Sarf Malzeme Gider Dekontu,
/// Mağaza Finansal Raporu (`Magaza_FinansalRapor2`) ve Kâr Raporu (`Magaza_KarRapor`).
class BranchStockCountAndFinancialsView extends ConsumerWidget {
  const BranchStockCountAndFinancialsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(
      accountingProvider.select((s) => s.branchProfiles),
    );
    final counts = ref.watch(
      accountingProvider.select((s) => s.branchStockCounts),
    );
    final notifier = ref.read(accountingProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        // 1. Mağaza Finansal Raporu & Kâr Raporu
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
                  '1. Mağaza Finansal Raporu (Magaza_FinansalRapor2) & Kâr Raporu (Magaza_KarRapor)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...stores.map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${s.storeCode} • ${s.storeName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      'Sermaye (Demirbaş+Stok+Kasa): ${s.capitalTl.toStringAsFixed(2)} ₺ | Fabrika Borcu: ${s.factoryDebtTl.toStringAsFixed(2)} ₺',
                    ),
                    trailing: Text(
                      'Net Durum: ${s.netFinancialStandingTl.toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Mağaza Stok Sayım & Otomatik Sarf Malzeme Gider Dekontu
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        '2. Mağaza Stok Sayım & Sarf Malzeme Otomatik Gider Dekontu (Magaza_StokSayimGiderGiris)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => notifier
                          .recordBranchStockCountAndConsumableExpense(
                        stockCode: 'MLZ-KUTU-SET',
                        stockName: 'Ambalaj, Kurdele & Çatal Sarf Paketi',
                        stockGroup: 'MALZEME',
                        systemQty: 120.0,
                        countedQty: 95.0,
                        unitCostTl: 85.0,
                      ),
                      icon: const Icon(Icons.calculate_outlined, size: 16),
                      label: const Text('+ Sayım Farkını Sarf Giderine İşle'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...counts.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${c.stockCode} • ${c.stockName} (${c.stockGroup})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      'Canlı Stok: ${c.systemQty} ${c.unit} → Fiili Sayım: ${c.countedQty} ${c.unit} (Fark: ${c.diffQty.toStringAsFixed(2)} ${c.unit})',
                    ),
                    trailing: Text(
                      c.expensedAsConsumable
                          ? 'Sarf Gideri: ${c.diffCostAmountTl.toStringAsFixed(2)} ₺'
                          : 'Stok Eşitlendi',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: c.expensedAsConsumable
                            ? const Color(0xFFB45309)
                            : const Color(0xFF047857),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sekme 5: 360° Şube Denetim & Kayıp Önleme (Loss Prevention) Merkezi.
/// 5 kritik denetim katmanını tek ekranda sunar.
class BranchAuditAndLossPreventionView extends ConsumerWidget {
  const BranchAuditAndLossPreventionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audits = ref.watch(
      accountingProvider.select((s) => s.branchAuditInspections),
    );
    final notifier = ref.read(accountingProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '360° ŞUBE DENETİM & KAYIP ÖNLEME (LOSS PREVENTION) RASATHANESİ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1) Kasiyer İptal/Bedelsiz Suistimal Radarı • 2) Tepsi-Gramaj-Kutu 3\'lü Fire Mutabakatı • 3) Kör Sayım • 4) PDKS×POS Çapraz Kalkan • 5) Soğuk Zincir (°C)',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => notifier.run360BranchAuditInspection(
                  inspectorName: 'Müfettiş: Merkez İç Denetim Hücresi',
                  blindCashVarianceTl: 0.0,
                  blindStockVarianceTl: 45.0,
                  coldChainTempCelsius: -18.2,
                  hygieneChecklistScore: 97,
                  findingSummary:
                      '360° Kör Sayım, Tepsi-Gramaj-Kutu Dara ve PDKS×POS vardiya eşleşmesi %100 doğrulandı.',
                  actionPlan: 'A+ Tam Mutabakat sertifikası mühürlendi.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
                icon: const Icon(Icons.verified_user_outlined, size: 16),
                label: const Text('+ Yeni 360° Şube Denetimi Çalıştır'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...audits.map(
          (aud) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${aud.auditDocNo} • ${aud.storeName} (${aud.dateKey})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Chip(
                        backgroundColor: aud.overallAuditScore >= 90
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEF3C7),
                        label: Text(
                          'SKOR: ${aud.overallAuditScore}/100 • ${aud.auditGradeBadge}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        '1) İptal/İade: ${aud.cancelledOrRefundCount} | Bedelsiz: ${aud.complimentaryItemCount} (Risk: ${aud.cashierRiskScore})',
                      ),
                      Text(
                        '2) Tepsi Sevk: ${aud.shippedTrayTotalKg} Kg | Kutu Dara: +${aud.boxTareOffsetKg} Kg | Fire Farkı: ${aud.unaccountedFireKg} Kg',
                      ),
                      Text(
                        '3) Kör Kasa Farkı: ${aud.blindCashVarianceTl.toStringAsFixed(0)} ₺ | Kör Stok Farkı: ${aud.blindStockVarianceTl.toStringAsFixed(0)} ₺',
                      ),
                      Text(
                        '4) PDKS Personel: ${aud.pdksCheckedInStaffCount} × POS Kasiyer: ${aud.posActiveCashierCount} (${aud.ghostCashierDetected ? "HAYALET KASİYER UYARISI" : "PDKS×POS UYUMLU"})',
                      ),
                      Text(
                        '5) Soğuk Zincir: ${aud.coldChainTempCelsius}°C | Hijyen: ${aud.hygieneChecklistScore}/100',
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Text(
                    'Denetim Bulgusu: ${aud.findingSummary}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Aksiyon Planı: ${aud.actionPlan} (${aud.inspectorName})',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
