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

**Uygulanan strateji:** W-Constant, K-Constant'tan bağımsız yazılıyor. Gerçek cihaz testi gerektirir.

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
