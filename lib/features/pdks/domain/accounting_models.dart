import 'package:flutter/foundation.dart';

enum AccountingAccountType {
  customer('Müşteri / Bayi', 'MŞT'),
  supplier('Tedarikçi', 'TED'),
  branch('Şube / Mağaza', 'ŞUB'),
  employee('Personel Cari', 'PRS');

  final String label;
  final String prefix;
  const AccountingAccountType(this.label, this.prefix);

  static AccountingAccountType fromName(String? raw) {
    for (final t in AccountingAccountType.values) {
      if (t.name == raw) return t;
    }
    return AccountingAccountType.customer;
  }
}

enum SalaryType {
  monthly('Aylık Maaş (4857 / 225 Saat)', 225.0),
  daily('Günlük Yevmiye (7.5 Saat)', 7.5);

  final String label;
  final double standardDivisorHours;
  const SalaryType(this.label, this.standardDivisorHours);

  static SalaryType fromName(String? raw) {
    for (final s in SalaryType.values) {
      if (s.name == raw) return s;
    }
    return SalaryType.monthly;
  }
}

@immutable
class AccountingAccount {
  final String id;
  final String code;
  final String name;
  final AccountingAccountType type;
  final String groupName;
  final String phone;
  final String taxOfficeAndNo;
  final String? employeeCardNo;
  final SalaryType salaryType;
  final double baseSalaryOrDailyRate;
  final double creditTotal; // Alacak (A)
  final double debitTotal; // Borç (B)
  final int trayBalance; // Emanet Tepsi Kalan (Verilen - Alınan)
  final int crateBalance; // Emanet Köşebent/Kasa Kalan (Verilen - Alınan)
  final String specialCode; // Cari Özel Kodu (Örn: OKUL, BAYİ-A)
  final int priceTier; // 1..10 Satış Fiyat Grubu
  final double defaultDiscountPercent; // Cari varsayılan fatura iskonto %
  final String salesRepName; // Sorumlu Plasiyer
  final double creditLimitTl; // Açık hesap kredi/risk limiti
  final String cityDistrict; // İl / İlçe / Bölge

  const AccountingAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.groupName = 'Genel',
    this.phone = '',
    this.taxOfficeAndNo = '',
    this.employeeCardNo,
    this.salaryType = SalaryType.monthly,
    this.baseSalaryOrDailyRate = 0.0,
    this.creditTotal = 0.0,
    this.debitTotal = 0.0,
    this.trayBalance = 0,
    this.crateBalance = 0,
    this.specialCode = '',
    this.priceTier = 1,
    this.defaultDiscountPercent = 0.0,
    this.salesRepName = '',
    this.creditLimitTl = 0.0,
    this.cityDistrict = '',
  });

  /// Net Bakiye: Alacak (A) - Borç (B).
  /// Müşteri/Şube borçluysa negatif görünür (Cari Borç Bakiyeleri standardı),
  /// Personel maaş alacaklısıysa pozitif görünür.
  double get netBalance => creditTotal - debitTotal;

  double get hourlyRate {
    if (baseSalaryOrDailyRate <= 0) return 0.0;
    return baseSalaryOrDailyRate / salaryType.standardDivisorHours;
  }

  AccountingAccount copyWith({
    String? id,
    String? code,
    String? name,
    AccountingAccountType? type,
    String? groupName,
    String? phone,
    String? taxOfficeAndNo,
    String? employeeCardNo,
    SalaryType? salaryType,
    double? baseSalaryOrDailyRate,
    double? creditTotal,
    double? debitTotal,
    int? trayBalance,
    int? crateBalance,
    String? specialCode,
    int? priceTier,
    double? defaultDiscountPercent,
    String? salesRepName,
    double? creditLimitTl,
    String? cityDistrict,
  }) {
    return AccountingAccount(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      groupName: groupName ?? this.groupName,
      phone: phone ?? this.phone,
      taxOfficeAndNo: taxOfficeAndNo ?? this.taxOfficeAndNo,
      employeeCardNo: employeeCardNo ?? this.employeeCardNo,
      salaryType: salaryType ?? this.salaryType,
      baseSalaryOrDailyRate:
          baseSalaryOrDailyRate ?? this.baseSalaryOrDailyRate,
      creditTotal: creditTotal ?? this.creditTotal,
      debitTotal: debitTotal ?? this.debitTotal,
      trayBalance: trayBalance ?? this.trayBalance,
      crateBalance: crateBalance ?? this.crateBalance,
      specialCode: specialCode ?? this.specialCode,
      priceTier: priceTier ?? this.priceTier,
      defaultDiscountPercent:
          defaultDiscountPercent ?? this.defaultDiscountPercent,
      salesRepName: salesRepName ?? this.salesRepName,
      creditLimitTl: creditLimitTl ?? this.creditLimitTl,
      cityDistrict: cityDistrict ?? this.cityDistrict,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'type': type.name,
        'groupName': groupName,
        'phone': phone,
        'taxOfficeAndNo': taxOfficeAndNo,
        'employeeCardNo': employeeCardNo,
        'salaryType': salaryType.name,
        'baseSalaryOrDailyRate': baseSalaryOrDailyRate,
        'creditTotal': creditTotal,
        'debitTotal': debitTotal,
        'trayBalance': trayBalance,
        'crateBalance': crateBalance,
        'specialCode': specialCode,
        'priceTier': priceTier,
        'defaultDiscountPercent': defaultDiscountPercent,
        'salesRepName': salesRepName,
        'creditLimitTl': creditLimitTl,
        'cityDistrict': cityDistrict,
      };

  factory AccountingAccount.fromJson(Map<String, dynamic> json) {
    return AccountingAccount(
      id: (json['id'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      type: AccountingAccountType.fromName(json['type'] as String?),
      groupName: (json['groupName'] as String?) ?? 'GENEL',
      phone: (json['phone'] as String?) ?? '',
      taxOfficeAndNo: (json['taxOfficeAndNo'] as String?) ?? '',
      employeeCardNo: json['employeeCardNo'] as String?,
      salaryType: SalaryType.values.firstWhere(
        (e) => e.name == json['salaryType'],
        orElse: () => SalaryType.monthly,
      ),
      baseSalaryOrDailyRate:
          (json['baseSalaryOrDailyRate'] as num?)?.toDouble() ?? 0.0,
      creditTotal: (json['creditTotal'] as num?)?.toDouble() ?? 0.0,
      debitTotal: (json['debitTotal'] as num?)?.toDouble() ?? 0.0,
      trayBalance: (json['trayBalance'] as num?)?.toInt() ?? 0,
      crateBalance: (json['crateBalance'] as num?)?.toInt() ?? 0,
      specialCode: (json['specialCode'] as String?) ?? '',
      priceTier: (json['priceTier'] as num?)?.toInt() ?? 1,
      defaultDiscountPercent:
          (json['defaultDiscountPercent'] as num?)?.toDouble() ?? 0.0,
      salesRepName: (json['salesRepName'] as String?) ?? '',
      creditLimitTl: (json['creditLimitTl'] as num?)?.toDouble() ?? 0.0,
      cityDistrict: (json['cityDistrict'] as String?) ?? '',
    );
  }
}

enum LedgerEntryType {
  salesOrder('Sipariş / Satış', true, 'B'),
  purchaseOrder('Verilen Sipariş', false, 'A'),
  salesInvoice('Satış Faturası', true, 'B'),
  purchaseInvoice('Alış Faturası', false, 'A'),
  salesWaybill('Satış İrsaliyesi', true, 'B'),
  purchaseWaybill('Alış İrsaliyesi', false, 'A'),
  salesReturn('Satıştan İade Faturası', true, 'A'),
  purchaseReturn('Alıştan İade Faturası', false, 'B'),
  iceCreamSale('Dondurma Satış Fişi', true, 'B'),
  cashIn('Gelen Nakit (Kasa Tahsilat)', true, 'A'),
  cashOut('Kasa Nakit Ödeme', false, 'B'),
  bankIn('Gelen Banka (Havale/EFT)', true, 'A'),
  bankOut('Giden Banka (Havale/EFT)', false, 'B'),
  checkIn('Çek Girişi (Alınan Çek)', true, 'A'),
  checkOut('Çek Çıkışı (Verilen/Ciro)', false, 'B'),
  promissoryIn('Senet Girişi (Alınan Senet)', true, 'A'),
  promissoryOut('Senet Çıkışı (Borç Senedi)', false, 'B'),
  debitMemo('Borç Dekontu', false, 'B'),
  creditMemo('Alacak Dekontu', true, 'A'),
  transferVirman('Virman Fişi', true, 'A'),
  stockInVoucher('Stok Giriş Fişi', true, 'A'),
  stockOutVoucher('Stok Çıkış / Sarf Fişi', false, 'B'),
  warehouseTransfer('Depo Sevk Fişi', false, 'B'),
  productionVoucher('Üretim Giriş Fişi', true, 'A'),
  expense('İşletme / Mağaza Gideri', false, 'B'),
  payrollAccrual('Puantaj Maaş Hakediş Dekontu', false, 'A'),
  advancePayment('Personel Avans Ödemesi', false, 'B'),
  personnelBonusOrDeduction('Personel Mesai / Kesinti Girişi', false, 'A'),
  vatReflectionMemo('Resmi KDV Yansıtma Fişi', false, 'B'),
  branchPosSale('Mağaza POS Gün Sonu Cirosu', true, 'B'),
  branchBoxTareCredit('Mağaza Kutu Dara Denkleştirme', true, 'A');

  final String label;
  final bool isIncomingFlow;
  final String defaultDirection; // 'A' = Alacak, 'B' = Borç
  const LedgerEntryType(
    this.label,
    this.isIncomingFlow,
    this.defaultDirection,
  );

  static LedgerEntryType fromName(String? raw) {
    for (final e in LedgerEntryType.values) {
      if (e.name == raw) return e;
    }
    return LedgerEntryType.cashIn;
  }
}

enum PreAccountingRibbonGroup {
  cariIslemler('Cari İşlemler'),
  fatura('Fatura'),
  stokIslemleri('Stok İşlemleri'),
  personel('Personel'),
  yardimcilar('Yardımcılar');

  final String title;
  const PreAccountingRibbonGroup(this.title);
}

enum PreAccountingOperationModule {
  // 1. Cari İşlemler
  cariTanimlari(
    PreAccountingRibbonGroup.cariIslemler,
    'Cari Tanımları',
    'Müşteri, Tedarikçi, Şube & Personel Cari Kart Tanımlama ve Açılış Devir Girişi',
    'Alacak Devir Girişi (A)',
    'Borç Devir Çıkışı (B)',
    LedgerEntryType.creditMemo,
    LedgerEntryType.debitMemo,
    'CARI',
  ),
  kasaIslemleri(
    PreAccountingRibbonGroup.cariIslemler,
    'Kasa İşlemleri',
    'Merkez & Şube Kasa Tahsilat (Giriş) ve Nakit Tediye / Gider Ödeme (Çıkış) Fişleri',
    'Kasa Giriş (Tahsilat)',
    'Kasa Çıkış (Tediye / Gider)',
    LedgerEntryType.cashIn,
    LedgerEntryType.cashOut,
    'KAS',
  ),
  bankaIslemleri(
    PreAccountingRibbonGroup.cariIslemler,
    'Banka İşlemleri',
    'Gelen Havale/EFT/POS Yatırılan (Giriş) ve Giden Havale/EFT/Çekilen (Çıkış) İşlemleri',
    'Banka Giriş (Gelen Havale/POS)',
    'Banka Çıkış (Giden EFT/Ödeme)',
    LedgerEntryType.bankIn,
    LedgerEntryType.bankOut,
    'BNK',
  ),
  cekIslemleri(
    PreAccountingRibbonGroup.cariIslemler,
    'Çek İşlemleri',
    'Müşteri Çeki Portföy Girişi, Kendi Çekimiz / Ciro Çıkışı ve Vade Takibi',
    'Çek Girişi (Alınan Çek)',
    'Çek Çıkışı (Verilen / Ciro)',
    LedgerEntryType.checkIn,
    LedgerEntryType.checkOut,
    'CEK',
  ),
  senetIslemleri(
    PreAccountingRibbonGroup.cariIslemler,
    'Senet İşlemleri',
    'Müşteri Senedi Girişi, Borç Senedi Çıkışı ve Vade / Tahsilat Takibi',
    'Senet Girişi (Alınan Senet)',
    'Senet Çıkışı (Borç Senedi)',
    LedgerEntryType.promissoryIn,
    LedgerEntryType.promissoryOut,
    'SNT',
  ),
  dekontIslemleri(
    PreAccountingRibbonGroup.cariIslemler,
    'Dekont İşlemleri',
    'Cari Alacak Dekontu (Giriş - A) ve Cari Borç Dekontu (Çıkış - B) Mahsup Fişleri',
    'Alacak Dekontu (A)',
    'Borç Dekontu (B)',
    LedgerEntryType.creditMemo,
    LedgerEntryType.debitMemo,
    'DEK',
  ),
  virmanlar(
    PreAccountingRibbonGroup.cariIslemler,
    'Virmanlar',
    'Cari-Cari, Kasa-Banka ve Şubeler Arası Çift Taraflı Bakiye Virman Fişleri',
    'Virman Giriş (Alacaklandır)',
    'Virman Çıkış (Borçlandır)',
    LedgerEntryType.transferVirman,
    LedgerEntryType.transferVirman,
    'VRM',
  ),
  giderIslemleri(
    PreAccountingRibbonGroup.cariIslemler,
    'Gider İşlemleri',
    'Gider Kartı Tanımlama, Kira, Enerji, Lojistik & Sarf Gider Girişi (Giris_GIDER)',
    'Gider İade / Mahsup Girişi',
    'İşletme / Mağaza Gider Çıkışı',
    LedgerEntryType.creditMemo,
    LedgerEntryType.expense,
    'GDR',
  ),
  kurBazliTahsilat(
    PreAccountingRibbonGroup.cariIslemler,
    'Kur Bazlı Tahsilat (Döviz)',
    'USD / EUR / GBP Kur Bazlı Döviz Kasa Tahsilatı ve TL Karşılığı Cari Mahsubu',
    'Dövizli Tahsilat Girişi (A)',
    'Dövizli Ödeme Çıkışı (B)',
    LedgerEntryType.cashIn,
    LedgerEntryType.cashOut,
    'DVZ',
  ),

  // 2. Fatura
  siparisler(
    PreAccountingRibbonGroup.fatura,
    'Siparişler',
    'Müşteriden Alınan Sipariş Girişi ve Tedarikçiye Verilen Sipariş Çıkışı',
    'Alınan Sipariş (Satış)',
    'Verilen Sipariş (Alım)',
    LedgerEntryType.salesOrder,
    LedgerEntryType.purchaseOrder,
    'SIP',
  ),
  irsaliyeler(
    PreAccountingRibbonGroup.fatura,
    'İrsaliyeler',
    'Siparişten İrsaliyeye Aktarım, Satış İrsaliyesi, Alış İrsaliyesi ve Faturaya Bağlama',
    'Satış İrsaliyesi (Sevk)',
    'Alış İrsaliyesi (Mal Kabul)',
    LedgerEntryType.salesWaybill,
    LedgerEntryType.purchaseWaybill,
    'IRS',
  ),
  faturalar(
    PreAccountingRibbonGroup.fatura,
    'Faturalar',
    'Satış Faturası, Alış Faturası ve Satıştan / Alıştan İade Faturası İşlemleri',
    'Satış / İade Faturası (Giriş)',
    'Alış Faturası (Borç/Çıkış)',
    LedgerEntryType.salesInvoice,
    LedgerEntryType.purchaseInvoice,
    'FAT',
  ),
  dondurmaSatislar(
    PreAccountingRibbonGroup.fatura,
    'Dondurma Satışlar',
    'Tezgah & Toptan Dondurma / Tatlı Hızlı Satış Girişi ve İade Çıkışı',
    'Dondurma Satış Girişi',
    'Dondurma İade / İkram Çıkışı',
    LedgerEntryType.iceCreamSale,
    LedgerEntryType.salesReturn,
    'DND',
  ),
  bayiSozlesmeVeBolgeFiyat(
    PreAccountingRibbonGroup.fatura,
    'Bayi Sözleşme & Bölge Fiyat',
    'Bayi Sözleşmesi, 1..10 Satış Fiyat Grubu ve Bölge Şablonuna Göre Toplu Fiyat Güncelleme',
    'Bayi İskonto / Prim Alacağı',
    'Bayi Sözleşme / Kota Tahakkuku',
    LedgerEntryType.creditMemo,
    LedgerEntryType.debitMemo,
    'BAY',
  ),

  // 3. Stok İşlemleri
  stokTanimlari(
    PreAccountingRibbonGroup.stokIslemleri,
    'Stok Tanımları',
    'Hammadde, Yarı Mamul & Mamul Stok Kartı Açma, Birim Maliyet ve Günlük Sarfiyat Tanımı',
    'Yeni Stok / Devir Girişi (+)',
    'Stok Düzeltme Çıkışı (-)',
    LedgerEntryType.stockInVoucher,
    LedgerEntryType.stockOutVoucher,
    'STK',
  ),
  stokFisleri(
    PreAccountingRibbonGroup.stokIslemleri,
    'Stok Fişleri',
    'Depo Stok Giriş Fişi (+Miktar) ve Stok Çıkış / Sarf / Fire Fişi (-Miktar)',
    'Stok Giriş Fişi (+)',
    'Stok Çıkış / Fire Fişi (-)',
    LedgerEntryType.stockInVoucher,
    LedgerEntryType.stockOutVoucher,
    'SFS',
  ),
  tepsiKosebentIade(
    PreAccountingRibbonGroup.stokIslemleri,
    'Tepsi ve Köşebent İade',
    'Müşteri & Şube Emanet Tepsi, Köşebent, Küvet ve Kasa Verilen (Çıkış) / İade (Giriş) Fişi',
    'Tepsi / Köşebent İade Girişi',
    'Emanet Tepsi / Köşebent Çıkışı',
    LedgerEntryType.stockInVoucher,
    LedgerEntryType.stockOutVoucher,
    'TPS',
  ),
  depoSevkFisleri(
    PreAccountingRibbonGroup.stokIslemleri,
    'Depo Sevk Fişleri',
    'Merkez Fabrika -> Şube Depoları Arası Ürün ve Hammadde Sevk / Transfer Fişleri',
    'Depo Teslim Giriş Fişi (+)',
    'Depo Sevk Çıkış Fişi (-)',
    LedgerEntryType.stockInVoucher,
    LedgerEntryType.warehouseTransfer,
    'SVK',
  ),
  uretimFisleri(
    PreAccountingRibbonGroup.stokIslemleri,
    'Üretim Fişleri',
    'Günlük Baklava / Dondurma Üretim Giriş Fişi ve Hammadde Sarfiyat Düşümü',
    'Mamul Üretim Girişi (+)',
    'Hammadde Sarf Düşümü (-)',
    LedgerEntryType.productionVoucher,
    LedgerEntryType.stockOutVoucher,
    'URT',
  ),
  uretimListesiVeHammaddeler(
    PreAccountingRibbonGroup.stokIslemleri,
    'Üretim Listesi ve Hammaddeler',
    'Reçete / BOM Hammadde Kalan Gün Analizi, Kritik Stok Giriş ve Tüketim Çıkış Kaydı',
    'Hammadde Stok Girişi (+)',
    'Günlük Üretim Tüketim Çıkışı (-)',
    LedgerEntryType.stockInVoucher,
    LedgerEntryType.stockOutVoucher,
    'BOM',
  ),
  bulgurVeBugdayUretim(
    PreAccountingRibbonGroup.stokIslemleri,
    'Buğday / Bulgur & Özel Reçete',
    'Buğday/Bulgur Üretim Fişi (UretimFisi_Bugday), Randıman, Fire ve Reçete Maliyet Hesabı',
    'Buğday/Bulgur Mamul Girişi (+)',
    'Buğday Hammadde Düşümü (-)',
    LedgerEntryType.productionVoucher,
    LedgerEntryType.stockOutVoucher,
    'BGD',
  ),
  resmiAlisFaturaVeRecete(
    PreAccountingRibbonGroup.stokIslemleri,
    'Resmi Fatura, Reçete & KDV Yansıtma',
    'Resmi Alış Faturası, Resmi Üretim Reçetesi ve Ana Programa KDV Yansıtma Hesabı',
    'Resmi Alış Faturası Girişi',
    'KDV Yansıtma Borç Dekontu',
    LedgerEntryType.purchaseInvoice,
    LedgerEntryType.vatReflectionMemo,
    'RSM',
  ),

  // 4. Personel
  personelKart(
    PreAccountingRibbonGroup.personel,
    'Personel Kart',
    'Personel Maaş / Yevmiye Cari Kartı Açma ve Ücret / Departman Tanımlama',
    'Personel Alacak Tanımı (A)',
    'Personel Borç / Zimmet (B)',
    LedgerEntryType.payrollAccrual,
    LedgerEntryType.advancePayment,
    'PRS',
  ),
  puantaj(
    PreAccountingRibbonGroup.personel,
    'Puantaj',
    '30/31 Günlük Otomatik PDKS Puantaj Hakediş Tahakkuku ve Maaş Ödeme Köprüsü',
    'Puantaj Hakediş Tahakkuku (A)',
    'Puantaj Maaş Ödeme Çıkışı (B)',
    LedgerEntryType.payrollAccrual,
    LedgerEntryType.cashOut,
    'PNT',
  ),
  personelGirisler(
    PreAccountingRibbonGroup.personel,
    'Personel Girişler',
    'Personel Avans Çıkışı, Maaş Ödeme, Fazla Mesai / İkramiye Girişi ve Kesinti Fişi',
    'Mesai / İkramiye Alacak Girişi',
    'Avans / Maaş / Kesinti Çıkışı',
    LedgerEntryType.personnelBonusOrDeduction,
    LedgerEntryType.advancePayment,
    'PRG',
  ),

  // 5. Yardımcılar
  ozelTablolar(
    PreAccountingRibbonGroup.yardimcilar,
    'Özel Tablolar',
    'Kasa, Banka, Çek, Senet, Cari ve Stok Çapraz Bakiye & Hareket Özel Tablosu',
    'Özel Gelir Kaydı Girişi',
    'Özel Gider Kaydı Çıkışı',
    LedgerEntryType.cashIn,
    LedgerEntryType.expense,
    'OZL',
  ),
  ajanda(
    PreAccountingRibbonGroup.yardimcilar,
    'Ajanda',
    'Tahsilat, Ödeme, Vergi/SGK ve Sevkiyat Ajanda Hatırlatma Giriş / Çıkış Takvimi',
    'Ajanda Tahsilat Hatırlatması',
    'Ajanda Ödeme Hatırlatması',
    LedgerEntryType.creditMemo,
    LedgerEntryType.debitMemo,
    'AJN',
  ),
  odemeEmirleri(
    PreAccountingRibbonGroup.yardimcilar,
    'Ödeme Emirleri',
    'Tedarikçi, Kira, Fatura ve Banka Ödeme Emri Talimatı Giriş / Onay Çıkışı',
    'Ödeme Emri Talimatı Oluştur',
    'Ödeme Emrini Kasadan/Bankadan Öde',
    LedgerEntryType.debitMemo,
    LedgerEntryType.bankOut,
    'ODM',
  ),
  notlar(
    PreAccountingRibbonGroup.yardimcilar,
    'Notlar',
    'Gün Sonu Vardiya, Kasa Devir ve Müşteri Uyarı Notları Kayıt Merkezi',
    'Bilgi / Uyarı Notu Ekle',
    'Acil / Kritik Not Ekle',
    LedgerEntryType.creditMemo,
    LedgerEntryType.debitMemo,
    'NOT',
  ),
  kayanYazi(
    PreAccountingRibbonGroup.yardimcilar,
    'Kayan Yazı',
    'Üst Şerit Kayan Duyuru, Kampanya ve Kritik Vade / Stok Uyarısı Yönetimi',
    'Kayan Duyuru Metni Ekle',
    'Acil Kayan Uyarı Ekle',
    LedgerEntryType.creditMemo,
    LedgerEntryType.debitMemo,
    'KYN',
  ),
  smsVeEpostaBildirim(
    PreAccountingRibbonGroup.yardimcilar,
    'SMS & E-Posta Bildirim',
    'Cari Bakiye, Vade Hatırlatma ve Bayram/Kampanya Toplu SMS & E-Posta Gönderimi',
    'Bakiye Mutabakat Bildirimi',
    'Vade / Ödeme Hatırlatma SMS',
    LedgerEntryType.creditMemo,
    LedgerEntryType.debitMemo,
    'SMS',
  ),
  donemDevirVeBulutYedek(
    PreAccountingRibbonGroup.yardimcilar,
    'Dönem Devir & Çoklu Yedek',
    'Yıl Sonu Cari/Stok/Kasa/Çek Devir İşlemi, Lokal Çoklu Yedek ve FTP/Drive Yedekleme',
    'Dönem Açılış Devir Fişi (A)',
    'Dönem Kapanış Devir Fişi (B)',
    LedgerEntryType.creditMemo,
    LedgerEntryType.debitMemo,
    'DVR',
  );

  final PreAccountingRibbonGroup group;
  final String title;
  final String subtitle;
  final String inActionLabel;
  final String outActionLabel;
  final LedgerEntryType defaultInType;
  final LedgerEntryType defaultOutType;
  final String docPrefix;

  const PreAccountingOperationModule(
    this.group,
    this.title,
    this.subtitle,
    this.inActionLabel,
    this.outActionLabel,
    this.defaultInType,
    this.defaultOutType,
    this.docPrefix,
  );
}

@immutable
class AccountingTransaction {
  final String id;
  final String docNo;
  final String dateKey; // YYYY-MM-DD
  final String accountId;
  final String accountName;
  final LedgerEntryType entryType;
  final String direction; // 'A' (Alacak) veya 'B' (Borç)
  final double amount;
  final String cashOrBankName;
  final String expenseCategory;
  final String description;
  final String? puantajPeriodKey; // Örn: '2026-10'
  final String currencyCode; // 'TRY', 'USD', 'EUR', 'GBP'
  final double fxRate; // TCMB veya kullanıcı kuru
  final double fxAmount; // Döviz tutarı
  final double discountPercent; // Fatura / işlem iskontosu %
  final String salesRepName; // Plasiyer
  final double settledAmountTl; // İlişkili faturaya karşılık tahsil edilen
  final String linkedOrderDocId; // İlişkili sipariş / fatura id

  const AccountingTransaction({
    required this.id,
    required this.docNo,
    required this.dateKey,
    required this.accountId,
    required this.accountName,
    required this.entryType,
    required this.direction,
    required this.amount,
    this.cashOrBankName = 'Merkez TL Kasa',
    this.expenseCategory = '',
    this.description = '',
    this.puantajPeriodKey,
    this.currencyCode = 'TRY',
    this.fxRate = 1.0,
    this.fxAmount = 0.0,
    this.discountPercent = 0.0,
    this.salesRepName = '',
    this.settledAmountTl = 0.0,
    this.linkedOrderDocId = '',
  });

  AccountingTransaction copyWith({
    String? id,
    String? docNo,
    String? dateKey,
    String? accountId,
    String? accountName,
    LedgerEntryType? entryType,
    String? direction,
    double? amount,
    String? cashOrBankName,
    String? expenseCategory,
    String? description,
    String? puantajPeriodKey,
    String? currencyCode,
    double? fxRate,
    double? fxAmount,
    double? discountPercent,
    String? salesRepName,
    double? settledAmountTl,
    String? linkedOrderDocId,
  }) {
    return AccountingTransaction(
      id: id ?? this.id,
      docNo: docNo ?? this.docNo,
      dateKey: dateKey ?? this.dateKey,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      entryType: entryType ?? this.entryType,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      cashOrBankName: cashOrBankName ?? this.cashOrBankName,
      expenseCategory: expenseCategory ?? this.expenseCategory,
      description: description ?? this.description,
      puantajPeriodKey: puantajPeriodKey ?? this.puantajPeriodKey,
      currencyCode: currencyCode ?? this.currencyCode,
      fxRate: fxRate ?? this.fxRate,
      fxAmount: fxAmount ?? this.fxAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      salesRepName: salesRepName ?? this.salesRepName,
      settledAmountTl: settledAmountTl ?? this.settledAmountTl,
      linkedOrderDocId: linkedOrderDocId ?? this.linkedOrderDocId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'docNo': docNo,
        'dateKey': dateKey,
        'accountId': accountId,
        'accountName': accountName,
        'entryType': entryType.name,
        'direction': direction,
        'amount': amount,
        'cashOrBankName': cashOrBankName,
        'expenseCategory': expenseCategory,
        'description': description,
        'puantajPeriodKey': puantajPeriodKey,
        'currencyCode': currencyCode,
        'fxRate': fxRate,
        'fxAmount': fxAmount,
        'discountPercent': discountPercent,
        'salesRepName': salesRepName,
        'settledAmountTl': settledAmountTl,
        'linkedOrderDocId': linkedOrderDocId,
      };

  factory AccountingTransaction.fromJson(Map<String, dynamic> json) {
    return AccountingTransaction(
      id: (json['id'] as String?) ?? '',
      docNo: (json['docNo'] as String?) ?? '',
      dateKey: (json['dateKey'] as String?) ?? '',
      accountId: (json['accountId'] as String?) ?? '',
      accountName: (json['accountName'] as String?) ?? '',
      entryType: LedgerEntryType.values.firstWhere(
        (e) => e.name == json['entryType'],
        orElse: () => LedgerEntryType.cashIn,
      ),
      direction: (json['direction'] as String?) ?? 'A',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      cashOrBankName: (json['cashOrBankName'] as String?) ?? 'Merkez TL Kasa',
      expenseCategory: (json['expenseCategory'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      puantajPeriodKey: json['puantajPeriodKey'] as String?,
      currencyCode: (json['currencyCode'] as String?) ?? 'TRY',
      fxRate: (json['fxRate'] as num?)?.toDouble() ?? 1.0,
      fxAmount: (json['fxAmount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      salesRepName: (json['salesRepName'] as String?) ?? '',
      settledAmountTl: (json['settledAmountTl'] as num?)?.toDouble() ?? 0.0,
      linkedOrderDocId: (json['linkedOrderDocId'] as String?) ?? '',
    );
  }
}

@immutable
class ContainerMovement {
  final String id;
  final String dateKey;
  final String accountId;
  final String accountName;
  final String containerType; // 'Tepsi' veya 'Köşebent / Kasa'
  final int givenQty; // Verilen (Çıkış)
  final int returnedQty; // İade Alınan (Giriş)
  final String note;

  const ContainerMovement({
    required this.id,
    required this.dateKey,
    required this.accountId,
    required this.accountName,
    required this.containerType,
    required this.givenQty,
    required this.returnedQty,
    this.note = '',
  });

  int get netRemaining => givenQty - returnedQty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'accountId': accountId,
        'accountName': accountName,
        'containerType': containerType,
        'givenQty': givenQty,
        'returnedQty': returnedQty,
        'note': note,
      };

  factory ContainerMovement.fromJson(Map<String, dynamic> json) {
    return ContainerMovement(
      id: (json['id'] as String?) ?? '',
      dateKey: (json['dateKey'] as String?) ?? '',
      accountId: (json['accountId'] as String?) ?? '',
      accountName: (json['accountName'] as String?) ?? '',
      containerType: (json['containerType'] as String?) ?? 'Tepsi',
      givenQty: (json['givenQty'] as num?)?.toInt() ?? 0,
      returnedQty: (json['returnedQty'] as num?)?.toInt() ?? 0,
      note: (json['note'] as String?) ?? '',
    );
  }
}

@immutable
class StockBurnItem {
  final String id;
  final String code;
  final String name;
  final String unit;
  final double currentQty;
  final double dailyBurnRate;
  final double unitCost;
  final double salePriceTl;
  final double depositUnitTl;
  final String templateCategory;
  final String priceHistoryJson;

  const StockBurnItem({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.currentQty,
    required this.dailyBurnRate,
    required this.unitCost,
    this.salePriceTl = 0.0,
    this.depositUnitTl = 0.0,
    this.templateCategory = '',
    this.priceHistoryJson = '[]',
  });

  int get remainingDays {
    if (dailyBurnRate <= 0) return 999;
    return (currentQty / dailyBurnRate).floor().clamp(0, 999);
  }

  double get totalValuation => currentQty * unitCost;
  bool get isCritical => remainingDays <= 15;

  StockBurnItem copyWith({
    String? id,
    String? code,
    String? name,
    String? unit,
    double? currentQty,
    double? dailyBurnRate,
    double? unitCost,
    double? salePriceTl,
    double? depositUnitTl,
    String? templateCategory,
    String? priceHistoryJson,
  }) {
    return StockBurnItem(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      currentQty: currentQty ?? this.currentQty,
      dailyBurnRate: dailyBurnRate ?? this.dailyBurnRate,
      unitCost: unitCost ?? this.unitCost,
      salePriceTl: salePriceTl ?? this.salePriceTl,
      depositUnitTl: depositUnitTl ?? this.depositUnitTl,
      templateCategory: templateCategory ?? this.templateCategory,
      priceHistoryJson: priceHistoryJson ?? this.priceHistoryJson,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'unit': unit,
        'currentQty': currentQty,
        'dailyBurnRate': dailyBurnRate,
        'unitCost': unitCost,
        'salePriceTl': salePriceTl,
        'depositUnitTl': depositUnitTl,
        'templateCategory': templateCategory,
        'priceHistoryJson': priceHistoryJson,
      };

  factory StockBurnItem.fromJson(Map<String, dynamic> json) {
    return StockBurnItem(
      id: (json['id'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? 'KG',
      currentQty: (json['currentQty'] as num?)?.toDouble() ?? 0.0,
      dailyBurnRate: (json['dailyBurnRate'] as num?)?.toDouble() ?? 1.0,
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
      salePriceTl: (json['salePriceTl'] as num?)?.toDouble() ?? 0.0,
      depositUnitTl: (json['depositUnitTl'] as num?)?.toDouble() ?? 0.0,
      templateCategory: (json['templateCategory'] as String?) ?? '',
      priceHistoryJson: (json['priceHistoryJson'] as String?) ?? '[]',
    );
  }
}

@immutable
class CheckOrAlertNote {
  final String id;
  final String dueDate;
  final String kind; // 'ÇEK' veya 'NOT'
  final String titleOrParty;
  final double amount;
  final String note;

  const CheckOrAlertNote({
    required this.id,
    required this.dueDate,
    required this.kind,
    required this.titleOrParty,
    this.amount = 0.0,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dueDate': dueDate,
        'kind': kind,
        'titleOrParty': titleOrParty,
        'amount': amount,
        'note': note,
      };

  factory CheckOrAlertNote.fromJson(Map<String, dynamic> json) {
    return CheckOrAlertNote(
      id: (json['id'] as String?) ?? '',
      dueDate: (json['dueDate'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? 'ÇEK',
      titleOrParty: (json['titleOrParty'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      note: (json['note'] as String?) ?? '',
    );
  }
}

// ============================================================================
// GMS.NET BORDRO & PUANTAJ MOTORU (KANUN NO, EKSİK GÜN, TAHAKKUK & TAZMİNAT)
// ============================================================================

enum GmsSgkIncentiveLaw {
  law05510(
    '05510',
    '05510 - %5 Hazine Puan İndirimi (Standart)',
    0.155,
    0.02,
    0.05,
  ),
  law06111(
    '06111',
    '06111 - Genç & Kadın İstihdam Teşviki (%15.5 Hazine)',
    0.05,
    0.02,
    0.155,
  ),
  law17103(
    '17103',
    '17103 - İmalat & Bilişim İlave İstihdam Teşviki (%100)',
    0.0,
    0.0,
    0.225,
  ),
  law27103(
    '27103',
    '27103 - Diğer Sektör İlave İstihdam Teşviki',
    0.05,
    0.02,
    0.155,
  ),
  law05746(
    '05746',
    '05746 - Ar-Ge & Tasarım Merkezi SGK/Vergi Teşviki',
    0.0775,
    0.02,
    0.1275,
  ),
  law00000(
    '00000',
    '00000 - Kanunsuz (Teşviksiz Normal Bildirim)',
    0.205,
    0.02,
    0.0,
  );

  final String code;
  final String label;
  final double employerSgkRate;
  final double unemploymentEmployerRate;
  final double treasurySubsidyRate;

  const GmsSgkIncentiveLaw(
    this.code,
    this.label,
    this.employerSgkRate,
    this.unemploymentEmployerRate,
    this.treasurySubsidyRate,
  );
}

enum GmsMissingDayReason {
  code00('00', '00 - Eksik Gün Yok (30 Tam Gün)'),
  code01('01', '01 - İstirahat (Raporlu)'),
  code06('06', '06 - Kısmi İstihdam (Part-Time Sözleşmeli)'),
  code07('07', '07 - Puantaj Kayıtları (SGK Sözleşme Kontrolü)'),
  code12('12', '12 - Birden Fazla (İstirahat + Ücretsiz İzin)'),
  code15('15', '15 - Devamsızlık'),
  code21('21', '21 - Diğer Ücretsiz İzin');

  final String code;
  final String label;
  const GmsMissingDayReason(this.code, this.label);
}

@immutable
class GmsPayrollParameters {
  final bool isNetToGross; // Netten Brüte / Brütten Nete
  final GmsSgkIncentiveLaw defaultSgkLaw;
  final double minimumWageGrossTl; // Asgari Ücret Brüt (GV/DV İstisnası için)
  final double dailyMealExemptionTl; // Günlük Yemek SGK/Vergi İstisnası
  final double dailyTransportExemptionTl; // Günlük Yol İstisnası
  final double severanceCeilingTl; // Kıdem Tazminatı Tavanı
  final double besAutoEnrollmentRate; // %3 BES Otomatik Katılım

  const GmsPayrollParameters({
    this.isNetToGross = false,
    this.defaultSgkLaw = GmsSgkIncentiveLaw.law05510,
    this.minimumWageGrossTl = 26005.50,
    this.dailyMealExemptionTl = 240.0,
    this.dailyTransportExemptionTl = 126.0,
    this.severanceCeilingTl = 46655.43,
    this.besAutoEnrollmentRate = 0.03,
  });

  GmsPayrollParameters copyWith({
    bool? isNetToGross,
    GmsSgkIncentiveLaw? defaultSgkLaw,
    double? minimumWageGrossTl,
    double? dailyMealExemptionTl,
    double? dailyTransportExemptionTl,
    double? severanceCeilingTl,
    double? besAutoEnrollmentRate,
  }) {
    return GmsPayrollParameters(
      isNetToGross: isNetToGross ?? this.isNetToGross,
      defaultSgkLaw: defaultSgkLaw ?? this.defaultSgkLaw,
      minimumWageGrossTl: minimumWageGrossTl ?? this.minimumWageGrossTl,
      dailyMealExemptionTl: dailyMealExemptionTl ?? this.dailyMealExemptionTl,
      dailyTransportExemptionTl:
          dailyTransportExemptionTl ?? this.dailyTransportExemptionTl,
      severanceCeilingTl: severanceCeilingTl ?? this.severanceCeilingTl,
      besAutoEnrollmentRate:
          besAutoEnrollmentRate ?? this.besAutoEnrollmentRate,
    );
  }
}

@immutable
class PuantajEmployeeRow {
  final int employeeId;
  final String cardNo;
  final String fullName;
  final String departmentName;
  final String branchName;
  final String accountId;
  final SalaryType salaryType;
  final double baseSalary;
  final Map<int, String>
      dayCodes; // 1..31 -> 'X', 'T', 'B', 'R', 'İ', 'Y', 'FM', '-'
  final int workedDays;
  final int weeklyRestDays;
  final int paidLeaveDays;
  final int sickReportDays;
  final int absentDays;
  final int ubgtDays; // Ulusal Bayram & Genel Tatil ('B')
  final double overtimeHours;
  final double approvedAdvanceDeduction;
  final bool isAccruedToLedger;
  final double currentLedgerBalance;
  // GMS.NET Bordro Ek Alanları
  final GmsSgkIncentiveLaw sgkLaw;
  final GmsMissingDayReason missingDayReason;
  final bool besEnrolled;
  final double garnishmentDeduction;
  final String? garnishmentFileNo;
  final double mealAllowanceTl;
  final double transportAllowanceTl;
  final double bonusOrPremiumTl;
  final double cumulativeTaxBaseTl;
  final String iban;
  final String hireDate;
  final bool isEnvelopeSignedByEmployee;

  const PuantajEmployeeRow({
    required this.employeeId,
    required this.cardNo,
    required this.fullName,
    required this.departmentName,
    required this.branchName,
    required this.accountId,
    required this.salaryType,
    required this.baseSalary,
    required this.dayCodes,
    required this.workedDays,
    required this.weeklyRestDays,
    required this.paidLeaveDays,
    required this.sickReportDays,
    required this.absentDays,
    this.ubgtDays = 0,
    required this.overtimeHours,
    required this.approvedAdvanceDeduction,
    required this.isAccruedToLedger,
    required this.currentLedgerBalance,
    this.sgkLaw = GmsSgkIncentiveLaw.law05510,
    this.missingDayReason = GmsMissingDayReason.code00,
    this.besEnrolled = true,
    this.garnishmentDeduction = 0.0,
    this.garnishmentFileNo,
    this.mealAllowanceTl = 2400.0,
    this.transportAllowanceTl = 1200.0,
    this.bonusOrPremiumTl = 0.0,
    this.cumulativeTaxBaseTl = 142000.0,
    this.iban = 'TR42 0006 4000 0011 2345 6789 01',
    this.hireDate = '2021-03-15',
    this.isEnvelopeSignedByEmployee = false,
  });

  /// 4857 Sayılı İş Kanunu Md. 63 / Yargıtay standardı: Aylık maaş / 225 saat.
  double get hourlyRate =>
      baseSalary <= 0 ? 0.0 : baseSalary / salaryType.standardDivisorHours;

  /// Günlük yevmiye karşılığı: Aylık maaş / 30 gün (veya doğrudan günlük ücret).
  double get dailyRate =>
      salaryType == SalaryType.daily ? baseSalary : (baseSalary / 30.0);

  /// Hak edilen gün sayısı (Çalışılan + Hafta Tatili + UBGT + Ücretli İzin + Rapor).
  int get payableDays =>
      (workedDays + weeklyRestDays + ubgtDays + paidLeaveDays + sickReportDays)
          .clamp(0, 30);

  /// SGK Prim Ödeme Gün Sayısı (Maks. 30 gün).
  int get sgkReportedDays => payableDays.clamp(0, 30);

  /// SGK Eksik Gün Sayısı (30 - Prim Günü).
  int get sgkMissingDays => (30 - sgkReportedDays).clamp(0, 30);

  /// SGK `07-Puantaj Kayıtları` denetim uyarısı: Tam zamanlı (aylık) sözleşmede 07 seçilmesi riski.
  bool get hasSgkCode07AuditWarning =>
      sgkMissingDays > 0 &&
      missingDayReason == GmsMissingDayReason.code07 &&
      salaryType == SalaryType.monthly;

  /// Normal mesai hakediş tutarı.
  double get baseEarnedPay {
    if (salaryType == SalaryType.monthly && absentDays == 0) {
      return baseSalary;
    }
    return payableDays * dailyRate;
  }

  /// Fazla mesai ücreti (%50 zamlı — 1.5x).
  double get overtimePay => overtimeHours * hourlyRate * 1.5;

  /// UBGT (Ulusal Bayram ve Genel Tatil) ilave mesai yevmiyesi (4857 Md. 47 — +1 yevmiye).
  double get ubgtExtraPay => ubgtDays * dailyRate;

  /// Brüt/Toplam Puantaj Hakedişi (Cari hesaba Alacak 'A' olarak yazılacak temel tutar).
  double get grossAccrualPay => baseEarnedPay + overtimePay;

  /// GMS.NET Sosyal Yardımlar & Ek Ödemeler Toplamı (Yemek + Yol + Prim/İkramiye).
  double get socialBenefitsTotalTl =>
      mealAllowanceTl + transportAllowanceTl + bonusOrPremiumTl;

  /// GMS.NET Toplam Brüt Kazanç (Normal + FM + UBGT + Sosyal Haklar).
  double get grossTotalEarningsTl =>
      grossAccrualPay + ubgtExtraPay + socialBenefitsTotalTl;

  /// Yemek Yardımı SGK/Vergi İstisnası (Çalışılan gün * günlük istisna tavanı).
  double get mealTaxExemptionTl =>
      mealAllowanceTl.clamp(0.0, (workedDays + ubgtDays) * 240.0);

  /// SGK Primine Esas Kazanç (SPEK / SGK Matrahı).
  double get sgkBaseTl =>
      (grossTotalEarningsTl - mealTaxExemptionTl).clamp(0.0, double.infinity);

  /// SGK İşçi Payı (%14).
  double get sgkWorkerShareTl => sgkBaseTl * 0.14;

  /// SGK İşsizlik Sigortası İşçi Payı (%1).
  double get unemploymentWorkerShareTl => sgkBaseTl * 0.01;

  /// Gelir Vergisi Matrahı (Brüt Kazanç - SGK İşçi %14 - İşsizlik %1 - Yemek İstisnası).
  double get incomeTaxBaseTl => (grossTotalEarningsTl -
          sgkWorkerShareTl -
          unemploymentWorkerShareTl -
          mealTaxExemptionTl)
      .clamp(0.0, double.infinity);

  /// GMS.NET Kümülatif Gelir Vergisi Dilimi (%15, %20, %27, %35).
  int get incomeTaxBracketPercent {
    if (cumulativeTaxBaseTl >= 800000) return 35;
    if (cumulativeTaxBaseTl >= 330000) return 27;
    if (cumulativeTaxBaseTl >= 158000) return 20;
    return 15;
  }

  /// Hesaplanan Gelir Vergisi (İstisna Öncesi).
  double get calculatedIncomeTaxTl =>
      incomeTaxBaseTl * (incomeTaxBracketPercent / 100.0);

  /// Asgari Ücret Gelir Vergisi İstisnası (GMS.NET 7349 Sayılı Kanun İstisnası).
  double get minWageIncomeTaxExemptionTl => 3315.70 * (sgkReportedDays / 30.0);

  /// Ödenecek Net Gelir Vergisi (Muhtasar 1003A/1003B).
  double get payableIncomeTaxTl =>
      (calculatedIncomeTaxTl - minWageIncomeTaxExemptionTl)
          .clamp(0.0, double.infinity);

  /// Hesaplanan Damga Vergisi (Binde 7,59 — 0.00759).
  double get calculatedStampTaxTl => grossTotalEarningsTl * 0.00759;

  /// Asgari Ücret Damga Vergisi İstisnası.
  double get minWageStampTaxExemptionTl => 197.38 * (sgkReportedDays / 30.0);

  /// Ödenecek Net Damga Vergisi.
  double get payableStampTaxTl =>
      (calculatedStampTaxTl - minWageStampTaxExemptionTl)
          .clamp(0.0, double.infinity);

  /// Yasal Kesintiler Toplamı (SGK İşçi + İşsizlik + Ödenecek GV + Ödenecek DV).
  double get totalStatutoryDeductionsTl =>
      sgkWorkerShareTl +
      unemploymentWorkerShareTl +
      payableIncomeTaxTl +
      payableStampTaxTl;

  /// Bireysel Emeklilik Sistemi (BES %3 Otomatik Katılım) Kesintisi.
  double get besDeductionTl => besEnrolled ? (sgkBaseTl * 0.03) : 0.0;

  /// Özel Kesintiler Toplamı (Avans + BES + İcra).
  double get totalSpecialDeductionsTl =>
      approvedAdvanceDeduction + besDeductionTl + garnishmentDeduction;

  /// GMS.NET Net Tahakkuk Ücreti (Avans Öncesi, Yasal + BES + İcra Düşülmüş).
  double get gmsNetSalaryBeforeAdvanceTl => (grossTotalEarningsTl -
          totalStatutoryDeductionsTl -
          besDeductionTl -
          garnishmentDeduction)
      .clamp(0.0, double.infinity);

  /// GMS.NET Banka / Kasa Net Ödenecek Maaş (Avans Düşülmüş).
  double get gmsNetBankPayableTl =>
      (gmsNetSalaryBeforeAdvanceTl - approvedAdvanceDeduction)
          .clamp(0.0, double.infinity);

  /// SGK İşveren Payı (Seçili Kanun No 05510/06111/17103 Teşviki Sonrası).
  double get sgkEmployerShareTl => sgkBaseTl * sgkLaw.employerSgkRate;

  /// SGK İşveren İşsizlik Payı (%2 veya 17103'te %0).
  double get unemploymentEmployerShareTl =>
      sgkBaseTl * sgkLaw.unemploymentEmployerRate;

  /// Hazine SGK Prim Teşvik İndirimi Kazancı (5510 / 6111 / 17103 / 5746).
  double get sgkTreasurySubsidyTl => sgkBaseTl * sgkLaw.treasurySubsidyRate;

  /// İşverene Toplam Maliyet (Brüt Kazanç + SGK İşveren + İşveren İşsizlik).
  double get totalEmployerCostTl =>
      grossTotalEarningsTl + sgkEmployerShareTl + unemploymentEmployerShareTl;

  /// Tazminata Esas Giydirilmiş Aylık Brüt Ücret (Maaş + Yemek + Yol + İkramiye/12).
  double get dressedMonthlyGrossTl =>
      baseSalary +
      mealAllowanceTl +
      transportAllowanceTl +
      (bonusOrPremiumTl / 12.0);

  /// Kıdem Yılı Hesabı (4857 Md. 14).
  int get tenureYears {
    final parsed = DateTime.tryParse(hireDate);
    if (parsed == null) return 3;
    final ref = DateTime(2026, 10, 31);
    int yrs = ref.year - parsed.year;
    if (ref.month < parsed.month ||
        (ref.month == parsed.month && ref.day < parsed.day)) {
      yrs--;
    }
    return yrs.clamp(1, 45);
  }

  /// Kıdem Tazminatı Tavan Kontrollü Brüt Tutar.
  double calculateSeveranceGross([
    int? yearsOverride,
    double ceilingTl = 46655.43,
  ]) {
    final yrs = yearsOverride ?? tenureYears;
    final base = dressedMonthlyGrossTl.clamp(0.0, ceilingTl);
    return base * yrs;
  }

  /// Kıdem Tazminatı Damga Vergisi (Gelir Vergisinden Muaf, Sadece Binde 7,59 DV).
  double calculateSeveranceStampTax([int? yearsOverride]) =>
      calculateSeveranceGross(yearsOverride) * 0.00759;

  /// Net Kıdem Tazminatı.
  double calculateSeveranceNet([int? yearsOverride]) =>
      calculateSeveranceGross(yearsOverride) -
      calculateSeveranceStampTax(yearsOverride);

  /// 4857 Md. 17 İhbar Süresi (Hafta: <6 ay=2, 6-18 ay=4, 1.5-3 yıl=6, >3 yıl=8 hafta).
  int noticeWeeksForTenure([int? yearsOverride]) {
    final yrs = yearsOverride ?? tenureYears;
    if (yrs >= 3) return 8;
    if (yrs >= 2) return 6;
    if (yrs >= 1) return 4;
    return 2;
  }

  /// Brüt İhbar Tazminatı (Hafta * 7 * Giydirilmiş Günlük Brüt).
  double calculateNoticeGross([int? yearsOverride]) {
    final weeks = noticeWeeksForTenure(yearsOverride);
    return (dressedMonthlyGrossTl / 30.0) * (weeks * 7);
  }

  /// Net İhbar Tazminatı (Gelir Vergisi + Binde 7,59 Damga Vergisi Kesintili).
  double calculateNoticeNet([int? yearsOverride]) {
    final gross = calculateNoticeGross(yearsOverride);
    final gv = gross * (incomeTaxBracketPercent / 100.0);
    final dv = gross * 0.00759;
    return (gross - gv - dv).clamp(0.0, double.infinity);
  }

  /// Avans düşüldükten sonra Kasa/Bankadan ödenecek net tutar.
  double get netPayableAfterAdvance =>
      (grossAccrualPay - approvedAdvanceDeduction).clamp(0.0, double.infinity);
}

@immutable
class EndOfDayCockpitSummary {
  final double currentTotalBalance; // Kasa + Banka + Stok + Alacaklar
  final double cashOnHand; // Kasadaki Nakit
  final double last7DaysCashAverage; // Son 7 Gün Ortalama
  final double dailyBalanceIncrease; // Bakiye Artışı
  final double dailyBalanceIncreasePercent;
  final double totalIncoming; // Gelenler Toplamı (Kasa-Banka)
  final double totalOutgoing; // Gidenler Toplamı (Kasa-Banka Ödemeleri)
  final double netRemainingFlow; // Kalanlar Toplamı
  final double consumptionVarianceTl; // Sarfiyat Farkı
  final double unbilledInvoiceGapTl; // Fatura Açığı
  final Map<String, double> incomingByType;
  final Map<String, double> outgoingByCategory;

  const EndOfDayCockpitSummary({
    this.currentTotalBalance = 0.0,
    this.cashOnHand = 0.0,
    this.last7DaysCashAverage = 0.0,
    this.dailyBalanceIncrease = 0.0,
    this.dailyBalanceIncreasePercent = 0.0,
    this.totalIncoming = 0.0,
    this.totalOutgoing = 0.0,
    this.netRemainingFlow = 0.0,
    this.consumptionVarianceTl = 0.0,
    this.unbilledInvoiceGapTl = 0.0,
    this.incomingByType = const <String, double>{},
    this.outgoingByCategory = const <String, double>{},
  });
}

enum SaaSTier {
  starterFree(
    'Hasibu Başlangıç (Ücretsiz Kanca)',
    0,
    5,
    25,
    '5 Personele kadar Mobil QR PDKS, 25 Cari Kart, Temel Kasa & Gün Sonu Özeti',
  ),
  proKobi(
    'Hasibu Pro (KOBİ & İmalat)',
    590,
    30,
    9999,
    'Canlı PDKS Cihaz Köprüsü (TCP 4370), Otomatik Puantaj->Cari Hakediş, Emanet Kap & Google Drive Sync',
  ),
  enterpriseMultiBranch(
    'Hasibu Kurumsal (Çok Şubeli)',
    1490,
    9999,
    999999,
    'Sınırsız Personel & Şube Konsolidasyonu, 4857 Uyum Radarı, Kritik Stok (Kalan Gün) & Göç Sihirbazı',
  );

  final String title;
  final int monthlyPriceTl;
  final int maxEmployees;
  final int maxAccounts;
  final String featuresSummary;

  const SaaSTier(
    this.title,
    this.monthlyPriceTl,
    this.maxEmployees,
    this.maxAccounts,
    this.featuresSummary,
  );

  static SaaSTier fromName(String? raw) {
    for (final t in SaaSTier.values) {
      if (t.name == raw) return t;
    }
    return SaaSTier.proKobi;
  }
}

enum StoreDistributionChannel {
  appleAppStore('Apple App Store (iOS/macOS)', '%15 Small Business Program'),
  googlePlayStore('Google Play Store (Android)', '%15 Hizmet Dilimi'),
  microsoftStoreDirect(
    'Microsoft Store & Web (Windows)',
    '%0 Komisyon (Doğrudan Tahsilat)',
  );

  final String label;
  final String commissionBadge;
  const StoreDistributionChannel(this.label, this.commissionBadge);

  static StoreDistributionChannel fromName(String? raw) {
    for (final c in StoreDistributionChannel.values) {
      if (c.name == raw) return c;
    }
    return StoreDistributionChannel.microsoftStoreDirect;
  }
}

@immutable
class SaaSSubscriptionState {
  final SaaSTier activeTier;
  final StoreDistributionChannel channel;
  final bool isTrialActive;
  final int trialDaysRemaining;
  final bool hardwareHookConnected;

  const SaaSSubscriptionState({
    this.activeTier = SaaSTier.proKobi,
    this.channel = StoreDistributionChannel.microsoftStoreDirect,
    this.isTrialActive = true,
    this.trialDaysRemaining = 14,
    this.hardwareHookConnected = true,
  });
}

@immutable
class MigrationImportResult {
  final int accountsImported;
  final int stocksImported;
  final int transactionsCreated;
  final List<String> warnings;

  const MigrationImportResult({
    required this.accountsImported,
    required this.stocksImported,
    required this.transactionsCreated,
    this.warnings = const <String>[],
  });
}

// ============================================================================
// HASİBU ERP (SİPARİŞ -> İRSALİYE -> FATURA, BAYİ BÖLGE FİYAT, REÇETE/BOM)
// ============================================================================

@immutable
class ErpOrderWaybillInvoiceItem {
  final String id;
  final String orderDocNo; // SIP-1001
  final String? waybillDocNo; // IRS-1001 (Siparişten İrsaliyeye aktarıldığında)
  final String? invoiceDocNo; // FAT-1001 (İrsaliyeden Faturaya aktarıldığında)
  final String dateKey;
  final String accountId;
  final String accountName;
  final String regionGroup; // Örn: 'Marmara Bayi (Fiyat-2)', 'Şube Sevkiyat (Fiyat-1)'
  final int priceTier; // 1..10 Satış Fiyat Grubu
  final String stockCode;
  final String stockName;
  final double orderedQtyKg;
  final double shippedQtyKg;
  final double invoicedQtyKg;
  final int trayCount; // Tepsi Genel Toplamı
  final double unitPriceTl;
  final double discountPercent;
  final double vatPercent;
  final double collectedAmountTl; // Faturaya Karşılık Tahsilat
  final String stage; // 'SIPARIS' | 'IRSALIYE_SEVK' | 'FATURALANDI'
  final bool isOfficialVatReflected; // Resmi İşlemler / KDV Yansıtma durumu
  final String docKind; // 'NORMAL' | 'SATIS_IADE' | 'ALIS_IADE'
  final String salesRepName; // Plasiyer adı
  final double depositAmountTl; // Hesaplanan tepsi/depozito tutarı

  const ErpOrderWaybillInvoiceItem({
    required this.id,
    required this.orderDocNo,
    this.waybillDocNo,
    this.invoiceDocNo,
    required this.dateKey,
    required this.accountId,
    required this.accountName,
    this.regionGroup = 'Marmara Bayi (Fiyat-2)',
    this.priceTier = 2,
    required this.stockCode,
    required this.stockName,
    required this.orderedQtyKg,
    this.shippedQtyKg = 0.0,
    this.invoicedQtyKg = 0.0,
    this.trayCount = 1,
    required this.unitPriceTl,
    this.discountPercent = 0.0,
    this.vatPercent = 10.0,
    this.collectedAmountTl = 0.0,
    this.stage = 'SIPARIS',
    this.isOfficialVatReflected = false,
    this.docKind = 'NORMAL',
    this.salesRepName = '',
    this.depositAmountTl = 0.0,
  });

  double get activeQtyKg =>
      invoicedQtyKg > 0 ? invoicedQtyKg : (shippedQtyKg > 0 ? shippedQtyKg : orderedQtyKg);

  double get grossTotalTl => activeQtyKg * unitPriceTl;
  double get discountAmountTl => grossTotalTl * (discountPercent / 100.0);
  double get netSubTotalTl => grossTotalTl - discountAmountTl;
  double get vatAmountTl => netSubTotalTl * (vatPercent / 100.0);
  double get grandTotalTl => netSubTotalTl + vatAmountTl;
  double get unbilledQtyGapKg => orderedQtyKg - invoicedQtyKg;
  double get remainingReceivableTl =>
      (grandTotalTl - collectedAmountTl).clamp(0.0, double.infinity);

  ErpOrderWaybillInvoiceItem copyWith({
    String? id,
    String? orderDocNo,
    String? waybillDocNo,
    String? invoiceDocNo,
    String? dateKey,
    String? accountId,
    String? accountName,
    String? regionGroup,
    int? priceTier,
    String? stockCode,
    String? stockName,
    double? orderedQtyKg,
    double? shippedQtyKg,
    double? invoicedQtyKg,
    int? trayCount,
    double? unitPriceTl,
    double? discountPercent,
    double? vatPercent,
    double? collectedAmountTl,
    String? stage,
    bool? isOfficialVatReflected,
    String? docKind,
    String? salesRepName,
    double? depositAmountTl,
  }) {
    return ErpOrderWaybillInvoiceItem(
      id: id ?? this.id,
      orderDocNo: orderDocNo ?? this.orderDocNo,
      waybillDocNo: waybillDocNo ?? this.waybillDocNo,
      invoiceDocNo: invoiceDocNo ?? this.invoiceDocNo,
      dateKey: dateKey ?? this.dateKey,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      regionGroup: regionGroup ?? this.regionGroup,
      priceTier: priceTier ?? this.priceTier,
      stockCode: stockCode ?? this.stockCode,
      stockName: stockName ?? this.stockName,
      orderedQtyKg: orderedQtyKg ?? this.orderedQtyKg,
      shippedQtyKg: shippedQtyKg ?? this.shippedQtyKg,
      invoicedQtyKg: invoicedQtyKg ?? this.invoicedQtyKg,
      trayCount: trayCount ?? this.trayCount,
      unitPriceTl: unitPriceTl ?? this.unitPriceTl,
      discountPercent: discountPercent ?? this.discountPercent,
      vatPercent: vatPercent ?? this.vatPercent,
      collectedAmountTl: collectedAmountTl ?? this.collectedAmountTl,
      stage: stage ?? this.stage,
      isOfficialVatReflected:
          isOfficialVatReflected ?? this.isOfficialVatReflected,
      docKind: docKind ?? this.docKind,
      salesRepName: salesRepName ?? this.salesRepName,
      depositAmountTl: depositAmountTl ?? this.depositAmountTl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderDocNo': orderDocNo,
        'waybillDocNo': waybillDocNo,
        'invoiceDocNo': invoiceDocNo,
        'dateKey': dateKey,
        'accountId': accountId,
        'accountName': accountName,
        'regionGroup': regionGroup,
        'priceTier': priceTier,
        'stockCode': stockCode,
        'stockName': stockName,
        'orderedQtyKg': orderedQtyKg,
        'shippedQtyKg': shippedQtyKg,
        'invoicedQtyKg': invoicedQtyKg,
        'trayCount': trayCount,
        'unitPriceTl': unitPriceTl,
        'discountPercent': discountPercent,
        'vatPercent': vatPercent,
        'collectedAmountTl': collectedAmountTl,
        'stage': stage,
        'isOfficialVatReflected': isOfficialVatReflected,
        'docKind': docKind,
        'salesRepName': salesRepName,
        'depositAmountTl': depositAmountTl,
      };

  factory ErpOrderWaybillInvoiceItem.fromJson(Map<String, dynamic> json) {
    return ErpOrderWaybillInvoiceItem(
      id: (json['id'] as String?) ?? '',
      orderDocNo: (json['orderDocNo'] as String?) ?? '',
      waybillDocNo: json['waybillDocNo'] as String?,
      invoiceDocNo: json['invoiceDocNo'] as String?,
      dateKey: (json['dateKey'] as String?) ?? '',
      accountId: (json['accountId'] as String?) ?? '',
      accountName: (json['accountName'] as String?) ?? '',
      regionGroup: (json['regionGroup'] as String?) ?? 'Marmara Bayi (Fiyat-2)',
      priceTier: (json['priceTier'] as num?)?.toInt() ?? 2,
      stockCode: (json['stockCode'] as String?) ?? '',
      stockName: (json['stockName'] as String?) ?? '',
      orderedQtyKg: (json['orderedQtyKg'] as num?)?.toDouble() ?? 0.0,
      shippedQtyKg: (json['shippedQtyKg'] as num?)?.toDouble() ?? 0.0,
      invoicedQtyKg: (json['invoicedQtyKg'] as num?)?.toDouble() ?? 0.0,
      trayCount: (json['trayCount'] as num?)?.toInt() ?? 1,
      unitPriceTl: (json['unitPriceTl'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      vatPercent: (json['vatPercent'] as num?)?.toDouble() ?? 10.0,
      collectedAmountTl: (json['collectedAmountTl'] as num?)?.toDouble() ?? 0.0,
      stage: (json['stage'] as String?) ?? 'SIPARIS',
      isOfficialVatReflected:
          (json['isOfficialVatReflected'] as bool?) ?? false,
      docKind: (json['docKind'] as String?) ?? 'NORMAL',
      salesRepName: (json['salesRepName'] as String?) ?? '',
      depositAmountTl: (json['depositAmountTl'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class ProductionRecipeBom {
  final String id;
  final String recipeCode;
  final String productName;
  final String recipeCategory; // 'BAKLAVA_GENEL' | 'BUGDAY_BULGUR' | 'RESMI_RECETE'
  final double batchOutputKg; // 1 Harç / Tepsi Çıktı Kg
  final int trayYieldCount; // Çıkan Tepsi Adedi
  final String ingredientsSummary; // Örn: 'Un 18kg, Sade Yağ 9kg, Antep Fıstık 6kg, Şeker 15kg'
  final double rawMaterialCostTl;
  final double overheadCostTl;
  final double fireWastePercent; // Buğday/Bulgur veya Fırın Fire %
  final int producedBatchesToday;

  const ProductionRecipeBom({
    required this.id,
    required this.recipeCode,
    required this.productName,
    this.recipeCategory = 'BAKLAVA_GENEL',
    required this.batchOutputKg,
    this.trayYieldCount = 10,
    required this.ingredientsSummary,
    required this.rawMaterialCostTl,
    this.overheadCostTl = 450.0,
    this.fireWastePercent = 3.2,
    this.producedBatchesToday = 1,
  });

  double get totalBatchCostTl => rawMaterialCostTl + overheadCostTl;
  double get unitCostPerKgTl =>
      batchOutputKg > 0 ? totalBatchCostTl / batchOutputKg : 0.0;
  double get unitCostPerTrayTl =>
      trayYieldCount > 0 ? totalBatchCostTl / trayYieldCount : 0.0;

  ProductionRecipeBom copyWith({
    int? producedBatchesToday,
    double? rawMaterialCostTl,
    double? overheadCostTl,
    double? fireWastePercent,
  }) {
    return ProductionRecipeBom(
      id: id,
      recipeCode: recipeCode,
      productName: productName,
      recipeCategory: recipeCategory,
      batchOutputKg: batchOutputKg,
      trayYieldCount: trayYieldCount,
      ingredientsSummary: ingredientsSummary,
      rawMaterialCostTl: rawMaterialCostTl ?? this.rawMaterialCostTl,
      overheadCostTl: overheadCostTl ?? this.overheadCostTl,
      fireWastePercent: fireWastePercent ?? this.fireWastePercent,
      producedBatchesToday: producedBatchesToday ?? this.producedBatchesToday,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeCode': recipeCode,
        'productName': productName,
        'recipeCategory': recipeCategory,
        'batchOutputKg': batchOutputKg,
        'trayYieldCount': trayYieldCount,
        'ingredientsSummary': ingredientsSummary,
        'rawMaterialCostTl': rawMaterialCostTl,
        'overheadCostTl': overheadCostTl,
        'fireWastePercent': fireWastePercent,
        'producedBatchesToday': producedBatchesToday,
      };

  factory ProductionRecipeBom.fromJson(Map<String, dynamic> json) {
    return ProductionRecipeBom(
      id: (json['id'] as String?) ?? '',
      recipeCode: (json['recipeCode'] as String?) ?? '',
      productName: (json['productName'] as String?) ?? '',
      recipeCategory: (json['recipeCategory'] as String?) ?? 'BAKLAVA_GENEL',
      batchOutputKg: (json['batchOutputKg'] as num?)?.toDouble() ?? 0.0,
      trayYieldCount: (json['trayYieldCount'] as num?)?.toInt() ?? 10,
      ingredientsSummary: (json['ingredientsSummary'] as String?) ?? '',
      rawMaterialCostTl: (json['rawMaterialCostTl'] as num?)?.toDouble() ?? 0.0,
      overheadCostTl: (json['overheadCostTl'] as num?)?.toDouble() ?? 450.0,
      fireWastePercent: (json['fireWastePercent'] as num?)?.toDouble() ?? 3.2,
      producedBatchesToday: (json['producedBatchesToday'] as num?)?.toInt() ?? 1,
    );
  }
}

@immutable
class CustomSpreadsheetRecord {
  final String id;
  final String sheetTitle;
  final String categoryName;
  final String periodKey;
  final double debitColumnTl;
  final double creditColumnTl;
  final String formulaNote;

  const CustomSpreadsheetRecord({
    required this.id,
    required this.sheetTitle,
    required this.categoryName,
    required this.periodKey,
    required this.debitColumnTl,
    required this.creditColumnTl,
    this.formulaNote = '',
  });

  double get netValueTl => creditColumnTl - debitColumnTl;

  CustomSpreadsheetRecord copyWith({
    String? sheetTitle,
    String? categoryName,
    String? periodKey,
    double? debitColumnTl,
    double? creditColumnTl,
    String? formulaNote,
  }) {
    return CustomSpreadsheetRecord(
      id: id,
      sheetTitle: sheetTitle ?? this.sheetTitle,
      categoryName: categoryName ?? this.categoryName,
      periodKey: periodKey ?? this.periodKey,
      debitColumnTl: debitColumnTl ?? this.debitColumnTl,
      creditColumnTl: creditColumnTl ?? this.creditColumnTl,
      formulaNote: formulaNote ?? this.formulaNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sheetTitle': sheetTitle,
        'categoryName': categoryName,
        'periodKey': periodKey,
        'debitColumnTl': debitColumnTl,
        'creditColumnTl': creditColumnTl,
        'formulaNote': formulaNote,
      };

  factory CustomSpreadsheetRecord.fromJson(Map<String, dynamic> json) {
    return CustomSpreadsheetRecord(
      id: (json['id'] as String?) ?? '',
      sheetTitle: (json['sheetTitle'] as String?) ?? '',
      categoryName: (json['categoryName'] as String?) ?? '',
      periodKey: (json['periodKey'] as String?) ?? '',
      debitColumnTl: (json['debitColumnTl'] as num?)?.toDouble() ?? 0.0,
      creditColumnTl: (json['creditColumnTl'] as num?)?.toDouble() ?? 0.0,
      formulaNote: (json['formulaNote'] as String?) ?? '',
    );
  }
}

// ============================================================================
// HASİBU MAĞAZA POS & 360° ŞUBE DENETİM MODELLERİ
// ============================================================================

@immutable
class BranchStoreProfile {
  final int branchId;
  final String storeCode;
  final String storeName;
  final String warehouseName;
  final String cashBoxName;
  final String posBankName;
  final String storeAccountId; // Merkezdeki Şube Cari Kartı
  final String scaleComPort; // Örn: 'COM2'
  final int scaleBaudRate; // Örn: 9600
  final String scaleModel; // 'CAS ER JR-CB' veya 'Sharp Plus'
  final String handingOverCashier; // Teslim Eden
  final String receivingManager; // Teslim Alan
  final String witnessName; // Şahit
  final bool isOnlineConnected;
  final double capitalTl; // Sermaye (Magaza_FinansalRapor2)
  final double factoryDebtTl; // Fabrika Borcu

  const BranchStoreProfile({
    required this.branchId,
    required this.storeCode,
    required this.storeName,
    required this.warehouseName,
    required this.cashBoxName,
    required this.posBankName,
    required this.storeAccountId,
    this.scaleComPort = 'COM2',
    this.scaleBaudRate = 9600,
    this.scaleModel = 'CAS ER JR-CB',
    this.handingOverCashier = 'Kasiyer Vardiya-1',
    this.receivingManager = 'Mağaza Müdürü',
    this.witnessName = 'Vardiya Şahidi',
    this.isOnlineConnected = true,
    this.capitalTl = 450000.0,
    this.factoryDebtTl = 115000.0,
  });

  double get netFinancialStandingTl => capitalTl - factoryDebtTl;

  BranchStoreProfile copyWith({
    bool? isOnlineConnected,
    String? scaleComPort,
    int? scaleBaudRate,
    String? scaleModel,
    String? handingOverCashier,
    String? receivingManager,
    String? witnessName,
  }) {
    return BranchStoreProfile(
      branchId: branchId,
      storeCode: storeCode,
      storeName: storeName,
      warehouseName: warehouseName,
      cashBoxName: cashBoxName,
      posBankName: posBankName,
      storeAccountId: storeAccountId,
      scaleComPort: scaleComPort ?? this.scaleComPort,
      scaleBaudRate: scaleBaudRate ?? this.scaleBaudRate,
      scaleModel: scaleModel ?? this.scaleModel,
      handingOverCashier: handingOverCashier ?? this.handingOverCashier,
      receivingManager: receivingManager ?? this.receivingManager,
      witnessName: witnessName ?? this.witnessName,
      isOnlineConnected: isOnlineConnected ?? this.isOnlineConnected,
      capitalTl: capitalTl,
      factoryDebtTl: factoryDebtTl,
    );
  }
}

@immutable
class BranchPosQuickButton {
  final int slotIndex; // 1..144 (4 Grup x 36 Tuş)
  final int tabGroupIndex; // 1..4 (TabGrup1AD..TabGrup4AD)
  final String tabGroupName; // 'BAKLAVALAR', 'DONDURMA & SÜTLÜ', 'KUTU & TEPSİ', 'İÇECEK & YÖRESEL'
  final String stockCode;
  final String productName;
  final String unit; // 'KG' veya 'ADET'
  final double unitPriceTl;
  final bool isComplimentaryDefault; // '* Bedelsiz *' veya 'Normal Satış Fiyatı'
  final bool isBoxContainer; // Kutu / Ambalaj mı?
  final double boxGramWeightKg; // Kutu Gramaj Ağırlığı (Örn: 0.085 kg = 85 gr)
  final int colorHex; // ButtonaRenkSec

  const BranchPosQuickButton({
    required this.slotIndex,
    required this.tabGroupIndex,
    required this.tabGroupName,
    required this.stockCode,
    required this.productName,
    this.unit = 'KG',
    required this.unitPriceTl,
    this.isComplimentaryDefault = false,
    this.isBoxContainer = false,
    this.boxGramWeightKg = 0.0,
    this.colorHex = 0xFF0F766E,
  });

  BranchPosQuickButton copyWith({
    String? productName,
    double? unitPriceTl,
    bool? isComplimentaryDefault,
    int? colorHex,
  }) {
    return BranchPosQuickButton(
      slotIndex: slotIndex,
      tabGroupIndex: tabGroupIndex,
      tabGroupName: tabGroupName,
      stockCode: stockCode,
      productName: productName ?? this.productName,
      unit: unit,
      unitPriceTl: unitPriceTl ?? this.unitPriceTl,
      isComplimentaryDefault:
          isComplimentaryDefault ?? this.isComplimentaryDefault,
      isBoxContainer: isBoxContainer,
      boxGramWeightKg: boxGramWeightKg,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}

@immutable
class BranchPosCartLine {
  final String id;
  final String stockCode;
  final String productName;
  final String unit; // 'KG' | 'ADET'
  final double quantity; // Terazi tartımı (KG) veya Adet
  final double normalUnitPriceTl;
  final bool isComplimentary; // Seçili Satırı BEDELSİZ'e Çevir / BEDELLİ'ye Çevir
  final bool isBoxContainer;
  final double boxGramWeightKg;

  const BranchPosCartLine({
    required this.id,
    required this.stockCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.normalUnitPriceTl,
    this.isComplimentary = false,
    this.isBoxContainer = false,
    this.boxGramWeightKg = 0.0,
  });

  double get effectiveUnitPriceTl => isComplimentary ? 0.0 : normalUnitPriceTl;
  double get lineTotalTl => quantity * effectiveUnitPriceTl;
  double get totalBoxTareKg => isBoxContainer ? (quantity * boxGramWeightKg) : 0.0;

  BranchPosCartLine copyWith({
    double? quantity,
    bool? isComplimentary,
  }) {
    return BranchPosCartLine(
      id: id,
      stockCode: stockCode,
      productName: productName,
      unit: unit,
      quantity: quantity ?? this.quantity,
      normalUnitPriceTl: normalUnitPriceTl,
      isComplimentary: isComplimentary ?? this.isComplimentary,
      isBoxContainer: isBoxContainer,
      boxGramWeightKg: boxGramWeightKg,
    );
  }
}

enum BranchPosPaymentMethod {
  cash('NAKİT ÖDEME'),
  creditCard('KREDİ KARTI (POS)'),
  splitCashAndPos('PARÇALI ÖDEME (Nakit + POS)'),
  openAccount('AÇIK HESAP (Veresiye)'),
  refundReturn('İADE ALIM');

  final String label;
  const BranchPosPaymentMethod(this.label);

  static BranchPosPaymentMethod fromName(String? raw) {
    for (final m in BranchPosPaymentMethod.values) {
      if (m.name == raw) return m;
    }
    return BranchPosPaymentMethod.cash;
  }
}

@immutable
class BranchPosReceipt {
  final String id;
  final String receiptNo; // FIS-2026-001
  final int branchId;
  final String storeName;
  final String dateKey;
  final String timeText;
  final String cashierName;
  final String receiptType; // 'SATIŞ' veya 'İADE'
  final BranchPosPaymentMethod paymentMethod;
  final double totalAmountTl;
  final double cashAmountTl;
  final double posAmountTl;
  final double openAccountAmountTl;
  final double receivedCashTl;
  final double changeReturnedTl; // Para Üstü
  final String customerName; // Açık Hesap Kişi Adı
  final String customerPhone; // Açık Hesap Tel
  final String note;
  final double sweetWeightKg; // Tartılan Tatlı Kg
  final int boxCount; // Fişteki Kutu Adedi
  final double boxTareWeightKg; // Kutu Dara Ağırlığı (kg)
  final int complimentaryLineCount; // Bedelsiz Satır Sayısı
  final bool syncedToHeadquarters; // ONLINE / OFFLINE durumu
  final String itemsSummary;

  const BranchPosReceipt({
    required this.id,
    required this.receiptNo,
    required this.branchId,
    required this.storeName,
    required this.dateKey,
    required this.timeText,
    required this.cashierName,
    this.receiptType = 'SATIŞ',
    required this.paymentMethod,
    required this.totalAmountTl,
    this.cashAmountTl = 0.0,
    this.posAmountTl = 0.0,
    this.openAccountAmountTl = 0.0,
    this.receivedCashTl = 0.0,
    this.changeReturnedTl = 0.0,
    this.customerName = '',
    this.customerPhone = '',
    this.note = '',
    this.sweetWeightKg = 0.0,
    this.boxCount = 0,
    this.boxTareWeightKg = 0.0,
    this.complimentaryLineCount = 0,
    this.syncedToHeadquarters = true,
    required this.itemsSummary,
  });

  BranchPosReceipt copyWith({
    bool? syncedToHeadquarters,
    double? openAccountAmountTl,
    String? note,
  }) {
    return BranchPosReceipt(
      id: id,
      receiptNo: receiptNo,
      branchId: branchId,
      storeName: storeName,
      dateKey: dateKey,
      timeText: timeText,
      cashierName: cashierName,
      receiptType: receiptType,
      paymentMethod: paymentMethod,
      totalAmountTl: totalAmountTl,
      cashAmountTl: cashAmountTl,
      posAmountTl: posAmountTl,
      openAccountAmountTl: openAccountAmountTl ?? this.openAccountAmountTl,
      receivedCashTl: receivedCashTl,
      changeReturnedTl: changeReturnedTl,
      customerName: customerName,
      customerPhone: customerPhone,
      note: note ?? this.note,
      sweetWeightKg: sweetWeightKg,
      boxCount: boxCount,
      boxTareWeightKg: boxTareWeightKg,
      complimentaryLineCount: complimentaryLineCount,
      syncedToHeadquarters: syncedToHeadquarters ?? this.syncedToHeadquarters,
      itemsSummary: itemsSummary,
    );
  }
}

@immutable
class BranchSuspendedReceipt {
  final String id;
  final int branchId;
  final String suspendedAtTime;
  final String labelNote;
  final List<BranchPosCartLine> lines;

  const BranchSuspendedReceipt({
    required this.id,
    required this.branchId,
    required this.suspendedAtTime,
    required this.labelNote,
    required this.lines,
  });

  double get totalAmountTl =>
      lines.fold<double>(0.0, (sum, item) => sum + item.lineTotalTl);
}

@immutable
class BranchTransferVoucher {
  final String id;
  final String docNo; // MSVK-101
  final String dateKey;
  final int targetBranchId;
  final String targetStoreName;
  final String sourceOrderNo; // Siparişten aktarıldıysa
  final String vehiclePlate; // Plaka
  final String driverName;
  final String itemsSummary;
  final double totalKg;
  final int trayCount; // Otomatik hesaplanan Tepsi
  final int kosebentCount; // Otomatik hesaplanan Köşebent
  final double transferAmountTl; // Şube Cari Borç / Merkez Alacak Virmanı
  final String status; // 'SEVK_EDILDI' | 'SUBE_TESLIM_ALDI'

  const BranchTransferVoucher({
    required this.id,
    required this.docNo,
    required this.dateKey,
    required this.targetBranchId,
    required this.targetStoreName,
    this.sourceOrderNo = '',
    this.vehiclePlate = '34 HSB 064',
    this.driverName = 'Sevkiyat Şoförü',
    required this.itemsSummary,
    required this.totalKg,
    required this.trayCount,
    required this.kosebentCount,
    required this.transferAmountTl,
    this.status = 'SEVK_EDILDI',
  });
}

@immutable
class BranchLocalPurchase {
  final String id;
  final String docNo; // MALM-101
  final String dateKey;
  final int branchId;
  final String storeName;
  final String supplierName;
  final String stockName;
  final double quantity;
  final double totalAmountTl;
  final String paymentMethod; // 'Şube Nakit Kasa' veya 'Merkez Cari'

  const BranchLocalPurchase({
    required this.id,
    required this.docNo,
    required this.dateKey,
    required this.branchId,
    required this.storeName,
    required this.supplierName,
    required this.stockName,
    required this.quantity,
    required this.totalAmountTl,
    this.paymentMethod = 'Şube Nakit Kasa',
  });
}

@immutable
class BranchEndOfDaySettlement {
  final String id;
  final String docNo; // GSN-2026-001
  final String dateKey;
  final int branchId;
  final String storeName;
  final int receiptCount;
  final double systemCashTl; // Sistem Nakit
  final double systemPosTl; // Sistem POS
  final double openAccountSalesTl; // Açık Hesap Satış
  final double openAccountCollectionsTl; // Açık Hesap Tahsilatları
  final double refundsTl; // İadeler
  final double localPurchasesTl; // Mal Alımı
  final double branchExpensesTl; // Şube Giderleri
  final double actualCountedCashTl; // Fiili Teslim Edilen Nakit
  final double coinCashTl; // Bozuk Para (Tutanak)
  final double actualPosZReportTl; // Fiili POS Z Raporu
  final double boxTareRecoveredKg; // Kutu Dara Tatlı Stoğuna Eklenen Kg
  final double boxPriceDiffProfitTl; // Kutu Fiyat Farkı (Kâr/Zarar TL)
  final String handedOverBy; // Teslim Eden
  final String receivedBy; // Teslim Alan
  final String witnessName; // Şahit
  final bool transferredToHq; // Merkeze Aktarıldı mı?

  const BranchEndOfDaySettlement({
    required this.id,
    required this.docNo,
    required this.dateKey,
    required this.branchId,
    required this.storeName,
    required this.receiptCount,
    required this.systemCashTl,
    required this.systemPosTl,
    this.openAccountSalesTl = 0.0,
    this.openAccountCollectionsTl = 0.0,
    this.refundsTl = 0.0,
    this.localPurchasesTl = 0.0,
    this.branchExpensesTl = 0.0,
    required this.actualCountedCashTl,
    this.coinCashTl = 0.0,
    required this.actualPosZReportTl,
    this.boxTareRecoveredKg = 0.0,
    this.boxPriceDiffProfitTl = 0.0,
    required this.handedOverBy,
    required this.receivedBy,
    required this.witnessName,
    this.transferredToHq = true,
  });

  double get expectedDrawerCashTl =>
      systemCashTl + openAccountCollectionsTl - refundsTl - localPurchasesTl - branchExpensesTl;
  double get totalActualCashTl => actualCountedCashTl + coinCashTl;
  double get cashVarianceTl => totalActualCashTl - expectedDrawerCashTl; // Nakit Farkı
  double get posVarianceTl => actualPosZReportTl - systemPosTl; // POS Farkı
  double get totalTurnoverVarianceTl => cashVarianceTl + posVarianceTl; // Ciro Farkı
  double get netTurnoverTl =>
      systemCashTl + systemPosTl + openAccountSalesTl - refundsTl;
}

@immutable
class BranchStockCountEntry {
  final String id;
  final String dateKey;
  final int branchId;
  final String storeName;
  final String stockCode;
  final String stockName;
  final String stockGroup; // 'TEPSİLİ TATLILAR' | 'MALZEME' | 'KUTULAR' | 'DONDURMA'
  final String unit;
  final double systemQty; // Canlı Stok
  final double countedQty; // Fiili Sayım
  final double unitCostTl;
  final bool expensedAsConsumable; // Malzeme farkı Sarf Malzeme Giderlerine işlendi mi?

  const BranchStockCountEntry({
    required this.id,
    required this.dateKey,
    required this.branchId,
    required this.storeName,
    required this.stockCode,
    required this.stockName,
    required this.stockGroup,
    this.unit = 'KG',
    required this.systemQty,
    required this.countedQty,
    required this.unitCostTl,
    this.expensedAsConsumable = false,
  });

  double get diffQty => countedQty - systemQty;
  double get diffCostAmountTl => diffQty.abs() * unitCostTl;
}

@immutable
class BranchAuditInspectionRecord {
  final String id;
  final String auditDocNo; // DNT-2026-001
  final String dateKey;
  final int branchId;
  final String storeName;
  final String inspectorName;
  // 1. Kasiyer İptal / İade / Bedelsiz Suistimal Radarı
  final int cancelledOrRefundCount;
  final int complimentaryItemCount;
  final double cashierRiskScore; // 0..100 (Düşük = Güvenli)
  // 2. Tepsi - Gramaj - Kutu Dara 3'lü Fire Mutabakatı
  final double shippedTrayTotalKg;
  final double posSoldPlusRemainingKg;
  final double boxTareOffsetKg;
  final double unaccountedFireKg; // Açıklanamayan Tepsi/Gramaj Fire Farkı
  // 3. Kör Kasa & Kör Stok Sayım Sapması
  final double blindCashVarianceTl;
  final double blindStockVarianceTl;
  // 4. PDKS x POS Vardiya Çapraz Doğrulama (Hayalet Kasiyer Kalkanı)
  final int pdksCheckedInStaffCount;
  final int posActiveCashierCount;
  final bool ghostCashierDetected; // PDKS girişi olmadan POS fişi kesildi mi?
  // 5. Soğuk Zincir, Tezgah Tazelik & Hijyen Denetimi
  final double coldChainTempCelsius; // Dondurma/Sütlü dolap °C (Örn: -18.5°C veya +4.0°C)
  final int hygieneChecklistScore; // 0..100
  final String findingSummary;
  final String actionPlan;

  const BranchAuditInspectionRecord({
    required this.id,
    required this.auditDocNo,
    required this.dateKey,
    required this.branchId,
    required this.storeName,
    required this.inspectorName,
    required this.cancelledOrRefundCount,
    required this.complimentaryItemCount,
    required this.cashierRiskScore,
    required this.shippedTrayTotalKg,
    required this.posSoldPlusRemainingKg,
    required this.boxTareOffsetKg,
    required this.unaccountedFireKg,
    required this.blindCashVarianceTl,
    required this.blindStockVarianceTl,
    required this.pdksCheckedInStaffCount,
    required this.posActiveCashierCount,
    required this.ghostCashierDetected,
    required this.coldChainTempCelsius,
    required this.hygieneChecklistScore,
    required this.findingSummary,
    required this.actionPlan,
  });

  /// 100 Puanlık 360° Şube Denetim Karnesi
  int get overallAuditScore {
    double score = 100.0;
    if (ghostCashierDetected) score -= 25.0;
    if (unaccountedFireKg.abs() > 1.5) score -= 15.0;
    if (blindCashVarianceTl.abs() > 250.0) score -= 15.0;
    if (blindStockVarianceTl.abs() > 500.0) score -= 10.0;
    if (cashierRiskScore > 30.0) score -= 15.0;
    if (hygieneChecklistScore < 85) score -= (85 - hygieneChecklistScore) * 0.5;
    return score.clamp(0.0, 100.0).round();
  }

  String get auditGradeBadge {
    final s = overallAuditScore;
    if (s >= 90) return 'A+ TAM MUTABAKAT';
    if (s >= 75) return 'B DÜŞÜK RİSK';
    if (s >= 60) return 'C İZLEME GEREKLİ';
    return 'D KRİTİK DENETİM UYARISI';
  }
}

