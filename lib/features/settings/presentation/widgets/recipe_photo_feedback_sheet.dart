import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/config/kilerce_contact_config.dart';
import '../../../../core/services/kilerce_notification_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet allowing users to submit real dish photos or general feedback.
class RecipePhotoFeedbackSheet extends StatefulWidget {
  final String? initialRecipeTitle;

  const RecipePhotoFeedbackSheet({
    super.key,
    this.initialRecipeTitle,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialRecipeTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecipePhotoFeedbackSheet(
        initialRecipeTitle: initialRecipeTitle,
      ),
    );
  }

  @override
  State<RecipePhotoFeedbackSheet> createState() =>
      _RecipePhotoFeedbackSheetState();
}

class _RecipePhotoFeedbackSheetState extends State<RecipePhotoFeedbackSheet> {
  final TextEditingController _recipeTitleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedPhotoPath;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final initialTitle = widget.initialRecipeTitle?.trim();
    if (initialTitle != null && initialTitle.isNotEmpty) {
      _recipeTitleController.text = initialTitle;
    }
  }

  @override
  void dispose() {
    _recipeTitleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      setState(() {
        _selectedPhotoPath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilemedi: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(
      const ClipboardData(text: KilerceContactConfig.supportEmail),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İletişim e-postası panoya kopyalandı.'),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  Future<void> _openEmailWithFallback(String subject, String body) async {
    final opened = await KilerceNotificationService.instance.openEmailClient(
      to: KilerceContactConfig.supportEmail,
      subject: subject,
      body: body,
    );
    if (!opened) {
      if (!mounted) return;
      await Share.share(
        'Alıcı: ${KilerceContactConfig.supportEmail}\n$body',
        subject: subject,
      );
    }
  }

  Future<void> _submitFeedback() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final recipeTitle = _recipeTitleController.text.trim();
      final note = _noteController.text.trim();
      final subject = recipeTitle.isNotEmpty
          ? 'Kilerce Tarif Fotoğrafı: $recipeTitle'
          : 'Kilerce Tarif Fotoğrafı & Geri Bildirim';

      final bodyLines = <String>[
        'Merhaba Kilerce Ekibi,',
        '',
        if (recipeTitle.isNotEmpty) 'Tarif Adı: $recipeTitle',
        if (note.isNotEmpty) 'Not: $note',
        if (recipeTitle.isEmpty && note.isEmpty)
          'Kilerce tarif fotoğrafımı / geri bildirimimi paylaşıyorum.',
        '',
        'Not: Seçilen görsellerin uygulamada gerçek tarif görseli olarak kullanılmasına onay veriyorum.',
      ];
      final body = bodyLines.join('\n');

      final photoPath = _selectedPhotoPath;
      if (photoPath != null && photoPath.isNotEmpty) {
        await Share.shareXFiles(
          [XFile(photoPath)],
          subject: subject,
          text: 'Alıcı: ${KilerceContactConfig.supportEmail}\n\n$body',
        );
      } else {
        await _openEmailWithFallback(subject, body);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gönderim başlatılamadı: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasPhoto = _selectedPhotoPath != null && _selectedPhotoPath!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textSecondaryColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.pastelSageTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_a_photo_rounded,
                      color: context.accentPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tarif Fotoğrafı Gönder',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textSecondaryColor,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.pastelSageTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.accentPrimary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  KilerceContactConfig.representativeImageDetailedNotice,
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _recipeTitleController,
                style: TextStyle(color: context.textPrimaryColor, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Tarif Adı',
                  hintText: 'Örn. Süzme Mercimek Çorbası',
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 2,
                style: TextStyle(color: context.textPrimaryColor, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Notunuz (İsteğe bağlı)',
                  hintText: 'Hazırlarken yaptığınız küçük dokunuşları paylaşabilirsiniz...',
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text(
                        'Galeriden Seç',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text(
                        'Kamera',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasPhoto && !kIsWeb) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_selectedPhotoPath!),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => setState(() => _selectedPhotoPath = null),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _submitFeedback,
                  icon: Icon(
                    hasPhoto ? Icons.send_rounded : Icons.mail_outline_rounded,
                    size: 18,
                  ),
                  label: Text(
                    hasPhoto
                        ? 'Tarif Fotoğrafını Gönder'
                        : 'Geri Bildirim Gönder',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.subtleSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.cardBorderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alternate_email_rounded,
                      size: 16,
                      color: context.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        KilerceContactConfig.supportEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openEmailWithFallback(
                        'Kilerce Tarif Fotoğrafı & Geri Bildirim',
                        'Merhaba Kilerce Ekibi,\n\n',
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Mail Aç',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _copyEmail,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Kopyala',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
