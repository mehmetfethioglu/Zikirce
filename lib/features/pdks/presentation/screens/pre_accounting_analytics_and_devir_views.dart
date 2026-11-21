import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/accounting_models.dart';
import '../../domain/pre_accounting_advanced_contracts.dart';

const Color _kBorderColor = Color(0xFFE2E8F0);
const Color _kSurfaceSubtle = Color(0xFFF8FAFC);
const Color _kTitleDark = Color(0xFF0F172A);
const Color _kBodySlate = Color(0xFF475569);
const Color _kMutedSlate = Color(0xFF64748B);
const Color _kEmeraldDark = Color(0xFF065F46);
const Color _kEmeraldPrimary = Color(0xFF0F766E);
const Color _kEmeraldBg = Color(0xFFECFDF5);
const Color _kEmeraldBorder = Color(0xFFA7F3D0);
const Color _kRedDark = Color(0xFFB91C1C);
const Color _kRedBg = Color(0xFFFEF2F2);
const Color _kRedBorder = Color(0xFFFECACA);
const Color _kAmberDark = Color(0xFFB45309);
const Color _kAmberBg = Color(0xFFFFFBEB);
const Color _kAmberBorder = Color(0xFFFDE68A);
const Color _kBlueDark = Color(0xFF1D4ED8);
const Color _kBlueBg = Color(0xFFEFF6FF);
const Color _kBlueBorder = Color(0xFFBFDBFE);

void _showNoticeSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _kRedDark : _kEmeraldPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

String _formatQty(double value) {
  if ((value - value.roundToDouble()).abs() < 0.001) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

String _signedBalanceLabel(double balanceTl) {
  if (balanceTl > 0.005) return '(A)';
  if (balanceTl < -0.005) return '(B)';
  return '(0)';
}

Color _balanceColor(double balanceTl) {
  if (balanceTl > 0.005) return _kEmeraldPrimary;
  if (balanceTl < -0.005) return _kRedDark;
  return _kMutedSlate;
}

String _nextPeriodSuggestion(String currentPeriodKey) {
  final clean = currentPeriodKey.trim();
  final match = RegExp(r'^(\d{4})(?:-(\d{2}))?').firstMatch(clean);
  if (match != null) {
    final year = int.tryParse(match.group(1)!) ?? DateTime.now().year;
    final nextYear = year + 1;
    final month = match.group(2);
    return month == null ? '$nextYear' : '$nextYear-01';
  }
  return '${DateTime.now().year + 1}-01';
}

String _nextRolloverDateSuggestion(String currentPeriodKey) {
  final clean = currentPeriodKey.trim();
  final match = RegExp(r'^(\d{4})').firstMatch(clean);
  final year = match != null
      ? (int.tryParse(match.group(1)!) ?? DateTime.now().year)
      : DateTime.now().year;
  return '${year + 1}-01-01';
}

List<Map<String, String>> _parsePriceHistoryEntries(String rawJson) {
  final trimmed = rawJson.trim();
  if (trimmed.isEmpty || trimmed == '[]') {
    return const <Map<String, String>>[];
  }
  final entries = <Map<String, String>>[];
  final objRegex = RegExp(r'\{([^}]*)\}');
  final pairRegex = RegExp(r'"([^"]+)"\s*:\s*("([^"]*)"|[-0-9.eE]+|true|false)');

  for (final objMatch in objRegex.allMatches(trimmed)) {
    final body = objMatch.group(1) ?? '';
    final map = <String, String>{};
    for (final pairMatch in pairRegex.allMatches(body)) {
      final key = pairMatch.group(1) ?? '';
      final val = pairMatch.group(3) ?? pairMatch.group(2) ?? '';
      if (key.isNotEmpty) {
        map[key] = val;
      }
    }
    if (map.isNotEmpty) {
      entries.add(map);
    }
  }

  if (entries.isEmpty && trimmed.startsWith('[') && trimmed.endsWith(']')) {
    final inner = trimmed.substring(1, trimmed.length - 1).trim();
    if (inner.isNotEmpty) {
      for (final token in inner.split(',')) {
        final clean = token.replaceAll('"', '').trim();
        if (clean.isNotEmpty) {
          entries.add(<String, String>{'Kayıt': clean});
        }
      }
    }
  }
  return entries;
}

String _formatCariStatementText({
  required PreAccountingAdvancedViewData data,
  required AccountingAccount account,
  required double openingBalanceTl,
  required List<CumulativeLedgerRow> rows,
  required CariNetStatusSummary netStatus,
  required double endorsedCheckRiskTl,
  required String startDateKey,
  required String endDateKey,
}) {
  final buf = StringBuffer();
  buf.writeln('============================================================');
  buf.writeln('${data.companyName} — CARİ KÜMÜLATİF EKSTRE VE RİSK ÖZETİ');
  buf.writeln('Cari: ${account.code} - ${account.name} (${account.type.label})');
  buf.writeln(
    'Özel Kod: ${account.specialCode.isEmpty ? "-" : account.specialCode} | '
    'Plasiyer: ${account.salesRepName.isEmpty ? "-" : account.salesRepName} | '
    'Fiyat-${account.priceTier}',
  );
  if (startDateKey.isNotEmpty || endDateKey.isNotEmpty) {
    buf.writeln(
      'Tarih Aralığı: ${startDateKey.isEmpty ? "Başlangıç" : startDateKey} .. '
      '${endDateKey.isEmpty ? "Bugün" : endDateKey}',
    );
  }
  buf.writeln('------------------------------------------------------------');
  buf.writeln(
    'DEVREDEN BAKİYE: ${PreAccountingMathEngine.formatTl(openingBalanceTl)} '
    '${_signedBalanceLabel(openingBalanceTl)}',
  );
  for (final r in rows) {
    buf.writeln(
      '${r.dateKey} | ${r.docNo} | ${r.description} | ${r.cashOrBankName} | '
      'Borç: ${PreAccountingMathEngine.formatTl(r.debitTl)} | '
      'Alacak: ${PreAccountingMathEngine.formatTl(r.creditTl)} | '
      'Bakiye: ${PreAccountingMathEngine.formatTl(r.runningBalanceTl)} '
      '${_signedBalanceLabel(r.runningBalanceTl)}',
    );
  }
  buf.writeln('------------------------------------------------------------');
  buf.writeln(
    'Dönem Borç: ${PreAccountingMathEngine.formatTl(netStatus.periodDebitTl)} | '
    'Dönem Alacak: ${PreAccountingMathEngine.formatTl(netStatus.periodCreditTl)}',
  );
  buf.writeln(
    'Defter Kapanış: ${PreAccountingMathEngine.formatTl(netStatus.ledgerClosingBalanceTl)} '
    '${_signedBalanceLabel(netStatus.ledgerClosingBalanceTl)}',
  );
  buf.writeln(
    'Açık Sipariş Riski: ${PreAccountingMathEngine.formatTl(netStatus.openOrderExposureTl)} | '
    'Portföy Çek: ${PreAccountingMathEngine.formatTl(netStatus.portfolioCheckExposureTl)} | '
    'Ciro Çek Riski: ${PreAccountingMathEngine.formatTl(endorsedCheckRiskTl)}',
  );
  buf.writeln(
    'Emanet Tepsi (${netStatus.trayCount} Adet): '
    '${PreAccountingMathEngine.formatTl(netStatus.depositExposureTl)}',
  );
  buf.writeln(
    'KONSOLİDE NET RİSK POZİSYONU: '
    '${PreAccountingMathEngine.formatTl(netStatus.consolidatedNetPositionTl)}',
  );
  if (account.creditLimitTl > 0) {
    final usedRisk =
        (netStatus.consolidatedNetPositionTl < 0
            ? netStatus.consolidatedNetPositionTl.abs()
            : 0.0) +
        endorsedCheckRiskTl;
    final remaining = account.creditLimitTl - usedRisk;
    buf.writeln(
      'Kredi Limiti: ${PreAccountingMathEngine.formatTl(account.creditLimitTl)} | '
      'Kalan Limit: ${PreAccountingMathEngine.formatTl(remaining)}',
    );
  }
  return buf.toString();
}

// ============================================================================
// 1. CARİ KÜMÜLATİF EKSTRE + NET RİSK DURUM PANELİ
// ============================================================================

/// Cari seçici, özellik rozetleri, DEVREDEN BAKİYE + yürüyen kümülatif ekstre,
/// konsolide net risk durumu ve metin ekstresi kopyalama paneli.
class HasibuCariCumulativeAndNetStatusPanel extends StatefulWidget {
  final PreAccountingAdvancedViewData data;

  const HasibuCariCumulativeAndNetStatusPanel({
    super.key,
    required this.data,
  });

  @override
  State<HasibuCariCumulativeAndNetStatusPanel> createState() =>
      _HasibuCariCumulativeAndNetStatusPanelState();
}

class _HasibuCariCumulativeAndNetStatusPanelState
    extends State<HasibuCariCumulativeAndNetStatusPanel> {
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _cashBankController;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _cashBankController = TextEditingController();
    _selectedAccountId = _resolveInitialAccountId(widget.data);
  }

  @override
  void didUpdateWidget(covariant HasibuCariCumulativeAndNetStatusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.selectedAccount?.id != oldWidget.data.selectedAccount?.id &&
        widget.data.selectedAccount != null) {
      _selectedAccountId = widget.data.selectedAccount!.id;
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _cashBankController.dispose();
    super.dispose();
  }

  String? _resolveInitialAccountId(PreAccountingAdvancedViewData data) {
    if (data.selectedAccount != null) {
      return data.selectedAccount!.id;
    }
    return data.accounts.isNotEmpty ? data.accounts.first.id : null;
  }

  AccountingAccount? _resolveActiveAccount() {
    final accounts = widget.data.accounts;
    if (accounts.isEmpty) return null;
    for (final a in accounts) {
      if (a.id == _selectedAccountId) return a;
    }
    return widget.data.selectedAccount ?? accounts.first;
  }

  void _applyPeriodStartFilter() {
    setState(() {
      _startDateController.text = '${widget.data.selectedPeriodKey}-01';
    });
  }

  void _clearFilters() {
    setState(() {
      _startDateController.clear();
      _endDateController.clear();
      _cashBankController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = _resolveActiveAccount();
    if (account == null) {
      return const _SectionCardShell(
        title: 'Cari Kümülatif Ekstre & Net Risk Durumu',
        subtitle: 'Yürüyen bakiye, devreden bakiye ve çek/sipariş risk özeti',
        icon: Icons.account_balance_wallet_outlined,
        child: _EmptySectionNotice(
          message: 'Görüntülenecek cari hesap kaydı henüz bulunmuyor.',
        ),
      );
    }

    final startKey = _startDateController.text.trim();
    final endKey = _endDateController.text.trim();
    final cashBankKey = _cashBankController.text.trim();

    final ledger = PreAccountingMathEngine.buildCumulativeLedger(
      transactions: widget.data.transactions,
      startDateKey: startKey.isEmpty ? null : startKey,
      endDateKey: endKey.isEmpty ? null : endKey,
      accountId: account.id,
      cashOrBankFilter: cashBankKey.isEmpty ? null : cashBankKey,
    );

    final netStatus = PreAccountingMathEngine.computeCariNetStatus(
      account: account,
      transactions: widget.data.transactions,
      erpDocs: widget.data.erpDocuments,
      checks: widget.data.checkPortfolio,
      stocks: widget.data.stocks,
      startDateKey: startKey.isEmpty ? null : startKey,
      endDateKey: endKey.isEmpty ? null : endKey,
    );

    final endorsedCheckRiskTl = widget.data.checkPortfolio
        .where(
          (c) =>
              (c.accountId == account.id || c.endorsedToAccountId == account.id) &&
              c.status == CheckPortfolioStatus.endorsed,
        )
        .fold<double>(0.0, (s, c) => s + c.amountTl);

    return _SectionCardShell(
      title: 'Cari Kümülatif Ekstre & Net Risk Durumu',
      subtitle:
          'Özel Kod, Plasiyer, Fiyat Grubu, Devreden Bakiye ve Konsolide Çek/Limit Analizi',
      icon: Icons.account_balance_wallet_outlined,
      trailing: FilledButton.tonalIcon(
        onPressed: () async {
          final text = _formatCariStatementText(
            data: widget.data,
            account: account,
            openingBalanceTl: ledger.openingBalanceTl,
            rows: ledger.rows,
            netStatus: netStatus,
            endorsedCheckRiskTl: endorsedCheckRiskTl,
            startDateKey: startKey,
            endDateKey: endKey,
          );
          await Clipboard.setData(ClipboardData(text: text));
          if (!context.mounted) return;
          _showNoticeSnackBar(
            context,
            '${account.name} kümülatif ekstresi panoya kopyalandı.',
          );
        },
        icon: const Icon(Icons.copy_all_outlined, size: 16),
        label: const Text('Metin Ekstresi Kopyala'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CariSelectorAndBadgesBar(
            accounts: widget.data.accounts,
            selectedAccount: account,
            onAccountChanged: (id) {
              if (id != null) {
                setState(() => _selectedAccountId = id);
              }
            },
          ),
          const SizedBox(height: 12),
          _CariLedgerFilterRow(
            startDateController: _startDateController,
            endDateController: _endDateController,
            cashBankController: _cashBankController,
            periodKey: widget.data.selectedPeriodKey,
            onFilterChanged: () => setState(() {}),
            onApplyPeriodStart: _applyPeriodStartFilter,
            onClearFilters: _clearFilters,
          ),
          const SizedBox(height: 12),
          _OpeningBalanceBanner(
            openingBalanceTl: ledger.openingBalanceTl,
            startDateKey: startKey,
          ),
          const SizedBox(height: 10),
          _CumulativeLedgerTable(
            openingBalanceTl: ledger.openingBalanceTl,
            rows: ledger.rows,
          ),
          const SizedBox(height: 14),
          _CariNetStatusSummaryCard(
            account: account,
            summary: netStatus,
            endorsedCheckRiskTl: endorsedCheckRiskTl,
          ),
        ],
      ),
    );
  }
}

class _CariSelectorAndBadgesBar extends StatelessWidget {
  final List<AccountingAccount> accounts;
  final AccountingAccount selectedAccount;
  final ValueChanged<String?> onAccountChanged;

  const _CariSelectorAndBadgesBar({
    required this.accounts,
    required this.selectedAccount,
    required this.onAccountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final limitText = selectedAccount.creditLimitTl > 0
        ? PreAccountingMathEngine.formatTl(selectedAccount.creditLimitTl)
        : 'Limitsiz';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Cari Hesap Seçimi',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              fillColor: Colors.white,
              filled: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedAccount.id,
                isDense: true,
                isExpanded: true,
                items: accounts
                    .map(
                      (a) => DropdownMenuItem<String>(
                        value: a.id,
                        child: Text(
                          '${a.code} — ${a.name} (${a.type.label})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onAccountChanged,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ToneBadge(
                label:
                    'Özel Kod: ${selectedAccount.specialCode.isEmpty ? "Tanımsız" : selectedAccount.specialCode}',
                bgColor: _kBlueBg,
                borderColor: _kBlueBorder,
                textColor: _kBlueDark,
                icon: Icons.label_outline,
              ),
              _ToneBadge(
                label:
                    'Plasiyer: ${selectedAccount.salesRepName.isEmpty ? "Merkez" : selectedAccount.salesRepName}',
                bgColor: _kEmeraldBg,
                borderColor: _kEmeraldBorder,
                textColor: _kEmeraldDark,
                icon: Icons.badge_outlined,
              ),
              _ToneBadge(
                label: 'Fiyat Grubu: Fiyat-${selectedAccount.priceTier}',
                bgColor: Colors.white,
                borderColor: _kBorderColor,
                textColor: _kTitleDark,
                icon: Icons.sell_outlined,
              ),
              _ToneBadge(
                label: 'Risk Limiti: $limitText',
                bgColor: _kAmberBg,
                borderColor: _kAmberBorder,
                textColor: _kAmberDark,
                icon: Icons.shield_outlined,
              ),
              if (selectedAccount.defaultDiscountPercent > 0)
                _ToneBadge(
                  label:
                      'Vars. İskonto: %${selectedAccount.defaultDiscountPercent.toStringAsFixed(1)}',
                  bgColor: Colors.white,
                  borderColor: _kBorderColor,
                  textColor: _kBodySlate,
                  icon: Icons.percent,
                ),
              if (selectedAccount.cityDistrict.isNotEmpty)
                _ToneBadge(
                  label: selectedAccount.cityDistrict,
                  bgColor: Colors.white,
                  borderColor: _kBorderColor,
                  textColor: _kBodySlate,
                  icon: Icons.location_on_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CariLedgerFilterRow extends StatelessWidget {
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController cashBankController;
  final String periodKey;
  final VoidCallback onFilterChanged;
  final VoidCallback onApplyPeriodStart;
  final VoidCallback onClearFilters;

  const _CariLedgerFilterRow({
    required this.startDateController,
    required this.endDateController,
    required this.cashBankController,
    required this.periodKey,
    required this.onFilterChanged,
    required this.onApplyPeriodStart,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: TextField(
            controller: startDateController,
            onChanged: (_) => onFilterChanged(),
            decoration: const InputDecoration(
              labelText: 'Başlangıç Tarihi',
              hintText: 'YYYY-AA-GG',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 150,
          child: TextField(
            controller: endDateController,
            onChanged: (_) => onFilterChanged(),
            decoration: const InputDecoration(
              labelText: 'Bitiş Tarihi',
              hintText: 'YYYY-AA-GG',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 190,
          child: TextField(
            controller: cashBankController,
            onChanged: (_) => onFilterChanged(),
            decoration: const InputDecoration(
              labelText: 'Kasa / Banka Filtresi',
              hintText: 'Örn: Merkez TL Kasa',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.date_range_outlined, size: 16),
          label: Text('Dönem Başı ($periodKey-01)'),
          onPressed: onApplyPeriodStart,
        ),
        ActionChip(
          avatar: const Icon(Icons.clear_all_outlined, size: 16),
          label: const Text('Filtreyi Temizle'),
          onPressed: onClearFilters,
        ),
      ],
    );
  }
}

class _OpeningBalanceBanner extends StatelessWidget {
  final double openingBalanceTl;
  final String startDateKey;

  const _OpeningBalanceBanner({
    required this.openingBalanceTl,
    required this.startDateKey,
  });

  @override
  Widget build(BuildContext context) {
    final color = _balanceColor(openingBalanceTl);
    final isCredit = openingBalanceTl > 0.005;
    final isDebit = openingBalanceTl < -0.005;
    final bg = isCredit ? _kEmeraldBg : (isDebit ? _kRedBg : _kSurfaceSubtle);
    final border =
        isCredit ? _kEmeraldBorder : (isDebit ? _kRedBorder : _kBorderColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.history_edu_outlined, size: 18, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    startDateKey.isEmpty
                        ? 'DEVREDEN BAKİYE (Açılış)'
                        : 'DEVREDEN BAKİYE ($startDateKey Öncesi)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${PreAccountingMathEngine.formatTl(openingBalanceTl)} ${_signedBalanceLabel(openingBalanceTl)}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CumulativeLedgerTable extends StatelessWidget {
  final double openingBalanceTl;
  final List<CumulativeLedgerRow> rows;

  const _CumulativeLedgerTable({
    required this.openingBalanceTl,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySectionNotice(
        message: 'Seçilen filtre aralığında kümülatif ekstre hareketi bulunmuyor.',
      );
    }

    return _HorizontalTableShell(
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 46,
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(_kSurfaceSubtle),
        columns: const <DataColumn>[
          DataColumn(label: Text('Tarih')),
          DataColumn(label: Text('Belge No')),
          DataColumn(label: Text('Açıklama')),
          DataColumn(label: Text('Kasa / Banka')),
          DataColumn(numeric: true, label: Text('Borç (B)')),
          DataColumn(numeric: true, label: Text('Alacak (A)')),
          DataColumn(numeric: true, label: Text('Yürüyen Bakiye')),
        ],
        rows: <DataRow>[
          DataRow(
            color: WidgetStateProperty.all(_kAmberBg),
            cells: <DataCell>[
              const DataCell(Text('—')),
              const DataCell(
                Text(
                  'DEVİR',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const DataCell(
                Text(
                  'DEVREDEN BAKİYE',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const DataCell(Text('—')),
              const DataCell(Text('—')),
              const DataCell(Text('—')),
              DataCell(
                Text(
                  '${PreAccountingMathEngine.formatTl(openingBalanceTl)} ${_signedBalanceLabel(openingBalanceTl)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _balanceColor(openingBalanceTl),
                  ),
                ),
              ),
            ],
          ),
          ...rows.map(
            (r) => DataRow(
              cells: <DataCell>[
                DataCell(Text(r.dateKey)),
                DataCell(
                  Text(
                    r.docNo,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      r.description,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
                DataCell(Text(r.cashOrBankName)),
                DataCell(
                  Text(
                    r.debitTl > 0
                        ? PreAccountingMathEngine.formatTl(r.debitTl)
                        : '—',
                    style: TextStyle(
                      color: r.debitTl > 0 ? _kRedDark : _kMutedSlate,
                      fontWeight: r.debitTl > 0 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    r.creditTl > 0
                        ? PreAccountingMathEngine.formatTl(r.creditTl)
                        : '—',
                    style: TextStyle(
                      color: r.creditTl > 0 ? _kEmeraldPrimary : _kMutedSlate,
                      fontWeight:
                          r.creditTl > 0 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${PreAccountingMathEngine.formatTl(r.runningBalanceTl)} ${_signedBalanceLabel(r.runningBalanceTl)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _balanceColor(r.runningBalanceTl),
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

class _CariNetStatusSummaryCard extends StatelessWidget {
  final AccountingAccount account;
  final CariNetStatusSummary summary;
  final double endorsedCheckRiskTl;

  const _CariNetStatusSummaryCard({
    required this.account,
    required this.summary,
    required this.endorsedCheckRiskTl,
  });

  @override
  Widget build(BuildContext context) {
    final usedRisk =
        (summary.consolidatedNetPositionTl < 0
            ? summary.consolidatedNetPositionTl.abs()
            : 0.0) +
        endorsedCheckRiskTl;
    final hasLimit = account.creditLimitTl > 0;
    final remainingLimit = hasLimit ? account.creditLimitTl - usedRisk : 0.0;
    final isLimitExceeded = hasLimit && remainingLimit < 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Cari Net Durum & Konsolide Risk Özeti',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kTitleDark,
                  ),
                ),
              ),
              if (isLimitExceeded)
                const _ToneBadge(
                  label: 'RİSK LİMİTİ AŞILDI',
                  bgColor: _kRedBg,
                  borderColor: _kRedBorder,
                  textColor: _kRedDark,
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KpiTile(
                title: 'Dönem Borç / Alacak',
                value:
                    'B: ${PreAccountingMathEngine.formatTl(summary.periodDebitTl)}\nA: ${PreAccountingMathEngine.formatTl(summary.periodCreditTl)}',
                accent: _kBodySlate,
              ),
              _KpiTile(
                title: 'Defter Net Bakiye',
                value:
                    '${PreAccountingMathEngine.formatTl(summary.ledgerClosingBalanceTl)} ${_signedBalanceLabel(summary.ledgerClosingBalanceTl)}',
                accent: _balanceColor(summary.ledgerClosingBalanceTl),
              ),
              _KpiTile(
                title: 'Açık Sipariş / İrsaliye',
                value: PreAccountingMathEngine.formatTl(
                  summary.openOrderExposureTl,
                ),
                accent: _kAmberDark,
              ),
              _KpiTile(
                title: 'Portföy Çek Riski',
                value: PreAccountingMathEngine.formatTl(
                  summary.portfolioCheckExposureTl,
                ),
                accent: _kBlueDark,
              ),
              _KpiTile(
                title: 'Ciro Çek Riski',
                value: PreAccountingMathEngine.formatTl(endorsedCheckRiskTl),
                accent: _kAmberDark,
              ),
              _KpiTile(
                title: 'Emanet Tepsi (${summary.trayCount})',
                value: PreAccountingMathEngine.formatTl(
                  summary.depositExposureTl,
                ),
                accent: _kBodySlate,
              ),
              _KpiTile(
                title: 'Konsolide Net Risk',
                value:
                    '${PreAccountingMathEngine.formatTl(summary.consolidatedNetPositionTl)} ${_signedBalanceLabel(summary.consolidatedNetPositionTl)}',
                accent: _balanceColor(summary.consolidatedNetPositionTl),
              ),
              _KpiTile(
                title: 'Kalan Kredi Limiti',
                value: hasLimit
                    ? PreAccountingMathEngine.formatTl(remainingLimit)
                    : 'Limitsiz',
                accent: isLimitExceeded ? _kRedDark : _kEmeraldPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. ERP İLERİ KONTROL PANELİ (İSKONTO, TAHSİLAT, ŞABLON, İADE, MATRİS, BAYİ)
// ============================================================================

enum _ErpSubFlowTab {
  all('Tümü'),
  discountAndSettle('İskonto & Tahsilat'),
  templateAndReturn('Şablon Sipariş & İade'),
  matrixControl('Sipariş↔Fatura & Matris'),
  dealerContracts('Bayi Sözleşmeleri');

  final String label;
  const _ErpSubFlowTab(this.label);
}

/// ERP ileri operasyonlar paneli: otomatik iskonto, parçalı tahsilat,
/// stok şablonundan sipariş, iade faturası, sipariş/ürün matrisi ve bayi sözleşmeleri.
class HasibuErpAdvancedControlsPanel extends StatefulWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const HasibuErpAdvancedControlsPanel({
    super.key,
    required this.data,
    required this.actions,
  });

  @override
  State<HasibuErpAdvancedControlsPanel> createState() =>
      _HasibuErpAdvancedControlsPanelState();
}

class _HasibuErpAdvancedControlsPanelState
    extends State<HasibuErpAdvancedControlsPanel> {
  _ErpSubFlowTab _activeTab = _ErpSubFlowTab.all;

  @override
  Widget build(BuildContext context) {
    final showDiscountSettle =
        _activeTab == _ErpSubFlowTab.all ||
        _activeTab == _ErpSubFlowTab.discountAndSettle;
    final showTemplateReturn =
        _activeTab == _ErpSubFlowTab.all ||
        _activeTab == _ErpSubFlowTab.templateAndReturn;
    final showMatrixControl =
        _activeTab == _ErpSubFlowTab.all ||
        _activeTab == _ErpSubFlowTab.matrixControl;
    final showDealerContracts =
        _activeTab == _ErpSubFlowTab.all ||
        _activeTab == _ErpSubFlowTab.dealerContracts;

    return _SectionCardShell(
      title: 'ERP İleri Kontrol Merkezi',
      subtitle:
          'Belge İskonto/Tahsilat, Şablon Sipariş, İade Faturası, Sipariş-Fatura Matrisi & Bayi Sözleşmeleri',
      icon: Icons.precision_manufacturing_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ErpSubFlowTab.values
                .map(
                  (tab) => ChoiceChip(
                    label: Text(tab.label),
                    selected: _activeTab == tab,
                    onSelected: (_) => setState(() => _activeTab = tab),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          if (showDiscountSettle) ...[
            _ErpDiscountAndSettlementCard(
              documents: widget.data.erpDocuments,
              actions: widget.actions,
            ),
            const SizedBox(height: 14),
          ],
          if (showTemplateReturn) ...[
            _StockTemplateAndReturnSection(
              data: widget.data,
              actions: widget.actions,
            ),
            const SizedBox(height: 14),
          ],
          if (showMatrixControl) ...[
            _OrderInvoiceMatrixCard(documents: widget.data.erpDocuments),
            const SizedBox(height: 14),
          ],
          if (showDealerContracts)
            _DealerContractsCard(
              data: widget.data,
              actions: widget.actions,
            ),
        ],
      ),
    );
  }
}

class _ErpDiscountAndSettlementCard extends StatelessWidget {
  final List<ErpOrderWaybillInvoiceItem> documents;
  final PreAccountingAdvancedActions actions;

  const _ErpDiscountAndSettlementCard({
    required this.documents,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return _InnerSubCard(
      title: 'Belge Üzeri Otomatik İskonto & Parçalı / Tam Tahsilat Kapatma',
      icon: Icons.receipt_long_outlined,
      child: documents.isEmpty
          ? const _EmptySectionNotice(
              message: 'İskonto veya tahsilat uygulanacak ERP belgesi yok.',
            )
          : Column(
              children: documents
                  .map(
                    (doc) => _ErpDocumentControlRow(
                      doc: doc,
                      onOpenAutoDiscount: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => _AutoDiscountDialog(
                            doc: doc,
                            onConfirm: (targetNet) {
                              actions.applyAutoDiscountToErpDoc(
                                erpDocId: doc.id,
                                targetNetTotalTl: targetNet,
                              );
                              _showNoticeSnackBar(
                                context,
                                '${doc.invoiceDocNo ?? doc.orderDocNo} için oto iskonto uygulandı.',
                              );
                            },
                          ),
                        );
                      },
                      onOpenSettlement: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => _PartialSettlementDialog(
                            doc: doc,
                            onConfirm: (amount, cashBankName, viaBank) {
                              actions.settleInvoicePartially(
                                erpDocId: doc.id,
                                amountTl: amount,
                                cashOrBankName: cashBankName,
                                viaBank: viaBank,
                              );
                              _showNoticeSnackBar(
                                context,
                                '${doc.invoiceDocNo ?? doc.orderDocNo} için ${PreAccountingMathEngine.formatTl(amount)} tahsilat işlendi.',
                              );
                            },
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ErpDocumentControlRow extends StatelessWidget {
  final ErpOrderWaybillInvoiceItem doc;
  final VoidCallback onOpenAutoDiscount;
  final VoidCallback onOpenSettlement;

  const _ErpDocumentControlRow({
    required this.doc,
    required this.onOpenAutoDiscount,
    required this.onOpenSettlement,
  });

  @override
  Widget build(BuildContext context) {
    final docNo = doc.invoiceDocNo ?? doc.waybillDocNo ?? doc.orderDocNo;
    final remaining = doc.remainingReceivableTl;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$docNo • ${doc.accountName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kTitleDark,
                  ),
                ),
              ),
              _ToneBadge(
                label: '${doc.stage} (${doc.docKind})',
                bgColor: doc.stage == 'FATURALANDI' ? _kEmeraldBg : _kAmberBg,
                borderColor:
                    doc.stage == 'FATURALANDI' ? _kEmeraldBorder : _kAmberBorder,
                textColor:
                    doc.stage == 'FATURALANDI' ? _kEmeraldDark : _kAmberDark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${doc.stockName} (${_formatQty(doc.activeQtyKg)} Kg • ${doc.trayCount} Tepsi) • '
            'İskonto: %${doc.discountPercent.toStringAsFixed(2)} • '
            'KDV: %${doc.vatPercent.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, color: _kBodySlate),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Genel Toplam: ${PreAccountingMathEngine.formatTl(doc.grandTotalTl)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _kTitleDark,
                ),
              ),
              Text(
                'Tahsil Edilen: ${PreAccountingMathEngine.formatTl(doc.collectedAmountTl)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kEmeraldPrimary,
                ),
              ),
              Text(
                'Kalan: ${PreAccountingMathEngine.formatTl(remaining)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: remaining > 0.01 ? _kRedDark : _kEmeraldPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenAutoDiscount,
                icon: const Icon(Icons.percent_outlined, size: 16),
                label: const Text('Oto İskonto Uygula'),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenSettlement,
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: Text(
                  remaining > 0.01
                      ? 'Parçalı / Tam Tahsilat Kapat'
                      : 'Ek Tahsilat Kaydet',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoDiscountDialog extends StatefulWidget {
  final ErpOrderWaybillInvoiceItem doc;
  final ValueChanged<double> onConfirm;

  const _AutoDiscountDialog({
    required this.doc,
    required this.onConfirm,
  });

  @override
  State<_AutoDiscountDialog> createState() => _AutoDiscountDialogState();
}

class _AutoDiscountDialogState extends State<_AutoDiscountDialog> {
  late final TextEditingController _targetNetController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _targetNetController = TextEditingController(
      text: widget.doc.netSubTotalTl.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _targetNetController.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(
      _targetNetController.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null || parsed < 0 || parsed > widget.doc.grossTotalTl) {
      setState(() {
        _errorText =
            'Hedef net tutar 0 ile ${widget.doc.grossTotalTl.toStringAsFixed(2)} TL arasında olmalıdır.';
      });
      return;
    }
    Navigator.of(context).pop();
    widget.onConfirm(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final target =
        double.tryParse(_targetNetController.text.trim().replaceAll(',', '.')) ??
        widget.doc.netSubTotalTl;
    final pct = PreAccountingMathEngine.computeAutoDiscountPercent(
      grossTotalTl: widget.doc.grossTotalTl,
      targetNetTotalTl: target,
    );
    final estVat = target * (widget.doc.vatPercent / 100.0);
    final estGrand = target + estVat;

    return AlertDialog(
      title: const Text('Belge Üzeri Otomatik İskonto'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.doc.invoiceDocNo ?? widget.doc.orderDocNo} • ${widget.doc.accountName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Brüt Ara Toplam: ${PreAccountingMathEngine.formatTl(widget.doc.grossTotalTl)}\n'
              'Mevcut İskonto: %${widget.doc.discountPercent.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12.5, color: _kBodySlate),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetNetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _errorText = null),
              decoration: InputDecoration(
                labelText: 'Hedef Net Ara Toplam (KDV Hariç ₺)',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kEmeraldBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kEmeraldBorder),
              ),
              child: Text(
                'Hesaplanan İskonto: %${pct.toStringAsFixed(2)}\n'
                'Tahmini KDV (%${widget.doc.vatPercent.toStringAsFixed(0)}): ${PreAccountingMathEngine.formatTl(estVat)}\n'
                'Yeni Genel Toplam: ${PreAccountingMathEngine.formatTl(estGrand)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kEmeraldDark,
                ),
              ),
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
          onPressed: _submit,
          child: const Text('İskontoyu Uygula'),
        ),
      ],
    );
  }
}

class _PartialSettlementDialog extends StatefulWidget {
  final ErpOrderWaybillInvoiceItem doc;
  final void Function(double amountTl, String cashOrBankName, bool viaBank)
  onConfirm;

  const _PartialSettlementDialog({
    required this.doc,
    required this.onConfirm,
  });

  @override
  State<_PartialSettlementDialog> createState() =>
      _PartialSettlementDialogState();
}

class _PartialSettlementDialogState extends State<_PartialSettlementDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _cashBankController;
  bool _viaBank = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.doc.remainingReceivableTl > 0
        ? widget.doc.remainingReceivableTl
        : widget.doc.grandTotalTl;
    _amountController = TextEditingController(
      text: initialAmount.toStringAsFixed(2),
    );
    _cashBankController = TextEditingController(text: 'Merkez TL Kasa');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cashBankController.dispose();
    super.dispose();
  }

  void _toggleChannel(bool viaBank) {
    setState(() {
      _viaBank = viaBank;
      final current = _cashBankController.text.trim();
      if (viaBank && (current.isEmpty || current == 'Merkez TL Kasa')) {
        _cashBankController.text = 'Ticari Banka Hesabı';
      } else if (!viaBank &&
          (current.isEmpty || current == 'Ticari Banka Hesabı')) {
        _cashBankController.text = 'Merkez TL Kasa';
      }
    });
  }

  void _submit() {
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    final channel = _cashBankController.text.trim();
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Geçerli bir tahsilat tutarı giriniz.');
      return;
    }
    if (channel.isEmpty) {
      setState(() => _errorText = 'Kasa veya banka adı boş bırakılamaz.');
      return;
    }
    Navigator.of(context).pop();
    widget.onConfirm(amount, channel, _viaBank);
  }

  @override
  Widget build(BuildContext context) {
    final rem = widget.doc.remainingReceivableTl;
    return AlertDialog(
      title: const Text('Parçalı / Tam Tahsilat Kapatma'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.doc.invoiceDocNo ?? widget.doc.orderDocNo} • ${widget.doc.accountName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Genel Toplam: ${PreAccountingMathEngine.formatTl(widget.doc.grandTotalTl)} | '
              'Kalan Alacak: ${PreAccountingMathEngine.formatTl(rem)}',
              style: const TextStyle(fontSize: 12.5, color: _kBodySlate),
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.point_of_sale_outlined, size: 16),
                  label: Text('Kasa Tahsilat'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.account_balance_outlined, size: 16),
                  label: Text('Banka Havale/EFT'),
                ),
              ],
              selected: <bool>{_viaBank},
              onSelectionChanged: (s) => _toggleChannel(s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cashBankController,
              onChanged: (_) => setState(() => _errorText = null),
              decoration: const InputDecoration(
                labelText: 'Kasa / Banka Hesabı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _errorText = null),
              decoration: InputDecoration(
                labelText: 'Tahsilat Tutarı (₺)',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
            ),
            if (rem > 0.01) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('%50 Parçalı'),
                    onPressed: () {
                      setState(() {
                        _amountController.text = (rem * 0.5).toStringAsFixed(2);
                        _errorText = null;
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('Kalanın Tamamı'),
                    onPressed: () {
                      setState(() {
                        _amountController.text = rem.toStringAsFixed(2);
                        _errorText = null;
                      });
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Tahsilatı Kaydet'),
        ),
      ],
    );
  }
}

class _StockTemplateAndReturnSection extends StatefulWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const _StockTemplateAndReturnSection({
    required this.data,
    required this.actions,
  });

  @override
  State<_StockTemplateAndReturnSection> createState() =>
      _StockTemplateAndReturnSectionState();
}

class _StockTemplateAndReturnSectionState
    extends State<_StockTemplateAndReturnSection> {
  late final TextEditingController _stockCodeController;
  late final TextEditingController _stockNameController;
  late final TextEditingController _qtyController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _vatController;

  String? _templateAccountId;
  String? _selectedTemplateCategory;
  int _selectedPriceTier = 1;

  String? _returnAccountId;
  String? _returnStockId;
  bool _isSalesReturn = true;
  String? _returnError;

  @override
  void initState() {
    super.initState();
    _stockCodeController = TextEditingController();
    _stockNameController = TextEditingController();
    _qtyController = TextEditingController(text: '10');
    _unitPriceController = TextEditingController(text: '0');
    _vatController = TextEditingController(text: '10');
    _syncDefaults();
  }

  @override
  void didUpdateWidget(covariant _StockTemplateAndReturnSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.accounts != widget.data.accounts ||
        oldWidget.data.stocks != widget.data.stocks) {
      _syncDefaults();
    }
  }

  @override
  void dispose() {
    _stockCodeController.dispose();
    _stockNameController.dispose();
    _qtyController.dispose();
    _unitPriceController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  void _syncDefaults() {
    final accounts = widget.data.accounts;
    if (accounts.isNotEmpty) {
      final defaultAccount = widget.data.selectedAccount ?? accounts.first;
      if (_templateAccountId == null ||
          !accounts.any((a) => a.id == _templateAccountId)) {
        _templateAccountId = defaultAccount.id;
        _selectedPriceTier = defaultAccount.priceTier.clamp(1, 10);
      }
      if (_returnAccountId == null ||
          !accounts.any((a) => a.id == _returnAccountId)) {
        _returnAccountId = defaultAccount.id;
      }
    }
    final categories = _templateCategories();
    if (categories.isNotEmpty &&
        (_selectedTemplateCategory == null ||
            !categories.contains(_selectedTemplateCategory))) {
      _selectedTemplateCategory = categories.first;
    }
    final stocks = widget.data.stocks;
    if (stocks.isNotEmpty &&
        (_returnStockId == null || !stocks.any((s) => s.id == _returnStockId))) {
      _applyReturnStock(stocks.first);
    }
  }

  List<String> _templateCategories() {
    final set = <String>{};
    for (final s in widget.data.stocks) {
      final cat = s.templateCategory.trim();
      if (cat.isNotEmpty) set.add(cat);
    }
    if (set.isEmpty && widget.data.stocks.isNotEmpty) {
      set.add('Genel Şablon');
    }
    final list = set.toList()..sort();
    return list;
  }

  void _applyReturnStock(StockBurnItem stock) {
    _returnStockId = stock.id;
    _stockCodeController.text = stock.code;
    _stockNameController.text = stock.name;
    final price = stock.salePriceTl > 0 ? stock.salePriceTl : stock.unitCost;
    _unitPriceController.text = price.toStringAsFixed(2);
  }

  AccountingAccount? _findAccount(String? id) {
    for (final a in widget.data.accounts) {
      if (a.id == id) return a;
    }
    return widget.data.accounts.isNotEmpty ? widget.data.accounts.first : null;
  }

  void _submitTemplateOrder() {
    final account = _findAccount(_templateAccountId);
    final category = _selectedTemplateCategory ?? '';
    if (account == null || category.isEmpty) {
      _showNoticeSnackBar(
        context,
        'Şablon siparişi için cari ve şablon kategorisi seçiniz.',
        isError: true,
      );
      return;
    }
    widget.actions.createOrdersFromStockTemplate(
      account: account,
      templateCategory: category,
      priceTier: _selectedPriceTier,
    );
    _showNoticeSnackBar(
      context,
      '${account.name} için "$category" şablonundan sipariş oluşturuldu.',
    );
  }

  void _submitReturnInvoice() {
    final account = _findAccount(_returnAccountId);
    final code = _stockCodeController.text.trim();
    final name = _stockNameController.text.trim();
    final qty = double.tryParse(_qtyController.text.trim().replaceAll(',', '.'));
    final price = double.tryParse(
      _unitPriceController.text.trim().replaceAll(',', '.'),
    );
    final vat = double.tryParse(_vatController.text.trim().replaceAll(',', '.'));

    if (account == null) {
      setState(() => _returnError = 'Lütfen cari hesap seçiniz.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _returnError = 'Lütfen stok adını giriniz.');
      return;
    }
    if (qty == null || qty <= 0 || price == null || price <= 0) {
      setState(() => _returnError = 'Miktar ve birim fiyat 0\'dan büyük olmalıdır.');
      return;
    }
    if (vat == null || vat < 0) {
      setState(() => _returnError = 'KDV oranı geçerli bir değer olmalıdır.');
      return;
    }

    setState(() => _returnError = null);
    widget.actions.createReturnErpInvoice(
      account: account,
      isSalesReturn: _isSalesReturn,
      stockCode: code.isEmpty ? 'IADE-STK' : code,
      stockName: name,
      qtyKg: qty,
      unitPriceTl: price,
      vatPercent: vat,
    );
    _showNoticeSnackBar(
      context,
      '${_isSalesReturn ? "Satıştan İade" : "Alıştan İade"} faturası oluşturuldu.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.data.accounts;
    final categories = _templateCategories();
    final templateAccount = _findAccount(_templateAccountId);
    final returnAccount = _findAccount(_returnAccountId);
    final matchingCount = widget.data.stocks
        .where(
          (s) =>
              _selectedTemplateCategory == 'Genel Şablon' ||
              s.templateCategory.trim() == _selectedTemplateCategory,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InnerSubCard(
          title: 'Stok Şablonundan Toplu Sipariş Oluşturma',
          icon: Icons.playlist_add_check_outlined,
          child: accounts.isEmpty || categories.isEmpty
              ? const _EmptySectionNotice(
                  message:
                      'Şablon siparişi için en az bir cari ve stok şablonu gereklidir.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 260,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Sipariş Carisi',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: templateAccount?.id,
                                isDense: true,
                                isExpanded: true,
                                items: accounts
                                    .map(
                                      (a) => DropdownMenuItem<String>(
                                        value: a.id,
                                        child: Text(
                                          '${a.code} — ${a.name}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (id) {
                                  if (id == null) return;
                                  final acc = _findAccount(id);
                                  setState(() {
                                    _templateAccountId = id;
                                    if (acc != null) {
                                      _selectedPriceTier =
                                          acc.priceTier.clamp(1, 10);
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Stok Şablon Kategorisi',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedTemplateCategory,
                                isDense: true,
                                isExpanded: true,
                                items: categories
                                    .map(
                                      (cat) => DropdownMenuItem<String>(
                                        value: cat,
                                        child: Text(
                                          cat,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (cat) {
                                  if (cat != null) {
                                    setState(
                                      () => _selectedTemplateCategory = cat,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fiyat Grubu',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedPriceTier,
                                isDense: true,
                                isExpanded: true,
                                items: List<int>.generate(10, (i) => i + 1)
                                    .map(
                                      (tier) => DropdownMenuItem<int>(
                                        value: tier,
                                        child: Text('Fiyat-$tier'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (tier) {
                                  if (tier != null) {
                                    setState(() => _selectedPriceTier = tier);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Şablondaki ürün sayısı: $matchingCount kalem • Seçili grup: Fiyat-$_selectedPriceTier',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kBodySlate,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _submitTemplateOrder,
                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                          label: const Text('Şablondan Sipariş Oluştur'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _InnerSubCard(
          title: 'Satıştan İade / Alıştan İade Faturası Oluştur',
          icon: Icons.assignment_return_outlined,
          child: accounts.isEmpty
              ? const _EmptySectionNotice(
                  message: 'İade faturası düzenlemek için cari hesap gereklidir.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.keyboard_return, size: 16),
                          label: Text('Satıştan İade Faturası'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.undo_outlined, size: 16),
                          label: Text('Alıştan İade Faturası'),
                        ),
                      ],
                      selected: <bool>{_isSalesReturn},
                      onSelectionChanged: (s) =>
                          setState(() => _isSalesReturn = s.first),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 240,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Cari Hesap',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: returnAccount?.id,
                                isDense: true,
                                isExpanded: true,
                                items: accounts
                                    .map(
                                      (a) => DropdownMenuItem<String>(
                                        value: a.id,
                                        child: Text(
                                          '${a.code} — ${a.name}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() => _returnAccountId = id);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        if (widget.data.stocks.isNotEmpty)
                          SizedBox(
                            width: 240,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Stok Kartından Seç',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _returnStockId,
                                  isDense: true,
                                  isExpanded: true,
                                  items: widget.data.stocks
                                      .map(
                                        (s) => DropdownMenuItem<String>(
                                          value: s.id,
                                          child: Text(
                                            '${s.code} — ${s.name}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (id) {
                                    if (id == null) return;
                                    final found = widget.data.stocks.firstWhere(
                                      (s) => s.id == id,
                                      orElse: () => widget.data.stocks.first,
                                    );
                                    setState(() => _applyReturnStock(found));
                                  },
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _stockCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Stok Kodu',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _stockNameController,
                            decoration: const InputDecoration(
                              labelText: 'Stok Adı',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Miktar (Kg)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _unitPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Birim Fiyat ₺',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _vatController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'KDV %',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_returnError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _returnError!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kRedDark,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: _submitReturnInvoice,
                        icon: const Icon(Icons.receipt_outlined, size: 16),
                        label: Text(
                          _isSalesReturn
                              ? 'Satıştan İade Faturasını Kes'
                              : 'Alıştan İade Faturasını Kes',
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _OrderInvoiceMatrixCard extends StatelessWidget {
  final List<ErpOrderWaybillInvoiceItem> documents;

  const _OrderInvoiceMatrixCard({required this.documents});

  @override
  Widget build(BuildContext context) {
    final matrix = PreAccountingMathEngine.buildOrderAnalyticalMatrix(documents);
    final totalOrdered = documents.fold<double>(
      0.0,
      (s, d) => s + d.orderedQtyKg,
    );
    final totalInvoiced = documents.fold<double>(
      0.0,
      (s, d) => s + d.invoicedQtyKg,
    );
    final totalGap = totalOrdered - totalInvoiced;
    final openDocsCount =
        documents.where((d) => d.unbilledQtyGapKg.abs() > 0.01).length;

    return _InnerSubCard(
      title: 'Sipariş ↔ Fatura Kontrolü & Sipariş / Ürün Analiz Matrisi',
      icon: Icons.grid_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KpiTile(
                title: 'Sipariş Toplamı',
                value: '${_formatQty(totalOrdered)} Kg',
                accent: _kTitleDark,
              ),
              _KpiTile(
                title: 'Faturalanan Toplam',
                value: '${_formatQty(totalInvoiced)} Kg',
                accent: _kEmeraldPrimary,
              ),
              _KpiTile(
                title: 'Faturasız Fark',
                value: '${_formatQty(totalGap)} Kg',
                accent: totalGap.abs() > 0.01 ? _kAmberDark : _kEmeraldPrimary,
              ),
              _KpiTile(
                title: 'Açık Kontrol Belgesi',
                value: '$openDocsCount Adet',
                accent: openDocsCount > 0 ? _kRedDark : _kEmeraldPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Belge Bazlı Sipariş ↔ İrsaliye ↔ Fatura Fark Kontrolü',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _kTitleDark,
            ),
          ),
          const SizedBox(height: 8),
          if (documents.isEmpty)
            const _EmptySectionNotice(
              message: 'Kontrol edilecek sipariş/fatura belgesi bulunmuyor.',
            )
          else
            ...documents.map((d) {
              final gap = d.unbilledQtyGapKg;
              final isBalanced = gap.abs() < 0.01 && d.stage == 'FATURALANDI';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kSurfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${d.orderDocNo} → ${d.waybillDocNo ?? "İrsaliye Yok"} → ${d.invoiceDocNo ?? "Fatura Yok"}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _kTitleDark,
                            ),
                          ),
                          Text(
                            '${d.accountName} • ${d.stockName} | Sipariş: ${_formatQty(d.orderedQtyKg)} Kg | Sevk: ${_formatQty(d.shippedQtyKg)} Kg | Fatura: ${_formatQty(d.invoicedQtyKg)} Kg',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _kBodySlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ToneBadge(
                      label: isBalanced
                          ? 'Tam Eşleşti'
                          : 'Fark: ${_formatQty(gap)} Kg',
                      bgColor: isBalanced ? _kEmeraldBg : _kAmberBg,
                      borderColor:
                          isBalanced ? _kEmeraldBorder : _kAmberBorder,
                      textColor: isBalanced ? _kEmeraldDark : _kAmberDark,
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          const Text(
            'Sipariş / Ürün Analiz Matrisi (OrderProductMatrixCell)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _kTitleDark,
            ),
          ),
          const SizedBox(height: 8),
          if (matrix.isEmpty)
            const _EmptySectionNotice(
              message: 'Analitik matris verisi henüz oluşmadı.',
            )
          else
            _HorizontalTableShell(
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 42,
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(_kSurfaceSubtle),
                columns: const <DataColumn>[
                  DataColumn(label: Text('Cari')),
                  DataColumn(label: Text('Ürün')),
                  DataColumn(numeric: true, label: Text('Sipariş (Kg)')),
                  DataColumn(numeric: true, label: Text('Fatura (Kg)')),
                  DataColumn(numeric: true, label: Text('Fark (Kg)')),
                  DataColumn(numeric: true, label: Text('Tepsi')),
                  DataColumn(numeric: true, label: Text('Net Tutar')),
                ],
                rows: matrix
                    .map(
                      (OrderProductMatrixCell cell) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(cell.accountName)),
                          DataCell(Text(cell.stockName)),
                          DataCell(Text(_formatQty(cell.totalOrderedKg))),
                          DataCell(Text(_formatQty(cell.totalInvoicedKg))),
                          DataCell(
                            Text(
                              _formatQty(
                                cell.totalOrderedKg - cell.totalInvoicedKg,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color:
                                    (cell.totalOrderedKg - cell.totalInvoicedKg)
                                                .abs() >
                                            0.01
                                        ? _kAmberDark
                                        : _kEmeraldPrimary,
                              ),
                            ),
                          ),
                          DataCell(Text('${cell.totalTrays}')),
                          DataCell(
                            Text(
                              PreAccountingMathEngine.formatTl(cell.totalNetTl),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _DealerContractsCard extends StatelessWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const _DealerContractsCard({
    required this.data,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return _InnerSubCard(
      title: 'Bayi Sözleşmeleri & Teminat Yönetimi',
      icon: Icons.handshake_outlined,
      trailing: FilledButton.tonalIcon(
        onPressed: data.accounts.isEmpty
            ? null
            : () {
                showDialog<void>(
                  context: context,
                  builder: (_) => _DealerContractUpsertDialog(
                    accounts: data.accounts,
                    defaultDateKey: data.selectedDateKey,
                    onSave: (record) {
                      actions.upsertDealerContract(record);
                      _showNoticeSnackBar(
                        context,
                        '${record.contractNo} bayi sözleşmesi kaydedildi.',
                      );
                    },
                  ),
                );
              },
        icon: const Icon(Icons.add, size: 16),
        label: const Text('+ Yeni Sözleşme'),
      ),
      child: data.dealerContracts.isEmpty
          ? const _EmptySectionNotice(
              message: 'Tanımlı bayi sözleşmesi bulunmuyor.',
            )
          : Column(
              children: data.dealerContracts
                  .map(
                    (c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.isTerminated ? _kRedBg : _kSurfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: c.isTerminated ? _kRedBorder : _kBorderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${c.contractNo} • ${c.accountName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _kTitleDark,
                                  ),
                                ),
                              ),
                              _ToneBadge(
                                label: c.isTerminated ? 'FESHEDİLDİ' : 'AKTİF',
                                bgColor:
                                    c.isTerminated ? Colors.white : _kEmeraldBg,
                                borderColor: c.isTerminated
                                    ? _kRedBorder
                                    : _kEmeraldBorder,
                                textColor: c.isTerminated
                                    ? _kRedDark
                                    : _kEmeraldDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tarih: ${c.dateKey} (${c.durationMonths} Ay) • '
                            'Bölge: ${c.regionName} • Fiyat-${c.priceTier} • '
                            'Marj: %${c.dealerMarginPercent.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kBodySlate,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Teminat: ${c.collateralType} — ${PreAccountingMathEngine.formatTl(c.collateralAmountTl)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kTitleDark,
                            ),
                          ),
                          if (c.isTerminated && c.terminationNote.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Fesih Gerekçesi: ${c.terminationNote}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _kRedDark,
                              ),
                            ),
                          ],
                          if (!c.isTerminated) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    showDialog<void>(
                                      context: context,
                                      builder: (_) =>
                                          _DealerContractUpsertDialog(
                                            accounts: data.accounts,
                                            defaultDateKey: data.selectedDateKey,
                                            initialContract: c,
                                            onSave: (updated) {
                                              actions.upsertDealerContract(
                                                updated,
                                              );
                                              _showNoticeSnackBar(
                                                context,
                                                '${updated.contractNo} sözleşmesi güncellendi.',
                                              );
                                            },
                                          ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Düzenle'),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _kRedDark,
                                  ),
                                  onPressed: () {
                                    showDialog<void>(
                                      context: context,
                                      builder: (_) => _TerminateContractDialog(
                                        contract: c,
                                        onConfirm: (reason) {
                                          actions.terminateDealerContract(
                                            contractId: c.id,
                                            reason: reason,
                                          );
                                          _showNoticeSnackBar(
                                            context,
                                            '${c.contractNo} sözleşmesi feshedildi.',
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Sözleşme Feshi'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _DealerContractUpsertDialog extends StatefulWidget {
  final List<AccountingAccount> accounts;
  final String defaultDateKey;
  final DealerContractRecord? initialContract;
  final ValueChanged<DealerContractRecord> onSave;

  const _DealerContractUpsertDialog({
    required this.accounts,
    required this.defaultDateKey,
    this.initialContract,
    required this.onSave,
  });

  @override
  State<_DealerContractUpsertDialog> createState() =>
      _DealerContractUpsertDialogState();
}

class _DealerContractUpsertDialogState
    extends State<_DealerContractUpsertDialog> {
  late final TextEditingController _contractNoController;
  late final TextEditingController _dateKeyController;
  late final TextEditingController _durationController;
  late final TextEditingController _collateralAmountController;
  late final TextEditingController _collateralTypeController;
  late final TextEditingController _regionController;
  late final TextEditingController _marginController;

  late String _accountId;
  late int _priceTier;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialContract;
    final defaultAccount = widget.accounts.first;
    final existingAccountId = existing?.accountId;
    _accountId = (existingAccountId != null &&
            widget.accounts.any((a) => a.id == existingAccountId))
        ? existingAccountId
        : defaultAccount.id;
    _priceTier = (existing?.priceTier ?? defaultAccount.priceTier).clamp(1, 10);

    _contractNoController = TextEditingController(
      text: existing?.contractNo ??
          'SZL-${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    _dateKeyController = TextEditingController(
      text: existing?.dateKey ?? widget.defaultDateKey,
    );
    _durationController = TextEditingController(
      text: '${existing?.durationMonths ?? 12}',
    );
    _collateralAmountController = TextEditingController(
      text: (existing?.collateralAmountTl ?? 100000.0).toStringAsFixed(0),
    );
    _collateralTypeController = TextEditingController(
      text: existing?.collateralType ?? 'Teminat Mektubu',
    );
    _regionController = TextEditingController(
      text: existing?.regionName ??
          (defaultAccount.cityDistrict.isEmpty
              ? 'Marmara Bölgesi'
              : defaultAccount.cityDistrict),
    );
    _marginController = TextEditingController(
      text: (existing?.dealerMarginPercent ?? 8.0).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _contractNoController.dispose();
    _dateKeyController.dispose();
    _durationController.dispose();
    _collateralAmountController.dispose();
    _collateralTypeController.dispose();
    _regionController.dispose();
    _marginController.dispose();
    super.dispose();
  }

  void _submit() {
    final contractNo = _contractNoController.text.trim();
    final dateKey = _dateKeyController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    final collateral = double.tryParse(
      _collateralAmountController.text.trim().replaceAll(',', '.'),
    );
    final margin = double.tryParse(
      _marginController.text.trim().replaceAll(',', '.'),
    );
    final collateralType = _collateralTypeController.text.trim();
    final region = _regionController.text.trim();

    if (contractNo.isEmpty || dateKey.isEmpty || region.isEmpty) {
      setState(() => _errorText = 'Sözleşme no, tarih ve bölge zorunludur.');
      return;
    }
    if (duration == null || duration <= 0) {
      setState(() => _errorText = 'Süre (Ay) pozitif bir tam sayı olmalıdır.');
      return;
    }
    if (collateral == null || collateral < 0 || margin == null || margin < 0) {
      setState(
        () => _errorText = 'Teminat tutarı ve marj % negatif olamaz.',
      );
      return;
    }

    final acc = widget.accounts.firstWhere(
      (a) => a.id == _accountId,
      orElse: () => widget.accounts.first,
    );
    final existing = widget.initialContract;
    final record = DealerContractRecord(
      id: existing?.id ?? 'CNT-${DateTime.now().millisecondsSinceEpoch}',
      contractNo: contractNo,
      dateKey: dateKey,
      durationMonths: duration,
      collateralAmountTl: collateral,
      collateralType:
          collateralType.isEmpty ? 'Teminat Mektubu' : collateralType,
      accountId: acc.id,
      accountName: acc.name,
      regionName: region,
      priceTier: _priceTier,
      dealerMarginPercent: margin,
      isTerminated: existing?.isTerminated ?? false,
      terminationNote: existing?.terminationNote ?? '',
    );

    Navigator.of(context).pop();
    widget.onSave(record);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialContract == null
            ? 'Yeni Bayi Sözleşmesi'
            : 'Bayi Sözleşmesini Düzenle',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Bayi / Cari Hesap',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _accountId,
                    isDense: true,
                    isExpanded: true,
                    items: widget.accounts
                        .map(
                          (a) => DropdownMenuItem<String>(
                            value: a.id,
                            child: Text(
                              '${a.code} — ${a.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) setState(() => _accountId = id);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contractNoController,
                decoration: const InputDecoration(
                  labelText: 'Sözleşme No',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dateKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Başlangıç (YYYY-AA-GG)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Süre (Ay)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _regionController,
                      decoration: const InputDecoration(
                        labelText: 'Bölge Adı',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fiyat Grubu',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _priceTier,
                          isDense: true,
                          isExpanded: true,
                          items: List<int>.generate(10, (i) => i + 1)
                              .map(
                                (tier) => DropdownMenuItem<int>(
                                  value: tier,
                                  child: Text('Fiyat-$tier'),
                                ),
                              )
                              .toList(),
                          onChanged: (tier) {
                            if (tier != null) {
                              setState(() => _priceTier = tier);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _collateralTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Teminat Türü',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _collateralAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Teminat Tutarı (₺)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _marginController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Bayi İskonto / Marj (%)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kRedDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Sözleşmeyi Kaydet'),
        ),
      ],
    );
  }
}

class _TerminateContractDialog extends StatefulWidget {
  final DealerContractRecord contract;
  final ValueChanged<String> onConfirm;

  const _TerminateContractDialog({
    required this.contract,
    required this.onConfirm,
  });

  @override
  State<_TerminateContractDialog> createState() =>
      _TerminateContractDialogState();
}

class _TerminateContractDialogState extends State<_TerminateContractDialog> {
  late final TextEditingController _reasonController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorText = 'Fesih gerekçesi girmek zorunludur.');
      return;
    }
    Navigator.of(context).pop();
    widget.onConfirm(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bayi Sözleşmesi Feshi'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.contract.contractNo} (${widget.contract.accountName}) sözleşmesini feshetmek üzeresiniz.',
              style: const TextStyle(fontSize: 12.5, color: _kBodySlate),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              onChanged: (_) => setState(() => _errorText = null),
              decoration: InputDecoration(
                labelText: 'Fesih Gerekçesi / Notu',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
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
          style: FilledButton.styleFrom(backgroundColor: _kRedDark),
          onPressed: _submit,
          child: const Text('Sözleşmeyi Feshet'),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. ANALİTİK RAPORLAR, DEPOZİTO, ÖZEL EXCEL, .REPX & DÖNEM SONU DEVİR PANELİ
// ============================================================================

/// Plasiyer performansı, depozito/tepsi takibi, maliyetli envanter & fiyat geçmişi,
/// etkileşimli özel Excel tabloları, 6 tıklanabilir .repx şablonu ve dönem sonu devir sihirbazı.
class HasibuAnalyticalReportsAndRepxPanel extends StatelessWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const HasibuAnalyticalReportsAndRepxPanel({
    super.key,
    required this.data,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final salesRepRows = PreAccountingMathEngine.buildSalesRepReport(
      accounts: data.accounts,
      docs: data.erpDocuments,
      transactions: data.transactions,
    );

    return _SectionCardShell(
      title: 'Analitik Raporlar, Özel Tablo, .REPX & Dönem Sonu Devir',
      subtitle:
          'Plasiyer Performans, Depozito/Tepsi, Maliyetli Envanter, 6 .REPX Belge Önizleme & Devir Sihirbazı',
      icon: Icons.analytics_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SalesRepPerformanceCard(rows: salesRepRows),
          const SizedBox(height: 14),
          _DepositAndContainerTrackingCard(
            accounts: data.accounts,
            containers: data.containers,
            stocks: data.stocks,
          ),
          const SizedBox(height: 14),
          _InventoryValuationAndPriceHistoryCard(stocks: data.stocks),
          const SizedBox(height: 14),
          _CustomSpreadsheetSection(
            sheets: data.customSpreadsheets,
            actions: actions,
          ),
          const SizedBox(height: 14),
          _RepxTemplatesCard(data: data),
          const SizedBox(height: 14),
          _PeriodRolloverWizardSection(data: data, actions: actions),
        ],
      ),
    );
  }
}

class _SalesRepPerformanceCard extends StatelessWidget {
  final List<SalesRepPerformanceRow> rows;

  const _SalesRepPerformanceCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _InnerSubCard(
      title: 'Plasiyer Performans & Tahsilat Oranı',
      icon: Icons.leaderboard_outlined,
      child: rows.isEmpty
          ? const _EmptySectionNotice(
              message: 'Plasiyer satış veya tahsilat hareketi bulunmuyor.',
            )
          : Column(
              children: rows
                  .map(
                    (row) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kSurfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${row.salesRepName} (${row.invoiceCount} Belge)',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _kTitleDark,
                                  ),
                                ),
                              ),
                              _ToneBadge(
                                label:
                                    'Tahsilat %${row.collectionRatioPercent.toStringAsFixed(1)}',
                                bgColor: row.collectionRatioPercent >= 70
                                    ? _kEmeraldBg
                                    : _kAmberBg,
                                borderColor: row.collectionRatioPercent >= 70
                                    ? _kEmeraldBorder
                                    : _kAmberBorder,
                                textColor: row.collectionRatioPercent >= 70
                                    ? _kEmeraldDark
                                    : _kAmberDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Satış: ${PreAccountingMathEngine.formatTl(row.totalSalesTl)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _kBodySlate,
                                ),
                              ),
                              Text(
                                'Tahsilat: ${PreAccountingMathEngine.formatTl(row.totalCollectedTl)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _kEmeraldPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (row.collectionRatioPercent / 100.0).clamp(
                                0.0,
                                1.0,
                              ),
                              minHeight: 6,
                              backgroundColor: _kBorderColor,
                              color: row.collectionRatioPercent >= 70
                                  ? _kEmeraldPrimary
                                  : _kAmberDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _DepositAndContainerTrackingCard extends StatelessWidget {
  final List<AccountingAccount> accounts;
  final List<ContainerMovement> containers;
  final List<StockBurnItem> stocks;

  const _DepositAndContainerTrackingCard({
    required this.accounts,
    required this.containers,
    required this.stocks,
  });

  @override
  Widget build(BuildContext context) {
    final totalTrays = accounts.fold<int>(0, (s, a) => s + a.trayBalance);
    final totalCrates = accounts.fold<int>(0, (s, a) => s + a.crateBalance);
    double depositUnit = 350.0;
    for (final s in stocks) {
      if (s.depositUnitTl > 0) {
        depositUnit = s.depositUnitTl;
        break;
      }
    }
    final totalDepositValue = totalTrays * depositUnit;
    final emanetAccounts = accounts
        .where((a) => a.trayBalance != 0 || a.crateBalance != 0)
        .toList();
    final depositStocks = stocks.where((s) => s.depositUnitTl > 0).toList();

    return _InnerSubCard(
      title: 'Depozitolu Ürün / Tepsi & Kasa Emanet Takibi',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KpiTile(
                title: 'Emanet Tepsi Toplamı',
                value: '$totalTrays Adet',
                accent: _kBlueDark,
              ),
              _KpiTile(
                title: 'Emanet Kasa / Köşebent',
                value: '$totalCrates Adet',
                accent: _kBodySlate,
              ),
              _KpiTile(
                title: 'Tepsi Depozito Karşılığı',
                value: PreAccountingMathEngine.formatTl(totalDepositValue),
                accent: _kAmberDark,
              ),
              _KpiTile(
                title: 'Depozitolu Stok Kalemi',
                value: '${depositStocks.length} Ürün',
                accent: _kEmeraldPrimary,
              ),
            ],
          ),
          if (emanetAccounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Cari Bazlı Emanet Tepsi / Kasa Bakiyeleri',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kTitleDark,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: emanetAccounts
                  .map(
                    (a) => _ToneBadge(
                      label:
                          '${a.name}: ${a.trayBalance} Tepsi / ${a.crateBalance} Kasa',
                      bgColor: _kSurfaceSubtle,
                      borderColor: _kBorderColor,
                      textColor: _kTitleDark,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          if (containers.isEmpty)
            const _EmptySectionNotice(
              message: 'Kayıtlı tepsi/kasa hareket fişi bulunmuyor.',
            )
          else
            ...containers.take(8).map(
                  (m) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _kSurfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${m.dateKey} • ${m.accountName} (${m.containerType})'
                            '${m.note.isEmpty ? "" : " — ${m.note}"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTitleDark,
                            ),
                          ),
                        ),
                        Text(
                          'Verilen: ${m.givenQty} | İade: ${m.returnedQty} | Net: ${m.netRemaining}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: m.netRemaining > 0
                                ? _kAmberDark
                                : _kEmeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _InventoryValuationAndPriceHistoryCard extends StatelessWidget {
  final List<StockBurnItem> stocks;

  const _InventoryValuationAndPriceHistoryCard({required this.stocks});

  @override
  Widget build(BuildContext context) {
    final totalValuation = stocks.fold<double>(
      0.0,
      (s, i) => s + i.totalValuation,
    );
    final criticalCount = stocks.where((s) => s.isCritical).length;

    return _InnerSubCard(
      title: 'Maliyetli Envanter Değerlemesi & Stok Fiyat Geçmişi',
      icon: Icons.warehouse_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KpiTile(
                title: 'Toplam Envanter Maliyeti',
                value: PreAccountingMathEngine.formatTl(totalValuation),
                accent: _kEmeraldPrimary,
              ),
              _KpiTile(
                title: 'Aktif Stok Kalemi',
                value: '${stocks.length} Kalem',
                accent: _kTitleDark,
              ),
              _KpiTile(
                title: 'Kritik Stok (<=15 Gün)',
                value: '$criticalCount Kalem',
                accent: criticalCount > 0 ? _kRedDark : _kEmeraldPrimary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (stocks.isEmpty)
            const _EmptySectionNotice(
              message: 'Stok envanter kalemi bulunmuyor.',
            )
          else
            ...stocks.map((stk) {
              final history = _parsePriceHistoryEntries(stk.priceHistoryJson);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kSurfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: stk.isCritical ? _kRedBorder : _kBorderColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${stk.code} — ${stk.name}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _kTitleDark,
                            ),
                          ),
                        ),
                        _ToneBadge(
                          label: stk.isCritical
                              ? 'KRİTİK (${stk.remainingDays} Gün)'
                              : '${stk.remainingDays} Gün Stok',
                          bgColor: stk.isCritical ? _kRedBg : _kEmeraldBg,
                          borderColor:
                              stk.isCritical ? _kRedBorder : _kEmeraldBorder,
                          textColor:
                              stk.isCritical ? _kRedDark : _kEmeraldDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mevcut: ${_formatQty(stk.currentQty)} ${stk.unit} • '
                      'Birim Maliyet: ${PreAccountingMathEngine.formatTl(stk.unitCost)} • '
                      'Satış Fiyatı: ${PreAccountingMathEngine.formatTl(stk.salePriceTl)} • '
                      'Envanter Değeri: ${PreAccountingMathEngine.formatTl(stk.totalValuation)}',
                      style: const TextStyle(fontSize: 12, color: _kBodySlate),
                    ),
                    if (history.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: history
                            .map(
                              (entry) => _ToneBadge(
                                label: entry.entries
                                    .map((e) => '${e.key}: ${e.value}')
                                    .join(' | '),
                                bgColor: Colors.white,
                                borderColor: _kBorderColor,
                                textColor: _kBodySlate,
                                icon: Icons.timeline_outlined,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CustomSpreadsheetSection extends StatelessWidget {
  final List<CustomSpreadsheetRecord> sheets;
  final PreAccountingAdvancedActions actions;

  const _CustomSpreadsheetSection({
    required this.sheets,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return _InnerSubCard(
      title: 'Etkileşimli Özel Excel Tabloları (OzelTablo)',
      icon: Icons.table_chart_outlined,
      trailing: FilledButton.tonalIcon(
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (_) => _CustomSpreadsheetRowDialog(
              onSubmit: (title, category, debit, credit, formula) {
                actions.addInteractiveCustomSpreadsheetRow(
                  sheetTitle: title,
                  categoryName: category,
                  debitColumnTl: debit,
                  creditColumnTl: credit,
                  formulaNote: formula,
                );
                _showNoticeSnackBar(
                  context,
                  '"$title" özel tablo satırı eklendi.',
                );
              },
            ),
          );
        },
        icon: const Icon(Icons.add_box_outlined, size: 16),
        label: const Text('+ Özel Tablo Satırı Ekle'),
      ),
      child: sheets.isEmpty
          ? const _EmptySectionNotice(
              message: 'Henüz özel tablo satırı oluşturulmadı.',
            )
          : Column(
              children: sheets
                  .map(
                    (sh) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kSurfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${sh.sheetTitle} (${sh.periodKey})',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _kTitleDark,
                                  ),
                                ),
                                Text(
                                  '${sh.categoryName} • Formül: ${sh.formulaNote.isEmpty ? "-" : sh.formulaNote}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _kMutedSlate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'B: ${PreAccountingMathEngine.formatTl(sh.debitColumnTl)} | A: ${PreAccountingMathEngine.formatTl(sh.creditColumnTl)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _kBodySlate,
                                ),
                              ),
                              Text(
                                'Net: ${PreAccountingMathEngine.formatTl(sh.netValueTl)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: _balanceColor(sh.netValueTl),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _CustomSpreadsheetRowDialog extends StatefulWidget {
  final void Function(
    String sheetTitle,
    String categoryName,
    double debitColumnTl,
    double creditColumnTl,
    String formulaNote,
  )
  onSubmit;

  const _CustomSpreadsheetRowDialog({required this.onSubmit});

  @override
  State<_CustomSpreadsheetRowDialog> createState() =>
      _CustomSpreadsheetRowDialogState();
}

class _CustomSpreadsheetRowDialogState
    extends State<_CustomSpreadsheetRowDialog> {
  late final TextEditingController _sheetTitleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _debitController;
  late final TextEditingController _creditController;
  late final TextEditingController _formulaController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _sheetTitleController = TextEditingController(
      text: 'PLASİYER & BÖLGE TAHSİLAT ANALİZİ',
    );
    _categoryController = TextEditingController(text: 'Yönetim Tablosu');
    _debitController = TextEditingController(text: '0');
    _creditController = TextEditingController(text: '0');
    _formulaController = TextEditingController(
      text: '=SUM(Alacak)-SUM(Borç)',
    );
  }

  @override
  void dispose() {
    _sheetTitleController.dispose();
    _categoryController.dispose();
    _debitController.dispose();
    _creditController.dispose();
    _formulaController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _sheetTitleController.text.trim();
    final category = _categoryController.text.trim();
    final debit = double.tryParse(
      _debitController.text.trim().replaceAll(',', '.'),
    );
    final credit = double.tryParse(
      _creditController.text.trim().replaceAll(',', '.'),
    );
    final formula = _formulaController.text.trim();

    if (title.isEmpty || category.isEmpty) {
      setState(() => _errorText = 'Tablo başlığı ve kategori zorunludur.');
      return;
    }
    if (debit == null || debit < 0 || credit == null || credit < 0) {
      setState(() => _errorText = 'Borç ve alacak sütunları 0 veya pozitif olmalıdır.');
      return;
    }
    Navigator.of(context).pop();
    widget.onSubmit(title, category, debit, credit, formula);
  }

  @override
  Widget build(BuildContext context) {
    final debit =
        double.tryParse(_debitController.text.trim().replaceAll(',', '.')) ??
        0.0;
    final credit =
        double.tryParse(_creditController.text.trim().replaceAll(',', '.')) ??
        0.0;
    final net = credit - debit;

    return AlertDialog(
      title: const Text('Yeni Özel Excel Tablo Satırı'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _sheetTitleController,
                decoration: const InputDecoration(
                  labelText: 'Tablo Başlığı',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _debitController,
                      onChanged: (_) => setState(() => _errorText = null),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Borç / Gider Sütunu (₺)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _creditController,
                      onChanged: (_) => setState(() => _errorText = null),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Alacak / Gelir Sütunu (₺)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _formulaController,
                decoration: const InputDecoration(
                  labelText: 'Formül / Açıklama Notu',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kSurfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorderColor),
                ),
                child: Text(
                  'Canlı Net Sonuç: ${PreAccountingMathEngine.formatTl(net)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _balanceColor(net),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kRedDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Satırı Ekle'),
        ),
      ],
    );
  }
}

class _RepxTemplatesCard extends StatelessWidget {
  final PreAccountingAdvancedViewData data;

  const _RepxTemplatesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _InnerSubCard(
      title: 'Belge Dizayn (.REPX) Canlı Önizleme & CSV Dışa Aktarım Şablonları',
      icon: Icons.print_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: RepxDocumentRegistry.templates
            .map(
              (tpl) => ActionChip(
                avatar: const Icon(Icons.description_outlined, size: 16),
                label: Text('${tpl.fileName} (${tpl.category})'),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => _RepxPreviewDialog(
                      template: tpl,
                      data: data,
                    ),
                  );
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RepxPreviewDialog extends StatefulWidget {
  final RepxTemplateSpec template;
  final PreAccountingAdvancedViewData data;

  const _RepxPreviewDialog({
    required this.template,
    required this.data,
  });

  @override
  State<_RepxPreviewDialog> createState() => _RepxPreviewDialogState();
}

class _RepxPreviewDialogState extends State<_RepxPreviewDialog> {
  late final ScrollController _previewScrollController;
  bool _showCsv = false;

  @override
  void initState() {
    super.initState();
    _previewScrollController = ScrollController();
  }

  @override
  void dispose() {
    _previewScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewText = RepxDocumentRegistry.renderPreviewText(
      widget.template.templateId,
      widget.data,
    );
    final csvText = RepxDocumentRegistry.exportCsv(
      widget.template.templateId,
      widget.data,
    );
    final activeOutput = _showCsv ? csvText : previewText;

    return AlertDialog(
      title: Text('${widget.template.fileName} — ${widget.template.title}'),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.article_outlined, size: 16),
                  label: Text('Canlı Belge Önizleme'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.table_view_outlined, size: 16),
                  label: Text('CSV Çıktısı'),
                ),
              ],
              selected: <bool>{_showCsv},
              onSelectionChanged: (s) => setState(() => _showCsv = s.first),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kSurfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorderColor),
                ),
                child: Scrollbar(
                  controller: _previewScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _previewScrollController,
                    child: SelectableText(
                      activeOutput,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _kTitleDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: previewText));
            if (!context.mounted) return;
            _showNoticeSnackBar(
              context,
              '${widget.template.fileName} metin çıktısı panoya kopyalandı.',
            );
          },
          icon: const Icon(Icons.copy_outlined, size: 16),
          label: const Text('Metin Kopyala'),
        ),
        FilledButton.tonalIcon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: csvText));
            if (!context.mounted) return;
            _showNoticeSnackBar(
              context,
              '${widget.template.fileName} CSV çıktısı panoya kopyalandı.',
            );
          },
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('CSV Kopyala'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _PeriodRolloverWizardSection extends StatefulWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const _PeriodRolloverWizardSection({
    required this.data,
    required this.actions,
  });

  @override
  State<_PeriodRolloverWizardSection> createState() =>
      _PeriodRolloverWizardSectionState();
}

class _PeriodRolloverWizardSectionState
    extends State<_PeriodRolloverWizardSection> {
  late final TextEditingController _nextPeriodController;
  late final TextEditingController _rolloverDateController;
  PeriodRolloverPreview? _localPreview;

  @override
  void initState() {
    super.initState();
    _nextPeriodController = TextEditingController(
      text:
          widget.data.rolloverPreview?.nextPeriodKey ??
          _nextPeriodSuggestion(widget.data.selectedPeriodKey),
    );
    _rolloverDateController = TextEditingController(
      text:
          widget.data.rolloverPreview?.rolloverDateKey ??
          _nextRolloverDateSuggestion(widget.data.selectedPeriodKey),
    );
    _localPreview = widget.data.rolloverPreview;
  }

  @override
  void didUpdateWidget(covariant _PeriodRolloverWizardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.rolloverPreview != oldWidget.data.rolloverPreview) {
      _localPreview = widget.data.rolloverPreview;
    } else if (widget.data.selectedPeriodKey !=
        oldWidget.data.selectedPeriodKey) {
      _localPreview = widget.data.rolloverPreview;
      _nextPeriodController.text = _nextPeriodSuggestion(
        widget.data.selectedPeriodKey,
      );
      _rolloverDateController.text = _nextRolloverDateSuggestion(
        widget.data.selectedPeriodKey,
      );
    }
  }

  @override
  void dispose() {
    _nextPeriodController.dispose();
    _rolloverDateController.dispose();
    super.dispose();
  }

  void _runPreview() {
    final nextPeriod = _nextPeriodController.text.trim();
    final rolloverDate = _rolloverDateController.text.trim();
    if (nextPeriod.isEmpty || rolloverDate.isEmpty) {
      _showNoticeSnackBar(
        context,
        'Hedef dönem kodu ve devir tarihi boş bırakılamaz.',
        isError: true,
      );
      return;
    }
    final preview = widget.actions.previewPeriodRollover(
      nextPeriodKey: nextPeriod,
      rolloverDateKey: rolloverDate,
    );
    setState(() => _localPreview = preview);
  }

  void _openExecuteConfirmation(PeriodRolloverPreview preview) {
    showDialog<void>(
      context: context,
      builder: (_) => _RolloverConfirmDialog(
        preview: preview,
        onConfirm: () {
          widget.actions.executePeriodRollover(
            nextPeriodKey: preview.nextPeriodKey,
            rolloverDateKey: preview.rolloverDateKey,
          );
          final refreshed = widget.actions.previewPeriodRollover(
            nextPeriodKey: preview.nextPeriodKey,
            rolloverDateKey: preview.rolloverDateKey,
          );
          if (mounted) {
            setState(() => _localPreview = refreshed);
          }
          _showNoticeSnackBar(
            context,
            '${preview.fromPeriodKey} → ${preview.nextPeriodKey} dönem devri tamamlandı.',
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _localPreview ?? widget.data.rolloverPreview;
    final isLocked = preview?.alreadyExecuted ?? false;

    return _InnerSubCard(
      title: 'Dönem Sonu Devir Sihirbazı',
      icon: Icons.autorenew_outlined,
      trailing: isLocked
          ? const _ToneBadge(
              label: 'DEVİR KİLİTLİ (YÜRÜTÜLDÜ)',
              bgColor: _kEmeraldBg,
              borderColor: _kEmeraldBorder,
              textColor: _kEmeraldDark,
              icon: Icons.lock_rounded,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _nextPeriodController,
                  decoration: const InputDecoration(
                    labelText: 'Hedef Dönem / Yıl',
                    hintText: 'Örn: 2027-01',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _rolloverDateController,
                  decoration: const InputDecoration(
                    labelText: 'Devir Tarihi',
                    hintText: 'YYYY-AA-GG',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _runPreview,
                icon: const Icon(Icons.preview_outlined, size: 16),
                label: const Text('Devir Önizlemesi Hesapla'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (preview == null)
            const _EmptySectionNotice(
              message:
                  'Hedef dönem bilgisini girip "Devir Önizlemesi Hesapla" butonuna basın.',
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _KpiTile(
                  title: 'Dönem Geçişi',
                  value: '${preview.fromPeriodKey} → ${preview.nextPeriodKey}',
                  accent: _kTitleDark,
                ),
                _KpiTile(
                  title: 'Devreden Cari',
                  value: '${preview.accountCount} Hesap',
                  accent: _kBlueDark,
                ),
                _KpiTile(
                  title: 'Devreden Alacak',
                  value: PreAccountingMathEngine.formatTl(
                    preview.totalReceivableCarryTl,
                  ),
                  accent: _kEmeraldPrimary,
                ),
                _KpiTile(
                  title: 'Devreden Borç',
                  value: PreAccountingMathEngine.formatTl(
                    preview.totalPayableCarryTl,
                  ),
                  accent: _kRedDark,
                ),
                _KpiTile(
                  title: 'Açık Çek (${preview.openCheckCount})',
                  value: PreAccountingMathEngine.formatTl(
                    preview.openCheckTotalTl,
                  ),
                  accent: _kAmberDark,
                ),
                _KpiTile(
                  title: 'Stok (${preview.stockItemCount} Kalem)',
                  value: PreAccountingMathEngine.formatTl(
                    preview.stockValuationCarryTl,
                  ),
                  accent: _kEmeraldPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isLocked
                        ? '${preview.nextPeriodKey} dönemi için devir işlemi kilitlenmiştir.'
                        : 'Devir Tarihi: ${preview.rolloverDateKey} — Onay sonrası geri alınamaz.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isLocked ? _kEmeraldDark : _kBodySlate,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: isLocked
                      ? null
                      : () => _openExecuteConfirmation(preview),
                  icon: Icon(
                    isLocked ? Icons.lock_rounded : Icons.check_circle_outline,
                    size: 16,
                  ),
                  label: Text(
                    isLocked ? 'Devir Tamamlandı' : 'Dönem Devrini Çalıştır',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RolloverConfirmDialog extends StatelessWidget {
  final PeriodRolloverPreview preview;
  final VoidCallback onConfirm;

  const _RolloverConfirmDialog({
    required this.preview,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dönem Sonu Devir Onayı'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${preview.fromPeriodKey} döneminden ${preview.nextPeriodKey} dönemine '
              '(${preview.rolloverDateKey}) devir işlemi çalıştırılacak:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '• Cari Sayısı: ${preview.accountCount}\n'
              '• Devreden Alacak: ${PreAccountingMathEngine.formatTl(preview.totalReceivableCarryTl)}\n'
              '• Devreden Borç: ${PreAccountingMathEngine.formatTl(preview.totalPayableCarryTl)}\n'
              '• Açık Çek: ${preview.openCheckCount} Adet (${PreAccountingMathEngine.formatTl(preview.openCheckTotalTl)})\n'
              '• Stok Envanteri: ${preview.stockItemCount} Kalem (${PreAccountingMathEngine.formatTl(preview.stockValuationCarryTl)})',
              style: const TextStyle(fontSize: 12.5, color: _kBodySlate),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Devri Onayla ve Başlat'),
        ),
      ],
    );
  }
}

// ============================================================================
// 4. ÜST TOPLAYICI PANEL
// ============================================================================

/// Cari kümülatif ekstre, ERP ileri kontrol merkezi ve analitik rapor / dönem sonu
/// devir panellerini tek bir responsive görünümde toplayan üst panel.
class HasibuAnalyticsAndDevirPanel extends StatelessWidget {
  final PreAccountingAdvancedViewData data;
  final PreAccountingAdvancedActions actions;

  const HasibuAnalyticsAndDevirPanel({
    super.key,
    required this.data,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return _AdaptiveScrollContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HasibuCariCumulativeAndNetStatusPanel(data: data),
          const SizedBox(height: 16),
          HasibuErpAdvancedControlsPanel(data: data, actions: actions),
          const SizedBox(height: 16),
          HasibuAnalyticalReportsAndRepxPanel(data: data, actions: actions),
        ],
      ),
    );
  }
}

// ============================================================================
// ATOMİK YARDIMCI BİLEŞENLER
// ============================================================================

class _AdaptiveScrollContainer extends StatelessWidget {
  final Widget child;

  const _AdaptiveScrollContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: child,
          );
        }
        return child;
      },
    );
  }
}

class _HorizontalTableShell extends StatefulWidget {
  final Widget child;

  const _HorizontalTableShell({required this.child});

  @override
  State<_HorizontalTableShell> createState() => _HorizontalTableShellState();
}

class _HorizontalTableShellState extends State<_HorizontalTableShell> {
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorderColor),
      ),
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: widget.child,
        ),
      ),
    );
  }
}

class _SectionCardShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final Widget child;

  const _SectionCardShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _kBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kEmeraldBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kEmeraldBorder),
                      ),
                      child: Icon(icon, size: 20, color: _kEmeraldPrimary),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kTitleDark,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kMutedSlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InnerSubCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Widget child;

  const _InnerSubCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _kBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: _kEmeraldPrimary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _kTitleDark,
                        ),
                      ),
                    ),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ToneBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;

  const _ToneBadge({
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;

  const _KpiTile({
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kMutedSlate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionNotice extends StatelessWidget {
  final String message;

  const _EmptySectionNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorderColor),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12.5,
          color: _kMutedSlate,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
