import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../database/zikir_seed_data.dart';
import '../../features/gamification/services/badge_service.dart';
import '../utils/pref_utils.dart';
import 'widget_sync_service.dart';

/// Kendini Onaran Veri Uzlaştırma Servisi (Self-Healing Data Reconciliation Engine)
/// 
/// 523.9K gibi log kayıtlarını, zikir toplamlarını, kaza borçlarını,
/// rozet kilitlerini ve oturum verilerini otomatik olarak analiz eder,
/// eksikleri giderir ve veritabanını %100 tutarlı hale getirir.
class DataReconciliationService {
  static bool _isReconciling = false;

  /// Ana uzlaştırma rutini: Açılışta ve yedek yükleme sonrasında otomatik çalışır.
  static Future<void> reconcileAll(AppDatabase db, [String? sessionId]) async {
    if (_isReconciling) return;
    _isReconciling = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Zikirler ve ZikirLogları Uzlaştırması
      await _reconcileZikirsAndLogs(db, prefs, sessionId);

      // 2. Kaza Namazları Veri Doğrulaması & Kurtarma
      await _reconcileKazaPrayers(db);

      // 3. Rozet ve Başarım Değerlendirmesi
      await _reconcileBadges(db, prefs, sessionId);

      // 4. Günlük Kur'an Okuma Verisi Doğrulaması & Kurtarma
      await _reconcileQuranDailyPages(db, prefs, sessionId);

      // 5. Widget Senkronizasyonu
      await WidgetSyncService.syncAll(db, sessionId: sessionId);

      debugPrint('[DataReconciliationService] ✅ Tüm veri uzlaştırmaları başarıyla tamamlandı.');
    } catch (e, st) {
      debugPrint('[DataReconciliationService] Uzlaştırma hatası: $e\n$st');
    } finally {
      _isReconciling = false;
    }
  }

  /// 1. Zikirler ve ZikirLogları Uzlaştırması
  /// db.zikirLogs tablosundaki 523.9K gibi tüm logları toplar.
  /// Loglarda mevcut olan her zikirId için db.zikirs içinde kayıt olup olmadığını doğrular,
  /// yoksa oluşturur ve totalCount değerini logların toplamıyla senkronize eder.
  static Future<void> _reconcileZikirsAndLogs(
    AppDatabase db,
    SharedPreferences prefs,
    String? sessionId,
  ) async {
    try {
      // Önce varsayılan tohum zikirlerin varlığını garantiye al
      await ZikirSeedData.ensureAllDefaultZikirsExist(db);

      final allZikirs = await db.select(db.zikirs).get();
      final allLogs = await db.select(db.zikirLogs).get();

      if (allLogs.isEmpty && allZikirs.isEmpty) return;

      final zikirMap = {for (final z in allZikirs) z.id: z};
      final logsGroupedByZikir = <int, int>{};
      int grandLogsSum = 0;

      for (final log in allLogs) {
        grandLogsSum += log.count;
        logsGroupedByZikir[log.zikirId] = (logsGroupedByZikir[log.zikirId] ?? 0) + log.count;
      }

      await db.transaction(() async {
        // A. Loglarda geçen ama db.zikirs içinde silinmiş veya bulunmayan zikirleri kurtar
        for (final entry in logsGroupedByZikir.entries) {
          final zId = entry.key;
          final totalFromLogs = entry.value;

          if (!zikirMap.containsKey(zId)) {
            // Tohum zikir listesinden isim ve arapça ara
            ZikirSeedItem? seedMatch;
            if (zId > 0 && zId <= ZikirSeedData.defaultZikirs.length) {
              seedMatch = ZikirSeedData.defaultZikirs[zId - 1];
            }

            final name = seedMatch?.name ?? 'Zikir #$zId';
            final arabic = seedMatch?.arabic ?? '';
            final target = seedMatch?.target ?? 33;
            final category = seedMatch?.category ?? 'Genel';

            await db.into(db.zikirs).insert(
              ZikirsCompanion.insert(
                id: Value(zId),
                name: name,
                arabic: Value(arabic.isNotEmpty ? arabic : null),
                target: Value(target),
                currentCount: const Value(0),
                totalCount: Value(totalFromLogs),
                lap: Value(target > 0 ? (totalFromLogs ~/ target) : 0),
                category: Value(category),
                isFavorite: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
          } else {
            // Zikir mevcut; totalCount logların toplamından küçükse güncelle
            final z = zikirMap[zId]!;
            final effectiveTotal = max(z.totalCount, totalFromLogs);
            if (effectiveTotal != z.totalCount) {
              await (db.update(db.zikirs)..where((t) => t.id.equals(z.id))).write(
                ZikirsCompanion(
                  totalCount: Value(effectiveTotal),
                  lap: Value(z.target > 0 ? (effectiveTotal ~/ z.target) : z.lap),
                ),
              );
            }
          }
        }
      });

      // SharedPreferences'taki TotalZikir değerini garantiye al
      final isDefault = sessionId == null || sessionId == 'default_user';
      final totalKey = isDefault ? 'TotalZikir' : 'TotalZikir_$sessionId';
      final curTotal = prefs.getInt(totalKey) ?? 0;
      final newTotal = max(curTotal, grandLogsSum);
      if (newTotal > 0) {
        await prefs.setInt(totalKey, newTotal);
        if (isDefault) {
          await prefs.setInt('TotalZikirCount', newTotal);
        }
      }
    } catch (e) {
      debugPrint('[DataReconciliationService] _reconcileZikirsAndLogs error: $e');
    }
  }

  /// 2. Kaza Namazları Veri Doğrulaması & Akıllı Kurtarma
  /// 7 temel kaza ibadetinin eksiksiz olmasını sağlar.
  /// Eğer tüm kaza borçları 0 görünüyorsa, cihazdaki son yedek dosyasından
  /// (PrayerName & Count eşlemesiyle) gerçek kaza borçlarını kurtarır.
  static Future<void> _reconcileKazaPrayers(AppDatabase db) async {
    try {
      const requiredTypes = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı', 'Vitir', 'Oruç'];
      final existing = await db.select(db.kazaPrayers).get();
      final existingMap = {for (final k in existing) k.prayerType: k};

      await db.transaction(() async {
        for (final pType in requiredTypes) {
          if (!existingMap.containsKey(pType)) {
            await db.into(db.kazaPrayers).insert(
              KazaPrayersCompanion.insert(
                prayerType: pType,
                totalCount: const Value(0),
                completedCount: const Value(0),
              ),
            );
          }
        }
      });

      // Kontrol et: Tüm kaza borçları 0 mı? (Yedek yükleme anahtar uyuşmazlığı nedeniyle sıfırlanmış mı?)
      final updatedExisting = await db.select(db.kazaPrayers).get();
      final hasZeroDebts = updatedExisting.every((k) => k.totalCount == 0);

      if (hasZeroDebts) {
        debugPrint('[DataReconciliationService] Kaza borçları 0 görünüyor. Yedekten kurtarma deneniyor...');
        final backupData = await _findLatestBackupJsonOnDevice();
        if (backupData != null && backupData['KazaPrayers'] is List) {
          final kazaList = backupData['KazaPrayers'] as List;
          int recoveredCount = 0;
          for (final item in kazaList) {
            if (item is! Map<String, dynamic>) continue;
            final pType = item['PrayerName']?.toString() ?? item['PrayerType']?.toString() ?? item['prayerType']?.toString();
            final count = _parseInt(item['Count'] ?? item['TargetCount'] ?? item['targetCount'] ?? item['TotalCount'] ?? item['totalCount'], 0);
            final comp = _parseInt(item['CompletedCount'] ?? item['completedCount'], 0);

            if (pType != null && pType.isNotEmpty && count > 0) {
              await (db.update(db.kazaPrayers)..where((tbl) => tbl.prayerType.equals(pType))).write(
                KazaPrayersCompanion(
                  totalCount: Value(count),
                  completedCount: Value(comp),
                ),
              );
              recoveredCount++;
            }
          }
          debugPrint('[DataReconciliationService] ✅ Kaza borçları yedekten kurtarıldı ($recoveredCount vakit güncellendi).');

          // KazaMeltLogs da boşsa kurtar
          final existingMelts = await db.select(db.kazaMeltLogs).get();
          if (existingMelts.isEmpty && backupData['KazaMeltLogs'] is List) {
            final meltList = backupData['KazaMeltLogs'] as List;
            for (final item in meltList) {
              if (item is! Map<String, dynamic>) continue;
              final mId = _tryParseInt(item['Id'] ?? item['id']);
              final pType = item['PrayerName']?.toString() ?? item['PrayerType']?.toString() ?? item['prayerType']?.toString() ?? 'Sabah';
              final amount = _parseInt(item['Count'] ?? item['MeltAmount'] ?? item['meltAmount'], 1);
              final unix = _tryParseInt(item['Timestamp']);
              final dt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix) : DateTime.now();

              await db.into(db.kazaMeltLogs).insert(
                KazaMeltLogsCompanion(
                  id: mId != null ? Value(mId) : const Value.absent(),
                  prayerType: Value(pType),
                  meltAmount: Value(amount),
                  timestamp: Value(dt),
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DataReconciliationService] _reconcileKazaPrayers error: $e');
    }
  }

  /// 3. Rozet ve Başarım Değerlendirmesi
  /// 523.9K zikir ve okuma verilerine göre BadgeService'i çalıştırır
  /// ve hak edilen tüm rozetleri db.unlockedBadges tablosuna kalıcı olarak yazar.
  static Future<void> _reconcileBadges(
    AppDatabase db,
    SharedPreferences prefs,
    String? sessionId,
  ) async {
    try {
      final badgeService = BadgeService(db);
      final badges = await badgeService.getBadges();
      final unlockedBadgeIds = badges.where((b) => b.isUnlocked).map((b) => b.id).toList();

      if (unlockedBadgeIds.isNotEmpty) {
        final isDefault = sessionId == null || sessionId == 'default_user';
        final key = isDefault ? 'UnlockedBadgeIds' : 'UnlockedBadgeIds_$sessionId';
        await prefs.setStringList(key, unlockedBadgeIds);
        if (isDefault) {
          await prefs.setStringList('UnlockedBadgeIds', unlockedBadgeIds);
        }
      }
    } catch (e) {
      debugPrint('[DataReconciliationService] _reconcileBadges error: $e');
    }
  }

  /// 4. Günlük Kur'an Okuma Verisi Doğrulaması & Kurtarma
  static Future<void> _reconcileQuranDailyPages(
    AppDatabase db,
    SharedPreferences prefs,
    String? sessionId,
  ) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final isDefault = sessionId == null || sessionId == 'default_user';
      final todayKey = isDefault ? 'TodayReadPages_$todayStr' : 'TodayReadPages_${todayStr}_$sessionId';
      final totalKey = isDefault ? 'TotalReadQuranPages' : 'TotalReadQuranPages_$sessionId';

      // A. Hatim tablosunu tara ve bugün okunan sayfaları topla
      final hatims = await db.select(db.hatims).get();
      int hatimMaxPage = 0;
      int todayHatimPages = 0;
      for (final h in hatims) {
        if (h.completedPages > hatimMaxPage) hatimMaxPage = h.completedPages;
        final hToday = prefs.getInt('HatimTodayPages_${h.id}_$todayStr') ?? 0;
        todayHatimPages += hToday;
      }

      // B. Yedek dosyasındaki AppSettings ve JuzBookmarks'ı tara
      final backupData = await _findLatestBackupJsonOnDevice();
      int backupTotalPages = 0;
      int backupTodayPages = 0;
      if (backupData != null) {
        bool isBackupFromToday = false;
        if (backupData['BackupDate'] is String) {
          final bDate = DateTime.tryParse(backupData['BackupDate'] as String);
          if (bDate != null && bDate.year == now.year && bDate.month == now.month && bDate.day == now.day) {
            isBackupFromToday = true;
          }
        }
        if (backupData['AppSettings'] is Map) {
          final s = backupData['AppSettings'] as Map;
          backupTotalPages = _parseInt(s['TotalReadPages'] ?? s['total_read_pages'], 0);
          if (isBackupFromToday) {
            backupTodayPages = _parseInt(s['TodayReadPages'] ?? s['today_read_pages'], 0);
          }
        }
        if (backupData['JuzBookmarks'] is List) {
          final bookmarks = backupData['JuzBookmarks'] as List;
          for (final b in bookmarks) {
            if (b is Map<String, dynamic>) {
              final page = _parseInt(b['Page'] ?? b['page'], 0);
              if (page > hatimMaxPage) hatimMaxPage = page;
            }
          }
        }
      }

      // C. Bugün okunan sayfayı doğru şekilde uzlaştır (Asla sahte sayfa üretme)
      int curToday = prefs.getInt(todayKey) ?? prefs.getInt('TodayReadPages_$todayStr') ?? 0;

      // 1. Hatimlerde bugün okunan sayfa varsa, curToday en az bu kadar olmalı
      if (todayHatimPages > 0 && curToday < todayHatimPages) {
        curToday = todayHatimPages;
      }

      // Self-healing: Eğer tek bir aktif hatim varsa ve curToday > 0 iken hatim bazlı bugün okunan sayfa 0 ise,
      // hatim kartında da doğru görünmesi için HatimTodayPages'e yansıt
      if (hatims.length == 1 && todayHatimPages == 0 && curToday > 0) {
        final singleHatim = hatims.first;
        await prefs.setInt('HatimTodayPages_${singleHatim.id}_$todayStr', curToday);
        todayHatimPages = curToday;
      }

      // 2. Eski hayalet +5 bug'ı (min(5, hatimMaxPage)) ile şişirilmiş veriyi temizle
      if (curToday == todayHatimPages + 5 || (todayHatimPages == 0 && curToday == 5)) {
        curToday = todayHatimPages;
        debugPrint('[DataReconciliationService] 🛠️ Hayalet +5 sayfa hatası düzeltildi: $curToday sayfa.');
      }

      // 3. Eğer bugün oluşturulmuş geçerli bir yedekten okuma geldiyse dahil et
      if (backupTodayPages > curToday) {
        curToday = backupTodayPages;
      }

      // 4. Anahtarları senkronize et ve tarihsiz eski anahtarları kaldır
      await prefs.setInt(todayKey, curToday);
      if (!isDefault) {
        await prefs.setInt('TodayReadPages_$todayStr', curToday);
      }
      await prefs.remove('TodayReadPages');
      await prefs.remove('today_read_pages');
      if (curToday > 0) {
        await prefs.setString('LastReadDate', todayStr);
        await prefs.setString('last_read_date', todayStr);
      }

      // D. Toplam okunan sayfayı kurtar (6056 sayfa gibi devasa geçmişi geri getir)
      final curTotal = prefs.getInt(totalKey) ?? 0;
      final effectiveTotal = max(max(curTotal, backupTotalPages), hatimMaxPage);
      if (effectiveTotal > curTotal) {
        await prefs.setInt(totalKey, effectiveTotal);
        if (isDefault) {
          await prefs.setInt('TotalReadPages_All', effectiveTotal);
          await prefs.setInt('total_read_pages', effectiveTotal);
          await prefs.setInt('TotalReadPages', effectiveTotal);
        }
        debugPrint('[DataReconciliationService] ✅ Toplam Kur\'an okuma $effectiveTotal sayfa olarak güncellendi.');
      }
    } catch (e) {
      debugPrint('[DataReconciliationService] _reconcileQuranDailyPages error: $e');
    }
  }

  /// Cihaz hafızasındaki (İndirilenler & Belgeler) en güncel Zikirce yedeğini bulur ve JSON olarak okur.
  static Future<Map<String, dynamic>?> _findLatestBackupJsonOnDevice() async {
    try {
      final candidateDirs = <Directory>[];
      if (Platform.isAndroid) {
        candidateDirs.add(Directory('/sdcard/Download'));
        candidateDirs.add(Directory('/storage/emulated/0/Download'));
      }
      try {
        final docDir = await getApplicationDocumentsDirectory();
        candidateDirs.add(docDir);
      } catch (_) {}

      final files = <File>[];
      for (final dir in candidateDirs) {
        if (!dir.existsSync()) continue;
        try {
          final entities = dir.listSync();
          for (final e in entities) {
            if (e is File) {
              final name = p.basename(e.path);
              if (name.startsWith('Zikirce_') && (name.endsWith('.json') || name.endsWith('.zikirback'))) {
                files.add(e);
              }
            }
          }
        } catch (_) {}
      }

      if (files.isEmpty) return null;

      // Değiştirilme tarihine göre en yeniden en eskiye sırala
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      for (final file in files) {
        try {
          final text = file.readAsStringSync();
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic> &&
              (decoded.containsKey('KazaPrayers') || decoded.containsKey('Zikirler') || decoded.containsKey('AppSettings'))) {
            debugPrint('[DataReconciliationService] En güncel cihaz yedeği bulundu: ${file.path}');
            return decoded;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DataReconciliationService] _findLatestBackupJsonOnDevice error: $e');
    }
    return null;
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    final s = value.toString().trim();
    return int.tryParse(s) ?? (double.tryParse(s)?.toInt() ?? fallback);
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    final s = value.toString().trim();
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }

  /// Akıllı Bulut Veri Birleştirme Motoru (Smart Conflict-Free Cloud Reconciliation)
  /// 
  /// İki farklı cihazdan (telefon/tablet/pc) gelen verileri sıfır kayıpla birleştirir:
  /// - Zikir logları mükerrersiz eklenir ve totalCount toplanır.
  /// - Kur'an ve Hatim'de en ileri kalınan sayfa korunur (max).
  /// - Kaza namazları ve eritme logları birleştirilir.
  /// - Rozetler ve en yüksek streak birleştirilir.
  /// - Kullanıcı tercihleri ve ayarları güncellenir.
  static Future<bool> smartMergeCloudPayload(
    AppDatabase db,
    Map<String, dynamic> remoteData, {
    String? sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isDefault = sessionId == null || sessionId == 'default_user';

    try {
      // 1. ZİKİRLER VE ZİKİR LOGLARI BİRLEŞTİRME
      final remoteZikirs = remoteData['Zikirler'] ?? remoteData['zikirler'];
      final remoteLogs = remoteData['ZikirLogs'] ?? remoteData['zikirLogs'];

      await ZikirSeedData.ensureAllDefaultZikirsExist(db);
      final localZikirs = await db.select(db.zikirs).get();
      final zikirMap = {for (final z in localZikirs) z.id: z};

      // A. Uzak Zikirleri Eşle / Ekle
      if (remoteZikirs is List) {
        for (final item in remoteZikirs) {
          if (item is! Map<String, dynamic>) continue;
          final zId = _tryParseInt(item['ZikirId'] ?? item['id']);
          final zName = (item['ZikirAdi'] ?? item['name'] ?? 'Zikir').toString();
          final zArabic = item['ArapceMetin'] ?? item['arabic'];
          final zTarget = _parseInt(item['ZikirMiktar'] ?? item['target'], 33);
          final zCount = _parseInt(item['Sayac'] ?? item['currentCount'], 0);
          final zTotal = _parseInt(item['ZikirToplam'] ?? item['totalCount'], 0);
          final zLap = _parseInt(item['MaxSeyir'] ?? item['lap'], 0);
          final zFav = item['IsFavorite'] == true || item['isFavorite'] == true || item['IsFavorite'] == 1;
          final zCat = (item['Kategori'] ?? item['category'] ?? 'Genel').toString();
          final zSound = (item['ZikirAciklama'] ?? item['soundEffect'] ?? 'bulbul').toString();
          final unix = _tryParseInt(item['TarihUnix']);
          final createdAt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix * 1000) : DateTime.now();
          final lastPracticedUnix = _tryParseInt(item['SonPratikUnix'] ?? item['lastPracticedUnix']);
          final remoteLastPracticed = lastPracticedUnix != null ? DateTime.fromMillisecondsSinceEpoch(lastPracticedUnix * 1000) : null;

          if (zId != null && zikirMap.containsKey(zId)) {
            final local = zikirMap[zId]!;
            final updatedTarget = max(local.target, zTarget);
            final updatedFav = local.isFavorite || zFav;

            final localPratikSec = local.lastPracticed != null ? local.lastPracticed!.millisecondsSinceEpoch ~/ 1000 : 0;
            final remotePratikSec = lastPracticedUnix ?? 0;

            final isRemoteNewer = (remotePratikSec > localPratikSec) ||
                (zTotal > local.totalCount) ||
                (zTotal == local.totalCount && zCount > local.currentCount);

            // Açılış anındaki yarış durumunu (race condition) engelle:
            // Eğer yerel cihazda yeni bir pratik/tıklama yapılmışsa (localPratikSec > remotePratikSec),
            // yereldeki tıklamaları kaybetmemek için yerel farkı uzaktaki sayının üstüne ekle.
            final localFreshDelta = (localPratikSec > remotePratikSec && local.currentCount > 0) ? local.currentCount : 0;
            final effectiveTotal = (localPratikSec > remotePratikSec && zTotal > local.totalCount)
                ? (zTotal + localFreshDelta)
                : max(local.totalCount, zTotal);
            final effectiveCount = isRemoteNewer ? (zCount + localFreshDelta) : local.currentCount;
            final effectiveLap = isRemoteNewer ? zLap : (local.target > 0 ? (effectiveTotal ~/ local.target) : local.lap);
            final effectiveLastPracticed = (localPratikSec > remotePratikSec)
                ? local.lastPracticed
                : (remoteLastPracticed ?? local.lastPracticed);

            await (db.update(db.zikirs)..where((t) => t.id.equals(zId))).write(
              ZikirsCompanion(
                target: Value(updatedTarget),
                currentCount: Value(effectiveCount),
                totalCount: Value(effectiveTotal),
                lap: Value(effectiveLap),
                lastPracticed: effectiveLastPracticed != null ? Value(effectiveLastPracticed) : const Value.absent(),
                isFavorite: Value(updatedFav),
                category: local.category == 'Genel' && zCat != 'Genel' ? Value(zCat) : const Value.absent(),
              ),
            );
          } else if (zId != null) {
            await db.into(db.zikirs).insert(
              ZikirsCompanion.insert(
                id: Value(zId),
                name: zName,
                arabic: Value(zArabic?.toString()),
                target: Value(zTarget),
                currentCount: Value(zCount),
                totalCount: Value(zTotal),
                lap: Value(zLap),
                category: Value(zCat),
                soundEffect: Value(zSound),
                isFavorite: Value(zFav),
                createdAt: Value(createdAt),
                lastPracticed: Value(remoteLastPracticed),
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        }
      }

      // B. Uzak Logları Mükerrersiz Birleştirme
      final localLogs = await db.select(db.zikirLogs).get();
      final localLogKeys = <String>{};
      for (final l in localLogs) {
        final sec = l.timestamp.millisecondsSinceEpoch ~/ 1000;
        localLogKeys.add('${l.zikirId}_${l.count}_${l.dateStr}_$sec');
      }

      if (remoteLogs is List) {
        for (final item in remoteLogs) {
          if (item is! Map<String, dynamic>) continue;
          final zId = _parseInt(item['ZikirId'] ?? item['zikirId'], 1);
          final count = _parseInt(item['CekilenMiktar'] ?? item['count'], 0);
          final unix = _tryParseInt(item['TarihUnix']);
          final dt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix * 1000) : DateTime.now();
          final sec = dt.millisecondsSinceEpoch ~/ 1000;
          final dateStr = (item['dateStr'] ?? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}').toString();

          final key = '${zId}_${count}_${dateStr}_$sec';
          if (!localLogKeys.contains(key) && count > 0) {
            localLogKeys.add(key);
            await db.into(db.zikirLogs).insert(
              ZikirLogsCompanion.insert(
                zikirId: zId,
                count: count,
                dateStr: dateStr,
                timestamp: Value(dt),
              ),
            );
          }
        }
      }

      // Zikir toplamlarını birleştirilen loglarla uzlaştır
      await _reconcileZikirsAndLogs(db, prefs, sessionId);

      // 2. KUR'AN, MUKABELE VE HATİM BİRLEŞTİRME (En ileri sayfa korunur - MAX)
      final remoteHatims = remoteData['Hatimler'] ?? remoteData['hatimler'];
      final remoteCuzList = remoteData['HatimCuzProgressList'] ?? remoteData['hatimCuzProgresses'];
      final remoteBookmarks = remoteData['JuzBookmarks'] ?? remoteData['juzBookmarks'];

      final localHatims = await db.select(db.hatims).get();
      final localHatimMap = {for (final h in localHatims) h.id: h};

      if (remoteHatims is List) {
        for (final item in remoteHatims) {
          if (item is! Map<String, dynamic>) continue;
          final hId = (item['RealHatimId'] ?? item['id'] ?? item['HatimId'] ?? '1').toString();
          final hTitle = (item['HatimAdi'] ?? item['title'] ?? 'Hatim').toString();
          final completedPages = _parseInt(item['CurrentPage'] ?? item['CompletedPages'] ?? item['completedPages'], 0);
          final isCompleted = item['IsCompleted'] == true || item['isCompleted'] == true;
          final isGroup = item['Type'] == 1 || item['Type'] == '1' || item['isGroup'] == true;
          final todayPages = _parseInt(item['TodayReadPages'] ?? item['todayReadPages'], 0);
          final lastReadDate = item['LastReadDate']?.toString();

          if (todayPages > 0) {
            final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
            final key = 'HatimTodayPages_${hId}_$todayStr';
            final cur = prefs.getInt(key) ?? 0;
            if (todayPages > cur) {
              await prefs.setInt(key, todayPages);
            }
          }
          if (lastReadDate != null && lastReadDate.isNotEmpty) {
            await prefs.setString('HatimLastReadDate_$hId', lastReadDate);
          }

          if (localHatimMap.containsKey(hId)) {
            final localH = localHatimMap[hId]!;
            final maxCompletedPages = max(localH.completedPages, completedPages);
            final mergedIsCompleted = localH.isCompleted || isCompleted;
            await (db.update(db.hatims)..where((t) => t.id.equals(hId))).write(
              HatimsCompanion(
                completedPages: Value(maxCompletedPages),
                isCompleted: Value(mergedIsCompleted),
              ),
            );
          } else {
            await db.into(db.hatims).insert(
              HatimsCompanion.insert(
                id: hId,
                title: hTitle,
                completedPages: Value(completedPages),
                isCompleted: Value(isCompleted),
                isGroup: Value(isGroup),
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        }
      }

      // Hatim Cüz İlerlemeleri
      if (remoteCuzList is List) {
        final localProgress = await db.select(db.hatimCuzProgresses).get();
        final progressMap = <String, HatimCuzProgressesData>{};
        for (final p in localProgress) {
          progressMap['${p.hatimId}_${p.juzNo}'] = p;
        }

        for (final item in remoteCuzList) {
          if (item is! Map<String, dynamic>) continue;
          final hatimId = (item['HatimId'] ?? item['hatimId'] ?? '1').toString();
          final juzNo = _parseInt(item['CuzNumber'] ?? item['juzNo'], 1);
          final isDone = item['Status'] == 2 || item['Status'] == '2' || item['isCompleted'] == true;
          final reader = item['OwnerName'] ?? item['readerName'];

          final key = '${hatimId}_$juzNo';
          if (progressMap.containsKey(key)) {
            final localP = progressMap[key]!;
            final mergedDone = localP.isCompleted || isDone;
            final readerName = (reader != null && reader.toString().isNotEmpty) ? reader.toString() : localP.readerName;
            await (db.update(db.hatimCuzProgresses)..where((t) => t.id.equals(localP.id))).write(
              HatimCuzProgressesCompanion(
                isCompleted: Value(mergedDone),
                readerName: Value(readerName),
              ),
            );
          } else {
            await db.into(db.hatimCuzProgresses).insert(
              HatimCuzProgressesCompanion.insert(
                hatimId: hatimId,
                juzNo: juzNo,
                isCompleted: Value(isDone),
                readerName: Value(reader?.toString()),
              ),
            );
          }
        }
      }

      // Cüz Yer İmleri (JuzBookmarks)
      if (remoteBookmarks is List) {
        final localBms = await db.select(db.juzBookmarks).get();
        final bmMap = {for (final b in localBms) b.juzNo: b};

        for (final item in remoteBookmarks) {
          if (item is! Map<String, dynamic>) continue;
          final juzNo = _parseInt(item['JuzNo'] ?? item['juzNo'], 1);
          final page = _parseInt(item['LastPage'] ?? item['lastPage'] ?? item['Page'], 1);

          if (bmMap.containsKey(juzNo)) {
            final localBm = bmMap[juzNo]!;
            final maxPage = max(localBm.lastPage, page);
            await (db.update(db.juzBookmarks)..where((t) => t.juzNo.equals(juzNo))).write(
              JuzBookmarksCompanion(
                lastPage: Value(maxPage),
                updatedAt: Value(DateTime.now()),
              ),
            );
          } else {
            await db.into(db.juzBookmarks).insert(
              JuzBookmarksCompanion.insert(
                juzNo: Value(juzNo),
                lastPage: Value(page),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }
      }

      // SharedPreferences Kur'an İlerlemeleri
      final appSettings = remoteData['AppSettings'] ?? remoteData['appSettings'];
      if (appSettings is Map<String, dynamic>) {
        final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
        final remoteTodayPages = _parseInt(appSettings['TodayReadPages_$todayStr'] ?? appSettings['TodayReadPages'], 0);
        final remoteTotalPages = _parseInt(appSettings['TotalReadQuranPages'] ?? appSettings['TotalReadPages_All'] ?? appSettings['TotalReadPages'], 0);

        final localTodayKey = isDefault ? 'TodayReadPages_$todayStr' : 'TodayReadPages_${todayStr}_$sessionId';
        final localTotalKey = isDefault ? 'TotalReadQuranPages' : 'TotalReadQuranPages_$sessionId';

        final curToday = prefs.getInt(localTodayKey) ?? 0;
        final curTotal = prefs.getInt(localTotalKey) ?? 0;

        if (remoteTodayPages > curToday) {
          await prefs.setInt(localTodayKey, remoteTodayPages);
          if (isDefault) await prefs.setInt('TodayReadPages_$todayStr', remoteTodayPages);
        }
        if (remoteTotalPages > curTotal) {
          await prefs.setInt(localTotalKey, remoteTotalPages);
          if (isDefault) {
            await prefs.setInt('TotalReadPages_All', remoteTotalPages);
            await prefs.setInt('TotalReadPages', remoteTotalPages);
          }
        }

        // Mukabele / Hatim son okunan sayfa
        for (final entry in appSettings.entries) {
          if (entry.key.startsWith('MukabeleLastPage_') || entry.key.startsWith('HatimLastPage_')) {
            final remoteP = _parseInt(entry.value, 1);
            final localP = prefs.getInt(entry.key) ?? 1;
            if (remoteP > localP) {
              await prefs.setInt(entry.key, remoteP);
            }
          }
        }

        // Hatim bugün okunan sayfa uzlaştırması (HatimTodayPages)
        final remoteHatimTodayMap = appSettings['HatimTodayPages'] ?? appSettings['hatimTodayPages'];
        if (remoteHatimTodayMap is Map) {
          for (final entry in remoteHatimTodayMap.entries) {
            final hatimId = entry.key.toString();
            final remoteCount = _parseInt(entry.value, 0);
            final localKey = 'HatimTodayPages_${hatimId}_$todayStr';
            final localCount = prefs.getInt(localKey) ?? 0;
            final maxCount = max(localCount, remoteCount);
            if (maxCount > 0) {
              await prefs.setInt(localKey, maxCount);
            }
          }
        }

        // Direct key formatında gelen HatimTodayPages_{id}_{date} ve HatimLastReadDate desteği
        for (final entry in appSettings.entries) {
          if (entry.key.startsWith('HatimTodayPages_')) {
            final remoteCount = _parseInt(entry.value, 0);
            final localCount = prefs.getInt(entry.key) ?? 0;
            final maxCount = max(localCount, remoteCount);
            if (maxCount > 0) {
              await prefs.setInt(entry.key, maxCount);
            }
          } else if (entry.key.startsWith('HatimLastReadDate_')) {
            final remoteVal = entry.value?.toString() ?? '';
            final localVal = prefs.getString(entry.key);
            if (localVal == null || localVal.isEmpty) {
              await prefs.setString(entry.key, remoteVal);
            }
          }
        }
      }

      await _reconcileQuranDailyPages(db, prefs, sessionId);

      // 3. KAZA NAMAZLARI BİRLEŞTİRME
      final remoteKaza = remoteData['KazaPrayers'] ?? remoteData['kazaPrayers'];
      if (remoteKaza is List) {
        final localKaza = await db.select(db.kazaPrayers).get();
        final kazaMap = {for (final k in localKaza) k.prayerType: k};

        for (final item in remoteKaza) {
          if (item is! Map<String, dynamic>) continue;
          final pType = (item['PrayerType'] ?? item['prayerType'] ?? '').toString();
          final total = _parseInt(item['TotalCount'] ?? item['totalCount'], 0);
          final completed = _parseInt(item['CompletedCount'] ?? item['completedCount'], 0);

          if (kazaMap.containsKey(pType)) {
            final localK = kazaMap[pType]!;
            final maxTotal = max(localK.totalCount, total);
            final maxCompleted = max(localK.completedCount, completed);
            await (db.update(db.kazaPrayers)..where((t) => t.id.equals(localK.id))).write(
              KazaPrayersCompanion(
                totalCount: Value(maxTotal),
                completedCount: Value(maxCompleted),
              ),
            );
          }
        }
      }

      // Kaza Eritme Logları (KazaMeltLogs)
      final remoteMelts = remoteData['KazaMeltLogs'] ?? remoteData['kazaMeltLogs'];
      if (remoteMelts is List) {
        final localMelts = await db.select(db.kazaMeltLogs).get();
        final meltKeys = {for (final m in localMelts) '${m.prayerType}_${m.timestamp.millisecondsSinceEpoch ~/ 1000}'};

        for (final item in remoteMelts) {
          if (item is! Map<String, dynamic>) continue;
          final pType = (item['PrayerType'] ?? item['prayerType'] ?? '').toString();
          final amount = _parseInt(item['MeltAmount'] ?? item['meltAmount'], 0);
          final unix = _tryParseInt(item['TarihUnix']);
          final dt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix * 1000) : DateTime.now();
          final key = '${pType}_${dt.millisecondsSinceEpoch ~/ 1000}';

          if (!meltKeys.contains(key) && amount > 0) {
            meltKeys.add(key);
            await db.into(db.kazaMeltLogs).insert(
              KazaMeltLogsCompanion.insert(
                prayerType: pType,
                meltAmount: amount,
                timestamp: Value(dt),
              ),
            );
          }
        }
      }

      // 4. ZİNCİR (STREAK), ELMAS, ALTIN VE ROZETLER BİRLEŞTİRME
      final userStreakRaw = remoteData['UserStreak'] ?? remoteData['userStreak'];
      final userStreaksList = remoteData['UserStreaks'] ?? remoteData['userStreaks'];
      final rStreak = (userStreakRaw is Map<String, dynamic>)
          ? userStreakRaw
          : (userStreaksList is List && userStreaksList.isNotEmpty ? userStreaksList.first as Map<String, dynamic> : null);

      if (rStreak != null) {
        final rCurrent = _parseInt(rStreak['CurrentStreak'] ?? rStreak['currentStreak'], 0);
        final rBest = _parseInt(rStreak['BestStreak'] ?? rStreak['bestStreak'] ?? rStreak['LongestStreak'], 0);
        final rTotalDays = _parseInt(rStreak['TotalDays'] ?? rStreak['totalDays'] ?? rStreak['TotalActiveDays'], 0);
        final rShields = _parseInt(rStreak['ShieldCount'] ?? rStreak['freezeCount'], 3);

        final localStreaks = await db.select(db.userStreaks).get();
        if (localStreaks.isNotEmpty) {
          final lStreak = localStreaks.first;
          await (db.update(db.userStreaks)..where((t) => t.id.equals(lStreak.id))).write(
            UserStreaksCompanion(
              currentStreak: Value(max(lStreak.currentStreak, rCurrent)),
              bestStreak: Value(max(lStreak.bestStreak, rBest)),
              totalDays: Value(max(lStreak.totalDays, rTotalDays)),
              freezeCount: Value(max(lStreak.freezeCount, rShields)),
            ),
          );
        }
      }

      // --- ELMAS VE ALTIN AKILLI UZLAŞTIRMA (Never drop balances) ---
      final sfx = isDefault ? '' : '_$sessionId';
      final curDiamonds = PrefUtils.getIntFromKeys(prefs, ['DiamondCount$sfx', 'DiamondCount'], 0);
      final curGold = PrefUtils.getIntFromKeys(prefs, ['GoldCount$sfx', 'GoldCount'], 0);

      final remoteDiamonds = _tryParseInt(
        rStreak?['DiamondCount'] ??
        (appSettings is Map ? appSettings['DiamondCount'] : null) ??
        (remoteData['Gamification'] is Map ? remoteData['Gamification']['DiamondCount'] : null)
      );

      final remoteGold = _tryParseInt(
        rStreak?['GoldCount'] ??
        rStreak?['OverflowBadgeCount'] ??
        (appSettings is Map ? appSettings['GoldCount'] : null) ??
        (remoteData['Gamification'] is Map ? remoteData['Gamification']['GoldCount'] : null)
      );

      final finalDiamonds = max(curDiamonds, remoteDiamonds ?? 0);
      final finalGold = max(curGold, remoteGold ?? 0);

      if (finalDiamonds > 0) {
        await prefs.setInt('DiamondCount$sfx', finalDiamonds);
        if (isDefault) await prefs.setInt('DiamondCount', finalDiamonds);
      }
      if (finalGold > 0) {
        await prefs.setInt('GoldCount$sfx', finalGold);
        if (isDefault) await prefs.setInt('GoldCount', finalGold);
        final localStreaks = await db.select(db.userStreaks).get();
        if (localStreaks.isNotEmpty) {
          await (db.update(db.userStreaks)..where((t) => t.id.equals(localStreaks.first.id))).write(
            UserStreaksCompanion(xp: Value(finalGold)),
          );
        }
      }

      final remoteBadges = remoteData['UnlockedBadges'] ?? remoteData['unlockedBadges'];
      if (remoteBadges is List) {
        final localBadges = await db.select(db.unlockedBadges).get();
        final badgeKeys = {for (final b in localBadges) b.badgeId};

        for (final item in remoteBadges) {
          if (item is! Map<String, dynamic>) continue;
          final bId = (item['BadgeId'] ?? item['badgeId'] ?? '').toString();
          final cat = (item['Category'] ?? item['category'] ?? 'General').toString();
          final unix = _tryParseInt(item['TarihUnix']);
          final dt = unix != null ? DateTime.fromMillisecondsSinceEpoch(unix * 1000) : DateTime.now();

          if (bId.isNotEmpty && !badgeKeys.contains(bId)) {
            badgeKeys.add(bId);
            await db.into(db.unlockedBadges).insert(
              UnlockedBadgesCompanion.insert(
                badgeId: bId,
                category: Value(cat),
                unlockedAt: Value(dt),
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        }
      }

      // 5. AYARLAR BİRLEŞTİRME (AppSettings)
      if (appSettings is Map<String, dynamic>) {
        for (final k in ['quran_arabic_font_size', 'quran_turkish_font_size']) {
          if (appSettings.containsKey(k)) {
            final val = double.tryParse(appSettings[k].toString());
            if (val != null && val > 0) {
              await prefs.setDouble(k, val);
            }
          }
        }
        if (appSettings.containsKey('quran_selected_font_name')) {
          await prefs.setString('quran_selected_font_name', appSettings['quran_selected_font_name'].toString());
        }
      }

      // 6. TÜM WIDGET'LARI GÜNCELLE
      await WidgetSyncService.syncAll(db, sessionId: sessionId);

      debugPrint('[DataReconciliationService] ✅ smartMergeCloudPayload başarıyla tamamlandı.');
      return true;
    } catch (e, st) {
      debugPrint('[DataReconciliationService] ❌ smartMergeCloudPayload hatası: $e\n$st');
      return false;
    }
  }
}
