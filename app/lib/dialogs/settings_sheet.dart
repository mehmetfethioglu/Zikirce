import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/camera_colors.dart';
import '../models/app_version_info.dart';
import 'release_notes_dialog.dart';

/// Comprehensive Settings & About modal bottom sheet for Zamera.
class SettingsSheet extends StatelessWidget {
  final VoidCallback onOpenProbe;
  final VoidCallback onOpenCalibration;

  const SettingsSheet({
    super.key,
    required this.onOpenProbe,
    required this.onOpenCalibration,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onOpenProbe,
    required VoidCallback onOpenCalibration,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SettingsSheet(
        onOpenProbe: onOpenProbe,
        onOpenCalibration: onOpenCalibration,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch URL $url: $e');
    }
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kBorderDark),
        ),
        title: const Text(
          'Telif & Lisans Politikası',
          style: TextStyle(
            color: kIosYellow,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Zamera — Sıfır GPL Bağımsız Mimari (ADR-2)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bu uygulama App Store ve Google Play Console ticari mağaza gereksinimlerine uygun olarak yalnızca MIT, Apache-2.0, BSD ve ISC lisanslı bağımlılıklar ile inşa edilmiştir.\n\n'
                'Gömülü Rust renk bilimi çekirdeği (zamera_core), Sharma 2005 CIEDE2000 formülleri ve BabelColor D50 referans matrisi kullanılarak geliştirilmiştir. Hiçbir statik GPL/AGPL kodu içermez.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 14),
              Text(
                '© 2026 Akarworks. Tüm Hakları Saklıdır.',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat', style: TextStyle(color: kIosYellow)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: kBorderDark, width: 1.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kIosYellow, Color(0xFFFF9F0A)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Z',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: kObsidianBg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zamera Ayarları',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Yapılandırma & Bilgi',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: kBorderDark, height: 1),

          // Settings Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Group 1: Release Notes & Features
                _buildSectionHeader('BİLGİ & YENİLİKLER'),
                _buildSettingsTile(
                  icon: Icons.new_releases_outlined,
                  iconColor: kIosYellow,
                  title: 'Sürüm Notları & Yenilikler',
                  subtitle: 'v${AppVersionInfo.currentVersion} güncelleme detayları',
                  onTap: () {
                    Navigator.of(context).pop();
                    ReleaseNotesDialog.show(context, showFeatures: false);
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.auto_awesome_outlined,
                  iconColor: kZameraCyan,
                  title: 'Zamera Genel Özellikleri',
                  subtitle: 'Sanat Modu, Pro Foto, Video & Gizlilik rehberi',
                  onTap: () {
                    Navigator.of(context).pop();
                    ReleaseNotesDialog.show(context, showFeatures: true);
                  },
                ),

                const SizedBox(height: 16),
                // Group 2: Hardware & Calibration Tools
                _buildSectionHeader('DONANIM & KALİBRASYON'),
                _buildSettingsTile(
                  icon: Icons.memory_outlined,
                  iconColor: const Color(0xFF64D2FF),
                  title: 'Cihaz Yetenek Probe (Faz 0)',
                  subtitle: 'Camera2 / AVFoundation donanım ve lens dökümü',
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenProbe();
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF34C759),
                  title: 'ColorChecker Kalibrasyonu (Faz 1)',
                  subtitle: '24-Yama D50 CIE-DE2000 renk matrisi çözücü',
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenCalibration();
                  },
                ),

                const SizedBox(height: 16),
                // Group 3: Privacy & Legal
                _buildSectionHeader('GİZLİLİK & YASAL'),
                _buildSettingsTile(
                  icon: Icons.security_outlined,
                  iconColor: const Color(0xFF30D158),
                  title: 'Gizlilik Politikası (GitHub Pages)',
                  subtitle: 'KVKK, GDPR & %100 çevrimdışı yerel veri güvencesi',
                  onTap: () => _launchUrl(AppVersionInfo.privacyPolicyUrl),
                ),
                _buildSettingsTile(
                  icon: Icons.policy_outlined,
                  iconColor: const Color(0xFFBF5AF2),
                  title: 'Telif & Açık Kaynak Lisansları',
                  subtitle: 'ADR-2 sıfır-GPL mağaza uyumluluk beyanı',
                  onTap: () => _showLicenseDialog(context),
                ),
                _buildSettingsTile(
                  icon: Icons.mail_outline,
                  iconColor: const Color(0xFFFF9F0A),
                  title: 'Destek & İletişim',
                  subtitle: AppVersionInfo.supportEmail,
                  onTap: () => _launchUrl('mailto:${AppVersionInfo.supportEmail}'),
                ),

                const SizedBox(height: 24),
                // Version Footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Zamera v${AppVersionInfo.currentVersion} (Derleme ${AppVersionInfo.currentBuildNumber})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white38,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Akarworks Studio · TrueColor CIEDE2000 Engine',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: Colors.white38,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: kCardDark,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorderDark),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
