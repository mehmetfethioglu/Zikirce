import '../../../../core/services/hasibu_print_service.dart';
import 'pdks_models.dart';

/// PDKS, Personel Kartı, Özlük Dosyası, İzin ve Devamsızlık raporları için
/// A4 HTML ve düz metin çıktı üreticileri.
class HasibuPrintBuilders {
  HasibuPrintBuilders._();

  static String _formatTimestamp(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString().padLeft(4, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  static String _formatDisplayDateOrDash(String? dateKey) {
    if (dateKey == null || dateKey.trim().isEmpty) return '-';
    final parsed = Employee.parseDateKey(dateKey);
    if (parsed == null) return dateKey.trim();
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final yyyy = parsed.year.toString().padLeft(4, '0');
    return '$dd.$mm.$yyyy';
  }

  static String _safeLogoDataUri(String? rawBase64) {
    if (rawBase64 == null) return '';
    final cleaned = rawBase64.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return '';
    if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleaned)) return '';
    return 'data:image/png;base64,$cleaned';
  }

  static String _wrapA4HtmlDocument({
    required CompanySettings companySettings,
    required String documentTitle,
    required String subtitle,
    required String bodyHtml,
    required bool landscape,
    required DateTime printedAt,
  }) {
    final safeCompany = escapeHtml(
      companySettings.companyName.trim().isEmpty
          ? 'Hasibu Kurumsal PDKS'
          : companySettings.companyName.trim(),
    );
    final safeTitle = escapeHtml(documentTitle);
    final safeSubtitle = escapeHtml(subtitle);
    final safeStamp = escapeHtml(_formatTimestamp(printedAt));
    final logoUri = _safeLogoDataUri(companySettings.logoDataBase64);
    final logoHtml = logoUri.isEmpty
        ? ''
        : '<img src="$logoUri" alt="Logo" style="height:40px;width:40px;object-fit:contain;border-radius:8px;border:1px solid #cbd5e1;background:#fff;padding:2px;" />';

    return '''<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>$safeTitle — $safeCompany</title>
<style>
  @page { size: A4 ${landscape ? 'landscape' : 'portrait'}; margin: 11mm; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 0;
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Arial, sans-serif;
    color: #0f172a;
    background: #ffffff;
    font-size: 11.5px;
    line-height: 1.42;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 16px;
    background: #0f172a;
    color: #f8fafc;
    margin-bottom: 12px;
  }
  .toolbar button {
    background: #0284c7;
    color: #ffffff;
    border: 0;
    border-radius: 6px;
    padding: 7px 14px;
    font-weight: 700;
    font-size: 12px;
    cursor: pointer;
  }
  .page-wrap { padding: 4px 8px 16px; }
  .doc-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    padding-bottom: 10px;
    margin-bottom: 12px;
    border-bottom: 2px solid #0f172a;
  }
  .brand-row { display: flex; align-items: center; gap: 10px; }
  .company-name { font-size: 12px; font-weight: 700; color: #0284c7; text-transform: uppercase; letter-spacing: 0.4px; }
  .doc-title { font-size: 17px; font-weight: 800; color: #0f172a; margin: 2px 0; }
  .doc-subtitle { font-size: 11px; color: #475569; }
  .doc-meta { text-align: right; font-size: 10.5px; color: #475569; white-space: nowrap; }
  .kpi-row {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 12px;
  }
  .kpi-box {
    flex: 1 1 110px;
    border: 1px solid #cbd5e1;
    border-radius: 6px;
    padding: 7px 9px;
    background: #f8fafc;
  }
  .kpi-val { font-size: 14px; font-weight: 800; color: #0f172a; }
  .kpi-lbl { font-size: 10px; font-weight: 600; color: #475569; }
  .section-title {
    font-size: 12.5px;
    font-weight: 800;
    color: #0f172a;
    margin: 12px 0 6px;
    padding-left: 7px;
    border-left: 3px solid #0284c7;
  }
  .info-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 6px 10px;
    padding: 9px;
    border: 1px solid #cbd5e1;
    border-radius: 6px;
    background: #f8fafc;
    margin-bottom: 10px;
  }
  .info-item .lbl { font-size: 9.5px; color: #64748b; font-weight: 700; text-transform: uppercase; }
  .info-item .val { font-size: 11.5px; font-weight: 700; color: #0f172a; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
  thead { display: table-header-group; }
  tr { break-inside: avoid; }
  th, td {
    border: 1px solid #cbd5e1;
    padding: 5px 6px;
    text-align: left;
    vertical-align: top;
    font-size: 10.5px;
  }
  th { background: #f1f5f9; font-weight: 800; color: #0f172a; }
  tbody tr:nth-child(even) { background: #f8fafc; }
  .badge {
    display: inline-block;
    padding: 1px 6px;
    border-radius: 4px;
    font-weight: 700;
    font-size: 9.5px;
    border: 1px solid #cbd5e1;
    background: #f1f5f9;
  }
  .signatures {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 18px;
    margin-top: 22px;
    break-inside: avoid;
  }
  .sig-box {
    border-top: 1px solid #64748b;
    padding-top: 5px;
    text-align: center;
    font-size: 10.5px;
    color: #334155;
    font-weight: 600;
  }
  .empty-note {
    padding: 10px;
    border: 1px dashed #cbd5e1;
    border-radius: 6px;
    color: #64748b;
    font-style: italic;
  }
  @media print {
    .no-print { display: none !important; }
    .page-wrap { padding: 0; }
  }
</style>
</head>
<body>
  <div class="toolbar no-print">
    <span><strong>$safeCompany</strong> • Yazdırmaya Hazır A4 Belge</span>
    <button type="button" onclick="window.print()">Yazdır / PDF Kaydet</button>
  </div>
  <div class="page-wrap">
    <div class="doc-header">
      <div class="brand-row">
        $logoHtml
        <div>
          <div class="company-name">$safeCompany</div>
          <div class="doc-title">$safeTitle</div>
          <div class="doc-subtitle">$safeSubtitle</div>
        </div>
      </div>
      <div class="doc-meta">
        <div><strong>Yazdırma Tarihi:</strong> $safeStamp</div>
        <div>Hasibu Kurumsal PDKS</div>
      </div>
    </div>
    $bodyHtml
    <div class="signatures">
      <div class="sig-box">Hazırlayan / İnsan Kaynakları</div>
      <div class="sig-box">Kontrol / Birim Amiri</div>
      <div class="sig-box">Onay / Yönetici</div>
    </div>
  </div>
</body>
</html>''';
  }

  /// 1. Tekil Personel Bilgi, Özlük & Devam Kartı Çıktısı (A4 Dikey).
  static PrintableDocument buildEmployeeCardDocument({
    required CompanySettings companySettings,
    required EmployeeDailyStatus status,
    required String selectedDateKey,
    required List<PersonnelDocument> documents,
    required List<EmployeeHistoryDayEntry> historyEntries,
    DateTime? printedAt,
  }) {
    final now = printedAt ?? DateTime.now();
    final emp = status.employee;
    final employmentLabel = emp.isSeparatedNow
        ? 'İşten Ayrıldı (${_formatDisplayDateOrDash(emp.normalizedExitDate)})'
        : (emp.hasExitDate
            ? 'Çıkış Planlı (${_formatDisplayDateOrDash(emp.normalizedExitDate)})'
            : 'Aktif Çalışan');

    final uploadedCats = documents.map((d) => d.category).toSet();
    final missingMandatory = PersonnelDocumentCategory.values
        .where((c) => c.isMandatory && !uploadedCats.contains(c))
        .toList(growable: false);

    final checkInText = status.firstCheckIn?.timeFormatted ?? '-';
    final checkOutText = (status.lastCheckOut != null &&
            status.lastCheckOut!.id != status.firstCheckIn?.id)
        ? status.lastCheckOut!.timeFormatted
        : (status.hasMissingCheckOut ? 'Çıkış Eksik' : '-');

    final modulesText = emp.allowedModules.map((m) => m.title).join(', ');
    final historySlice = historyEntries.take(31).toList(growable: false);

    final bodyBuf = StringBuffer()
      ..writeln('<div class="section-title">Kimlik ve İstihdam Bilgileri</div>')
      ..writeln('<div class="info-grid">')
      ..writeln(_infoCell('Ad Soyad', emp.fullName))
      ..writeln(_infoCell('Sicil / Kart No', '#${emp.cardNo}'))
      ..writeln(_infoCell('Unvan / Görev', emp.title))
      ..writeln(_infoCell('Şube', status.branch.name))
      ..writeln(_infoCell('Bölüm / Departman', status.department.name))
      ..writeln(
        _infoCell(
          'Vardiya',
          '${status.shift.name} (${status.shift.startTime}-${status.shift.endTime})',
        ),
      )
      ..writeln(_infoCell('İşe Giriş Tarihi', _formatDisplayDateOrDash(emp.hireDate)))
      ..writeln(_infoCell('Çalışma Durumu', employmentLabel))
      ..writeln(_infoCell('Kıdem Süresi', emp.tenureSummaryAt()))
      ..writeln(_infoCell('SGK Durumu', emp.sgkActive ? 'Aktif' : 'Pasif'))
      ..writeln(_infoCell('KPI Skoru', '%${emp.kpiScore.toStringAsFixed(0)}'))
      ..writeln(_infoCell('Yetkili Modüller', modulesText))
      ..writeln('</div>')
      ..writeln('<div class="section-title">Yıllık İzin ve Seçili Gün Yoklama Özeti (${escapeHtml(_formatDisplayDateOrDash(selectedDateKey))})</div>')
      ..writeln('<div class="kpi-row">')
      ..writeln(_kpiBox('${emp.annualLeaveEntitlement} Gün', 'Yıllık İzin Hakkı'))
      ..writeln(_kpiBox('${emp.usedAnnualLeave} Gün', 'Kullanılan İzin'))
      ..writeln(_kpiBox('${emp.remainingAnnualLeave} Gün', 'Kalan İzin'))
      ..writeln(_kpiBox(status.state.label, 'Günlük Durum'))
      ..writeln(_kpiBox('$checkInText / $checkOutText', 'Giriş / Çıkış'))
      ..writeln(_kpiBox(status.workedDurationFormatted, 'Net Süre (Gecikme: ${status.lateMinutes} dk • Mesai: +${status.overtimeMinutes} dk)'))
      ..writeln('</div>')
      ..writeln('<div class="section-title">Dijital Özlük Dosyası ve Evrak Kontrolü (${documents.length} Yüklü • ${missingMandatory.length} Eksik Zorunlu)</div>');

    if (documents.isEmpty) {
      bodyBuf.writeln('<div class="empty-note">Kayıtlı dijital özlük evrakı bulunmuyor.</div>');
    } else {
      bodyBuf.writeln('<table><thead><tr><th>#</th><th>Kategori</th><th>Evrak Başlığı</th><th>Tarih</th><th>Not</th></tr></thead><tbody>');
      for (int i = 0; i < documents.length; i++) {
        final d = documents[i];
        bodyBuf.writeln(
          '<tr><td>${i + 1}</td>'
          '<td>${escapeHtml(d.category.label)}</td>'
          '<td>${escapeHtml(d.title)}</td>'
          '<td>${escapeHtml(_formatDisplayDateOrDash(d.uploadDate))}</td>'
          '<td>${escapeHtml(d.notes.isEmpty ? "-" : d.notes)}</td></tr>',
        );
      }
      bodyBuf.writeln('</tbody></table>');
    }

    if (missingMandatory.isNotEmpty) {
      final missingStr = missingMandatory.map((m) => m.label).join(', ');
      bodyBuf.writeln(
        '<p><strong>Eksik Zorunlu Evraklar:</strong> ${escapeHtml(missingStr)}</p>',
      );
    }

    bodyBuf.writeln('<div class="section-title">Son Giriş-Çıkış ve Puantaj Geçmişi (${historySlice.length} Gün)</div>');
    if (historySlice.isEmpty) {
      bodyBuf.writeln('<div class="empty-note">Geçmiş yoklama kaydı bulunmuyor.</div>');
    } else {
      bodyBuf.writeln('<table><thead><tr><th>Tarih</th><th>İlk Giriş</th><th>Son Çıkış</th><th>Net Süre</th><th>Gecikme</th><th>Mesai</th><th>Durum</th></tr></thead><tbody>');
      for (final h in historySlice) {
        final inStr = h.firstCheckIn?.timeFormatted ?? '-';
        final outStr = (h.lastCheckOut != null && h.lastCheckOut!.id != h.firstCheckIn?.id)
            ? h.lastCheckOut!.timeFormatted
            : '-';
        bodyBuf.writeln(
          '<tr><td>${escapeHtml(_formatDisplayDateOrDash(h.dateKey))}</td>'
          '<td>${escapeHtml(inStr)}</td>'
          '<td>${escapeHtml(outStr)}</td>'
          '<td>${escapeHtml(h.workedDurationFormatted)}</td>'
          '<td>${h.lateMinutes} dk</td>'
          '<td>+${h.overtimeMinutes} dk</td>'
          '<td><span class="badge">${escapeHtml(h.state.label)}</span></td></tr>',
        );
      }
      bodyBuf.writeln('</tbody></table>');
    }

    final textBuf = StringBuffer()
      ..writeln('${companySettings.companyName} — PERSONEL BİLGİ & ÖZLÜK KARTI')
      ..writeln('Yazdırma Tarihi: ${_formatTimestamp(now)}')
      ..writeln('------------------------------------------------------------')
      ..writeln('Ad Soyad       : ${emp.fullName} (#${emp.cardNo})')
      ..writeln('Unvan / Bölüm  : ${emp.title} • ${status.branch.name} / ${status.department.name}')
      ..writeln('Vardiya        : ${status.shift.name} (${status.shift.startTime}-${status.shift.endTime})')
      ..writeln('İşe Giriş      : ${_formatDisplayDateOrDash(emp.hireDate)} • Kıdem: ${emp.tenureSummaryAt()}')
      ..writeln('Durum / SGK    : $employmentLabel • SGK ${emp.sgkActive ? "Aktif" : "Pasif"}')
      ..writeln('Yıllık İzin    : Hak ${emp.annualLeaveEntitlement}g | Kullanılan ${emp.usedAnnualLeave}g | Kalan ${emp.remainingAnnualLeave}g')
      ..writeln('Seçili Tarih   : ${_formatDisplayDateOrDash(selectedDateKey)} • ${status.state.label} • Giriş: $checkInText / Çıkış: $checkOutText')
      ..writeln('')
      ..writeln('ÖZLÜK EVRAKLARI (${documents.length} Yüklü, ${missingMandatory.length} Eksik Zorunlu):');
    for (final d in documents) {
      textBuf.writeln('  • [${d.category.label}] ${d.title} (${_formatDisplayDateOrDash(d.uploadDate)})');
    }
    if (missingMandatory.isNotEmpty) {
      textBuf.writeln('  ! Eksik Zorunlular: ${missingMandatory.map((m) => m.label).join(", ")}');
    }
    textBuf
      ..writeln('')
      ..writeln('SON YOKLAMA GEÇMİŞİ (${historySlice.length} Gün):');
    for (final h in historySlice) {
      final inStr = h.firstCheckIn?.timeFormatted ?? '-';
      final outStr = (h.lastCheckOut != null && h.lastCheckOut!.id != h.firstCheckIn?.id)
          ? h.lastCheckOut!.timeFormatted
          : '-';
      textBuf.writeln(
        '  ${_formatDisplayDateOrDash(h.dateKey)} | Giriş: $inStr | Çıkış: $outStr | Net: ${h.workedDurationFormatted} | ${h.state.label}',
      );
    }

    return PrintableDocument(
      jobName: 'Personel_Karti_${emp.cardNo}_${emp.fullName}',
      title: 'Personel Bilgi ve Özlük Kartı — ${emp.fullName}',
      subtitle: 'Sicil #${emp.cardNo} • ${status.branch.name} • ${status.department.name}',
      htmlContent: _wrapA4HtmlDocument(
        companySettings: companySettings,
        documentTitle: 'Personel Bilgi ve Özlük Kartı',
        subtitle: '${emp.fullName} (#${emp.cardNo}) • ${status.branch.name} / ${status.department.name}',
        bodyHtml: bodyBuf.toString(),
        landscape: false,
        printedAt: now,
      ),
      plainTextSummary: textBuf.toString(),
      landscape: false,
    );
  }

  /// 2. Personel Kadro Listesi Çıktısı (A4 Yatay).
  static PrintableDocument buildEmployeeDirectoryListDocument({
    required CompanySettings companySettings,
    required List<EmployeeDailyStatus> items,
    required Map<int, int> documentCountsByEmployeeId,
    required String filterDescription,
    DateTime? printedAt,
  }) {
    final now = printedAt ?? DateTime.now();
    final activeCount = items.where((s) => !s.employee.isSeparatedNow).length;
    final separatedCount = items.length - activeCount;
    final sgkActiveCount = items.where((s) => s.employee.sgkActive).length;

    final bodyBuf = StringBuffer()
      ..writeln('<div class="kpi-row">')
      ..writeln(_kpiBox('${items.length}', 'Listelenen Personel'))
      ..writeln(_kpiBox('$activeCount', 'Aktif Personel'))
      ..writeln(_kpiBox('$separatedCount', 'İşten Ayrılan'))
      ..writeln(_kpiBox('$sgkActiveCount', 'SGK Aktif'))
      ..writeln('</div>');

    if (items.isEmpty) {
      bodyBuf.writeln('<div class="empty-note">Seçili filtreye uygun personel bulunamadı.</div>');
    } else {
      bodyBuf.writeln(
        '<table><thead><tr>'
        '<th>#</th><th>Kart No</th><th>Ad Soyad</th><th>Şube</th><th>Bölüm</th>'
        '<th>Unvan</th><th>Vardiya</th><th>İşe Giriş</th><th>Kıdem</th>'
        '<th>Kalan İzin</th><th>Evrak</th><th>Durum</th>'
        '</tr></thead><tbody>',
      );
      for (int i = 0; i < items.length; i++) {
        final s = items[i];
        final e = s.employee;
        final docCount = documentCountsByEmployeeId[e.id] ?? 0;
        final statusTxt = e.isSeparatedNow
            ? 'İşten Ayrıldı'
            : (e.hasExitDate ? 'Çıkış Planlı' : 'Aktif');
        bodyBuf.writeln(
          '<tr>'
          '<td>${i + 1}</td>'
          '<td>${escapeHtml(e.cardNo)}</td>'
          '<td><strong>${escapeHtml(e.fullName)}</strong></td>'
          '<td>${escapeHtml(s.branch.name)}</td>'
          '<td>${escapeHtml(s.department.name)}</td>'
          '<td>${escapeHtml(e.title)}</td>'
          '<td>${escapeHtml(s.shift.name)}</td>'
          '<td>${escapeHtml(_formatDisplayDateOrDash(e.hireDate))}</td>'
          '<td>${escapeHtml(e.tenureSummaryAt())}</td>'
          '<td>${e.remainingAnnualLeave} Gün</td>'
          '<td>$docCount</td>'
          '<td><span class="badge">${escapeHtml(statusTxt)}</span></td>'
          '</tr>',
        );
      }
      bodyBuf.writeln('</tbody></table>');
    }

    final textBuf = StringBuffer()
      ..writeln('${companySettings.companyName} — PERSONEL KADRO LİSTESİ')
      ..writeln('Filtre: $filterDescription • Tarih: ${_formatTimestamp(now)}')
      ..writeln('Toplam: ${items.length} | Aktif: $activeCount | Ayrılan: $separatedCount | SGK Aktif: $sgkActiveCount')
      ..writeln('------------------------------------------------------------');
    for (int i = 0; i < items.length; i++) {
      final s = items[i];
      final e = s.employee;
      final docCount = documentCountsByEmployeeId[e.id] ?? 0;
      textBuf.writeln(
        '${i + 1}. #${e.cardNo} ${e.fullName} | ${s.branch.name}/${s.department.name} | ${e.title} | İzin: ${e.remainingAnnualLeave}g | Evrak: $docCount',
      );
    }

    return PrintableDocument(
      jobName: 'Personel_Listesi',
      title: 'Personel Kadro ve Özlük Özeti Listesi',
      subtitle: filterDescription,
      htmlContent: _wrapA4HtmlDocument(
        companySettings: companySettings,
        documentTitle: 'Personel Kadro Listesi',
        subtitle: filterDescription,
        bodyHtml: bodyBuf.toString(),
        landscape: true,
        printedAt: now,
      ),
      plainTextSummary: textBuf.toString(),
      landscape: true,
    );
  }

  /// 3. Canlı Yoklama Günlük Çizelge Çıktısı (A4 Yatay).
  static PrintableDocument buildLiveAttendanceListDocument({
    required CompanySettings companySettings,
    required String selectedDateKey,
    required String filterDescription,
    required List<EmployeeDailyStatus> items,
    required int totalCount,
    required int presentCount,
    required int lateCount,
    required int absentCount,
    required int onLeaveCount,
    required int sickReportCount,
    DateTime? printedAt,
  }) {
    final now = printedAt ?? DateTime.now();
    final dateDisplay = _formatDisplayDateOrDash(selectedDateKey);

    final bodyBuf = StringBuffer()
      ..writeln('<div class="kpi-row">')
      ..writeln(_kpiBox('$totalCount', 'Toplam Kadro'))
      ..writeln(_kpiBox('$presentCount', 'Giriş Yapan'))
      ..writeln(_kpiBox('$lateCount', 'Geç Gelen'))
      ..writeln(_kpiBox('$absentCount', 'Devamsız'))
      ..writeln(_kpiBox('$onLeaveCount', 'İzinli'))
      ..writeln(_kpiBox('$sickReportCount', 'Raporlu'))
      ..writeln('</div>');

    if (items.isEmpty) {
      bodyBuf.writeln('<div class="empty-note">Seçili filtreye uygun yoklama kaydı bulunamadı.</div>');
    } else {
      bodyBuf.writeln(
        '<table><thead><tr>'
        '<th>#</th><th>Kart No</th><th>Ad Soyad</th><th>Şube</th><th>Bölüm</th>'
        '<th>Vardiya</th><th>İlk Giriş</th><th>Son Çıkış</th><th>Net Süre</th>'
        '<th>Gecikme</th><th>Mesai</th><th>Durum</th>'
        '</tr></thead><tbody>',
      );
      for (int i = 0; i < items.length; i++) {
        final s = items[i];
        final inStr = s.firstCheckIn?.timeFormatted ?? '-';
        final outStr = (s.lastCheckOut != null && s.lastCheckOut!.id != s.firstCheckIn?.id)
            ? s.lastCheckOut!.timeFormatted
            : (s.hasMissingCheckOut ? 'Eksik' : '-');
        bodyBuf.writeln(
          '<tr>'
          '<td>${i + 1}</td>'
          '<td>${escapeHtml(s.employee.cardNo)}</td>'
          '<td><strong>${escapeHtml(s.employee.fullName)}</strong></td>'
          '<td>${escapeHtml(s.branch.name)}</td>'
          '<td>${escapeHtml(s.department.name)}</td>'
          '<td>${escapeHtml(s.shift.startTime)}-${escapeHtml(s.shift.endTime)}</td>'
          '<td>${escapeHtml(inStr)}</td>'
          '<td>${escapeHtml(outStr)}</td>'
          '<td>${escapeHtml(s.workedDurationFormatted)}</td>'
          '<td>${s.lateMinutes} dk</td>'
          '<td>+${s.overtimeMinutes} dk</td>'
          '<td><span class="badge">${escapeHtml(s.state.label)}</span></td>'
          '</tr>',
        );
      }
      bodyBuf.writeln('</tbody></table>');
    }

    final textBuf = StringBuffer()
      ..writeln('${companySettings.companyName} — CANLI YOKLAMA ÇİZELGESİ ($dateDisplay)')
      ..writeln('Filtre: $filterDescription • Listelenen: ${items.length} kişi')
      ..writeln('Kadro: $totalCount | Giriş: $presentCount | Geç: $lateCount | Devamsız: $absentCount | İzinli: $onLeaveCount | Raporlu: $sickReportCount')
      ..writeln('------------------------------------------------------------');
    for (int i = 0; i < items.length; i++) {
      final s = items[i];
      final inStr = s.firstCheckIn?.timeFormatted ?? '-';
      final outStr = (s.lastCheckOut != null && s.lastCheckOut!.id != s.firstCheckIn?.id)
          ? s.lastCheckOut!.timeFormatted
          : '-';
      textBuf.writeln(
        '${i + 1}. #${s.employee.cardNo} ${s.employee.fullName} | ${s.department.name} | Giriş: $inStr | Çıkış: $outStr | Net: ${s.workedDurationFormatted} | ${s.state.label}',
      );
    }

    return PrintableDocument(
      jobName: 'Canli_Yoklama_$selectedDateKey',
      title: 'Canlı Yoklama Çizelgesi ($dateDisplay)',
      subtitle: '$filterDescription • ${items.length} personel',
      htmlContent: _wrapA4HtmlDocument(
        companySettings: companySettings,
        documentTitle: 'Canlı Yoklama Çizelgesi ($dateDisplay)',
        subtitle: '$filterDescription • ${items.length} personel',
        bodyHtml: bodyBuf.toString(),
        landscape: true,
        printedAt: now,
      ),
      plainTextSummary: textBuf.toString(),
      landscape: true,
    );
  }

  /// 4. Çok Günlü Devam / Devamsızlık Raporu Çıktısı (A4 Yatay).
  static PrintableDocument buildAttendancePeriodReportDocument({
    required CompanySettings companySettings,
    required String startDateKey,
    required String endDateKey,
    required String filterDescription,
    required List<EmployeeAttendancePeriodSummary> rows,
    DateTime? printedAt,
  }) {
    final now = printedAt ?? DateTime.now();
    final rangeDisplay =
        '${_formatDisplayDateOrDash(startDateKey)} – ${_formatDisplayDateOrDash(endDateKey)}';
    final totalPresent = rows.fold<int>(0, (s, r) => s + r.presentDays);
    final totalAbsent = rows.fold<int>(0, (s, r) => s + r.absentDays);
    final totalLateDays = rows.fold<int>(0, (s, r) => s + r.lateDays);
    final totalLateMins = rows.fold<int>(0, (s, r) => s + r.totalLateMinutes);
    final totalLeaveSick =
        rows.fold<int>(0, (s, r) => s + r.onLeaveDays + r.sickReportDays);
    final totalMissingOut =
        rows.fold<int>(0, (s, r) => s + r.missingCheckOutDays);

    final bodyBuf = StringBuffer()
      ..writeln('<div class="kpi-row">')
      ..writeln(_kpiBox('${rows.length}', 'Personel'))
      ..writeln(_kpiBox('$totalPresent gün', 'Toplam Devam'))
      ..writeln(_kpiBox('$totalAbsent gün', 'Devamsızlık'))
      ..writeln(_kpiBox('$totalLateDays gün ($totalLateMins dk)', 'Geç Kalma'))
      ..writeln(_kpiBox('$totalLeaveSick gün', 'İzin / Rapor'))
      ..writeln(_kpiBox('$totalMissingOut gün', 'Eksik Çıkış'))
      ..writeln('</div>');

    if (rows.isEmpty) {
      bodyBuf.writeln('<div class="empty-note">Seçili kriterlere uygun rapor kaydı bulunamadı.</div>');
    } else {
      bodyBuf.writeln(
        '<table><thead><tr>'
        '<th>#</th><th>Kart No</th><th>Ad Soyad</th><th>Şube</th><th>Bölüm</th>'
        '<th>Devam</th><th>Zamanında</th><th>Geç (G/dk)</th><th>Devamsız</th>'
        '<th>İzin/Rapor</th><th>Eksik Çıkış</th><th>Oran</th><th>Devamsızlık Tarihleri</th>'
        '</tr></thead><tbody>',
      );
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        final absentDates = r.absentDateKeys.isEmpty
            ? '-'
            : r.absentDateKeys.map(_formatDisplayDateOrDash).join(', ');
        bodyBuf.writeln(
          '<tr>'
          '<td>${i + 1}</td>'
          '<td>${escapeHtml(r.employee.cardNo)}</td>'
          '<td><strong>${escapeHtml(r.employee.fullName)}</strong></td>'
          '<td>${escapeHtml(r.branch.name)}</td>'
          '<td>${escapeHtml(r.department.name)}</td>'
          '<td>${r.presentDays}/${r.totalDays}</td>'
          '<td>${r.onTimeDays}</td>'
          '<td>${r.lateDays}g / ${r.totalLateMinutes}dk</td>'
          '<td>${r.absentDays}</td>'
          '<td>${r.onLeaveDays + r.sickReportDays}</td>'
          '<td>${r.missingCheckOutDays}</td>'
          '<td>%${r.attendanceRatePercent.toStringAsFixed(0)}</td>'
          '<td>${escapeHtml(absentDates)}</td>'
          '</tr>',
        );
      }
      bodyBuf.writeln('</tbody></table>');
    }

    final textBuf = StringBuffer()
      ..writeln('${companySettings.companyName} — DEVAM / DEVAMSIZLIK RAPORU')
      ..writeln('Dönem: $rangeDisplay • Filtre: $filterDescription')
      ..writeln('Personel: ${rows.length} | Devam: $totalPresent g | Devamsız: $totalAbsent g | Geç: $totalLateDays g ($totalLateMins dk) | İzin/Rapor: $totalLeaveSick g')
      ..writeln('------------------------------------------------------------');
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      textBuf.writeln(
        '${i + 1}. #${r.employee.cardNo} ${r.employee.fullName} | Devam: ${r.presentDays}/${r.totalDays} | Geç: ${r.lateDays}g (${r.totalLateMinutes}dk) | Devamsız: ${r.absentDays}g | Oran: %${r.attendanceRatePercent.toStringAsFixed(0)}',
      );
    }

    return PrintableDocument(
      jobName: 'Devam_Devamsizlik_Raporu_${startDateKey}_$endDateKey',
      title: 'Çok Günlü Devam / Devamsızlık Raporu',
      subtitle: 'Dönem: $rangeDisplay • $filterDescription',
      htmlContent: _wrapA4HtmlDocument(
        companySettings: companySettings,
        documentTitle: 'Çok Günlü Devam / Devamsızlık Raporu',
        subtitle: 'Dönem: $rangeDisplay • $filterDescription',
        bodyHtml: bodyBuf.toString(),
        landscape: true,
        printedAt: now,
      ),
      plainTextSummary: textBuf.toString(),
      landscape: true,
    );
  }

  /// 5. İzin & Sağlık Raporları Listesi Çıktısı (A4 Dikey).
  static PrintableDocument buildLeaveRecordsReportDocument({
    required CompanySettings companySettings,
    required String scopeTitle,
    required List<LeaveRecord> records,
    required Map<int, EmployeeDailyStatus> statusByEmployeeId,
    EmployeeDailyStatus? singleEmployeeStatus,
    DateTime? printedAt,
  }) {
    final now = printedAt ?? DateTime.now();
    final bodyBuf = StringBuffer();

    if (singleEmployeeStatus != null) {
      final emp = singleEmployeeStatus.employee;
      bodyBuf
        ..writeln('<div class="info-grid">')
        ..writeln(_infoCell('Personel', '${emp.fullName} (#${emp.cardNo})'))
        ..writeln(_infoCell('Şube / Bölüm', '${singleEmployeeStatus.branch.name} / ${singleEmployeeStatus.department.name}'))
        ..writeln(_infoCell('Yıllık İzin Bakiyesi', 'Hak: ${emp.annualLeaveEntitlement}g • Kullanılan: ${emp.usedAnnualLeave}g • Kalan: ${emp.remainingAnnualLeave}g'))
        ..writeln('</div>');
    }

    if (records.isEmpty) {
      bodyBuf.writeln('<div class="empty-note">Kayıtlı izin veya sağlık raporu bulunmuyor.</div>');
    } else {
      bodyBuf.writeln(
        '<table><thead><tr>'
        '<th>#</th><th>Tarih</th><th>Kart No</th><th>Ad Soyad</th>'
        '<th>Şube / Bölüm</th><th>İzin / Rapor Türü</th><th>Açıklama</th>'
        '</tr></thead><tbody>',
      );
      for (int i = 0; i < records.length; i++) {
        final rec = records[i];
        final st = statusByEmployeeId[rec.employeeId];
        final cardNo = st?.employee.cardNo ?? '-';
        final fullName = st?.employee.fullName ?? 'Personel #${rec.employeeId}';
        final branchDept = st != null ? '${st.branch.name} / ${st.department.name}' : '-';
        bodyBuf.writeln(
          '<tr>'
          '<td>${i + 1}</td>'
          '<td>${escapeHtml(_formatDisplayDateOrDash(rec.date))}</td>'
          '<td>${escapeHtml(cardNo)}</td>'
          '<td><strong>${escapeHtml(fullName)}</strong></td>'
          '<td>${escapeHtml(branchDept)}</td>'
          '<td><span class="badge">${escapeHtml(rec.leaveType.label)}</span></td>'
          '<td>${escapeHtml(rec.note.trim().isEmpty ? "-" : rec.note.trim())}</td>'
          '</tr>',
        );
      }
      bodyBuf.writeln('</tbody></table>');
    }

    final textBuf = StringBuffer()
      ..writeln('${companySettings.companyName} — İZİN & SAĞLIK RAPORLARI ÇIKTISI')
      ..writeln('Kapsam: $scopeTitle • Toplam Kayıt: ${records.length}')
      ..writeln('------------------------------------------------------------');
    if (singleEmployeeStatus != null) {
      final emp = singleEmployeeStatus.employee;
      textBuf.writeln(
        'Personel: ${emp.fullName} (#${emp.cardNo}) • Kalan İzin: ${emp.remainingAnnualLeave}/${emp.annualLeaveEntitlement} Gün',
      );
    }
    for (int i = 0; i < records.length; i++) {
      final rec = records[i];
      final st = statusByEmployeeId[rec.employeeId];
      final name = st?.employee.fullName ?? 'Personel #${rec.employeeId}';
      textBuf.writeln(
        '${i + 1}. ${_formatDisplayDateOrDash(rec.date)} | $name | ${rec.leaveType.label}${rec.note.trim().isNotEmpty ? " • ${rec.note.trim()}" : ""}',
      );
    }

    return PrintableDocument(
      jobName: 'Izin_ve_Raporlar',
      title: 'İzin ve Sağlık Raporları Çıktısı',
      subtitle: '$scopeTitle • ${records.length} kayıt',
      htmlContent: _wrapA4HtmlDocument(
        companySettings: companySettings,
        documentTitle: 'İzin ve Sağlık Raporları Çıktısı',
        subtitle: '$scopeTitle • ${records.length} kayıt',
        bodyHtml: bodyBuf.toString(),
        landscape: false,
        printedAt: now,
      ),
      plainTextSummary: textBuf.toString(),
      landscape: false,
    );
  }

  static String _infoCell(String label, String value) {
    return '<div class="info-item"><div class="lbl">${escapeHtml(label)}</div><div class="val">${escapeHtml(value)}</div></div>';
  }

  static String _kpiBox(String value, String label) {
    return '<div class="kpi-box"><div class="kpi-val">${escapeHtml(value)}</div><div class="kpi-lbl">${escapeHtml(label)}</div></div>';
  }
}
