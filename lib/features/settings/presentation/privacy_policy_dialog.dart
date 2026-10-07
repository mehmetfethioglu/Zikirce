import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PrivacyPolicyDialog {
  static void show(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final surfaceColor = context.surfaceColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryEmerald, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gizlilik Politikası & Kullanım Koşulları',
                    style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context, '1. Veri Gizliliği İlkesi'),
                    _buildSectionBody(
                      context,
                      'OrganicScore uygulaması olarak kişisel verilerinizin gizliliğine ve güvenliğine en üst düzeyde önem veriyoruz. Uygulamamız kişisel kimlik verilerinizi, adınızı veya iletişim bilgilerinizi kesinlikle toplamaz veya üçüncü taraflarla paylaşmaz.',
                    ),
                    const SizedBox(height: 14),
                    _buildSectionTitle(context, '2. Kamera İzni Kullanımı'),
                    _buildSectionBody(
                      context,
                      'Uygulamamız ambalajlar üzerindeki barkodları ve içindekiler etiketlerini anlık olarak okuyabilmek için kamera izni (android.permission.CAMERA) talep eder. Kamera görüntüleriniz tamamen cihaz üzerinde (Google ML Kit On-Device Vision AI) işlenir, hiçbir sunucuya kaydedilmez veya yüklenmez.',
                    ),
                    const SizedBox(height: 14),
                    _buildSectionTitle(context, '3. Yerel Depolama (SQLite) ve Çerezler'),
                    _buildSectionBody(
                      context,
                      'Taramış olduğunuz ürünler, aile profili tercihleriniz ve günlük kullanım haklarınız cihazınızın yerel SQLite veritabanında saklanır. Uygulamayı sildiğinizde bu veriler cihazınızdan temizlenir.',
                    ),
                    const SizedBox(height: 14),
                    _buildSectionTitle(context, '4. Üçüncü Taraf Servisler & Reklamlar'),
                    _buildSectionBody(
                      context,
                      'Uygulamamız içerisinde Google AdMob reklam ağı kullanılmaktadır. AdMob reklam gösterimi amacıyla anonim cihaz tanımlayıcılarını kullanabilir. Google Gizlilik Politikası standartlarına tam uyum sağlanmaktadır.',
                    ),
                    const SizedBox(height: 14),
                    _buildSectionTitle(context, '5. İletişim & Destek'),
                    _buildSectionBody(
                      context,
                      'Her türlü soru, bildirim veya veri talepleriniz için destek@organicscore.app adresi üzerinden ekibimizle iletişime geçebilirsiniz.',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.textPrimaryColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static Widget _buildSectionBody(BuildContext context, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        body,
        style: TextStyle(
          color: context.textSecondaryColor,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}
