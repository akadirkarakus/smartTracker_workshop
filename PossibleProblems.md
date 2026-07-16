# Possible Problems — K-LINE / KWP2000 Integration

## 1. K-LINE Wakeup Yöntemi

**Seçilen yol:** `0x00` byte gönder + 23 ms bekle, ardından StartCommunication (`81 EE F0 81 E0`).

**Risk:** Bazı adaptörler (USB-RS232 köprüsü, BT-SPP adaptör) `0x00` yerine voltaj seviyesini doğrudan manipüle eder ya da wakeup'ı donanım katmanında halleder. Bu durumda uygulama `0x00` gönderdiğinde adaptör bunu takografa iletmez veya wakeup gereksinimi yoktur. Takografın ilk StartCommunication'a yanıt vermemesi bu duruma işaret edebilir.

**Alternatifler:**
- Adaptöre özgü AT komutu (örn. `ATZ`, `ATSP5`) ile wakeup tetikleme.
- `0x00` göndermeden doğrudan StartCommunication (bazı adaptörler donanım katmanında wakeup yapar).

---

## 2. Response Frame Formatı

**Risk:** Adaptörün ham K-LINE frame'leri (başlık + CS dahil) mi yoksa sadece payload baytlarını mı döndürdüğü bilinmiyor. `KLineFrameBuffer`, tam KWP2000 frame beklediği için (`0x80 0xEE 0xF0 LEN SID DATA CS`) payload-only yanıt gelirse parse başarısız olur.

**Test:** Bağlandıktan sonra SPP_DATA akışını ham olarak logla. Eğer ilk byte `0x80` veya `0xC1` değilse adaptör wrap yapmıyordur.

---

## 3. Bayt Bölünmesi (TCP/BT Chunking)

**Risk:** SPP akışı tek bir K-LINE frame'ini birden fazla paket halinde teslim edebilir. `KLineFrameBuffer.add()` bu durumu yönetmek için tasarlandı; ancak adaptör davranışına (her byte'ı ayrı bildirim mi, blok mu) göre farklı çalışabilir.

**Symptom:** Bazı frame'ler parse edilemez veya kaybolur.

---

## 4. 60 ms Inter-Message Gecikme

**Risk:** `_interMsgDelay()` fonksiyonu tüm request/response çiftleri arasında 60 ms bekler. Eğer bu süre çok kısa tutulursa takograf "mesaj sıralama hatası" nedeniyle sonraki isteği reddedebilir (NRC 0x21 — busyRepeatRequest). Çok uzun tutulursa kalibrasyon oturumu zaman aşımına uğrayabilir.

**Önerilen eylem:** İlk entegrasyon testinde her iki yönde de (40 ms, 80 ms) dene.

---

## 5. Write Commit İçin İkinci StartCommunication

**Risk:** Flow 3–7'de parametre yazıldıktan sonra veriyi kalıcı belleğe (flash) commit etmek için ikinci bir StartCommunication göndermek gerekebilir. Bu adım atlanırsa parametreler volatile RAM'de kalır ve güç kesiminde kaybolur. Stoneridge dokümanı bunu "Programming Session → commit" olarak tanımlar; bazı takograflar bunu zorlamaz.

**Test:** Parametre yaz → güç kes → yeniden bağlan → parametreyi oku. Değer korunmuyorsa commit adımı eksik demektir.

---

## 6. NRC 0x78 — Bekleyen Yanıt Döngüsü

**Risk:** SecurityAccess `SendKey` sonrası takograf PIN'i 1000 ms+ işleyebilir ve bu süre zarfında `NRC 0x78` (requestCorrectlyReceivedResponsePending) ile yanıt verir. `KLineService._send()` bu durumda yeniden deneme döngüsüne girer. Süresiz bekleme tehlikesi: NRC 0x78 kesilmeden devam ederse döngü hiç çıkmaz.

**Uygulanan çözüm:** Maximum yeniden deneme süresi 10 s, her deneme arasında `_interMsgDelay()`.

---

## 7. Stoneridge W-Constant Varyantı

**Risk:** Bazı Stoneridge takograflarında W-Constant (0xF91D) yazıldığında K-Constant (0xF918) da aynı değerle otomatik olarak yazılmak zorunda olabilir. Yanlış detekte edilirse K-Constant üzerine istenmeyen bir değer yazılabilir.

**Uygulanan strateji (güncel kod):** W-Constant yazılırken K-Constant otomatik olarak aynı değerle yazılıp doğrulanıyor (`kline_service.dart::writeParameter`, `CalibrationMessages.md` Flow 3'teki STONERIDGE özel durumuna uygun). K-Constant tek başına düzenlendiğinde bu ikili yazma tetiklenmez. Gerçek cihazda bu dual-write'ın beklenmedik şekilde K-Constant'ın üzerine yazmaya yol açıp açmadığı hâlâ doğrulanmalı.

---

## 8. TesterPresent Keep-Alive Akışı

**Risk:** Uzun süren testlerde (Clock Test Flow 10, Speed/Odo Test Flow 11) her 150 ms'de bir `TesterPresent (3E)` gönderilmesi gerekir. Mobil uygulama arka plana alındığında veya ekran kilitlendiğinde (özellikle iOS) bu akış kesilebilir ve aktif kalibrasyon oturumu zaman aşımına uğrar.

**Geçici çözüm:** Test süresince `WakeLock` aktif et (Flutter `wakelock_plus` paketi). Uzun test başlamadan önce kullanıcıyı uyar.

---

## 9. Bluetooth Yetkileri (Android 12+)

**Risk:** Android 12 ve üzerinde `BLUETOOTH_SCAN` ve `BLUETOOTH_CONNECT` izinleri çalışma zamanında talep edilmeli. İzin reddedilirse BLE/SPP tarama tamamen başarısız olur.

**Kontrol:** `AndroidManifest.xml`'de `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` tanımlı mı?

---

## 10. iOS Core Bluetooth Kısıtlamaları

**Risk:** iOS, background modda Core Bluetooth bağlantılarını kısıtlar. SPP (Classic Bluetooth) iOS'ta `ExternalAccessory` framework'ü gerektirir ve MFi sertifikası olmayan adaptörler bu framework'e erişemez. Bu nedenle iOS'ta K-LINE bağlantısı yalnızca BLE üzerinden mümkün olabilir; bu da adaptörün BLE+SPP bridge desteği gerektireceği anlamına gelir.

---

## 11. ⚠️ SecurityAccess Tek-Transaction Sadeleştirmesi — Donanım Testi Gerekli

**Risk:** `KLineService.requestSeed()`/`sendKey()`, önceden (H14 düzeltmesi öncesi) her biri kendi bağımsız transaction'ında çalışıyordu — `sendKey()` kendi içinde YENİ bir RequestSeed daha gönderiyordu. Bu, operatöre gösterilen seed ile `SendKey` anında ECU'nun beklediği seed'in farklı olabileceği bir riski taşıyordu (tachograf her RequestSeed'de farklı/rastgele seed üretiyorsa). Düzeltme, `requestSeed()`'i transaction'ı kapatmadan bırakıp, operatör PIN'i hesaplarken bir `TesterPresent` keep-alive (`securityAccessKeepAliveInterval`, 2 s) ile oturumu canlı tutuyor; `sendKey()` bu AYNI oturum üzerinden PIN'i gönderiyor.

**Doğrulanmamış varsayım:** Tachografın, RequestSeed sonrası uzatılmış (potansiyel olarak dakikalarca sürebilen) bir bekleme penceresinde hâlâ o seed'i geçerli kabul ettiği — bazı ECU implementasyonları SecurityAccess için S3 oturum zaman aşımından bağımsız, çok daha kısa bir "seed-to-key" penceresi uygulayabilir.

**Test:** Gerçek tachograf donanımıyla uçtan uca dene: seed göster → operatör servis kartından PIN hesaplasın (gerçekçi bir gecikmeyle, örn. 30-60 s) → PIN gir → doğrula. Ayrıca yanlış PIN girip (kilitlenmeden) tekrar deneme akışını test et (aynı seed'in tekrar kabul edilip edilmediği). Başarısız olursa geri dönüş planı: seed'i göstermeden önce operatörden PIN'i harici olarak önceden hazırlamasını isteyen bir UX'e geçmek (RequestSeed ve SendKey'i minimum gecikmeyle art arda göndermek).

---

## 12. ⚠️ Gerçek BLE'de 'SPP_DATA' Kanal Adı Hiç Eşlenmiyor — Bilinen Kırık

**Risk:** `KLineService`, transport'tan bağımsız olarak sabit `'SPP_DATA'` kanal adını kullanır (`writeCharacteristic`/`setNotify`/`notifyStream`, hepsi `kline_service.dart`). Bu isim `classic_connection_service.dart` ve `simulated_connection_service.dart`'ta gerçekten tek kanalın literal adı olarak kullanılıyor, ama `FlutterBluePlusConnectionService` (`ble_connection_service.dart`) karakteristikleri gerçek GATT UUID'leriyle anahtarlıyor — `'SPP_DATA'` → gerçek UUID eşlemesi hiçbir yerde yok. Ayrıca `ble_terminal_screen.dart`'taki `_kNotifyChar`/`_kWriteChar` sabitleri gerçek cihaz UUID'leri değil, LightBlue test ortamı için konmuş placeholder'lar (bkz. dosyadaki "Sabit UUID'ler (LightBlue test ortamı)" yorumu).

**Sonuç:** Gerçek bir BLE tachograph adaptörüne bağlanıldığında `KLineService` her zaman `BleCharacteristicException: Notify not active: SPP_DATA` ile patlar — bu cihaza özgü bir uyumsuzluk değil, kodda eksik bir entegrasyon katmanı.

**Gereken düzeltme:** `discoverServices()` sonrası gerçek adaptörün notify/write karakteristiklerini (standart GATT servisleri hariç tutarak — Generic Access 1800, Generic Attribute 1801, Device Information 180A, Battery 180F) tespit edip `'SPP_DATA'` adı altında alias'lamak gerekiyor. Adaptörün tek çift-yönlü karakteristik mi yoksa ayrı TX/RX karakteristikleri mi kullandığı bilinmiyor — `BleConnectionRepository` arayüzü şu an tek bir `charUuid` string'inin hem yazma hem notify'ı karşıladığını varsayıyor; ayrı TX/RX ise arayüzün genişletilmesi gerekebilir.

**Test:** Gerçek adaptöre bağlan, `discoverServices()`'ın logladığı servis/karakteristik listesini (`Service: ...` satırları) kaydet, gerçek notify+write UUID'lerini belirle, `ble_terminal_screen.dart`'taki placeholder'ları güncelle ve BLE tarafı için `'SPP_DATA'` alias mekanizmasını uygula.

**Durum (2026-07-14):** `'SPP_DATA'` alias mekanizması `ble_connection_service.dart::_resolveSppDataAlias()` ile eklendi (standart GATT servislerini eleyip yazma+notify destekleyen ilk özel karakteristiği eşliyor) ve `ble_terminal_screen.dart`'taki LightBlue placeholder UUID'leri kaldırıldı. Ardından ayrı bir bug ortaya çıktı — bkz. #13.

---

## 13. BLE Terminal → KLineService Devir Race Condition (Düzeltildi 2026-07-14)

**Risk:** `ble_terminal_screen.dart`, `onConnected` callback'ini (KLineService'in inşa edildiği yer) ham GATT `connectionState == connected` olayına bağlı SABİT bir 2 sn `Timer` ile tetikliyordu — bu, `_connect()` içindeki asıl `discoverServices()` + `setNotify('SPP_DATA', ...)` zincirinin bitip bitmediğinden bağımsızdı. Bu iki adım 2 sn'den uzun sürerse (yavaş/gerçek cihazlarda olası), `KLineService` notify kanalı hazır olmadan inşa ediliyor, constructor'daki `notifyStream('SPP_DATA')` çağrısı `BleCharacteristicException` fırlatıyordu — ve bu, bir `Timer` callback'i içinde try/catch'siz olduğu için YAKALANMAMIŞ bir exception olarak uygulamayı donduruyordu ("Exception has occurred", debugger/ANR benzeri davranış).

**Düzeltme:** `_scheduleHandoff()` artık `setNotify()` başarıyla `await` edildikten SONRA `_connect()` içinden çağrılıyor; ham `connectionState` listener'ı sadece UI state'i güncelliyor, handoff'u tetiklemiyor. `setNotify` hata verirse (örn. karşı cihaz K-Line değilse/yanıt vermiyorsa) `onConnected` hiç çağrılmıyor, hata terminal ekranında görünür kalıyor — uygulama donmuyor.

**Doğrulanmamış ayrı risk:** Kullanıcı, bağlandığı cihazın takograf olmayabileceğini veya farklı bir üretici takografı olabileceğini belirtti — bu durumda `KLineService`'in wakeup/StartCommunication adımı (Flow 1) muhtemelen timeout ile başarısız olacak (bkz. `KLineTiming.defaultTimeout`, `_transact()`), ki bu beklenen/güvenli bir davranış, ama gerçek uyumlu donanımla doğrulanmadıkça K-Line akışının bu cihazla çalışıp çalışmadığı bilinmiyor.

---

## 14. ⚠️ KRİTİK — `lastValueStream` Kendi Yazdığımız Byte'ları Yankı Olarak Geri Veriyordu (Düzeltildi 2026-07-14)

**Risk:** `FlutterBluePlusConnectionService.setNotify()`, gelen bildirimleri dinlemek için `c.lastValueStream` kullanıyordu. `flutter_blue_plus` paketinin kendi dokümantasyonuna göre (`bluetooth_characteristic.dart:64-72`) bu stream `onCharacteristicReceived` (gerçek gelen veri) İLE `onCharacteristicWritten` (bizim `write()` çağrılarımızın onayı) stream'lerini BİRLEŞTİRİYOR. K-Line'da hem istek hem yanıt aynı `SPP_DATA` karakteristiği üzerinden aktığı için, her `writeCharacteristic('SPP_DATA', frame)` çağrısından hemen sonra gönderdiğimiz byte'ların TIPKISI, sanki takograftan gelmiş gibi `notifyStream('SPP_DATA')`'ya düşüyordu.

**Belirti:** Gerçek test loglarında (`Kadir's AirPods` ve `Bilinmeyen Cihaz` ile) gönderdiğimiz `StartCommunication` isteği (`81 EE F0 81 E0`) `← Notify [SPP_DATA]` olarak, biz onu göndermeden hemen önce/sonra buffer'a düşüyor, `KLineFrameBuffer` bunu geçersiz bir yanıt formatı olarak parse etmeye çalışıp "Unknown frame format" hatalarıyla byte byte atıyor, ve gerçek yanıt hiç gelmeden `_transact()` "Yanıt zaman aşımına uğradı" ile timeout oluyordu.

**Etki:** Bu, bağlanılan cihazdan TAMAMEN BAĞIMSIZDI — gerçek, tam uyumlu bir takografla bile K-Line hiçbir zaman çalışamazdı, çünkü kendi giden isteğimiz her seferinde kendi alım buffer'ımızı kirletiyordu.

**Düzeltme:** `setNotify()` artık `c.lastValueStream` yerine `c.onValueReceived` kullanıyor — bu stream sadece `read()` çağrılarını ve gerçek gelen bildirimleri yayınlar, kendi `write()` çağrılarımızı İÇERMEZ (bkz. `ble_connection_service.dart::setNotify`).

**Test:** Gerçek tachograf donanımıyla yeniden dene — artık `← Notify` loglarında kendi gönderdiğimiz byte dizileri (`→ Sent` ile aynı içerik) görünmemeli.

---

## 15. Android Classic SPP — "Socket Might Be Closed" (Düzeltildi 2026-07-14)

**Risk:** `ClassicBluetoothConnectionService.connect()`, `flutter_classic_bluetooth` paketinin `secure` parametresini hiç vermeden çağırıyordu, bu da varsayılan olarak Android'in `createRfcommSocketToServiceRecord()` (secure/authenticated RFCOMM, SSP eşleşmesi gerektirir) metodunu kullanıyordu. Karşı cihaz SSP eşleşmesini düzgün desteklemiyorsa (jenerik BT-seri köprü modülleri — HC-05/06 klonları ve benzerleri — genelde bunu desteklemez), Android native tarafta `IOException: read failed, socket might closed or timeout, read ret: -1` fırlatılır (`BtcConnectionException` olarak Dart'a geliyor).

**Belirti:** Kullanıcı, kendi firmasının takograf cihazına SPP ile sorunsuz bağlanabiliyor (muhtemelen zaten eşleşmiş/secure destekliyor) ama taramada bulunan diğer cihazların neredeyse hiçbirine SPP modunda bağlanamıyor — hepsi "Connection failed, socket might be closed" ile başarısız oluyor. BLE modunda bazı bilinmeyen cihazlara bağlanabiliyor (BLE'nin güvenlik modeli farklı, bu sorunu yaşamıyor).

**Düzeltme:** `connect()` artık önce secure RFCOMM dener; `BtcConnectionException` alırsa (ki bu tam olarak bu native IOException'ın Dart karşılığı) `secure: false` ile insecure RFCOMM'a otomatik fallback yapıyor. Gerçek zaman aşımlarında (`BtcTimeoutException` — cihaz menzil dışı/kapalı) fallback YAPILMIYOR, çünkü bu farklı bir hata sınıfı.

**Test:** Gerçek cihazlarla dene — daha önce "socket might be closed" ile başarısız olan cihazların artık insecure fallback ile bağlanıp bağlanmadığını doğrula (test log'da "Secure RFCOMM failed, retrying as insecure..." satırını ara).

---

## 16. Saat Testi (Flow 10) Gerçek Sapma Ölçemez — Donanım Kısıtı (Netleştirildi, Sprint 5)

**Risk/Kısıt:** `CalibrationMessages.md` Flow 10'a göre 1 Hz RTC darbeleri K-Line veri hattında değil, ayrı bir "kalibrasyon I/O hattında" akıyor ve "cihazın kendi 120 MHz donanım sayacı" ile yakalanması gerekiyor. K-Line üzerinden akan tek şey darbe penceresi boyunca gönderilen `TesterPresent` keep-alive'lardır (`kline_service.dart::runClockTest()`) — hiçbir yanıt ne darbe zamanlaması ne de hesaplanmış sapma değeri taşıyor.

**Sonuç:** Gerçek ±s/gün sapma hesabı, bu uygulamanın mevcut Flutter/Dart + K-Line mimarisiyle **yazılım-only çözülemez** — RTC darbelerini donanım düzeyinde zaman damgalayabilen ayrı bir adaptör/native entegrasyon gerekir. Bu bir kod eksikliği değil, mimari bir sınır.

**Mevcut durum:** `extended_hardware_test_screen.dart` bunu yanıltmadan belirtiyor ("sapma hesaplaması bu sürümde uygulanmadı, sadece iletişim doğrulanır") — kod tarafında ek değişiklik yapılmadı. İleride gerçek sapma ölçümü isteniyorsa, ayrı bir donanım entegrasyonu kararı ve muhtemelen adaptör firmware değişikliği gerekir.

---

## 17. ⚠️ P4min Bayt-Arası Gecikme Eksikti — Takografın Kendi Debug Çıktısında Header Hataları (Düzeltildi 2026-07-16)

**Belirti:** Gerçek donanıma bağlanıldığında, takografın kendi seri/debug çıkışında (uygulamanın logundan BAĞIMSIZ, doğrudan takograf firmware'inin ürettiği) bağlantı anında 4-5 kırmızı hata satırı görülüyordu: `kwp: FMT not correct!`, `ddw: TGT check failure!`, `daw: SRC check failure!`. Okuma/yazma işlemleri yine de çalışıyordu — sadece bağlantı anında (Wakeup+StartCommunication) görünüyordu.

**Kök neden:** ISO 14230, test cihazının (bizim) gönderdiği bir frame içindeki ardışık baytlar arasında **P4min ≥ 5 ms** boşluk bırakmasını şart koşar. `/Users/akadir/Desktop/SmartTrack/STKC` (bu projenin referans aldığı, gerçek donanımda kanıtlanmış çalışan kalibrasyon cihazı) firmware'i bunu birebir uyguluyor — `Kline_Port.c::Send_KLINE_Package_Receive_Response()` her baytı ayrı `UART_write` ile gönderip aralarında `Task_sleep(5)` bekliyor; ayrıca K-LINE tek telli (half-duplex) olduğu için gönderdiği her baytın yankısını `UART_read` ile okuyup atıyor. `KLineService`'imiz ise her frame'i (`KLineFrame.startCommunication()` dahil, doğrulandı: `81 EE F0 81 E0` STKC'nin kaynağıyla birebir aynı — header/checksum'da hata yoktu) TEK bir `writeCharacteristic` çağrısıyla, bayt-arası hiçbir boşluk garantisi olmadan gönderiyordu. Bağlantı anında (360→10400 baud geçişinden hemen sonraki ilk frame, StartCommunication) bu, takografın basit gömülü K-LINE alıcısının header baytlarını (FMT/TGT/SRC) hizalı okuyamamasına yol açıyordu; sonraki mesajlar zaten var olan 60 ms `interMessageDelay` sayesinde daha toleranslı bir ritme oturduğundan okuma/yazma sorunsuz çalışıyordu.

**Düzeltme:** `KLineService._write()` artık her frame'i STKC ile birebir aynı disipline göre gönderiyor — baytı yaz, `KLineTiming.interByteDelay` (5 ms, P4min) kadar bekle, sonrakini yaz. `KLineFrameBuffer.expectEcho()` de eklendi: köprü adaptörü ham K-LINE geçişi yapıp kendi baytlarımızı bize yankı olarak geri veriyorsa (STKC'nin de okuyup attığı gibi), bu yankı gerçek yanıtla karışmadan sessizce tüketiliyor.

**Test:** Gerçek donanımla yeniden bağlan — takografın debug çıkışında bu üç satırın artık görünmediğini doğrula. Görünmeye devam ederse, köprü adaptörünün K-LINE tarafında P4min'i KENDİ bit-bang'inde farklı şekilde ihlal ediyor olabileceği düşünülmeli (bu durumda `interByteDelay` değerini artırmak veya adaptör firmware'ini incelemek gerekir).

**Doğrulama (2026-07-16):** Kullanıcının sağladığı `CELEX_02016R0799-20230821_EN_TXT.pdf` (Regulation (EU) 2016/799, Annex 1C App.8 "Calibration Protocol", Table 4 "Communication timing values") bunu resmi olarak teyit ediyor: **P4 = Inter byte time for tester request, min 5 ms, max 20 ms.** `interByteDelay=5ms` bu aralığın alt sınırında ve tam uyumlu. Aynı tablo P3 (VU yanıtı sonu ile yeni tester isteği arası) için min 55 ms veriyor — mevcut `KLineTiming.interMessageDelay=60ms` de bunun üzerinde, uyumlu.

**⚠️ Varsayım yanlış çıktı (2026-07-16):** "Sonraki mesajlar zaten var olan 60ms interMessageDelay sayesinde sorunsuz çalışıyordu" notu gerçek donanımda hiç doğrulanmamıştı. Kullanıcı, aynı üç hata satırının (`ddw: TGT check failure!` / `daw: SRC check failure!` / `ddw: FMT check failure!`) artık StartCommunication'a özgü olmadığını, **her RDBI/WDBI isteğinde de sürekli** tekrarlandığını bildirdi (checksum hatası sanılmıştı, ama gerçek metin header/adres kontrolü hatası). Checksum algoritması (`kline_frame.dart::_cs`) bağımsız olarak STKC referans kaynağı ve CELEX regülasyon metniyle karşılaştırılıp doğru bulundu — sorun kesinlikle checksum formülünde değil.

**Yeni hipotez:** `KLineService._write()`, her `writeCharacteristic()` çağrısından SONRA 5ms bekliyor, ama çağrının KENDİSİNİN ne kadar sürdüğünü hesaba katmıyor. BLE'de karakteristik `writeWithoutResponse` desteklemiyorsa her bayt bir ACK round-trip'i bekler; bu, yazılımın eklediği 5ms'in üzerine öngörülemez bir gecikme daha ekleyip gerçek bayt-arası boşluğu P4max=20ms sınırının üzerine taşırabilir. Bu, kısa StartCommunication frame'inde (5 bayt) daha az görülüp RDBI/WDBI'de (8+ bayt) sürekli görülmesiyle tutarlı — bayt sayısı arttıkça bir boşluğun sınırı aşma ihtimali artar. ECU bir P4 timeout'undan sonra bir sonraki (aslında halâ mevcut frame'e ait) baytı yeni bir frame'in FMT'si sanabilir, bu da FMT→TGT→SRC kontrollerinin art arda başarısız olmasını açıklar.

**Eklenen teşhis (2026-07-16):** `KLineService._write()` artık her bayt için gerçek geçen süreyi (önceki bayttan bu yana + `writeCharacteristic()` çağrısının kendi süresi) `AppLogger`'a logluyor; `ble_connection_service.dart::writeCharacteristic()` da `withoutResponse` mu yoksa ACK'li yazım mı kullanıldığını logluyor. Henüz bir düzeltme değil — amaç bir sonraki donanım testinde gerçek bayt-arası boşlukları ve yazım modunu ölçüp hipotezi doğrulamak/çürütmek.

**Test:** Gerçek donanıma bağlan, hatayı üreten bir RDBI/WDBI akışını tetikle, `TestLogScreen` çıktısını incele: (1) yazım ACK'li mi, (2) ölçülen bayt-arası boşluklar 5-20ms aralığında mı. Aralık dışına çıkan boşluklar + ACK'li yazım tespit edilirse, çözüm muhtemelen `writeWithoutResponse`'ı zorlamak veya BLE bağlantı parametrelerini (connection interval) düşürmek olacaktır.

---

## 18. Var Olmayan "Fast-Init Yanıt" Formatı — StartCommunication Yanıtı Aslında Standart Frame (Düzeltildi 2026-07-16)

**Risk:** `KLineFrameBuffer`, StartCommunication'ın pozitif yanıtının ayrı, özel bir 5 baytlık format (`C1 EE F0 <SID> <CS>`, FMT=0xC1) olduğunu varsayıyordu (`_fmtFastResp`/`_parseFastInitResponse`). Bu, `CalibrationMessages.md`'nin (türetilmiş bir doküman) yanlış yorumlanmasından kaynaklanıyordu.

**Gerçek:** `CELEX_02016R0799-20230821_EN_TXT.pdf`, Annex 1C App.8, Table 6 "StartCommunication Positive Response Message" açıkça gösteriyor ki bu da **standart formatta, 8 baytlık normal bir frame**: `80 <tt> EE 03 C1 <KB1=EA> <KB2=8F> <CS>` (FMT=0x80, TGT=tester adresi, SRC=0xEE, LEN=3, SID=0xC1, iki "key byte", CS). Ayrı bir "fast-init yanıt" formatı yok — bunu STKC'nin gerçek C kaynağı da doğruluyor (`Kline_Port.c::Send_KLINE_Package_Receive_Response`, her yanıtı tek tip `0x80` formatında bekliyor).

**Etki:** Pratikte zararsızdı çünkü gerçek yanıtlar `0x80` ile başladığından her zaman doğru (standart) dala düşüyordu; yanlış `_fmtFastResp` dalı hiç tetiklenmiyordu — ama gürültülü/echo'lu bir akışta tesadüfen `_buf[0]==0xC1` olursa yanlış dala girip veri bozulmasına yol açabilirdi.

**Düzeltme:** `_fmtFastResp`/`_parseFastInitResponse` kaldırıldı; tüm yanıtlar tek, doğru standart-format yoluyla parse ediliyor. Test yardımcıları (`hardware_test_runner_test.dart`, `kline_service_routine_test.dart`) resmi 8 baytlık formatı (KB1/KB2 dahil) kullanacak şekilde güncellendi.
