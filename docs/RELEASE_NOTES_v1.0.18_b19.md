# Hasibu v1.0.18 (Build 19) — Sürüm Notları / Release Notes

- **Tarih:** 2026-11-27
- **Paket:** `com.akarworks.hasibu`
- **Sürüm:** `1.0.18+19` (MSIX: `1.0.18.0`)

### Türkçe (tr)
Hasibu v1.0.18 Yenilikleri:
• Güvenli GPS Yoklama & Erişim Kontrolü: QR kod ile yoklama girişi kaldırıldı; çalışan oturumları kendi şubesi ve kendi adına gerçek GPS (anti-spoof) doğrulamasına kilitlendi, kişisel şifre belirleyen hesaplarda varsayılan PIN arka kapısı kapatıldı.
• Gelişmiş Puantaj Motoru & 4857 Uyum: Yarım gün/saatlik izin (`0.5` gün bakiye hassasiyeti), Arefe yarım gün, hafta tatili (`HT`) ve bayram (`BM`) mesaisi, net çalışma bazlı fazla mesai, 2024–2030 dini bayramlar ile gece 7,5 saat / haftalık 45 saat proaktif uyarıları eklendi.
• Vardiya Rotasyonu & Çift Yönlü Terminal: Tarih aralıklı vardiya atama takvimi ile Tenfei D35/ZKTeco saat eşitleme (`CMD_SET_TIME`) ve kadro gönderme/ayrılan silme desteği eklendi.
• Toplu İşlemler, KVKK & Portal: Toplu CSV personel içe aktarım/atama, UTF-8 BOM & formül korumalı CSV dışa aktarım, KVKK T.C./IBAN maskeleme, iOS/Android evrak seçici ve Personel Portalı aylık puantaj özeti sunuldu.

### English (en-US)
What's New in Hasibu v1.0.18:
• Secure GPS Attendance & Access Control: Removed QR attendance check-in; scoped employee sessions to their assigned branch and self-only real GPS verification, and disabled the default PIN fallback for accounts with custom passwords.
• Enhanced Attendance Engine & Compliance: Added half-day/hourly leave (`0.5`-day balance precision), holiday eve handling, weekend (`HT`) and public holiday (`BM`) overtime, net-worked overtime validation, 2024–2030 religious holidays, and 7.5h night / 45h weekly alerts.
• Shift Rotation & Two-Way Terminal Sync: Added date-ranged shift assignments (`ShiftAssignment`) and ZKTeco/Tenfei terminal clock sync and staff push/removal commands.
• Bulk Operations, Privacy & Portal: Added bulk CSV employee import/assignment, formula-safe UTF-8 BOM CSV exports, National ID/IBAN masking, native iOS/Android document picker, and personal monthly attendance summaries in the Employee Portal.
