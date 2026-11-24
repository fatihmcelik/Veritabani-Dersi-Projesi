USE OtelRezervasyonDB;

DROP VIEW IF EXISTS vw_bugunku_giris_cikislar;
DROP VIEW IF EXISTS vw_oda_durum_ve_son_temizlik;


--  Bugün Giriş / Çıkış Yapacak Misafirler Listesi

CREATE VIEW vw_bugunku_giris_cikislar AS
SELECT
    r.id AS rezervasyon_id,
    CASE
        WHEN r.giris_tarihi = CURDATE() THEN 'GIRIS'
        WHEN r.cikis_tarihi = CURDATE() THEN 'CIKIS'
    END AS hareket_tipi,
    CONCAT(m.ad, ' ', m.soyad) AS misafir_ad_soyad,
    m.tc_pasaport,
    m.telefon,
    o.oda_numarasi,
    o.kat,
    ot.tip_adi AS oda_tipi,
    r.giris_tarihi,
    r.cikis_tarihi,
    r.kisi_sayisi,
    r.durum AS rezervasyon_durumu,
    k.gercek_giris_zamani,
    k.gercek_cikis_zamani
FROM Rezervasyon r
INNER JOIN Misafir m ON r.misafir_id = m.id
INNER JOIN Oda o ON r.oda_id = o.id
INNER JOIN OdaTipi ot ON o.oda_tipi_id = ot.id
LEFT JOIN Konaklama k ON r.id = k.rezervasyon_id
WHERE r.durum != 'iptal'
  AND (r.giris_tarihi = CURDATE() OR r.cikis_tarihi = CURDATE())
ORDER BY hareket_tipi ASC, o.oda_numarasi ASC;


--  Oda Bazında Güncel Durum ve Son Temizlik Tarihi

CREATE VIEW vw_oda_durum_ve_son_temizlik AS
SELECT
    o.id AS oda_id,
    o.oda_numarasi,
    o.kat,
    ot.tip_adi AS oda_tipi,
    ot.kapasite,
    ot.temel_fiyat,
    o.durum AS guncel_durum,
    MAX(CASE WHEN tk.durum = 'tamamlandi' THEN tk.tarih END) AS son_temizlik_tarihi,
    (
        SELECT CONCAT(p.ad, ' ', p.soyad)
        FROM TemizlikKaydi tk2
        INNER JOIN Personel p ON tk2.personel_id = p.id
        WHERE tk2.oda_id = o.id
          AND tk2.durum = 'tamamlandi'
        ORDER BY tk2.tarih DESC, tk2.id DESC
        LIMIT 1
    ) AS son_temizleyen_personel,
    SUM(CASE WHEN tk.durum = 'bekliyor' THEN 1 ELSE 0 END) AS bekleyen_temizlik_sayisi
FROM Oda o
INNER JOIN OdaTipi ot ON o.oda_tipi_id = ot.id
LEFT JOIN TemizlikKaydi tk ON o.id = tk.oda_id
GROUP BY o.id, o.oda_numarasi, o.kat, ot.tip_adi, ot.kapasite, ot.temel_fiyat, o.durum
ORDER BY o.oda_numarasi ASC;