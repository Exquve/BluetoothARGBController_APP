# Universal ARGB LED Controller

## 🌟 Özellikler

Bu macOS uygulaması, Universal ARGB LED kontrolcünüzü Bluetooth üzerinden kontrol etmenizi sağlar ve müzik senkronizasyonu ile harika LED efektleri oluşturur.

### 🎮 Ana Özellikler

- **🔵 Bluetooth Connectivity**: ESP32, Arduino ve diğer universal ARGB kontrolcüleri ile uyumlu
- **🎨 Renk Kontrolü**: Gelişmiş renk seçici, HSV kontrolleri ve hazır renk paleti  
- **✨ LED Efektleri**: 10+ önceden tanımlanmış efekt (Gökkuşağı, Nefes Alma, Kovalama, Ateş, vb.)
- **🎵 Müzik Senkronizasyonu**: Core Audio ile gerçek zamanlı ses analizi ve ritim senkronizasyonu
- **⚡ Hızlı Kontroller**: Tek tıkla efekt değiştirme ve parlaklık ayarları

### 🔧 Desteklenen Protokoller

Uygulama, şu protokollerle uyumludur:

1. **ESP32-WS2812B-Controller** protokolü (String tabanlı komutlar)
2. **Android-BLE-LED** protokolü (Structured binary data)  
3. **WLED** protokolü (JSON tabanlı komutlar)
4. **Generic UART** protokolü (Custom string commands)

### 🎵 Müzik Senkronizasyonu

- **FFT-Based Audio Analysis**: Gerçek zamanlı frekans analizi
- **Beat Detection**: Otomatik ritim algılama ve BPM hesaplama
- **Frequency Bands**: Bass, Mid, Treble ayrı ayrı analiz
- **Real-time Visualization**: Spektrum analizörü ve dalga formu görüntüleme

## 🚀 Kurulum

### Gereksinimler

- macOS 14.0 veya üzeri
- Xcode 15.0 veya üzeri
- Bluetooth 4.0+ desteği
- Mikrofon erişimi (müzik senkronizasyonu için)

### Adım 1: Projeyi İndir ve Derle

```bash
git clone https://github.com/yourusername/UniversalARGBledController.git
cd UniversalARGBledController
open UniversalARGBledController.xcodeproj
```

Xcode'da `Product > Build` ile projeyi derleyin.

### Adım 2: İzinleri Ayarla

Uygulama çalıştıktan sonra şu izinler gerekecek:

1. **Bluetooth İzni**: LED kontrolcüsü ile bağlantı için
2. **Mikrofon İzni**: Müzik senkronizasyonu için

Sistem Tercihleri > Güvenlik ve Gizlilik bölümünden gerekli izinleri verin.

## 🔌 Donanım Kurulumu

### ESP32 Tabanlı Kontrolcüler

Eğer ESP32 kullanıyorsanız, [ESP32-WS2812B-Controller](https://github.com/PaxtonMarchiafava/ESP32-WS2812B-Controller) projesini ESP32'nize yükleyin.

**Temel Bağlantı:**
```
ESP32 Pin 19 -> WS2812B Data In
ESP32 GND -> WS2812B GND  
ESP32 5V -> WS2812B VCC
```

### Arduino Tabanlı Kontrolcüler

Arduino Nano/Uno ile Bluetooth modülü (HC-05) kullanabilirsiniz:

```
Arduino Pin 6 -> WS2812B Data In
HC-05 VCC -> Arduino 3.3V
HC-05 GND -> Arduino GND
HC-05 RX -> Arduino Pin 2
HC-05 TX -> Arduino Pin 3
```

### WLED Uyumlu Cihazlar

WLED firmware yüklü ESP8266/ESP32 cihazlarınızı da kullanabilirsiniz.

## 📱 Kullanım

### 1. Bluetooth Bağlantısı

- **Bağlantı** sekmesine gidin
- **Cihaz Ara** butonuna tıklayın
- LED kontrolcünüzü listeden seçin ve **Bağlan** deyin

### 2. Renk Kontrolü

- **Renk Kontrolü** sekmesinde:
  - Hazır renklerden seçim yapın
  - Özel renk seçici ile istediğiniz rengi ayarlayın
  - Parlaklık seviyesini ayarlayın

### 3. Efektler

- **Efektler** sekmesinde:
  - 10+ farklı LED efekti arasından seçim yapın
  - Animasyon hızını ayarlayın
  - Efekt kategorilerine göre filtreleyin

### 4. Müzik Senkronizasyonu

- **Müzik Sync** sekmesinde:
  - **Music Sync** toggle'ını aktif edin
  - Mikrofon izni verin
  - Müzik çalın ve LED'lerin ritimle dans etmesini izleyin!

## 🎨 Efekt Listesi

| Efekt | Açıklama | Özellikler |
|-------|----------|------------|
| **Sabit Renk** | Tüm LED'ler aynı renkte | Renk seçilebilir |
| **Gökkuşağı** | Renk spektrumunda döngü | Hız ayarlanabilir |
| **Nefes Alma** | Yumuşak parlaklık değişimi | Renk seçilebilir |
| **Kovalama** | LED'ler sırayla yanıp söner | 2 renk, hız ayarı |
| **Yanıp Sönme** | Hızlı strobe efekti | Renk, hız ayarı |
| **Solma** | Renkler arası yumuşak geçiş | 2 renk arası geçiş |
| **Tarayıcı** | İleri-geri tarama | Knight Rider benzeri |
| **Ateş** | Ateş benzetimi | Rastgele flicker |
| **Dalga** | Dalga hareketi | Sinüs dalgası |
| **Meteor** | Meteor geçişi | Kuyruklu yıldız efekti |

## 🔧 Protokol Detayları

### ESP32 String Commands
```
"rgb(255,0,0)"        // Kırmızı renk
"mode=1"              // Rainbow mode
"step=0.05"           // Animation speed  
"on"/"off"            // Power control
```

### BLE Binary Protocol
```
Color Command: [start_h, start_l, length_h, length_l, r, g, b, alpha, brightness]
Animation: [mode, reverse, delay, ...mode_specific_data]
```

### WLED JSON Protocol
```json
{
  "on": true,
  "seg": [{
    "col": [[255, 0, 0]],
    "fx": 1,
    "sx": 128
  }]
}
```

## 🎵 Müzik Senkronizasyonu Teknikleri

### Audio Analysis
- **FFT (Fast Fourier Transform)**: Frekans analizi için
- **RMS (Root Mean Square)**: Genel ses seviyesi
- **Band Filtering**: Bass (20-250Hz), Mid (250-4000Hz), Treble (4000-20000Hz)

### Beat Detection
- **Energy-based**: Enerji seviyesi değişimlerini takip
- **Adaptive Threshold**: Dinamik eşik değeri
- **BPM Calculation**: Gerçek zamanlı tempo hesaplama

### Visual Mapping
- **Bass → Parlaklık**: Bas seviyesi LED parlaklığını kontrol eder  
- **Frequency → Renk**: Baskın frekans renk spektrumunu belirler
- **Beat → Flash**: Her vuruşta parlaklık artışı

## 🛠️ Geliştirme

### Proje Yapısı
```
UniversalARGBledController/
├── Managers/
│   ├── BluetoothManager.swift    // Bluetooth connectivity
│   ├── LEDController.swift       // LED effects & control
│   └── AudioManager.swift        // Music sync & analysis
├── Views/
│   ├── ContentView.swift         // Main navigation
│   ├── ColorPickerView.swift     // Color selection
│   ├── EffectsView.swift         // LED effects
│   ├── MusicSyncView.swift       // Music sync UI
│   └── ControlPanelView.swift    // Quick controls
└── Resources/
```

### Yeni Efekt Ekleme

1. `LEDController.swift` içinde `LEDEffect` enum'una ekleyin
2. `sendCommand` methodunda yeni efekt için komut ekleyin
3. UI'da gerekli kontrolleri ekleyin

### Yeni Protokol Desteği

1. `BluetoothManager.swift` içinde yeni characteristic UUID'lerini ekleyin
2. İlgili send methodlarını implement edin
3. Protokol dokümantasyonunu güncelleyin

## 🐛 Sorun Giderme

### Bağlantı Sorunları
- LED kontrolcünüzün Bluetooth'unun açık olduğundan emin olun
- Cihazın isminde "LED", "RGB", "ARGB", "WS2812" gibi kelimeler bulunduğundan emin olun
- ESP32'de Bluetooth Serial başlatıldığından emin olun

### Müzik Sync Çalışmıyor  
- Sistem Tercihleri > Güvenlik ve Gizlilik > Mikrofon'dan izin verin
- Ses seviyenizin yeterli olduğundan emin olun
- Diğer uygulamaları kapatıp tekrar deneyin

### LED'ler Yanmıyor
- Power supply'nin yeterli olduğundan emin olun (5V, minimum 2A)
- Data pin bağlantısını kontrol edin  
- LED strip'in WS2812B/NeoPixel uyumlu olduğundan emin olun

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için `LICENSE` dosyasına bakın.

## 🤝 Katkıda Bulunma

1. Repository'yi fork edin
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add amazing feature'`)
4. Branch'inizi push edin (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## 📞 İletişim

Sorularınız için:
- GitHub Issues: [Yeni issue oluştur](https://github.com/yourusername/UniversalARGBledController/issues)
- Email: your.email@example.com

## 🙏 Teşekkürler

Bu proje şu açık kaynak projelerdeki analiz ve araştırmalardan faydalanmıştır:
- [WLED](https://github.com/Aircoookie/WLED) - LED control protocols
- [ESP32-WS2812B-Controller](https://github.com/PaxtonMarchiafava/ESP32-WS2812B-Controller) - ESP32 implementation
- [Android-BLE-LED](https://github.com/ardnew/Android-BLE-LED) - BLE protocol reference

---

**⚡ Enjoy your synchronized LED experience! ⚡**