# Otel Rezervasyon ve Konaklama Yönetim Sistemi

## Proje Hakkında
Bu proje, bir otel işletmesinin rezervasyon, konaklama, ödeme ve personel süreçlerini yöneten kapsamlı bir otomasyon sistemidir. 

## Geliştiriciler
*   Fatih Muhammed Çelik 445852

## Kullanılan Teknolojiler
*   **Backend:** Java Spring Boot
*   **Veritabanı:** MySQL


## Veritabanı Mimarisi (ER Diyagramı)
Aşağıdaki şema, sistemde kullanılacak temel 13 tabloyu ve aralarındaki ilişkileri göstermektedir:

```mermaid
erDiagram
    Kullanici {
        int id PK
        string kullanici_adi
        string sifre
        string rol
    }
    Misafir {
        int id PK
        string ad
        string soyad
        string tc_pasaport
    }
    Personel {
        int id PK
        string ad
        string gorev
    }
    OdaTipi {
        int id PK
        string tip_adi
        int kapasite
    }
    Oda {
        int id PK
        int oda_numarasi
        string durum
        int oda_tipi_id FK
    }
    SezonFiyati {
        int id PK
        int oda_tipi_id FK
        date baslangic
        decimal fiyat
    }
    Rezervasyon {
        int id PK
        int misafir_id FK
        int oda_id FK
        string durum
    }
    Konaklama {
        int id PK
        int rezervasyon_id FK
        datetime giris
        int islem_yapan_id FK
    }
    EkHizmet {
        int id PK
        string hizmet_adi
        decimal fiyat
    }
    KonaklamaHizmeti {
        int id PK
        int konaklama_id FK
        int ek_hizmet_id FK
    }
    Odeme {
        int id PK
        int konaklama_id FK
        decimal tutar
    }
    TemizlikKaydi {
        int id PK
        int oda_id FK
        int personel_id FK
        string durum
    }
    IslemLog {
        int id PK
        string tablo_adi
        string islem
    }

    Misafir ||--o{ Rezervasyon : "yapar"
    Kullanici |o--o| Misafir : "misafir hesabi"
    Kullanici |o--o| Personel : "personel hesabi"
    OdaTipi ||--o{ Oda : "sahiptir"
    OdaTipi ||--o{ SezonFiyati : "fiyatlandirilir"
    Oda ||--o{ Rezervasyon : "rezerve edilir"
    Oda ||--o{ TemizlikKaydi : "temizlenir"
    Personel ||--o{ TemizlikKaydi : "yapar"
    Personel ||--o{ Konaklama : "check-in/out yapar"
    Rezervasyon ||--o| Konaklama : "donusur"
    Konaklama ||--o{ Odeme : "odenir"
    Konaklama ||--o{ KonaklamaHizmeti : "alir"
    EkHizmet ||--o{ KonaklamaHizmeti : "eklenir"
