import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/zikir_seed_data.dart';
import '../services/data_reconciliation_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/widget_sync_service.dart';
import '../session/session_providers.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final activeSession = ref.watch(activeSessionProvider);
  final db = AppDatabase(null, activeSession.dbFileName);
  ref.onDispose(() => db.close());

  // Non-blocking deferred dispatch to allow UI isolate to render initial frame
  // and satisfy OS watchdog deadlines before background reconciliation
  Future.delayed(const Duration(milliseconds: 1500), () async {
    try {
      await ZikirSeedData.ensureAllDefaultZikirsExist(db);
      await DataReconciliationService.reconcileAll(db, activeSession.id);
      await WidgetSyncService.syncAll(db, sessionId: activeSession.id);
      if (activeSession.isCloud) {
        GoogleDriveBackupService.triggerAutoBackupBackground(db, force: false, sessionId: activeSession.id);
      }
    } catch (_) {}
  });

  return db;
});
