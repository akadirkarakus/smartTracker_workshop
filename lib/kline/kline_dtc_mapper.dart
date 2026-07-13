// KWP2000 3-byte DTC kod çözücü.
// Yüksek byte (bit 23-16) alt sistemi belirtir.
// Bilinmeyen kodlar için modül adını içeren genel açıklama döner.

class KLineDtcMapper {
  KLineDtcMapper._();

  static String module(int code) {
    final high = (code >> 16) & 0xFF;
    return _modules[high] ?? 'ECU';
  }

  static String description(int code) {
    return _descriptions[code] ?? _fallback(code);
  }

  static String _fallback(int code) {
    final mid = (code >> 8) & 0xFF;
    final low = code & 0xFF;
    final mod = module(code);
    final sub = '${mid.toRadixString(16).toUpperCase().padLeft(2, '0')}'
        '${low.toRadixString(16).toUpperCase().padLeft(2, '0')}';
    return '$mod arızası (alt kod: 0x$sub)';
  }

  // ── Yüksek byte → modül adı ───────────────────────────────────────────────

  static const Map<int, String> _modules = {
    0x00: 'ECU',
    0x01: 'Hareket Sensörü',
    0x02: 'Kart Okuyucu',
    0x03: 'Ekran',
    0x04: 'Yazıcı',
    0x05: 'Güç Kaynağı',
    0x06: 'Saat / RTC',
    0x07: 'Veri Belleği',
    0x08: 'CAN Veriyolu',
    0x09: 'GNSS / Anten',
    0x0A: 'Tuş Takımı',
    0x0B: 'Buzzer',
    0x0C: 'Yazılım',
    0x0D: 'Sürücü Kartı',
    0x0E: 'Asistan Kartı',
    0x0F: 'Ön Panel',
    0xC0: 'Hız Girişi',
    0xC1: 'TCO1 Çıkışı',
    0xC2: 'CAN-A',
    0xC3: 'CAN-C',
    0xFF: 'Genel',
  };

  // ── Bilinen DTC kod tablosu ───────────────────────────────────────────────

  static const Map<int, String> _descriptions = {
    // Hareket sensörü
    0x010001: 'Hareket sensörü sinyal yok',
    0x010002: 'Hareket sensörü sinyal hatalı',
    0x010003: 'Hareket sensörü kimlik doğrulama hatası',
    0x010004: 'Hareket sensörü eşleşme kaybı',
    0x010005: 'Hareket sensörü frekans hatası',

    // Kart okuyucu
    0x020001: 'Sürücü kartı okuyucu arızası',
    0x020002: 'Sürücü kartı iletişim hatası',
    0x020003: 'Asistan kartı okuyucu arızası',
    0x020004: 'Asistan kartı iletişim hatası',
    0x020005: 'Kart klonlama algılandı',

    // Ekran
    0x030001: 'Ekran iletişim hatası',
    0x030002: 'Ekran arka ışık arızası',
    0x030003: 'LCD kontroller hatası',

    // Yazıcı
    0x040001: 'Yazıcı kağıt yok',
    0x040002: 'Yazıcı başlık arızası',
    0x040003: 'Yazıcı iletişim hatası',
    0x040004: 'Yazıcı kağıt sıkışması',

    // Güç kaynağı
    0x050001: 'Düşük batarya voltajı',
    0x050002: 'Yüksek besleme voltajı',
    0x050003: 'Ana güç kaynağı arızası',
    0x050004: 'Yedek batarya arızası',
    0x050005: 'Voltaj regülatörü hatası',

    // Saat / RTC
    0x060001: 'RTC saat arızası',
    0x060002: 'Saat senkronizasyon hatası',
    0x060003: 'RTC pil gerilimi düşük',
    0x060004: 'Zaman damgası tutarsızlığı',

    // Veri belleği
    0x070001: 'Veri belleği okuma hatası',
    0x070002: 'Veri belleği yazma hatası',
    0x070003: 'Veri belleği doluluk uyarısı',
    0x070004: 'Veri belleği bütünlük hatası',
    0x070005: 'Flash bellek aşınma eşiği',

    // CAN veriyolu
    0x080001: 'CAN-A veriyolu arızası',
    0x080002: 'CAN-C veriyolu arızası',
    0x080003: 'CAN mesaj zaman aşımı',
    0x080004: 'CAN veri çerçevesi hatası',

    // GNSS
    0x090001: 'GNSS anten bağlantı hatası',
    0x090002: 'GNSS sinyal yok',
    0x090003: 'GNSS konum belirsizlik hatası',

    // Tuş takımı
    0x0A0001: 'Tuş takımı arızası',
    0x0A0002: 'Tuş sıkışma algılandı',

    // Buzzer
    0x0B0001: 'Buzzer devre arızası',

    // Yazılım
    0x0C0001: 'Yazılım bütünlük hatası (CRC)',
    0x0C0002: 'Konfigürasyon verisi hatası',
    0x0C0003: 'Kalibrasyon verisi geçersiz',
    0x0C0004: 'Bootloader bütünlük hatası',

    // Sürücü kartı (uygulama katmanı)
    0x0D0001: 'Sürücü kartı geçersiz',
    0x0D0002: 'Sürücü kartı süresi dolmuş',
    0x0D0003: 'Sürücü kartı kilitli',

    // Asistan kartı
    0x0E0001: 'Asistan kartı geçersiz',
    0x0E0002: 'Asistan kartı süresi dolmuş',

    // Hız girişi
    0xC00001: 'Hız sinyal kaybı',
    0xC00002: 'Hız sinyal gürültüsü',
    0xC00003: 'Hız sınırı aşımı algılama hatası',

    // TCO1
    0xC10001: 'TCO1 mesaj gönderme hatası',
    0xC10002: 'TCO1 veri çerçevesi hatası',
  };
}
