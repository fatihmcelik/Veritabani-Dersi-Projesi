-- 1. Veritabanını Oluşturma ve Seçme
CREATE DATABASE IF NOT EXISTS OtelRezervasyonDB;
USE OtelRezervasyonDB;

-- 2. Kullanıcı Tablosu (Kimlik doğrulama ve roller için)
CREATE TABLE Kullanici (
    id INT AUTO_INCREMENT PRIMARY KEY,
    kullanici_adi VARCHAR(50) NOT NULL UNIQUE,
    sifre VARCHAR(255) NOT NULL,
    rol ENUM('misafir', 'resepsiyon', 'yonetici') NOT NULL
);

-- 3. Misafir Tablosu[cite: 1]
CREATE TABLE Misafir (
    id INT AUTO_INCREMENT PRIMARY KEY,
    kullanici_id INT UNIQUE,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    tc_pasaport VARCHAR(20) NOT NULL UNIQUE,
    telefon VARCHAR(15),
    e_posta VARCHAR(100) UNIQUE,
    dogum_tarihi DATE,
    FOREIGN KEY (kullanici_id) REFERENCES Kullanici(id) ON DELETE CASCADE
);

-- 4. Personel Tablosu[cite: 1]
CREATE TABLE Personel (
    id INT AUTO_INCREMENT PRIMARY KEY,
    kullanici_id INT UNIQUE,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    gorev ENUM('resepsiyon', 'kat_gorevlisi', 'yonetici') NOT NULL,
    ise_giris_tarihi DATE NOT NULL,
    FOREIGN KEY (kullanici_id) REFERENCES Kullanici(id) ON DELETE CASCADE
);

-- 5. Oda Tipi Tablosu[cite: 1]
CREATE TABLE OdaTipi (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tip_adi VARCHAR(50) NOT NULL, -- standart, deluxe, suit vb.
    kapasite INT NOT NULL,
    aciklama TEXT,
    temel_fiyat DECIMAL(10,2) NOT NULL
);

-- 6. Oda Tablosu[cite: 1]
CREATE TABLE Oda (
    id INT AUTO_INCREMENT PRIMARY KEY,
    oda_numarasi INT NOT NULL UNIQUE,
    kat INT NOT NULL,
    oda_tipi_id INT NOT NULL,
    durum ENUM('bos', 'dolu', 'temizlikte', 'bakimda') DEFAULT 'bos',
    FOREIGN KEY (oda_tipi_id) REFERENCES OdaTipi(id)
);

-- 7. Sezon Fiyatı Tablosu[cite: 1]
CREATE TABLE SezonFiyati (
    id INT AUTO_INCREMENT PRIMARY KEY,
    oda_tipi_id INT NOT NULL,
    baslangic_tarihi DATE NOT NULL,
    bitis_tarihi DATE NOT NULL,
    gecelik_fiyat DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (oda_tipi_id) REFERENCES OdaTipi(id)
);

-- 8. Rezervasyon Tablosu[cite: 1]
CREATE TABLE Rezervasyon (
    id INT AUTO_INCREMENT PRIMARY KEY,
    misafir_id INT NOT NULL,
    oda_id INT NOT NULL,
    giris_tarihi DATE NOT NULL,
    cikis_tarihi DATE NOT NULL,
    kisi_sayisi INT NOT NULL,
    durum ENUM('beklemede', 'onayli', 'iptal', 'tamamlandi') DEFAULT 'beklemede',
    olusturma_tarihi DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (misafir_id) REFERENCES Misafir(id),
    FOREIGN KEY (oda_id) REFERENCES Oda(id)
);

-- 9. Konaklama Tablosu[cite: 1]
CREATE TABLE Konaklama (
    id INT AUTO_INCREMENT PRIMARY KEY,
    rezervasyon_id INT NOT NULL UNIQUE,
    gercek_giris_zamani DATETIME,
    gercek_cikis_zamani DATETIME,
    islem_yapan_personel_id INT NOT NULL,
    FOREIGN KEY (rezervasyon_id) REFERENCES Rezervasyon(id),
    FOREIGN KEY (islem_yapan_personel_id) REFERENCES Personel(id)
);

-- 10. Ek Hizmet Tablosu[cite: 1]
CREATE TABLE EkHizmet (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hizmet_adi VARCHAR(100) NOT NULL,
    birim_fiyat DECIMAL(10,2) NOT NULL
);

-- 11. Konaklama Hizmeti Tablosu (Ara Tablo)[cite: 1]
CREATE TABLE KonaklamaHizmeti (
    id INT AUTO_INCREMENT PRIMARY KEY,
    konaklama_id INT NOT NULL,
    ek_hizmet_id INT NOT NULL,
    adet INT DEFAULT 1,
    tarih DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (konaklama_id) REFERENCES Konaklama(id),
    FOREIGN KEY (ek_hizmet_id) REFERENCES EkHizmet(id)
);

-- 12. Ödeme Tablosu[cite: 1]
CREATE TABLE Odeme (
    id INT AUTO_INCREMENT PRIMARY KEY,
    konaklama_id INT NOT NULL,
    tutar DECIMAL(10,2) NOT NULL,
    odeme_turu ENUM('nakit', 'kart') NOT NULL,
    tarih DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (konaklama_id) REFERENCES Konaklama(id)
);

-- 13. Temizlik Kaydı Tablosu[cite: 1]
CREATE TABLE TemizlikKaydi (
    id INT AUTO_INCREMENT PRIMARY KEY,
    oda_id INT NOT NULL,
    personel_id INT NOT NULL,
    tarih DATETIME DEFAULT CURRENT_TIMESTAMP,
    durum ENUM('bekliyor', 'tamamlandi') DEFAULT 'bekliyor',
    FOREIGN KEY (oda_id) REFERENCES Oda(id),
    FOREIGN KEY (personel_id) REFERENCES Personel(id)
);

-- 14. İşlem Log Tablosu (Trigger'lar için hazır altyapı)[cite: 1]
CREATE TABLE IslemLog (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tablo_adi VARCHAR(50) NOT NULL,
    islem_tipi VARCHAR(50) NOT NULL,
    islem_zamani DATETIME DEFAULT CURRENT_TIMESTAMP,
    eski_veri TEXT,
    yeni_veri TEXT
);