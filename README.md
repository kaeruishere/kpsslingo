# 🐸 Kaeru KPSS (Kpsslingo)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Store%20%7C%20DB-orange.svg?logo=firebase)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Kaeru KPSS**, KPSS (Kamu Personel Seçme Sınavı) hazırlık sürecini sıkıcılıktan kurtarıp eğlenceli ve rekabetçi bir deneyime dönüştüren modern, oyunlaştırılmış bir mobil öğrenme platformudur.

<p align="center">
  <img src="assets/logo.png" width="200" alt="Kaeru KPSS Logo">
</p>

## ✨ Öne Çıkan Özellikler

### 📚 Akıllı Çalışma Modları
*   **Kapsamlı Soru Bankası**: Sınav müfredatına uygun, binlerce özgün ve güncel soru.
*   **Kategorize Edilmiş Dersler**: Genel Kültür ve Genel Yetenek konularında odaklanmış çalışma imkanı.
*   **Kaldığın Yerden Devam Et**: Çalışma verilerini anlık kaydeden ve son kaldığın sorudan devam etmeni sağlayan sistem.

### ⚔️ Düello ve Sosyal Rekabet
*   **Gerçek Zamanlı Düellolar**: Arkadaşlarınla veya rastgele rakiplerle eşleşerek bilgilerini yarıştır.
*   **Global Sıralama**: Kazandığın XP'lerle liderlik tablosunda yüksel ve başarını herkese kanıtla.
*   **Anlık Bildirimler**: Düello istekleri ve önemli hatırlatıcılar için akıllı bildirim sistemi.

### 🎮 Oyunlaştırılmış Deneyim
*   **Seviye ve XP Sistemi**: Soru çözdükçe seviye atla, yeni özelliklerin kilidini aç.
*   **Günlük Seriler (Streaks)**: Her gün çalışarak serini koru ve disiplinini ödüllendir.
*   **Özel Avatarlar**: Profilini kişiselleştirmek için birbirinden eğlenceli avatarlar seç.

### 🎨 Modern ve Dinamik Arayüz
*   **Karanlık ve Aydınlık Mod**: Göz yormayan, dinamik olarak değiştirilebilen modern temalar.
*   **Neon Tasarım**: Material 3 standartlarında, akıcı animasyonlarla desteklenmiş premium kullanıcı deneyimi.
*   **Sınav Sayaçları**: Yaklaşan sınavlar için özelleştirilmiş geri sayım araçları.

## 🛠️ Teknik Altyapı

*   **Framework**: [Flutter](https://flutter.dev) (Dart)
*   **Durum Yönetimi (State Management)**: [Riverpod](https://riverpod.dev)
*   **Backend Servisleri**:
    *   **Firebase Authentication**: Güvenli Google ve E-posta girişi.
    *   **Cloud Firestore**: Kullanıcı verileri ve çalışma istatistikleri.
    *   **Realtime Database**: Anlık düello eşleşmeleri ve canlı veri akışı.
    *   **Firebase Messaging (FCM)**: Push bildirimleri.
*   **Navigasyon**: [GoRouter](https://pub.dev/packages/go_router)
*   **Yerel Veri**: [Shared Preferences](https://pub.dev/packages/shared_preferences)
*   **Tasarım**: Custom Material 3 UI, Google Fonts, Shimmer effects.

## 🚀 Başlangıç

Projeyi yerel makinenizde çalıştırmak için şu adımları izleyin:

1.  **Depoyu Klonlayın**:
    ```bash
    git clone https://github.com/kaeruishere/kpsslingo.git
    ```

2.  **Bağımlılıkları Yükleyin**:
    ```bash
    flutter pub get
    ```

3.  **Firebase Yapılandırması**:
    *   Kendi Firebase projenizi oluşturun.
    *   `google-services.json` (Android) ve `GoogleService-Info.plist` (iOS) dosyalarını ilgili dizinlere ekleyin.
    *   `lib/firebase_options.dart` dosyasını `flutterfire configure` ile güncelleyin.

4.  **Uygulamayı Çalıştırın**:
    ```bash
    flutter run
    ```

## 📄 Lisans

Bu proje MIT Lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.

---
<p align="center">
  Kaeru tarafından sevgiyle geliştirildi 🐸
</p>
