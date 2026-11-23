import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasibu/core/database/hasibu_database.dart';
import 'package:hasibu/features/pdks/data/workplace_seed_data.dart';
import 'package:hasibu/features/pdks/domain/pdks_models.dart';
import 'package:hasibu/features/pdks/presentation/providers/pdks_providers.dart';
import 'package:hasibu/main.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
      'Release branch, department & shift skeletons contain zero personal or private workplace data',
      () {
    expect(WorkplaceSeedData.releaseBranches, hasLength(1));
    expect(WorkplaceSeedData.releaseDepartments, hasLength(1));
    expect(WorkplaceSeedData.releaseShifts, hasLength(1));

    final b = WorkplaceSeedData.releaseBranches.first;
    expect(b.code, equals('MERKEZ'));
    expect(b.name, equals('Merkez Şube'));
    expect(b.hasTerminal, isFalse);
    expect(b.terminalIp ?? '', isEmpty);
    expect(b.terminalCommKey, equals(0));
    expect(b.latitude, equals(0.0));
    expect(b.longitude, equals(0.0));
    expect(
      const ['DEVTEYSTI', 'YENISEHIR', 'KARAKOPRU'],
      isNot(contains(b.code)),
    );
  });

  testWidgets(
      'Empty zero-state database renders login screen & admin dashboard cleanly without personal seed rows',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final db = HasibuDatabase.inMemory();
    addTearDown(db.dispose);

    // Simulate a clean !kDebugMode database: wipe employees/logs/leaves/docs/requests
    // and replace branches/departments/shifts with the neutral 1-item release skeleton.
    final Database raw = db.rawDb;
    raw.execute('DELETE FROM attendance_logs;');
    raw.execute('DELETE FROM leave_records;');
    raw.execute('DELETE FROM employee_documents;');
    raw.execute('DELETE FROM hr_requests;');
    raw.execute('DELETE FROM employees;');
    raw.execute('DELETE FROM branches;');
    raw.execute('DELETE FROM departments;');
    raw.execute('DELETE FROM shifts;');
    for (final b in WorkplaceSeedData.releaseBranches) {
      db.upsertBranch(b);
    }
    for (final d in WorkplaceSeedData.releaseDepartments) {
      db.upsertDepartment(d);
    }
    for (final s in WorkplaceSeedData.releaseShifts) {
      db.upsertShift(s);
    }

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasibuDatabaseProvider.overrideWithValue(db),
        ],
        child: const HasibuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login_submit_button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('login_first_setup_info_card')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('login_fill_initial_admin_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('force_admin_password_dialog')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('force_admin_new_password_field')),
      'Admin#2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('force_admin_confirm_password_field')),
      'Admin#2026',
    );
    await tester.tap(
      find.byKey(const ValueKey('force_admin_password_submit_button')),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final dashState = container.read(pdksDashboardProvider);
    expect(dashState.authSession.isAuthenticated, isTrue);
    expect(dashState.authSession.role, equals(UserRole.admin));
    expect(dashState.dailyStatuses, isEmpty);
    expect(dashState.branches, hasLength(1));
    expect(dashState.departments, hasLength(1));
    expect(dashState.shifts, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
