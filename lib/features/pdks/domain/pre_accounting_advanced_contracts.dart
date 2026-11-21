import 'package:flutter/foundation.dart';

import 'accounting_models.dart';

@immutable
class CurrencyRateQuote {
  final String code;
  final String label;
  final double buyingTl;
  final double sellingTl;
  final String updatedAtIso;
  final bool isFallback;

  const CurrencyRateQuote({
    required this.code,
    required this.label,
    required this.buyingTl,
    required this.sellingTl,
    required this.updatedAtIso,
    this.isFallback = false,
  });

  CurrencyRateQuote copyWith({
    String? code,
    String? label,
    double? buyingTl,
    double? sellingTl,
    String? updatedAtIso,
    bool? isFallback,
  }) {
    return CurrencyRateQuote(
      code: code ?? this.code,
      label: label ?? this.label,
      buyingTl: buyingTl ?? this.buyingTl,
      sellingTl: sellingTl ?? this.sellingTl,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      isFallback: isFallback ?? this.isFallback,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'buyingTl': buyingTl,
        'sellingTl': sellingTl,
        'updatedAtIso': updatedAtIso,
        'isFallback': isFallback,
      };

  factory CurrencyRateQuote.fromJson(Map<String, dynamic> json) {
    return CurrencyRateQuote(
      code: (json['code'] as String?) ?? 'USD',
      label: (json['label'] as String?) ?? 'ABD Doları',
      buyingTl: (json['buyingTl'] as num?)?.toDouble() ?? 0.0,
      sellingTl: (json['sellingTl'] as num?)?.toDouble() ?? 0.0,
      updatedAtIso: (json['updatedAtIso'] as String?) ?? '',
      isFallback: (json['isFallback'] as bool?) ?? false,
    );
  }
}

@immutable
class MaturityCalcRow {
  final String id;
  final String label;
  final String dueDateKey; // YYYY-MM-DD
  final double amountTl;

  const MaturityCalcRow({
    required this.id,
    required this.label,
    required this.dueDateKey,
    required this.amountTl,
  });

  MaturityCalcRow copyWith({
    String? id,
    String? label,
    String? dueDateKey,
    double? amountTl,
  }) {
    return MaturityCalcRow(
      id: id ?? this.id,
      label: label ?? this.label,
      dueDateKey: dueDateKey ?? this.dueDateKey,
      amountTl: amountTl ?? this.amountTl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'dueDateKey': dueDateKey,
        'amountTl': amountTl,
      };

  factory MaturityCalcRow.fromJson(Map<String, dynamic> json) {
    return MaturityCalcRow(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      dueDateKey: (json['dueDateKey'] as String?) ?? '',
      amountTl: (json['amountTl'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class MaturitySummary {
  final String baseDateKey;
  final String averageDueDateKey;
  final double weightedDays;
  final double totalAmountTl;
  final int rowCount;
  final List<MaturityCalcRow> sortedRows;

  const MaturitySummary({
    required this.baseDateKey,
    required this.averageDueDateKey,
    required this.weightedDays,
    required this.totalAmountTl,
    required this.rowCount,
    required this.sortedRows,
  });
}

enum CheckPortfolioStatus {
  inPortfolio('Portföyde'),
  endorsed('Ciro Edildi'),
  collected('Tahsil Edildi'),
  paid('Ödendi'),
  returned('İade Edildi');

  final String label;
  const CheckPortfolioStatus(this.label);

  static CheckPortfolioStatus fromName(String? raw) {
    for (final s in CheckPortfolioStatus.values) {
      if (s.name == raw) return s;
    }
    return CheckPortfolioStatus.inPortfolio;
  }
}

@immutable
class CheckPortfolioItem {
  final String id;
  final String bordroNo;
  final bool isIncoming;
  final String accountId;
  final String accountName;
  final String bankName;
  final String serialNo;
  final String issueDateKey;
  final String dueDateKey;
  final double amountTl;
  final String currencyCode;
  final double fxRate;
  final CheckPortfolioStatus status;
  final String endorsedToAccountId;
  final String endorsedToName;
  final String linkedInvoiceDocNo;
  final String note;

  const CheckPortfolioItem({
    required this.id,
    required this.bordroNo,
    required this.isIncoming,
    required this.accountId,
    required this.accountName,
    required this.bankName,
    required this.serialNo,
    required this.issueDateKey,
    required this.dueDateKey,
    required this.amountTl,
    this.currencyCode = 'TRY',
    this.fxRate = 1.0,
    this.status = CheckPortfolioStatus.inPortfolio,
    this.endorsedToAccountId = '',
    this.endorsedToName = '',
    this.linkedInvoiceDocNo = '',
    this.note = '',
  });

  CheckPortfolioItem copyWith({
    String? id,
    String? bordroNo,
    bool? isIncoming,
    String? accountId,
    String? accountName,
    String? bankName,
    String? serialNo,
    String? issueDateKey,
    String? dueDateKey,
    double? amountTl,
    String? currencyCode,
    double? fxRate,
    CheckPortfolioStatus? status,
    String? endorsedToAccountId,
    String? endorsedToName,
    String? linkedInvoiceDocNo,
    String? note,
  }) {
    return CheckPortfolioItem(
      id: id ?? this.id,
      bordroNo: bordroNo ?? this.bordroNo,
      isIncoming: isIncoming ?? this.isIncoming,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      bankName: bankName ?? this.bankName,
      serialNo: serialNo ?? this.serialNo,
      issueDateKey: issueDateKey ?? this.issueDateKey,
      dueDateKey: dueDateKey ?? this.dueDateKey,
      amountTl: amountTl ?? this.amountTl,
      currencyCode: currencyCode ?? this.currencyCode,
      fxRate: fxRate ?? this.fxRate,
      status: status ?? this.status,
      endorsedToAccountId: endorsedToAccountId ?? this.endorsedToAccountId,
      endorsedToName: endorsedToName ?? this.endorsedToName,
      linkedInvoiceDocNo: linkedInvoiceDocNo ?? this.linkedInvoiceDocNo,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bordroNo': bordroNo,
        'isIncoming': isIncoming,
        'accountId': accountId,
        'accountName': accountName,
        'bankName': bankName,
        'serialNo': serialNo,
        'issueDateKey': issueDateKey,
        'dueDateKey': dueDateKey,
        'amountTl': amountTl,
        'currencyCode': currencyCode,
        'fxRate': fxRate,
        'status': status.name,
        'endorsedToAccountId': endorsedToAccountId,
        'endorsedToName': endorsedToName,
        'linkedInvoiceDocNo': linkedInvoiceDocNo,
        'note': note,
      };

  factory CheckPortfolioItem.fromJson(Map<String, dynamic> json) {
    return CheckPortfolioItem(
      id: (json['id'] as String?) ?? '',
      bordroNo: (json['bordroNo'] as String?) ?? '',
      isIncoming: (json['isIncoming'] as bool?) ?? true,
      accountId: (json['accountId'] as String?) ?? '',
      accountName: (json['accountName'] as String?) ?? '',
      bankName: (json['bankName'] as String?) ?? '',
      serialNo: (json['serialNo'] as String?) ?? '',
      issueDateKey: (json['issueDateKey'] as String?) ?? '',
      dueDateKey: (json['dueDateKey'] as String?) ?? '',
      amountTl: (json['amountTl'] as num?)?.toDouble() ?? 0.0,
      currencyCode: (json['currencyCode'] as String?) ?? 'TRY',
      fxRate: (json['fxRate'] as num?)?.toDouble() ?? 1.0,
      status: CheckPortfolioStatus.fromName(json['status'] as String?),
      endorsedToAccountId: (json['endorsedToAccountId'] as String?) ?? '',
      endorsedToName: (json['endorsedToName'] as String?) ?? '',
      linkedInvoiceDocNo: (json['linkedInvoiceDocNo'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
    );
  }
}

@immutable
class PaymentInstructionTemplate {
  final String id;
  final String kind; // 'BANKA' | 'KASA'
  final String targetBankOrCashName;
  final String iban;
  final String templateBody;

  const PaymentInstructionTemplate({
    required this.id,
    required this.kind,
    required this.targetBankOrCashName,
    required this.iban,
    required this.templateBody,
  });

  PaymentInstructionTemplate copyWith({
    String? id,
    String? kind,
    String? targetBankOrCashName,
    String? iban,
    String? templateBody,
  }) {
    return PaymentInstructionTemplate(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      targetBankOrCashName: targetBankOrCashName ?? this.targetBankOrCashName,
      iban: iban ?? this.iban,
      templateBody: templateBody ?? this.templateBody,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'targetBankOrCashName': targetBankOrCashName,
        'iban': iban,
        'templateBody': templateBody,
      };

  factory PaymentInstructionTemplate.fromJson(Map<String, dynamic> json) {
    return PaymentInstructionTemplate(
      id: (json['id'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? 'BANKA',
      targetBankOrCashName: (json['targetBankOrCashName'] as String?) ?? '',
      iban: (json['iban'] as String?) ?? '',
      templateBody: (json['templateBody'] as String?) ?? '',
    );
  }
}

@immutable
class PaymentOrderRecord {
  final String id;
  final String orderNo;
  final String dateKey;
  final String dueDateKey;
  final String kind; // 'BANKA' | 'KASA'
  final String bankOrCashName;
  final String accountId;
  final String accountName;
  final String iban;
  final double amountTl;
  final String status; // 'BEKLIYOR' | 'ODENDI'
  final String renderedInstruction;
  final String note;

  const PaymentOrderRecord({
    required this.id,
    required this.orderNo,
    required this.dateKey,
    required this.dueDateKey,
    required this.kind,
    required this.bankOrCashName,
    required this.accountId,
    required this.accountName,
    required this.iban,
    required this.amountTl,
    required this.status,
    required this.renderedInstruction,
    this.note = '',
  });

  PaymentOrderRecord copyWith({
    String? id,
    String? orderNo,
    String? dateKey,
    String? dueDateKey,
    String? kind,
    String? bankOrCashName,
    String? accountId,
    String? accountName,
    String? iban,
    double? amountTl,
    String? status,
    String? renderedInstruction,
    String? note,
  }) {
    return PaymentOrderRecord(
      id: id ?? this.id,
      orderNo: orderNo ?? this.orderNo,
      dateKey: dateKey ?? this.dateKey,
      dueDateKey: dueDateKey ?? this.dueDateKey,
      kind: kind ?? this.kind,
      bankOrCashName: bankOrCashName ?? this.bankOrCashName,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      iban: iban ?? this.iban,
      amountTl: amountTl ?? this.amountTl,
      status: status ?? this.status,
      renderedInstruction: renderedInstruction ?? this.renderedInstruction,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNo': orderNo,
        'dateKey': dateKey,
        'dueDateKey': dueDateKey,
        'kind': kind,
        'bankOrCashName': bankOrCashName,
        'accountId': accountId,
        'accountName': accountName,
        'iban': iban,
        'amountTl': amountTl,
        'status': status,
        'renderedInstruction': renderedInstruction,
        'note': note,
      };

  factory PaymentOrderRecord.fromJson(Map<String, dynamic> json) {
    return PaymentOrderRecord(
      id: (json['id'] as String?) ?? '',
      orderNo: (json['orderNo'] as String?) ?? '',
      dateKey: (json['dateKey'] as String?) ?? '',
      dueDateKey: (json['dueDateKey'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? 'BANKA',
      bankOrCashName: (json['bankOrCashName'] as String?) ?? '',
      accountId: (json['accountId'] as String?) ?? '',
      accountName: (json['accountName'] as String?) ?? '',
      iban: (json['iban'] as String?) ?? '',
      amountTl: (json['amountTl'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] as String?) ?? 'BEKLIYOR',
      renderedInstruction: (json['renderedInstruction'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
    );
  }
}

@immutable
class DealerContractRecord {
  final String id;
  final String contractNo;
  final String dateKey;
  final int durationMonths;
  final double collateralAmountTl;
  final String collateralType;
  final String accountId;
  final String accountName;
  final String regionName;
  final int priceTier;
  final double dealerMarginPercent;
  final bool isTerminated;
  final String terminationNote;

  const DealerContractRecord({
    required this.id,
    required this.contractNo,
    required this.dateKey,
    required this.durationMonths,
    required this.collateralAmountTl,
    required this.collateralType,
    required this.accountId,
    required this.accountName,
    required this.regionName,
    required this.priceTier,
    required this.dealerMarginPercent,
    this.isTerminated = false,
    this.terminationNote = '',
  });

  DealerContractRecord copyWith({
    String? id,
    String? contractNo,
    String? dateKey,
    int? durationMonths,
    double? collateralAmountTl,
    String? collateralType,
    String? accountId,
    String? accountName,
    String? regionName,
    int? priceTier,
    double? dealerMarginPercent,
    bool? isTerminated,
    String? terminationNote,
  }) {
    return DealerContractRecord(
      id: id ?? this.id,
      contractNo: contractNo ?? this.contractNo,
      dateKey: dateKey ?? this.dateKey,
      durationMonths: durationMonths ?? this.durationMonths,
      collateralAmountTl: collateralAmountTl ?? this.collateralAmountTl,
      collateralType: collateralType ?? this.collateralType,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      regionName: regionName ?? this.regionName,
      priceTier: priceTier ?? this.priceTier,
      dealerMarginPercent: dealerMarginPercent ?? this.dealerMarginPercent,
      isTerminated: isTerminated ?? this.isTerminated,
      terminationNote: terminationNote ?? this.terminationNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contractNo': contractNo,
        'dateKey': dateKey,
        'durationMonths': durationMonths,
        'collateralAmountTl': collateralAmountTl,
        'collateralType': collateralType,
        'accountId': accountId,
        'accountName': accountName,
        'regionName': regionName,
        'priceTier': priceTier,
        'dealerMarginPercent': dealerMarginPercent,
        'isTerminated': isTerminated,
        'terminationNote': terminationNote,
      };

  factory DealerContractRecord.fromJson(Map<String, dynamic> json) {
    return DealerContractRecord(
      id: (json['id'] as String?) ?? '',
      contractNo: (json['contractNo'] as String?) ?? '',
      dateKey: (json['dateKey'] as String?) ?? '',
      durationMonths: (json['durationMonths'] as num?)?.toInt() ?? 12,
      collateralAmountTl:
          (json['collateralAmountTl'] as num?)?.toDouble() ?? 0.0,
      collateralType: (json['collateralType'] as String?) ?? 'Teminat Mektubu',
      accountId: (json['accountId'] as String?) ?? '',
      accountName: (json['accountName'] as String?) ?? '',
      regionName: (json['regionName'] as String?) ?? '',
      priceTier: (json['priceTier'] as num?)?.toInt() ?? 1,
      dealerMarginPercent:
          (json['dealerMarginPercent'] as num?)?.toDouble() ?? 0.0,
      isTerminated: (json['isTerminated'] as bool?) ?? false,
      terminationNote: (json['terminationNote'] as String?) ?? '',
    );
  }
}

@immutable
class CumulativeLedgerRow {
  final String id;
  final String dateKey;
  final String docNo;
  final String description;
  final String cashOrBankName;
  final double debitTl;
  final double creditTl;
  final double runningBalanceTl;

  const CumulativeLedgerRow({
    required this.id,
    required this.dateKey,
    required this.docNo,
    required this.description,
    required this.cashOrBankName,
    required this.debitTl,
    required this.creditTl,
    required this.runningBalanceTl,
  });
}

@immutable
class CariNetStatusSummary {
  final String accountId;
  final String accountName;
  final double openingBalanceTl;
  final double periodDebitTl;
  final double periodCreditTl;
  final double ledgerClosingBalanceTl;
  final double openOrderExposureTl;
  final double portfolioCheckExposureTl;
  final int trayCount;
  final double depositExposureTl;
  final double consolidatedNetPositionTl;

  const CariNetStatusSummary({
    required this.accountId,
    required this.accountName,
    required this.openingBalanceTl,
    required this.periodDebitTl,
    required this.periodCreditTl,
    required this.ledgerClosingBalanceTl,
    required this.openOrderExposureTl,
    required this.portfolioCheckExposureTl,
    required this.trayCount,
    required this.depositExposureTl,
    required this.consolidatedNetPositionTl,
  });
}

@immutable
class EodFlowBucket {
  final String code;
  final String title;
  final bool isIncoming;
  final double totalAmountTl;
  final int count;
  final List<AccountingTransaction> items;

  const EodFlowBucket({
    required this.code,
    required this.title,
    required this.isIncoming,
    required this.totalAmountTl,
    required this.count,
    required this.items,
  });
}

@immutable
class EodFlowBreakdown {
  final String dateKey;
  final double totalIncomingTl;
  final double totalOutgoingTl;
  final double netFlowTl;
  final List<EodFlowBucket> buckets;

  const EodFlowBreakdown({
    required this.dateKey,
    required this.totalIncomingTl,
    required this.totalOutgoingTl,
    required this.netFlowTl,
    required this.buckets,
  });
}

@immutable
class PeriodRolloverPreview {
  final String fromPeriodKey;
  final String nextPeriodKey;
  final String rolloverDateKey;
  final int accountCount;
  final double totalReceivableCarryTl;
  final double totalPayableCarryTl;
  final int openCheckCount;
  final double openCheckTotalTl;
  final int stockItemCount;
  final double stockValuationCarryTl;
  final bool alreadyExecuted;

  const PeriodRolloverPreview({
    required this.fromPeriodKey,
    required this.nextPeriodKey,
    required this.rolloverDateKey,
    required this.accountCount,
    required this.totalReceivableCarryTl,
    required this.totalPayableCarryTl,
    required this.openCheckCount,
    required this.openCheckTotalTl,
    required this.stockItemCount,
    required this.stockValuationCarryTl,
    required this.alreadyExecuted,
  });

  Map<String, dynamic> toJson() => {
        'fromPeriodKey': fromPeriodKey,
        'nextPeriodKey': nextPeriodKey,
        'rolloverDateKey': rolloverDateKey,
        'accountCount': accountCount,
        'totalReceivableCarryTl': totalReceivableCarryTl,
        'totalPayableCarryTl': totalPayableCarryTl,
        'openCheckCount': openCheckCount,
        'openCheckTotalTl': openCheckTotalTl,
        'stockItemCount': stockItemCount,
        'stockValuationCarryTl': stockValuationCarryTl,
        'alreadyExecuted': alreadyExecuted,
      };
}

@immutable
class RepxTemplateSpec {
  final String templateId;
  final String fileName;
  final String title;
  final String category;

  const RepxTemplateSpec({
    required this.templateId,
    required this.fileName,
    required this.title,
    required this.category,
  });
}

@immutable
class OrderProductMatrixCell {
  final String accountName;
  final String stockName;
  final double totalOrderedKg;
  final double totalInvoicedKg;
  final int totalTrays;
  final double totalNetTl;

  const OrderProductMatrixCell({
    required this.accountName,
    required this.stockName,
    required this.totalOrderedKg,
    required this.totalInvoicedKg,
    required this.totalTrays,
    required this.totalNetTl,
  });
}

@immutable
class SalesRepPerformanceRow {
  final String salesRepName;
  final int invoiceCount;
  final double totalSalesTl;
  final double totalCollectedTl;
  final double collectionRatioPercent;

  const SalesRepPerformanceRow({
    required this.salesRepName,
    required this.invoiceCount,
    required this.totalSalesTl,
    required this.totalCollectedTl,
    required this.collectionRatioPercent,
  });
}

@immutable
class PreAccountingAdvancedViewData {
  final String selectedDateKey;
  final String selectedPeriodKey;
  final String companyName;
  final List<AccountingAccount> accounts;
  final AccountingAccount? selectedAccount;
  final List<AccountingTransaction> transactions;
  final List<StockBurnItem> stocks;
  final List<ContainerMovement> containers;
  final List<ErpOrderWaybillInvoiceItem> erpDocuments;
  final List<CustomSpreadsheetRecord> customSpreadsheets;
  final List<CurrencyRateQuote> currencyRates;
  final List<CheckPortfolioItem> checkPortfolio;
  final List<PaymentInstructionTemplate> paymentTemplates;
  final List<PaymentOrderRecord> paymentOrders;
  final List<DealerContractRecord> dealerContracts;
  final PeriodRolloverPreview? rolloverPreview;

  const PreAccountingAdvancedViewData({
    required this.selectedDateKey,
    required this.selectedPeriodKey,
    this.companyName = 'HASİBU İŞLETME YÖNETİMİ',
    this.accounts = const <AccountingAccount>[],
    this.selectedAccount,
    this.transactions = const <AccountingTransaction>[],
    this.stocks = const <StockBurnItem>[],
    this.containers = const <ContainerMovement>[],
    this.erpDocuments = const <ErpOrderWaybillInvoiceItem>[],
    this.customSpreadsheets = const <CustomSpreadsheetRecord>[],
    this.currencyRates = const <CurrencyRateQuote>[],
    this.checkPortfolio = const <CheckPortfolioItem>[],
    this.paymentTemplates = const <PaymentInstructionTemplate>[],
    this.paymentOrders = const <PaymentOrderRecord>[],
    this.dealerContracts = const <DealerContractRecord>[],
    this.rolloverPreview,
  });
}

/// Saf matematik, kümülatif defter, ağırlıklı ortalama vade ve yazıyla tutar motoru.
class PreAccountingMathEngine {
  PreAccountingMathEngine._();

  static DateTime parseDateKey(String raw) {
    final clean = raw.trim();
    final parts = clean.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String formatTl(double val) {
    final fixed = val.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final isNeg = intPart.startsWith('-');
    final digits = isNeg ? intPart.substring(1) : intPart;
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(digits[i]);
    }
    return '${isNeg ? "-" : ""}${buf.toString()},${parts[1]} ₺';
  }

  static MaturitySummary computeWeightedMaturity({
    required String baseDateKey,
    required List<MaturityCalcRow> rows,
  }) {
    final baseDt = parseDateKey(baseDateKey);
    final sorted = List<MaturityCalcRow>.from(rows)
      ..sort((a, b) => a.dueDateKey.compareTo(b.dueDateKey));

    double totalAmount = 0.0;
    double weightedDaySum = 0.0;
    for (final row in sorted) {
      if (row.amountTl <= 0) continue;
      final rowDt = parseDateKey(row.dueDateKey);
      final dayDiff = rowDt.difference(baseDt).inDays.toDouble();
      totalAmount += row.amountTl;
      weightedDaySum += row.amountTl * dayDiff;
    }

    if (totalAmount <= 0.0) {
      return MaturitySummary(
        baseDateKey: formatDateKey(baseDt),
        averageDueDateKey: formatDateKey(baseDt),
        weightedDays: 0.0,
        totalAmountTl: 0.0,
        rowCount: sorted.length,
        sortedRows: List<MaturityCalcRow>.unmodifiable(sorted),
      );
    }

    final avgDays = weightedDaySum / totalAmount;
    final avgDate = baseDt.add(Duration(days: avgDays.round()));
    return MaturitySummary(
      baseDateKey: formatDateKey(baseDt),
      averageDueDateKey: formatDateKey(avgDate),
      weightedDays: double.parse(avgDays.toStringAsFixed(2)),
      totalAmountTl: double.parse(totalAmount.toStringAsFixed(2)),
      rowCount: sorted.length,
      sortedRows: List<MaturityCalcRow>.unmodifiable(sorted),
    );
  }

  static double computeAutoDiscountPercent({
    required double grossTotalTl,
    required double targetNetTotalTl,
  }) {
    if (grossTotalTl <= 0.0 || targetNetTotalTl <= 0.0) {
      return grossTotalTl > 0.0 && targetNetTotalTl == 0.0 ? 100.0 : 0.0;
    }
    final pct = (1.0 - (targetNetTotalTl / grossTotalTl)) * 100.0;
    return double.parse(pct.clamp(0.0, 100.0).toStringAsFixed(4));
  }

  static const List<String> _ones = <String>[
    '',
    'Bir',
    'İki',
    'Üç',
    'Dört',
    'Beş',
    'Altı',
    'Yedi',
    'Sekiz',
    'Dokuz',
  ];

  static const List<String> _tens = <String>[
    '',
    'On',
    'Yirmi',
    'Otuz',
    'Kırk',
    'Elli',
    'Altmış',
    'Yetmiş',
    'Seksen',
    'Doksan',
  ];

  static const List<String> _scales = <String>[
    '',
    'Bin',
    'Milyon',
    'Milyar',
    'Trilyon',
  ];

  static String _threeDigitsToWords(int num) {
    final hundreds = num ~/ 100;
    final tens = (num % 100) ~/ 10;
    final ones = num % 10;
    final parts = <String>[];
    if (hundreds == 1) {
      parts.add('Yüz');
    } else if (hundreds > 1) {
      parts.add('${_ones[hundreds]} Yüz');
    }
    if (tens > 0) parts.add(_tens[tens]);
    if (ones > 0) parts.add(_ones[ones]);
    return parts.join(' ');
  }

  static String _integerToTurkishWords(int value) {
    if (value == 0) return 'Sıfır';
    var remaining = value;
    var scaleIndex = 0;
    final chunks = <String>[];

    while (remaining > 0 && scaleIndex < _scales.length) {
      final group = remaining % 1000;
      if (group > 0) {
        if (scaleIndex == 1 && group == 1) {
          chunks.insert(0, 'Bin');
        } else {
          final groupWords = _threeDigitsToWords(group);
          final scaleWord = _scales[scaleIndex];
          chunks.insert(
            0,
            scaleWord.isEmpty ? groupWords : '$groupWords $scaleWord',
          );
        }
      }
      remaining ~/= 1000;
      scaleIndex++;
    }
    return chunks.join(' ');
  }

  static String amountToTurkishWords(double amountTl) {
    final absVal = amountTl.isNaN || amountTl.isInfinite
        ? 0.0
        : amountTl.abs();
    final totalKurus = (absVal * 100.0).round();
    final lira = totalKurus ~/ 100;
    final kurus = totalKurus % 100;
    final liraText = '${_integerToTurkishWords(lira)} Türk Lirası';
    if (kurus == 0) {
      return '#Yalnız $liraText\'dır#';
    }
    final kurusText = '${_integerToTurkishWords(kurus)} Kuruştur';
    return '#Yalnız $liraText $kurusText#';
  }

  static String renderPaymentInstruction({
    required String templateBody,
    required String dateKey,
    required String accountName,
    required String iban,
    required double amountTl,
    required String description,
  }) {
    final amountWords = amountToTurkishWords(amountTl);
    return templateBody
        .replaceAll('@TalimatTarihi', dateKey)
        .replaceAll('@Unvan', accountName)
        .replaceAll('@IBAN', iban.isEmpty ? 'BELİRTİLMEDİ' : iban)
        .replaceAll('@Tutar', formatTl(amountTl))
        .replaceAll('@YaziylaTutar', amountWords)
        .replaceAll('@Aciklama', description.isEmpty ? '-' : description);
  }

  static ({double openingBalanceTl, List<CumulativeLedgerRow> rows})
      buildCumulativeLedger({
    required List<AccountingTransaction> transactions,
    String? startDateKey,
    String? endDateKey,
    String? accountId,
    String? cashOrBankFilter,
    Set<LedgerEntryType>? entryTypeFilter,
  }) {
    final filtered = transactions.where((t) {
      if (accountId != null && accountId.isNotEmpty && t.accountId != accountId) {
        return false;
      }
      if (cashOrBankFilter != null &&
          cashOrBankFilter.isNotEmpty &&
          t.cashOrBankName != cashOrBankFilter) {
        return false;
      }
      if (entryTypeFilter != null && !entryTypeFilter.contains(t.entryType)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final cmp = a.dateKey.compareTo(b.dateKey);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      });

    double openingBalance = 0.0;
    final start = startDateKey?.trim() ?? '';
    final end = endDateKey?.trim() ?? '';
    final inRange = <AccountingTransaction>[];

    for (final tx in filtered) {
      final signed = tx.direction == 'A' ? tx.amount : -tx.amount;
      if (start.isNotEmpty && tx.dateKey.compareTo(start) < 0) {
        openingBalance += signed;
      } else if (end.isNotEmpty && tx.dateKey.compareTo(end) > 0) {
        continue;
      } else {
        inRange.add(tx);
      }
    }

    double running = openingBalance;
    final rows = <CumulativeLedgerRow>[];
    for (final tx in inRange) {
      final isCredit = tx.direction == 'A';
      running += isCredit ? tx.amount : -tx.amount;
      rows.add(
        CumulativeLedgerRow(
          id: tx.id,
          dateKey: tx.dateKey,
          docNo: tx.docNo,
          description: tx.description.isNotEmpty ? tx.description : tx.entryType.label,
          cashOrBankName: tx.cashOrBankName,
          debitTl: isCredit ? 0.0 : tx.amount,
          creditTl: isCredit ? tx.amount : 0.0,
          runningBalanceTl: double.parse(running.toStringAsFixed(2)),
        ),
      );
    }

    return (
      openingBalanceTl: double.parse(openingBalance.toStringAsFixed(2)),
      rows: List<CumulativeLedgerRow>.unmodifiable(rows),
    );
  }

  static CariNetStatusSummary computeCariNetStatus({
    required AccountingAccount account,
    required List<AccountingTransaction> transactions,
    required List<ErpOrderWaybillInvoiceItem> erpDocs,
    required List<CheckPortfolioItem> checks,
    required List<StockBurnItem> stocks,
    String? startDateKey,
    String? endDateKey,
  }) {
    final ledger = buildCumulativeLedger(
      transactions: transactions,
      startDateKey: startDateKey,
      endDateKey: endDateKey,
      accountId: account.id,
    );
    double periodDebit = 0.0;
    double periodCredit = 0.0;
    for (final r in ledger.rows) {
      periodDebit += r.debitTl;
      periodCredit += r.creditTl;
    }
    final closing = ledger.rows.isNotEmpty
        ? ledger.rows.last.runningBalanceTl
        : ledger.openingBalanceTl;

    final openOrderExposure = erpDocs
        .where((d) => d.accountId == account.id && d.stage != 'FATURALANDI')
        .fold<double>(0.0, (s, d) => s + d.grandTotalTl);

    final portfolioCheckExposure = checks
        .where(
          (c) =>
              c.accountId == account.id &&
              c.status == CheckPortfolioStatus.inPortfolio,
        )
        .fold<double>(
          0.0,
          (s, c) => s + (c.isIncoming ? c.amountTl : -c.amountTl),
        );

    double trayDepositUnit = 350.0;
    for (final stk in stocks) {
      if (stk.depositUnitTl > 0) {
        trayDepositUnit = stk.depositUnitTl;
        break;
      }
    }
    final depositExposure = account.trayBalance * trayDepositUnit;
    final consolidated =
        closing - openOrderExposure + portfolioCheckExposure - depositExposure;

    return CariNetStatusSummary(
      accountId: account.id,
      accountName: account.name,
      openingBalanceTl: ledger.openingBalanceTl,
      periodDebitTl: double.parse(periodDebit.toStringAsFixed(2)),
      periodCreditTl: double.parse(periodCredit.toStringAsFixed(2)),
      ledgerClosingBalanceTl: double.parse(closing.toStringAsFixed(2)),
      openOrderExposureTl: double.parse(openOrderExposure.toStringAsFixed(2)),
      portfolioCheckExposureTl:
          double.parse(portfolioCheckExposure.toStringAsFixed(2)),
      trayCount: account.trayBalance,
      depositExposureTl: double.parse(depositExposure.toStringAsFixed(2)),
      consolidatedNetPositionTl: double.parse(consolidated.toStringAsFixed(2)),
    );
  }

  static List<OrderProductMatrixCell> buildOrderAnalyticalMatrix(
    List<ErpOrderWaybillInvoiceItem> docs,
  ) {
    final grouped = <String, OrderProductMatrixCell>{};
    for (final doc in docs) {
      final key = '${doc.accountName}||${doc.stockName}';
      final prev = grouped[key];
      grouped[key] = OrderProductMatrixCell(
        accountName: doc.accountName,
        stockName: doc.stockName,
        totalOrderedKg: (prev?.totalOrderedKg ?? 0.0) + doc.orderedQtyKg,
        totalInvoicedKg: (prev?.totalInvoicedKg ?? 0.0) + doc.invoicedQtyKg,
        totalTrays: (prev?.totalTrays ?? 0) + doc.trayCount,
        totalNetTl: (prev?.totalNetTl ?? 0.0) + doc.grandTotalTl,
      );
    }
    final list = grouped.values.toList()
      ..sort((a, b) => b.totalNetTl.compareTo(a.totalNetTl));
    return List<OrderProductMatrixCell>.unmodifiable(list);
  }

  static List<SalesRepPerformanceRow> buildSalesRepReport({
    required List<AccountingAccount> accounts,
    required List<ErpOrderWaybillInvoiceItem> docs,
    required List<AccountingTransaction> transactions,
  }) {
    final repByAccountId = <String, String>{
      for (final a in accounts)
        if (a.salesRepName.trim().isNotEmpty) a.id: a.salesRepName.trim(),
    };
    final salesMap = <String, ({int count, double sales, double collected})>{};

    for (final d in docs) {
      final rep = d.salesRepName.trim().isNotEmpty
          ? d.salesRepName.trim()
          : (repByAccountId[d.accountId] ?? 'Merkez Ekip');
      final cur = salesMap[rep] ?? (count: 0, sales: 0.0, collected: 0.0);
      salesMap[rep] = (
        count: cur.count + 1,
        sales: cur.sales + d.grandTotalTl,
        collected: cur.collected + d.collectedAmountTl,
      );
    }

    for (final tx in transactions) {
      if (tx.entryType == LedgerEntryType.cashIn ||
          tx.entryType == LedgerEntryType.bankIn) {
        final rep = tx.salesRepName.trim().isNotEmpty
            ? tx.salesRepName.trim()
            : (repByAccountId[tx.accountId] ?? '');
        if (rep.isEmpty) continue;
        final cur = salesMap[rep] ?? (count: 0, sales: 0.0, collected: 0.0);
        salesMap[rep] = (
          count: cur.count,
          sales: cur.sales,
          collected: cur.collected + tx.amount,
        );
      }
    }

    final rows = salesMap.entries.map((e) {
      final ratio = e.value.sales > 0
          ? ((e.value.collected / e.value.sales) * 100.0).clamp(0.0, 100.0)
          : 0.0;
      return SalesRepPerformanceRow(
        salesRepName: e.key,
        invoiceCount: e.value.count,
        totalSalesTl: double.parse(e.value.sales.toStringAsFixed(2)),
        totalCollectedTl: double.parse(e.value.collected.toStringAsFixed(2)),
        collectionRatioPercent: double.parse(ratio.toStringAsFixed(1)),
      );
    }).toList()
      ..sort((a, b) => b.totalSalesTl.compareTo(a.totalSalesTl));

    return List<SalesRepPerformanceRow>.unmodifiable(rows);
  }
}

class _EodBucketRule {
  final String code;
  final String title;
  final bool isIncoming;
  final bool Function(AccountingTransaction tx) matches;

  const _EodBucketRule({
    required this.code,
    required this.title,
    required this.isIncoming,
    required this.matches,
  });
}

/// OCP uyumlu Gün Sonu Tüm Gelen/Giden 9'lu kırılım sınıflandırıcı.
class EodBucketClassifier {
  EodBucketClassifier._();

  static final List<_EodBucketRule> _rules = <_EodBucketRule>[
    _EodBucketRule(
      code: 'GELEN_NAKIT',
      title: 'Gelen Nakit Tahsilatlar',
      isIncoming: true,
      matches: (tx) => tx.entryType == LedgerEntryType.cashIn,
    ),
    _EodBucketRule(
      code: 'GELEN_BANKA',
      title: 'Gelen Banka (Havale / EFT / POS)',
      isIncoming: true,
      matches: (tx) => tx.entryType == LedgerEntryType.bankIn,
    ),
    _EodBucketRule(
      code: 'PERAKENDE_DONDURMA',
      title: 'Mağaza & Dondurma Satış Gelirleri',
      isIncoming: true,
      matches: (tx) =>
          tx.entryType == LedgerEntryType.iceCreamSale ||
          tx.entryType == LedgerEntryType.branchPosSale ||
          tx.entryType == LedgerEntryType.salesInvoice,
    ),
    _EodBucketRule(
      code: 'ALIS_FATURA',
      title: 'Alış Faturaları & İade Kesintileri',
      isIncoming: false,
      matches: (tx) =>
          tx.entryType == LedgerEntryType.purchaseInvoice ||
          tx.entryType == LedgerEntryType.salesReturn ||
          tx.entryType == LedgerEntryType.purchaseReturn,
    ),
    _EodBucketRule(
      code: 'MUTFAK_URETIM',
      title: 'Mutfak & Üretim Hammadde Gideri',
      isIncoming: false,
      matches: (tx) {
        final cat = tx.expenseCategory.toUpperCase();
        return cat.contains('MUTFAK') ||
            cat.contains('ÜRETİM') ||
            cat.contains('URETIM') ||
            tx.entryType == LedgerEntryType.productionVoucher;
      },
    ),
    _EodBucketRule(
      code: 'LOJISTIK_NAKLIYE',
      title: 'Nakliye, Lojistik & Sevk Giderleri',
      isIncoming: false,
      matches: (tx) {
        final cat = tx.expenseCategory.toUpperCase();
        return cat.contains('NAKLİYE') ||
            cat.contains('NAKLIYE') ||
            cat.contains('LOJİSTİK') ||
            tx.entryType == LedgerEntryType.warehouseTransfer;
      },
    ),
    _EodBucketRule(
      code: 'PERSONEL_ODEME',
      title: 'Personel Maaş / Avans / Puantaj Ödemeleri',
      isIncoming: false,
      matches: (tx) =>
          tx.entryType == LedgerEntryType.payrollAccrual ||
          tx.entryType == LedgerEntryType.advancePayment ||
          tx.entryType == LedgerEntryType.personnelBonusOrDeduction,
    ),
    _EodBucketRule(
      code: 'TEDARIKCI_ODEME',
      title: 'Tedarikçi Tediye & Banka Çıkışları',
      isIncoming: false,
      matches: (tx) =>
          tx.entryType == LedgerEntryType.cashOut ||
          tx.entryType == LedgerEntryType.bankOut ||
          tx.entryType == LedgerEntryType.expense,
    ),
  ];

  static EodFlowBreakdown classify({
    required String dateKey,
    required List<AccountingTransaction> transactions,
  }) {
    final dayTxs = dateKey.trim().isEmpty
        ? transactions
        : transactions.where((t) => t.dateKey == dateKey).toList();

    final grouped = <String, List<AccountingTransaction>>{
      for (final r in _rules) r.code: <AccountingTransaction>[],
      'DIGER_HAREKET': <AccountingTransaction>[],
    };

    for (final tx in dayTxs) {
      var placed = false;
      for (final rule in _rules) {
        if (rule.matches(tx)) {
          grouped[rule.code]!.add(tx);
          placed = true;
          break;
        }
      }
      if (!placed) {
        grouped['DIGER_HAREKET']!.add(tx);
      }
    }

    final buckets = <EodFlowBucket>[];
    for (final rule in _rules) {
      final list = grouped[rule.code]!;
      final sum = list.fold<double>(0.0, (s, t) => s + t.amount);
      buckets.add(
        EodFlowBucket(
          code: rule.code,
          title: rule.title,
          isIncoming: rule.isIncoming,
          totalAmountTl: double.parse(sum.toStringAsFixed(2)),
          count: list.length,
          items: List<AccountingTransaction>.unmodifiable(list),
        ),
      );
    }

    final others = grouped['DIGER_HAREKET']!;
    final otherSum = others.fold<double>(0.0, (s, t) => s + t.amount);
    buckets.add(
      EodFlowBucket(
        code: 'DIGER_HAREKET',
        title: 'Çek, Senet, Virman & Dekont İşlemleri',
        isIncoming: false,
        totalAmountTl: double.parse(otherSum.toStringAsFixed(2)),
        count: others.length,
        items: List<AccountingTransaction>.unmodifiable(others),
      ),
    );

    final totalIncoming = buckets
        .where((b) => b.isIncoming)
        .fold<double>(0.0, (s, b) => s + b.totalAmountTl);
    final totalOutgoing = buckets
        .where((b) => !b.isIncoming)
        .fold<double>(0.0, (s, b) => s + b.totalAmountTl);

    return EodFlowBreakdown(
      dateKey: dateKey,
      totalIncomingTl: double.parse(totalIncoming.toStringAsFixed(2)),
      totalOutgoingTl: double.parse(totalOutgoing.toStringAsFixed(2)),
      netFlowTl: double.parse((totalIncoming - totalOutgoing).toStringAsFixed(2)),
      buckets: List<EodFlowBucket>.unmodifiable(buckets),
    );
  }
}

/// OCP uyumlu 6 kurumsal Hasibu belge & rapor şablon kayıt defteri (.repx & CSV).
class RepxDocumentRegistry {
  RepxDocumentRegistry._();

  static const List<RepxTemplateSpec> templates = <RepxTemplateSpec>[
    RepxTemplateSpec(
      templateId: 'FATURA',
      fileName: 'FATURA.repx',
      title: 'Kurumsal Satış & İade Faturası',
      category: 'Ticari Belge',
    ),
    RepxTemplateSpec(
      templateId: 'IRSALIYE',
      fileName: 'IRSALIYE.repx',
      title: 'Sevk İrsaliyesi & Tepsi Zimmet Formu',
      category: 'Lojistik Belge',
    ),
    RepxTemplateSpec(
      templateId: 'SIPARIS',
      fileName: 'SIPARIS.repx',
      title: 'Müşteri Sipariş Onay Fişi',
      category: 'Sipariş Belgesi',
    ),
    RepxTemplateSpec(
      templateId: 'MAGAZA_SEVK',
      fileName: 'MagazaSevk.repx',
      title: 'Şube & Mağaza Depo Sevk Çeki Listesi',
      category: 'Şube Sevkiyat',
    ),
    RepxTemplateSpec(
      templateId: 'GENEL_DURUM',
      fileName: 'GENELDURUMRAPOR.repx',
      title: 'Genel Durum, Stok Maliyet & Nakit İcmali',
      category: 'Yönetici Raporu',
    ),
    RepxTemplateSpec(
      templateId: 'DONEMSEL_RAPOR',
      fileName: 'DonemselRapor.repx',
      title: 'Dönemsel Faaliyet & Plasiyer Raporu',
      category: 'Dönem Raporu',
    ),
  ];

  static String renderPreviewText(
    String templateId,
    PreAccountingAdvancedViewData data,
  ) {
    final buf = StringBuffer();
    buf.writeln('============================================================');
    buf.writeln('${data.companyName} — HASİBU KURUMSAL BELGE ÇIKTISI');
    buf.writeln(
      'Şablon: $templateId | Dönem: ${data.selectedPeriodKey} | Tarih: ${data.selectedDateKey}',
    );
    buf.writeln('============================================================');

    if (templateId == 'FATURA' ||
        templateId == 'IRSALIYE' ||
        templateId == 'SIPARIS' ||
        templateId == 'MAGAZA_SEVK') {
      final docs = data.erpDocuments;
      if (docs.isEmpty) {
        buf.writeln('Kayıtlı ERP belge satırı bulunmuyor.');
      } else {
        double grand = 0.0;
        for (final d in docs.take(12)) {
          grand += d.grandTotalTl;
          buf.writeln(
            '• ${d.invoiceDocNo ?? d.waybillDocNo ?? d.orderDocNo} | ${d.accountName} | ${d.stockName} | ${d.activeQtyKg.toStringAsFixed(1)} Kg (${d.trayCount} Tepsi) | ${PreAccountingMathEngine.formatTl(d.grandTotalTl)}',
          );
        }
        buf.writeln('------------------------------------------------------------');
        buf.writeln('GENEL TOPLAM: ${PreAccountingMathEngine.formatTl(grand)}');
        buf.writeln(PreAccountingMathEngine.amountToTurkishWords(grand));
      }
      return buf.toString();
    }

    if (templateId == 'GENEL_DURUM') {
      final stockVal = data.stocks.fold<double>(
        0.0,
        (s, i) => s + i.totalValuation,
      );
      final rec = data.accounts
          .where((a) => a.netBalance < 0)
          .fold<double>(0.0, (s, a) => s + a.netBalance.abs());
      final pay = data.accounts
          .where((a) => a.netBalance > 0)
          .fold<double>(0.0, (s, a) => s + a.netBalance);
      buf.writeln('Toplam Müşteri/Şube Alacağı: ${PreAccountingMathEngine.formatTl(rec)}');
      buf.writeln('Toplam Tedarikçi/Personel Borcu: ${PreAccountingMathEngine.formatTl(pay)}');
      buf.writeln('Maliyetli Stok Envanter Değeri: ${PreAccountingMathEngine.formatTl(stockVal)}');
      buf.writeln('Portföydeki Çek/Senet Sayısı: ${data.checkPortfolio.length}');
      return buf.toString();
    }

    final repRows = PreAccountingMathEngine.buildSalesRepReport(
      accounts: data.accounts,
      docs: data.erpDocuments,
      transactions: data.transactions,
    );
    buf.writeln('PLASİYER VE DÖNEMSEL FAALİYET ÖZETİ:');
    for (final r in repRows) {
      buf.writeln(
        '• ${r.salesRepName}: ${r.invoiceCount} Belge | Satış ${PreAccountingMathEngine.formatTl(r.totalSalesTl)} | Tahsilat ${PreAccountingMathEngine.formatTl(r.totalCollectedTl)} (%${r.collectionRatioPercent.toStringAsFixed(1)})',
      );
    }
    return buf.toString();
  }

  static String exportCsv(
    String templateId,
    PreAccountingAdvancedViewData data,
  ) {
    final buf = StringBuffer();
    if (templateId == 'GENEL_DURUM') {
      buf.writeln('Kod;CariAdi;Tip;OzelKod;Plasiyer;NetBakiyeTL;EmanetTepsi');
      for (final a in data.accounts) {
        buf.writeln(
          '${a.code};${a.name};${a.type.label};${a.specialCode};${a.salesRepName};${a.netBalance.toStringAsFixed(2)};${a.trayBalance}',
        );
      }
      return buf.toString();
    }
    if (templateId == 'DONEMSEL_RAPOR') {
      buf.writeln('Plasiyer;BelgeSayisi;ToplamSatisTL;ToplamTahsilatTL;TahsilatOraniYuzde');
      final rows = PreAccountingMathEngine.buildSalesRepReport(
        accounts: data.accounts,
        docs: data.erpDocuments,
        transactions: data.transactions,
      );
      for (final r in rows) {
        buf.writeln(
          '${r.salesRepName};${r.invoiceCount};${r.totalSalesTl.toStringAsFixed(2)};${r.totalCollectedTl.toStringAsFixed(2)};${r.collectionRatioPercent.toStringAsFixed(1)}',
        );
      }
      return buf.toString();
    }
    buf.writeln('SiparisNo;IrsaliyeNo;FaturaNo;Tarih;CariAdi;StokAdi;MiktarKg;Tepsi;GenelToplamTL;Asama');
    for (final d in data.erpDocuments) {
      buf.writeln(
        '${d.orderDocNo};${d.waybillDocNo ?? ""};${d.invoiceDocNo ?? ""};${d.dateKey};${d.accountName};${d.stockName};${d.activeQtyKg.toStringAsFixed(2)};${d.trayCount};${d.grandTotalTl.toStringAsFixed(2)};${d.stage}',
      );
    }
    return buf.toString();
  }
}

/// DIP Döviz Kuru Sağlayıcı Sözleşmesi.
abstract interface class CurrencyRateGateway {
  Future<List<CurrencyRateQuote>> fetchRates({bool forceRefresh = false});
  List<CurrencyRateQuote> fallbackRates();
}

/// DIP Ön Muhasebe İleri Operasyon Sözleşmesi.
abstract interface class PreAccountingAdvancedActions {
  Future<void> refreshCurrencyRates({bool forceRefresh = true});

  void recordFxCollection({
    required AccountingAccount account,
    required bool isIncoming,
    required String currencyCode,
    required double fxRate,
    required double fxAmount,
    required String cashOrBankName,
    String description = '',
  });

  void submitCheckBordroBatch({
    required AccountingAccount account,
    required bool isIncoming,
    required List<CheckPortfolioItem> items,
    String bordroNote = '',
  });

  void transitionCheckStatus({
    required String checkId,
    required CheckPortfolioStatus nextStatus,
    AccountingAccount? endorseTargetAccount,
    String cashOrBankName = 'Merkez TL Kasa',
  });

  void upsertPaymentTemplate(PaymentInstructionTemplate template);
  void deletePaymentTemplate(String id);

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
  });

  void executePendingPaymentOrder(String orderId);

  void applyAutoDiscountToErpDoc({
    required String erpDocId,
    required double targetNetTotalTl,
  });

  void settleInvoicePartially({
    required String erpDocId,
    required double amountTl,
    required String cashOrBankName,
    required bool viaBank,
  });

  void createOrdersFromStockTemplate({
    required AccountingAccount account,
    required String templateCategory,
    required int priceTier,
  });

  void createReturnErpInvoice({
    required AccountingAccount account,
    required bool isSalesReturn,
    required String stockCode,
    required String stockName,
    required double qtyKg,
    required double unitPriceTl,
    double vatPercent = 10.0,
  });

  void upsertDealerContract(DealerContractRecord contract);

  void terminateDealerContract({
    required String contractId,
    required String reason,
  });

  void addInteractiveCustomSpreadsheetRow({
    required String sheetTitle,
    required String categoryName,
    required double debitColumnTl,
    required double creditColumnTl,
    required String formulaNote,
  });

  PeriodRolloverPreview previewPeriodRollover({
    required String nextPeriodKey,
    required String rolloverDateKey,
  });

  void executePeriodRollover({
    required String nextPeriodKey,
    required String rolloverDateKey,
  });
}
