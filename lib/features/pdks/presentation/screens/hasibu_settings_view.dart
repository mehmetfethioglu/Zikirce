/// Geriye dönük uyumluluk barrel dosyası.
/// Tüm ayar bileşenleri SOLID ve döngüsüz DAG katmanlarına (Layers 4, 5, 6)
/// bölünmüştür; yeni PDKS modülleri doğrudan ilgili widget/screen dosyalarını
/// import etmelidir.
library;

export '../widgets/employee_profile_avatar.dart'
    show CompanyLogoBadge, EmployeeProfileAvatar, UserThemeSelectorBar;
export '../widgets/hasibu_theme_palette.dart' show HasibuPalette;
export 'attendance_correction_settings_view.dart'
    show AttendanceCorrectionSettingsView;
export 'company_branches_settings_view.dart'
    show CompanyAndBranchesSettingsView;
export 'employee_history_dossier_dialog.dart'
    show showEmployeeHistoryAndDossierDialog;
export 'employees_management_settings_view.dart'
    show EmployeesManagementSettingsView;
export 'leaves_and_reports_view.dart' show LeavesAndReportsSettingsView;
export 'pdks_operational_dialogs.dart'
    show
        pickPdksDateWithCalendar,
        pullTerminalAndShowPopup,
        showCompanyLogoDialog,
        showCreateHrRequestDialog,
        showGmailDriveSyncDialog,
        showPuantajCsvExportDialog,
        showTerminalDiagnosticsDialog,
        showTerminalPullResultDialog;
export 'shift_tolerance_settings_view.dart'
    show ShiftAndLateToleranceSettingsView;
