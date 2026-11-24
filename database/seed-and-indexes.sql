USE OtelRezervasyonDB;


--   Tekrar çalıştırmada veri çakışmasını önler

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE IslemLog;
TRUNCATE TABLE TemizlikKaydi;
TRUNCATE TABLE Odeme;
TRUNCATE TABLE KonaklamaHizmeti;
TRUNCATE TABLE EkHizmet;
TRUNCATE TABLE Konaklama;
TRUNCATE TABLE Rezervasyon;
TRUNCATE TABLE SezonFiyati;
TRUNCATE TABLE Oda;
TRUNCATE TABLE OdaTipi;
TRUNCATE TABLE Personel;
TRUNCATE TABLE Misafir;
TRUNCATE TABLE Kullanici;
SET FOREIGN_KEY_CHECKS = 1;


--  TEMEL TANIM TABLOLARI (OdaTipi, Oda, SezonFiyati, EkHizmet)

INSERT INTO OdaTipi (tip_adi, kapasite, aciklama, temel_fiyat) VALUES
('Standart', 2, 'Cift kisilik veya iki tek kisilik yatakli, sehir manzarali standart oda', 1800.00),
('Deluxe', 2, 'Balkonlu, deniz manzarali genis deluxe oda', 2600.00),
('Aile Odasi', 4, 'Iki baglantili odali, cocuklu aileler icin genis oda', 3500.00),
('Suit', 3, 'Oturma alanli, jakuzili ve panoramik manzarali lux suit', 5200.00);

-- 4 Kat x 5 Oda = 20 Oda (Başlangıçta 'bos'; check-in/out trigger'ları güncelleyecek)
INSERT INTO Oda (oda_numarasi, kat, oda_tipi_id, durum) VALUES
(101, 1, 1, 'bos'), (102, 1, 1, 'bos'), (103, 1, 1, 'bos'), (104, 1, 1, 'bos'), (105, 1, 1, 'bos'),
(201, 2, 2, 'bos'), (202, 2, 2, 'bos'), (203, 2, 2, 'bos'), (204, 2, 2, 'bos'), (205, 2, 2, 'bos'),
(301, 3, 3, 'bos'), (302, 3, 3, 'bos'), (303, 3, 3, 'bos'), (304, 3, 3, 'bos'), (305, 3, 3, 'bos'),
(401, 4, 4, 'bos'), (402, 4, 4, 'bos'), (403, 4, 4, 'bos'), (404, 4, 4, 'bos'), (405, 4, 4, 'bos');

-- Yaz ve Kış/Yılbaşı Sezon Fiyatları
INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat) VALUES
(1, '2026-06-01', '2026-09-15', 2400.00),
(2, '2026-06-01', '2026-09-15', 3400.00),
(3, '2026-06-01', '2026-09-15', 4500.00),
(4, '2026-06-01', '2026-09-15', 6800.00),
(1, '2026-11-15', '2027-01-15', 2100.00),
(2, '2026-11-15', '2027-01-15', 3000.00),
(3, '2026-11-15', '2027-01-15', 4000.00),
(4, '2026-11-15', '2027-01-15', 6000.00);

INSERT INTO EkHizmet (hizmet_adi, birim_fiyat) VALUES
('Acik Bufe Kahvalti', 350.00),
('Spa ve Masaj Paketi', 1200.00),
('Havaalani VIP Transfer', 900.00),
('Minibar Kullanimi', 250.00),
('Camasirhane ve Utu', 300.00),
('Gec Cikis (Late Check-out)', 750.00);


--  PERSONEL VE SİSTEM KULLANICILARI

INSERT INTO Kullanici (kullanici_adi, sifre, rol) VALUES
('admin', '123456', 'yonetici'),
('resepsiyon1', '123456', 'resepsiyon'),
('resepsiyon2', '123456', 'resepsiyon');

INSERT INTO Personel (kullanici_id, ad, soyad, gorev, ise_giris_tarihi) VALUES
(1, 'Ahmet', 'Yilmaz', 'yonetici', '2022-03-01'),
(2, 'Zeynep', 'Kaya', 'resepsiyon', '2023-06-15'),
(3, 'Emre', 'Demir', 'resepsiyon', '2024-01-10'),
(NULL, 'Fatma', 'Celik', 'kat_gorevlisi', '2023-04-20'),
(NULL, 'Hasan', 'Sahin', 'kat_gorevlisi', '2023-09-05'),
(NULL, 'Merve', 'Aydin', 'kat_gorevlisi', '2024-05-12');


--  50 MİSAFİR VE 200 REZERVASYON ÜRETİMİ (Geçici Seed Prosedürü)

DROP PROCEDURE IF EXISTS sp_seed_otel_verileri;

DELIMITER //
CREATE PROCEDURE sp_seed_otel_verileri()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE v_kullanici_id INT;
    DECLARE v_oda INT DEFAULT 1;
    DECLARE v_slot INT DEFAULT 1;
    DECLARE v_misafir INT;
    DECLARE v_personel INT;
    DECLARE v_kisi INT;
    DECLARE v_giris DATE;
    DECLARE v_cikis DATE;
    DECLARE v_durum VARCHAR(20);
    DECLARE v_rez_id INT;
    DECLARE v_konaklama_id INT;
    DECLARE v_temel_fiyat DECIMAL(10,2);
    DECLARE v_odeme_tutar DECIMAL(10,2);

    -- 50 Misafir ve Kullanıcı Hesabı Oluştur
    WHILE i <= 50 DO
        INSERT INTO Kullanici (kullanici_adi, sifre, rol)
        VALUES (CONCAT('misafir', i), '123456', 'misafir');

        SET v_kullanici_id = LAST_INSERT_ID();

        INSERT INTO Misafir (kullanici_id, ad, soyad, tc_pasaport, telefon, e_posta, dogum_tarihi)
        VALUES (
            v_kullanici_id,
            ELT(((i - 1) % 10) + 1, 'Ali', 'Ayse', 'Mehmet', 'Elif', 'Can', 'Selin', 'Burak', 'Deniz', 'Murat', 'Ece'),
            ELT(((i - 1) % 7) + 1, 'Yildiz', 'Ozturk', 'Arslan', 'Dogan', 'Kilic', 'Aslan', 'Cetin'),
            CONCAT('10000000', LPAD(i, 3, '0')),
            CONCAT('0532000', LPAD(i, 4, '0')),
            CONCAT('misafir', i, '@ornekmail.com'),
            DATE_SUB('1998-01-01', INTERVAL (i * 120) DAY)
        );

        SET i = i + 1;
    END WHILE;

    -- 20 Oda x 10 Çakışmasız Tarih Dilimi = 200 Rezervasyon
    WHILE v_oda <= 20 DO
        SELECT ot.temel_fiyat INTO v_temel_fiyat
        FROM Oda o
        INNER JOIN OdaTipi ot ON o.oda_tipi_id = ot.id
        WHERE o.id = v_oda;

        SET v_slot = 1;
        WHILE v_slot <= 10 DO
            SET v_misafir = ((v_oda * 7 + v_slot * 3) % 50) + 1;
            SET v_personel = IF((v_oda + v_slot) % 2 = 0, 2, 3);
            SET v_kisi = CASE WHEN v_oda <= 10 THEN 2 WHEN v_oda <= 15 THEN 3 ELSE 2 END;

            IF v_slot = 1 THEN
                SET v_giris = DATE_SUB(CURDATE(), INTERVAL 180 DAY);
                SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 177 DAY);
                SET v_durum = 'tamamlandi';
            ELSEIF v_slot = 2 THEN
                SET v_giris = DATE_SUB(CURDATE(), INTERVAL 150 DAY);
                SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 146 DAY);
                SET v_durum = 'tamamlandi';
            ELSEIF v_slot = 3 THEN
                SET v_giris = DATE_SUB(CURDATE(), INTERVAL 120 DAY);
                SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 117 DAY);
                SET v_durum = 'tamamlandi';
            ELSEIF v_slot = 4 THEN
                SET v_giris = DATE_SUB(CURDATE(), INTERVAL 90 DAY);
                SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 86 DAY);
                SET v_durum = 'tamamlandi';
            ELSEIF v_slot = 5 THEN
                SET v_giris = DATE_SUB(CURDATE(), INTERVAL 60 DAY);
                SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 57 DAY);
                SET v_durum = 'tamamlandi';
            ELSEIF v_slot = 6 THEN
                SET v_giris = DATE_SUB(CURDATE(), INTERVAL 30 DAY);
                SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 26 DAY);
                SET v_durum = 'tamamlandi';
            ELSEIF v_slot = 7 THEN
                SET v_giris = DATE_SUB(CURDATE(), INTERVAL 15 DAY);
                SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 12 DAY);
                SET v_durum = IF(v_oda <= 15, 'tamamlandi', 'iptal');
            ELSEIF v_slot = 8 THEN
                IF v_oda BETWEEN 1 AND 5 THEN
                    -- Bugün çıkış yapacak aktif konaklamalar
                    SET v_giris = DATE_SUB(CURDATE(), INTERVAL 3 DAY);
                    SET v_cikis = CURDATE();
                    SET v_durum = 'onayli';
                ELSEIF v_oda BETWEEN 6 AND 10 THEN
                    -- Halen otelde konaklayanlar
                    SET v_giris = DATE_SUB(CURDATE(), INTERVAL 2 DAY);
                    SET v_cikis = DATE_ADD(CURDATE(), INTERVAL 2 DAY);
                    SET v_durum = 'onayli';
                ELSEIF v_oda BETWEEN 11 AND 15 THEN
                    -- Bugün giriş yapacak misafirler
                    SET v_giris = CURDATE();
                    SET v_cikis = DATE_ADD(CURDATE(), INTERVAL 3 DAY);
                    SET v_durum = 'onayli';
                ELSEIF v_oda BETWEEN 16 AND 19 THEN
                    -- Dün çıkış yapanlar (trigger odayı 'temizlikte' yapacak)
                    SET v_giris = DATE_SUB(CURDATE(), INTERVAL 5 DAY);
                    SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 1 DAY);
                    SET v_durum = 'onayli';
                ELSE
                    -- Oda 20 (bakıma alınacak)
                    SET v_giris = DATE_SUB(CURDATE(), INTERVAL 8 DAY);
                    SET v_cikis = DATE_SUB(CURDATE(), INTERVAL 6 DAY);
                    SET v_durum = 'iptal';
                END IF;
            ELSEIF v_slot = 9 THEN
                SET v_giris = DATE_ADD(CURDATE(), INTERVAL 10 DAY);
                SET v_cikis = DATE_ADD(CURDATE(), INTERVAL 14 DAY);
                SET v_durum = IF(v_oda = 20, 'iptal', IF(v_oda % 2 = 0, 'onayli', 'beklemede'));
            ELSE
                SET v_giris = DATE_ADD(CURDATE(), INTERVAL 25 DAY);
                SET v_cikis = DATE_ADD(CURDATE(), INTERVAL 28 DAY);
                SET v_durum = IF(v_oda = 20, 'iptal', IF(v_oda % 2 = 0, 'beklemede', 'onayli'));
            END IF;

            INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum)
            VALUES (v_misafir, v_oda, v_giris, v_cikis, v_kisi, v_durum);

            SET v_rez_id = LAST_INSERT_ID();

            -- Geçmiş tamamlanmış konaklamalar + ek hizmet + ödeme
            IF v_slot <= 7 AND v_durum = 'tamamlandi' THEN
                INSERT INTO Konaklama (rezervasyon_id, gercek_giris_zamani, gercek_cikis_zamani, islem_yapan_personel_id)
                VALUES (v_rez_id, CONCAT(v_giris, ' 14:00:00'), CONCAT(v_cikis, ' 11:00:00'), v_personel);

                SET v_konaklama_id = LAST_INSERT_ID();

                INSERT INTO KonaklamaHizmeti (konaklama_id, ek_hizmet_id, adet, tarih)
                VALUES (v_konaklama_id, 1, v_kisi, CONCAT(DATE_ADD(v_giris, INTERVAL 1 DAY), ' 09:00:00'));

                IF (v_oda + v_slot) % 3 = 0 THEN
                    INSERT INTO KonaklamaHizmeti (konaklama_id, ek_hizmet_id, adet, tarih)
                    VALUES (v_konaklama_id, 4, 2, CONCAT(DATE_ADD(v_giris, INTERVAL 1 DAY), ' 21:00:00'));
                END IF;

                SET v_odeme_tutar = (DATEDIFF(v_cikis, v_giris) * v_temel_fiyat) + (v_kisi * 350.00);
                INSERT INTO Odeme (konaklama_id, tutar, odeme_turu, tarih)
                VALUES (v_konaklama_id, v_odeme_tutar, IF((v_oda + v_slot) % 3 = 0, 'nakit', 'kart'), CONCAT(v_cikis, ' 11:15:00'));

            -- Şu an otelde olanlar (trg_konaklama_checkin odayı 'dolu' yapar)
            ELSEIF v_slot = 8 AND v_oda BETWEEN 1 AND 10 THEN
                INSERT INTO Konaklama (rezervasyon_id, gercek_giris_zamani, gercek_cikis_zamani, islem_yapan_personel_id)
                VALUES (v_rez_id, CONCAT(v_giris, ' 14:00:00'), NULL, v_personel);

                SET v_konaklama_id = LAST_INSERT_ID();

                INSERT INTO KonaklamaHizmeti (konaklama_id, ek_hizmet_id, adet, tarih)
                VALUES (v_konaklama_id, 2, 1, CONCAT(CURDATE(), ' 10:00:00'));

            -- Dün çıkış yapanlar (trg_konaklama_checkout odayı 'temizlikte', rezervasyonu 'tamamlandi' yapar ve loglar)
            ELSEIF v_slot = 8 AND v_oda BETWEEN 16 AND 19 THEN
                INSERT INTO Konaklama (rezervasyon_id, gercek_giris_zamani, gercek_cikis_zamani, islem_yapan_personel_id)
                VALUES (v_rez_id, CONCAT(v_giris, ' 14:00:00'), NULL, v_personel);

                SET v_konaklama_id = LAST_INSERT_ID();

                UPDATE Konaklama
                SET gercek_cikis_zamani = CONCAT(v_cikis, ' 11:30:00')
                WHERE id = v_konaklama_id;

                INSERT INTO KonaklamaHizmeti (konaklama_id, ek_hizmet_id, adet, tarih)
                VALUES (v_konaklama_id, 1, v_kisi, CONCAT(v_cikis, ' 08:30:00'));

                SET v_odeme_tutar = (DATEDIFF(v_cikis, v_giris) * v_temel_fiyat) + (v_kisi * 350.00);
                INSERT INTO Odeme (konaklama_id, tutar, odeme_turu, tarih)
                VALUES (v_konaklama_id, v_odeme_tutar, 'kart', CONCAT(v_cikis, ' 11:35:00'));
            END IF;

            SET v_slot = v_slot + 1;
        END WHILE;

        -- Her oda için geçmiş temizlik kaydı ekle
        INSERT INTO TemizlikKaydi (oda_id, personel_id, tarih, durum)
        VALUES (v_oda, 4 + (v_oda % 3), DATE_SUB(NOW(), INTERVAL (v_oda + 1) DAY), 'tamamlandi');

        -- Temizlikte olan odalar için bekleyen görev ekle
        IF v_oda BETWEEN 16 AND 19 THEN
            INSERT INTO TemizlikKaydi (oda_id, personel_id, tarih, durum)
            VALUES (v_oda, 4 + (v_oda % 3), NOW(), 'bekliyor');
        END IF;

        SET v_oda = v_oda + 1;
    END WHILE;

    -- 405 numaralı odayı bakım durumuna çek (4 oda durumunun tamamını test etmek için)
    UPDATE Oda SET durum = 'bakimda' WHERE oda_numarasi = 405;
END //
DELIMITER ;

CALL sp_seed_otel_verileri();
DROP PROCEDURE IF EXISTS sp_seed_otel_verileri;


-- PERFORMANS İNDEKSLERİ (7 Bileşik İndeks)

CREATE INDEX idx_rezervasyon_oda_durum_tarih ON Rezervasyon (oda_id, durum, giris_tarihi, cikis_tarihi);
CREATE INDEX idx_rezervasyon_giris_cikis     ON Rezervasyon (giris_tarihi, cikis_tarihi, durum);
CREATE INDEX idx_rezervasyon_misafir         ON Rezervasyon (misafir_id, durum);
CREATE INDEX idx_oda_tipi_durum              ON Oda (oda_tipi_id, durum);
CREATE INDEX idx_sezonfiyati_tip_tarih       ON SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi);
CREATE INDEX idx_odeme_tarih_tur             ON Odeme (tarih, odeme_turu);
CREATE INDEX idx_temizlik_oda_durum_tarih    ON TemizlikKaydi (oda_id, durum, tarih);