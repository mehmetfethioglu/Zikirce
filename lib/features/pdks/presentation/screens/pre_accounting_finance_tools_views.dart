import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/accounting_models.dart';
import '../../domain/pre_accounting_advanced_contracts.dart';

const List<String> _kDefaultCashAndBankOptions = <String>[
  'Merkez TL Kasa',
  'Şube Nakit Kasa',
  'POS Tahsilat Kasası',
  'Döviz Kasası',
  'Ziraat Ticari Banka',
  'Garanti BBVA Ticari',
];

const List<String> _kFxCashAndBankOptions = <String>[
  'Döviz Kasası',
  'Merkez TL Kasa',
  'Ziraat Ticari Banka',
  'Garanti BBVA Ticari',
];

const String _kDefaultPaymentTemplateBody =
    'Sayın @BankaYetkilisi,\n'
    '@TalimatTarihi tarihli ödeme talimatımız gereği @Unvan hesabına (@IBAN) '
    '@Tutar (@YaziylaTutar) tutarının ödenmesini rica ederiz.\n'
    'Açıklama: @Aciklama';

double _parseDecimalAmount(String raw) {
  final clean = raw.trim().replaceAll(' ', '');
  if (clean.isEmpty) return 0.0;
  final normalized = (clean.contains('.') && clean.contains(','))
      ? clean.replaceAll('.', '').replaceAll(',', '.')
      : clean.replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0.0;
}

void _showInfoSnack(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor:
          isError ? const Color(0xFFB91C1C) : const Color(0xFF047857),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<String?> _pickFormattedDate(
  BuildContext context,
  String currentDateKey,
) async {
  final initial = PreAccountingMathEngine.parseDateKey(currentDateKey);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (picked == null) return null;
  return PreAccountingMathEngine.formatDateKey(picked);
}

List<MaturityCalcRow> _deriveInitialMaturityRows(
  PreAccountingAdvancedViewData data,
) {
  return data.checkPortfolio
      .where(
        (c) =>
            c.status == CheckPortfolioStatus.inPortfolio && c.amountTl > 0.0,
      )
      .map(
        (c) => MaturityCalcRow(
          id: c.id,
          label:
              '${c.serialNo.isNotEmpty ? c.serialNo : c.bordroNo} • ${c.accountName}',
          dueDateKey: c.dueDateKey,
          amountTl: c.amountTl,
        ),
      )
      .toList(growable: false);
}

// =============================================================================
// 1. CANLI TCMB DÖVİZ KURLARI VE KUR BAZLI TAHSİLAT / ÖDEME KARTI
// =============================================================================

/// Canlı TCMB USD/EUR/GBP kurları (fallback rozeti ile) ve Kur Bazlı Tahsilat/Ödeme kartı.
class HasibuLiveFxAndCollectionCard extends StatefulWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const HasibuLiveFxAndCollectionCard({
    super.key,
    required this.data,
    required this.actions,
  });

  @override
  State<HasibuLiveFxAndCollectionCard> createState() =>
      _HasibuLiveFxAndCollectionCardState();
}

class _HasibuLiveFxAndCollectionCardState
    extends State<HasibuLiveFxAndCollectionCard> {
  late final TextEditingController _rateCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;

  String _selectedCurrency = 'USD';
  String? _selectedAccountId;
  String _selectedCashOrBank = _kFxCashAndBankOptions.first;
  bool _isIncoming = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    final initialQuote = _findQuote('USD');
    _rateCtrl = TextEditingController(
      text: (initialQuote?.sellingTl ?? 34.50).toStringAsFixed(4),
    );
    _amountCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _selectedAccountId = widget.data.selectedAccount?.id ??
        (widget.data.accounts.isNotEmpty ? widget.data.accounts.first.id : null);
  }

  @override
  void didUpdateWidget(covariant HasibuLiveFxAndCollectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedAccountId == null ||
        !widget.data.accounts.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = widget.data.selectedAccount?.id ??
          (widget.data.accounts.isNotEmpty
              ? widget.data.accounts.first.id
              : null);
    }
    if (oldWidget.data.currencyRates != widget.data.currencyRates &&
        !_isRefreshing) {
      final q = _findQuote(_selectedCurrency);
      if (q != null && _parseDecimalAmount(_rateCtrl.text) <= 0) {
        _rateCtrl.text = q.sellingTl.toStringAsFixed(4);
      }
    }
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  CurrencyRateQuote? _findQuote(String code) {
    for (final q in widget.data.currencyRates) {
      if (q.code.toUpperCase() == code.toUpperCase()) return q;
    }
    return null;
  }

  void _selectCurrency(String code) {
    final quote = _findQuote(code);
    setState(() {
      _selectedCurrency = code;
      if (quote != null) {
        final rate = _isIncoming ? quote.buyingTl : quote.sellingTl;
        _rateCtrl.text =
            (rate > 0 ? rate : quote.sellingTl).toStringAsFixed(4);
      }
    });
  }

  void _toggleFlowDirection(bool incoming) {
    final quote = _findQuote(_selectedCurrency);
    setState(() {
      _isIncoming = incoming;
      if (quote != null) {
        final rate = incoming ? quote.buyingTl : quote.sellingTl;
        if (rate > 0) {
          _rateCtrl.text = rate.toStringAsFixed(4);
        }
      }
    });
  }

  Future<void> _handleRefreshRates() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await widget.actions.refreshCurrencyRates(forceRefresh: true);
      if (!mounted) return;
      final refreshed = _findQuote(_selectedCurrency);
      if (refreshed != null) {
        final rate = _isIncoming ? refreshed.buyingTl : refreshed.sellingTl;
        _rateCtrl.text =
            (rate > 0 ? rate : refreshed.sellingTl).toStringAsFixed(4);
      }
      _showInfoSnack(context, 'TCMB döviz kurları güncellendi.');
    } catch (error) {
      if (!mounted) return;
      _showInfoSnack(
        context,
        'Kur yenileme sırasında hata oluştu: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _handleSubmitCollection() {
    final account = widget.data.accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
    if (account == null) {
      _showInfoSnack(
        context,
        'Lütfen döviz işlemi için geçerli bir cari seçin.',
        isError: true,
      );
      return;
    }
    final fxRate = _parseDecimalAmount(_rateCtrl.text);
    final fxAmount = _parseDecimalAmount(_amountCtrl.text);
    if (fxRate <= 0 || fxAmount <= 0) {
      _showInfoSnack(
        context,
        'Kur ve döviz tutarı sıfırdan büyük olmalıdır.',
        isError: true,
      );
      return;
    }

    widget.actions.recordFxCollection(
      account: account,
      isIncoming: _isIncoming,
      currencyCode: _selectedCurrency,
      fxRate: fxRate,
      fxAmount: fxAmount,
      cashOrBankName: _selectedCashOrBank,
      description: _descCtrl.text.trim(),
    );

    final tlTotal = fxRate * fxAmount;
    setState(() {
      _amountCtrl.clear();
      _descCtrl.clear();
    });
    _showInfoSnack(
      context,
      '${account.name} için ${fxAmount.toStringAsFixed(2)} $_selectedCurrency '
      '(${PreAccountingMathEngine.formatTl(tlTotal)}) kaydedildi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final quotes = widget.data.currencyRates;
    final hasAnyFallback = quotes.any((q) => q.isFallback);
    final fxRate = _parseDecimalAmount(_rateCtrl.text);
    final fxAmount = _parseDecimalAmount(_amountCtrl.text);
    final previewTl = fxRate * fxAmount;
    final effectiveAccountId =
        widget.data.accounts.any((a) => a.id == _selectedAccountId)
            ? _selectedAccountId
            : (widget.data.accounts.isNotEmpty
                ? widget.data.accounts.first.id
                : null);

    return _FinanceCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeaderRow(
            icon: Icons.currency_exchange_rounded,
            iconColor: const Color(0xFF0284C7),
            title: 'Canlı TCMB Kurları & Dövizli Tahsilat',
            subtitle: 'USD / EUR / GBP anlık kur takibi ve TRY mahsuplaşma',
            trailing: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (quotes.isNotEmpty)
                  _StatusPillBadge(
                    text: hasAnyFallback ? 'Yedek Kur (Fallback)' : 'TCMB Canlı',
                    bgColor: hasAnyFallback
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFECFDF5),
                    fgColor: hasAnyFallback
                        ? const Color(0xFF92400E)
                        : const Color(0xFF047857),
                    icon: hasAnyFallback
                        ? Icons.warning_amber_rounded
                        : Icons.verified_rounded,
                  ),
                FilledButton.tonalIcon(
                  onPressed: _isRefreshing ? null : _handleRefreshRates,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_isRefreshing ? 'Yenileniyor...' : 'Yenile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (quotes.isEmpty)
            const _EmptyStateBox(
              icon: Icons.currency_lira_rounded,
              message:
                  'Henüz kur verisi yüklenmedi. Yenile butonuna basarak TCMB kurlarını çekin.',
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: quotes
                  .map(
                    (quote) => _FxQuoteTile(
                      quote: quote,
                      isSelected: quote.code.toUpperCase() ==
                          _selectedCurrency.toUpperCase(),
                      onTap: () => _selectCurrency(quote.code),
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Döviz Tahsilatı (Giriş - A)'),
                selected: _isIncoming,
                selectedColor: const Color(0xFFD1FAE5),
                onSelected: (_) => _toggleFlowDirection(true),
              ),
              ChoiceChip(
                label: const Text('Döviz Ödemesi (Çıkış - B)'),
                selected: !_isIncoming,
                selectedColor: const Color(0xFFFEE2E2),
                onSelected: (_) => _toggleFlowDirection(false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;
              final accountField = DropdownButtonFormField<String>(
                key: ValueKey('fx_acc_$effectiveAccountId'),
                initialValue: effectiveAccountId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Cari Hesap',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.data.accounts
                    .map(
                      (a) => DropdownMenuItem<String>(
                        value: a.id,
                        child: Text(
                          '${a.code} • ${a.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (val) => setState(() => _selectedAccountId = val),
              );

              final cashBankField = DropdownButtonFormField<String>(
                key: ValueKey('fx_cb_$_selectedCashOrBank'),
                initialValue: _selectedCashOrBank,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kasa / Banka',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _kFxCashAndBankOptions
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCashOrBank = val);
                },
              );

              final currencyField = DropdownButtonFormField<String>(
                key: ValueKey('fx_cur_$_selectedCurrency'),
                initialValue: _selectedCurrency,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Döviz',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: const ['USD', 'EUR', 'GBP']
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (val) {
                  if (val != null) _selectCurrency(val);
                },
              );

              final rateField = TextField(
                controller: _rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'İşlem Kuru (TRY)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              );

              final amountField = TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Tutar ($_selectedCurrency)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              );

              final descField = TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Açıklama / Makbuz Notu',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              );

              if (!isWide) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    accountField,
                    const SizedBox(height: 10),
                    cashBankField,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: currencyField),
                        const SizedBox(width: 8),
                        Expanded(child: rateField),
                      ],
                    ),
                    const SizedBox(height: 10),
                    amountField,
                    const SizedBox(height: 10),
                    descField,
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: accountField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: cashBankField),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(width: 96, child: currencyField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: rateField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: amountField),
                      const SizedBox(width: 10),
                      Expanded(flex: 3, child: descField),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fxAmount.toStringAsFixed(2)} $_selectedCurrency × ${fxRate.toStringAsFixed(4)} = '
                      '${PreAccountingMathEngine.formatTl(previewTl)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (previewTl > 0)
                      Text(
                        PreAccountingMathEngine.amountToTurkishWords(previewTl),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _handleSubmitCollection,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isIncoming
                        ? const Color(0xFF047857)
                        : const Color(0xFFB91C1C),
                  ),
                  icon: Icon(
                    _isIncoming
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _isIncoming
                        ? 'Döviz Tahsilatı Kaydet'
                        : 'Döviz Ödemesi Kaydet',
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

class _FxQuoteTile extends StatelessWidget {
  final CurrencyRateQuote quote;
  final bool isSelected;
  final VoidCallback onTap;

  const _FxQuoteTile({
    required this.quote,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0);
    final bgColor =
        isSelected ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 195,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quote.code,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                _StatusPillBadge(
                  text: quote.isFallback ? 'Fallback' : 'Canlı',
                  bgColor: quote.isFallback
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFD1FAE5),
                  fgColor: quote.isFallback
                      ? const Color(0xFF92400E)
                      : const Color(0xFF065F46),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              quote.label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              'Alış: ${quote.buyingTl.toStringAsFixed(4)} ₺',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF047857),
              ),
            ),
            Text(
              'Satış: ${quote.sellingTl.toStringAsFixed(4)} ₺',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E40AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. AĞIRLIKLI ORTALAMA VADE & ADAT HESAPLAYICI KARTI + DİYALOĞU
// =============================================================================

/// Dinamik ağırlıklı vade/ortalama gün rozeti ve gerçek zamanlı Adat/Vade hesaplayıcı kartı.
class HasibuWeightedMaturityCard extends StatelessWidget {
  final PreAccountingAdvancedViewData data;
  final VoidCallback? onOpenDialog;

  const HasibuWeightedMaturityCard({
    super.key,
    required this.data,
    this.onOpenDialog,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _deriveInitialMaturityRows(data);
    final summary = PreAccountingMathEngine.computeWeightedMaturity(
      baseDateKey: data.selectedDateKey,
      rows: rows,
    );

    return _FinanceCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeaderRow(
            icon: Icons.event_available_rounded,
            iconColor: const Color(0xFF6D28D9),
            title: 'Ağırlıklı Ortalama Vade (Adat)',
            subtitle: 'Portföy çek/senet bazlı anlık ortalama vade gün özeti',
            trailing: _StatusPillBadge(
              text: '${summary.weightedDays.toStringAsFixed(1)} Ort. Gün',
              bgColor: const Color(0xFFF5F3FF),
              fgColor: const Color(0xFF6D28D9),
              icon: Icons.schedule_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DarkMetricBadge(
                  label: 'Baz Tarih',
                  value: summary.baseDateKey,
                  sub: '${summary.rowCount} Portföy Kalemi',
                  color: const Color(0xFF38BDF8),
                ),
                _DarkMetricBadge(
                  label: 'Ortalama Vade Tarihi',
                  value: summary.averageDueDateKey,
                  sub: 'Ağırlıklı: ${summary.weightedDays.toStringAsFixed(2)} Gün',
                  color: const Color(0xFFA78BFA),
                ),
                _DarkMetricBadge(
                  label: 'Portföy Vade Tutarı',
                  value: PreAccountingMathEngine.formatTl(summary.totalAmountTl),
                  sub: 'Anlık Adat Ağırlık Toplamı',
                  color: const Color(0xFF34D399),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (summary.sortedRows.isEmpty)
            const _EmptyStateBox(
              icon: Icons.calculate_outlined,
              message:
                  'Portföyde bekleyen vade satırı bulunmuyor. Hesaplayıcıyı açıp manuel satırlarla Adat hesaplayabilirsiniz.',
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: summary.sortedRows
                  .take(3)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              row.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            row.dueDateKey,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            PreAccountingMathEngine.formatTl(row.amountTl),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onOpenDialog ??
                  () => showHasibuWeightedMaturityDialog(
                        context,
                        initialSummary: summary,
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
              ),
              icon: const Icon(Icons.calculate_rounded, size: 16),
              label: const Text('Adat / Vade Hesaplayıcıyı Aç'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gerçek zamanlı Ağırlıklı Ortalama Vade (Adat) hesaplayıcı modal diyaloğunu açar.
Future<void> showHasibuWeightedMaturityDialog(
  BuildContext context, {
  required MaturitySummary initialSummary,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _WeightedMaturityCalculatorDialog(
      initialSummary: initialSummary,
    ),
  );
}

class _WeightedMaturityCalculatorDialog extends StatefulWidget {
  final MaturitySummary initialSummary;

  const _WeightedMaturityCalculatorDialog({
    required this.initialSummary,
  });

  @override
  State<_WeightedMaturityCalculatorDialog> createState() =>
      _WeightedMaturityCalculatorDialogState();
}

class _WeightedMaturityCalculatorDialogState
    extends State<_WeightedMaturityCalculatorDialog> {
  late final TextEditingController _baseDateCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _dueDateCtrl;
  late final TextEditingController _amountCtrl;
  late List<MaturityCalcRow> _rows;
  int _seq = 1;

  @override
  void initState() {
    super.initState();
    _baseDateCtrl = TextEditingController(
      text: widget.initialSummary.baseDateKey,
    );
    _labelCtrl = TextEditingController();
    _dueDateCtrl = TextEditingController(
      text: PreAccountingMathEngine.formatDateKey(
        PreAccountingMathEngine.parseDateKey(widget.initialSummary.baseDateKey)
            .add(const Duration(days: 30)),
      ),
    );
    _amountCtrl = TextEditingController();
    _rows = List<MaturityCalcRow>.from(widget.initialSummary.sortedRows);
  }

  @override
  void dispose() {
    _baseDateCtrl.dispose();
    _labelCtrl.dispose();
    _dueDateCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _addRow() {
    final amount = _parseDecimalAmount(_amountCtrl.text);
    final dueKey = _dueDateCtrl.text.trim();
    if (amount <= 0 || dueKey.isEmpty) {
      _showInfoSnack(
        context,
        'Geçerli bir vade tarihi (YYYY-AA-GG) ve tutar girin.',
        isError: true,
      );
      return;
    }
    final label = _labelCtrl.text.trim().isEmpty
        ? 'Vade Kalemi #${_seq++}'
        : _labelCtrl.text.trim();
    setState(() {
      _rows.add(
        MaturityCalcRow(
          id: 'mat_${DateTime.now().microsecondsSinceEpoch}_$_seq',
          label: label,
          dueDateKey: dueKey,
          amountTl: amount,
        ),
      );
      _labelCtrl.clear();
      _amountCtrl.clear();
    });
  }

  void _removeRow(String id) {
    setState(() {
      _rows.removeWhere((r) => r.id == id);
    });
  }

  Future<void> _pickDate(TextEditingController target) async {
    final picked = await _pickFormattedDate(context, target.text);
    if (!mounted || picked == null) return;
    setState(() => target.text = picked);
  }

  @override
  Widget build(BuildContext context) {
    final summary = PreAccountingMathEngine.computeWeightedMaturity(
      baseDateKey: _baseDateCtrl.text,
      rows: _rows,
    );
    final baseDt = PreAccountingMathEngine.parseDateKey(_baseDateCtrl.text);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.calculate_rounded, color: Color(0xFF6D28D9)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ağırlıklı Ortalama Vade (Adat) Hesaplayıcı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DarkMetricBadge(
                      label: 'Ortalama Vade Tarihi',
                      value: summary.averageDueDateKey,
                      sub: 'Baz: ${summary.baseDateKey}',
                      color: const Color(0xFFA78BFA),
                    ),
                    _DarkMetricBadge(
                      label: 'Ağırlıklı Ort. Gün',
                      value: '${summary.weightedDays.toStringAsFixed(2)} Gün',
                      sub: '${summary.rowCount} Satır',
                      color: const Color(0xFF38BDF8),
                    ),
                    _DarkMetricBadge(
                      label: 'Toplam Tutar',
                      value: PreAccountingMathEngine.formatTl(
                        summary.totalAmountTl,
                      ),
                      sub: 'Adat Toplamı Bazlı',
                      color: const Color(0xFF34D399),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _baseDateCtrl,
                      decoration: InputDecoration(
                        labelText: 'Baz Tarih (YYYY-AA-GG)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'Tarih Seç',
                          onPressed: () => _pickDate(_baseDateCtrl),
                          icon: const Icon(Icons.date_range_rounded, size: 18),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _rows.clear()),
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Listeyi Temizle'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 210,
                      child: TextField(
                        controller: _labelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Evrak / Çek Açıklaması',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 175,
                      child: TextField(
                        controller: _dueDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Vade (YYYY-AA-GG)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            tooltip: 'Vade Seç',
                            onPressed: () => _pickDate(_dueDateCtrl),
                            icon:
                                const Icon(Icons.date_range_rounded, size: 18),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tutar (TRY)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Satır Ekle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (summary.sortedRows.isEmpty)
                const _EmptyStateBox(
                  icon: Icons.list_alt_rounded,
                  message:
                      'Hesaplama için yukarıdan vade tarihi ve tutar satırı ekleyin.',
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: summary.sortedRows.map((row) {
                    final rowDt =
                        PreAccountingMathEngine.parseDateKey(row.dueDateKey);
                    final diffDays = rowDt.difference(baseDt).inDays;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.label,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Vade: ${row.dueDateKey} ($diffDays gün)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            PreAccountingMathEngine.formatTl(row.amountTl),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Satırı Sil',
                            onPressed: () => _removeRow(row.id),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(growable: false),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

// =============================================================================
// 3. ÇOKLU ÇEK/SENET BORDRO GİRİŞİ VE PORTFÖY DURUM YÖNETİMİ
// =============================================================================

/// Çoklu Çek/Senet bordro giriş formu, durum filtresi ve yaşam döngüsü geçiş paneli.
class HasibuCheckBordroAndLifecyclePanel extends StatefulWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const HasibuCheckBordroAndLifecyclePanel({
    super.key,
    required this.data,
    required this.actions,
  });

  @override
  State<HasibuCheckBordroAndLifecyclePanel> createState() =>
      _HasibuCheckBordroAndLifecyclePanelState();
}

class _HasibuCheckBordroAndLifecyclePanelState
    extends State<HasibuCheckBordroAndLifecyclePanel> {
  late final TextEditingController _bordroNoteCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _dueDateCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _invoiceDocCtrl;

  bool _isIncoming = true;
  String? _selectedAccountId;
  CheckPortfolioStatus? _statusFilter;
  final List<CheckPortfolioItem> _draftChecks = <CheckPortfolioItem>[];
  int _draftCounter = 1;

  @override
  void initState() {
    super.initState();
    _bordroNoteCtrl = TextEditingController();
    _bankCtrl = TextEditingController();
    _serialCtrl = TextEditingController();
    _dueDateCtrl = TextEditingController(
      text: PreAccountingMathEngine.formatDateKey(
        PreAccountingMathEngine.parseDateKey(widget.data.selectedDateKey)
            .add(const Duration(days: 30)),
      ),
    );
    _amountCtrl = TextEditingController();
    _invoiceDocCtrl = TextEditingController();
    _selectedAccountId = widget.data.selectedAccount?.id ??
        (widget.data.accounts.isNotEmpty ? widget.data.accounts.first.id : null);
  }

  @override
  void didUpdateWidget(covariant HasibuCheckBordroAndLifecyclePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedAccountId == null ||
        !widget.data.accounts.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = widget.data.selectedAccount?.id ??
          (widget.data.accounts.isNotEmpty
              ? widget.data.accounts.first.id
              : null);
    }
  }

  @override
  void dispose() {
    _bordroNoteCtrl.dispose();
    _bankCtrl.dispose();
    _serialCtrl.dispose();
    _dueDateCtrl.dispose();
    _amountCtrl.dispose();
    _invoiceDocCtrl.dispose();
    super.dispose();
  }

  AccountingAccount? get _currentAccount {
    return widget.data.accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;
  }

  Future<void> _pickDueDate() async {
    final picked = await _pickFormattedDate(context, _dueDateCtrl.text);
    if (!mounted || picked == null) return;
    setState(() => _dueDateCtrl.text = picked);
  }

  void _addDraftRow() {
    final account = _currentAccount;
    if (account == null) {
      _showInfoSnack(context, 'Lütfen önce bir cari seçin.', isError: true);
      return;
    }
    final bank = _bankCtrl.text.trim();
    final serial = _serialCtrl.text.trim();
    final dueDate = _dueDateCtrl.text.trim();
    final amount = _parseDecimalAmount(_amountCtrl.text);
    if (bank.isEmpty || serial.isEmpty || dueDate.isEmpty || amount <= 0) {
      _showInfoSnack(
        context,
        'Banka, seri no, vade tarihi ve sıfırdan büyük tutar girin.',
        isError: true,
      );
      return;
    }

    setState(() {
      final seq = _draftCounter++;
      _draftChecks.add(
        CheckPortfolioItem(
          id: 'chk_draft_${DateTime.now().microsecondsSinceEpoch}_$seq',
          bordroNo: 'TASLAK-$seq',
          isIncoming: _isIncoming,
          accountId: account.id,
          accountName: account.name,
          bankName: bank,
          serialNo: serial,
          issueDateKey: widget.data.selectedDateKey,
          dueDateKey: dueDate,
          amountTl: amount,
          linkedInvoiceDocNo: _invoiceDocCtrl.text.trim(),
          note: _bordroNoteCtrl.text.trim(),
        ),
      );
      _serialCtrl.clear();
      _amountCtrl.clear();
      _invoiceDocCtrl.clear();
    });
  }

  void _submitBordroBatch() {
    final account = _currentAccount;
    if (account == null) {
      _showInfoSnack(context, 'Bordro için cari seçmelisiniz.', isError: true);
      return;
    }
    if (_draftChecks.isEmpty) {
      _showInfoSnack(
        context,
        'Bordroya en az bir çek veya senet satırı ekleyin.',
        isError: true,
      );
      return;
    }

    final batch = List<CheckPortfolioItem>.from(_draftChecks);
    final total = batch.fold<double>(0.0, (s, c) => s + c.amountTl);
    widget.actions.submitCheckBordroBatch(
      account: account,
      isIncoming: _isIncoming,
      items: batch,
      bordroNote: _bordroNoteCtrl.text.trim(),
    );

    setState(() {
      _draftChecks.clear();
      _bordroNoteCtrl.clear();
    });
    _showInfoSnack(
      context,
      '${batch.length} kalem (${PreAccountingMathEngine.formatTl(total)}) bordro ile kaydedildi.',
    );
  }

  Future<void> _openEndorseDialog(CheckPortfolioItem check) async {
    final candidates = widget.data.accounts
        .where((a) => a.id != check.accountId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      _showInfoSnack(
        context,
        'Ciro için portföyde başka cari hesap bulunmuyor.',
        isError: true,
      );
      return;
    }

    final target = await showDialog<AccountingAccount>(
      context: context,
      builder: (_) => _CheckEndorseTargetDialog(
        check: check,
        accounts: candidates,
      ),
    );
    if (!mounted || target == null) return;
    widget.actions.transitionCheckStatus(
      checkId: check.id,
      nextStatus: CheckPortfolioStatus.endorsed,
      endorseTargetAccount: target,
    );
    _showInfoSnack(
      context,
      '${check.serialNo} nolu evrak ${target.name} carisine ciro edildi.',
    );
  }

  Future<void> _openCashBankSettleDialog(
    CheckPortfolioItem check,
    CheckPortfolioStatus nextStatus,
  ) async {
    final selectedCashBank = await showDialog<String>(
      context: context,
      builder: (_) => _CheckCashBankSettleDialog(
        check: check,
        nextStatus: nextStatus,
      ),
    );
    if (!mounted || selectedCashBank == null) return;
    widget.actions.transitionCheckStatus(
      checkId: check.id,
      nextStatus: nextStatus,
      cashOrBankName: selectedCashBank,
    );
    _showInfoSnack(
      context,
      '${check.serialNo} durumu "${nextStatus.label}" ($selectedCashBank) olarak güncellendi.',
    );
  }

  void _markReturned(CheckPortfolioItem check) {
    widget.actions.transitionCheckStatus(
      checkId: check.id,
      nextStatus: CheckPortfolioStatus.returned,
    );
    _showInfoSnack(
      context,
      '${check.serialNo} nolu evrak "İade Edildi" durumuna geçirildi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final allChecks = widget.data.checkPortfolio;
    final filteredChecks = _statusFilter == null
        ? allChecks
        : allChecks.where((c) => c.status == _statusFilter).toList();
    final draftTotal = _draftChecks.fold<double>(0.0, (s, c) => s + c.amountTl);
    final effectiveAccountId =
        widget.data.accounts.any((a) => a.id == _selectedAccountId)
            ? _selectedAccountId
            : (widget.data.accounts.isNotEmpty
                ? widget.data.accounts.first.id
                : null);

    return _FinanceCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeaderRow(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF0F766E),
            title: 'Çoklu Çek / Senet Bordrosu & Portföy Yaşam Döngüsü',
            subtitle:
                'Toplu bordro girişi, ciro cari seçimi ve tahsil / ödeme / iade geçişleri',
            trailing: _StatusPillBadge(
              text: '${allChecks.length} Kayıt',
              bgColor: const Color(0xFFF0FDFA),
              fgColor: const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(height: 12),
          // Çoklu Bordro Giriş Kutusu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Alınan Çek/Senet Bordrosu'),
                      selected: _isIncoming,
                      selectedColor: const Color(0xFFD1FAE5),
                      onSelected: (_) => setState(() => _isIncoming = true),
                    ),
                    ChoiceChip(
                      label: const Text('Verilen Çek/Senet Bordrosu'),
                      selected: !_isIncoming,
                      selectedColor: const Color(0xFFFEE2E2),
                      onSelected: (_) => setState(() => _isIncoming = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 680;
                    final accDropdown = DropdownButtonFormField<String>(
                      key: ValueKey('chk_acc_$effectiveAccountId'),
                      initialValue: effectiveAccountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Bordro Carisi',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: widget.data.accounts
                          .map(
                            (a) => DropdownMenuItem<String>(
                              value: a.id,
                              child: Text(
                                '${a.code} • ${a.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (val) =>
                          setState(() => _selectedAccountId = val),
                    );
                    final noteField = TextField(
                      controller: _bordroNoteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bordro Genel Notu',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    );
                    if (!isWide) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          accDropdown,
                          const SizedBox(height: 8),
                          noteField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 3, child: accDropdown),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: noteField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 170,
                      child: TextField(
                        controller: _bankCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Banka / Keşideci',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 135,
                      child: TextField(
                        controller: _serialCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Seri / Evrak No',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 165,
                      child: TextField(
                        controller: _dueDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Vade (YYYY-AA-GG)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            tooltip: 'Vade Seç',
                            onPressed: _pickDueDate,
                            icon:
                                const Icon(Icons.date_range_rounded, size: 18),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 135,
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tutar (TRY)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 145,
                      child: TextField(
                        controller: _invoiceDocCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bağlı Fatura No',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _addDraftRow,
                      icon: const Icon(Icons.playlist_add_rounded, size: 17),
                      label: const Text('Bordroya Satır Ekle'),
                    ),
                  ],
                ),
                if (_draftChecks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _draftChecks
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.subdirectory_arrow_right_rounded,
                                  size: 16,
                                  color: Color(0xFF0F766E),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${item.serialNo} • ${item.bankName} • Vade: ${item.dueDateKey}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  PreAccountingMathEngine.formatTl(
                                    item.amountTl,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Taslak Satırı Kaldır',
                                  onPressed: () => setState(
                                    () => _draftChecks.removeWhere(
                                      (d) => d.id == item.id,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Taslak Bordro: ${_draftChecks.length} Evrak • Toplam '
                        '${PreAccountingMathEngine.formatTl(draftTotal)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _submitBordroBatch,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Bordroyu Kaydet'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Durum Filtresi
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text('Tümü (${allChecks.length})'),
                selected: _statusFilter == null,
                onSelected: (_) => setState(() => _statusFilter = null),
              ),
              ...CheckPortfolioStatus.values.map((status) {
                final count =
                    allChecks.where((c) => c.status == status).length;
                return FilterChip(
                  label: Text('${status.label} ($count)'),
                  selected: _statusFilter == status,
                  onSelected: (_) => setState(() => _statusFilter = status),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          if (filteredChecks.isEmpty)
            const _EmptyStateBox(
              icon: Icons.account_balance_wallet_outlined,
              message: 'Seçili filtreye uygun çek veya senet kaydı bulunmuyor.',
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: filteredChecks
                  .map(
                    (check) => _CheckPortfolioRowCard(
                      check: check,
                      onCollect: () => _openCashBankSettleDialog(
                        check,
                        CheckPortfolioStatus.collected,
                      ),
                      onPay: () => _openCashBankSettleDialog(
                        check,
                        CheckPortfolioStatus.paid,
                      ),
                      onEndorse: () => _openEndorseDialog(check),
                      onReturn: () => _markReturned(check),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _CheckPortfolioRowCard extends StatelessWidget {
  final CheckPortfolioItem check;
  final VoidCallback onCollect;
  final VoidCallback onPay;
  final VoidCallback onEndorse;
  final VoidCallback onReturn;

  const _CheckPortfolioRowCard({
    required this.check,
    required this.onCollect,
    required this.onPay,
    required this.onEndorse,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (check.status) {
      CheckPortfolioStatus.inPortfolio => (
          const Color(0xFFDBEAFE),
          const Color(0xFF1E40AF),
        ),
      CheckPortfolioStatus.endorsed => (
          const Color(0xFFF3E8FF),
          const Color(0xFF6B21A8),
        ),
      CheckPortfolioStatus.collected || CheckPortfolioStatus.paid => (
          const Color(0xFFD1FAE5),
          const Color(0xFF065F46),
        ),
      CheckPortfolioStatus.returned => (
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPillBadge(
                    text: check.isIncoming ? 'ALINAN' : 'VERİLEN',
                    bgColor: check.isIncoming
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF2F2),
                    fgColor: check.isIncoming
                        ? const Color(0xFF047857)
                        : const Color(0xFFB91C1C),
                  ),
                  Text(
                    '${check.serialNo} • ${check.bankName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '(${check.bordroNo})',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPillBadge(
                    text: check.status.label,
                    bgColor: bg,
                    fgColor: fg,
                  ),
                  Text(
                    PreAccountingMathEngine.formatTl(check.amountTl),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Cari: ${check.accountName}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
              ),
              Text(
                'Vade: ${check.dueDateKey}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              if (check.endorsedToName.isNotEmpty)
                Text(
                  'Ciro Edilen: ${check.endorsedToName}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B21A8),
                  ),
                ),
              if (check.linkedInvoiceDocNo.isNotEmpty)
                Text(
                  'Fatura: ${check.linkedInvoiceDocNo}',
                  style:
                      const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
            ],
          ),
          if (check.status == CheckPortfolioStatus.inPortfolio ||
              check.status == CheckPortfolioStatus.endorsed) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (check.status == CheckPortfolioStatus.inPortfolio &&
                    check.isIncoming) ...[
                  OutlinedButton.icon(
                    onPressed: onCollect,
                    icon: const Icon(Icons.payments_rounded, size: 15),
                    label: const Text('Tahsil Edildi'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEndorse,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                    label: const Text('Ciro Et'),
                  ),
                ],
                if (check.status == CheckPortfolioStatus.inPortfolio &&
                    !check.isIncoming)
                  OutlinedButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text('Ödendi İşaretle'),
                  ),
                OutlinedButton.icon(
                  onPressed: onReturn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 15),
                  label: const Text('İade Edildi'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckEndorseTargetDialog extends StatefulWidget {
  final CheckPortfolioItem check;
  final List<AccountingAccount> accounts;

  const _CheckEndorseTargetDialog({
    required this.check,
    required this.accounts,
  });

  @override
  State<_CheckEndorseTargetDialog> createState() =>
      _CheckEndorseTargetDialogState();
}

class _CheckEndorseTargetDialogState extends State<_CheckEndorseTargetDialog> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.accounts.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Çek / Senet Ciro Et',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.check.serialNo} • ${widget.check.bankName} • '
              '${PreAccountingMathEngine.formatTl(widget.check.amountTl)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('endorse_$_selectedId'),
              initialValue: _selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ciro Edilecek Hedef Cari',
                border: OutlineInputBorder(),
              ),
              items: widget.accounts
                  .map(
                    (a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(
                        '${a.code} • ${a.name} (${a.type.label})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (val) {
                if (val != null) setState(() => _selectedId = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final chosen =
                widget.accounts.where((a) => a.id == _selectedId).firstOrNull;
            Navigator.of(context).pop(chosen);
          },
          child: const Text('Ciro İşlemini Onayla'),
        ),
      ],
    );
  }
}

class _CheckCashBankSettleDialog extends StatefulWidget {
  final CheckPortfolioItem check;
  final CheckPortfolioStatus nextStatus;

  const _CheckCashBankSettleDialog({
    required this.check,
    required this.nextStatus,
  });

  @override
  State<_CheckCashBankSettleDialog> createState() =>
      _CheckCashBankSettleDialogState();
}

class _CheckCashBankSettleDialogState
    extends State<_CheckCashBankSettleDialog> {
  String _selectedCashOrBank = _kDefaultCashAndBankOptions.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Evrak Durumunu Güncelle: ${widget.nextStatus.label}',
        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.check.serialNo} • ${PreAccountingMathEngine.formatTl(widget.check.amountTl)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('chk_settle_$_selectedCashOrBank'),
              initialValue: _selectedCashOrBank,
              decoration: const InputDecoration(
                labelText: 'İşlem Yapılacak Kasa / Banka',
                border: OutlineInputBorder(),
              ),
              items: _kDefaultCashAndBankOptions
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCashOrBank = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedCashOrBank),
          child: const Text('Onayla'),
        ),
      ],
    );
  }
}

// =============================================================================
// 4. BANKA / KASA ÖDEME TALİMATI ŞABLONLARI VE TALİMAT FİŞİ PANELİ
// =============================================================================

/// Banka/Kasa ödeme talimat şablonu CRUD, talimat fişi oluşturma, canlı yazıyla tutar ve pano kopyalama paneli.
class HasibuPaymentInstructionsPanel extends StatefulWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const HasibuPaymentInstructionsPanel({
    super.key,
    required this.data,
    required this.actions,
  });

  @override
  State<HasibuPaymentInstructionsPanel> createState() =>
      _HasibuPaymentInstructionsPanelState();
}

class _HasibuPaymentInstructionsPanelState
    extends State<HasibuPaymentInstructionsPanel> {
  late final TextEditingController _bankOrCashCtrl;
  late final TextEditingController _ibanCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _dueDateCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _templateBodyCtrl;

  String _kind = 'BANKA';
  String? _selectedTemplateId;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    final firstTpl = widget.data.paymentTemplates.firstOrNull;
    _kind = firstTpl?.kind ?? 'BANKA';
    _selectedTemplateId = firstTpl?.id;
    _bankOrCashCtrl = TextEditingController(
      text: firstTpl?.targetBankOrCashName ?? 'Ziraat Ticari Banka',
    );
    _ibanCtrl = TextEditingController(text: firstTpl?.iban ?? '');
    _amountCtrl = TextEditingController();
    _dueDateCtrl = TextEditingController(text: widget.data.selectedDateKey);
    _noteCtrl = TextEditingController();
    _templateBodyCtrl = TextEditingController(
      text: firstTpl?.templateBody ?? _kDefaultPaymentTemplateBody,
    );
    _selectedAccountId = widget.data.selectedAccount?.id ??
        (widget.data.accounts.isNotEmpty ? widget.data.accounts.first.id : null);
  }

  @override
  void didUpdateWidget(covariant HasibuPaymentInstructionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedAccountId == null ||
        !widget.data.accounts.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = widget.data.selectedAccount?.id ??
          (widget.data.accounts.isNotEmpty
              ? widget.data.accounts.first.id
              : null);
    }
    if (_selectedTemplateId != null &&
        !widget.data.paymentTemplates.any((t) => t.id == _selectedTemplateId)) {
      _selectedTemplateId = widget.data.paymentTemplates.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _bankOrCashCtrl.dispose();
    _ibanCtrl.dispose();
    _amountCtrl.dispose();
    _dueDateCtrl.dispose();
    _noteCtrl.dispose();
    _templateBodyCtrl.dispose();
    super.dispose();
  }

  AccountingAccount? get _currentAccount {
    return widget.data.accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;
  }

  void _applyTemplate(PaymentInstructionTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _kind = template.kind;
      _bankOrCashCtrl.text = template.targetBankOrCashName;
      if (template.iban.isNotEmpty) {
        _ibanCtrl.text = template.iban;
      }
      _templateBodyCtrl.text = template.templateBody;
    });
  }

  Future<void> _openTemplateEditor([PaymentInstructionTemplate? existing]) async {
    final result = await showDialog<PaymentInstructionTemplate>(
      context: context,
      builder: (_) => _PaymentTemplateEditorDialog(initial: existing),
    );
    if (!mounted || result == null) return;
    widget.actions.upsertPaymentTemplate(result);
    _applyTemplate(result);
    _showInfoSnack(context, 'Ödeme talimat şablonu kaydedildi.');
  }

  void _deleteTemplate(PaymentInstructionTemplate template) {
    widget.actions.deletePaymentTemplate(template.id);
    _showInfoSnack(
      context,
      '${template.targetBankOrCashName} şablonu silindi.',
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await _pickFormattedDate(context, _dueDateCtrl.text);
    if (!mounted || picked == null) return;
    setState(() => _dueDateCtrl.text = picked);
  }

  String _renderPreviewText() {
    final accName = _currentAccount?.name ?? 'CARİ SEÇİLMEDİ';
    final amount = _parseDecimalAmount(_amountCtrl.text);
    final raw = PreAccountingMathEngine.renderPaymentInstruction(
      templateBody: _templateBodyCtrl.text,
      dateKey: _dueDateCtrl.text.trim(),
      accountName: accName,
      iban: _ibanCtrl.text.trim(),
      amountTl: amount,
      description: _noteCtrl.text.trim(),
    );
    return raw.replaceAll(
      '@BankaYetkilisi',
      _bankOrCashCtrl.text.trim().isEmpty
          ? 'Banka/Kasa Yetkilisi'
          : '${_bankOrCashCtrl.text.trim()} Yetkilisi',
    );
  }

  Future<void> _copyTextToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showInfoSnack(context, 'Ödeme talimatı metni panoya kopyalandı.');
  }

  void _createOrder({required bool executeImmediately}) {
    final account = _currentAccount;
    if (account == null) {
      _showInfoSnack(context, 'Talimat için cari hesap seçin.', isError: true);
      return;
    }
    final bankOrCash = _bankOrCashCtrl.text.trim();
    final amount = _parseDecimalAmount(_amountCtrl.text);
    final dueDate = _dueDateCtrl.text.trim();
    if (bankOrCash.isEmpty || amount <= 0 || dueDate.isEmpty) {
      _showInfoSnack(
        context,
        'Banka/Kasa adı, vade tarihi ve sıfırdan büyük tutar girin.',
        isError: true,
      );
      return;
    }

    widget.actions.createPaymentOrder(
      kind: _kind,
      bankOrCashName: bankOrCash,
      account: account,
      iban: _ibanCtrl.text.trim(),
      amountTl: amount,
      dueDateKey: dueDate,
      templateBody: _templateBodyCtrl.text,
      note: _noteCtrl.text.trim(),
      executeImmediately: executeImmediately,
    );

    setState(() {
      _amountCtrl.clear();
      _noteCtrl.clear();
    });
    _showInfoSnack(
      context,
      executeImmediately
          ? '${account.name} için talimat oluşturuldu ve ödendi.'
          : '${account.name} için bekleyen ödeme talimatı oluşturuldu.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = widget.data.paymentTemplates;
    final orders = widget.data.paymentOrders;
    final amount = _parseDecimalAmount(_amountCtrl.text);
    final amountWords = PreAccountingMathEngine.amountToTurkishWords(amount);
    final previewText = _renderPreviewText();
    final effectiveAccountId =
        widget.data.accounts.any((a) => a.id == _selectedAccountId)
            ? _selectedAccountId
            : (widget.data.accounts.isNotEmpty
                ? widget.data.accounts.first.id
                : null);

    return _FinanceCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeaderRow(
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF1D4ED8),
            title: 'Banka & Kasa Ödeme Talimatları ve Şablon Yönetimi',
            subtitle:
                'Şablon CRUD, canlı yazıyla tutar çevirimi, panoya kopyala ve bekleyen talimat onayı',
            trailing: FilledButton.tonalIcon(
              onPressed: () => _openTemplateEditor(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Yeni Şablon'),
            ),
          ),
          const SizedBox(height: 12),
          // Şablonlar Şeridi
          if (templates.isEmpty)
            const _EmptyStateBox(
              icon: Icons.description_outlined,
              message:
                  'Kayıtlı ödeme talimat şablonu yok. "Yeni Şablon" ile banka veya kasa şablonu ekleyin.',
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: templates
                  .map(
                    (tpl) => _PaymentTemplateChipCard(
                      template: tpl,
                      isSelected: tpl.id == _selectedTemplateId,
                      onUse: () => _applyTemplate(tpl),
                      onEdit: () => _openTemplateEditor(tpl),
                      onDelete: () => _deleteTemplate(tpl),
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 14),
          // Talimat Oluşturma Formu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('BANKA Talimatı'),
                      selected: _kind == 'BANKA',
                      selectedColor: const Color(0xFFDBEAFE),
                      onSelected: (_) => setState(() => _kind = 'BANKA'),
                    ),
                    ChoiceChip(
                      label: const Text('KASA Talimatı'),
                      selected: _kind == 'KASA',
                      selectedColor: const Color(0xFFD1FAE5),
                      onSelected: (_) => setState(() => _kind = 'KASA'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 680;
                    final accountField = DropdownButtonFormField<String>(
                      key: ValueKey('pay_acc_$effectiveAccountId'),
                      initialValue: effectiveAccountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Lehtar Cari',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: widget.data.accounts
                          .map(
                            (a) => DropdownMenuItem<String>(
                              value: a.id,
                              child: Text(
                                '${a.code} • ${a.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (val) =>
                          setState(() => _selectedAccountId = val),
                    );
                    final bankCashField = TextField(
                      controller: _bankOrCashCtrl,
                      decoration: InputDecoration(
                        labelText:
                            _kind == 'BANKA' ? 'Talimat Banka Adı' : 'Kasa Adı',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    );
                    final ibanField = TextField(
                      controller: _ibanCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Alıcı IBAN',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    );
                    final amountField = TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tutar (TRY)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    );
                    final dateField = TextField(
                      controller: _dueDateCtrl,
                      decoration: InputDecoration(
                        labelText: 'Talimat / Vade Tarihi',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'Tarih Seç',
                          onPressed: _pickDueDate,
                          icon: const Icon(Icons.date_range_rounded, size: 18),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    );
                    final noteField = TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Talimat Açıklaması',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    );

                    if (!isWide) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          accountField,
                          const SizedBox(height: 8),
                          bankCashField,
                          const SizedBox(height: 8),
                          ibanField,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: amountField),
                              const SizedBox(width: 8),
                              Expanded(child: dateField),
                            ],
                          ),
                          const SizedBox(height: 8),
                          noteField,
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(flex: 3, child: accountField),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: bankCashField),
                            const SizedBox(width: 10),
                            Expanded(flex: 3, child: ibanField),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(flex: 2, child: amountField),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: dateField),
                            const SizedBox(width: 10),
                            Expanded(flex: 4, child: noteField),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _templateBodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText:
                        'Talimat Metin Şablonu (@TalimatTarihi, @Unvan, @IBAN, @Tutar, @YaziylaTutar, @Aciklama)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yazıyla Tutar: $amountWords',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        previewText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyTextToClipboard(previewText),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Panoya Kopyala'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _createOrder(executeImmediately: false),
                      icon: const Icon(Icons.pending_actions_rounded, size: 16),
                      label: const Text('Bekleyen Talimat Oluştur'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _createOrder(executeImmediately: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Oluştur & Gerçekleştir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Talimat Fişleri & Onay Kuyruğu',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            const _EmptyStateBox(
              icon: Icons.assignment_outlined,
              message: 'Henüz kayıtlı ödeme talimat fişi bulunmuyor.',
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: orders
                  .map(
                    (order) => _PaymentOrderRowCard(
                      order: order,
                      onCopy: () =>
                          _copyTextToClipboard(order.renderedInstruction),
                      onExecute: () {
                        widget.actions.executePendingPaymentOrder(order.id);
                        _showInfoSnack(
                          context,
                          '${order.orderNo} talimatı onaylandı ve ödendi.',
                        );
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _PaymentTemplateChipCard extends StatelessWidget {
  final PaymentInstructionTemplate template;
  final bool isSelected;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentTemplateChipCard({
    required this.template,
    required this.isSelected,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 265,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPillBadge(
                text: template.kind,
                bgColor: template.kind == 'BANKA'
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFD1FAE5),
                fgColor: template.kind == 'BANKA'
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFF065F46),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  template.targetBankOrCashName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (template.iban.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              template.iban,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onUse,
                child: const Text('Kullan', style: TextStyle(fontSize: 12)),
              ),
              IconButton(
                tooltip: 'Şablonu Düzenle',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
              ),
              IconButton(
                tooltip: 'Şablonu Sil',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentOrderRowCard extends StatelessWidget {
  final PaymentOrderRecord order;
  final VoidCallback onCopy;
  final VoidCallback onExecute;

  const _PaymentOrderRowCard({
    required this.order,
    required this.onCopy,
    required this.onExecute,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = order.status.toUpperCase() == 'ODENDI';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPillBadge(
                    text: order.kind,
                    bgColor: const Color(0xFFF1F5F9),
                    fgColor: const Color(0xFF334155),
                  ),
                  Text(
                    '${order.orderNo} • ${order.accountName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPillBadge(
                    text: isPaid ? 'ÖDENDİ' : 'BEKLİYOR',
                    bgColor: isPaid
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEF3C7),
                    fgColor: isPaid
                        ? const Color(0xFF065F46)
                        : const Color(0xFF92400E),
                  ),
                  Text(
                    PreAccountingMathEngine.formatTl(order.amountTl),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.bankOrCashName} • Vade: ${order.dueDateKey}'
            '${order.iban.isNotEmpty ? " • ${order.iban}" : ""}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
          ),
          if (order.renderedInstruction.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              order.renderedInstruction,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Panoya Kopyala'),
              ),
              if (!isPaid)
                FilledButton.icon(
                  onPressed: onExecute,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 15),
                  label: const Text('Onayla & Gerçekleştir'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentTemplateEditorDialog extends StatefulWidget {
  final PaymentInstructionTemplate? initial;

  const _PaymentTemplateEditorDialog({this.initial});

  @override
  State<_PaymentTemplateEditorDialog> createState() =>
      _PaymentTemplateEditorDialogState();
}

class _PaymentTemplateEditorDialogState
    extends State<_PaymentTemplateEditorDialog> {
  late final TextEditingController _bankOrCashCtrl;
  late final TextEditingController _ibanCtrl;
  late final TextEditingController _bodyCtrl;
  late String _kind;

  @override
  void initState() {
    super.initState();
    _kind = widget.initial?.kind ?? 'BANKA';
    _bankOrCashCtrl = TextEditingController(
      text: widget.initial?.targetBankOrCashName ?? '',
    );
    _ibanCtrl = TextEditingController(text: widget.initial?.iban ?? '');
    _bodyCtrl = TextEditingController(
      text: widget.initial?.templateBody ?? _kDefaultPaymentTemplateBody,
    );
  }

  @override
  void dispose() {
    _bankOrCashCtrl.dispose();
    _ibanCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _bankOrCashCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (name.isEmpty || body.isEmpty) {
      _showInfoSnack(
        context,
        'Banka/Kasa adı ve şablon gövdesi zorunludur.',
        isError: true,
      );
      return;
    }
    final tpl = PaymentInstructionTemplate(
      id: widget.initial?.id ??
          'ptpl_${DateTime.now().microsecondsSinceEpoch}',
      kind: _kind,
      targetBankOrCashName: name,
      iban: _ibanCtrl.text.trim(),
      templateBody: body,
    );
    Navigator.of(context).pop(tpl);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? 'Yeni Ödeme Talimat Şablonu'
            : 'Ödeme Talimat Şablonunu Düzenle',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('BANKA'),
                    selected: _kind == 'BANKA',
                    onSelected: (_) => setState(() => _kind = 'BANKA'),
                  ),
                  ChoiceChip(
                    label: const Text('KASA'),
                    selected: _kind == 'KASA',
                    onSelected: (_) => setState(() => _kind = 'KASA'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bankOrCashCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hedef Banka / Kasa Adı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ibanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Varsayılan IBAN (Opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Şablon Metni',
                  helperText:
                      'Yer tutucular: @TalimatTarihi, @Unvan, @IBAN, @Tutar, @YaziylaTutar, @Aciklama',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Şablonu Kaydet'),
        ),
      ],
    );
  }
}

// =============================================================================
// 5. KÜMÜLATİF YÜRÜYEN BAKİYELİ KASA & BANKA FÖYLERİ KARTI
// =============================================================================

/// Tam satırlı Kasa & Banka hareket föyleri ve yürüyen kümülatif bakiye kartı.
class HasibuCumulativeCashBankLedgersCard extends StatefulWidget {
  final PreAccountingAdvancedViewData data;

  const HasibuCumulativeCashBankLedgersCard({
    super.key,
    required this.data,
  });

  @override
  State<HasibuCumulativeCashBankLedgersCard> createState() =>
      _HasibuCumulativeCashBankLedgersCardState();
}

class _HasibuCumulativeCashBankLedgersCardState
    extends State<HasibuCumulativeCashBankLedgersCard> {
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;
  String? _selectedCashOrBankFilter;
  int _activeTab = 0; // 0: Kasa, 1: Banka

  @override
  void initState() {
    super.initState();
    _startDateCtrl = TextEditingController();
    _endDateCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFilterDate(TextEditingController ctrl) async {
    final fallback =
        ctrl.text.trim().isNotEmpty ? ctrl.text : widget.data.selectedDateKey;
    final picked = await _pickFormattedDate(context, fallback);
    if (!mounted || picked == null) return;
    setState(() => ctrl.text = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cashOrBankNames = widget.data.transactions
        .map((t) => t.cashOrBankName.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final cashLedger = PreAccountingMathEngine.buildCumulativeLedger(
      transactions: widget.data.transactions,
      startDateKey: _startDateCtrl.text.trim(),
      endDateKey: _endDateCtrl.text.trim(),
      cashOrBankFilter: _selectedCashOrBankFilter,
      entryTypeFilter: const {
        LedgerEntryType.cashIn,
        LedgerEntryType.cashOut,
      },
    );

    final bankLedger = PreAccountingMathEngine.buildCumulativeLedger(
      transactions: widget.data.transactions,
      startDateKey: _startDateCtrl.text.trim(),
      endDateKey: _endDateCtrl.text.trim(),
      cashOrBankFilter: _selectedCashOrBankFilter,
      entryTypeFilter: const {
        LedgerEntryType.bankIn,
        LedgerEntryType.bankOut,
      },
    );

    final activeLedger = _activeTab == 0 ? cashLedger : bankLedger;
    final activeTitle = _activeTab == 0
        ? 'Kasa Hareket Föyü (Yürüyen Bakiyeli)'
        : 'Banka Hareket Föyü (Yürüyen Bakiyeli)';

    return _FinanceCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeaderRow(
            icon: Icons.table_rows_rounded,
            iconColor: const Color(0xFF0F172A),
            title: 'Kasa & Banka Kümülatif Hareket Föyleri',
            subtitle:
                'Tarih • Fiş • Açıklama • Borç • Alacak • Yürüyen Bakiye tam satır dökümü',
            trailing: SegmentedButton<int>(
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  icon: const Icon(Icons.point_of_sale_rounded, size: 15),
                  label: Text('Kasa (${cashLedger.rows.length})'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: const Icon(Icons.account_balance_rounded, size: 15),
                  label: Text('Banka (${bankLedger.rows.length})'),
                ),
              ],
              selected: <int>{_activeTab},
              onSelectionChanged: (sel) =>
                  setState(() => _activeTab = sel.first),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _startDateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Başlangıç Tarihi',
                    hintText: 'YYYY-AA-GG',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: 'Tarih Seç',
                      onPressed: () => _pickFilterDate(_startDateCtrl),
                      icon: const Icon(Icons.date_range_rounded, size: 17),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _endDateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Bitiş Tarihi',
                    hintText: 'YYYY-AA-GG',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: 'Tarih Seç',
                      onPressed: () => _pickFilterDate(_endDateCtrl),
                      icon: const Icon(Icons.date_range_rounded, size: 17),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('ledger_cb_$_selectedCashOrBankFilter'),
                  initialValue: cashOrBankNames.contains(_selectedCashOrBankFilter)
                      ? _selectedCashOrBankFilter
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kasa / Banka Filtresi',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tüm Kasa / Bankalar'),
                    ),
                    ...cashOrBankNames.map(
                      (name) => DropdownMenuItem<String?>(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedCashOrBankFilter = val),
                ),
              ),
              if (_startDateCtrl.text.isNotEmpty ||
                  _endDateCtrl.text.isNotEmpty ||
                  _selectedCashOrBankFilter != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _startDateCtrl.clear();
                      _endDateCtrl.clear();
                      _selectedCashOrBankFilter = null;
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Filtreyi Sıfırla'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _CumulativeLedgerTableSection(
            title: activeTitle,
            openingBalanceTl: activeLedger.openingBalanceTl,
            rows: activeLedger.rows,
          ),
        ],
      ),
    );
  }
}

class _CumulativeLedgerTableSection extends StatelessWidget {
  final String title;
  final double openingBalanceTl;
  final List<CumulativeLedgerRow> rows;

  const _CumulativeLedgerTableSection({
    required this.title,
    required this.openingBalanceTl,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final totalDebit = rows.fold<double>(0.0, (s, r) => s + r.debitTl);
    final totalCredit = rows.fold<double>(0.0, (s, r) => s + r.creditTl);
    final closingBalance =
        rows.isNotEmpty ? rows.last.runningBalanceTl : openingBalanceTl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    'Devir: ${PreAccountingMathEngine.formatTl(openingBalanceTl)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    'Borç (Çıkış): ${PreAccountingMathEngine.formatTl(totalDebit)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  Text(
                    'Alacak (Giriş): ${PreAccountingMathEngine.formatTl(totalCredit)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
                  Text(
                    'Kümülatif Bakiye: ${PreAccountingMathEngine.formatTl(closingBalance)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: closingBalance >= 0
                          ? const Color(0xFF047857)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const _EmptyStateBox(
            icon: Icons.receipt_outlined,
            message: 'Seçili kasa/banka ve tarih filtresinde hareket yok.',
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 760),
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 54,
                horizontalMargin: 10,
                columnSpacing: 16,
                headingRowColor:
                    const WidgetStatePropertyAll(Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('Tarih')),
                  DataColumn(label: Text('Fiş No')),
                  DataColumn(label: Text('Kasa / Banka')),
                  DataColumn(label: Text('Açıklama')),
                  DataColumn(label: Text('Borç (Çıkış)'), numeric: true),
                  DataColumn(label: Text('Alacak (Giriş)'), numeric: true),
                  DataColumn(label: Text('Yürüyen Bakiye'), numeric: true),
                ],
                rows: rows
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(
                            Text(
                              r.dateKey,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.docNo,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.cashOrBankName,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 230),
                              child: Text(
                                r.description,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.debitTl > 0
                                  ? PreAccountingMathEngine.formatTl(r.debitTl)
                                  : '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: r.debitTl > 0
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.creditTl > 0
                                  ? PreAccountingMathEngine.formatTl(r.creditTl)
                                  : '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: r.creditTl > 0
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              PreAccountingMathEngine.formatTl(
                                r.runningBalanceTl,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: r.runningBalanceTl >= 0
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// 6. GÜN SONU 9'LU TÜM GELEN / GİDEN AKIŞLAR PANELİ
// =============================================================================

/// Gün sonu 9'lu kırılım (EodBucketClassifier) gelen/giden akış özeti paneli.
class HasibuEndOfDayAllFlowsPanel extends StatefulWidget {
  final PreAccountingAdvancedViewData data;

  const HasibuEndOfDayAllFlowsPanel({
    super.key,
    required this.data,
  });

  @override
  State<HasibuEndOfDayAllFlowsPanel> createState() =>
      _HasibuEndOfDayAllFlowsPanelState();
}

class _HasibuEndOfDayAllFlowsPanelState
    extends State<HasibuEndOfDayAllFlowsPanel> {
  bool _includeAllDates = false;

  @override
  Widget build(BuildContext context) {
    final breakdown = EodBucketClassifier.classify(
      dateKey: _includeAllDates ? '' : widget.data.selectedDateKey,
      transactions: widget.data.transactions,
    );

    return _FinanceCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeaderRow(
            icon: Icons.analytics_rounded,
            iconColor: const Color(0xFF047857),
            title: 'Gün Sonu 9\'lu Gelen / Giden Akış Kırılımı',
            subtitle: _includeAllDates
                ? 'Tüm dönem işlem kırılımları (${widget.data.selectedPeriodKey})'
                : 'Seçili gün akışları (${widget.data.selectedDateKey})',
            trailing: SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text(widget.data.selectedDateKey),
                ),
                const ButtonSegment<bool>(
                  value: true,
                  label: Text('Tüm Dönem'),
                ),
              ],
              selected: <bool>{_includeAllDates},
              onSelectionChanged: (sel) =>
                  setState(() => _includeAllDates = sel.first),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DarkMetricBadge(
                  label: 'Toplam Gelen Akış',
                  value: PreAccountingMathEngine.formatTl(
                    breakdown.totalIncomingTl,
                  ),
                  sub: 'Nakit + Banka + Perakende Satış',
                  color: const Color(0xFF34D399),
                ),
                _DarkMetricBadge(
                  label: 'Toplam Giden Akış',
                  value: PreAccountingMathEngine.formatTl(
                    breakdown.totalOutgoingTl,
                  ),
                  sub: 'Alım + Üretim + Lojistik + Personel + Gider',
                  color: const Color(0xFFF43F5E),
                ),
                _DarkMetricBadge(
                  label: 'Net Gün Sonu Akışı',
                  value: PreAccountingMathEngine.formatTl(breakdown.netFlowTl),
                  sub: breakdown.netFlowTl >= 0
                      ? 'Pozitif Net Nakit/Finans Akışı'
                      : 'Negatif Net Nakit/Finans Akışı',
                  color: breakdown.netFlowTl >= 0
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFFFBBF24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 3
                  : (constraints.maxWidth >= 600 ? 2 : 1);
              final spacing = 10.0;
              final tileWidth =
                  (constraints.maxWidth - (columns - 1) * spacing) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: breakdown.buckets
                    .map(
                      (bucket) => SizedBox(
                        width: tileWidth,
                        child: _EodFlowBucketCard(bucket: bucket),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EodFlowBucketCard extends StatelessWidget {
  final EodFlowBucket bucket;

  const _EodFlowBucketCard({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final accent = bucket.isIncoming
        ? const Color(0xFF047857)
        : const Color(0xFFB91C1C);
    final softBg = bucket.isIncoming
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFEF2F2);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Row(
            children: [
              _StatusPillBadge(
                text: bucket.isIncoming ? 'GELEN' : 'GİDEN',
                bgColor: softBg,
                fgColor: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bucket.title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${bucket.count} İşlem',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  PreAccountingMathEngine.formatTl(bucket.totalAmountTl),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          children: bucket.items.isEmpty
              ? const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bu akış kırılımında hareket kaydı bulunmuyor.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ]
              : bucket.items
                  .take(6)
                  .map(
                    (tx) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${tx.docNo} • ${tx.accountName}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            PreAccountingMathEngine.formatTl(tx.amount),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
        ),
      ),
    );
  }
}

// =============================================================================
// 7. ÜST BİRLEŞİK FİNANS ARAÇLARI PANELİ
// =============================================================================

/// Ön muhasebe ileri finans araçlarını kompakt responsif düzende sunan üst panel.
class HasibuFinanceToolsPanel extends StatelessWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const HasibuFinanceToolsPanel({
    super.key,
    required this.data,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final openChecksCount = data.checkPortfolio
        .where((c) => c.status == CheckPortfolioStatus.inPortfolio)
        .length;
    final pendingOrdersCount = data.paymentOrders
        .where((o) => o.status.toUpperCase() != 'ODENDI')
        .length;
    final eod = EodBucketClassifier.classify(
      dateKey: data.selectedDateKey,
      transactions: data.transactions,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data.companyName} • FİNANS, DÖVİZ, ÇEK/SENET & GÜN SONU KONTROL PANELİ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dönem: ${data.selectedPeriodKey} • Tarih: ${data.selectedDateKey} • '
                '${data.accounts.length} Aktif Cari • ${data.currencyRates.length} Kur Kotasyonu',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DarkMetricBadge(
                    label: 'Portföydeki Çek / Senet',
                    value: '$openChecksCount Evrak',
                    sub: 'Toplam ${data.checkPortfolio.length} Kayıt',
                    color: const Color(0xFF38BDF8),
                  ),
                  _DarkMetricBadge(
                    label: 'Bekleyen Talimatlar',
                    value: '$pendingOrdersCount Talimat',
                    sub: '${data.paymentTemplates.length} Kayıtlı Şablon',
                    color: const Color(0xFFFBBF24),
                  ),
                  _DarkMetricBadge(
                    label: 'Gün Sonu Net Akış',
                    value: PreAccountingMathEngine.formatTl(eod.netFlowTl),
                    sub:
                        'Gelen ${PreAccountingMathEngine.formatTl(eod.totalIncomingTl)}',
                    color: eod.netFlowTl >= 0
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF43F5E),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1060;
            if (!isWide) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HasibuLiveFxAndCollectionCard(data: data, actions: actions),
                  const SizedBox(height: 14),
                  HasibuWeightedMaturityCard(data: data),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: HasibuLiveFxAndCollectionCard(
                    data: data,
                    actions: actions,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: HasibuWeightedMaturityCard(data: data),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        HasibuCheckBordroAndLifecyclePanel(data: data, actions: actions),
        const SizedBox(height: 14),
        HasibuPaymentInstructionsPanel(data: data, actions: actions),
        const SizedBox(height: 14),
        HasibuCumulativeCashBankLedgersCard(data: data),
        const SizedBox(height: 14),
        HasibuEndOfDayAllFlowsPanel(data: data),
      ],
    );
  }
}

// =============================================================================
// ORTAK ATOMİK UI YARDIMCI BİLEŞENLERİ
// =============================================================================

class _FinanceCardShell extends StatelessWidget {
  final Widget child;

  const _FinanceCardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeaderRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _DarkMetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _DarkMetricBadge({
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

class _StatusPillBadge extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color fgColor;
  final IconData? icon;

  const _StatusPillBadge({
    required this.text,
    required this.bgColor,
    required this.fgColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fgColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateBox extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyStateBox({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
