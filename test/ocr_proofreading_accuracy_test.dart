import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahrir/features/reader/domain/content_block.dart';
import 'package:tahrir/features/reader/engine/ocr_proofreader_engine.dart';
import 'package:tahrir/features/reader/engine/ocr_text_healer.dart';

/// OCR Gözden Geçir doğruluk ölçüm seti:
/// 1) Temiz metin hiçbir şekilde değiştirilmemeli (yanlış pozitif = 0).
/// 2) Gerçek OCR bozulmaları düzeltilmeli.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OcrProofreaderEngine.ensureInitialized();
  });

  String proofread(String text) {
    final result = OcrProofreaderEngine.proofreadBlocks([TextBlock(text: text)]);
    return (result.blocks.first as TextBlock).text;
  }

  group('Yanlış pozitif koruması — doğru Türkçe metin asla bozulmaz', () {
    const cleanSentences = [
      'Kırmızı elbiseli kadın, yapılanın ve anlatılanın doğru olduğunu söyledi.',
      'Kullanılanın değeri, harcananın çok üstündeydi.',
      'Bu kitapların çoğu, geçmiş yüzyıllarda yazılmış eserlerdir.',
      'Tarihçilerin yanılmaları, bazı sebeplere dayanmaktadır.',
      'Gelinceye kadar bekledik; sonra hep birlikte yola çıktık.',
      'Saatlerce süren müzakerelerden sonra antlaşma imzalandı.',
      'Hükümdarların ve idare ettikleri devletlerin durumunu öğretir.',
      'Öğrenciler, öğretmenlerinin anlattıklarını dikkatle dinlediler.',
      'Kalbi kırık olanların hâlini ancak yaşayanlar anlayabilir.',
      'Türkmen boylarının göç yolları üzerinde yeni araştırmalar yapılmaktadır.',
      'İstanbul’un fethi, Orta Çağ’ın sonu olarak kabul edilir.',
      'Gördüğümüz ve işittiğimiz her şeyi kaydetmeye çalıştık.',
      'Yeni yöntem araştırmacılara büyük bir olanak sağladı.',
      'Uzun görüşmeler sonunda buna karar verdi.',
      'Eskiden ben bilirim derdi ama yanılırdı.',
      '1950’de ve 2000’de yapılan sayımlar karşılaştırıldı.',
      'Ankara’m ve İstanbul’un tarihi dokusu korunmalıdır.',
    ];

    for (final s in cleanSentences) {
      test(s, () {
        expect(proofread(s), s);
        expect(OcrTextHealer.heal(s), s);
      });
    }
  });

  group('OCR bozulmaları sözlük doğrulamasıyla otomatik düzeltilir', () {
    const pairs = {
      'Bu kıtap çok değerli bir eserdir.': 'Bu kitap çok değerli bir eserdir.',
      'Gecmis zamanlarda yaşanan olaylar.': 'Geçmiş zamanlarda yaşanan olaylar.',
      'Bu dusunceler yeni bir anlayışın ürünüdür.': 'Bu düşünceler yeni bir anlayışın ürünüdür.',
      'Eser büyük bir dikkatle yapılmıstır.': 'Eser büyük bir dikkatle yapılmıştır.',
      'Bu konuda yeterli bılgi yoktur.': 'Bu konuda yeterli bilgi yoktur.',
      'İnsanlann çoğu bunu bilmez.': 'İnsanların çoğu bunu bilmez.',
      'Bu hal uzun süre devam etmiş olmuştnr.': 'Bu hal uzun süre devam etmiş olmuştur.',
      'Cümhuriyet ilan edildi.': 'Cumhuriyet ilan edildi.',
      'Bu kitapda önemli bilgiler yer alır.': 'Bu kitapta önemli bilgiler yer alır.',
      'Sabah erkenden oraya gitdi.': 'Sabah erkenden oraya gitti.',
      'Halk tarafmdan büyük ilgi gördü.': 'Halk tarafından büyük ilgi gördü.',
      'Yeni bir dıişünce akımı doğdu.': 'Yeni bir düşünce akımı doğdu.',
      'Eski tarihçilerm eserleri incelendi.': 'Eski tarihçilerin eserleri incelendi.',
      'Bunun yapılmasl şarttır.': 'Bunun yapılması şarttır.',
      "Osmanlı'nm yükselme dönemi parlaktır.": "Osmanlı'nın yükselme dönemi parlaktır.",
      "İslam'm ilk asırlarında ilim gelişti.": "İslam'ın ilk asırlarında ilim gelişti.",
      "Türkiye'dekı yazma eserler koruma altındadır.": "Türkiye'deki yazma eserler koruma altındadır.",
      "Cumhuriyet 1923'de ilan edildi.": "Cumhuriyet 1923'te ilan edildi.",
      'Sonuç olanak bu görüş kabul edildi.': 'Sonuç olarak bu görüş kabul edildi.',
      'Başta tarih olmak üzen pek çok alan gelişti.': 'Başta tarih olmak üzere pek çok alan gelişti.',
      'Bundan dolay yeni tedbirler alındı.': 'Bundan dolayı yeni tedbirler alındı.',
      'Buna gön hareket etmek gerekir.': 'Buna göre hareket etmek gerekir.',
      'Öteden ben vardır bu gelenek.': 'Öteden beri vardır bu gelenek.',
      'Yazar önemli bir iddia ilen sürdü.': 'Yazar önemli bir iddia ileri sürdü.',
      'Bugüne karar pek çok eser yazıldı.': 'Bugüne kadar pek çok eser yazıldı.',
    };

    pairs.forEach((dirty, clean) {
      test(dirty, () {
        expect(proofread(dirty), clean);
      });
    });
  });

  test('Cümle ortasındaki bilinmeyen özel isimler otomatik değiştirilmez', () {
    const s = 'Bu eseri İbn Haldun yazmıştır.';
    expect(proofread(s), s);
  });

  test('Uzun ve temiz bir sayfa tek kelime bile değiştirilmeden ve hızlıca gözden geçirilir', () {
    const page =
        'Bil ki, tarih, gaye ve amacı şerefli ve faydaları çok olan bir ilimdir. Tarih, gelip geçen '
        'kavimlerin hal ve ahlâklarını, peygamberlerin hal ve hareketlerini, hükümdarların ve idare '
        'ettikleri devletlerin durumunu ve takip etmiş oldukları politikayı öğretir. Din ve dünya işlerini '
        'bütünlemek isteyen kimse, tarihe başvurarak onu kendisine örnek edinir ve bu ilimden faydalanır. '
        'Tarih bu cihetlerden birçok kaynaklara, türlü bilgilere, dikkatle bakış ve incelemelere muhtaçtır. '
        'Bu gibi dikkat ve incelemeler, bu yolda hareket eden kimseyi, sürçme ve yanılmalardan kurtarır. '
        'Çünkü haberlere yalnızca nakil yoluyla güvenilip, âdetlerin esasları, siyasetin kaideleri, '
        'medeniyetin tabiatı ve insan topluluğundaki halin özellikleri hakkında bilgi sahibi olunmazsa, '
        'gaip olanı hazır olana kıyaslamak mümkün olmaz. Böyle bir durumda tarihçi, çoğu zaman sürçmekten '
        've doğru yoldan sapmaktan kurtulamaz. Nitekim birçok tarihçinin ve müfessirin hikâyelerde ve '
        'olaylarda yanıldıkları görülmüştür.';
    final sw = Stopwatch()..start();
    final result = OcrProofreaderEngine.proofreadBlocks([const TextBlock(text: page)]);
    sw.stop();
    expect((result.blocks.first as TextBlock).text, page);
    expect(result.report.autoCorrectedCount, 0);
    expect(sw.elapsedMilliseconds, lessThan(1500));
  });
}
