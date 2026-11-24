USE OtelRezervasyonDB;

DROP PROCEDURE IF EXISTS sp_musait_odalari_listele;
DROP PROCEDURE IF EXISTS sp_konaklama_tutari_hesapla;
DROP PROCEDURE IF EXISTS sp_aylik_doluluk_ve_gelir_raporu;

DELIMITER //

--  Tarih Aralığı ve Oda Tipine Göre Müsait Odalar

CREATE PROCEDURE sp_musait_odalari_listele(
    IN p_giris_tarihi DATE,
    IN p_cikis_tarihi DATE,
    IN p_oda_tipi_id INT
)
BEGIN
    IF p_cikis_tarihi <= p_giris_tarihi THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'HATA: Cikis tarihi giris tarihinden sonra olmalidir.';
    END IF;

    SELECT
        o.id AS oda_id,
        o.oda_numarasi,
        o.kat,
        o.durum AS anlik_durum,
        ot.id AS oda_tipi_id,
        ot.tip_adi,
        ot.kapasite,
        ot.temel_fiyat
    FROM Oda o
    INNER JOIN OdaTipi ot ON o.oda_tipi_id = ot.id
    WHERE o.durum != 'bakimda'
      AND (p_oda_tipi_id IS NULL OR o.oda_tipi_id = p_oda_tipi_id)
      AND NOT EXISTS (
          SELECT 1
          FROM Rezervasyon r
          WHERE r.oda_id = o.id
            AND r.durum IN ('beklemede', 'onayli')
            AND p_giris_tarihi < r.cikis_tarihi
            AND p_cikis_tarihi > r.giris_tarihi
      )
    ORDER BY o.oda_numarasi ASC;
END //


--  Sezon Fiyatı + Ek Hizmetlerle Toplam Tutar Hesaplama

CREATE PROCEDURE sp_konaklama_tutari_hesapla(
    IN p_konaklama_id INT
)
BEGIN
    DECLARE v_var_mi INT DEFAULT 0;
    DECLARE v_oda_tipi_id INT;
    DECLARE v_giris_tarihi DATE;
    DECLARE v_cikis_tarihi DATE;
    DECLARE v_temel_fiyat DECIMAL(10,2);
    DECLARE v_gecerli_gun DATE;
    DECLARE v_gunluk_fiyat DECIMAL(10,2);
    DECLARE v_gece_sayisi INT DEFAULT 0;
    DECLARE v_oda_tutari DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_ek_hizmet_tutari DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_odenen_tutar DECIMAL(10,2) DEFAULT 0.00;

    SELECT COUNT(*) INTO v_var_mi
    FROM Konaklama
    WHERE id = p_konaklama_id;

    IF v_var_mi = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'HATA: Belirtilen konaklama kaydi bulunamadi.';
    END IF;

    SELECT
        o.oda_tipi_id,
        r.giris_tarihi,
        r.cikis_tarihi,
        ot.temel_fiyat
    INTO
        v_oda_tipi_id,
        v_giris_tarihi,
        v_cikis_tarihi,
        v_temel_fiyat
    FROM Konaklama k
    INNER JOIN Rezervasyon r ON k.rezervasyon_id = r.id
    INNER JOIN Oda o ON r.oda_id = o.id
    INNER JOIN OdaTipi ot ON o.oda_tipi_id = ot.id
    WHERE k.id = p_konaklama_id;

    -- Her gece icin sezon fiyati varsa onu, yoksa temel fiyati ekle
    SET v_gecerli_gun = v_giris_tarihi;
    WHILE v_gecerli_gun < v_cikis_tarihi DO
        SELECT COALESCE(
            (
                SELECT sf.gecelik_fiyat
                FROM SezonFiyati sf
                WHERE sf.oda_tipi_id = v_oda_tipi_id
                  AND v_gecerli_gun BETWEEN sf.baslangic_tarihi AND sf.bitis_tarihi
                ORDER BY sf.id DESC
                LIMIT 1
            ),
            v_temel_fiyat
        ) INTO v_gunluk_fiyat;

        SET v_oda_tutari = v_oda_tutari + v_gunluk_fiyat;
        SET v_gece_sayisi = v_gece_sayisi + 1;
        SET v_gecerli_gun = DATE_ADD(v_gecerli_gun, INTERVAL 1 DAY);
    END WHILE;

    -- Ek hizmet toplamini hesapla
    SELECT COALESCE(SUM(kh.adet * eh.birim_fiyat), 0.00)
    INTO v_ek_hizmet_tutari
    FROM KonaklamaHizmeti kh
    INNER JOIN EkHizmet eh ON kh.ek_hizmet_id = eh.id
    WHERE kh.konaklama_id = p_konaklama_id;

    -- Yapilan odemelerin toplamini hesapla
    SELECT COALESCE(SUM(tutar), 0.00)
    INTO v_odenen_tutar
    FROM Odeme
    WHERE konaklama_id = p_konaklama_id;

    SELECT
        p_konaklama_id AS konaklama_id,
        v_gece_sayisi AS gece_sayisi,
        v_oda_tutari AS oda_tutari,
        v_ek_hizmet_tutari AS ek_hizmet_tutari,
        (v_oda_tutari + v_ek_hizmet_tutari) AS toplam_tutar,
        v_odenen_tutar AS odenen_tutar,
        ((v_oda_tutari + v_ek_hizmet_tutari) - v_odenen_tutar) AS kalan_tutar;
END //


-- Aylık Doluluk ve Gelir Raporu

CREATE PROCEDURE sp_aylik_doluluk_ve_gelir_raporu(
    IN p_yil INT,
    IN p_ay INT
)
BEGIN
    DECLARE v_ay_basi DATE;
    DECLARE v_ay_sonu DATE;
    DECLARE v_sonraki_ay_basi DATE;
    DECLARE v_ay_gun_sayisi INT;
    DECLARE v_toplam_oda INT DEFAULT 0;
    DECLARE v_kapasite_oda_gece INT DEFAULT 0;
    DECLARE v_dolu_oda_gece INT DEFAULT 0;
    DECLARE v_rezervasyon_sayisi INT DEFAULT 0;
    DECLARE v_toplam_gelir DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_nakit_gelir DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_kart_gelir DECIMAL(12,2) DEFAULT 0.00;

    IF p_ay < 1 OR p_ay > 12 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'HATA: Ay degeri 1 ile 12 arasinda olmalidir.';
    END IF;

    SET v_ay_basi = STR_TO_DATE(CONCAT(p_yil, '-', LPAD(p_ay, 2, '0'), '-01'), '%Y-%m-%d');
    SET v_ay_sonu = LAST_DAY(v_ay_basi);
    SET v_sonraki_ay_basi = DATE_ADD(v_ay_sonu, INTERVAL 1 DAY);
    SET v_ay_gun_sayisi = DAY(v_ay_sonu);

    SELECT COUNT(*) INTO v_toplam_oda
    FROM Oda
    WHERE durum != 'bakimda';

    SET v_kapasite_oda_gece = v_toplam_oda * v_ay_gun_sayisi;

    SELECT
        COUNT(*),
        COALESCE(
            SUM(
                DATEDIFF(
                    LEAST(cikis_tarihi, v_sonraki_ay_basi),
                    GREATEST(giris_tarihi, v_ay_basi)
                )
            ),
            0
        )
    INTO v_rezervasyon_sayisi, v_dolu_oda_gece
    FROM Rezervasyon
    WHERE durum IN ('onayli', 'tamamlandi')
      AND giris_tarihi < v_sonraki_ay_basi
      AND cikis_tarihi > v_ay_basi;

    SELECT
        COALESCE(SUM(tutar), 0.00),
        COALESCE(SUM(CASE WHEN odeme_turu = 'nakit' THEN tutar ELSE 0.00 END), 0.00),
        COALESCE(SUM(CASE WHEN odeme_turu = 'kart' THEN tutar ELSE 0.00 END), 0.00)
    INTO v_toplam_gelir, v_nakit_gelir, v_kart_gelir
    FROM Odeme
    WHERE YEAR(tarih) = p_yil
      AND MONTH(tarih) = p_ay;

    SELECT
        p_yil AS yil,
        p_ay AS ay,
        v_toplam_oda AS aktif_oda_sayisi,
        v_rezervasyon_sayisi AS rezervasyon_sayisi,
        v_dolu_oda_gece AS dolu_oda_gece,
        v_kapasite_oda_gece AS toplam_kapasite_gece,
        ROUND(COALESCE((v_dolu_oda_gece / NULLIF(v_kapasite_oda_gece, 0)) * 100, 0), 2) AS doluluk_orani_yuzde,
        v_nakit_gelir AS nakit_gelir,
        v_kart_gelir AS kart_gelir,
        v_toplam_gelir AS toplam_gelir;
END //

DELIMITER ;