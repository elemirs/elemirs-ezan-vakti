# Ezan Vakti

macOS menü çubuğunda sonraki ezana ne kadar kaldığını gösteren küçük, internetsiz bir uygulama.

```
Akşama 12 dk
```

Menüye tıklayınca günün vakitleri açılır, sıradaki vakit kalın yazılır. Türkiye'nin 81 ili ve 869 ilçesi seçilebilir.

*A small, offline macOS menu bar app that counts down to the next Islamic call to prayer in Turkey, using the calculation method of the Presidency of Religious Affairs (Diyanet).*

## Özellikler

- Vakitleri cihazda hesaplar; ağ bağlantısı kullanmaz, hiçbir veri göndermez.
- Dock'ta görünmez, yalnızca menü çubuğunda durur.
- Geri sayım Türkiye saatine göre yapılır, Mac başka saat dilimindeyse de doğru kalır.
- Güneş vakti için ezan okunmadığından geri sayımda atlanır, listede görünür.
- İsteğe bağlı olarak oturum açılınca başlar.

## Kurulum

macOS 13 veya üstü ve Swift 5.9 veya üstü (Xcode ya da Command Line Tools) gerekir.

```bash
git clone https://github.com/elemirs/elemirs-ezan-vakti.git
cd elemirs-ezan-vakti
./build.sh install
```

Bu komut uygulamayı derler, `/Applications/Ezan Vakti.app` konumuna kurar ve başlatır. Yalnızca derlemek için `./build.sh` yeterlidir; çıktı `build/` klasörüne yazılır.

Testler:

```bash
swift test
```

## Hesaplama yöntemi

Hesap [`PrayerCalculator.swift`](Sources/EzanCore/PrayerCalculator.swift) dosyasındadır.

| Vakit | Güneş'in konumu | Temkin |
|---|---|---|
| İmsak | ufkun 18° altında | 0 |
| Güneş | üst kenar ufukta (−0,8333°) | −7 dk |
| Öğle | Güneş'in meridyen geçişi | +5 dk |
| İkindi | gölge boyu = öğle gölgesi + cismin boyu | +4 dk |
| Akşam | üst kenar ufukta (−0,8333°) | +7 dk |
| Yatsı | ufkun 17° altında | 0 |

Güneş'in deklinasyonu ve zaman denklemi gün boyu sabit tutulur; o günün 00:00 UT değeri kullanılır. Bu kural Diyanet tarafından yayımlanmış değildir, 2026 vakitlerinden çıkarılmıştır.

### Doğruluk

Hesap, Diyanet'in 2026 vakitleriyle karşılaştırılmıştır:

| Ölçüm | Birebir aynı | En büyük fark |
|---|---|---|
| Ayarda kullanılmayan 48 ilçe, 365 gün | %93–96 | 1 dk |
| 869 ilçenin tamamı, 21 Haziran 2026 | %87–95 | 1 dk |

Bu nedenle bazı günlerde bir vakit Diyanet takviminden 1 dakika farklı olabilir. Ölçüm yalnızca 2026 verisini kapsar. İbadet vakitleri için esas kaynak [Diyanet'in resmî takvimidir](https://namazvakitleri.diyanet.gov.tr/).

Bu proje Diyanet İşleri Başkanlığı ile bağlantılı değildir.

Menüdeki hicri tarih macOS'un Ümmü'l-Kurâ takviminden gelir ve Diyanet'in hicri tarihinden bir gün farklı olabilir.

## Konum verisi

İl ve ilçe listesi `Resources/locations.json` dosyasındadır ve uygulamayla birlikte gelir. Listeyi yeniden üretmek için:

```bash
python3 scripts/fetch-locations.py
```

Bu betik, il ve ilçe adlarını kodlarıyla birlikte ağdan alır; yazım düzeltmelerini ve `scripts/district-coordinates.json` dosyasındaki koordinatları ekler. Ağ bağlantısı yalnızca bu betikte kullanılır, uygulamada kullanılmaz.

## Lisans

Kaynak kod [MIT](LICENSE) lisansıyla sunulur. Koordinat verisinin lisansı ve atıflar için [NOTICE.md](NOTICE.md) dosyasına bakın.
