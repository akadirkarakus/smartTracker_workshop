# Takograpp — Kapsamlı Eksiklik Taraması ve Sprint Backlog

**Tarama tarihi:** 2026-07-13
**Kapsam:** `lib/` altındaki tüm katmanlar (K-Line/Bluetooth, Ekranlar/UI, Modeller), proje altyapısı (test, CI/CD, platform config, bağımlılıklar), kök dizin dokümanları (`CalibrationMessages.md`, `PossibleProblems.md`, `DURUM_NOTU.txt`).
**Yöntem:** Üç bağımsız derin kod taraması (K-Line/Bluetooth katmanı, Ekranlar/UI/Model katmanı, proje geneli) + en kritik ~5 bulgunun doğrudan koddan ve `flutter test` çalıştırılarak teyidi.

Bu doküman gelecek sprint'lerin planlanması için birincil kaynaktır. Her madde dosya/satır referansı, sorunun ne olduğu, neden önemli olduğu ve önerilen yön içerir.

---

## Nasıl okunmalı

| Seviye | Anlamı |
|---|---|
| 🔴 **Kritik** | Ya kullanıcıyı doğrudan yanıltıyor/veri bütünlüğünü tehdit ediyor, ya da geliştirme sürecinin temel bir parçası (versiyon kontrolü, test) tamamen eksik. Sprint planlamasında en yüksek öncelik. |
| 🟠 **Yüksek** | Gerçek kullanıcı etkisi var (yarım kalmış özellik, güvenlik/gizlilik riski, yayına hazır olmama) ama sistemi anlık olarak çökertmiyor/yanıltmıyor. |
| 🟡 **Orta** | Kod kalitesi, sağlamlık, veya küçük ama gerçek kullanıcı etkisi olan eksiklikler. |
| ⚪ **Düşük** | Bakım/temizlik/gelecek riskleri; şu an kullanıcıyı etkilemiyor. |

Format: **[ID] Başlık** — `dosya:satır` — Sorun / Etki / Öneri.

---

## Yönetici Özeti

| ID | Seviye | Alan | Özet |
|---|---|---|---|
| K1 | 🔴 | Bluetooth | "Bağlantıyı Kes" fiilen BLE/Classic bağlantısını kapatmıyor |
| K2 | 🔴 | K-Line/UI | W-Sabiti otomatik ölçüm akışı baştan sona ölü kod |
| K3 | 🔴 | K-Line | Saat Testi gerçek drift ölçmüyor, sonuç hep boş |
| K4 | 🔴 | K-Line/UI | Tanı testleri cihaz yanıtından bağımsız her zaman "Geçti" |
| K5 | 🔴 | K-Line | Bozuk frame baytı transaction'ı kalıcı senkron dışı bırakabiliyor |
| K6 | 🔴 | Bluetooth | iOS'ta Classic Bluetooth seçeneği koddan engellenmiyor |
| K7 | 🔴 | Altyapı | Git deposu yok — versiyon kontrolü / rollback / CI imkânsız |
| K8 | 🔴 | Test | `flutter test` şu an kırık (tek testin kendisi) |
| K9 | 🔴 | Test | Protokolün en kritik dosyası (`kline_codec.dart`) dahil sıfır unit test |
| K10 | 🔴 | Simülatör | AB 561/2006 modeli eksik/hatalı (mola sıfırlama bug'ı + limitler yok) |
| H1 | 🟠 | UI | PDF Dışa Aktar / Yazdır butonları no-op |
| H2 | 🟠 | UI | PIN kimlik doğrulaması yazmaları fiilen kilitlemiyor |
| H3 | 🟠 | Güvenlik | Workshop PIN düz metin loglanıp panoya kopyalanabiliyor |
| H4 | 🟠 | UI | Şoför ekranının (MonitorScreen) hiç gerçek cihaz veri yolu yok |
| H5 | 🟠 | UI | Raporlar sahte "BAŞARILI" rozeti + uydurma teknisyen notu gösteriyor |
| H6 | 🟠 | Yayın | Release imzalama debug key ile; `applicationId` hâlâ `com.example.*` |
| H7 | 🟠 | Yayın | Uygulama ikonu (Android) ve açılış ekranı (iOS) placeholder |
| H8 | 🟠 | Altyapı | CI/CD hiç yok |
| H9 | 🟠 | Altyapı | Crash reporting / telemetri entegrasyonu yok |
| H10 | 🟠 | Bağımlılık | `flutter_blue_plus` 1.x (güncel 2.x), `flutter_classic_bluetooth` 1.0 altı, `permission_handler` 11.x |
| H11 | 🟠 | K-Line/UI | Bağlı ön-uyarı/indirme-periyodu üçlü alanlarında sessiz sıfırla üzerine yazma riski |
| H12 | 🟠 | UI/K-Line | Opsiyonel Ayarlar'ın 13 alanında validasyon yok (sessiz clamp + ham hata metni) |
| H13 | 🟠 | Bluetooth | Transport varsayılanı derleme-zamanlı, iOS'ta da "classic" varsayılan |
| H14 | 🟠 | K-Line | Flow 1 (Security Access) dokümantasyondan sapıyor — 2 oturum + 3x RequestSeed |
| H15 | 🟠 | K-Line | NRC 0x78 bekleme sabiti (10s) tanımlı ama kullanılmıyor, gerçek pencere 5s |
| O1 | 🟡 | UI | `_writeCalParam`/`_clearDtcs`'te dispose-sonrası `setState` riski |
| O2 | 🟡 | UI | "Son Raporlar" geçmişi yapısal olarak hiç dolamaz |
| O3 | 🟡 | UI | "Koyu Tema" ve "Dil" ayarları hiçbir etki yaratmıyor |
| O4 | 🟡 | K-Line | K/W-Sabiti yazma sırası dokümantasyon ve risk notuyla çelişiyor |
| O5 | 🟡 | K-Line | ~35 dokümante opsiyonel parametreden sadece 13'ü bağlı, geri kalanı için yazma yolu yok |
| O6 | 🟡 | K-Line/UI | SecurityAccess NRC'si UI'a hiç iletilmiyor (yanlış PIN / kilit / bekleme ayırt edilemiyor) |
| O7 | 🟡 | UI | Sistem geri tuşu Servis akışında hiçbir geri bildirim vermeden yutuluyor |
| O8 | 🟡 | Bluetooth | Hiçbir transport'ta yeniden bağlanma/retry stratejisi yok |
| O9 | 🟡 | UI | 2 tanı testi (Saat, Hız&Km) her zaman anında "Başarısız" gösteriyor (stub) |
| O10 | 🟡 | K-Line | Bazı K-Line record sabitleri tanımlı ama hiç okunmuyor/decode edilmiyor |
| O11 | 🟡 | K-Line | Motion sensor eşleştirme routine ID'si (0x0155) doğrulanmamış varsayım |
| O12 | 🟡 | Bluetooth | Classic transport `readCharacteristic()` süresiz bekleyebilir (timeout yok) |
| O13 | 🟡 | UI | Rol seçimi / uygulama konfigürasyonu tamamen bellekte, hiç kalıcı değil |
| O14 | 🟡 | UI | Validasyon exception'ı `try` bloğunun dışında çağrılıyor (kırılgan) |
| O15 | 🟡 | UI | Sayısal klavyede tam sayı alanları için ondalık nokta tuşu var |
| D1 | ⚪ | UI | Erişilebilirlik/l10n altyapısı sıfır + işlevsiz dil seçici |
| D2 | ⚪ | UI | Bölüm başlığı/kart widget'ları 4+ dosyada tekrar tekrar yazılmış |
| D3 | ⚪ | UI | Uzun `build()` metodları + görünmeyen tab'larda arka planda çalışan timer'lar |
| D4 | ⚪ | UI | `const` constructor eksiklikleri (perf/lint) |
| D5 | ⚪ | K-Line | Frame parser'da magic number'lar, sınırsız buffer büyümesi, log spam riski |
| D6 | ⚪ | K-Line | DTC kod kataloğu doğrulanmamış/uydurulmuş görünüyor |
| D7 | ⚪ | Bluetooth | Simüle transport'un mock RDBI tablosu eksik, gerçek cihazı tam yansıtmıyor |
| D8 | ⚪ | Platform | iOS konum izni açıklaması eksik; eski Gradle bayrakları |
| D9 | ⚪ | Dokümantasyon | Kök dizin dokümanları tutarsız (`CalibrationMessages.md` izinleri, boş README) |

---

## 🔴 Kritik / Engelleyici

### K1 — "Bağlantıyı Kes" fiilen bağlantıyı kapatmıyor
`lib/screens/calibration_screen.dart:391-393` ve `dispose()` (`:74-79`) yalnızca `_btRepo?.dispose()` çağırıyor.
`ble_connection_service.dart:230-241` (`dispose()`) hiçbir zaman `_device?.disconnect()` çağırmıyor — bu sadece `disconnect()` metodunda (satır 85) var.
`classic_connection_service.dart:171-179` (`dispose()`) da aynı şekilde `disconnect()`'teki gerçek RFCOMM kapatma mantığını (satır 82-84) atlıyor.
**Etki:** Her "Bağlantıyı Kes" tıklamasında fiziksel GATT/RFCOMM bağlantısı OS/adaptör seviyesinde açık kalıyor. Aynı cihaza kısa süre sonra tekrar bağlanmaya çalışıldığında adaptör "zaten bağlı" diyebilir veya timeout verebilir; ayrıca tachografın K-Line oturumu tanımsız durumda kalabilir.
**Öneri:** `_disconnectDevice()`'ın `dispose()` yerine (veya öncesinde) `disconnect()` çağırmasını sağla; her iki servis sınıfının `dispose()` metodunu da gerçek disconnect mantığını içerecek şekilde düzelt.

### K2 — W-Sabiti otomatik ölçüm akışı baştan sona ölü kod
`lib/screens/calibration/w_constant_measurement_screen.dart:8,21-28` — `onMeasure` parametresi opsiyonel; `null` ise `_startMeasurement()` her zaman "Cihaz bağlı değil." hatası veriyor.
İki çağrı noktası da bu parametreyi hiç geçmiyor: `dashboard_tab.dart:85-92` ve `calibration_params_tab.dart:177-186`.
Ayrıca "Kabul Et & Yaz" butonu da (`_acceptAndWrite`, satır 68-77 → `onWConstantWritten` → `calibration_screen.dart:82-87` `_updateParam`) sadece yerel `_params` listesini güncelliyor, **K-Line'a hiçbir şey yazmıyor**.
**Etki:** Dashboard ve Kalibrasyon sekmesindeki "W-Sabiti Ölç" aksiyonu, cihaz bağlantı durumundan bağımsız olarak her zaman yanıltıcı "bağlı değil" hatası veriyor; teorik olarak çalışsa bile ölçülen değer asla cihaza yazılmıyor.
**Öneri:** `KLineService`'te gerçek bir W-sabiti otomatik ölçüm metodu (varsa Flow'a uygun) yazıp her iki çağrı noktasına `onMeasure` olarak bağla; `_acceptAndWrite`'ın gerçekten `writeParameter('w_constant', ...)` çağırmasını sağla.

### K3 — Saat Testi (Clock Test) gerçek drift ölçmüyor
`lib/kline/kline_service.dart:527-556` (`runClockTest()`). Dokümantasyon (Flow 10), cihazın 12 gerçek 1 Hz RTC darbesini donanım sayaçla zaman damgalayıp s/gün cinsinden sapma hesaplamasını gerektiriyor. Kod ise sadece `pulses < 12` döngüsünde sayaç artırıp `TesterPresent` gönderiyor — gerçek darbe yakalama ve sapma hesabı hiçbir yerde yok. `ClockTestProgress.driftSecondsPerDay` hep `null`.
**Etki:** Saat Testi ekranı "12/12 darbe yakalandı, tamamlandı" gösterecek ama kalibrasyon raporunun içermesi gereken sapma sonucu (±2 s/gün kabul kriteri) hiçbir zaman üretilmiyor.
**Öneri:** Gerçek darbe yakalama/sapma hesabı native/donanım tarafında mı olacak netleştir; değilse bu flow'u tamamla ya da UI'da "desteklenmiyor" olarak işaretle.

**Durum (Sprint 5, netleştirildi — kapatıldı, kod değişikliği yapılmadı):** `CalibrationMessages.md` Flow 10 (satır 401-423) incelendiğinde, 1 Hz RTC darbelerinin K-Line veri hattında DEĞİL, ayrı bir "kalibrasyon I/O hattında" aktığı ve "cihazın kendi 120 MHz donanım sayacıyla" yakalanması gerektiği görülüyor. K-Line üzerinden akan tek şey darbe yakalama penceresi boyunca gönderilen `TesterPresent` keep-alive'lardır — hiçbir yanıt darbe zamanlaması veya hesaplanmış sapma değeri taşımıyor. Bu nedenle gerçek sapma ölçümü, bu uygulamanın mevcut Flutter/Dart + K-Line mimarisiyle **yazılım-only çözülemez**; RTC darbelerini donanım düzeyinde zaman damgalayabilen ayrı bir adaptör/native entegrasyon gerektirir. `extended_hardware_test_screen.dart` zaten bunu dürüstçe "bu sürümde sapma hesaplaması uygulanmadı, sadece iletişim doğrulanır" diyerek belirtiyor — yanıltıcı bir sonuç göstermiyor, bu nedenle ek bir UI değişikliği gerekmedi. Bu madde, ayrı bir donanım entegrasyonu kararı verilmedikçe kapsam dışı kalacak.

### K4 — Tanı testleri (TEST1/TEST2) cihaz yanıtından bağımsız her zaman "Geçti" gösteriyor
`lib/screens/calibration/tabs/diagnostics_tab.dart:122-158` (`_startTest`) — `startRoutineTest`/`stopRoutineTest` çağrılarından sonra, bunlar hata fırlatmadığı sürece koşulsuz `TestStatus.passed` set ediliyor.
`lib/kline/kline_service.dart:635-660` — `startRoutineTest`/`stopRoutineTest` düşük seviye `_transact(frame)` çağırıyor ama dönen yanıtı hiç değişkene atmıyor, dolayısıyla `resp.isNegative` hiç kontrol edilmiyor (doğrudan kodda doğrulandı: 635-660 arasında `isNegative` referansı yok; oysa `_rdbi`/`_wdbi` bunu satır 734/756'da yapıyor). `stopRoutineTest`'in `operatorResult` parametresi de (gerçek fiziksel sonucu cihaza bildirmek için) diagnostics_tab tarafından hiç kullanılmıyor.
**Etki:** Ekran testi, yazıcı testi, kart okuyucu testi, batarya testi vb. 10 test, Bluetooth round-trip tamamlandığı sürece — tachograf reddetse bile — yeşil ✓ "Geçti" gösterecek. Bu, kalibrasyon aracının öz-test paketinin güvenlik/uyumluluk amacını doğrudan zayıflatıyor; bu sahte "Geçti" sonuçları H5'teki sahte rapor rozetini de besliyor.
**Öneri:** `startRoutineTest`/`stopRoutineTest` yanıtlarını yakala, `isNegative` kontrolü ekle, gerçek NRC'ye göre `passed`/`failed` belirle; mümkünse cihazdan gerçek test sonucu payload'ını oku.

### K5 — Bozuk frame uzunluk baytı transaction'ı kalıcı senkron dışı bırakabiliyor
`lib/kline/kline_frame.dart:178-195` (`tryParse()`). İlk bayt `_fmtStandard` (0x80) ile eşleşip `LEN` baytı (satır 178'deki `_buf[3]`) gürültü/bit-flip nedeniyle bozuksa, `totalLen` yanlış hesaplanıyor ve metod asla tamamlanmayacak bir uzunluk için beklemeye giriyor — checksum kontrolüne (ve oradaki resync mantığına) hiç ulaşmıyor. `_buffer.clear()` sadece `_beginTransaction()`'da çağrılıyor, her `_transact()`/`_waitResponse()` sonrasında değil — yani `readAllCalibrationData()` gibi tek transaction içinde ~28 RDBI gönderen akışlarda tek bir bozuk bayt, o transaction'ın geri kalanındaki her isteği kendi 5s timeout'una kadar askıda bırakabiliyor.
**Etki:** Gerçek dünyada BLE/SPP parçalanma gürültüsü altında (bkz. `PossibleProblems.md` risk #3), tek bir bozuk bayt, tek bir açıklayıcı checksum hatası yerine bir dizi kafa karıştırıcı "yanıt zaman aşımı" hatasına dönüşebiliyor.
**Öneri:** LEN baytı mantıksız (çok büyük/0) olduğunda anında resync tetikleyen bir üst sınır/stall-timeout ekle; buffer'a maksimum boyut sınırı koy.

### K6 — iOS'ta Classic Bluetooth seçeneği koddan engellenmiyor
`lib/screens/ble_scan_screen.dart:295-361` (`_TransportSelector`) — "Classic Bluetooth" kartı her platformda tıklanabilir; sadece alt metni "Android için" diyor, `Platform.isIOS` kontrolü yok. `bluetooth_config.dart`'ta da platform bazlı bir zorlama yok (bkz. H13).
**Etki:** CLAUDE.md'nin kendi belirttiği kısıt (Classic SPP, ExternalAccessory + MFi sertifikası olmadan iOS'ta çalışamaz) koda yansımamış; bir iOS kullanıcısı "Classic Bluetooth"a tıklarsa `flutter_classic_bluetooth`'tan tanımsız/test edilmemiş bir hata alır.
**Öneri:** `Platform.isIOS` durumunda Classic kartını devre dışı bırak veya gizle, net bir "iOS'ta desteklenmiyor" mesajı göster.

### K7 — Git deposu yok
`git status`/`git rev-parse --is-inside-work-tree` ikisi de "not a git repository" veriyor (doğrudan doğrulandı). `.gitignore` dosyası olmasına rağmen hiç commit geçmişi yok.
**Etki:** `kline_codec.dart` gibi doğrudan fiziksel cihaza yazan bir dosyadaki kötü bir değişiklik bisect/revert edilemez; PR açılamaz, hiçbir CI tetiklenemez, hiçbir kod incelemesi/geçmişi yok.
**Öneri:** `git init` + baseline commit — bu, bu listedeki diğer her şeyden önce yapılmalı (5 dakikalık iş, ama temel).

### K8 — `flutter test` şu an kırık
Doğrudan çalıştırılarak doğrulandı:
```
Expected: exactly one matching candidate
Actual: _TextWidgetFinder:<Found 0 widgets with text "Takograf İzleme": []>
```
`test/widget_test.dart:9`, `TachographApp()`'ı pompalayıp doğrudan `'Takograf İzleme'` metnini arıyor, ama uygulamanın gerçek ana ekranı (`lib/main.dart:34` → `RoleSelectionScreen`) "Rol Seçin" gösteriyor ve `MonitorScreen`'e ulaşmak için "Şoför" butonuna basmak gerekiyor. Test, rol seçimi akışı eklendikten sonra hiç güncellenmemiş.
**Etki:** Depodaki tek test şu anda kırmızı — fiilen %0 geçen test kapsamı. `flutter test`'e dayalı herhangi bir CI kapısı her zaman başarısız olur.
**Öneri:** Testi güncel navigasyon akışına göre düzelt (önce Rol Seçim ekranını, sonra "Şoför" tıklanınca Monitor'ü doğrula).

### K9 — Protokolün en kritik dosyası dahil sıfır unit test
`test/` sadece `widget_test.dart` içeriyor (ve o da kırık — bkz. K8). Hiçbir test dosyası yok:
- `lib/kline/kline_codec.dart` (426 satır) — VIN, VRN, kilometre sayacı, K/W-sabiti, lastik çevresi, tarihler, UTC offset, PIN baytları vb. encode/decode. Round-trip (encode→decode) testi yok, sınır testi yok (`_validDate`, satır 421, ay uzunluğunu hiç kontrol etmiyor — 30 gün çeken bir ayda 31. gün kabul ediliyor).
- `lib/services/tachograph_simulator.dart` — 4.5 saat sıfırlama davranışı, hız ihlali sayımı, kilometre birikimi için hiçbir test yok.
- `lib/bluetooth/services/` altındaki 5 dosya (BLE/Classic/Simulated) — mimari zaten mock'lanabilir (soyut repository arayüzleri + bunun için var olan `SimulatedConnection`) ama hiçbir şey test edilmiyor.
- `KLineService` (821 satır, Flow 1-21) — frame oluşturma, `KLineFrameBuffer` chunk birleştirme (bkz. K5), retry/NRC-0x78 (bkz. H15) için test yok.
**Öneri:** En azından `kline_codec.dart` round-trip testleri, `TachographSimulator` kural testleri, `SimulatedConnection` destekli bir `KLineService` akış testi — bu backlogda testing epic'inin ilk maddesi olmalı.

### K10 — `TachographSimulator`'ın AB 561/2006 modeli eksik/hatalı
`CLAUDE.md` "4.5 saat sürekli sürüş + 90 km/h hız limiti ihlal sayımı" iddia ediyor. `lib/services/tachograph_simulator.dart`:
- **Sıfırlama hatası** (satır 75-81): `isResting` true olduğu anda (tek 1 saniyelik tick sonrası) `contDriving` sıfırlanıyor. Gerçek AB 561/2006 (Md. 7) 4.5 saat sayacının sıfırlanması için **en az 45 dakikalık** (veya 15+30 bölünmüş) mola gerektirir. Şu anki haliyle simülatör bu kuralın ihlalini gerçekçi kullanımda hiç gösteremiyor.
- 4.5 saat kuralı için ayrı bir ihlal sayacı yok (sadece hız ihlali sayılıyor).
- Günlük sürüş limiti (9 saat, haftada 2 kez 10'a uzatılabilir) hiç modellenmemiş.
- Haftalık (56 saat) / iki haftalık (90 saat) sürüş limitleri hiç kontrol edilmiyor.
- Günlük dinlenme (11 saat/9 saat indirimli) ve haftalık dinlenme (45 saat/24 saat) kuralları hiç yok.
- Mola deseni doğrulaması (45 dk veya 15+30 dk bölünmüş) yok — sürüşten herhangi bir uzaklaşma, süresinden bağımsız olarak molayı "tamamlanmış" sayıyor.
- Çok günlü/takvim günü takibi yok — `dailyDriving`/`weeklyDriving`/`dailyRest` gün/hafta sınırlarında hiç sıfırlanmıyor.
**Öneri:** Ya CLAUDE.md'deki iddiayı doğru kapsama göre güncelle ("sadece 4.5 saat sayacı + hız ihlali, mola-süresi hatasıyla birlikte"), ya da simülatörü gerçek kural kapsamına genişlet — bu bilinçli bir ürün kararı olmalı, doküman/kod uyumsuzluğu olarak kalmamalı.

---

## 🟠 Yüksek Öncelik

### H1 — PDF Dışa Aktar / Yazdır butonları no-op
`lib/screens/calibration/tabs/reports_tab.dart:99` (`onPressed: () {}`) ve `:116` (`onPressed: () {}`). Hiçbir `pdf`/`printing` paketi `pubspec.yaml`'da yok. Butonlar tıklanabilir görünüyor, ripple efekti veriyor ama hiçbir şey yapmıyor, hiçbir hata/bilgi mesajı göstermiyor.
**Öneri:** `pdf`/`printing` paketi ekle, gerçek PDF üretimi/yazdırma implemente et; kısa vadede en azından "yakında" mesajı göster.

### H2 — PIN kimlik doğrulaması yazmaları fiilen kilitlemiyor
`_isPinAuthenticated` (`calibration_screen.dart:32`) sadece `dashboard_tab.dart:116`'da bir durum rozetini renklendirmek için okunuyor. `_writeCalParam` (`:97-194`), `CalibrationParamsTab._commitAll`/`_openEdit` (`calibration_params_tab.dart:96-186`) veya `OptionalSettingsScreen._save` (`:141-185`) içinde hiç kontrol edilmiyor.
**Etki:** PIN ekranı hiç açılmamış veya PIN yanlış girilmiş olsa bile `KLineService.writeParameter`/`writeDateTime` vb. çağrıları sorunsuz çalışıyor — PIN ekranı görsel bir tiyatro.
**Öneri:** Tüm yazma yollarının başında `if (!_isPinAuthenticated) throw/return` guard'ı ekle.

### H3 — Workshop PIN düz metin loglanıp panoya kopyalanabiliyor
`lib/core/bt_utils.dart:1-5` (`bytesToHex`) yazdırılabilir ASCII karakterleri hex dump yanında ayrıca çıkarıyor. `ble_connection_service.dart:176-179` ve `classic_connection_service.dart:120-121`, her `writeCharacteristic()` çağrısını bununla logluyor — `KLineFrame.securityAccessSendKey()` (`kline_frame.dart:51-53`) operatörün girdiği PIN'i ham ASCII bayt olarak içeriyor (protokol PIN'i seed-hash'lemeden düz gönderiyor). Bu log akışı `ble_terminal_screen.dart:57-62`'de canlı gösteriliyor ve Test Mode açıkken `AppLogger`'a köprüleniyor, oradan da `test_log_screen.dart:70` ile panoya kopyalanabiliyor.
**Etki:** Tachografa tüm yazma erişimini kilitleyen kimlik bilgisi (workshop PIN), düz metin, dışa aktarılabilir/paylaşılabilir bir logda sona erebiliyor.
**Öneri:** SendKey frame'inin loglanmadan önce PIN baytlarını maskele/redakte et.

### H4 — Şoför ekranının (MonitorScreen) hiç gerçek cihaz veri yolu yok
`lib/screens/monitor_screen.dart:22-35` — `_simulator = TachographSimulator()` ekranın tek veri kaynağı; `:50-56`'daki Bluetooth ikonu `BleScanScreen()`'e gidiyor ama `onDeviceConnected` callback'i hiç geçilmiyor, yani bağlanılan cihaz asla dashboard'un veri akışına bağlanmıyor.
**Etki:** Şoför Bluetooth ikonuna basıp gerçek bir tachografla eşleşse bile hız/RPM/sürüş süresi göstergeleri hiçbir zaman değişmiyor — hep simülasyon verisi kalıyor, ve ekranda "bu veri sahte" diye ayırt edici hiçbir gösterge yok.
**Öneri:** Ürün kararı olarak netleştir — şoför ekranının gerçek cihaza bağlanması planlanıyor mu? Öyleyse `onDeviceConnected`'ı gerçek bir K-Line veri akışına bağla; değilse en azından "SİMÜLASYON" rozetini her zaman görünür/net yap.

### H5 — Raporlar sahte "BAŞARILI" rozeti + uydurma teknisyen notu her zaman gösteriyor
`reports_tab.dart:176-186` (`_ReportSummaryCard`) `passedCount`/`tests.length`'i veya herhangi bir `TestStatus.failed`'ı hiç kontrol etmeden her zaman yeşil "BAŞARILI" gösteriyor. `:397-423` (`_OperatorNotes`) her raporda aynı sabit, düzenlenemez Türkçe paragrafı ("...sensör kablosu değiştirildi...") gösteriyor — gerçekte yapılan işten bağımsız. Not metni "AB 561/2006"ya atıfta bulunuyor; kalibrasyon sertifikaları yasal ağırlık taşıdığından bu ciddi bir veri bütünlüğü/uyumluluk sorunu.
**Öneri:** Gerçek test sonuçlarına göre koşullu rozet; operatör notlarını gerçek, düzenlenebilir bir alana çevir.

### H6 — Release imzalama debug key ile; `applicationId` hâlâ `com.example.*`
`android/app/build.gradle.kts` — `applicationId = "com.example.takograpp_d1"` (Flutter şablonu varsayılanı) ve `release { signingConfig = signingConfigs.getByName("debug") }`, ikisi de kod içi `TODO` ile işaretli.
**Etki:** Bu haliyle uygulama Play Store'a yayınlanamaz (debug-imzalı release build reddedilir), `com.example.*` altında yayınlamak da uygun değil.
**Öneri:** Gerçek bir applicationId/bundle ID seç, release keystore üret, `key.properties` ile imzalama config'i bağla.

### H7 — Uygulama ikonu (Android) ve açılış ekranı (iOS) placeholder
`android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (ve tüm yoğunluklar) hâlâ stok mavi Flutter "F" logosu — `assets/logo.png` ve "Tacho" markası varken kullanılmamış. `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png` 1×1 şeffaf placeholder.
**Öneri:** `flutter_launcher_icons` ile `assets/logo.png`'den ikon setleri üret; iOS launch image'i gerçek marka ile değiştir.

### H8 — CI/CD hiç yok
`.github/workflows`, `fastlane` veya başka bir CI config yok. K7 (git yok) ve K8 (`flutter test` kırık) ile birleşince, hiçbir regresyonu önleyen otomatik kapı yok.
**Öneri:** Git init sonrası minimal bir GitHub Actions workflow (`flutter analyze` + `flutter test`) ekle — ama önce K7/K8 çözülmeli.

### H9 — Crash reporting / telemetri entegrasyonu yok
`lib/` ve `pubspec.yaml` içinde Sentry/Crashlytics/Firebase/analytics araması sonuçsuz. Saha çalışması sırasında gerçek cihazla K-Line iletişim hataları dahil tüm runtime exception'lar görünmez oluyor — teknisyen `AppLogger`/`TestLogScreen`'e bakmadıkça (ve Test Mode açık değilse o da boş).
**Öneri:** En azından `CalibrationScreen`/`KLineService` yazma yolu hataları için hafif bir Sentry/Crashlytics entegrasyonu ekle.

### H10 — Bağımlılıklar eski
`flutter pub outdated`: `flutter_blue_plus` 1.36.8 → güncel 2.3.10 (major sürüm geride), `flutter_classic_bluetooth` 0.1.2 → 0.1.3 (hiç 1.0'a ulaşmamış, düşük bakım riski), `permission_handler` 11.4.0 → 12.0.3.
**Öneri:** Özellikle Android 14/15 hedefleme öncesi, her iki Bluetooth paketinin yükseltilmesi için bir spike planla.

### H11 — Bağlı ön-uyarı/indirme-periyodu üçlü alanlarında sessiz sıfırla üzerine yazma riski
`calibration_screen.dart:223-238` (`_writePrewarning`/`_writeDownloadPeriod`) — üç kardeş alandan (`prewarning_card1`/`prewarning_tacho`/`prewarning_cal`, veya `download_period_vu`/`download_period_card`) sadece biri değiştirildiğinde, değişmeyen kardeşler `_paramIntValue(id)` ile okunuyor: `int.tryParse(...) ?? 0`. Eğer bir kardeşin ilk K-Line okuması başarısız olduysa (`CalParam.value == null` kaldıysa), bu sessizce **0**'a düşüyor.
**Etki:** Sadece "Kart 1 Ön Uyarı Süresi"ni düzenleyen bir teknisyen, okuması başarısız olmuş "Takograf Ön Uyarı Süresi"ni fark etmeden **0'a (devre dışı) sıfırlayarak** cihaza yazabilir — gerçek, çalışan bir yapılandırmanın üzerine sessizce yazılıyor.
**Öneri:** Kardeş alan `null`/okunamamış ise yazmadan önce kullanıcıyı uyar veya yazmayı engelle.

### H12 — Opsiyonel Ayarlar'ın 13 alanında validasyon yok
`lib/screens/calibration/optional_settings_screen.dart` — "Hız Göstergesi Faktörü" gibi alanlar serbest metin `TextField` ile alınıyor, sınır kontrolü yok. `KLineCodec.encodeSpeedometerFactor`/`encodeOverspeedPrewarningSeconds` gibi encoder'lar aralık dışı girdiyi **sessizce clamp'liyor** (`.clamp(1, 60000)` vb.) — ekranda gösterilen değer (clamp öncesi, ham girilen) ile cihaza gerçekten yazılan değer (clamp sonrası) birbirini tutmuyor. Hatalar `FormatException: ...` gibi ham, teknik metinlerle kullanıcıya gösteriliyor; ana parametre listesindeki temiz `ParamValidationException` mesajlarıyla tutarsız. Ana listenin `lib/kline/parameter_validation.dart` altyapısı bu ekranda hiç kullanılmıyor.
**Not:** Bu, kod tabanında tekrar eden bir desenin parçası — `encodeIgnitionOption`, `encodeCanBaudrate`, `encodeDistanceUnit` vb. birçok encoder da tanınmayan girdide sessizce geçerli ama yanlış bir varsayılan değere düşüyor (üç ayrı taramada bağımsız olarak bulundu).
**Öneri:** `ParameterValidator` altyapısını Opsiyonel Ayarlar ekranına da uygula; encoder'ları sessiz varsayılan yerine hata fırlatacak şekilde sıkılaştır (en azından unit testle davranışı sabitle).

### H13 — Transport varsayılanı derleme-zamanlı, iOS'ta da "classic" varsayılan
`lib/bluetooth/config/bluetooth_config.dart:9-13` — `String.fromEnvironment('BT_TRANSPORT', defaultValue: 'classic')`, `Platform.isIOS` kontrolü hiç yapmıyor. `BT_TRANSPORT=simulated` geçilirse bile karşılaştırma mantığı yüzünden sessizce `BtTransport.ble`'a düşüyor (`simulated` bu yoldan hiç ulaşılamıyor).
**Etki:** `--dart-define` bayrağı unutulmuş bir iOS release build'i sessizce çalışmayan bir varsayılan transport'la sevk edilebilir.
**Öneri:** `Platform.isIOS` ise varsayılanı zorla `ble` yap; string eşleştirmeyi `simulated` değerini de kapsayacak şekilde düzelt.

### H14 — Flow 1 (Security Access) dokümantasyondan sapıyor
`kline_service.dart:181-214`. `CalibrationMessages.md` Flow 1, tek bir `Wakeup → StartComm → StartSession → RequestSeed → SendKey → StopComm` dizisi tanımlıyor. Kod bunun yerine `requestSeed()`'i kendi tam transaction'ında (satır 181), `sendKey()`'i de içinde ikinci bir `RequestSeed` daha yapan (satır 200) ayrı bir transaction'da çalıştırıyor — toplamda 3 RequestSeed, 2 ayrı wakeup/StartComm/StopComm döngüsü.
**Etki:** Gecikme artıyor; bazı ECU'lar SendKey'in aynı oturumdaki RequestSeed'i hemen takip etmesini zorunlu tutabilir — gerçek donanımda doğrulanması gereken bir sapma.

### H15 — NRC 0x78 bekleme sabiti (10s) tanımlı ama kullanılmıyor
`kline_records.dart:213` — `nrc78MaxWait = Duration(seconds: 10)` (`PossibleProblems.md` §6'daki "10s azami yeniden deneme" ile eşleşiyor) hiçbir yerde referans edilmiyor. Gerçekte `_waitResponse()` (`kline_service.dart:786-808`) tek bir deadline kullanıyor ve bu, `sendKey` için 5s (`pinResponseTimeout`), diğer her şey için yine 5s (`defaultTimeout`).
**Etki:** Tachograf PIN çözme veya yazma için 5 saniyeye yakın/fazla süre gerektirirse (doküman zaten zincirlenmiş 0x78 yanıtlarını bekliyor), uygulama meşru bir işlemi belgelenen 10s'lik azami süreden çok önce "zaman aşımı" olarak raporlayabilir.
**Öneri:** `_waitResponse`'un NRC-0x78 retry penceresini `nrc78MaxWait`'e göre hesaplamasını sağla.

---

## 🟡 Orta Öncelik

**O1 — Dispose sonrası `setState` riski.** `calibration_screen.dart:181-184` (`_writeCalParam`) ve `diagnostics_tab.dart:100-114` (`_clearDtcs`), birden fazla `await`'li K-Line round-trip'ten sonra `mounted` kontrolü olmadan `setState` çağırıyor — `_loadDeviceData`/`_loadSettings` bunu doğru yapıyor, bu ikisi yapmıyor. Teknisyen yazma devam ederken Ayarlar'dan "Çıkış Yap" yaparsa çökme riski var.

**O2 — "Son Raporlar" geçmişi yapısal olarak hiç dolamaz.** `lib/models/calibration_data.dart:178` (`defaultReports() => []`), `calibration_screen.dart:40,54`'te set edildikten sonra hiçbir yerde mutasyona uğramıyor (`RecentReport(` için grep sadece model tanımını ve bu initializer'ı buluyor). Dashboard'daki "Son Raporlar" bölümü sonsuza kadar boş kalacak.

**O3 — "Koyu Tema" ve "Dil" ayarları hiçbir etki yaratmıyor.** `service_settings_tab.dart` tam işlevli, SharedPreferences'a kalıcı bir "Koyu Tema" toggle'ı sunuyor ama `lib/main.dart:16-33`'teki `MaterialApp`'te `darkTheme`/`themeMode` yok, `darkThemeEnabled` hiçbir yerde tüketilmiyor. Aynı şekilde "Dil" seçici (İngilizce/İspanyolca/Ukraynaca) tamamen kozmetik — uygulamada hiç l10n altyapısı yok (bkz. D1).

**O4 — K/W-Sabiti yazma sırası dokümantasyon ve risk notuyla çelişiyor.** `kline_service.dart:339-342` W-Sabiti yazılırken önce K-Sabiti'ni yazıyor; `CalibrationMessages.md` Flow 3 tersini gösteriyor, ve `PossibleProblems.md` §7 açıkça "W-Constant, K-Constant'tan bağımsız yazılıyor" stratejisini belirtiyor. Kod bunu koşulsuz her zaman bağlıyor — gerçek donanımda doğrulanmamış, potansiyel olarak istenmeyen K-Sabiti üzerine yazma riski.

**O5 — ~35 dokümante opsiyonel parametreden sadece 13'ü bağlı.** `CalibrationMessages.md` §8.3/8.4, STC8250/8255 için ~35+ yazılabilir opsiyonel parametre (CAN config, kart geçerlilik tarihleri, ateşleme seçenekleri, arka ışık, N/V hız profilleri vb.) ve bir blok-yazma (`0x8250`/`0x8255`) tanımlıyor. `kline_service.dart`'ta bunlar için **hiçbir yazma yolu yok**; `readOptionalSettings()` da sadece ~13 alanı okuyor. `kline_records.dart`'ta sabitler tanımlı ama kullanılmıyor (ölü kod).

**Durum (Sprint 5):** Bayt formatı dokümanda net olan ~21 mantıksal parametrenin tamamı (Card Expiry Dates, CAN A/C On-Off, CAN C TCO1, Backlight & Battery [STC8250], Language Change, Overspeed Prewarning Output, Buzzer Overspeed Control, Overspeed TCO1, Output Shaft Speed Enable, TCO1 Handling Info, CAN A/C Sample, CAN A/C Sync Jump, IMS CAN PGN, N/V Profile Registry + Speed Profiles, N Factor, D1/D2 State Enable, Engine Speed Source, CAN Protocols, CAN Terminations, RDDW in Sleep, DAGS Buzzer Control) `kline_codec.dart` + `readOptionalSettings()` + `optional_settings_screen.dart` üzerinden uçtan uca bağlandı. **Kapsam dışı bırakılan:** `fd10BacklightSource8255` ("Backlight Source + levels", STC8255) — doküman bu alanın mod-bazlı (Disable/Menu/A2/Cabin) 1-5 bayt arası değişken uzunluğunu belirtiyor ama her modun bayt içeriğini tanımlamıyor; tahmin ederek implemente etmek yanlış veri yazma riski taşıdığından **vendor dokümantasyonu veya gerçek donanım doğrulaması gelene kadar** bağlanmadı. `0x8250`/`0x8255` blok-yazma da (§8.4) kapsam dışı kaldı — doküman alan sırasını/offsetlerini vermiyor; mevcut per-field `0xFD??` WDBI yazma yolu (bu implementasyonun izlediği yol) zaten aynı sonucu sağlıyor.

**O6 — SecurityAccess NRC'si UI'a hiç iletilmiyor.** `kline_service.dart:206-209` `SecurityAccessResult(success:false, nrc: resp.nrc)` döndürüyor; `kline_records.dart:196-199`'daki özel NRC sabitleri (`securityAccessDenied`, `invalidKey`, `exceededNumberOfAttempts`, `requiredTimeDelayNotExpired`) hiç kullanılmıyor. `dashboard_tab.dart:63-69` sadece bare `bool` iletiyor, hataları `catch (_)` ile yutuyor. Teknisyen yanlış PIN, kilitlenme (3 deneme) veya gerekli bekleme süresini birbirinden ayırt edemiyor.

**O7 — Sistem geri tuşu Servis akışında geri bildirimsiz yutuluyor.** `calibration_screen.dart:441-442` `PopScope(canPop: false, ...)` — `onPopInvokedWithPop` yok, snackbar/dialog yok. Çıkışın tek yolu üç dokunuş derinlikte gömülü ("Ayarlar → aşağı kaydır → Çıkış Yap").

**O8 — Hiçbir transport'ta yeniden bağlanma/retry stratejisi yok.** BLE/Classic/Simulated servislerinin hiçbiri beklenmedik kopma sonrası otomatik yeniden bağlanma denemiyor; ~28 RDBI'lık `readAllCalibrationData()` gibi uzun transaction'lar sırasında bağlantı düşerse, tek belirti sıradan bir 5s "yanıt zaman aşımı" — "bağlantı koptu" diye ayrı bir hata yok.

**O9 — 2 tanı testi (Saat, Hız&Km) her zaman anında "Başarısız" gösteriyor.** `diagnostics_tab.dart:34-45` (`_testRoutineMap`) 12 testten sadece 10'unu bir routine ID'sine eşliyor; eşlenmeyen ikisi için kod yorumu "clock and speed_odo require dedicated streaming flows — not handled here" diyerek `TestStatus.failed`'ı koşulsuz set ediyor. `TestStatus` enum'ında "desteklenmiyor" durumu yok, bu yüzden gerçek bir donanım arızasıyla ayırt edilemiyor.

**O10 — Bazı K-Line record sabitleri tanımlı ama hiç okunmuyor/decode edilmiyor.** `systemSupplierIdentifier`, `ecuManufacturingDate`, `swNumber`, `exhaustRegOrTypeApprovalNumber`, `calibrationDate`, `serviceComponentId`, `serviceDelayCalendarTimeBased`, `downloadPeriod992` — hiçbirinin karşılığı `KLineCodec.decode*` yok, `readAllCalibrationData()`'da okunmuyor.

**Durum (Sprint 5):** `systemSupplierIdentifier` (0xF18A), `swNumber` (0xF194) ve `exhaustRegOrTypeApprovalNumber` (0xF196) bağlandı — bunlar mevcut `hwNumber`/`swVersionNumber` gibi ASCII string kayıtlarla aynı örüntüye uyuyor (`KLineCodec.decodeAsciiTrimmed`), `readAllCalibrationData()`'ya eklendi ve Dashboard'daki "Cihaz Bilgisi" kartında gösteriliyor. **Kapsam dışı bırakılan 5 alan:** `ecuManufacturingDate` (0xF18B), `calibrationDate` (0xF19B), `serviceComponentId` (0xF914), `serviceDelayCalendarTimeBased` (0xF915), `downloadPeriod992` (0xF992) — `CalibrationMessages.md` §7 bu alanlar için Record ID + isim dışında hiçbir bayt formatı vermiyor (`0xF992` doküman satırında `(?)` ile işaretli, yazarı bile emin değil). Formatı tahmin ederek decode etmek (ör. tarih mi, BCD mi, ham sayı mı) teknisyene yanlış veri gösterme riski taşıyor; bu alanlar vendor dokümantasyonu veya gerçek donanımda bayt-bayt yakalama ile doğrulanana kadar bağlanmayacak.

**O11 — Motion sensor eşleştirme routine ID'si (0x0155) doğrulanmamış varsayım.** `kline_records.dart:160` — doküman `0x0150-0x0154, 0x0156-0x015A` aralığını listeliyor ama `0x0155`'i sayısal olarak hiç doğrulamıyor; kod bu boşluktaki değeri tahminle kullanıyor. Gerçek donanımda doğrulanmalı.

**O12 — Classic transport `readCharacteristic()` süresiz bekleyebilir.** `classic_connection_service.dart:130-141` — `.stream.first`'te timeout yok. Şu an production K-Line akışında kullanılmıyor (o `notifyStream` kullanıyor) ama `BleConnectionRepository` kontratının parçası; gelecekte bir çağıran (ör. BLE Terminal'de "Oku" butonu) süresiz asılabilir.

**O13 — Rol seçimi / uygulama konfigürasyonu tamamen bellekte, hiç kalıcı değil.** `lib/main.dart`'ta hiç `SharedPreferences` çağrısı yok; her yeniden başlatma rol seçim ekranına dönüyor. `pubspec.yaml`'daki `version: 1.0.0+1` hiçbir yerde kullanıcıya gösterilmiyor. (Buna karşın `ServiceSettings` zaten SharedPreferences ile doğru çalışıyor — altyapı var, sadece uygulanmamış.)

**O14 — Validasyon exception'ı `try` bloğunun dışında çağrılıyor.** `calibration_screen.dart:100` — `ParameterValidator.validate(param, value)`, `_writeCalParam`'ın kendi `try {` bloğu (satır 101) başlamadan önce çalışıyor; fırlatılan `ParamValidationException` bu fonksiyonun kendi `catch`'ine (satır 186) hiç uğramadan yayılıyor. Bugün her iki çağıran da bunu doğru yakalıyor ama gelecekteki bir çağıran (ör. toplu içe aktarma) bunu unutursa çökme riski var.

**O15 — Sayısal klavyede tam sayı alanları için ondalık nokta tuşu var.** `edit_parameter_screen.dart:819-841` (`_NumericKeypad`) her `ParamType.number` alanı için `.` tuşu gösteriyor, ama `parameter_validation.dart:35` tam sayı regex'i (`^[0-9]+$`) ondalığı reddediyor — teknisyen `123.4` yazıp "Onayla & Yaz"a bastıktan sonra hata alıyor, önlenebilir bir geri dönüş.

---

## ⚪ Düşük Öncelik

**D1 — Erişilebilirlik/l10n altyapısı sıfır.** `lib/` genelinde `Semantics(` araması sonuçsuz; ikon-only `IconButton`ların çoğunda `tooltip` yok. Hiç `.arb`/`intl_*`/`flutter_localizations` yok — ~242 `Text()` widget'ı hardcoded Türkçe literal. `service_settings_tab.dart:91`'daki dil seçici (bkz. O3) bu altyapı yokluğunun somut bir örneği.

**D2 — Bölüm başlığı/kart widget'ları 4+ dosyada neredeyse birebir tekrar ediliyor.** `optional_settings_screen.dart`, `reports_tab.dart`, `service_settings_tab.dart` içinde ayrı ayrı tanımlanmış `_SectionHeader`/`_SectionLabel` (aynı font boyutu, `letterSpacing`, renk) — ortak bir `lib/screens/calibration/widgets/` modülüne çıkarılabilir.

**D3 — Uzun `build()` metodları + görünmeyen tab'larda arka planda çalışan timer'lar.** `CalibrationScreen._tab()` (satır 429-437) tüm 4 tab'ı `Stack` + `AnimatedOpacity` + `IgnorePointer` ile sürekli canlı tutuyor (literal bir `IndexedStack` değil) — `CalibrationParamsTab`'ın `Timer.periodic` "attention" hatırlatıcısı (satır 46) başka bir tab görünürken bile çalışmaya devam ediyor. Küçük ama sürekli bir CPU/pil maliyeti.

**D4 — `const` constructor eksiklikleri.** `_WeeklyThroughput`, `_DisconnectedBanner`, `_EmptyDtc`, `_DiagDisconnectedBanner` gibi sınıflar `const` constructor tanımlamıyor, oysa tüm alanları `final`. `prefer_const_constructors` lint taraması muhtemelen düzinelerce örnek bulur.

**D5 — Frame parser'da magic number'lar, sınırsız buffer büyümesi, log spam riski.** `kline_frame.dart:255,265` `0x62`/`0x6E`/`0x71` gibi ham SID değerleri isimlendirilmemiş sabitler yerine doğrudan kullanılıyor; `_buf` üst sınırı olmayan bir liste (K5 ile ilişkili); her bozuk bayt tek tek `LogLevel.error` ile loglanıyor — sürekli gürültü altında `AppLogger`'ın 500 kayıtlık ring buffer'ını doldurup asıl önemli bağlamı silebilir.

**D6 — DTC kod kataloğu doğrulanmamış/uydurulmuş görünüyor.** `lib/kline/kline_dtc_mapper.dart:28-141` — `CalibrationMessages.md` sadece DTC servis ID'lerini (0x19, 0x14) belgeliyor, spesifik DTC kod/açıklama listesi vermiyor. Buradaki tablo muhtemelen elle yazılmış; gerçek donanım/resmi listeyle doğrulanmalı.

**D7 — Simüle transport'un mock RDBI tablosu eksik.** `simulated_connection_service.dart:201-255` (`_getMockRdbiData`) `readAllCalibrationData()`'nın okuduğu bazı record ID'ler (0xF91E, 0xF91A, 0xF913, 0xF90D/0xF90E, 0xF90C, 0xF90F, 0xF920, 0xF19D vb.) için giriş içermiyor — Test Mode/demo oturumlarında kalibrasyon snapshot'ında gerçek cihazı yansıtmayan boşluklar oluşuyor.

**D8 — iOS konum izni açıklaması eksik; eski Gradle bayrakları.** `ios/Runner/Info.plist`'te `NSLocationWhenInUseUsageDescription` yok (şu an tetiklenmiyor ama `Permission.location` hiç çağrılırsa iOS'ta çökme riski). `android/gradle.properties`'teki `android.newDsl=false`/`android.builtInKotlin=false` Flutter şablonundan kalma, gözden geçirilmeli.

**D9 — Kök dizin dokümanları tutarsız.** `CalibrationMessages.md` `-rwx------` izinleriyle (muhtemelen kazara chmod), `README.md` tek satır ("A new Flutter project."), `STKC_Analiz.md` (35KB, değerli tersine mühendislik referansı) `README.md`/`CLAUDE.md`'den hiç link verilmiyor.

---

## Önerilen Epic/Sprint Gruplaması

| Epic | İçerdiği maddeler | Not |
|---|---|---|
| **E1 — Temel Altyapı (önce bu)** | K7, K8, H8 | Git init + test düzeltme + minimal CI, diğer her şeyin önkoşulu |
| **E2 — Test Kapsamı** | K9, K10 (kısmen) | `kline_codec` round-trip testleri en yüksek ROI |
| **E3 — Bağlantı Güvenilirliği** | K1, K6, H13, O8, O12 | Disconnect/reconnect/transport-seçimi sağlamlığı |
| **E4 — Kalibrasyon Yazma Bütünlüğü** | H2, H11, H12, O4, O6, O14, O15 | PIN kilidi, sessiz sıfırlama/clamp riskleri, validasyon tutarlılığı |
| **E5 — Tanı & Rapor Doğruluğu** | K4, H1, H5, O9 | Sahte "Geçti"/"BAŞARILI" sonuçlarının gerçek veriye bağlanması |
| **E6 — W-Sabiti & Saat Testi Tamamlama** | K2, K3 | İki ölü/yarım flow'un gerçek K-Line'a bağlanması |
| **E7 — Opsiyonel Ayarlar Genişletme** | O5, O10, O11 | ~22 eksik parametrenin yazma/okuma yolunun tamamlanması |
| **E8 — Şoför Ekranı Gerçek Veri** | H4 | Ürün kararı gerektirir — kapsam netleşince ayrı bir epic |
| **E9 — Yayına Hazırlık** | H6, H7, H9, H10 | İmzalama, ikon, crash reporting, bağımlılık güncelleme |
| **E10 — Güvenlik/Gizlilik** | H3 | PIN loglama redaksiyonu — küçük ama önemli |
| **E11 — Protokol Sağlamlığı** | K5, H14, H15, D5 | Frame parser resync, Flow 1 sadeleştirme, NRC-0x78 zamanlaması |
| **E12 — Kod Kalitesi/Temizlik** | O1, O2, O3, O7, D1-D4, D6-D9 | Sürekli, düşük riskli iyileştirmeler; boş zamanlarda alınabilir |

---

## Sprint Yol Haritası

Epic tablosundaki gruplamaları bağımlılık ve risk sırasına göre somut, sıralı sprint'lere döken öneri (2 haftalık sprint varsayımıyla — takım kapasitesine göre birleştirilip/bölünebilir). Her sprint başlamadan hemen önce, buradaki maddeler için ayrı bir detaylı planlama (görev kırılımı, kabul kriterleri, efor tahmini) yapılacak; bu bölüm sadece kapsam/sıra belirler.

**Sıralama mantığı:** (1) test/CI altyapısı olmadan riskli protokol değişikliklerine girmek güvensiz olduğu için önce temel; (2) veri bütünlüğü/güvenlik riskleri UX cilasından önce; (3) bağımsız iş paketleri aynı sprint'te toplanıyor.

### Sprint 1 — Temel Altyapı ve Güven Ağı
*(E1 + E2 + K10'un bug-düzeltme kısmı)*
- Git deposu başlat + baseline commit (K7)
- `flutter test`'i güncel rol-seçimi akışına göre düzelt (K8)
- Minimal CI ekle: `flutter analyze` + `flutter test` (H8)
- `kline_codec.dart` için round-trip/sınır-değer unit testleri (K9)
- `TachographSimulator` için kural testleri + 4.5 saatlik mola sıfırlama bug'ının düzeltilmesi (K10 — bug kısmı)
- CLAUDE.md'deki AB 561/2006 kapsam iddiasını gerçek koda göre güncelle
- **Amaç:** sonraki sprint'lerin üzerine güvenle inşa edilebileceği bir zemin.

### Sprint 2 — Bağlantı ve Protokol Sağlamlığı
*(E3 + E11)*
- "Bağlantıyı Kes"in gerçekten `disconnect()` çağırmasını sağla (K1)
- iOS'ta Classic Bluetooth'u engelle + transport varsayılanını platforma göre ayarla (K6, H13)
- Frame parser'da bozuk uzunluk baytında resync/üst sınır (K5, D5)
- NRC 0x78 bekleme süresini dokümana uygun hale getir (H15)
- Flow 1 (Security Access) sadeleştirmesi — gerçek donanımda doğrulanmalı (H14)
- Temel reconnection/retry stratejisi + Classic `readCharacteristic` timeout (O8, O12)
- **Amaç:** Bluetooth/K-Line katmanının güvenilirlik sorunlarını gidermek.

### Sprint 3 — Kalibrasyon Yazma Bütünlüğü ve Güvenlik
*(E4 + E10)*
- PIN kimlik doğrulamasının yazmaları gerçekten kilitlemesi (H2)
- Bağlı prewarning/download-period üçlü alanlarındaki sessiz sıfırlama riskinin giderilmesi (H11)
- Opsiyonel Ayarlar'ın 13 alanına validasyon eklenmesi, encoder'ların sessiz clamp yerine hata vermesi (H12)
- K/W-Sabiti yazma sırasının doğrulanması/düzeltilmesi (O4)
- SecurityAccess NRC'sinin UI'a iletilmesi (O6)
- Validasyon exception'ının `try` bloğuna alınması, ondalık tuş düzeltmesi (O14, O15)
- Workshop PIN'inin loglardan redakte edilmesi (H3)
- **Amaç:** Cihaza yazılan hiçbir değerin sessizce yanlış veya yetkisiz olmaması.

### Sprint 4 — Tanı ve Rapor Doğruluğu
*(E5)*
- Tanı testlerinde gerçek NRC kontrolü — sahte "Geçti" sonucunun giderilmesi (K4)
- Desteklenmeyen 2 testin (Saat, Hız&Km) "Başarısız" yerine "Desteklenmiyor" göstermesi (O9)
- Raporlardaki sahte "BAŞARILI" rozetinin ve uydurma teknisyen notunun gerçek veriye bağlanması (H5)
- PDF Dışa Aktar / Yazdır'ın gerçek implementasyonu (H1)
- **Amaç:** Uygulamanın "geçti"/"başarılı" dediği her şeyin gerçek olması — yasal/güvenlik açısından kritik.

### Sprint 5 — Ölü Akışların Tamamlanması ve Opsiyonel Ayarlar Genişletmesi
*(E6 + E7)*
- W-Sabiti otomatik ölçüm akışının gerçek K-Line'a bağlanması (K2)
- Saat Testi'nin gerçek drift ölçümü — native/donanım tarafı netleştirilmeli (K3)
- ~22 eksik dokümante opsiyonel parametrenin yazma/okuma yolunun tamamlanması (O5)
- Ölü K-Line record sabitlerinin bağlanması veya temizlenmesi (O10)
- Motion sensor routine ID doğrulaması (O11)
- **Amaç:** Dokümante edilmiş ama hiç bağlanmamış protokol kapsamını kapatmak.

### Sprint 6 — Yayına Hazırlık
*(E9)*
- Gerçek `applicationId` + release imzalama config'i (H6)
- Uygulama ikonu (Android) / açılış ekranı (iOS) (H7)
- Crash reporting entegrasyonu (H9)
- Bağımlılık güncellemeleri: `flutter_blue_plus` 2.x, `permission_handler` 12.x vb. (H10)
- **Amaç:** Uygulamayı gerçekten yayınlanabilir hale getirmek.

### Sprint 7 — Ürün Kararları, UX ve Kod Kalitesi
*(E8 + E12 + O13, D3)*
- Şoför ekranının (MonitorScreen) gerçek cihaza bağlanıp bağlanmayacağına dair ürün kararı + uygulanması (H4)
- Koyu Tema / Dil ayarlarının gerçekten uygulanması ya da arayüzden kaldırılması (O3)
- "Son Raporlar" geçmişinin kalıcı hale getirilmesi (O2)
- Geri tuşu UX iyileştirmesi (O7)
- Dispose-sonrası `setState` düzeltmeleri (O1)
- Rol seçimi / uygulama config kalıcılığı (O13)
- Erişilebilirlik/l10n altyapısı için ürün kararı (D1)
- Kod tekrarı temizliği, `const` constructor'lar, uzun `build()`/arka plan timer temizliği (D2, D3, D4)
- DTC kataloğu doğrulaması, simüle transport mock tamamlama, iOS izin açıklaması, kök dizin dokümantasyon düzeni (D6, D7, D8, D9)
- **Amaç:** Kalan ürün kararlarını netleştirmek ve genel kod kalitesini yükseltmek.

### Kapsam dışı / ayrı takip
- `PossibleProblems.md`'deki donanım doğrulama gerektiren 8 madde — yazılım sprint'i değil, gerçek cihazla test seansı olarak ayrı planlanmalı.
- `TachographSimulator`'ın AB 561/2006 kapsamının tam genişletilmesi (günlük/haftalık limitler, mola deseni doğrulaması) — Sprint 1'de sadece mevcut bug düzeltiliyor; tam kapsam genişletmesi ayrı bir ürün kararı gerektirir, istenirse Sprint 7'den sonrasına eklenebilir.

---

## Zaten Çözülmüş Maddeler (önceki oturumlarda kapatıldı)

Bu tarama sırasında, proje belleğindeki bazı eski notların artık **güncel olmadığı** doğrulandı — sprint planlamasında yeniden açılmamalı:

- ✅ **Opsiyonel Ayarlar'ın 13 temel alanı** artık gerçekten K-Line'a yazıyor/okuyor (`optional_settings_screen.dart:141-185`, `kline_service.dart:294-329`) — önceki "tamamen simüle" durumu geçerliliğini yitirdi. (Ancak O5'te belirtildiği gibi, dokümante edilen ~35 alanın geri kalanı hâlâ bağlı değil.)
- ✅ `code_page` CalParam'ı tamamen kaldırıldı, kodda hiç referansı yok.
- ✅ `readAllCalibrationData`/`_applySnapshot` artık daha önce eksik olan 9 CalParam'ı (`trip_distance`, `datetime`, `utc_offset`, `heartbeat`, `tco1_priority`, `tco1_rate`, `prewarning_card1/tacho/cal`, `download_period_vu/card`) okuyor.
- ✅ "Takograf Ayarları" bölümündeki yanıltıcı isimlendirme küçüldü — artık sadece "Foto Sensör" alanı yerel kaldı (önceden 4 alan böyleydi); "Dil" ve "Koyu Tema" doğru şekilde "Uygulama Ayarları" bölümüne taşındı (her ne kadar O3'te belirtildiği gibi bu ikisi de hâlâ işlevsiz olsa da).
- ⚠️ Hâlâ açık kalan önceden bilinen maddeler (bu dokümanda ilgili ID'lerle yeniden listelendi): PIN kilidi yok → **H2**, W-Sabiti bağlı değil → **K2**, Foto Sensör K-Line'a bağlı değil → (H12/O5 kapsamında, ayrı ele alınabilir).

---

## Kapsam Dışı Bırakılanlar / Bağımsız Doğrulama Gerektirenler

- `PossibleProblems.md`'deki 10 bilinen entegrasyon riskinden 8'i hâlâ gerçek donanımda doğrulanmayı bekliyor (60ms mesaj-arası gecikme ayarı, ikinci StartComm zorunluluğu, vb.) — bunlar yazılım değişikliği değil, "donanım doğrulama" epic'i olarak ayrı ele alınmalı.
- `flutter analyze` şu an **temiz** (0 uyarı) — pozitif bir taban çizgisi ama sadece varsayılan `flutter_lints` kural setiyle; ekip büyüdükçe daha sıkı kurallar (`avoid_print` vb.) değerlendirilebilir.
