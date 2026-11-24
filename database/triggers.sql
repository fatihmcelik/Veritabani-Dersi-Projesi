USE OtelRezervasyonDB;

-- Tekrar çalıştırıldığında hata vermemesi için eski trigger'ları temizle
DROP TRIGGER IF EXISTS trg_rezervasyon_cakisma_insert;
DROP TRIGGER IF EXISTS trg_rezervasyon_cakisma_update;
DROP TRIGGER IF EXISTS trg_konaklama_checkin;
DROP TRIGGER IF EXISTS trg_konaklama_checkout;
DROP TRIGGER IF EXISTS trg_rezervasyon_log_update;
DROP TRIGGER IF EXISTS trg_odeme_log_insert;

DELIMITER //


-- 1. TRIGGER GRUBU: Çakışan Rezervasyon ve Tarih Kontrolü

CREATE TRIGGER trg_rezervasyon_cakisma_insert
BEFORE INSERT ON Rezervasyon
FOR EACH ROW
BEGIN
    DECLARE v_cakisma_sayisi INT DEFAULT 0;
    DECLARE v_oda_durum VARCHAR(20);

    IF NEW.cikis_tarihi <= NEW.giris_tarihi THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'HATA: Cikis tarihi giris tarihinden sonra olmalidir.';
    END IF;

    SELECT durum INTO v_oda_durum
    FROM Oda
    WHERE id = NEW.oda_id;

    IF v_oda_durum = 'bakimda' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'HATA: Bakimda olan bir odaya rezervasyon yapilamaz.';
    END IF;

    IF NEW.durum IN ('beklemede', 'onayli') THEN
        SELECT COUNT(*) INTO v_cakisma_sayisi
        FROM Rezervasyon
        WHERE oda_id = NEW.oda_id
          AND durum IN ('beklemede', 'onayli')
          AND NEW.giris_tarihi < cikis_tarihi
          AND NEW.cikis_tarihi > giris_tarihi;

        IF v_cakisma_sayisi > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'HATA: Secilen oda bu tarih araliginda zaten rezerve edilmis!';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_rezervasyon_cakisma_update
BEFORE UPDATE ON Rezervasyon
FOR EACH ROW
BEGIN
    DECLARE v_cakisma_sayisi INT DEFAULT 0;

    IF NEW.cikis_tarihi <= NEW.giris_tarihi THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'HATA: Cikis tarihi giris tarihinden sonra olmalidir.';
    END IF;

    IF NEW.durum IN ('beklemede', 'onayli') THEN
        SELECT COUNT(*) INTO v_cakisma_sayisi
        FROM Rezervasyon
        WHERE oda_id = NEW.oda_id
          AND id != NEW.id
          AND durum IN ('beklemede', 'onayli')
          AND NEW.giris_tarihi < cikis_tarihi
          AND NEW.cikis_tarihi > giris_tarihi;

        IF v_cakisma_sayisi > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'HATA: Guncellenen tarih araligi baska bir rezervasyonla cakisiyor!';
        END IF;
    END IF;
END //


-- 2. TRIGGER GRUBU: Check-in / Check-out Oda Durumu Güncelleme

CREATE TRIGGER trg_konaklama_checkin
AFTER INSERT ON Konaklama
FOR EACH ROW
BEGIN
    DECLARE v_oda_id INT;

    SELECT oda_id INTO v_oda_id
    FROM Rezervasyon
    WHERE id = NEW.rezervasyon_id;

    IF NEW.gercek_giris_zamani IS NOT NULL AND NEW.gercek_cikis_zamani IS NULL THEN
        UPDATE Oda
        SET durum = 'dolu'
        WHERE id = v_oda_id;
    END IF;
END //

CREATE TRIGGER trg_konaklama_checkout
AFTER UPDATE ON Konaklama
FOR EACH ROW
BEGIN
    DECLARE v_oda_id INT;

    IF OLD.gercek_cikis_zamani IS NULL AND NEW.gercek_cikis_zamani IS NOT NULL THEN
        SELECT oda_id INTO v_oda_id
        FROM Rezervasyon
        WHERE id = NEW.rezervasyon_id;

        UPDATE Oda
        SET durum = 'temizlikte'
        WHERE id = v_oda_id;

        UPDATE Rezervasyon
        SET durum = 'tamamlandi'
        WHERE id = NEW.rezervasyon_id;
    END IF;
END //


-- 3. TRIGGER GRUBU: Rezervasyon ve Ödeme Değişikliklerini Loglama

CREATE TRIGGER trg_rezervasyon_log_update
AFTER UPDATE ON Rezervasyon
FOR EACH ROW
BEGIN
    INSERT INTO IslemLog (tablo_adi, islem_tipi, eski_veri, yeni_veri)
    VALUES (
        'Rezervasyon',
        'UPDATE',
        CONCAT('id=', OLD.id, ', oda_id=', OLD.oda_id, ', giris=', OLD.giris_tarihi, ', cikis=', OLD.cikis_tarihi, ', durum=', OLD.durum),
        CONCAT('id=', NEW.id, ', oda_id=', NEW.oda_id, ', giris=', NEW.giris_tarihi, ', cikis=', NEW.cikis_tarihi, ', durum=', NEW.durum)
    );
END //

CREATE TRIGGER trg_odeme_log_insert
AFTER INSERT ON Odeme
FOR EACH ROW
BEGIN
    INSERT INTO IslemLog (tablo_adi, islem_tipi, eski_veri, yeni_veri)
    VALUES (
        'Odeme',
        'INSERT',
        NULL,
        CONCAT('odeme_id=', NEW.id, ', konaklama_id=', NEW.konaklama_id, ', tutar=', NEW.tutar, ', odeme_turu=', NEW.odeme_turu)
    );
END //

DELIMITER ;