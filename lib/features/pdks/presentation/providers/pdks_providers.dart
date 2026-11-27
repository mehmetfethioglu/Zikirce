import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/hasibu_database.dart';
import '../../../../core/database/hasibu_pdks_schedule_dao.dart';
import '../../../../core/security/hasibu_security_service.dart';
import '../../../../core/security/license_guard_service.dart';
import '../../../../core/services/company_logo_service.dart';
import '../../../../core/services/google_auth_adapter.dart';
import '../../../../core/services/google_drive_sync_service.dart';
import '../../../../core/services/hasibu_print_service.dart';
import '../../../../core/services/login_preferences_service.dart';
import '../../../../core/services/password_recovery_service.dart';
import '../../data/tenfei_zk_client.dart';
import '../../data/workplace_seed_data.dart';
import '../../domain/attendance_evaluation_engine.dart';
import '../../domain/attendance_report_engine.dart';
import '../../domain/employee_bulk_import_engine.dart';
import '../../domain/mobile_checkin_gateway.dart';
import '../../domain/pdks_models.dart';
import 'pdks_dashboard_state.dart';

export 'pdks_dashboard_state.dart';

final hasibuDatabaseProvider = Provider<HasibuDatabase>((ref) {
  final db = HasibuDatabase.inMemory();
  ref.onDispose(db.dispose);
  return db;
});

final hasibuPrintGatewayProvider = Provider<HasibuPrintGateway>((ref) {
  return PlatformHasibuPrintGateway();
});

final companyLogoPickerGatewayProvider = Provider<CompanyLogoPickerGateway>((
  ref,
) {
  return PlatformCompanyLogoPickerGateway();
});

final mobileLocationGatewayProvider = Provider<MobileLocationGateway>((ref) {
  return const BranchFallbackLocationGateway();
});

final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  final db = ref.watch(hasibuDatabaseProvider);
  return GoogleDriveSyncService(db: db);
});

final googleAuthAdapterProvider = Provider<GoogleAuthAdapter>((ref) {
  final sync = ref.watch(googleDriveSyncServiceProvider);
  return createPlatformGoogleAuthAdapter(sync);
});

final loginPreferencesServiceProvider = Provider<LoginPreferencesService>(
  (ref) => const LoginPreferencesService(),
);

final passwordRecoveryEmailGatewayProvider =
    Provider<PasswordRecoveryEmailGateway>(
  (ref) => GmailApiPasswordRecoveryGateway(),
);

final passwordRecoveryServiceProvider = Provider<PasswordRecoveryService>((ref) {
  final gateway = ref.watch(passwordRecoveryEmailGatewayProvider);
  return PasswordRecoveryService(emailGateway: gateway);
});

class PdksDashboardNotifier extends StateNotifier<PdksDashboardState> {
  final HasibuDatabase _db;
  final GoogleDriveSyncService _syncService;
  final GoogleAuthAdapter _googleAuthAdapter;
  final PasswordRecoveryService _passwordRecoveryService;
  Timer? _autoPollTimer;
  Timer? _autoCloudBackupTimer;
  Timer? _branchInboxPullTimer;
  Timer? _realtimeUploadDebounce;
  bool _isPullingBranchInboxes = false;
  final Map<int, TenfeiZkClient> _activeClients = <int, TenfeiZkClient>{};
  final List<StreamSubscription<AttendanceLog>> _realtimeSubs =
      <StreamSubscription<AttendanceLog>>[];

  PdksDashboardNotifier({
    required HasibuDatabase db,
    required GoogleDriveSyncService syncService,
    GoogleAuthAdapter? googleAuthAdapter,
    PasswordRecoveryService? passwordRecoveryService,
    String? initialSelectedDate,
  })  : _db = db,
        _syncService = syncService,
        _googleAuthAdapter =
            googleAuthAdapter ?? createPlatformGoogleAuthAdapter(syncService),
        _passwordRecoveryService = passwordRecoveryService ??
            PasswordRecoveryService(
              emailGateway: GmailApiPasswordRecoveryGateway(),
            ),
        super(
          PdksDashboardState(
            selectedDate: initialSelectedDate ?? todayDateKey(),
          ),
        ) {
    refreshDashboard();
    if (_googleAuthAdapter.isNativePlatform) {
      _syncService.setMobileTokenRefresher(
        () => _googleAuthAdapter.refreshAccessTokenSilently(),
      );
    }
    unawaited(restorePersistedGoogleSession());
    _configureAutoPollTimer();
    _configureAutoCloudBackupTimer();
    _configureBranchInboxPullTimer();
    if (!kDebugMode &&
        (state.dailyStatuses.isEmpty ||
            state.dailyStatuses.every(
              (s) => s.employee.fullName.startsWith('PERSONEL #'),
            ))) {
      unawaited(Future<void>.microtask(() => pullFromTenfeiTerminals()));
    }
  }

  static String formatDateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Bugünün gerçek sistem tarihini YYYY-MM-DD formatında döndürür (örn. 2026-10-22).
  static String todayDateKey() => formatDateKey(DateTime.now());

  /// YYYY-MM-DD tarih anahtarını GG.AA.YYYY formatına çevirir; bugüne eşitse "(Bugün)" ekler.
  static String formatDisplayDate(
    String dateKey, {
    bool includeTodayBadge = true,
  }) {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      final formatted =
          '${parts[2].padLeft(2, '0')}.${parts[1].padLeft(2, '0')}.${parts[0]}';
      if (includeTodayBadge && dateKey == todayDateKey()) {
        return '$formatted (Bugün)';
      }
      return formatted;
    }
    return dateKey;
  }

  List<int> get _scopedBranchIds => state.effectiveBranchScopeIds;

  bool get _isBranchScoped => _scopedBranchIds.isNotEmpty;

  bool _isBranchAllowed(int branchId) =>
      !_isBranchScoped || _scopedBranchIds.contains(branchId);

  bool _isEmployeeInScope(int employeeId) {
    if (!_isBranchScoped) return true;
    final scopedSet = _scopedBranchIds.toSet();
    for (final emp in _db.getEmployees()) {
      if (emp.id == employeeId) {
        return scopedSet.contains(emp.branchId);
      }
    }
    return false;
  }

  bool _isCardInScope(String cardNo) {
    if (!_isBranchScoped) return true;
    final scopedSet = _scopedBranchIds.toSet();
    final clean = cardNo.trim();
    final padded = clean.padLeft(5, '0');
    for (final emp in _db.getEmployees()) {
      if (emp.cardNo == clean || emp.cardNo == padded) {
        return scopedSet.contains(emp.branchId);
      }
    }
    return false;
  }

  static bool _isAuditLogInScope(
    AuditLogEntry entry, {
    required Set<int> scopedBranchIds,
    required Set<String> scopedCardNos,
    required Set<String> scopedRequestIds,
  }) {
    if (scopedCardNos.contains(entry.targetRecordId)) return true;
    for (final branchId in scopedBranchIds) {
      if (entry.targetRecordId.startsWith('branch_${branchId}_')) {
        return true;
      }
    }
    if (scopedRequestIds.contains(entry.targetRecordId)) return true;
    if (entry.actionType == 'MISSING_CHECKOUT_COMPLETED' &&
        scopedCardNos.contains(entry.targetRecordId.split('_').first)) {
      return true;
    }
    if (scopedCardNos.contains(entry.actorEmployeeId)) return true;
    return false;
  }

  /// Yönetici girişini değerlendirir; ilk kurulumdaki varsayılan yönetici parolası
  /// henüz güncellenmemişse oturumu açmadan parola güncelleme adımını zorunlu tutar.
  AdminLoginOutcome attemptAdminLogin({
    required String username,
    required String password,
  }) {
    final u = username.trim().toLowerCase();
    final p = password.trim();
    final expectedUser = state.companySettings.adminUsername.trim().toLowerCase();
    final expectedPass = state.companySettings.adminPassword;

    if (u == expectedUser &&
        HasibuSecurityService.verifyPassword(p, expectedPass) &&
        state.companySettings.requiresInitialAdminPasswordChange) {
      state = state.copyWith(
        authSession: state.authSession.copyWith(
          isAuthenticated: false,
          errorMessage: () => null,
        ),
      );
      return AdminLoginOutcome.requiresInitialPasswordUpdate;
    }

    final ok = loginAsAdmin(username: username, password: password);
    return ok ? AdminLoginOutcome.authenticated : AdminLoginOutcome.failed;
  }

  /// İlk kurulumdaki varsayılan yönetici parolasını güvenli PBKDF2 hash ile günceller,
  /// opsiyonel işletme adı ve logosunu kaydeder, ilk kurulum bilgisini kapatır ve yönetici oturumunu açar.
  Future<String?> completeInitialAdminPasswordUpdateAndLogin({
    required String username,
    required String currentPassword,
    required String newPassword,
    String? companyName,
    String? logoPath,
    String? logoDataBase64,
  }) async {
    final u = username.trim().toLowerCase();
    final current = currentPassword.trim();
    final next = newPassword.trim();
    final expectedUser = state.companySettings.adminUsername.trim().toLowerCase();
    final expectedPass = state.companySettings.adminPassword;

    if (u != expectedUser ||
        !HasibuSecurityService.verifyPassword(current, expectedPass)) {
      return 'Mevcut yönetici kullanıcı adı veya geçici parola doğrulanamadı.';
    }
    if (next.length < 6) {
      return 'Yeni yönetici parolası en az 6 karakter olmalıdır.';
    }
    if (next == CompanySettings.defaultAdminPassword) {
      return 'Güvenliğiniz için varsayılan geçici parola (123) kullanılamaz.';
    }
    if (next.toLowerCase() == expectedUser) {
      return 'Yeni parola yönetici kullanıcı adı ile aynı olamaz.';
    }

    final hashed = HasibuSecurityService.hashPassword(next);
    final cleanCompanyName = companyName?.trim();
    final hasLogoUpdate = logoPath != null || logoDataBase64 != null;
    final cleanLogoPath = logoPath?.trim();
    final cleanLogoBase64 = logoDataBase64?.trim();
    final updated = state.companySettings.copyWith(
      companyName: (cleanCompanyName != null && cleanCompanyName.isNotEmpty)
          ? cleanCompanyName
          : state.companySettings.companyName,
      logoPath: hasLogoUpdate
          ? () => (cleanLogoPath != null && cleanLogoPath.isNotEmpty)
              ? cleanLogoPath
              : null
          : null,
      logoDataBase64: hasLogoUpdate
          ? () => (cleanLogoBase64 != null && cleanLogoBase64.isNotEmpty)
              ? cleanLogoBase64
              : null
          : null,
      adminPassword: hashed,
      adminPasswordUpdated: true,
    );
    _db.saveCompanySettings(updated);
    _db.appendAuditLog(
      actorEmployeeId: expectedUser,
      actionType: 'ADMIN_INITIAL_PASSWORD_UPDATED',
      targetRecordId: expectedUser,
      oldValue: 'default_setup',
      newValue: 'updated_pbkdf2',
    );
    refreshDashboard();

    final ok = loginAsAdmin(username: username, password: next);
    if (!ok) {
      return 'Parola güncellendi ancak oturum başlatılamadı.';
    }

    if (state.isGoogleCloudConnected ||
        state.companySettings.syncFolderPath.trim().isNotEmpty) {
      unawaited(
        _pushAutoBackupOnChange('İlk Kurulum Yönetici Parola Güncellemesi'),
      );
    }
    return null;
  }

  /// Şifremi Unuttum akışı için kullanıcı adını/kart numarasını ve kayıtlı şirket Gmail'ini arar.
  /// `role` belirtilmezse önce Ana Yönetici, ardından Yetkili Kullanıcı ve Personel kartlarında otomatik arar.
  PasswordRecoveryAccountLookup lookupRecoverableAccount({
    required String identifier,
    UserRole? role,
  }) {
    final companyGmail = state.companySettings.syncGmailAccount.trim();
    final maskedGmail = PasswordRecoveryService.maskEmail(companyGmail);
    final hasGmail = companyGmail.isNotEmpty && companyGmail.contains('@');
    final rawIdentifier = identifier.trim();
    final cleanUser = rawIdentifier.toLowerCase();

    if (rawIdentifier.isEmpty) {
      return PasswordRecoveryAccountLookup(
        found: false,
        errorMessage: role == UserRole.employee
            ? 'Lütfen personel kart / sicil numaranızı girin.'
            : 'Lütfen kullanıcı adınızı veya personel kart numaranızı girin.',
      );
    }

    if (role == null || role == UserRole.admin) {
      final adminUser = state.companySettings.adminUsername.trim().toLowerCase();
      if (cleanUser == adminUser) {
        return PasswordRecoveryAccountLookup(
          found: true,
          hasCompanyGmail: hasGmail,
          normalizedUsername: cleanUser,
          displayName: state.companySettings.adminUsername,
          kind: RecoverableAccountKind.rootAdmin,
          resolvedRole: UserRole.admin,
          companyGmail: companyGmail,
          maskedCompanyGmail: maskedGmail,
          errorMessage: hasGmail
              ? null
              : 'Şirket Gmail hesabı henüz bağlı değil. Lütfen sağ üstteki bulut simgesinden veya Ayarlar bölümünden şirketin Gmail hesabını bağlayın.',
        );
      }

      final appUser = _db.findAppUserByUsername(cleanUser);
      if (appUser != null) {
        if (!appUser.isActive) {
          return PasswordRecoveryAccountLookup(
            found: false,
            errorMessage:
                'Kullanıcı hesabınız ($cleanUser) pasif durumda olduğu için parola sıfırlanamaz.',
          );
        }
        return PasswordRecoveryAccountLookup(
          found: true,
          hasCompanyGmail: hasGmail,
          normalizedUsername: appUser.username,
          displayName: appUser.displayName,
          kind: RecoverableAccountKind.appUser,
          resolvedRole: appUser.role.baseRole,
          companyGmail: companyGmail,
          maskedCompanyGmail: maskedGmail,
          errorMessage: hasGmail
              ? null
              : 'Şirket Gmail hesabı henüz bağlı değil. Lütfen sağ üstteki bulut simgesinden veya Ayarlar bölümünden şirketin Gmail hesabını bağlayın.',
        );
      }

      if (role == UserRole.admin) {
        return const PasswordRecoveryAccountLookup(
          found: false,
          errorMessage: 'Bu kullanıcı adına ait kayıtlı bir hesap bulunamadı.',
        );
      }
    }

    final isNumericCard = RegExp(r'^\d+$').hasMatch(rawIdentifier);
    final paddedCard = isNumericCard ? rawIdentifier.padLeft(5, '0') : rawIdentifier;
    Employee? matchedEmp;
    for (final e in _db.getEmployees()) {
      if (e.cardNo.toLowerCase() == cleanUser || e.cardNo == paddedCard) {
        matchedEmp = e;
        break;
      }
    }
    if (matchedEmp == null) {
      return PasswordRecoveryAccountLookup(
        found: false,
        errorMessage: role == UserRole.employee
            ? 'Personel Kart No (#$paddedCard) bulunamadı.'
            : 'Bu kullanıcı adı veya kart numarasına ait kayıtlı bir hesap bulunamadı.',
      );
    }
    if (matchedEmp.isSeparatedNow) {
      return PasswordRecoveryAccountLookup(
        found: false,
        errorMessage:
            'Personel #${matchedEmp.cardNo} için işten ayrılış kaydı bulunduğu için parola sıfırlanamaz.',
      );
    }
    return PasswordRecoveryAccountLookup(
      found: true,
      hasCompanyGmail: hasGmail,
      normalizedUsername: matchedEmp.cardNo,
      displayName: matchedEmp.fullName,
      kind: RecoverableAccountKind.employee,
      resolvedRole: UserRole.employee,
      companyGmail: companyGmail,
      maskedCompanyGmail: maskedGmail,
      errorMessage: hasGmail
          ? null
          : 'Şirket Gmail hesabı henüz bağlı değil. Parola sıfırlama için yöneticinizden şirket Gmail hesabını bağlamasını isteyin.',
    );
  }

  /// Kullanıcı adı doğrulandıktan sonra şirketin kayıtlı Gmail hesabına 6 haneli tek kullanımlık
  /// doğrulama kodu gönderir; Gmail API kapalı veya yetki eksikse Google OAuth sahiplik doğrulaması önerir.
  Future<PasswordRecoverySendOutcome> sendPasswordResetCodeToCompanyGmail({
    required String identifier,
    UserRole? role,
    bool allowIncrementalConsent = true,
  }) async {
    final lookup = lookupRecoverableAccount(identifier: identifier, role: role);
    if (!lookup.found || !lookup.hasCompanyGmail) {
      return PasswordRecoverySendOutcome(
        success: false,
        maskedEmail: lookup.maskedCompanyGmail,
        message: lookup.errorMessage ?? 'Hesap veya şirket Gmail adresi bulunamadı.',
      );
    }
    final effectiveRole = role ?? lookup.resolvedRole ?? UserRole.admin;

    final challenge = _passwordRecoveryService.createChallenge(
      username: lookup.normalizedUsername,
      role: effectiveRole,
      targetEmail: lookup.companyGmail,
    );
    if (!challenge.ok) {
      return PasswordRecoverySendOutcome(
        success: false,
        maskedEmail: lookup.maskedCompanyGmail,
        message: challenge.message,
      );
    }

    String? accessToken;
    try {
      accessToken = await _syncService.getAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) {
        accessToken = await _syncService.refreshAccessToken();
      }
    } catch (e) {
      debugPrint('PdksProviders: şifre kurtarma token okuma uyarısı: $e');
    }

    PasswordResetEmailResult? emailResult;
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      emailResult = await _passwordRecoveryService.sendChallengeEmail(
        accessToken: accessToken.trim(),
        recipientEmail: lookup.companyGmail,
        companyName: state.companySettings.displayCompanyNameForLogin,
        targetUsername: lookup.normalizedUsername,
        verificationCode: challenge.code,
      );

      if (emailResult.errorCode == PasswordResetEmailErrorCode.unauthorized) {
        try {
          final refreshed = await _syncService.refreshAccessToken();
          if (refreshed != null && refreshed.trim().isNotEmpty) {
            emailResult = await _passwordRecoveryService.sendChallengeEmail(
              accessToken: refreshed.trim(),
              recipientEmail: lookup.companyGmail,
              companyName: state.companySettings.displayCompanyNameForLogin,
              targetUsername: lookup.normalizedUsername,
              verificationCode: challenge.code,
            );
          }
        } catch (e) {
          debugPrint('PdksProviders: şifre kurtarma token yenileme uyarısı: $e');
        }
      }
    }

    final needsIncrementalConsent = emailResult == null ||
        emailResult.errorCode == PasswordResetEmailErrorCode.unauthorized ||
        emailResult.errorCode == PasswordResetEmailErrorCode.insufficientScope;

    if (needsIncrementalConsent && allowIncrementalConsent) {
      final authRes = await _googleAuthAdapter.signIn(
        loginHintEmail: lookup.companyGmail,
        extraScopes: const <String>[PasswordRecoveryService.gmailSendScope],
      );
      if (!authRes.success) {
        _passwordRecoveryService.clearChallenge();
        return PasswordRecoverySendOutcome(
          success: false,
          canUseGoogleIdentityFallback: true,
          maskedEmail: lookup.maskedCompanyGmail,
          message: authRes.message,
        );
      }

      final signedEmail = authRes.email.trim().toLowerCase();
      if (signedEmail.isNotEmpty &&
          signedEmail != lookup.companyGmail.toLowerCase()) {
        _passwordRecoveryService.clearChallenge();
        return PasswordRecoverySendOutcome(
          success: false,
          maskedEmail: lookup.maskedCompanyGmail,
          message:
              'Şirket Gmail hesabı (${lookup.maskedCompanyGmail}) ile eşleşen Google hesabıyla oturum açmalısınız.',
        );
      }

      if (authRes.accessToken.trim().isNotEmpty) {
        try {
          await _syncService.saveOAuthTokens(
            accessToken: authRes.accessToken,
            refreshToken: authRes.refreshToken.trim().isEmpty
                ? null
                : authRes.refreshToken,
          );
        } catch (e) {
          debugPrint('PdksProviders: saveOAuthTokens kurtarma uyarısı: $e');
        }
        emailResult = await _passwordRecoveryService.sendChallengeEmail(
          accessToken: authRes.accessToken.trim(),
          recipientEmail: lookup.companyGmail,
          companyName: state.companySettings.displayCompanyNameForLogin,
          targetUsername: lookup.normalizedUsername,
          verificationCode: challenge.code,
        );
      }
    }

    if (emailResult == null || !emailResult.success) {
      _passwordRecoveryService.clearChallenge();
      final code = emailResult?.errorCode ?? PasswordResetEmailErrorCode.networkOrOther;
      final allowFallback = code == PasswordResetEmailErrorCode.apiDisabled ||
          code == PasswordResetEmailErrorCode.insufficientScope ||
          code == PasswordResetEmailErrorCode.unauthorized;
      return PasswordRecoverySendOutcome(
        success: false,
        canUseGoogleIdentityFallback: allowFallback,
        maskedEmail: lookup.maskedCompanyGmail,
        message: emailResult?.message ??
            'Doğrulama kodu e-postası gönderilemedi.',
      );
    }

    _db.appendAuditLog(
      actorEmployeeId: lookup.normalizedUsername,
      actionType: 'PASSWORD_RESET_CODE_SENT',
      targetRecordId: lookup.normalizedUsername,
      oldValue: 'requested',
      newValue: 'email=${lookup.maskedCompanyGmail}',
    );
    refreshDashboard();

    return PasswordRecoverySendOutcome(
      success: true,
      maskedEmail: lookup.maskedCompanyGmail,
      expiresInMinutes: PasswordRecoveryService.codeValidity.inMinutes,
      message:
          '6 haneli doğrulama kodu şirketin Gmail hesabına (${lookup.maskedCompanyGmail}) gönderildi.',
    );
  }

  /// Gmail API etkin olmayan durumlarda şirketin kayıtlı Gmail hesabını canlı Google OAuth ile doğrular.
  Future<PasswordRecoveryVerifyOutcome>
      verifyCompanyGmailOwnershipViaGoogleOAuth({
    required String identifier,
    UserRole? role,
  }) async {
    final lookup = lookupRecoverableAccount(identifier: identifier, role: role);
    if (!lookup.found || !lookup.hasCompanyGmail) {
      return PasswordRecoveryVerifyOutcome(
        success: false,
        maskedEmail: lookup.maskedCompanyGmail,
        message: lookup.errorMessage ?? 'Hesap veya şirket Gmail adresi bulunamadı.',
      );
    }
    final effectiveRole = role ?? lookup.resolvedRole ?? UserRole.admin;

    final authRes = await _googleAuthAdapter.signIn(
      loginHintEmail: lookup.companyGmail,
    );
    if (!authRes.success) {
      return PasswordRecoveryVerifyOutcome(
        success: false,
        maskedEmail: lookup.maskedCompanyGmail,
        message: authRes.message,
      );
    }

    final verifiedEmail = authRes.email.trim().toLowerCase();
    if (verifiedEmail.isEmpty ||
        verifiedEmail != lookup.companyGmail.toLowerCase()) {
      return PasswordRecoveryVerifyOutcome(
        success: false,
        maskedEmail: lookup.maskedCompanyGmail,
        message:
            'Doğrulanan Google hesabı şirketin kayıtlı Gmail adresi (${lookup.maskedCompanyGmail}) ile eşleşmiyor.',
      );
    }

    if (authRes.accessToken.trim().isNotEmpty) {
      try {
        await _syncService.saveOAuthTokens(
          accessToken: authRes.accessToken,
          refreshToken:
              authRes.refreshToken.trim().isEmpty ? null : authRes.refreshToken,
        );
      } catch (e) {
        debugPrint('PdksProviders: OAuth sahiplik doğrulama token uyarısı: $e');
      }
    }

    _passwordRecoveryService.markVerifiedByGoogleOAuth(
      username: lookup.normalizedUsername,
      role: effectiveRole,
      verifiedEmail: verifiedEmail,
    );
    _db.appendAuditLog(
      actorEmployeeId: lookup.normalizedUsername,
      actionType: 'PASSWORD_RESET_GOOGLE_VERIFIED',
      targetRecordId: lookup.normalizedUsername,
      oldValue: 'unverified',
      newValue: 'email=${lookup.maskedCompanyGmail}',
    );
    refreshDashboard();

    return PasswordRecoveryVerifyOutcome(
      success: true,
      maskedEmail: lookup.maskedCompanyGmail,
      message:
          'Şirket Gmail hesabı (${lookup.maskedCompanyGmail}) doğrulandı. Yeni parolanızı belirleyebilirsiniz.',
    );
  }

  /// Doğrulama kodu veya Google OAuth doğrulaması onaylandıktan sonra yeni parolayı kaydeder.
  Future<String?> completePasswordReset({
    required String identifier,
    UserRole? role,
    String? verificationCode,
    required String newPassword,
  }) async {
    final lookup = lookupRecoverableAccount(identifier: identifier, role: role);
    if (!lookup.found) {
      return lookup.errorMessage ?? 'Hesap bulunamadı.';
    }
    final effectiveRole = role ?? lookup.resolvedRole ?? UserRole.admin;

    final cleanPass = newPassword.trim();
    if (effectiveRole == UserRole.admin) {
      if (cleanPass.length < 6) {
        return 'Yeni parola en az 6 karakter olmalıdır.';
      }
      if (lookup.kind == RecoverableAccountKind.rootAdmin &&
          cleanPass == CompanySettings.defaultAdminPassword) {
        return 'Güvenliğiniz için varsayılan başlangıç parolası (123) kullanılamaz.';
      }
      if (cleanPass.toLowerCase() == lookup.normalizedUsername) {
        return 'Yeni parola kullanıcı adı ile aynı olamaz.';
      }
    } else {
      if (cleanPass.length < 4) {
        return 'Yeni personel parolası en az 4 karakter olmalıdır.';
      }
    }

    final check = _passwordRecoveryService.verifyChallenge(
      username: lookup.normalizedUsername,
      role: effectiveRole,
      code: verificationCode,
    );
    if (!check.verified) {
      return check.message;
    }

    final hashed = HasibuSecurityService.hashPassword(cleanPass);
    switch (lookup.kind!) {
      case RecoverableAccountKind.rootAdmin:
        _db.saveCompanySettings(
          state.companySettings.copyWith(
            adminPassword: hashed,
            adminPasswordUpdated: true,
          ),
        );
        break;
      case RecoverableAccountKind.appUser:
        final user = _db.findAppUserByUsername(lookup.normalizedUsername);
        if (user == null) {
          return 'Yetkili kullanıcı hesabı bulunamadı.';
        }
        _db.upsertAppUser(user.copyWith(passwordHash: hashed));
        break;
      case RecoverableAccountKind.employee:
        Employee? targetEmp;
        for (final emp in _db.getEmployees()) {
          if (emp.cardNo == lookup.normalizedUsername) {
            targetEmp = emp;
            break;
          }
        }
        if (targetEmp == null) {
          return 'Personel kaydı bulunamadı.';
        }
        _db.upsertEmployee(targetEmp.copyWith(password: hashed));
        break;
    }

    _passwordRecoveryService.clearChallenge();
    _db.appendAuditLog(
      actorEmployeeId: lookup.normalizedUsername,
      actionType: 'PASSWORD_RESET_COMPLETED',
      targetRecordId: lookup.normalizedUsername,
      oldValue: 'recovery_verified',
      newValue: 'updated_pbkdf2',
    );
    refreshDashboard();

    if (state.isGoogleCloudConnected ||
        state.companySettings.syncFolderPath.trim().isNotEmpty) {
      unawaited(_pushAutoBackupOnChange('Parola Sıfırlama'));
    }
    return null;
  }

  /// Tekil giriş: Girilen kullanıcı adı veya personel kart numarasına göre
  /// Ana Yönetici, Yetkili Kullanıcı veya Personel hesabını otomatik algılayıp oturum açar.
  UnifiedLoginResult attemptUnifiedLogin({
    required String identifier,
    required String password,
  }) {
    final rawId = identifier.trim();
    final lowerId = rawId.toLowerCase();
    final cleanPass = password.trim();

    if (rawId.isEmpty || cleanPass.isEmpty) {
      state = state.copyWith(
        authSession: state.authSession.copyWith(
          isAuthenticated: false,
          errorMessage: () =>
              'Lütfen kullanıcı adı / kart no ve parolanızı girin.',
        ),
      );
      return const UnifiedLoginResult(outcome: AdminLoginOutcome.failed);
    }

    // 1. Ana Yönetici hesabı kontrolü
    final expectedAdmin = state.companySettings.adminUsername.trim().toLowerCase();
    if (lowerId == expectedAdmin) {
      final outcome = attemptAdminLogin(username: rawId, password: cleanPass);
      return UnifiedLoginResult(
        outcome: outcome,
        resolvedRole: UserRole.admin,
        resolvedUsername: state.companySettings.adminUsername.trim(),
      );
    }

    // 2. Yetkili Kullanıcı (AppUserAccount) hesabı kontrolü
    final appUser = _db.findAppUserByUsername(lowerId);
    if (appUser != null) {
      final ok = loginAsAdmin(username: appUser.username, password: cleanPass);
      return UnifiedLoginResult(
        outcome: ok ? AdminLoginOutcome.authenticated : AdminLoginOutcome.failed,
        resolvedRole: appUser.role.baseRole,
        resolvedUsername: appUser.username,
      );
    }

    // 3. Personel kart / sicil no kontrolü
    final isNumericCard = RegExp(r'^\d+$').hasMatch(rawId);
    final paddedCard = isNumericCard ? rawId.padLeft(5, '0') : rawId;
    Employee? matchedEmp;
    for (final emp in _db.getEmployees()) {
      if (emp.cardNo.toLowerCase() == lowerId || emp.cardNo == paddedCard) {
        matchedEmp = emp;
        break;
      }
    }
    if (matchedEmp != null) {
      final ok = loginAsEmployee(cardNo: matchedEmp.cardNo, pin: cleanPass);
      return UnifiedLoginResult(
        outcome: ok ? AdminLoginOutcome.authenticated : AdminLoginOutcome.failed,
        resolvedRole: UserRole.employee,
        resolvedUsername: matchedEmp.cardNo,
      );
    }

    state = state.copyWith(
      authSession: state.authSession.copyWith(
        isAuthenticated: false,
        errorMessage: () => 'Kullanıcı adı / kart no veya parola hatalı.',
      ),
    );
    return const UnifiedLoginResult(outcome: AdminLoginOutcome.failed);
  }

  /// Yönetici / Yetkili Kullanıcı Girişi doğrular.
  bool loginAsAdmin({required String username, required String password}) {
    final u = username.trim().toLowerCase();
    final p = password.trim();
    final expectedUser = state.companySettings.adminUsername.toLowerCase();
    final expectedPass = state.companySettings.adminPassword;

    if (u == expectedUser &&
        HasibuSecurityService.verifyPassword(p, expectedPass)) {
      // [AUD-03] Yönetici/İK ekranlarında ekran görüntüsü ve App Switcher zırhını (FLAG_SECURE) etkinleştir
      HasibuSecurityService.setFlagSecureEnabled(true);
      state = state.copyWith(
        authSession: AuthSession(
          isAuthenticated: true,
          username: username.trim(),
          displayName: 'Yönetim (${state.companySettings.companyName})',
          role: UserRole.admin,
          allowedModules: HasibuModule.activePhaseModules,
        ),
        activeModule: HasibuModule.pdksHr,
        selectedBranchId: () => null,
        selectedStateFilter: () => null,
        selectedAnomalyFilter: PdksAnomalyFilter.all,
        searchQuery: '',
        terminalStatusMessage: 'PDKS Terminali hazır',
        lastTerminalReachable: () => null,
        mockGpsAnomalyCount: 0,
        lastMockGpsAlert: () => null,
        lastRestoreSummary: () => null,
      );
      refreshDashboard();
      return true;
    }

    final appUser = _db.findAppUserByUsername(u);
    if (appUser != null) {
      if (!appUser.isActive) {
        state = state.copyWith(
          authSession: state.authSession.copyWith(
            isAuthenticated: false,
            errorMessage: () =>
                'Kullanıcı hesabınız ($u) pasif duruma alınmış. Yöneticinizle iletişime geçin.',
          ),
        );
        return false;
      }
      if (HasibuSecurityService.verifyPassword(p, appUser.passwordHash)) {
        final scopedBranchIds = appUser.effectiveAllowedBranchIds;
        if (appUser.role == AppUserRole.branchSupervisor &&
            scopedBranchIds.isEmpty) {
          state = state.copyWith(
            authSession: state.authSession.copyWith(
              isAuthenticated: false,
              errorMessage: () =>
                  'Bu Şube Sorumlusu hesabına şube atanmamış. Lütfen yöneticiden "Ayarlar > Yetkili Kullanıcılar" üzerinden sorumlu şubeleri seçmesini isteyin.',
            ),
          );
          return false;
        }
        final modules = HasibuModule.filterActive(appUser.allowedModules);
        final hasAdminLikeModule = modules.any(
          (m) => m != HasibuModule.employeePortal,
        );
        HasibuSecurityService.setFlagSecureEnabled(hasAdminLikeModule);
        state = state.copyWith(
          authSession: AuthSession(
            isAuthenticated: true,
            username: appUser.username,
            displayName: appUser.displayName,
            role: appUser.role.baseRole,
            allowedModules: modules,
            appUserId: appUser.id,
            scopedBranchId:
                scopedBranchIds.isNotEmpty ? scopedBranchIds.first : null,
            scopedBranchIds: scopedBranchIds,
          ),
          activeModule: modules.first,
          selectedBranchId: () =>
              scopedBranchIds.length == 1 ? scopedBranchIds.first : null,
          selectedStateFilter: () => null,
          selectedAnomalyFilter: PdksAnomalyFilter.all,
          searchQuery: '',
          terminalStatusMessage: 'PDKS Terminali hazır',
          lastTerminalReachable: () => null,
          mockGpsAnomalyCount: 0,
          lastMockGpsAlert: () => null,
          lastRestoreSummary: () => null,
        );
        refreshDashboard();
        return true;
      }
    }

    state = state.copyWith(
      authSession: state.authSession.copyWith(
        isAuthenticated: false,
        errorMessage: () => 'Kullanıcı adı veya parola hatalı.',
      ),
    );
    return false;
  }

  /// Personel Kart/Sicil No + Kişisel Parola Girişi doğrular ve yetkili modüllerini açar.
  bool loginAsEmployee({required String cardNo, required String pin}) {
    final normalizedCard = cardNo.trim().padLeft(5, '0');
    final fallbackPin = state.companySettings.defaultEmployeePin;
    final allEmployees = _db.getEmployees();

    final matchIndex = allEmployees.indexWhere(
      (e) => e.cardNo == normalizedCard,
    );

    if (matchIndex >= 0) {
      final emp = allEmployees[matchIndex];
      if (emp.isSeparatedNow) {
        final exitDisplay = formatDisplayDate(
          emp.normalizedExitDate!,
          includeTodayBadge: false,
        );
        state = state.copyWith(
          authSession: state.authSession.copyWith(
            isAuthenticated: false,
            errorMessage: () =>
                'Personel #${emp.cardNo} için $exitDisplay tarihli işten ayrılış kaydı bulunduğu için oturum açılamaz.',
          ),
        );
        return false;
      }
      final expectedPassword = emp.password.trim();

      // [DB-04] Tuzlanmış PBKDF2/Argon2id hash doğrulaması (yalnızca şifresi boşsa varsayılan PIN geçerlidir)
      final isPasswordValid = expectedPassword.isNotEmpty
          ? HasibuSecurityService.verifyPassword(pin.trim(), expectedPassword)
          : HasibuSecurityService.verifyPassword(pin.trim(), fallbackPin);

      if (isPasswordValid) {
        final modules = HasibuModule.filterActive(emp.allowedModules);
        final hasAdminLikeModule = modules.any(
          (m) => m != HasibuModule.employeePortal,
        );
        HasibuSecurityService.setFlagSecureEnabled(hasAdminLikeModule);
        state = state.copyWith(
          authSession: AuthSession(
            isAuthenticated: true,
            username: emp.cardNo,
            displayName: emp.fullName,
            role: UserRole.employee,
            employeeCardNo: emp.cardNo,
            scopedBranchId: emp.branchId,
            scopedBranchIds: <int>[emp.branchId],
            allowedModules: modules,
          ),
          activeSelfServiceCardNo: emp.cardNo,
          activeModule: modules.first,
          selectedBranchId: () => emp.branchId,
        );
        refreshDashboard();
        return true;
      }
    }

    state = state.copyWith(
      authSession: state.authSession.copyWith(
        isAuthenticated: false,
        errorMessage: () =>
            'Personel Kart No (#$normalizedCard) veya kişisel parola hatalı.',
      ),
    );
    return false;
  }

  /// Oturumu kapatır ve Giriş (Login) ekranına döner.
  void logout() {
    HasibuSecurityService.setFlagSecureEnabled(false);
    state = state.copyWith(
      authSession: const AuthSession(isAuthenticated: false),
      activeModule: HasibuModule.pdksHr,
      selectedBranchId: () => null,
      selectedStateFilter: () => null,
      selectedAnomalyFilter: PdksAnomalyFilter.all,
      searchQuery: '',
      terminalStatusMessage: 'PDKS Terminali hazır',
      lastTerminalReachable: () => null,
      mockGpsAnomalyCount: 0,
      lastMockGpsAlert: () => null,
      lastRestoreSummary: () => null,
    );
    refreshDashboard();
  }

  /// Üst modül seçme satırından aktif modülü değiştirir (faz & yetki kontrolü ile).
  void selectModule(HasibuModule module) {
    if (!module.isEnabledInCurrentPhase ||
        !state.authSession.canAccess(module)) {
      return;
    }
    HasibuSecurityService.setFlagSecureEnabled(
      module != HasibuModule.employeePortal,
    );
    state = state.copyWith(activeModule: module);
  }

  void refreshDashboard() {
    final companySettings = _db.getCompanySettings();
    final branches = _db.getBranches();
    final shifts = _db.getShifts();
    final shiftAssignments = _db.getShiftAssignments();
    final departments = _db.getDepartments();
    _db.ensureEmployeesForUnregisteredLogCards();
    final employees = _db.getEmployees();

    final prevDateKey =
        AttendanceEvaluationEngine.previousDateKey(state.selectedDate);
    final nextDateKey =
        AttendanceEvaluationEngine.nextDateKey(state.selectedDate);
    final alertStartKey = formatDateKey(
      (Employee.parseDateKey(state.selectedDate) ?? DateTime.now())
          .subtract(const Duration(days: 5)),
    );
    final recentLogs = _db.getAttendanceLogsInDateRange(alertStartKey, nextDateKey);
    final leaves = _db.getLeaveRecordsForDate(state.selectedDate);
    final allLeaves = _db.getAllLeaveRecords();
    final publicHolidays = _db.getPublicHolidays();
    final allDocs = _db.getAllPersonnelDocuments();
    final allRequests = _db.getAllHrRequests();
    final appUsers = _db.getAppUsers();
    final tamperedLogs = _db.getTamperedAttendanceLogs();
    final auditLogs = _db.getAuditLogs(limit: 200);

    // [LIC-04] Monotonik Saat Kalkanı Kontrolü
    final clockCheck = _db.evaluateMonotonicClockShield();
    // [LIC-03] Ed25519 Lisans ve Donanım Kimliği Kontrolü
    final activeEmployeeCount =
        employees.where((e) => !e.isSeparatedNow).length;
    final licenseCheck = LicenseGuardService.verifyLicenseTokenSync(
      companySettings.licenseToken,
      expectedHwId: companySettings.hardwareFingerprint,
      currentEmployeeCount: activeEmployeeCount,
      currentBranchCount: branches.length,
    );

    final isClockTampered = clockCheck.isClockTampered;
    final isSubscriptionLocked = licenseCheck.isReadOnlyLocked;
    final String licenseMessage = isClockTampered
        ? clockCheck.reason
        : licenseCheck.reason;

    final branchMap = {for (final b in branches) b.id: b};
    final deptMap = {for (final d in departments) d.id: d};
    final shiftMap = {for (final s in shifts) s.id: s};
    final leaveMap = {for (final l in leaves) l.employeeId: l};
    final holidayByDate = {for (final h in publicHolidays) h.dateKey: h};

    final logsByCardDate = <String, List<AttendanceLog>>{};
    for (final log in recentLogs) {
      logsByCardDate
          .putIfAbsent('${log.cardNo}|${log.dateKey}', () => <AttendanceLog>[])
          .add(log);
    }

    final scopedBranchIds = state.effectiveBranchScopeIds;
    final scopedBranchIdSet = scopedBranchIds.toSet();
    final visibleBranches = scopedBranchIdSet.isNotEmpty
        ? branches
            .where((b) => scopedBranchIdSet.contains(b.id))
            .toList(growable: false)
        : branches;
    final visibleEmployees = scopedBranchIdSet.isNotEmpty
        ? employees
            .where((e) => scopedBranchIdSet.contains(e.branchId))
            .toList(growable: false)
        : employees;
    final scopedEmployeeIds = {for (final e in visibleEmployees) e.id};
    final scopedCardNos = {for (final e in visibleEmployees) e.cardNo};
    final scopedDeptIds = {for (final e in visibleEmployees) e.departmentId};
    final visibleDepartments = scopedBranchIdSet.isNotEmpty
        ? departments
            .where(
              (d) =>
                  scopedBranchIdSet.contains(d.branchId) ||
                  scopedDeptIds.contains(d.id),
            )
            .toList(growable: false)
        : departments;

    final fallbackBranch = branches.isNotEmpty
        ? branches.first
        : WorkplaceSeedData.branches.first;
    final fallbackShift =
        shifts.isNotEmpty ? shifts.first : WorkplaceSeedData.shifts.first;

    final assignmentsByEmp = <int, List<ShiftAssignment>>{};
    for (final a in shiftAssignments) {
      assignmentsByEmp
          .putIfAbsent(a.employeeId, () => <ShiftAssignment>[])
          .add(a);
    }

    final statuses = <EmployeeDailyStatus>[];
    for (final emp in visibleEmployees) {
      final branch = branchMap[emp.branchId] ?? fallbackBranch;
      final dept = deptMap[emp.departmentId] ??
          const Department(id: 1, name: 'GENEL', branchId: 1);
      final shift = AttendanceEvaluationEngine.resolveShiftForDate(
        employee: emp,
        dateKey: state.selectedDate,
        shiftMap: shiftMap,
        fallbackShift: fallbackShift,
        shiftAssignments: assignmentsByEmp[emp.id] ?? const <ShiftAssignment>[],
      );
      final empLogs = logsByCardDate['${emp.cardNo}|${state.selectedDate}'] ??
          const <AttendanceLog>[];
      final prevLogs = logsByCardDate['${emp.cardNo}|$prevDateKey'] ??
          const <AttendanceLog>[];
      final nextLogs = logsByCardDate['${emp.cardNo}|$nextDateKey'] ??
          const <AttendanceLog>[];
      final leave = leaveMap[emp.id];
      final holiday = holidayByDate[state.selectedDate];

      final eval = AttendanceEvaluationEngine.evaluateDay(
        rawDayLogs: empLogs,
        previousDayLogs: prevLogs,
        nextDayLogs: nextLogs,
        shift: shift,
        leave: leave,
        publicHoliday: holiday,
        employee: emp,
        dateKey: state.selectedDate,
      );

      statuses.add(
        EmployeeDailyStatus(
          employee: emp,
          department: dept,
          branch: branch,
          shift: shift,
          state: eval.state,
          firstCheckIn: eval.firstIn,
          lastCheckOut: eval.lastOut,
          allLogsOfDay: empLogs,
          leaveRecord: leave,
          publicHoliday: holiday,
          lateMinutes: eval.lateMinutes,
          workedMinutes: eval.workedMinutes,
          breakDeductedMinutes: eval.breakDeductedMinutes,
          overtimeMinutes: eval.overtimeMinutes,
          earlyLeaveMinutes: eval.earlyLeaveMinutes,
          hasMissingCheckOut: eval.hasMissingCheckOut,
          duplicateScansFiltered: eval.duplicateScansFiltered,
          isHolidayWork: eval.isHolidayWork,
          isWeeklyOffWork: eval.isWeeklyOffWork,
        ),
      );
    }

    final List<LeaveRecord> visibleLeaves;
    final List<PersonnelDocument> visibleDocs;
    final List<HrRequest> visibleRequests;
    final List<AttendanceLog> visibleTamperedLogs;
    final List<AuditLogEntry> visibleAuditLogs;
    final List<BranchInboxDeviceStatus> visibleInboxStatuses;
    final List<AppUserAccount> visibleAppUsers;
    String? nextSelfServiceCardNo;

    if (scopedBranchIdSet.isNotEmpty) {
      visibleLeaves = allLeaves
          .where((l) => scopedEmployeeIds.contains(l.employeeId))
          .toList(growable: false);
      visibleDocs = allDocs
          .where((d) => scopedEmployeeIds.contains(d.employeeId))
          .toList(growable: false);
      visibleRequests = allRequests
          .where(
            (r) =>
                scopedEmployeeIds.contains(r.employeeId) ||
                scopedCardNos.contains(r.employeeCardNo),
          )
          .toList(growable: false);
      final scopedRequestIds = {for (final r in visibleRequests) r.id};
      visibleTamperedLogs = tamperedLogs
          .where(
            (l) =>
                scopedBranchIdSet.contains(l.branchId) ||
                scopedCardNos.contains(l.cardNo),
          )
          .toList(growable: false);
      visibleAuditLogs = auditLogs
          .where(
            (a) => _isAuditLogInScope(
              a,
              scopedBranchIds: scopedBranchIdSet,
              scopedCardNos: scopedCardNos,
              scopedRequestIds: scopedRequestIds,
            ),
          )
          .toList(growable: false);
      visibleInboxStatuses = state.branchInboxStatuses
          .where((d) => scopedBranchIdSet.contains(d.branchId))
          .toList(growable: false);
      visibleAppUsers = appUsers
          .where(
            (u) =>
                u.id == state.authSession.appUserId ||
                (u.effectiveAllowedBranchIds.isNotEmpty &&
                    u.effectiveAllowedBranchIds.every(
                      scopedBranchIdSet.contains,
                    )),
          )
          .toList(growable: false);

      if (scopedCardNos.contains(state.activeSelfServiceCardNo)) {
        nextSelfServiceCardNo = state.activeSelfServiceCardNo;
      } else {
        final activeVisible = visibleEmployees
            .where((e) => !e.isSeparatedNow)
            .toList(growable: false);
        if (activeVisible.isNotEmpty) {
          nextSelfServiceCardNo = activeVisible.first.cardNo;
        } else if (visibleEmployees.isNotEmpty) {
          nextSelfServiceCardNo = visibleEmployees.first.cardNo;
        } else {
          nextSelfServiceCardNo = '';
        }
      }
    } else {
      visibleLeaves = allLeaves;
      visibleDocs = allDocs;
      visibleRequests = allRequests;
      visibleTamperedLogs = tamperedLogs;
      visibleAuditLogs = auditLogs;
      visibleInboxStatuses = state.branchInboxStatuses;
      visibleAppUsers = appUsers;
    }

    final visibleShiftAssignments = scopedBranchIdSet.isNotEmpty
        ? shiftAssignments
            .where((a) => scopedEmployeeIds.contains(a.employeeId))
            .toList(growable: false)
        : shiftAssignments;

    final proactiveAlerts = AttendanceReportEngine.buildProactiveAlerts(
      anchorDateKey: state.selectedDate,
      todayStatuses: statuses,
      employees: visibleEmployees,
      recentLogs: recentLogs,
      recentLeaves: visibleLeaves,
      holidays: holidayByDate,
      documents: visibleDocs,
      shiftMap: shiftMap,
      fallbackShift: fallbackShift,
      shiftAssignments: visibleShiftAssignments,
    );

    final int? Function()? nextSelectedBranchId;
    if (scopedBranchIds.length == 1) {
      nextSelectedBranchId = () => scopedBranchIds.first;
    } else if (scopedBranchIds.length > 1 &&
        state.selectedBranchId != null &&
        !scopedBranchIdSet.contains(state.selectedBranchId)) {
      nextSelectedBranchId = () => null;
    } else {
      nextSelectedBranchId = null;
    }

    final currentSync = state.syncStatus;
    final trimmedSyncGmail = companySettings.syncGmailAccount.trim();
    final DriveSyncStatus updatedSyncStatus = currentSync.copyWith(
      connectedGmail: trimmedSyncGmail.isNotEmpty
          ? trimmedSyncGmail
          : currentSync.connectedGmail,
      cloudProfileId: companySettings.cloudProfileId,
    );

    state = state.copyWith(
      companySettings: companySettings,
      autoPollEnabled: companySettings.autoPollEnabled,
      autoPollMinutes: companySettings.autoPollMinutes,
      selectedBranchId: nextSelectedBranchId,
      branches: visibleBranches,
      shifts: shifts,
      shiftAssignments: visibleShiftAssignments,
      departments: visibleDepartments,
      dailyStatuses: statuses,
      allLeaveRecords: visibleLeaves,
      publicHolidays: publicHolidays,
      allPersonnelDocuments: visibleDocs,
      allHrRequests: visibleRequests,
      proactiveAlerts: proactiveAlerts,
      appUsers: visibleAppUsers,
      branchInboxStatuses: visibleInboxStatuses,
      activeSelfServiceCardNo: nextSelfServiceCardNo,
      syncStatus: updatedSyncStatus,
      isReadOnlySubscriptionLocked: isSubscriptionLocked,
      isClockTampered: isClockTampered,
      licenseStatusMessage: licenseMessage,
      tamperedAttendanceLogs: visibleTamperedLogs,
      auditLogs: visibleAuditLogs,
    );
  }

  void setSelectedDate(String dateKey) {
    state = state.copyWith(selectedDate: dateKey);
    refreshDashboard();
  }

  void shiftSelectedDateByDays(int deltaDays) {
    final current =
        DateTime.tryParse(state.selectedDate) ?? DateTime(2026, 10, 19);
    final shifted = current.add(Duration(days: deltaDays));
    final nextKey =
        '${shifted.year.toString().padLeft(4, '0')}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
    setSelectedDate(nextKey);
  }

  void setBranchFilter(int? branchId) {
    final scoped = _scopedBranchIds;
    if (scoped.length == 1) {
      final onlyId = scoped.first;
      if (state.selectedBranchId != onlyId) {
        state = state.copyWith(selectedBranchId: () => onlyId);
      }
      return;
    }
    if (scoped.length > 1) {
      if (branchId != null && !scoped.contains(branchId)) return;
      state = state.copyWith(selectedBranchId: () => branchId);
      return;
    }
    state = state.copyWith(selectedBranchId: () => branchId);
  }

  void setStateFilter(DailyAttendanceState? filter) {
    state = state.copyWith(selectedStateFilter: () => filter);
  }

  void setAnomalyFilter(PdksAnomalyFilter filter) {
    state = state.copyWith(selectedAnomalyFilter: filter);
  }

  void setSearchQuery(String query) {
    final normalized = query.trim().isEmpty ? '' : query;
    if (state.searchQuery == normalized) return;
    state = state.copyWith(searchQuery: normalized);
  }

  void clearSearchQuery() {
    if (state.searchQuery.isEmpty) return;
    state = state.copyWith(searchQuery: '');
  }

  void clearAllAttendanceFilters() {
    state = state.copyWith(
      selectedStateFilter: () => null,
      selectedAnomalyFilter: PdksAnomalyFilter.all,
      searchQuery: '',
    );
  }

  void setSelfServiceEmployee(String cardNo) {
    if (_isBranchScoped &&
        !state.dailyStatuses.any((s) => s.employee.cardNo == cardNo)) {
      return;
    }
    state = state.copyWith(activeSelfServiceCardNo: cardNo);
  }

  Future<void> updateCompanySettings(CompanySettings newSettings) async {
    _db.saveCompanySettings(newSettings);
    refreshDashboard();
    _configureAutoPollTimer();
    _configureAutoCloudBackupTimer();
    await _pushAutoBackupOnChange(
      'Hasibu Ayarlar (${newSettings.companyName})',
      force: false,
    );
  }

  void toggleAutoPoll(bool enabled) {
    final updated = state.companySettings.copyWith(autoPollEnabled: enabled);
    _db.saveCompanySettings(updated);
    state = state.copyWith(
      companySettings: updated,
      autoPollEnabled: enabled,
      terminalStatusMessage: enabled
          ? 'Otomatik Tenfei D35 veri çekimi aktif (Her ${updated.autoPollMinutes} dk)'
          : 'Otomatik Tenfei D35 veri çekimi duraklatıldı',
    );
    _configureAutoPollTimer();
  }

  void _configureAutoPollTimer() {
    _autoPollTimer?.cancel();
    _autoPollTimer = null;
    if (!state.autoPollEnabled) return;

    _autoPollTimer = Timer.periodic(
      Duration(minutes: state.autoPollMinutes.clamp(1, 1440)),
      (_) => pullFromTenfeiTerminals(),
    );
  }

  void _configureAutoCloudBackupTimer() {
    _autoCloudBackupTimer?.cancel();
    _autoCloudBackupTimer = null;
    if (!state.companySettings.autoCloudBackupEnabled) return;

    _autoCloudBackupTimer = Timer.periodic(
      Duration(
        minutes: state.companySettings.autoCloudBackupMinutes.clamp(5, 1440),
      ),
      (_) => unawaited(runAutomaticCloudBackup()),
    );
  }

  void _configureBranchInboxPullTimer() {
    _branchInboxPullTimer?.cancel();
    _branchInboxPullTimer = null;
    if (state.isCommercialWriteLocked) return;

    _branchInboxPullTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (!mounted || state.isCommercialWriteLocked || state.isCloudBusy) {
          return;
        }
        unawaited(pullBranchInboxesNow(force: false));
      },
    );
  }

  /// Google Drive'daki tüm şube cihaz gelen kutularını (`hasibu_branch_inbox_*.enc`)
  /// okuyup mevcut veritabanına kayıpsız birleştirir.
  Future<BranchInboxPullResult> pullBranchInboxesNow({
    bool force = true,
  }) async {
    if (!mounted || state.isCommercialWriteLocked || _isPullingBranchInboxes) {
      return const BranchInboxPullResult();
    }
    _isPullingBranchInboxes = true;
    try {
      final res = await _syncService.pullAndMergeBranchInboxes(force: force);
      if (!mounted) return res;
      if (res.totalNewLogsInserted > 0 || res.totalUsersSynced > 0) {
        refreshDashboard();
      }
      final scopedSet = _scopedBranchIds.toSet();
      final visibleDevices = scopedSet.isNotEmpty
          ? res.devices
              .where((d) => scopedSet.contains(d.branchId))
              .toList(growable: false)
          : res.devices;
      if (visibleDevices.isNotEmpty || force) {
        state = state.copyWith(branchInboxStatuses: visibleDevices);
      }
      if (scopedSet.isNotEmpty) {
        return BranchInboxPullResult(
          devices: visibleDevices,
          totalLogsRead: visibleDevices.fold<int>(
            0,
            (sum, d) => sum + d.logCount,
          ),
          totalNewLogsInserted: visibleDevices.fold<int>(
            0,
            (sum, d) => sum + d.newlyInsertedCount,
          ),
          totalUsersSynced: visibleDevices.fold<int>(
            0,
            (sum, d) => sum + d.syncedUsersCount,
          ),
          warnings: res.warnings,
        );
      }
      return res;
    } catch (e) {
      debugPrint('Şube kutuları çekim uyarısı: $e');
      return BranchInboxPullResult(warnings: <String>[e.toString()]);
    } finally {
      _isPullingBranchInboxes = false;
    }
  }

  /// Şubedeki Windows 10 x64 `HasibuBranchBridge.exe` ajanına yapıştırılacak veya
  /// `--import-config` ile aktarılacak şube yapılandırma JSON metnini üretir (OAuth sırrı içermez).
  Future<String> buildBranchBridgeConfigJson(Branch branch) async {
    if (!_isBranchAllowed(branch.id)) {
      throw StateError(
        'Yetki kapsamı dışındaki şube için köprü yapılandırması üretilemez.',
      );
    }
    final workspaceKey = await _syncService.getWorkspaceKey();
    final effectiveCommKey = branch.terminalCommKey <= 0
        ? HasibuSecurityService.defaultTenfeiCommKey
        : branch.terminalCommKey;
    final payload = <String, dynamic>{
      'deviceSlug': GoogleDriveSyncService.normalizeDeviceSlug(
        '${branch.code}_d35',
      ),
      'deviceName': '${branch.name} Akıllı Terazi Köprüsü',
      'cloudProfileId': state.companySettings.cloudProfileId,
      'branchId': branch.id,
      'branchCode': branch.code,
      'branchName': branch.name,
      'terminalIp': (branch.terminalIp ?? '').trim(),
      'terminalPort': branch.terminalPort,
      'machineNo': branch.machineNo,
      'commKey': effectiveCommKey,
      'debounceSeconds': 3,
      'catchUpPollMinutes': 3,
      'keepAliveSeconds': 30,
      'workspaceKey': workspaceKey,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Yerel ağdaki aktif Tenfei D35 terminalleri için canlı push olay (`CMD_REG_EVENT`)
  /// dinleyicilerini başlatır; yeni okuma geldiğinde 3 sn gecikmeli otomatik yedek tetikler.
  Future<void> startRealtimeMonitoring() async {
    await stopRealtimeMonitoring();
    if (!mounted || state.isCommercialWriteLocked) return;

    final targetBranches = state.branches.where(
      (b) => b.hasTerminal && (b.terminalIp?.isNotEmpty ?? false),
    );
    for (final branch in targetBranches) {
      final client = TenfeiZkClient.forBranch(branch);
      try {
        await client.connect();
        await client.enableRealtimeEvents();
        if (!mounted) {
          await client.dispose();
          return;
        }
        _activeClients[branch.id] = client;
        final sub = client.realtimeAttendanceStream.listen(
          (log) {
            if (!mounted || state.isCommercialWriteLocked) return;
            final inserted = _db.upsertAttendanceLog(log);
            _db.ensureEmployeesForUnregisteredLogCards();
            if (inserted) {
              refreshDashboard();
              _realtimeUploadDebounce?.cancel();
              _realtimeUploadDebounce = Timer(
                const Duration(seconds: 3),
                () => unawaited(
                  _pushAutoBackupOnChange('Hasibu Canlı Tenfei Dinleyici'),
                ),
              );
            }
          },
          onError: (Object err) {
            debugPrint('Tenfei canlı akış hatası (${branch.name}): $err');
          },
        );
        _realtimeSubs.add(sub);
      } catch (e) {
        debugPrint('Tenfei canlı dinleme başlatılamadı (${branch.name}): $e');
        await client.dispose();
      }
    }
  }

  /// Açık canlı terminal dinleyicilerini ve soketlerini kapatır.
  Future<void> stopRealtimeMonitoring() async {
    _realtimeUploadDebounce?.cancel();
    _realtimeUploadDebounce = null;
    for (final sub in _realtimeSubs) {
      await sub.cancel();
    }
    _realtimeSubs.clear();
    for (final client in _activeClients.values) {
      await client.dispose();
    }
    _activeClients.clear();
  }

  /// Zamanlayıcı tarafından tetiklenen periyodik otomatik bulut yedeklemesi.
  Future<DriveSyncStatus> runAutomaticCloudBackup() async {
    if (!mounted ||
        state.isCommercialWriteLocked ||
        state.isCloudBusy ||
        !state.companySettings.autoCloudBackupEnabled) {
      return state.syncStatus;
    }
    try {
      final isEmployeePortal = state.authSession.role == UserRole.employee;
      final status = await _syncService.pushToCloud(
        deviceName: 'Hasibu Otomatik Bulut Yedekleme',
        force: false,
        isEmployeePortalOnly: isEmployeePortal,
        employeeCardNo: state.authSession.employeeCardNo,
        operationLabel: 'auto_backup',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: status);
      }
      return status;
    } catch (e) {
      debugPrint('Otomatik bulut yedekleme uyarısı: $e');
      return state.syncStatus;
    }
  }

  Future<void> _pushAutoBackupOnChange(
    String deviceName, {
    bool force = true,
    bool isEmployeePortalOnly = false,
    String? employeeCardNo,
  }) async {
    if (!mounted ||
        state.isCommercialWriteLocked ||
        !state.companySettings.autoCloudBackupEnabled ||
        !state.companySettings.autoCloudBackupOnChange) {
      return;
    }
    try {
      final result = await _syncService.pushToCloud(
        deviceName: deviceName,
        force: force,
        isEmployeePortalOnly: isEmployeePortalOnly,
        employeeCardNo: employeeCardNo,
        operationLabel: 'auto_backup',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: result);
      }
    } catch (e) {
      debugPrint('$deviceName bulut senkronizasyon uyarısı: $e');
    }
  }

  /// Doğrudan Tenfei D35 (192.168.9.150:4370 ve aktif şube terminalleri) üzerinden
  /// TCP 4370 protokolüyle giriş-çıkış kayıtlarını çeker, Google Drive'a yedekler ve özet rapor döndürür.
  Future<TerminalPullSummary?> pullFromTenfeiTerminals({
    int? onlyBranchId,
  }) async {
    // [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu / Saat Manipülasyonu Kilidi
    if (state.isCommercialWriteLocked) {
      state = state.copyWith(
        isPollingTerminal: false,
        terminalStatusMessage:
            'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Tenfei D35 veri çekimi durduruldu.',
      );
      return null;
    }
    if (state.isPollingTerminal) return null;
    state = state.copyWith(
      isPollingTerminal: true,
      terminalStatusMessage:
          'Tenfei D35 terminallerine (TCP 4370) bağlanılıyor...',
    );

    if (onlyBranchId != null && !_isBranchAllowed(onlyBranchId)) {
      state = state.copyWith(
        isPollingTerminal: false,
        terminalStatusMessage:
            'Yetki kapsamınız dışındaki şube terminalinden veri çekilemez.',
      );
      return null;
    }
    final targetBranches = state.branches.where((b) {
      if (onlyBranchId != null) return b.id == onlyBranchId;
      return b.hasTerminal && (b.terminalIp?.isNotEmpty ?? false);
    }).toList(growable: false);

    int totalFetched = 0;
    int newInserted = 0;
    int syncedEmployees = 0;
    int reachableCount = 0;
    bool anyReachable = false;
    String? latestPulledDateKey;
    final messages = <String>[];

    for (final branch in targetBranches) {
      final ip = (branch.terminalIp ?? '').trim();
      if (ip.isEmpty) {
        messages.add('${branch.name}: Terminal IP adresi tanımlanmamış.');
        continue;
      }
      // [HW-02] Şubenin şifreli `terminalCommKey` anahtarıyla bağlan
      final client = TenfeiZkClient.forBranch(branch);
      final branchPulledLogs = <AttendanceLog>[];

      try {
        final logs = await client.fetchAttendanceLogs();
        anyReachable = true;
        reachableCount++;
        totalFetched += logs.length;
        branchPulledLogs.addAll(logs);
        final insertedForBranch = _db.upsertAttendanceLogsBatch(logs);
        newInserted += insertedForBranch;
        for (final l in logs) {
          if (latestPulledDateKey == null ||
              l.dateKey.compareTo(latestPulledDateKey) > 0) {
            latestPulledDateKey = l.dateKey;
          }
        }
        messages.add(
          '${branch.name} ($ip:${branch.terminalPort} + LAN Köprüsü): ${logs.length} hareket okundu ($insertedForBranch yeni kayıt eklendi)',
        );
      } catch (_) {
        final fallbackLogs = await client.fetchLanPersonel2020BridgeLogs();
        if (fallbackLogs.isNotEmpty) {
          anyReachable = true;
          reachableCount++;
          totalFetched += fallbackLogs.length;
          branchPulledLogs.addAll(fallbackLogs);
          final insertedForBranch = _db.upsertAttendanceLogsBatch(fallbackLogs);
          newInserted += insertedForBranch;
          for (final l in fallbackLogs) {
            if (latestPulledDateKey == null ||
                l.dateKey.compareTo(latestPulledDateKey) > 0) {
              latestPulledDateKey = l.dateKey;
            }
          }
          messages.add(
            '${branch.name} (LAN personel2020 Köprüsü): ${fallbackLogs.length} hareket kurtarıldı ($insertedForBranch yeni kayıt eklendi)',
          );
        } else {
          messages.add(
            '${branch.name} ($ip:${branch.terminalPort}): Cihaza ulaşılamadı',
          );
        }
      }

      // Katman 1: LAN personel2020 üzerinden canlı kadro & bölüm eşitleme
      bool lanDirLoaded = false;
      try {
        final dir = await client.fetchLanPersonel2020Directory(
          defaultBranchId: branch.id,
        );
        if (dir.departments.isNotEmpty) {
          _db.upsertMissingDepartments(dir.departments);
        }
        if (dir.employees.isNotEmpty) {
          lanDirLoaded = true;
          syncedEmployees += _db.syncEmployeesFromDeviceOrBridge(dir.employees);
        }
        if (dir.exitedCardDates.isNotEmpty) {
          syncedEmployees += _db.applyExternalExitDates(dir.exitedCardDates);
        }
      } catch (e) {
        debugPrint('LAN personel2020 kadro eşitleme uyarısı: $e');
      }

      // Katman 2: Tenfei D35 cihaz içi kullanıcı rehberi (CMD_USERTEMP_RRQ)
      try {
        final deviceUsers = await client.fetchDeviceUsers();
        if (deviceUsers.isNotEmpty) {
          final currentEmployees = _db.getEmployees();
          final existingEmpCards =
              currentEmployees.map((e) => e.cardNo).toSet();
          final placeholderCards = currentEmployees
              .where((e) => e.fullName.startsWith('PERSONEL #'))
              .map((e) => e.cardNo)
              .toSet();
          final logCards = branchPulledLogs.map((l) => l.cardNo).toSet();

          final List<TenfeiDeviceUser> targetUsers;
          if (!lanDirLoaded) {
            targetUsers = existingEmpCards.isEmpty
                ? deviceUsers
                : deviceUsers
                    .where(
                      (u) =>
                          logCards.contains(u.cardNo) ||
                          !existingEmpCards.contains(u.cardNo) ||
                          placeholderCards.contains(u.cardNo),
                    )
                    .toList(growable: false);
          } else {
            targetUsers = deviceUsers
                .where(
                  (u) =>
                      logCards.contains(u.cardNo) &&
                      (!existingEmpCards.contains(u.cardNo) ||
                          placeholderCards.contains(u.cardNo)),
                )
                .toList(growable: false);
          }

          if (targetUsers.isNotEmpty) {
            final todayKeyStr = todayDateKey();
            final mapped = targetUsers
                .map(
                  (u) => Employee(
                    id: 0,
                    cardNo: u.cardNo,
                    fullName: u.fullName,
                    title: 'YÜZ TANIMA CİHAZI',
                    departmentId: branch.id == 1 ? 31 : branch.id,
                    branchId: branch.id,
                    shiftId: branch.id == 1 ? 1 : 3,
                    hireDate: todayKeyStr,
                  ),
                )
                .toList(growable: false);
            syncedEmployees += _db.syncEmployeesFromDeviceOrBridge(mapped);
          }
        }
      } catch (e) {
        debugPrint('Tenfei D35 kullanıcı rehberi çekme uyarısı: $e');
      } finally {
        await client.dispose();
      }
    }

    // Katman 3: Hareketlerde geçip hâlâ kaydı olmayan kartları yer tutucu olarak ekle
    syncedEmployees += _db.ensureEmployeesForUnregisteredLogCards();
    if (syncedEmployees > 0) {
      messages.add('+$syncedEmployees personel kadrosu eşitlendi');
    }

    final todayKey = todayDateKey();
    if (latestPulledDateKey == todayKey && state.selectedDate != todayKey) {
      state = state.copyWith(selectedDate: todayKey);
    }

    refreshDashboard();
    final logsForSelectedDate = _isBranchScoped
        ? state.dailyStatuses.fold<int>(
            0,
            (sum, s) => sum + s.allLogsOfDay.length,
          )
        : _db.getAttendanceLogsForDate(state.selectedDate).length;
    await _pushAutoBackupOnChange(
      'Hasibu Masaüstü (Tenfei D35 Köprüsü)',
      force: false,
    );

    state = state.copyWith(
      isPollingTerminal: false,
      lastTerminalReachable: () => anyReachable,
      terminalStatusMessage: messages.isEmpty
          ? 'Aktif terminal tanımlı değil.'
          : '${messages.join(' | ')} ($newInserted yeni, toplam $totalFetched)',
    );

    return TerminalPullSummary(
      anyReachable: anyReachable,
      targetTerminalCount: targetBranches.length,
      reachableTerminalCount: reachableCount,
      totalFetched: totalFetched,
      newInserted: newInserted,
      logsCountForSelectedDate: logsForSelectedDate,
      selectedDateAfterPull: state.selectedDate,
      latestPulledDateKey: latestPulledDateKey,
      branchMessages: messages,
      pulledAt: DateTime.now(),
    );
  }

  /// Tüm aktif terminallerde TCP 4370 + ZKTeco CMD_AUTH bağlantı kontrolünü çalıştırır.
  Future<List<TenfeiConnectionDiagnostics>> testAllTerminalsConnection() async {
    final targetBranches = state.branches
        .where((b) => b.hasTerminal && (b.terminalIp?.isNotEmpty ?? false))
        .toList(growable: false);
    if (targetBranches.isEmpty && state.branches.isNotEmpty) {
      final firstDiag =
          await testBranchTerminalConnection(state.branches.first);
      state = state.copyWith(
        lastTerminalReachable: () => firstDiag.isReachable,
        terminalStatusMessage: firstDiag.message,
      );
      return <TenfeiConnectionDiagnostics>[firstDiag];
    }

    final results = <TenfeiConnectionDiagnostics>[];
    bool anyReachable = false;
    for (final b in targetBranches) {
      final diag = await testBranchTerminalConnection(b);
      if (diag.isReachable) anyReachable = true;
      results.add(diag);
    }
    state = state.copyWith(
      lastTerminalReachable: () => anyReachable,
      terminalStatusMessage: results.isEmpty
          ? 'Test edilecek terminal bulunamadı.'
          : results.map((r) => r.message).join(' | '),
    );
    return results;
  }

  Future<TenfeiConnectionDiagnostics> testBranchTerminalConnection(
    Branch branch,
  ) async {
    if (!_isBranchAllowed(branch.id)) {
      return const TenfeiConnectionDiagnostics(
        isReachable: false,
        latencyMs: 0,
        message: 'Yetki kapsamınız dışındaki şube terminaline erişilemez.',
      );
    }
    final ip = (branch.terminalIp ?? '').trim();
    if (ip.isEmpty) {
      return const TenfeiConnectionDiagnostics(
        isReachable: false,
        latencyMs: 0,
        message: 'Terminal IP adresi boş.',
      );
    }
    // [HW-02] Şubenin şifreli `terminalCommKey` anahtarıyla bağlan
    final client = TenfeiZkClient.forBranch(branch);
    try {
      final diag = await client.testConnection();
      state = state.copyWith(
        lastTerminalReachable: () => diag.isReachable,
        terminalStatusMessage: diag.message,
      );
    return diag;
    } finally {
      await client.dispose();
    }
  }

  /// Şubedeki Tenfei D35 / ZKTeco terminalinin saatini sistem saatiyle eşitler.
  Future<String> syncBranchTerminalClock(int branchId) async {
    if (state.isCommercialWriteLocked) {
      return 'Salt-okunur kilitli modda terminal saati değiştirilemez.';
    }
    if (!_isBranchAllowed(branchId)) {
      return 'Yetki kapsamınız dışındaki şube terminaline erişilemez.';
    }
    final branch = _db.getBranches().where((b) => b.id == branchId).firstOrNull;
    if (branch == null || !branch.hasTerminal || (branch.terminalIp ?? '').trim().isEmpty) {
      return 'Şube için aktif terminal IP adresi tanımlı değil.';
    }
    final client = TenfeiZkClient(
      host: branch.terminalIp!.trim(),
      port: branch.terminalPort,
      branchId: branch.id,
      machineNo: branch.machineNo,
      commKey: branch.terminalCommKey,
    );
    try {
      final ok = await client.syncDeviceTime();
      if (ok) {
        final actor = state.authSession.username.isEmpty
            ? 'admin'
            : state.authSession.username;
        _db.appendAuditLog(
          actorEmployeeId: actor,
          actionType: 'TERMINAL_CLOCK_SYNCED',
          targetRecordId: 'branch_${branch.id}',
          oldValue: '${branch.terminalIp}:${branch.terminalPort}',
          newValue: DateTime.now().toIso8601String(),
        );
        refreshDashboard();
        return '✓ ${branch.name} terminal saati sistem saatiyle eşitlendi.';
      }
      return '${branch.name} terminal saati güncellenemedi (ACK alınamadı).';
    } catch (e) {
      return '${branch.name} terminal saat eşitleme hatası: $e';
    } finally {
      await client.dispose();
    }
  }

  /// Şube kadrosunu (aktif ekleme, işten ayrılanları silme) terminalle eşitler.
  Future<String> syncEmployeesToBranchTerminal(int branchId) async {
    if (state.isCommercialWriteLocked) {
      return 'Salt-okunur kilitli modda terminal kadrosu değiştirilemez.';
    }
    if (!_isBranchAllowed(branchId)) {
      return 'Yetki kapsamınız dışındaki şube terminaline erişilemez.';
    }
    final branch = _db.getBranches().where((b) => b.id == branchId).firstOrNull;
    if (branch == null || !branch.hasTerminal || (branch.terminalIp ?? '').trim().isEmpty) {
      return 'Şube için aktif terminal IP adresi tanımlı değil.';
    }
    final branchEmployees = _db
        .getEmployees()
        .where((e) => e.branchId == branchId)
        .toList(growable: false);
    final client = TenfeiZkClient(
      host: branch.terminalIp!.trim(),
      port: branch.terminalPort,
      branchId: branch.id,
      machineNo: branch.machineNo,
      commKey: branch.terminalCommKey,
    );
    try {
      await client.connect();
      final deviceUsers = await client.fetchDeviceUsers();
      final deviceUidByCard = <String, int>{
        for (final u in deviceUsers) u.cardNo: u.uid,
      };
      int pushed = 0;
      int removed = 0;
      for (final emp in branchEmployees) {
        final card = emp.cardNo.trim().padLeft(5, '0');
        final existingUid = deviceUidByCard[card];
        if (emp.isSeparatedNow) {
          if (existingUid != null && await client.deleteDeviceUserByUid(existingUid)) {
            removed++;
          }
        } else {
          final uid = existingUid ?? (int.tryParse(card) ?? emp.id);
          if (uid > 0 &&
              await client.upsertDeviceUser(
                uid: uid,
                cardNo: card,
                fullName: emp.fullName,
              )) {
            pushed++;
          }
        }
      }
      final actor = state.authSession.username.isEmpty
          ? 'admin'
          : state.authSession.username;
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: 'TERMINAL_STAFF_SYNCED',
        targetRecordId: 'branch_${branch.id}',
        oldValue: 'deviceUsers=${deviceUsers.length}',
        newValue: 'pushed=$pushed, removed=$removed',
      );
      refreshDashboard();
      return '✓ ${branch.name} terminal kadrosu eşitlendi ($pushed gönderildi, $removed ayrılan silindi).';
    } catch (e) {
      return '${branch.name} kadro eşitleme hatası: $e';
    } finally {
      await client.dispose();
    }
  }

  /// Şube veya Cihaz ekler / günceller.
  Future<void> saveBranch(Branch branch) async {
    if (!_isBranchAllowed(branch.id)) return;
    _db.upsertBranch(branch);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Şube/Cihaz Yönetimi');
  }

  Future<void> deleteBranch(int branchId) async {
    if (_isBranchScoped) return;
    _db.deleteBranch(branchId);
    if (state.selectedBranchId == branchId) {
      state = state.copyWith(selectedBranchId: () => null);
    }
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Şube/Cihaz Yönetimi');
  }

  /// Vardiya / Mesai Saat Aralığı ve Geç Kalma Toleransını ekler veya günceller.
  Future<void> saveShiftPlan(ShiftPlan shift) async {
    _db.upsertShift(shift);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Vardiya Yönetimi');
  }

  Future<void> deleteShiftPlan(int shiftId) async {
    _db.deleteShift(shiftId);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Vardiya Yönetimi');
  }

  /// Tarih bazlı vardiya ataması / rotasyon kaydı ekler veya günceller.
  Future<void> saveShiftAssignment(ShiftAssignment assignment) async {
    if (state.isCommercialWriteLocked) return;
    if (!_isEmployeeInScope(assignment.employeeId)) return;
    _db.upsertShiftAssignment(assignment);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'SHIFT_ASSIGNMENT_SAVED',
      targetRecordId: 'emp_${assignment.employeeId}',
      oldValue: '-',
      newValue:
          'shift=${assignment.shiftId} (${assignment.validFrom}..${assignment.validTo ?? "DEVAM"})',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Vardiya Rotasyonu');
  }

  Future<void> deleteShiftAssignment(String assignmentId) async {
    if (state.isCommercialWriteLocked) return;
    _db.deleteShiftAssignment(assignmentId);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Vardiya Rotasyonu');
  }

  /// Resmi tatil (UBGT) kaydı ekler veya günceller.
  Future<void> savePublicHoliday(PublicHoliday holiday) async {
    if (state.isCommercialWriteLocked) return;
    _db.upsertPublicHoliday(holiday);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'PUBLIC_HOLIDAY_SAVED',
      targetRecordId: holiday.dateKey,
      oldValue: '-',
      newValue: '${holiday.dateKey} (${holiday.name})',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Resmi Tatil Takvimi');
  }

  Future<void> deletePublicHoliday(String holidayId) async {
    if (state.isCommercialWriteLocked) return;
    _db.deletePublicHoliday(holidayId);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'PUBLIC_HOLIDAY_DELETED',
      targetRecordId: holidayId,
      oldValue: holidayId,
      newValue: 'DELETED',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Resmi Tatil Takvimi');
  }

  Future<int> seedTurkeyOfficialHolidays(int year) async {
    if (state.isCommercialWriteLocked) return 0;
    final added = _db.seedTurkeyOfficialHolidays(year);
    if (added > 0) {
      refreshDashboard();
      await _pushAutoBackupOnChange('Hasibu Resmi Tatil Takvimi');
    }
    return added;
  }

  /// Departman / Üretim Bölümü ekler veya günceller.
  Future<void> saveDepartment(Department dept) async {
    if (!_isBranchAllowed(dept.branchId)) return;
    _db.upsertDepartment(dept);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Bölüm Yönetimi');
  }

  /// Personel ekler veya mevcut personelin bilgilerini günceller.
  Future<void> saveEmployee(Employee employee) async {
    Employee? previous;
    for (final emp in _db.getEmployees()) {
      if (emp.id == employee.id) {
        previous = emp;
        break;
      }
    }
    if (!_isBranchAllowed(employee.branchId) ||
        (previous != null && !_isBranchAllowed(previous.branchId))) {
      return;
    }
    _db.upsertEmployee(employee);
    if (previous != null && previous.shiftId != employee.shiftId) {
      final existingAssignments = _db.getShiftAssignments(employeeId: employee.id);
      final effectiveFrom = state.selectedDate;
      final prevDay = AttendanceEvaluationEngine.previousDateKey(effectiveFrom);
      if (existingAssignments.isEmpty &&
          previous.hireDate.compareTo(prevDay) <= 0) {
        _db.upsertShiftAssignment(
          ShiftAssignment(
            id: 'sa_hist_${employee.id}_${previous.hireDate}_${previous.shiftId}',
            employeeId: employee.id,
            shiftId: previous.shiftId,
            validFrom: previous.hireDate,
            validTo: prevDay,
            note: 'Önceki vardiya geçmişi (otomatik koruma)',
          ),
        );
      } else {
        for (final a in existingAssignments) {
          if (a.validTo == null && a.validFrom.compareTo(effectiveFrom) < 0) {
            _db.upsertShiftAssignment(a.copyWith(validTo: () => prevDay));
          }
        }
      }
      _db.upsertShiftAssignment(
        ShiftAssignment(
          id: 'sa_${employee.id}_${effectiveFrom}_${employee.shiftId}',
          employeeId: employee.id,
          shiftId: employee.shiftId,
          validFrom: effectiveFrom,
          note: 'Vardiya değişikliği',
        ),
      );
    }
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    final normalizedCard = employee.cardNo.trim().padLeft(5, '0');
    if (previous == null ||
        previous.hireDate != employee.hireDate ||
        previous.normalizedExitDate != employee.normalizedExitDate) {
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: 'EMPLOYEE_EMPLOYMENT_DATES_UPDATED',
        targetRecordId: normalizedCard,
        oldValue: previous == null
            ? 'NEW_EMPLOYEE'
            : 'hireDate=${previous.hireDate}, exitDate=${previous.normalizedExitDate ?? "AKTIF"}',
        newValue:
            'hireDate=${employee.hireDate}, exitDate=${employee.normalizedExitDate ?? "AKTIF"}',
      );
    } else {
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: 'EMPLOYEE_SAVED',
        targetRecordId: normalizedCard,
        oldValue: '${previous.fullName} (branch=${previous.branchId}, shift=${previous.shiftId})',
        newValue: '${employee.fullName} (branch=${employee.branchId}, shift=${employee.shiftId})',
      );
    }
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Personel Yönetimi');
  }

  /// Excel/CSV metninden toplu personel kartı içe aktarır.
  Future<EmployeeCsvImportResult> importEmployeesFromCsv(String rawCsv) async {
    if (state.isCommercialWriteLocked) {
      return const EmployeeCsvImportResult(
        validEmployees: <Employee>[],
        warnings: <String>['Salt-okunur kilitli modda toplu içe aktarım yapılamaz.'],
        skippedExistingCount: 0,
        totalRowsRead: 0,
      );
    }
    final existing = _db.getEmployees();
    final branches = _isBranchScoped
        ? _db.getBranches().where((b) => _isBranchAllowed(b.id)).toList(growable: false)
        : _db.getBranches();
    final departments = _db.getDepartments();
    final shifts = _db.getShifts();

    final parsed = EmployeeBulkImportEngine.parseEmployeeCsv(
      rawCsv,
      branches: branches,
      departments: departments,
      shifts: shifts,
      existingEmployees: existing,
      defaultHireDate: state.selectedDate,
    );

    final allowedToInsert = parsed.validEmployees
        .where((e) => _isBranchAllowed(e.branchId))
        .toList(growable: false);

    if (allowedToInsert.isNotEmpty) {
      for (final emp in allowedToInsert) {
        _db.upsertEmployee(emp);
      }
      final actor = state.authSession.username.isEmpty
          ? 'admin'
          : state.authSession.username;
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: 'EMPLOYEES_BULK_IMPORTED',
        targetRecordId: 'count_${allowedToInsert.length}',
        oldValue: 'existing=${existing.length}',
        newValue: 'imported=${allowedToInsert.length}',
      );
      refreshDashboard();
      await _pushAutoBackupOnChange('Hasibu Toplu Personel Aktarımı');
    }

    return EmployeeCsvImportResult(
      validEmployees: allowedToInsert,
      warnings: parsed.warnings,
      skippedExistingCount: parsed.skippedExistingCount,
      totalRowsRead: parsed.totalRowsRead,
    );
  }

  /// Seçili personellere toplu vardiya, şube veya bölüm ataması yapar.
  Future<int> bulkAssignEmployees({
    required List<int> employeeIds,
    int? shiftId,
    int? branchId,
    int? departmentId,
    String? effectiveDateKey,
  }) async {
    if (state.isCommercialWriteLocked || employeeIds.isEmpty) return 0;
    if (branchId != null && !_isBranchAllowed(branchId)) return 0;
    final idSet = employeeIds.toSet();
    final employees = _db.getEmployees();
    final effectiveFrom = effectiveDateKey ?? state.selectedDate;
    final prevDay = AttendanceEvaluationEngine.previousDateKey(effectiveFrom);
    int updated = 0;

    for (final emp in employees) {
      if (!idSet.contains(emp.id)) continue;
      if (!_isBranchAllowed(emp.branchId)) continue;
      final nextEmp = emp.copyWith(
        shiftId: shiftId ?? emp.shiftId,
        branchId: branchId ?? emp.branchId,
        departmentId: departmentId ?? emp.departmentId,
      );
      _db.upsertEmployee(nextEmp);
      if (shiftId != null && shiftId != emp.shiftId) {
        final existingAssignments = _db.getShiftAssignments(employeeId: emp.id);
        if (existingAssignments.isEmpty && emp.hireDate.compareTo(prevDay) <= 0) {
          _db.upsertShiftAssignment(
            ShiftAssignment(
              id: 'sa_hist_${emp.id}_${emp.hireDate}_${emp.shiftId}',
              employeeId: emp.id,
              shiftId: emp.shiftId,
              validFrom: emp.hireDate,
              validTo: prevDay,
              note: 'Toplu atama öncesi vardiya',
            ),
          );
        }
        _db.upsertShiftAssignment(
          ShiftAssignment(
            id: 'sa_bulk_${emp.id}_${effectiveFrom}_$shiftId',
            employeeId: emp.id,
            shiftId: shiftId,
            validFrom: effectiveFrom,
            note: 'Toplu vardiya ataması',
          ),
        );
      }
      updated++;
    }

    if (updated > 0) {
      final actor = state.authSession.username.isEmpty
          ? 'admin'
          : state.authSession.username;
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: 'EMPLOYEES_BULK_ASSIGNED',
        targetRecordId: 'count_$updated',
        oldValue: '-',
        newValue:
            'shift=${shiftId ?? "-"}, branch=${branchId ?? "-"}, dept=${departmentId ?? "-"}',
      );
      refreshDashboard();
      await _pushAutoBackupOnChange('Hasibu Toplu Personel Atama');
    }
    return updated;
  }

  Future<void> deleteEmployee(int employeeId) async {
    if (!_isEmployeeInScope(employeeId)) return;
    final target = _db
        .getEmployees()
        .where((e) => e.id == employeeId)
        .firstOrNull;
    _db.deleteEmployee(employeeId);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'EMPLOYEE_DELETED',
      targetRecordId: target?.cardNo ?? employeeId.toString(),
      oldValue: target?.fullName ?? 'id=$employeeId',
      newValue: 'DELETED',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Personel Yönetimi');
  }

  /// `HH:mm` (00:00 - 23:59) saat biçimini katı olarak doğrular.
  static ({int hour, int minute})? parseStrictTimeHhMm(String raw) {
    final match = RegExp(r'^\s*([01]?\d|2[0-3]):([0-5]\d)\s*$').firstMatch(raw);
    if (match == null) return null;
    final h = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    if (h == null || m == null) return null;
    return (hour: h, minute: m);
  }

  /// Personel hareketini (Giriş veya Çıkış saatini) manuel ekler veya düzeltir.
  Future<bool> saveOrUpdateAttendanceLog({
    String? existingLogId,
    required Employee employee,
    required String dateKey, // YYYY-MM-DD
    required String timeHhMm, // HH:mm
    required bool isCheckIn,
    AttendanceSource source = AttendanceSource.manual,
    VerifyMethod verifyMethod = VerifyMethod.face,
    String? note,
    bool writeAuditLog = true,
  }) async {
    if (state.isCommercialWriteLocked) return false;
    if (!_isBranchAllowed(employee.branchId)) return false;

    final parsedTime = parseStrictTimeHhMm(timeHhMm);
    if (parsedTime == null) return false;

    final parsedDate = Employee.parseDateKey(dateKey);
    if (parsedDate == null) return false;

    final dt = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    final existing =
        existingLogId != null ? _db.getAttendanceLogById(existingLogId) : null;

    final String logId = existingLogId ??
        '${employee.branchId}_${employee.cardNo}_${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}_${isCheckIn ? "IN" : "OUT"}';

    final integrityHash = HasibuSecurityService.computeAttendanceIntegrityHash(
      cardNo: employee.cardNo,
      timestamp: dt,
      isCheckIn: isCheckIn,
      verifyMethod: verifyMethod.name,
    );

    final log = AttendanceLog(
      id: logId,
      cardNo: employee.cardNo,
      branchId: employee.branchId,
      deviceNo: 1,
      timestamp: dt,
      isCheckIn: isCheckIn,
      source: source,
      verifyMethod: verifyMethod,
      integrityHash: integrityHash,
    );

    _db.upsertAttendanceLog(log);

    if (writeAuditLog) {
      final actor = state.authSession.username.isEmpty
          ? 'admin'
          : state.authSession.username;
      final cleanNote = (note ?? '').trim();
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: existing != null
            ? 'MANUAL_ATTENDANCE_UPDATED'
            : 'MANUAL_ATTENDANCE_ADDED',
        targetRecordId: logId,
        oldValue: existing == null
            ? 'NONE'
            : '${existing.dateKey} ${existing.timeFormatted} ${existing.isCheckIn ? "IN" : "OUT"}',
        newValue:
            '${log.dateKey} ${log.timeFormatted} ${log.isCheckIn ? "IN" : "OUT"}${cleanNote.isNotEmpty ? " ($cleanNote)" : ""}',
      );
    }

    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Hareket Düzeltme');
    return true;
  }

  /// Yetki kapsamındaki personelin belirli bir tarihteki tüm yoklama hareketlerini kronolojik döndürür.
  List<AttendanceLog> getAttendanceLogsForEmployeeOnDate(
    String cardNo,
    String dateKey,
  ) {
    if (_isBranchScoped && !_isCardInScope(cardNo)) {
      return const <AttendanceLog>[];
    }
    final logs = _db
        .getAttendanceLogsForDate(dateKey)
        .where((l) => l.cardNo == cardNo)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return List<AttendanceLog>.unmodifiable(logs);
  }

  Future<void> deleteAttendanceLog(String logId) async {
    if (state.isCommercialWriteLocked) return;
    final existing = _db.getAttendanceLogById(logId);
    if (existing == null) return;
    if (_isBranchScoped &&
        !_isBranchAllowed(existing.branchId) &&
        !_isCardInScope(existing.cardNo)) {
      return;
    }
    _db.deleteAttendanceLog(logId);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'MANUAL_ATTENDANCE_DELETED',
      targetRecordId: logId,
      oldValue:
          '${existing.cardNo} ${existing.dateKey} ${existing.timeFormatted} ${existing.isCheckIn ? "IN" : "OUT"}',
      newValue: 'DELETED',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Hareket Düzeltme');
  }

  /// Çoklu personel seçimiyle toplu giriş ve/veya çıkış saati uygular.
  Future<int> saveBulkManualAttendance({
    required List<Employee> employees,
    required String dateKey,
    String? checkInTime,
    String? checkOutTime,
    bool replaceExistingForDay = true,
  }) async {
    final scopedEmployees = _isBranchScoped
        ? employees
            .where((e) => _isBranchAllowed(e.branchId))
            .toList(growable: false)
        : employees;
    if (scopedEmployees.isEmpty) return 0;
    final affected = _db.applyBulkManualAttendance(
      employees: scopedEmployees,
      dateKey: dateKey,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      replaceExistingForDay: replaceExistingForDay,
    );
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'BULK_MANUAL_ATTENDANCE_APPLIED',
      targetRecordId: dateKey,
      oldValue: 'replace=$replaceExistingForDay',
      newValue:
          'employees=${scopedEmployees.length}, affected=$affected, in=${checkInTime ?? "-"}, out=${checkOutTime ?? "-"}',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Toplu Hareket Düzeltme');
    return affected;
  }

  /// Google (Gmail) bulut eşitleme hesabını, yerel Drive klasörünü ve varsa OAuth anahtarını doğrular ve kaydeder.
  Future<DriveSyncStatus> saveGmailSyncAccount({
    required String gmailAccount,
    required String syncFolderPath,
    String? accessToken,
    bool syncAfterVerify = false,
  }) async {
    String cleanGmail = gmailAccount.trim();
    if (cleanGmail.isNotEmpty && !cleanGmail.contains('@')) {
      cleanGmail = '$cleanGmail@gmail.com';
    }
    String cleanFolder = syncFolderPath.trim();
    if (cleanFolder.isEmpty) {
      cleanFolder = GoogleDriveSyncService.detectDefaultGoogleDrivePath();
    }

    state = state.copyWith(
      isCloudBusy: true,
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: 'Google OAuth 2.0 & Drive bağlantısı doğrulanıyor...',
      ),
    );

    try {
      bool tokenPreVerified = false;
      if (accessToken != null) {
        final cleanToken = accessToken.trim();
        if (cleanToken.isEmpty) {
          try {
            await _syncService.clearTokens();
          } catch (e) {
            debugPrint('PdksProviders: clearTokens uyarısı: $e');
            if (mounted) {
              state = state.copyWith(
                syncStatus: state.syncStatus.copyWith(
                  message: 'Token temizleme uyarısı: $e',
                ),
              );
            }
          }
        } else {
          if (mounted) {
            state = state.copyWith(
              syncStatus: state.syncStatus.copyWith(
                stage: DriveSyncStage.syncing,
                message: 'Google OAuth 2.0 erişim anahtarı doğrulanıyor...',
              ),
            );
          }
          final verification =
              await _syncService.verifyGoogleAccessToken(cleanToken);
          if (!verification.isValid) {
            final errStatus = DriveSyncStatus(
              stage: DriveSyncStage.error,
              lastSyncTime: DateTime.now(),
              connectedGmail: cleanGmail,
              isCloudApiVerified: false,
              isDriveFolderMirrored: false,
              message: verification.errorMessage,
            );
            if (mounted) {
              state = state.copyWith(syncStatus: errStatus);
            }
            return errStatus;
          }
          tokenPreVerified = true;
          if (verification.email.isNotEmpty) {
            cleanGmail = verification.email;
          }
          try {
            await _syncService.saveOAuthTokens(accessToken: cleanToken);
          } catch (e) {
            debugPrint('PdksProviders: saveOAuthTokens uyarısı: $e');
            if (mounted) {
              state = state.copyWith(
                syncStatus: state.syncStatus.copyWith(
                  message: 'Token saklama uyarısı: $e',
                ),
              );
            }
          }
        }
      }

      if (!mounted) return state.syncStatus;
      final updated = state.companySettings.copyWith(
        syncGmailAccount: cleanGmail,
        syncFolderPath: cleanFolder,
      );
      _db.saveCompanySettings(updated);
      if (cleanGmail.isNotEmpty) {
        await _syncService.setLastSyncedGmailAccount(cleanGmail);
      }
      refreshDashboard();

      if (syncAfterVerify) {
        await syncWithGoogleDriveNow();
        return state.syncStatus;
      }

      final verifiedStatus = await _syncService.verifyCloudConnection(
        previousStatus: state.syncStatus,
        tokenAlreadyVerified: tokenPreVerified,
      );
      if (!mounted) return verifiedStatus;

      final resolvedEmail = verifiedStatus.connectedGmail.trim();
      if (resolvedEmail.isNotEmpty) {
        await _syncService.setLastSyncedGmailAccount(resolvedEmail);
        if (resolvedEmail != state.companySettings.syncGmailAccount.trim()) {
          _db.saveCompanySettings(
            state.companySettings.copyWith(syncGmailAccount: resolvedEmail),
          );
          refreshDashboard();
        }
      }
      if (mounted) {
        state = state.copyWith(syncStatus: verifiedStatus);
      }
      return verifiedStatus;
    } catch (e) {
      debugPrint('PdksProviders: saveGmailSyncAccount hatası: $e');
      final errStatus = DriveSyncStatus(
        stage: DriveSyncStage.error,
        lastSyncTime: DateTime.now(),
        connectedGmail: cleanGmail,
        isCloudApiVerified: false,
        isDriveFolderMirrored: false,
        message: 'Google bağlantı doğrulama hatası: $e',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: errStatus);
      }
      return errStatus;
    } finally {
      if (mounted) {
        state = state.copyWith(isCloudBusy: false);
      }
    }
  }

  /// Platforma uygun Google OAuth 2.0 akışını (Masaüstünde Edge PKCE, Mobilde Google Sign-In) başlatır.
  /// `authenticateAppSession` true ise doğrulanmış Google e-postası ile Hasibu oturumunu da açar.
  Future<BrowserGoogleSignInResult> signInWithGoogleViaBrowser({
    String? emailHint,
    String? customClientId,
    String? customClientSecret,
    String? syncFolderPath,
    bool authenticateAppSession = false,
  }) async {
    state = state.copyWith(
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: _googleAuthAdapter.isNativePlatform
            ? 'Google oturumu açılıyor, cihaz onayı bekleniyor...'
            : 'Edge tarayıcıda Google OAuth 2.0 oturumu açıldı, onay bekleniyor...',
      ),
    );

    final result = await _googleAuthAdapter.signIn(
      loginHintEmail: emailHint,
      customClientId: customClientId,
      customClientSecret: customClientSecret,
    );

    if (!result.success) {
      state = state.copyWith(
        syncStatus: state.syncStatus.copyWith(
          stage: DriveSyncStage.error,
          message: result.message,
        ),
        authSession: authenticateAppSession
            ? state.authSession.copyWith(
                isAuthenticated: false,
                errorMessage: () => result.message,
              )
            : state.authSession,
      );
      return result;
    }

    if (result.accessToken.trim().isNotEmpty) {
      try {
        await _syncService.saveOAuthTokens(
          accessToken: result.accessToken,
          refreshToken:
              result.refreshToken.trim().isEmpty ? null : result.refreshToken,
        );
      } catch (e) {
        debugPrint('PdksProviders: saveOAuthTokens oturum uyarısı: $e');
        state = state.copyWith(
          syncStatus:
              state.syncStatus.copyWith(message: 'OAuth token saklama hatası: $e'),
        );
      }
    }

    final resolvedGmail = result.email.isNotEmpty
        ? result.email
        : (emailHint?.trim() ?? state.companySettings.syncGmailAccount);
    final resolvedFolder = (syncFolderPath != null &&
            syncFolderPath.trim().isNotEmpty)
        ? syncFolderPath.trim()
        : (state.companySettings.syncFolderPath.isNotEmpty
            ? state.companySettings.syncFolderPath
            : GoogleDriveSyncService.detectDefaultGoogleDrivePath());

    final prevSettingsGmail =
        state.companySettings.syncGmailAccount.trim().toLowerCase();
    final prevStoredGmail =
        (await _syncService.getLastSyncedGmailAccount()).trim().toLowerCase();
    final effectivePrevGmail =
        prevSettingsGmail.isNotEmpty ? prevSettingsGmail : prevStoredGmail;
    final normalizedNewGmail = resolvedGmail.trim().toLowerCase();
    final bool isSwitchingToDifferentAccount = effectivePrevGmail.isNotEmpty &&
        normalizedNewGmail.isNotEmpty &&
        effectivePrevGmail != normalizedNewGmail;

    if (isSwitchingToDifferentAccount) {
      await _syncService.resetWorkspaceEncryptionToAccountAuto();
      await _syncService.clearLocalAppSupportMirrors();
      _syncService.clearRuntimeSyncCaches();
      _db.resetForCloudAccountSwitch(
        newGmailAccount: resolvedGmail,
        syncFolderPath: resolvedFolder,
        previousGmailAccount: effectivePrevGmail,
      );
      if (!mounted) return result;
      state = state.copyWith(
        branchInboxStatuses: const <BranchInboxDeviceStatus>[],
        lastRestoreSummary: () => null,
        authSession: authenticateAppSession
            ? const AuthSession()
            : state.authSession,
      );
      refreshDashboard();
    } else {
      final updated = state.companySettings.copyWith(
        syncGmailAccount: resolvedGmail,
        syncFolderPath: resolvedFolder,
      );
      _db.saveCompanySettings(updated);
      refreshDashboard();
    }

    if (resolvedGmail.trim().isNotEmpty) {
      await _syncService.setLastSyncedGmailAccount(resolvedGmail);
    }

    final pullRes = await _syncService.restoreFromCloud(
      mode: CloudRestoreMode.merge,
      isEmployeePortalOnly: false,
      cloudOnly: isSwitchingToDifferentAccount,
      skipDriveFolderFallback: isSwitchingToDifferentAccount &&
          (syncFolderPath == null || syncFolderPath.trim().isEmpty),
    );
    if (!mounted) return result;
    refreshDashboard();

    final bool isMissingRemoteOnSwitch = isSwitchingToDifferentAccount &&
        pullRes.summary == null &&
        !pullRes.status.isDecryptionKeyMismatch &&
        pullRes.status.stage == DriveSyncStage.error &&
        pullRes.status.message.contains('bulunamadı');

    if (pullRes.status.stage == DriveSyncStage.error &&
        !isMissingRemoteOnSwitch) {
      if (mounted) {
        state = state.copyWith(syncStatus: pullRes.status);
      }
      if (authenticateAppSession) {
        if (mounted) {
          state = state.copyWith(
            authSession: state.authSession.copyWith(
              isAuthenticated: false,
              errorMessage: () => null,
            ),
          );
        }
        return BrowserGoogleSignInResult(
          success: true,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          email: resolvedGmail,
          displayName: result.displayName,
          requiresUserLogin: true,
          message: pullRes.status.message,
        );
      }
      return BrowserGoogleSignInResult(
        success: true,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        email: resolvedGmail,
        displayName: result.displayName,
        message: pullRes.status.message,
      );
    }

    DriveSyncStatus finalSyncStatus = pullRes.status;
    if (pullRes.summary == null) {
      if (isSwitchingToDifferentAccount) {
        finalSyncStatus = DriveSyncStatus(
          stage: DriveSyncStage.synced,
          lastSyncTime: DateTime.now(),
          connectedGmail: resolvedGmail,
          isCloudApiVerified: result.accessToken.trim().isNotEmpty,
          isDriveFolderMirrored: false,
          cloudProfileId: state.companySettings.cloudProfileId,
          lastOperation: 'account_switch',
          message:
              'Google bulut oturumu açıldı ($resolvedGmail). Bulutta henüz yedek bulunamadı; temiz çalışma alanı hazır.',
        );
      } else {
        finalSyncStatus = await _syncService.pushToCloud(
          deviceName: 'Hasibu İlk Bulut Eşitleme',
          force: true,
          operationLabel: 'sync',
        );
      }
    }
    if (finalSyncStatus.connectedGmail.trim().isEmpty &&
        resolvedGmail.isNotEmpty) {
      finalSyncStatus = finalSyncStatus.copyWith(connectedGmail: resolvedGmail);
    }
    if (mounted) {
      state = state.copyWith(syncStatus: finalSyncStatus);
    }

    if (authenticateAppSession) {
      final activeAppUsers =
          state.appUsers.where((u) => u.isActive).toList(growable: false);
      if (activeAppUsers.isNotEmpty) {
        AppUserAccount? matched;
        final targetEmail = resolvedGmail.trim().toLowerCase();
        if (targetEmail.isNotEmpty) {
          for (final u in activeAppUsers) {
            if ((u.linkedGmail ?? '').trim().toLowerCase() == targetEmail) {
              matched = u;
              break;
            }
          }
        }
        if (mounted) {
          state = state.copyWith(
            authSession: state.authSession.copyWith(
              isAuthenticated: false,
              errorMessage: () => null,
            ),
          );
        }
        return BrowserGoogleSignInResult(
          success: true,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          email: resolvedGmail,
          displayName: result.displayName,
          requiresUserLogin: true,
          suggestedUsername: matched?.username,
          message:
              'Google bulut oturumu açık ($resolvedGmail). Devam etmek için kullanıcı adınız ve parolanızla giriş yapın.',
        );
      }

      HasibuSecurityService.setFlagSecureEnabled(true);
      final disp = result.displayName.trim().isNotEmpty
          ? '${result.displayName.trim()} ($resolvedGmail)'
          : (resolvedGmail.isNotEmpty ? resolvedGmail : 'Google Yönetici');
      state = state.copyWith(
        authSession: AuthSession(
          isAuthenticated: true,
          username: resolvedGmail.isNotEmpty ? resolvedGmail : 'google_admin',
          displayName: disp,
          role: UserRole.admin,
          allowedModules: HasibuModule.activePhaseModules,
        ),
        activeModule: HasibuModule.pdksHr,
        selectedBranchId: () => null,
      );
      refreshDashboard();
    }

    return result;
  }

  /// Aktif bulut/yerel yedek klasörünü Windows Gezgini'nde (Explorer) açar.
  Future<String> openCloudSyncFolder([String? customFolder]) {
    return _syncService.openSyncFolderInExplorer(customFolder);
  }

  /// Bağlı Google (Gmail) hesabının bağlantısını keser.
  Future<void> disconnectGmailSyncAccount() async {
    final previousGmail = state.companySettings.syncGmailAccount.trim();
    if (previousGmail.isNotEmpty) {
      await _syncService.setLastSyncedGmailAccount(previousGmail);
    }
    final updated = state.companySettings.copyWith(
      syncGmailAccount: '',
    );
    _db.saveCompanySettings(updated);
    try {
      await _googleAuthAdapter.signOut();
    } catch (e) {
      debugPrint('PdksProviders: disconnect signOut uyarısı: $e');
    }
    try {
      await _syncService.clearTokens();
    } catch (e) {
      debugPrint('PdksProviders: disconnect clearTokens uyarısı: $e');
      if (mounted) {
        state = state.copyWith(
          syncStatus: state.syncStatus.copyWith(message: 'Token silme uyarısı: $e'),
        );
      }
    }
    _syncService.clearRuntimeSyncCaches();
    if (!mounted) return;
    refreshDashboard();
    state = state.copyWith(
      branchInboxStatuses: const <BranchInboxDeviceStatus>[],
      syncStatus: const DriveSyncStatus(
        stage: DriveSyncStage.idle,
        connectedGmail: '',
        message: 'Google hesap bağlantısı kaldırıldı.',
      ),
    );
  }

  /// Cihaz olmayan şubelerde Konum (GPS Geofence + Sahte GPS Kontrolü) doğrulaması ile
  /// personel giriş-çıkış kaydı oluşturur (QR kod yoklama güvenlik nedeniyle kaldırılmıştır).
  Future<String> recordBranchMobileCheckIn({
    required Employee employee,
    required Branch branch,
    required AttendanceSource source,
    required bool isCheckIn,
    double? currentLat,
    double? currentLng,
    String? qrPayload,
    bool isMockedGps = false,
    bool isSimulatedFallback = false,
    DateTime? verificationNow,
  }) async {
    if (source == AttendanceSource.mobileQr) {
      return 'QR kod ile yoklama özelliği kaldırılmıştır. Lütfen yüz okutma terminali veya GPS konum yoklamasını kullanın.';
    }
    if (!_isBranchAllowed(branch.id) || !_isBranchAllowed(employee.branchId)) {
      return 'Yetki kapsamınız dışındaki şube veya personel için yoklama kaydı oluşturulamaz.';
    }
    if (state.authSession.role == UserRole.employee) {
      final sessionCard = state.authSession.employeeCardNo?.trim() ?? '';
      if (employee.cardNo != sessionCard || branch.id != employee.branchId) {
        return 'Personel oturumunda yalnızca kendi adınıza ve kendi şubenizde yoklama kaydı oluşturabilirsiniz.';
      }
      if (isSimulatedFallback) {
        return 'Gerçek GPS sensörü doğrulanamadığı için personel konum girişi reddedildi.';
      }
    }
    // [HW-06] Sahte GPS (position.isMocked) Kontrolü
    if (isMockedGps) {
      final alertMsg =
          'SAHTE GPS ALGILANDI: ${employee.fullName} (#${employee.cardNo}) - ${branch.name} şubesinde sahte konum (Mock Location) ile ${isCheckIn ? "GİRİŞ" : "ÇIKIŞ"} denemesi reddedildi!';
      _db.appendAuditLog(
        actorEmployeeId: employee.cardNo,
        actionType: 'MOCK_GPS_REJECTED',
        targetRecordId: 'branch_${branch.id}_${employee.cardNo}',
        oldValue: 'isMocked=false',
        newValue:
            'isMocked=true (${currentLat?.toStringAsFixed(4) ?? "?"}, ${currentLng?.toStringAsFixed(4) ?? "?"})',
      );
      state = state.copyWith(
        mockGpsAnomalyCount: state.mockGpsAnomalyCount + 1,
        lastMockGpsAlert: () => alertMsg,
        auditLogs: _db.getAuditLogs(limit: 200),
      );
      return alertMsg;
    }

    if (source == AttendanceSource.mobileGps &&
        currentLat != null &&
        currentLng != null) {
      final double distanceMeters = _haversineMeters(
        branch.latitude,
        branch.longitude,
        currentLat,
        currentLng,
      );
      if (distanceMeters > branch.geofenceRadiusMeters) {
        return 'Konum şube sınırları dışında (${distanceMeters.round()}m > ${branch.geofenceRadiusMeters.round()}m).';
      }
    }

    final now = DateTime.now();
    final dateParts = state.selectedDate.split('-');
    final logTime = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      now.hour,
      now.minute,
      now.second,
    );
    const verifyMethod = VerifyMethod.mobileGps;

    final log = AttendanceLog(
      id: '${branch.id}_${employee.cardNo}_${logTime.millisecondsSinceEpoch}',
      cardNo: employee.cardNo,
      branchId: branch.id,
      deviceNo: branch.machineNo,
      timestamp: logTime,
      isCheckIn: isCheckIn,
      source: source,
      verifyMethod: verifyMethod,
      integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
        cardNo: employee.cardNo,
        timestamp: logTime,
        isCheckIn: isCheckIn,
        verifyMethod: verifyMethod.name,
      ),
    );

    _db.upsertAttendanceLog(log);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Mobil (${branch.name})');
    return '${employee.fullName} için ${branch.name} şubesinde ${source.label} ile ${isCheckIn ? "GİRİŞ" : "ÇIKIŞ"} kaydedildi.';
  }

  static double _annualLeaveCost(LeaveRecord? record) {
    if (record == null || record.leaveType != LeaveType.yillikIzin) return 0.0;
    return record.effectiveLeaveDays;
  }

  void _applyAnnualLeaveDelta(int employeeId, double delta) {
    if (delta.abs() < 0.001) return;
    final emp = _db
        .getEmployees()
        .where((e) => e.id == employeeId)
        .firstOrNull;
    if (emp == null) return;
    final nextExact = (emp.usedAnnualLeaveDays + delta).clamp(0.0, 365.0);
    final roundedExact = (nextExact * 20).round() / 20.0;
    if ((roundedExact - emp.usedAnnualLeaveDays).abs() < 0.001 &&
        roundedExact.round() == emp.usedAnnualLeave) {
      return;
    }
    _db.upsertEmployee(
      emp.copyWith(
        usedAnnualLeave: roundedExact.round(),
        usedAnnualLeaveExact: () => roundedExact,
      ),
    );
  }

  /// Devamsız personeli İzinli (Yıllık, Ücretli, Mazeret, Saatlik/Yarım Gün) veya Raporlu olarak işaretler
  /// ve yıllık izin bakiyesini otomatik günceller.
  Future<void> assignLeaveOrReport({
    required int employeeId,
    required LeaveType leaveType,
    required String note,
    String? customDateKey,
    bool isHalfDay = false,
    double? durationHours,
    String? startTime,
    String? endTime,
  }) async {
    if (!_isEmployeeInScope(employeeId)) return;
    final targetDate = customDateKey ?? state.selectedDate;
    final recordId = 'leave_${employeeId}_$targetDate';
    final previous = _db
        .getLeaveRecordsForEmployee(employeeId)
        .where((r) => r.id == recordId)
        .firstOrNull;
    final record = LeaveRecord(
      id: recordId,
      employeeId: employeeId,
      date: targetDate,
      leaveType: leaveType,
      note: note.trim().isEmpty ? leaveType.label : note.trim(),
      isHalfDay: isHalfDay,
      durationHours: durationHours,
      startTime: startTime,
      endTime: endTime,
    );
    _db.upsertLeaveRecord(record);
    _applyAnnualLeaveDelta(
      employeeId,
      _annualLeaveCost(record) - _annualLeaveCost(previous),
    );
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'LEAVE_ASSIGNED',
      targetRecordId: recordId,
      oldValue: previous?.leaveType.label ?? 'NONE',
      newValue: '${leaveType.label} (${record.formattedScopeLabel})',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu İK Yönetimi');
  }

  /// Başlangıç ve bitiş tarihleri arasındaki iş günleri için toplu izin/rapor kaydı oluşturur.
  Future<int> assignLeaveDateRange({
    required int employeeId,
    required DateTime startDate,
    required DateTime endDate,
    required LeaveType leaveType,
    required String note,
    bool excludeOffDaysAndHolidays = true,
    bool isHalfDay = false,
    double? durationHours,
    String? startTime,
    String? endTime,
  }) async {
    if (!_isEmployeeInScope(employeeId)) return 0;
    final DateTime normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final DateTime normalizedEnd =
        DateTime(endDate.year, endDate.month, endDate.day);
    if (normalizedEnd.isBefore(normalizedStart)) return 0;

    final emp = _db
        .getEmployees()
        .where((e) => e.id == employeeId)
        .firstOrNull;
    final shifts = _db.getShifts();
    final shift = shifts.firstWhere(
      (s) => s.id == (emp?.shiftId ?? 1),
      orElse: () =>
          shifts.isNotEmpty ? shifts.first : WorkplaceSeedData.shifts.first,
    );
    final holidayKeys = {
      for (final h in _db.getPublicHolidays())
        if (!h.isHalfDay) h.dateKey,
    };
    final existingById = {
      for (final r in _db.getLeaveRecordsForEmployee(employeeId)) r.id: r,
    };
    final bool isMultiDay = normalizedEnd.isAfter(normalizedStart);

    double daysCount = 0;
    double annualDelta = 0.0;
    DateTime cursor = normalizedStart;
    while (!cursor.isAfter(normalizedEnd) && daysCount <= 90) {
      final dKey = formatDateKey(cursor);
      if (isMultiDay && excludeOffDaysAndHolidays) {
        final isOff = holidayKeys.contains(dKey) ||
            AttendanceEvaluationEngine.isScheduledWeeklyOffDay(
              employee: emp,
              shift: shift,
              dateKey: dKey,
            );
        if (isOff) {
          cursor = cursor.add(const Duration(days: 1));
          continue;
        }
      }
      final recordId = 'leave_${employeeId}_$dKey';
      final previous = existingById[recordId];
      final rec = LeaveRecord(
        id: recordId,
        employeeId: employeeId,
        date: dKey,
        leaveType: leaveType,
        note: note.trim().isEmpty ? leaveType.label : note.trim(),
        isHalfDay: isHalfDay,
        durationHours: durationHours,
        startTime: startTime,
        endTime: endTime,
      );
      _db.upsertLeaveRecord(rec);
      annualDelta += _annualLeaveCost(rec) - _annualLeaveCost(previous);
      daysCount += 1;
      cursor = cursor.add(const Duration(days: 1));
    }

    _applyAnnualLeaveDelta(employeeId, annualDelta);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'LEAVE_RANGE_ASSIGNED',
      targetRecordId: 'emp_$employeeId',
      oldValue: '${formatDateKey(normalizedStart)}..${formatDateKey(normalizedEnd)}',
      newValue: '${leaveType.label} (${daysCount.round()} gün)',
    );

    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu İK İzin/Rapor Yönetimi');
    return daysCount.round();
  }

  Future<void> deleteLeaveRecord(String leaveId) async {
    LeaveRecord? target;
    for (final rec in _db.getAllLeaveRecords()) {
      if (rec.id == leaveId) {
        target = rec;
        break;
      }
    }
    if (target == null) return;
    if (_isBranchScoped && !_isEmployeeInScope(target.employeeId)) return;
    _db.deleteLeaveRecord(leaveId);
    final refund = _annualLeaveCost(target);
    if (refund > 0) {
      _applyAnnualLeaveDelta(target.employeeId, -refund);
    }
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'LEAVE_DELETED',
      targetRecordId: leaveId,
      oldValue: '${target.date} ${target.leaveType.label}',
      newValue: 'DELETED',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu İK İzin/Rapor Yönetimi');
  }

  /// Personelin tüm tarihlerdeki giriş-çıkış, geç kalma ve izin/rapor geçmişini kronolojik olarak döndürür.
  List<EmployeeHistoryDayEntry> getEmployeeHistory(Employee emp) {
    if (!_isBranchAllowed(emp.branchId)) {
      return const <EmployeeHistoryDayEntry>[];
    }
    final logs = _db.getAttendanceLogsForEmployee(emp.cardNo);
    final leaves = _db.getLeaveRecordsForEmployee(emp.id);
    final holidayByDate = {
      for (final h in _db.getPublicHolidays()) h.dateKey: h,
    };
    final shiftMap = {for (final s in state.shifts) s.id: s};
    final empAssignments = _db.getShiftAssignments(employeeId: emp.id);
    final defaultShift = shiftMap[emp.shiftId] ??
        (state.shifts.isNotEmpty
            ? state.shifts.first
            : WorkplaceSeedData.shifts.first);

    final logsByDate = <String, List<AttendanceLog>>{};
    for (final l in logs) {
      logsByDate.putIfAbsent(l.dateKey, () => <AttendanceLog>[]).add(l);
    }
    final leaveByDate = <String, LeaveRecord>{
      for (final lv in leaves) lv.date: lv,
    };

    final allDates = <String>{
      ...logsByDate.keys,
      ...leaveByDate.keys,
      state.selectedDate,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final entries = <EmployeeHistoryDayEntry>[];
    for (final dKey in allDates) {
      final dayLogs = List<AttendanceLog>.from(
        logsByDate[dKey] ?? const <AttendanceLog>[],
      )..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final prevLogs =
          logsByDate[AttendanceEvaluationEngine.previousDateKey(dKey)] ??
              const <AttendanceLog>[];
      final nextLogs =
          logsByDate[AttendanceEvaluationEngine.nextDateKey(dKey)] ??
              const <AttendanceLog>[];
      final lv = leaveByDate[dKey];
      final holiday = holidayByDate[dKey];
      final dayShift = AttendanceEvaluationEngine.resolveShiftForDate(
        employee: emp,
        dateKey: dKey,
        shiftMap: shiftMap,
        fallbackShift: defaultShift,
        shiftAssignments: empAssignments,
      );

      final eval = AttendanceEvaluationEngine.evaluateDay(
        rawDayLogs: dayLogs,
        previousDayLogs: prevLogs,
        nextDayLogs: nextLogs,
        shift: dayShift,
        leave: lv,
        publicHoliday: holiday,
        employee: emp,
        dateKey: dKey,
      );

      entries.add(
        EmployeeHistoryDayEntry(
          dateKey: dKey,
          state: eval.state,
          firstCheckIn: eval.firstIn,
          lastCheckOut: eval.lastOut,
          allLogs: dayLogs,
          leaveRecord: lv,
          publicHoliday: holiday,
          lateMinutes: eval.lateMinutes,
          workedMinutes: eval.workedMinutes,
          breakDeductedMinutes: eval.breakDeductedMinutes,
          overtimeMinutes: eval.overtimeMinutes,
          earlyLeaveMinutes: eval.earlyLeaveMinutes,
          hasMissingCheckOut: eval.hasMissingCheckOut,
          isHolidayWork: eval.isHolidayWork,
          isWeeklyOffWork: eval.isWeeklyOffWork,
        ),
      );
    }
    return entries;
  }

  /// Tek tıkla eksik çıkış (Tek Okuma) anomalisini personelin vardiya bitiş saatine göre tamamlar.
  Future<void> quickCompleteMissingCheckOut(EmployeeDailyStatus item) async {
    if (!_isBranchAllowed(item.employee.branchId)) return;
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    await saveOrUpdateAttendanceLog(
      employee: item.employee,
      dateKey: state.selectedDate,
      timeHhMm: item.shift.endTime,
      isCheckIn: false,
      source: AttendanceSource.manual,
      verifyMethod: VerifyMethod.password,
      writeAuditLog: false,
    );
    // [AUD-02] "1-Tıkla Eksik Çıkış Tamamlama" işlemini otomatik olarak audit_logs tablosuna yazdır
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'MISSING_CHECKOUT_COMPLETED',
      targetRecordId: '${item.employee.cardNo}_${state.selectedDate}',
      oldValue: 'lastCheckOut=NULL',
      newValue: 'lastCheckOut=${item.shift.endTime}',
    );
    refreshDashboard();
  }

  /// Seçili tarihte çıkış basmayı unutan tüm personellerin çıkış saatini kendi vardiya bitiş saatlerine göre toplu tamamlar.
  Future<int> batchCompleteAllMissingCheckOuts() async {
    final targets = state.filteredByBranch
        .where((s) => s.hasMissingCheckOut)
        .toList(growable: false);
    if (targets.isEmpty) return 0;

    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;

    final dParts = state.selectedDate.split('-');
    final year = int.tryParse(dParts[0]) ?? 2026;
    final month = dParts.length > 1 ? (int.tryParse(dParts[1]) ?? 10) : 10;
    final day = dParts.length > 2 ? (int.tryParse(dParts[2]) ?? 19) : 19;

    final logsToInsert = <AttendanceLog>[];
    for (final item in targets) {
      final tParts = item.shift.endTime.split(':');
      final h = int.tryParse(tParts[0]) ?? 18;
      final m = tParts.length > 1 ? (int.tryParse(tParts[1]) ?? 0) : 0;
      final dt = DateTime(year, month, day, h, m);
      logsToInsert.add(
        AttendanceLog(
          id: 'AUTO_OUT_${item.employee.cardNo}_${state.selectedDate}_${h.toString().padLeft(2, '0')}${m.toString().padLeft(2, '0')}',
          cardNo: item.employee.cardNo,
          branchId: item.employee.branchId,
          deviceNo: 99,
          timestamp: dt,
          isCheckIn: false,
          source: AttendanceSource.manual,
          verifyMethod: VerifyMethod.password,
          integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
            cardNo: item.employee.cardNo,
            timestamp: dt,
            isCheckIn: false,
            verifyMethod: VerifyMethod.password.name,
          ),
        ),
      );
      // [AUD-02] Her tamamlanan eksik çıkış kaydını silinemez audit_logs tablosuna yazdır
      _db.appendAuditLog(
        actorEmployeeId: actor,
        actionType: 'MISSING_CHECKOUT_COMPLETED',
        targetRecordId: '${item.employee.cardNo}_${state.selectedDate}',
        oldValue: 'lastCheckOut=NULL',
        newValue: 'lastCheckOut=${item.shift.endTime} (Toplu)',
      );
    }

    _db.upsertAttendanceLogsBatch(logsToInsert);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Eksik Çıkış Otomasyonu');
    return logsToInsert.length;
  }

  /// Personel Portalı veya İK üzerinden yeni talep (İzin, Fazla Mesai, Eksik Hareket, Avans) oluşturur.
  Future<void> submitHrRequest(HrRequest request) async {
    if (_isBranchScoped &&
        !_isEmployeeInScope(request.employeeId) &&
        !_isCardInScope(request.employeeCardNo)) {
      return;
    }
    _db.upsertHrRequest(request);
    refreshDashboard();
    await _pushAutoBackupOnChange(
      'Hasibu Personel Talep Merkezi',
      isEmployeePortalOnly: state.authSession.role == UserRole.employee,
      employeeCardNo: state.authSession.employeeCardNo,
    );
  }

  /// İK Yöneticisi personel talebini Tek Tıkla Onaylar veya Reddeder.
  /// Onaylandığında izin veya unutulan giriş/çıkış hareketi otomatik olarak puantaja işlenir!
  Future<String> reviewHrRequest({
    required HrRequest request,
    required bool approve,
    String? reviewerNote,
  }) async {
    if (_isBranchScoped &&
        !_isEmployeeInScope(request.employeeId) &&
        !_isCardInScope(request.employeeCardNo)) {
      return 'Yetki kapsamınız dışındaki şubeye ait talep işlenemez.';
    }
    // [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu / Saat Manipülasyonu Kilidi
    if (state.isCommercialWriteLocked) {
      return 'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Yeni İK talebi onaylama devre dışı bırakıldı.';
    }

    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;

    final updated = request.copyWith(
      status: approve ? HrRequestStatus.approved : HrRequestStatus.rejected,
      reviewerNote: () => reviewerNote?.trim().isEmpty == true
          ? (approve ? 'İK tarafından onaylandı ve puantaja işlendi' : 'İK tarafından reddedildi')
          : reviewerNote?.trim(),
    );
    _db.upsertHrRequest(updated);

    // [AUD-02] "İK Talep Onaylama" işlemini otomatik olarak audit_logs tablosuna yazdır
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'HR_REQUEST_REVIEWED',
      targetRecordId: request.id,
      oldValue: 'status=${request.status.name}',
      newValue:
          'status=${updated.status.name} (${request.employeeCardNo} • ${request.type.name})',
    );

    String actionSummary = approve
        ? '${request.employeeName} talebi onaylandı.'
        : '${request.employeeName} talebi reddedildi.';

    if (approve) {
      if (request.type == HrRequestType.annualLeave) {
        final start =
            DateTime.tryParse(request.targetDate) ?? DateTime(2026, 10, 19);
        final end = DateTime.tryParse(request.endDate ?? request.targetDate) ??
            start;
        final days = await assignLeaveDateRange(
          employeeId: request.employeeId,
          startDate: start,
          endDate: end,
          leaveType: request.leaveType,
          note: '${request.leaveType.label} (Talep Onayı: ${request.reason})',
        );
        actionSummary =
            '${request.employeeName} için $days günlük ${request.leaveType.label} onaylandı ve puantaja işlendi.';
      } else if (request.type == HrRequestType.missingPunchCorrection) {
        final empStatus = state.dailyStatuses
            .where((s) => s.employee.id == request.employeeId)
            .toList(growable: false);
        if (empStatus.isNotEmpty) {
          final emp = empStatus.first.employee;
          final timeStr = request.requestedTime ??
              (request.isCheckInCorrection
                  ? empStatus.first.shift.startTime
                  : empStatus.first.shift.endTime);
          await saveOrUpdateAttendanceLog(
            employee: emp,
            dateKey: request.targetDate,
            timeHhMm: timeStr,
            isCheckIn: request.isCheckInCorrection,
            source: AttendanceSource.manual,
            verifyMethod: VerifyMethod.password,
          );
          actionSummary =
              '${request.employeeName} için ${request.targetDate} $timeStr ${request.isCheckInCorrection ? "Giriş" : "Çıkış"} hareketi onaylanıp eklendi.';
        }
      } else if (request.type == HrRequestType.overtimeApproval) {
        final mins = request.overtimeMinutes;
        _db.appendAuditLog(
          actorEmployeeId: actor,
          actionType: 'OVERTIME_REQUEST_APPROVED',
          targetRecordId: request.employeeCardNo,
          oldValue: 'pending',
          newValue: '${request.targetDate} (+$mins dk onaylı FM)',
        );
        actionSummary =
            '${request.employeeName} için ${request.targetDate} tarihli +$mins dk fazla mesai talebi onaylandı.';
      }
    }

    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu İK Onay Merkezi');
    return actionSummary;
  }

  /// 4857 sayılı İş Kanunu Md. 53 uyarınca kıdem yılına göre eksik tanımlanmış yıllık izin haklarını otomatik günceller.
  Future<int> syncStatutoryLeaveEntitlements() async {
    final employees = _db
        .getEmployees()
        .where((e) => _isBranchAllowed(e.branchId))
        .toList(growable: false);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    int updatedCount = 0;
    for (final emp in employees) {
      if (emp.isSeparatedNow) continue;
      if (emp.hasStatutoryLeaveMismatch) {
        final oldVal = emp.annualLeaveEntitlement;
        final newVal = emp.statutoryAnnualLeaveEntitlement;
        _db.upsertEmployee(
          emp.copyWith(
            annualLeaveEntitlement: newVal,
          ),
        );
        // [AUD-02] "Yıllık İzin Hakediş Eşitleme" işlemini otomatik olarak audit_logs tablosuna yazdır
        _db.appendAuditLog(
          actorEmployeeId: actor,
          actionType: 'STATUTORY_LEAVE_SYNCED',
          targetRecordId: emp.cardNo,
          oldValue: 'annualLeaveEntitlement=$oldVal',
          newValue: 'annualLeaveEntitlement=$newVal',
        );
        updatedCount++;
      }
    }
    if (updatedCount > 0) {
      refreshDashboard();
      await _pushAutoBackupOnChange('Hasibu 4857 İzin Hakediş Eşitleme');
    }
    return updatedCount;
  }

  /// Seçili tarihteki resmi PDKS & Puantaj çizelgesini Excel uyumlu (; ayraçlı) CSV metni olarak üretir.
  String generateDailyPuantajCsv({bool onlyVisible = false}) {
    // [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu Modunda resmi Excel/CSV Puantaj dışa aktarımını kilitle
    if (state.isCommercialWriteLocked) {
      return '';
    }
    final rows =
        onlyVisible ? state.visibleStatuses : state.filteredByBranch;
    return AttendanceReportEngine.generateDailyPuantajCsv(
      selectedDate: state.selectedDate,
      rows: rows,
    );
  }

  /// Seçili tarih aralığı için tüm personellerin devam, geç kalma, izin, rapor ve devamsızlık özetini hesaplar.
  List<EmployeeAttendancePeriodSummary> buildAttendancePeriodReport({
    required String startDateKey,
    required String endDateKey,
    int? branchId,
    int? departmentId,
    String searchQuery = '',
    bool onlyWithAbsences = false,
    bool onlyWithLates = false,
    bool excludeSundays = false,
  }) {
    final parsedStart = DateTime.tryParse(startDateKey) ??
        DateTime.tryParse(state.selectedDate) ??
        DateTime.now();
    final parsedEnd = DateTime.tryParse(endDateKey) ?? parsedStart;
    var rangeStart =
        DateTime(parsedStart.year, parsedStart.month, parsedStart.day);
    var rangeEnd = DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day);
    if (rangeStart.isAfter(rangeEnd)) {
      final tmp = rangeStart;
      rangeStart = rangeEnd;
      rangeEnd = tmp;
    }
    if (rangeEnd.difference(rangeStart).inDays > 365) {
      rangeStart = rangeEnd.subtract(const Duration(days: 365));
    }

    final startKey = formatDateKey(rangeStart);
    final endKey = formatDateKey(rangeEnd);
    final prevStartKey = AttendanceEvaluationEngine.previousDateKey(startKey);
    final nextEndKey = AttendanceEvaluationEngine.nextDateKey(endKey);

    final employees = _db
        .getEmployees()
        .where((e) => _isBranchAllowed(e.branchId))
        .toList(growable: false);
    final branches = _db.getBranches();
    final departments = _db.getDepartments();
    final shifts = _db.getShifts();
    final shiftAssignments = _db.getShiftAssignments();
    final logs = _db.getAttendanceLogsInDateRange(prevStartKey, nextEndKey);
    final leaves = _db.getLeaveRecordsInDateRange(startKey, endKey);
    final holidayByDate = {
      for (final h in _db.getPublicHolidaysInDateRange(startKey, endKey))
        h.dateKey: h,
    };

    final int? effectiveFilterBranchId =
        (branchId != null && _isBranchAllowed(branchId))
            ? branchId
            : (_scopedBranchIds.length == 1 ? _scopedBranchIds.first : null);

    return AttendanceReportEngine.buildAttendancePeriodReport(
      startDateKey: startKey,
      endDateKey: endKey,
      employees: employees,
      branchMap: {for (final b in branches) b.id: b},
      deptMap: {for (final d in departments) d.id: d},
      shiftMap: {for (final s in shifts) s.id: s},
      fallbackBranch: branches.isNotEmpty
          ? branches.first
          : WorkplaceSeedData.branches.first,
      fallbackShift:
          shifts.isNotEmpty ? shifts.first : WorkplaceSeedData.shifts.first,
      logsWithBoundaryDays: logs,
      leaves: leaves,
      holidayByDate: holidayByDate,
      shiftAssignments: shiftAssignments,
      filterBranchId: effectiveFilterBranchId,
      departmentId: departmentId,
      searchQuery: searchQuery,
      onlyWithAbsences: onlyWithAbsences,
      onlyWithLates: onlyWithLates,
      excludeSundays: excludeSundays,
    );
  }

  /// Seçili ay için 1–31 günlük PDKS puantaj matrisini üretir.
  List<MonthlyPuantajRow> buildMonthlyPuantajMatrix({
    required int year,
    required int month,
    int? branchId,
    int? departmentId,
    String searchQuery = '',
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startKey = formatDateKey(DateTime(year, month, 1));
    final endKey = formatDateKey(DateTime(year, month, daysInMonth));
    final prevStartKey = AttendanceEvaluationEngine.previousDateKey(startKey);
    final nextEndKey = AttendanceEvaluationEngine.nextDateKey(endKey);

    final employees = _db
        .getEmployees()
        .where((e) => _isBranchAllowed(e.branchId))
        .toList(growable: false);
    final branches = _db.getBranches();
    final departments = _db.getDepartments();
    final shifts = _db.getShifts();
    final shiftAssignments = _db.getShiftAssignments();
    final logs = _db.getAttendanceLogsInDateRange(prevStartKey, nextEndKey);
    final leaves = _db.getLeaveRecordsInDateRange(startKey, endKey);
    final holidayByDate = {
      for (final h in _db.getPublicHolidaysInDateRange(startKey, endKey))
        h.dateKey: h,
    };

    final int? effectiveFilterBranchId =
        (branchId != null && _isBranchAllowed(branchId))
            ? branchId
            : (_scopedBranchIds.length == 1 ? _scopedBranchIds.first : null);

    return AttendanceReportEngine.buildMonthlyPuantajMatrix(
      year: year,
      month: month,
      employees: employees,
      branchMap: {for (final b in branches) b.id: b},
      deptMap: {for (final d in departments) d.id: d},
      shiftMap: {for (final s in shifts) s.id: s},
      fallbackBranch: branches.isNotEmpty
          ? branches.first
          : WorkplaceSeedData.branches.first,
      fallbackShift:
          shifts.isNotEmpty ? shifts.first : WorkplaceSeedData.shifts.first,
      logsWithBoundaryDays: logs,
      leaves: leaves,
      holidayByDate: holidayByDate,
      shiftAssignments: shiftAssignments,
      filterBranchId: effectiveFilterBranchId,
      departmentId: departmentId,
      searchQuery: searchQuery,
    );
  }

  String generateMonthlyPuantajCsv({
    required int year,
    required int month,
    int? branchId,
    int? departmentId,
    String searchQuery = '',
  }) {
    if (state.isCommercialWriteLocked) return '';
    final rows = buildMonthlyPuantajMatrix(
      year: year,
      month: month,
      branchId: branchId,
      departmentId: departmentId,
      searchQuery: searchQuery,
    );
    return AttendanceReportEngine.generateMonthlyPuantajCsv(
      rows,
      year: year,
      month: month,
    );
  }

  /// Seçili tarih aralığındaki Devam / Devamsızlık Raporunu Excel uyumlu (; ayraçlı) CSV olarak üretir.
  String generatePeriodAttendanceReportCsv({
    required String startDateKey,
    required String endDateKey,
    int? branchId,
    int? departmentId,
    String searchQuery = '',
    bool onlyWithAbsences = false,
    bool onlyWithLates = false,
    bool excludeSundays = false,
  }) {
    if (state.isCommercialWriteLocked) {
      return '';
    }
    final rows = buildAttendancePeriodReport(
      startDateKey: startDateKey,
      endDateKey: endDateKey,
      branchId: branchId,
      departmentId: departmentId,
      searchQuery: searchQuery,
      onlyWithAbsences: onlyWithAbsences,
      onlyWithLates: onlyWithLates,
      excludeSundays: excludeSundays,
    );
    final rangeLabel = '${formatDisplayDate(startDateKey, includeTodayBadge: false)} - ${formatDisplayDate(endDateKey, includeTodayBadge: false)}';
    final buf = StringBuffer();
    buf.writeln(
      'Tarih Aralığı;Kart No;Ad Soyad;Şube;Bölüm;Toplam Gün;Devam (Gün);Zamanında;Geç Kalma (Gün);Toplam Gecikme (Dk);Devamsızlık (Gün);İzinli (Gün);Raporlu (Gün);Eksik Çıkış (Gün);Net Çalışma (Saat);Fazla Mesai (Dk);Devam Oranı (%);Devamsız Tarihler',
    );
    for (final row in rows) {
      final workedHours = (row.totalWorkedMinutes / 60.0).toStringAsFixed(1);
      final rateStr = row.attendanceRatePercent.toStringAsFixed(1);
      final absentDatesStr = row.absentDateKeys.isEmpty
          ? '-'
          : row.absentDateKeys
              .map((d) => formatDisplayDate(d, includeTodayBadge: false))
              .join(', ');
      buf.writeln(
        '${AttendanceReportEngine.sanitizeCsvCell(rangeLabel)};'
        '${AttendanceReportEngine.sanitizeCsvCell(row.employee.cardNo)};'
        '${AttendanceReportEngine.sanitizeCsvCell(row.employee.fullName)};'
        '${AttendanceReportEngine.sanitizeCsvCell(row.branch.name)};'
        '${AttendanceReportEngine.sanitizeCsvCell(row.department.name)};'
        '${row.totalDays};'
        '${row.presentDays};'
        '${row.onTimeDays};'
        '${row.lateDays};'
        '${row.totalLateMinutes};'
        '${row.absentDays};'
        '${row.onLeaveDays};'
        '${row.sickReportDays};'
        '${row.missingCheckOutDays};'
        '$workedHours;'
        '${row.totalOvertimeMinutes};'
        '%$rateStr;'
        '${AttendanceReportEngine.sanitizeCsvCell(absentDatesStr)}',
      );
    }
    return buf.toString();
  }

  /// Personelin özlük dosyasına resmi evrak dijital kopyası ekler veya günceller.
  Future<void> savePersonnelDocument(PersonnelDocument doc) async {
    if (!_isEmployeeInScope(doc.employeeId)) return;
    _db.upsertPersonnelDocument(doc);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Özlük Dosyası Yönetimi');
  }

  /// Personelin özlük dosyasından dijital evrak kaydını siler.
  Future<void> deletePersonnelDocument(String docId) async {
    if (_isBranchScoped) {
      PersonnelDocument? target;
      for (final doc in _db.getAllPersonnelDocuments()) {
        if (doc.id == docId) {
          target = doc;
          break;
        }
      }
      if (target == null || !_isEmployeeInScope(target.employeeId)) return;
    }
    _db.deletePersonnelDocument(docId);
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Özlük Dosyası Yönetimi');
  }

  /// Aktif kullanıcının (Yönetici, Yetkili Kullanıcı veya Personel) kendine özgü temasını günceller.
  Future<void> setCurrentUserThemeMode(HasibuThemeMode mode) async {
    if (state.authSession.isAuthenticated &&
        state.authSession.appUserId != null) {
      _db.updateAppUserThemeMode(state.authSession.appUserId!, mode);
      refreshDashboard();
      return;
    }
    if (state.authSession.isAuthenticated &&
        state.authSession.role == UserRole.employee &&
        state.authSession.employeeCardNo != null) {
      final cardNo = state.authSession.employeeCardNo!;
      final idx = state.dailyStatuses.indexWhere(
        (s) => s.employee.cardNo == cardNo,
      );
      if (idx >= 0) {
        final emp = state.dailyStatuses[idx].employee.copyWith(themeMode: mode);
        _db.upsertEmployee(emp);
        refreshDashboard();
        return;
      }
    }
    final updated = state.companySettings.copyWith(adminThemeMode: mode);
    _db.saveCompanySettings(updated);
    refreshDashboard();
  }

  /// Şirket logosunu (yerel görsel yolu veya kurumsal hazır logo) günceller.
  Future<void> updateCompanyLogo(String? logoPath) async {
    final clean = logoPath?.trim();
    final updated = state.companySettings.copyWith(
      logoPath: () => (clean == null || clean.isEmpty) ? null : clean,
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
  }

  /// Manuel Google Drive Yedekleme & Cihazlar Arası Uzlaştırma (Zikirce_ modeli)
  Future<void> syncWithGoogleDriveNow() async {
    // [LIC-05] Salt-Okunur (Read-Only) Abonelik Sonu / Saat Manipülasyonu Kilidi
    if (state.isCommercialWriteLocked) {
      state = state.copyWith(
        syncStatus: state.syncStatus.copyWith(
          stage: DriveSyncStage.error,
          message:
              'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Google Drive senkronizasyonu devre dışı bırakıldı.',
        ),
      );
      return;
    }

    final isEmployeePortal = state.authSession.role == UserRole.employee;
    state = state.copyWith(
      isCloudBusy: true,
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: 'Google Drive (AES-256-GCM) ile eşitleniyor...',
      ),
    );
    try {
      final pullStatus = await _syncService.pullAndReconcile(
        isEmployeePortalOnly: isEmployeePortal,
      );
      if (!mounted) return;
      if (pullStatus.stage == DriveSyncStage.error) {
        refreshDashboard();
        if (mounted) {
          state = state.copyWith(syncStatus: pullStatus);
        }
        return;
      }
      final pushStatus = await _syncService.pushToCloud(
        deviceName: 'Hasibu Cihaz Senkronizasyonu',
        force: true,
        isEmployeePortalOnly: isEmployeePortal,
        employeeCardNo: state.authSession.employeeCardNo,
        operationLabel: 'sync',
      );
      if (!mounted) return;
      refreshDashboard();
      if (mounted) {
        state = state.copyWith(syncStatus: pushStatus);
      }
    } catch (e) {
      debugPrint('PdksProviders: syncWithGoogleDriveNow hatası: $e');
      if (mounted) {
        state = state.copyWith(
          syncStatus: state.syncStatus.copyWith(
            stage: DriveSyncStage.error,
            lastSyncTime: DateTime.now(),
            message: 'Google Drive eşitleme hatası: $e',
          ),
        );
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isCloudBusy: false);
      }
    }
  }

  /// Buluta anında manuel şifreli yedekleme yapar (Buluta Yedekle).
  Future<DriveSyncStatus> backupToCloudNow({String? profileId}) async {
    if (state.isCommercialWriteLocked) {
      final errStatus = state.syncStatus.copyWith(
        stage: DriveSyncStage.error,
        message:
            'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Buluta yedekleme devre dışı bırakıldı.',
      );
      state = state.copyWith(syncStatus: errStatus);
      return errStatus;
    }

    final isEmployeePortal = state.authSession.role == UserRole.employee;
    state = state.copyWith(
      isCloudBusy: true,
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: 'Bulut yedeği hazırlanıp yükleniyor...',
      ),
    );
    try {
      final status = await _syncService.pushToCloud(
        deviceName: 'Hasibu Manuel Bulut Yedekleme',
        force: true,
        isEmployeePortalOnly: isEmployeePortal,
        employeeCardNo: state.authSession.employeeCardNo,
        profileId: profileId,
        operationLabel: 'backup',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: status);
      }
      if (mounted && status.isTrulySynced) {
        await refreshAvailableCloudBackups();
      }
      return status;
    } catch (e) {
      debugPrint('PdksProviders: backupToCloudNow hatası: $e');
      final errStatus = state.syncStatus.copyWith(
        stage: DriveSyncStage.error,
        lastSyncTime: DateTime.now(),
        message: 'Buluta yedekleme hatası: $e',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: errStatus);
      }
      return errStatus;
    } finally {
      if (mounted) {
        state = state.copyWith(isCloudBusy: false);
      }
    }
  }

  /// Buluttan şifreli yedeği indirir ve seçilen stratejiye göre geri yükler (Buluttan Yükle).
  Future<({DriveSyncStatus status, CloudRestoreSummary? summary})>
      restoreFromCloudNow({
    String? profileId,
    CloudRestoreMode mode = CloudRestoreMode.merge,
    bool cloudOnly = false,
    String? overrideWorkspaceKey,
  }) async {
    if (state.isCommercialWriteLocked) {
      final errStatus = state.syncStatus.copyWith(
        stage: DriveSyncStage.error,
        message:
            'KİLİTLİ (Salt-Okunur Mod): ${state.licenseStatusMessage} — Buluttan geri yükleme devre dışı bırakıldı.',
      );
      state = state.copyWith(syncStatus: errStatus);
      return (status: errStatus, summary: null);
    }

    final isEmployeePortal = state.authSession.role == UserRole.employee;
    state = state.copyWith(
      isCloudBusy: true,
      syncStatus: state.syncStatus.copyWith(
        stage: DriveSyncStage.syncing,
        message: 'Bulut yedeği indiriliyor ve uygulanıyor...',
      ),
    );
    try {
      final res = await _syncService.restoreFromCloud(
        profileId: profileId,
        mode: mode,
        isEmployeePortalOnly: isEmployeePortal,
        cloudOnly: cloudOnly,
        overrideWorkspaceKey: overrideWorkspaceKey,
      );
      if (!mounted) return res;
      if (res.summary != null || res.status.isTrulySynced) {
        refreshDashboard();
        _configureAutoPollTimer();
        _configureAutoCloudBackupTimer();
      }
      if (mounted) {
        state = state.copyWith(
          syncStatus: res.status,
          lastRestoreSummary: res.summary != null ? () => res.summary : null,
        );
      }
      return res;
    } catch (e) {
      debugPrint('PdksProviders: restoreFromCloudNow hatası: $e');
      final errStatus = state.syncStatus.copyWith(
        stage: DriveSyncStage.error,
        lastSyncTime: DateTime.now(),
        message: 'Buluttan yükleme hatası: $e',
      );
      if (mounted) {
        state = state.copyWith(syncStatus: errStatus);
      }
      return (status: errStatus, summary: null);
    } finally {
      if (mounted) {
        state = state.copyWith(isCloudBusy: false);
      }
    }
  }

  /// Bağlı Google Drive hesabındaki ve klasöründeki tüm yedek profillerini tarar.
  Future<List<CloudBackupProfileInfo>> refreshAvailableCloudBackups() async {
    final list = await _syncService.listAvailableCloudBackups();
    if (mounted) {
      state = state.copyWith(availableCloudBackups: list);
    }
    return list;
  }

  /// Otomatik bulut yedekleme ve aktif yedek profili (kasa) ayarlarını günceller.
  Future<void> updateCloudBackupSettings({
    bool? autoCloudBackupEnabled,
    int? autoCloudBackupMinutes,
    bool? autoCloudBackupOnChange,
    String? cloudProfileId,
    String? cloudProfileLabel,
  }) async {
    final normalizedProfile = cloudProfileId != null
        ? GoogleDriveSyncService.normalizeCloudProfileId(cloudProfileId)
        : null;
    final updated = state.companySettings.copyWith(
      autoCloudBackupEnabled: autoCloudBackupEnabled,
      autoCloudBackupMinutes: autoCloudBackupMinutes?.clamp(5, 1440),
      autoCloudBackupOnChange: autoCloudBackupOnChange,
      cloudProfileId: normalizedProfile,
      cloudProfileLabel: cloudProfileLabel?.trim().isNotEmpty == true
          ? cloudProfileLabel!.trim()
          : null,
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
    _configureAutoCloudBackupTimer();
  }

  /// Uygulama yeniden açıldığında kalıcı Google Bulut oturumunu geri yükler.
  Future<void> restorePersistedGoogleSession() async {
    final restored = await _syncService.restorePersistedGoogleSession();
    if (mounted && restored != null) {
      state = state.copyWith(syncStatus: restored);
    }
  }

  Future<String> getCloudWorkspaceKey() => _syncService.getWorkspaceKey();

  Future<void> updateCloudWorkspaceKey(String key) =>
      _syncService.saveWorkspaceKey(key);

  Future<CloudEncryptionKeyMode> getCloudEncryptionKeyMode() =>
      _syncService.getCloudEncryptionKeyMode();

  Future<void> setCloudEncryptionPassphrase(String passphrase) =>
      _syncService.saveCloudSyncPassphrase(passphrase);

  Future<void> useAutomaticCloudEncryption() =>
      _syncService.useAutomaticAccountEncryption();

  /// Aynı şirket (ve aynı Gmail bulut yedeği) altında yeni yetkili kullanıcı ekler veya günceller.
  Future<String?> saveAppUser({
    String? existingId,
    required String username,
    required String displayName,
    String? plainPassword,
    required AppUserRole role,
    required List<HasibuModule> allowedModules,
    int? allowedBranchId,
    List<int>? allowedBranchIds,
    String? linkedGmail,
    bool isActive = true,
  }) async {
    if (_isBranchScoped) {
      return 'Şube kapsamlı kullanıcı yetkili hesap yönetimi yapamaz.';
    }
    final normalizedBranchIds = AppUserAccount.normalizeBranchIds(
      allowedBranchIds,
      legacyBranchId: allowedBranchId,
    );
    if (role == AppUserRole.branchSupervisor && normalizedBranchIds.isEmpty) {
      return 'Şube Sorumlusu için en az bir yetkili şube seçilmelidir.';
    }

    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      return 'Kullanıcı adı boş bırakılamaz.';
    }
    if (cleanUsername ==
        state.companySettings.adminUsername.trim().toLowerCase()) {
      return 'Ana yönetici kullanıcı adı ("$cleanUsername") ile aynı kullanıcı adı kullanılamaz.';
    }

    final duplicate = _db.findAppUserByUsername(cleanUsername);
    if (duplicate != null && duplicate.id != existingId) {
      return '"$cleanUsername" kullanıcı adı zaten kayıtlı.';
    }

    AppUserAccount? existingUser;
    if (existingId != null && existingId.trim().isNotEmpty) {
      for (final u in _db.getAppUsers()) {
        if (u.id == existingId) {
          existingUser = u;
          break;
        }
      }
    }

    final trimmedPlain = plainPassword?.trim() ?? '';
    if (existingUser == null && trimmedPlain.isEmpty) {
      return 'Yeni kullanıcı için parola zorunludur.';
    }

    final passwordHash = trimmedPlain.isEmpty
        ? existingUser!.passwordHash
        : HasibuSecurityService.hashPassword(trimmedPlain);

    final account = AppUserAccount(
      id: existingUser?.id ?? 'USR-${DateTime.now().microsecondsSinceEpoch}',
      username: cleanUsername,
      displayName:
          displayName.trim().isEmpty ? cleanUsername : displayName.trim(),
      passwordHash: passwordHash,
      role: role,
      allowedModules: allowedModules.isEmpty ? role.defaultModules : allowedModules,
      allowedBranchId:
          normalizedBranchIds.isNotEmpty ? normalizedBranchIds.first : null,
      allowedBranchIds: normalizedBranchIds,
      linkedGmail: linkedGmail?.trim().isEmpty == true
          ? null
          : linkedGmail?.trim(),
      isActive: isActive,
      themeMode: existingUser?.themeMode ?? HasibuThemeMode.light,
      createdAtIso:
          existingUser?.createdAtIso ?? DateTime.now().toIso8601String(),
    );

    _db.upsertAppUser(account);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: existingUser == null ? 'APP_USER_CREATED' : 'APP_USER_UPDATED',
      targetRecordId: cleanUsername,
      oldValue: existingUser == null
          ? 'NEW'
          : 'role=${existingUser.role.name}, active=${existingUser.isActive}',
      newValue:
          'role=${account.role.name}, active=${account.isActive}, branch=${normalizedBranchIds.isEmpty ? "ALL" : normalizedBranchIds.join(",")}',
    );

    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Çoklu Kullanıcı Yönetimi');
    return null;
  }

  Future<void> deleteAppUser(String userId) async {
    _db.deleteAppUser(userId);
    final actor = state.authSession.username.isEmpty
        ? 'admin'
        : state.authSession.username;
    _db.appendAuditLog(
      actorEmployeeId: actor,
      actionType: 'APP_USER_DELETED',
      targetRecordId: userId,
      oldValue: 'active',
      newValue: 'deleted',
    );
    refreshDashboard();
    await _pushAutoBackupOnChange('Hasibu Çoklu Kullanıcı Yönetimi');
  }

  Future<void> toggleAppUserActive(String userId, bool isActive) async {
    for (final u in _db.getAppUsers()) {
      if (u.id == userId) {
        final updated = u.copyWith(isActive: isActive);
        _db.upsertAppUser(updated);
        final actor = state.authSession.username.isEmpty
            ? 'admin'
            : state.authSession.username;
        _db.appendAuditLog(
          actorEmployeeId: actor,
          actionType: 'APP_USER_STATUS_CHANGED',
          targetRecordId: u.username,
          oldValue: 'active=${u.isActive}',
          newValue: 'active=$isActive',
        );
        refreshDashboard();
        await _pushAutoBackupOnChange('Hasibu Çoklu Kullanıcı Yönetimi');
        return;
      }
    }
  }

  /// [LIC-03] & [LIC-05] Yeni müşteri lisans tokenını (Ed25519) doğrular ve kaydeder.
  Future<LicenseVerificationResult> updateCommercialLicenseToken(
    String newLicenseToken,
  ) async {
    final result = await LicenseGuardService.verifyLicenseToken(
      newLicenseToken,
      expectedHwId: state.companySettings.hardwareFingerprint,
      currentEmployeeCount: _db.getEmployees().length,
      currentBranchCount: _db.getBranches().length,
    );
    final updated = state.companySettings.copyWith(
      licenseToken: newLicenseToken.trim(),
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
    return result;
  }

  /// [LIC-05] Abonelik Sonu (Salt-Okunur / Read-Only) modunu test etmek veya
  /// aktif kurumsal lisansı yenilemek için yardımcı fonksiyon.
  void setSubscriptionExpiredForDemo(bool expired) {
    final hwId = state.companySettings.hardwareFingerprint.isNotEmpty
        ? state.companySettings.hardwareFingerprint
        : HardwareFingerprintService.getDeviceHardwareFingerprint();
    final token = LicenseGuardService.createBootstrapLicenseTokenSync(
      company: state.companySettings.companyName,
      hwId: hwId,
      expiresAt: expired
          ? DateTime.now().toUtc().subtract(const Duration(days: 5))
          : DateTime.now().toUtc().add(const Duration(days: 365)),
    );
    final updated = state.companySettings.copyWith(
      licenseToken: token,
      hardwareFingerprint: hwId,
    );
    _db.saveCompanySettings(updated);
    refreshDashboard();
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLon = (lon2 - lon1) * math.pi / 180.0;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  void dispose() {
    _autoPollTimer?.cancel();
    _autoCloudBackupTimer?.cancel();
    _branchInboxPullTimer?.cancel();
    _realtimeUploadDebounce?.cancel();
    for (final sub in _realtimeSubs) {
      sub.cancel();
    }
    _realtimeSubs.clear();
    for (final client in _activeClients.values) {
      client.dispose();
    }
    _activeClients.clear();
    super.dispose();
  }
}

final pdksDashboardProvider =
    StateNotifierProvider<PdksDashboardNotifier, PdksDashboardState>((ref) {
  final db = ref.watch(hasibuDatabaseProvider);
  final sync = ref.watch(googleDriveSyncServiceProvider);
  final authAdapter = ref.watch(googleAuthAdapterProvider);
  final recoveryService = ref.watch(passwordRecoveryServiceProvider);
  return PdksDashboardNotifier(
    db: db,
    syncService: sync,
    googleAuthAdapter: authAdapter,
    passwordRecoveryService: recoveryService,
  );
});
