import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Gizlilik Politikası',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          // Başlık
          Center(
            child: Column(
              children: [
                Text(
                  'Gizlilik Politikası',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Son güncelleme: 22 Şubat 2026',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: colors.borderStroke, thickness: 1),
          const SizedBox(height: 12),

          // Giriş
          Text(
            'Zikirce ("Uygulama"), kullanıcılarının gizliliğine büyük önem verir. Bu gizlilik politikası, uygulamanın veri toplama, kullanma ve koruma uygulamalarını açıklamaktadır.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 20),

          // Bölüm 1
          _buildSectionTitle('1. Toplanan Veriler', colors.primaryText),
          const SizedBox(height: 6),
          Text(
            'Zikirce, kişisel verilerinizi toplamaz, sunucularına göndermez ve üçüncü taraflarla paylaşmaz.\n\n'
            'Uygulama içinde saklanan veriler:\n'
            '• Zikir sayaçları ve istatistikleri\n'
            '• Hatim takip verileri\n'
            '• Kullanıcı tercihleri (tema, bildirim ayarları)\n'
            '• Profil bilgileri (isteğe bağlı kullanıcı adı)\n\n'
            'Tüm bu veriler yalnızca cihazınızda (yerel depolama) saklanır.',
            style: TextStyle(fontSize: 13.5, height: 1.6, color: colors.primaryText),
          ),
          const SizedBox(height: 20),

          // Bölüm 2
          _buildSectionTitle('2. Veri Depolama', colors.primaryText),
          const SizedBox(height: 6),
          Text(
            'Tüm veriler cihazınızın yerel SQLite veritabanında saklanır. Veriler internet üzerinden herhangi bir sunucuya gönderilmez.\n\n'
            'İsteğe bağlı olarak:\n'
            '• Yerel yedekleme: Verilerinizi cihaz depolamanıza yedekleyebilirsiniz.\n'
            '• Google Drive yedekleme: Kendi Google hesabınıza yedekleme yapabilirsiniz. Bu durumda veriler yalnızca sizin Google Drive alanınızda saklanır.',
            style: TextStyle(fontSize: 13.5, height: 1.6, color: colors.primaryText),
          ),
          const SizedBox(height: 20),

          // Bölüm 3
          _buildSectionTitle('3. İnternet Erişimi', colors.primaryText),
          const SizedBox(height: 6),
          Text(
            'Uygulama aşağıdaki amaçlarla internet erişimi kullanır:\n'
            '• Namaz vakitlerini almak (Diyanet API)\n'
            '• Kur\'an meali ve tefsir verilerini indirmek\n'
            '• Google Drive yedekleme (isteğe bağlı)\n\n'
            'Hiçbir kişisel veri internet üzerinden gönderilmez.',
            style: TextStyle(fontSize: 13.5, height: 1.6, color: colors.primaryText),
          ),
          const SizedBox(height: 20),

          // Bölüm 4
          _buildSectionTitle('4. Üçüncü Taraf Hizmetleri', colors.primaryText),
          const SizedBox(height: 6),
          Text(
            'Zikirce reklam içermez ve hiçbir analitik veya izleme SDK\'sı kullanmaz.\n\n'
            'Uygulama tamamen ücretsizdir ve herhangi bir ticari amaç gütmemektedir.',
            style: TextStyle(fontSize: 13.5, height: 1.6, color: colors.primaryText),
          ),
          const SizedBox(height: 20),

          // Bölüm 5
          _buildSectionTitle('5. İzinler', colors.primaryText),
          const SizedBox(height: 6),
          Text(
            'Uygulama aşağıdaki izinleri kullanır:\n'
            '• Titreşim: Zikir sayarken dokunsal geri bildirim\n'
            '• İnternet: Namaz vakitleri ve Kur\'an verileri\n'
            '• Bildirim: Namaz vakti ve zikir hatırlatıcıları\n'
            '• Depolama: Yerel yedekleme (isteğe bağlı)\n\n'
            'Tüm izinler yalnızca uygulamanın temel işlevselliği için gereklidir.',
            style: TextStyle(fontSize: 13.5, height: 1.6, color: colors.primaryText),
          ),
          const SizedBox(height: 20),

          // Bölüm 6
          _buildSectionTitle('6. Çocukların Gizliliği', colors.primaryText),
          const SizedBox(height: 6),
          Text(
            'Zikirce hiçbir kullanıcıdan kişisel veri toplamadığı için çocuklar dahil her yaş grubunun güvenle kullanabileceği bir uygulamadır.',
            style: TextStyle(fontSize: 13.5, height: 1.6, color: colors.primaryText),
          ),
          const SizedBox(height: 20),

          // Bölüm 7
          _buildSectionTitle('7. İletişim', colors.primaryText),
          const SizedBox(height: 6),
          Text(
            'Bu gizlilik politikası hakkında sorularınız varsa bizimle iletişime geçebilirsiniz:\n\n'
            'E-posta: theakar@windowslive.com',
            style: TextStyle(fontSize: 13.5, height: 1.6, color: colors.primaryText),
          ),
          const SizedBox(height: 28),

          // Alt Bilgi Notu Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackgroundAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderStroke),
            ),
            child: Text(
              'Bu gizlilik politikası zaman zaman güncellenebilir. Değişiklikler uygulama içinden duyurulacaktır. Uygulamayı kullanmaya devam ederek güncel politikayı kabul etmiş sayılırsınız.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: colors.secondaryTextAlt,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}
