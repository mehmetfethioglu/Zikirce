import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_settings_view.dart';

enum _DossierFilter { all, missing, uploaded }

/// Personelin dijital özlük dosyası (zorunlu/opsiyonel evrak kontrol listesi,
/// filtreleme ve sade evrak yükleme/yönetim paneli).
class EmployeeDossierPanel extends ConsumerStatefulWidget {
  final Employee employee;

  const EmployeeDossierPanel({
    super.key,
    required this.employee,
  });

  @override
  ConsumerState<EmployeeDossierPanel> createState() =>
      _EmployeeDossierPanelState();
}

class _EmployeeDossierPanelState extends ConsumerState<EmployeeDossierPanel> {
  _DossierFilter _filter = _DossierFilter.all;

  Future<void> _openAddDialog(
    BuildContext context, {
    PersonnelDocumentCategory? initialCategory,
  }) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddDossierDocumentDialog(
        employee: widget.employee,
        initialCategory:
            initialCategory ?? PersonnelDocumentCategory.kimlikFotokopisi,
      ),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dijital evrak özlük dosyasına kaydedildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteDoc(
    BuildContext context,
    PdksDashboardNotifier notifier,
    PersonnelDocument doc,
  ) async {
    try {
      await notifier.deletePersonnelDocument(doc.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${doc.title}" özlük dosyasından kaldırıldı.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evrak silinemedi: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final state = ref.watch(pdksDashboardProvider);
    final notifier = ref.read(pdksDashboardProvider.notifier);

    final empDocs = state.documentsForEmployee(widget.employee.id);
    final uploadedCategorySet = empDocs.map((d) => d.category).toSet();
    final mandatoryCategories = PersonnelDocumentCategory.values
        .where((c) => c.isMandatory)
        .toList(growable: false);
    final missingMandatory = mandatoryCategories
        .where((c) => !uploadedCategorySet.contains(c))
        .toList(growable: false);
    final completedMandatoryCount =
        mandatoryCategories.length - missingMandatory.length;
    final double progress = mandatoryCategories.isEmpty
        ? 1.0
        : (completedMandatoryCount / mandatoryCategories.length).clamp(0.0, 1.0);
    final bool allMandatoryDone = missingMandatory.isEmpty;
    final Color statusAccent =
        allMandatoryDone ? const Color(0xFF059669) : const Color(0xFFD97706);

    final defaultMissingCategory = missingMandatory.isNotEmpty
        ? missingMandatory.first
        : PersonnelDocumentCategory.digerEvrak;

    final bool showMissingSection =
        _filter == _DossierFilter.all || _filter == _DossierFilter.missing;
    final bool showUploadedSection =
        _filter == _DossierFilter.all || _filter == _DossierFilter.uploaded;

    return ListView(
      padding: const EdgeInsets.only(bottom: 6),
      children: [
        // 1. Özet Durum Çubuğu + Evrak Ekle Butonu
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: pal.subtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: statusAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          allMandatoryDone
                              ? Icons.verified_rounded
                              : Icons.folder_shared_outlined,
                          color: statusAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completedMandatoryCount / ${mandatoryCategories.length} Zorunlu Evrak Tamam',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: pal.textPrimary,
                              ),
                            ),
                            Text(
                              allMandatoryDone
                                  ? 'Tüm zorunlu özlük evrakları yüklendi • Toplam ${empDocs.length} dijital kopya'
                                  : '${missingMandatory.length} zorunlu evrak eksik • Toplam ${empDocs.length} dijital kopya',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: pal.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    key: const ValueKey('dossier_add_document_button'),
                    onPressed: () => _openAddDialog(
                      context,
                      initialCategory: defaultMissingCategory,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Evrak Ekle'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: pal.border.withValues(alpha: 0.6),
                  color: statusAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Yalın Filtre Şeridi
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              key: const ValueKey('dossier_filter_all'),
              label: Text(
                'Tümü (${missingMandatory.length + empDocs.length})',
              ),
              selected: _filter == _DossierFilter.all,
              onSelected: (_) => setState(() => _filter = _DossierFilter.all),
            ),
            ChoiceChip(
              key: const ValueKey('dossier_filter_missing'),
              label: Text('Eksikler (${missingMandatory.length})'),
              selected: _filter == _DossierFilter.missing,
              onSelected: (_) =>
                  setState(() => _filter = _DossierFilter.missing),
            ),
            ChoiceChip(
              key: const ValueKey('dossier_filter_uploaded'),
              label: Text('Yüklü (${empDocs.length})'),
              selected: _filter == _DossierFilter.uploaded,
              onSelected: (_) =>
                  setState(() => _filter = _DossierFilter.uploaded),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. Evrak & Eksik Kontrol Listesi
        if (showMissingSection) ...[
                if (missingMandatory.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Eksik Zorunlu Evraklar (${missingMandatory.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: pal.textSecondary,
                      ),
                    ),
                  ),
                  for (final cat in missingMandatory)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: pal.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFD97706).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: pal.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Zorunlu evrak bekleniyor',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: pal.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            key: ValueKey('dossier_quick_upload_${cat.name}'),
                            onPressed: () => _openAddDialog(
                              context,
                              initialCategory: cat,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.upload_file_rounded,
                              size: 15,
                            ),
                            label: const Text(
                              'Yükle',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (showUploadedSection && empDocs.isNotEmpty)
                    const SizedBox(height: 8),
                ] else if (_filter == _DossierFilter.missing) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bu personelin tüm zorunlu özlük evrakları eksiksiz tamamlanmış.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (showUploadedSection) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Kayıtlı Dijital Evraklar (${empDocs.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pal.textSecondary,
                    ),
                  ),
                ),
                if (empDocs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: pal.subtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: pal.border),
                    ),
                    child: Text(
                      'Henüz dijital evrak yüklenmemiş. "Evrak Ekle" veya yukarıdaki "Yükle" düğmeleriyle hemen ekleyebilirsiniz.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: pal.textSecondary,
                      ),
                    ),
                  )
                else
                  for (final doc in empDocs)
                    _UploadedDossierDocCard(
                      doc: doc,
                      onOpen: (Platform.isWindows &&
                              doc.filePath.isNotEmpty &&
                              File(doc.filePath).existsSync())
                          ? () async {
                              try {
                                await EmployeeProfileAvatar
                                    .openDigitalDocument(doc.filePath);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Evrak açılamadı: $e'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      onDelete: () => _deleteDoc(context, notifier, doc),
                    ),
              ],
      ],
    );
  }
}

class _UploadedDossierDocCard extends StatelessWidget {
  final PersonnelDocument doc;
  final VoidCallback? onOpen;
  final VoidCallback onDelete;

  const _UploadedDossierDocCard({
    required this.doc,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final isPdf = doc.filePath.toLowerCase().endsWith('.pdf');
    final fileName = doc.filePath.trim().isEmpty
        ? 'Dijital Arşiv'
        : doc.filePath.split(RegExp(r'[/\\]')).last;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.insert_drive_file_rounded,
              color: const Color(0xFF0284C7),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${doc.category.label} • ${doc.uploadDate} • $fileName'
                  '${doc.notes.isNotEmpty ? " • ${doc.notes}" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: pal.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (onOpen != null)
            IconButton(
              tooltip: 'Evrakı Aç',
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
            ),
          IconButton(
            key: ValueKey('dossier_delete_${doc.id}'),
            tooltip: 'Evrakı Sil',
            color: const Color(0xFFDC2626),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _AddDossierDocumentDialog extends ConsumerStatefulWidget {
  final Employee employee;
  final PersonnelDocumentCategory initialCategory;

  const _AddDossierDocumentDialog({
    required this.employee,
    required this.initialCategory,
  });

  @override
  ConsumerState<_AddDossierDocumentDialog> createState() =>
      _AddDossierDocumentDialogState();
}

class _AddDossierDocumentDialogState
    extends ConsumerState<_AddDossierDocumentDialog> {
  late PersonnelDocumentCategory _selectedCategory;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _pathCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _titleCtrl = TextEditingController(text: widget.initialCategory.label);
    _pathCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _pathCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picked = await EmployeeProfileAvatar.pickDocumentFromDesktop();
      if (picked != null && mounted) {
        setState(() => _pathCtrl.text = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya seçilemedi: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final state = ref.read(pdksDashboardProvider);
      final notifier = ref.read(pdksDashboardProvider.notifier);
      final path = _pathCtrl.text.trim().isEmpty
          ? 'Dijital_Arsiv/${widget.employee.cardNo}_${_selectedCategory.name}.pdf'
          : _pathCtrl.text.trim();

      final doc = PersonnelDocument(
        id: 'doc_${widget.employee.id}_${DateTime.now().millisecondsSinceEpoch}',
        employeeId: widget.employee.id,
        category: _selectedCategory,
        title: title,
        filePath: path,
        uploadDate: state.selectedDate,
        notes: _notesCtrl.text.trim(),
      );

      await notifier.savePersonnelDocument(doc);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evrak kaydedilemedi: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return AlertDialog(
      title: Text(
        'Özlük Evrakı Ekle (${widget.employee.fullName})',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 64).clamp(260.0, 460.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<PersonnelDocumentCategory>(
                key: const ValueKey('dossier_doc_category_dropdown'),
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Evrak Kategorisi',
                ),
                items: [
                  for (final cat in PersonnelDocumentCategory.values)
                    DropdownMenuItem(
                      value: cat,
                      child: Text(
                        '${cat.label}${cat.isMandatory ? " (Zorunlu)" : ""}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  final prevLabel = _selectedCategory.label;
                  setState(() {
                    _selectedCategory = val;
                    final current = _titleCtrl.text.trim();
                    if (current.isEmpty || current == prevLabel) {
                      _titleCtrl.text = val.label;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('dossier_doc_title_field'),
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Evrak Başlığı / Adı',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('dossier_doc_path_field'),
                      controller: _pathCtrl,
                      decoration: InputDecoration(
                        labelText: 'Dijital Kopya Yolu (Opsiyonel)',
                        hintText:
                            'Boş bırakılırsa Dijital_Arsiv/${widget.employee.cardNo}_...pdf oluşur',
                        helperStyle: TextStyle(color: pal.textSecondary),
                      ),
                    ),
                  ),
                  if (Platform.isWindows) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _pickFile,
                        icon: const Icon(Icons.attach_file_rounded, size: 17),
                        label: const Text('Seç'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('dossier_doc_notes_field'),
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Not / Açıklama (Opsiyonel)',
                  hintText: 'Örn: Islak imzalı aslı arşivde',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          key: const ValueKey('dossier_dialog_save_button'),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.cloud_upload_outlined, size: 17),
          label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}
