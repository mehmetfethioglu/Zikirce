import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../session/session_providers.dart';
import 'data_reconciliation_service.dart';
import 'google_drive_backup_service.dart';
import '../../features/zikir/providers/zikir_providers.dart';
import '../../features/hatim/providers/hatim_providers.dart';
import '../../features/namaz_vakitleri/providers/prayer_providers.dart';
import '../../features/gamification/providers/gamification_providers.dart';
import '../../features/settings/providers/settings_provider.dart';

/// Senkronizasyon Durumu
enum CloudSyncStatus {
  idle,
  checking,
  syncing,
  success,
  error,
}

/// Senkronizasyon Durum Modeli
class CloudSyncState {
  final CloudSyncStatus status;
  final DateTime? lastSyncTime;
  final String? lastSyncedDevice;
  final String? errorMessage;
  final bool hasPendingChanges;

  const CloudSyncState({
    this.status = CloudSyncStatus.idle,
    this.lastSyncTime,
    this.lastSyncedDevice,
    this.errorMessage,
    this.hasPendingChanges = false,
  });

  CloudSyncState copyWith({
    CloudSyncStatus? status,
    DateTime? lastSyncTime,
    String? lastSyncedDevice,
    String? errorMessage,
    bool? hasPendingChanges,
  }) {
    return CloudSyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSyncedDevice: lastSyncedDevice ?? this.lastSyncedDevice,
      errorMessage: errorMessage,
      hasPendingChanges: hasPendingChanges ?? this.hasPendingChanges,
    );
  }
}

/// Riverpod Senkronizasyon Notifier'ı
class CloudSyncNotifier extends StateNotifier<CloudSyncState> {
  final Ref ref;

  CloudSyncNotifier(this.ref) : super(const CloudSyncState()) {
    CloudSyncEngine.instance.setAppRef(ref);
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('CloudSync_LastSyncTimestamp') ?? 0;
    final lastDev = prefs.getString('CloudSync_LastSyncedDevice');
    if (lastMs > 0) {
      state = state.copyWith(
        lastSyncTime: DateTime.fromMillisecondsSinceEpoch(lastMs),
        lastSyncedDevice: lastDev,
      );
    }
  }

  void setStatus(CloudSyncStatus status, {String? error, String? device}) {
    if (!mounted) return;
    state = state.copyWith(
      status: status,
      errorMessage: error,
      lastSyncedDevice: device ?? state.lastSyncedDevice,
      lastSyncTime: status == CloudSyncStatus.success ? DateTime.now() : state.lastSyncTime,
    );

    // Başarılı veya hata durumunda 2 saniye sonra idle durumuna pürüzsüzce geri dön
    if (status == CloudSyncStatus.success || status == CloudSyncStatus.error) {
      Timer(const Duration(milliseconds: 2000), () {
        if (mounted && state.status == status) {
          state = state.copyWith(status: CloudSyncStatus.idle);
        }
      });
    }
  }

  void markPendingChanges() {
    if (!mounted) return;
    state = state.copyWith(hasPendingChanges: true);
  }

  void clearPendingChanges() {
    if (!mounted) return;
    state = state.copyWith(hasPendingChanges: false);
  }
}

final cloudSyncProvider = StateNotifierProvider<CloudSyncNotifier, CloudSyncState>((ref) {
  CloudSyncEngine.instance.setAppRef(ref);
  return CloudSyncNotifier(ref);
});

/// Çoklu Cihaz Akıllı Senkronizasyon Motoru (Multi-Device Cloud Sync Engine)
class CloudSyncEngine {
  CloudSyncEngine._();
  static final CloudSyncEngine instance = CloudSyncEngine._();

  static const String syncFileName = 'Zikirce_CloudSync.json';
  static const String snapshotPrefix = 'Zikirce_Sync_Snapshot_';
  static const int maxSnapshots = 10;

  Timer? _debounceTimer;
  Timer? _periodicSyncTimer;
  String? _cachedSyncFileId;
  bool _isSyncInProgress = false;
  ProviderContainer? _container;
  Ref? _appRef;

  /// Application-level ProviderContainer kaydı (WidgetRef unmount olsa dahi kalıcı Riverpod konteyner erişimi)
  void setContainer(ProviderContainer container) {
    _container = container;
  }

  /// Application-level Ref kaydı (WidgetRef unmount olsa dahi kalıcı Riverpod konteyner erişimi)
  void setAppRef(Ref ref) {
    _appRef = ref;
  }

  /// Aktif ve güvenli Ref çözümleme. WidgetRef unmount/dispose olsa dahi
  /// arka planda tetiklenen debounce/sync işlemleri için _container veya _appRef kullanılır.
  dynamic _resolveRef(dynamic passedRef) {
    if (passedRef is Ref) {
      _appRef = passedRef;
      return passedRef;
    }
    if (_container != null) {
      return _container;
    }
    if (_appRef != null) {
      return _appRef;
    }
    return passedRef;
  }

  /// Disposed widget elemanları kaynaklı StateError hatalarını engelleyen güvenli okuma
  T? _safeRead<T>(dynamic ref, ProviderListenable<T> provider) {
    if (_container != null) {
      try {
        return _container!.read(provider);
      } catch (e) {
        debugPrint('[CloudSyncEngine] Container read notice: $e');
      }
    }
    if (_appRef != null) {
      try {
        return _appRef!.read(provider);
      } catch (e) {
        debugPrint('[CloudSyncEngine] AppRef read notice: $e');
      }
    }
    if (ref != null && ref != _appRef) {
      try {
        return (ref as dynamic).read(provider) as T?;
      } on StateError catch (e) {
        debugPrint('[CloudSyncEngine] StateError reading provider from transient ref: $e');
      } catch (e) {
        debugPrint('[CloudSyncEngine] Error reading provider from transient ref: $e');
      }
    }
    return null;
  }

  /// Dış servislerin güvenli Riverpod provider okuyabilmesi için genel erişim metodu
  T? read<T>(ProviderListenable<T> provider) => _safeRead(null, provider);

  /// Buluttan yeni veri indiğinde tüm UI ve sayaç provider'larını reaktif olarak yeniler
  void invalidateAllUiProviders(dynamic ref) {
    try {
      final effectiveRef = _resolveRef(ref);
      if (effectiveRef == null) return;

      void safeInvalidate(ProviderOrFamily provider) {
        try {
          if (effectiveRef is WidgetRef) {
            effectiveRef.invalidate(provider);
          } else if (effectiveRef is Ref) {
            effectiveRef.invalidate(provider);
          } else if (effectiveRef is ProviderContainer) {
            effectiveRef.invalidate(provider);
          }
        } catch (e) {
          debugPrint('[CloudSyncEngine] safeInvalidate notice: $e');
        }
      }

      safeInvalidate(databaseProvider);
      safeInvalidate(zikirListStreamProvider);
      safeInvalidate(selectedZikirIdProvider);
      safeInvalidate(hatimStatsProvider);
      safeInvalidate(hatimListStreamProvider);
      safeInvalidate(activeMukabeleHatimProvider);
      safeInvalidate(dailyGoalsStatusProvider);
      safeInvalidate(userProfileStreamProvider);
      safeInvalidate(userStreakStreamProvider);
      safeInvalidate(diamondCountProvider);
      safeInvalidate(goldCountProvider);
      safeInvalidate(kazaPrayersStreamProvider);
      safeInvalidate(kazaSummaryProvider);
      safeInvalidate(todayPrayersProvider);

      try {
        _safeRead(effectiveRef, badgeRefreshTriggerProvider.notifier)?.state++;
      } catch (_) {}

      try {
        _safeRead(effectiveRef, userSettingsProvider.notifier)?.reloadSettings();
      } catch (_) {}

      debugPrint('[CloudSyncEngine] 🔄 Senkronizasyon sonrası tüm Riverpod UI sağlayıcıları yenilendi.');
    } catch (e) {
      debugPrint('[CloudSyncEngine] invalidateAllUiProviders error: $e');
    }
  }

  /// Cihaz için kalıcı benzersiz kimlik (UUID)
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('CloudSync_DeviceId');
    if (id == null || id.isEmpty) {
      final rand = Random.secure();
      final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
      id = sha256.convert(bytes).toString().substring(0, 16);
      await prefs.setString('CloudSync_DeviceId', id);
    }
    return id;
  }

  /// Kullanıcı dostu cihaz adı (Telefon / Tablet / PC)
  String getDeviceName() {
    if (Platform.isAndroid) return 'Android Cihaz';
    if (Platform.isIOS) return 'Apple Cihaz';
    if (Platform.isWindows) return 'Windows Masaüstü';
    if (Platform.isMacOS) return 'macOS Bilgisayar';
    if (Platform.isLinux) return 'Linux Bilgisayar';
    return 'Zikirce Cihazı';
  }

  /// 1. Yerel Güvenlik Kopyası Al (Snapshot Pre-Sync Shadow Copy)
  Future<void> takeLocalSafetySnapshot(AppDatabase db, String? sessionId) async {
    try {
      final driveService = GoogleDriveBackupService(db: db, sessionId: sessionId);
      final json = await driveService.createBackupJson();
      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/Zikirce_SafetySnapshot_PreSync.json');
      await file.writeAsString(json, encoding: utf8);
      debugPrint('[CloudSyncEngine] 🛡️ Yerel güvenlik kopyası alındı: ${file.path}');
    } catch (e) {
      debugPrint('[CloudSyncEngine] Yerel güvenlik kopyası uyarısı: $e');
    }
  }

  /// 2. Debounced Otomatik Yükleme Tetikleyici (2-3 saniye bekleme, hafif push)
  void triggerDebouncedSync(dynamic ref, {Duration delay = const Duration(seconds: 3)}) {
    try {
      _safeRead(ref, cloudSyncProvider.notifier)?.markPendingChanges();
    } catch (e) {
      debugPrint('[CloudSyncEngine] triggerDebouncedSync markPendingChanges notice: $e');
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      try {
        final timerRef = _resolveRef(ref);
        pushCurrentState(timerRef, rotateSnapshot: false);
      } catch (e, st) {
        debugPrint('[CloudSyncEngine] Debounce timer push notice: $e\n$st');
      }
    });
  }

  /// 3. Yaşam Döngüsü: Uygulama Açıldığında / Ön Plana Geldiğinde (App Resume)
  Future<void> syncOnAppResume(dynamic ref) async {
    try {
      final effectiveRef = _resolveRef(ref);
      debugPrint('[CloudSyncEngine] App Resumed -> Sessiz bulut senkronizasyonu denetleniyor...');
      await pullAndMerge(effectiveRef, isBackground: true);
    } catch (e) {
      debugPrint('[CloudSyncEngine] syncOnAppResume uyarısı: $e');
    }
  }

  /// Arka planda periyodik bulut kontrolü (Her 5 dakikada bir)
  void startPeriodicSync(dynamic ref) {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      try {
        final effectiveRef = _resolveRef(ref);
        pullAndMerge(effectiveRef, isBackground: true);
      } catch (e) {
        debugPrint('[CloudSyncEngine] Periodic sync notice: $e');
      }
    });
  }

  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  /// 4. Yaşam Döngüsü: Uygulamadan Çıkıldığında / Arka Plana Atıldığında (App Pause)
  Future<void> syncOnAppPause(dynamic ref) async {
    try {
      final effectiveRef = _resolveRef(ref);
      final hasPending = _safeRead(effectiveRef, cloudSyncProvider)?.hasPendingChanges ?? false;
      if (_debounceTimer?.isActive == true || hasPending) {
        _debounceTimer?.cancel();
        debugPrint('[CloudSyncEngine] App Paused -> Bekleyen değişiklikler buluta anında gönderiliyor...');
        if (effectiveRef != null) {
          await pushCurrentState(effectiveRef, rotateSnapshot: false);
        }
      }
    } catch (e) {
      debugPrint('[CloudSyncEngine] syncOnAppPause uyarısı: $e');
    }
  }

  /// 5. Buluttan İndir ve Akıllı Birleştir (Pull & Merge)
  Future<bool> pullAndMerge(dynamic ref, {bool force = false, bool isBackground = false}) async {
    if (_isSyncInProgress) {
      debugPrint('[CloudSyncEngine] Senkronizasyon zaten çalışıyor, atlandı.');
      return false;
    }

    CloudSyncNotifier? notifier;
    try {
      final effectiveRef = _resolveRef(ref);
      if (effectiveRef == null) return false;

      final db = _safeRead(effectiveRef, databaseProvider);
      final activeSession = _safeRead(effectiveRef, activeSessionProvider);
      final driveService = _safeRead(effectiveRef, googleDriveBackupServiceProvider);
      notifier = _safeRead(effectiveRef, cloudSyncProvider.notifier);

      if (db == null || activeSession == null || driveService == null || notifier == null) {
        debugPrint('[CloudSyncEngine] pullAndMerge: Gerekli sağlayıcılar okunamadı.');
        return false;
      }

      final isSignedIn = await driveService.isSignedIn();
      if (!isSignedIn) {
        debugPrint('[CloudSyncEngine] Google hesabı bağlı değil, senkronizasyon atlandı.');
        return false;
      }

      _isSyncInProgress = true;
      notifier.setStatus(CloudSyncStatus.checking);

      final token = await driveService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        notifier.setStatus(CloudSyncStatus.idle);
        _isSyncInProgress = false;
        return false;
      }

      final dio = Dio();

      // A. Drive AppData klasöründeki aktif senkronizasyon dosyasını sorgula
      final searchRes = await dio.get(
        GoogleDriveBackupService.driveFilesEndpoint,
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': "name = '$syncFileName' and 'appDataFolder' in parents and trashed = false",
          'fields': 'files(id, name, modifiedTime, size, md5Checksum)',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (searchRes.statusCode != 200 || searchRes.data == null) {
        notifier.setStatus(CloudSyncStatus.idle);
        _isSyncInProgress = false;
        return false;
      }

      final files = searchRes.data['files'] as List?;
      if (files == null || files.isEmpty) {
        debugPrint('[CloudSyncEngine] Bulutta henüz senkronizasyon dosyası yok. İlk durum gönderilecek.');
        _isSyncInProgress = false;
        await pushCurrentState(effectiveRef, rotateSnapshot: true);
        return true;
      }

      final remoteFile = files.first as Map<String, dynamic>;
      final remoteFileId = remoteFile['id']?.toString() ?? '';
      if (remoteFileId.isNotEmpty) {
        _cachedSyncFileId = remoteFileId;
      }
      final remoteModifiedStr = remoteFile['modifiedTime']?.toString();
      final remoteModified = remoteModifiedStr != null ? DateTime.tryParse(remoteModifiedStr) : null;

      final prefs = await SharedPreferences.getInstance();
      final lastLocalSyncMs = prefs.getInt('CloudSync_LastRemoteSyncTimeMs') ?? 0;

      // Eğer uzaktaki dosya yereldeki son senkronizasyondan daha yeniyse indir ve birleştir
      if (force || remoteModified == null || remoteModified.millisecondsSinceEpoch > lastLocalSyncMs) {
        notifier.setStatus(CloudSyncStatus.syncing);
        debugPrint('[CloudSyncEngine] Bulutta yeni veri bulundu ($remoteModified). İndiriliyor...');

        final downloadUrl = '${GoogleDriveBackupService.driveFilesEndpoint}/$remoteFileId?alt=media';
        final downloadRes = await dio.get(
          downloadUrl,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            responseType: ResponseType.plain,
          ),
        );

        if (downloadRes.statusCode == 200 && downloadRes.data != null) {
          final jsonContent = downloadRes.data.toString();
          final parsed = jsonDecode(jsonContent);

          if (parsed is Map<String, dynamic>) {
            final remoteDeviceId = parsed['SyncMetadata']?['DeviceId']?.toString();
            final remoteDeviceName = parsed['SyncMetadata']?['DeviceName']?.toString() ?? 'Diğer Cihaz';
            final myDeviceId = await getDeviceId();

            // Kendi cihazımızın yüklediği aynı dosyayı tekrar birleştirmeyi atla
            if (remoteDeviceId != myDeviceId || force) {
              // 1. Önce yerel güvenlik kopyası al
              await takeLocalSafetySnapshot(db, activeSession.id);

              // 2. Akıllı Delta Uzlaştırmasını çalıştır
              final success = await DataReconciliationService.smartMergeCloudPayload(
                db,
                parsed,
                sessionId: activeSession.id,
              );

              if (success) {
                final nowMs = remoteModified?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
                await prefs.setInt('CloudSync_LastRemoteSyncTimeMs', nowMs);
                await prefs.setInt('CloudSync_LastSyncTimestamp', DateTime.now().millisecondsSinceEpoch);
                await prefs.setString('CloudSync_LastSyncedDevice', remoteDeviceName);

                notifier.setStatus(
                  CloudSyncStatus.success,
                  device: remoteDeviceName,
                );

                // Riverpod UI sağlayıcılarını otomatik yenile
                invalidateAllUiProviders(effectiveRef);

                // 3. Birleşmiş nihai durumu buluta geri yaz (tam çift yönlü mutabakat)
                await pushCurrentState(effectiveRef, rotateSnapshot: false);
                debugPrint('[CloudSyncEngine] ✅ $remoteDeviceName ile senkronizasyon başarıyla tamamlandı.');
                return true;
              }
            } else {
              debugPrint('[CloudSyncEngine] Buluttaki son veri zaten bu cihaza ait ($myDeviceId).');
              if (remoteModified != null) {
                await prefs.setInt('CloudSync_LastRemoteSyncTimeMs', remoteModified.millisecondsSinceEpoch);
              }
            }
          }
        }
      } else {
        debugPrint('[CloudSyncEngine] Buluttaki veri güncel, yerel veri ile eşit.');
      }

      notifier.setStatus(CloudSyncStatus.idle);
      return true;
    } catch (e, st) {
      debugPrint('[CloudSyncEngine] pullAndMerge hatası: $e\n$st');
      notifier?.setStatus(CloudSyncStatus.error, error: e.toString());
      return false;
    } finally {
      _isSyncInProgress = false;
    }
  }

  /// 6. Yerel Durumu Buluta Gönder (Push Current State)
  Future<bool> pushCurrentState(dynamic ref, {bool rotateSnapshot = false}) async {
    CloudSyncNotifier? notifier;
    try {
      final effectiveRef = _resolveRef(ref);
      if (effectiveRef == null) return false;

      final driveService = _safeRead(effectiveRef, googleDriveBackupServiceProvider);
      notifier = _safeRead(effectiveRef, cloudSyncProvider.notifier);

      if (driveService == null || notifier == null) {
        debugPrint('[CloudSyncEngine] pushCurrentState: Gerekli sağlayıcılar okunamadı.');
        return false;
      }

      final isSignedIn = await driveService.isSignedIn();
      if (!isSignedIn) return false;

      notifier.setStatus(CloudSyncStatus.syncing);

      final token = await driveService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        notifier.setStatus(CloudSyncStatus.idle);
        return false;
      }

      final dio = Dio();
      final myDeviceId = await getDeviceId();
      final myDeviceName = getDeviceName();

      // 1. Yerel veritabanı JSON'ını üret
      final baseJsonStr = await driveService.createBackupJson();
      final data = jsonDecode(baseJsonStr) as Map<String, dynamic>;

      // 2. Senkronizasyon Meta Bilgilerini Ekle
      data['SyncMetadata'] = {
        'DeviceId': myDeviceId,
        'DeviceName': myDeviceName,
        'Timestamp': DateTime.now().toIso8601String(),
        'TimestampMs': DateTime.now().millisecondsSinceEpoch,
        'Version': 2,
      };

      final payloadJson = jsonEncode(data);

      // 3. Buluttaki Zikirce_CloudSync.json dosyasını güncelle (Önce önbellekteki FileId ile PATCH)
      String? targetFileId = _cachedSyncFileId;

      if (targetFileId == null || targetFileId.isEmpty) {
        final searchRes = await dio.get(
          GoogleDriveBackupService.driveFilesEndpoint,
          queryParameters: {
            'spaces': 'appDataFolder',
            'q': "name = '$syncFileName' and 'appDataFolder' in parents and trashed = false",
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        if (searchRes.statusCode == 200 && searchRes.data != null) {
          final files = searchRes.data['files'] as List?;
          if (files != null && files.isNotEmpty) {
            targetFileId = files.first['id']?.toString();
            _cachedSyncFileId = targetFileId;
          }
        }
      }

      bool patchSuccess = false;
      if (targetFileId != null && targetFileId.isNotEmpty) {
        try {
          final patchRes = await dio.patch(
            '${GoogleDriveBackupService.driveUploadEndpoint}/$targetFileId?uploadType=media',
            data: payloadJson,
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json; charset=UTF-8',
              },
            ),
          );
          if (patchRes.statusCode == 200) {
            patchSuccess = true;
            debugPrint('[CloudSyncEngine] Zikirce_CloudSync.json hızlı PATCH ile güncellendi: $targetFileId');
          }
        } catch (e) {
          debugPrint('[CloudSyncEngine] Cached PATCH uyarısı (yeniden aranacak): $e');
          _cachedSyncFileId = null;
        }
      }

      if (!patchSuccess) {
        await _uploadMultipart(dio, token, syncFileName, payloadJson);
        debugPrint('[CloudSyncEngine] Zikirce_CloudSync.json ilk kez oluşturuldu.');
      }

      // 4. Tarih Damgalı Snapshot Oluştur & Son 10 Yedeği Koru (Rolling 10 Snapshots - Yalnızca istendiğinde)
      if (rotateSnapshot) {
        final now = DateTime.now();
        final nowStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
        final snapshotName = '$snapshotPrefix${nowStr}_$myDeviceId.json';
        await _uploadMultipart(dio, token, snapshotName, payloadJson);

        // Eski snapshotları temizle (10'dan fazlasını sil)
        await _cleanupOldSnapshots(dio, token);
      }

      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('CloudSync_LastRemoteSyncTimeMs', nowMs);
      await prefs.setInt('CloudSync_LastSyncTimestamp', nowMs);
      await prefs.setString('CloudSync_LastSyncedDevice', myDeviceName);

      notifier.clearPendingChanges();
      notifier.setStatus(CloudSyncStatus.success, device: myDeviceName);
      debugPrint('[CloudSyncEngine] ✅ Bulut yedekleme başarıyla yüklendi ($myDeviceName).');
      return true;
    } catch (e, st) {
      debugPrint('[CloudSyncEngine] pushCurrentState hatası: $e\n$st');
      notifier?.setStatus(CloudSyncStatus.error, error: e.toString());
      return false;
    }
  }

  /// 7. Snapshot Listesini Getir (Son 10 Geri Dönüş Noktası)
  Future<List<CloudBackupInfo>> listRollbackSnapshots(dynamic ref) async {
    final effectiveRef = _resolveRef(ref);
    if (effectiveRef == null) return [];

    final driveService = _safeRead(effectiveRef, googleDriveBackupServiceProvider);
    if (driveService == null) return [];

    final token = await driveService.getValidAccessToken();
    if (token == null || token.isEmpty) return [];

    try {
      final dio = Dio();
      final res = await dio.get(
        GoogleDriveBackupService.driveFilesEndpoint,
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': "name contains '$snapshotPrefix' and 'appDataFolder' in parents and trashed = false",
          'fields': 'files(id, name, modifiedTime, size)',
          'orderBy': 'createdTime desc',
          'pageSize': 15,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final list = <CloudBackupInfo>[];
      if (res.statusCode == 200 && res.data != null) {
        final files = res.data['files'] as List?;
        if (files != null) {
          for (final f in files) {
            final fileId = f['id']?.toString() ?? '';
            final fileName = f['name']?.toString() ?? '';
            final modStr = f['modifiedTime']?.toString();
            final dt = modStr != null ? DateTime.tryParse(modStr) ?? DateTime.now() : DateTime.now();
            final size = int.tryParse(f['size']?.toString() ?? '0');

            list.add(
              CloudBackupInfo(
                fileId: fileId,
                fileName: fileName,
                modifiedTime: dt,
                deviceName: fileName.contains('_') ? 'Yedek Snapshot' : 'Bulut Yedeği',
                displayName: '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                sizeBytes: size,
              ),
            );
          }
        }
      }
      return list;
    } catch (e) {
      debugPrint('[CloudSyncEngine] listRollbackSnapshots hatası: $e');
      return [];
    }
  }

  /// 8. Seçilen Tarihli Snapshot'ı Geri Yükle
  Future<bool> restoreRollbackSnapshot(dynamic ref, String fileId) async {
    final effectiveRef = _resolveRef(ref);
    if (effectiveRef == null) return false;

    final driveService = _safeRead(effectiveRef, googleDriveBackupServiceProvider);
    if (driveService == null) return false;

    final count = await driveService.restoreFromCloud(fileId: fileId);
    return count > 0;
  }

  // --- YARDIMCI METOTLAR ---

  Future<void> _uploadMultipart(Dio dio, String token, String filename, String content) async {
    final boundary = '----WebKitFormBoundary${DateTime.now().millisecondsSinceEpoch}';
    final metadataJson = jsonEncode({
      'name': filename,
      'parents': ['appDataFolder'],
    });

    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadataJson\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$content\r\n'
        '--$boundary--\r\n';

    await dio.post(
      '${GoogleDriveBackupService.driveUploadEndpoint}?uploadType=multipart',
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
      ),
    );
  }

  Future<void> _cleanupOldSnapshots(Dio dio, String token) async {
    try {
      final res = await dio.get(
        GoogleDriveBackupService.driveFilesEndpoint,
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': "name contains '$snapshotPrefix' and 'appDataFolder' in parents and trashed = false",
          'fields': 'files(id, name, createdTime)',
          'orderBy': 'createdTime desc',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (res.statusCode == 200 && res.data != null) {
        final files = res.data['files'] as List?;
        if (files != null && files.length > maxSnapshots) {
          for (int i = maxSnapshots; i < files.length; i++) {
            final oldId = files[i]['id']?.toString();
            if (oldId != null && oldId.isNotEmpty) {
              await dio.delete(
                '${GoogleDriveBackupService.driveFilesEndpoint}/$oldId',
                options: Options(headers: {'Authorization': 'Bearer $token'}),
              );
              debugPrint('[CloudSyncEngine] 10 kuralı gereği eski snapshot silindi: $oldId');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[CloudSyncEngine] Snapshot temizleme uyarısı: $e');
    }
  }
}
