/// İstanbul'un 39 ilçesi ve filtre ekranında kullanılacak yaklaşık merkezleri.
///
/// Merkezler yalnızca haritayı seçilen bölgeye taşımak ve mevcut raporları
/// yaklaşık olarak gruplamak için kullanılır; sınır veya yasal park kuralı
/// verisi değildir.
class IstanbulDistrict {
  const IstanbulDistrict(this.name, this.latitude, this.longitude);

  final String name;
  final double latitude;
  final double longitude;
}

const istanbulDistricts = <IstanbulDistrict>[
  IstanbulDistrict('Adalar', 40.8617, 29.1234),
  IstanbulDistrict('Arnavutköy', 41.1850, 28.7400),
  IstanbulDistrict('Ataşehir', 40.9930, 29.1300),
  IstanbulDistrict('Avcılar', 40.9790, 28.7210),
  IstanbulDistrict('Bağcılar', 41.0390, 28.8560),
  IstanbulDistrict('Bahçelievler', 41.0020, 28.8580),
  IstanbulDistrict('Bakırköy', 40.9810, 28.8720),
  IstanbulDistrict('Başakşehir', 41.0920, 28.8020),
  IstanbulDistrict('Bayrampaşa', 41.0490, 28.9000),
  IstanbulDistrict('Beşiktaş', 41.0430, 29.0050),
  IstanbulDistrict('Beykoz', 41.1270, 29.1020),
  IstanbulDistrict('Beylikdüzü', 40.9900, 28.6500),
  IstanbulDistrict('Beyoğlu', 41.0340, 28.9770),
  IstanbulDistrict('Büyükçekmece', 41.0200, 28.5850),
  IstanbulDistrict('Çatalca', 41.1430, 28.4610),
  IstanbulDistrict('Çekmeköy', 41.0340, 29.1780),
  IstanbulDistrict('Esenler', 41.0430, 28.8760),
  IstanbulDistrict('Esenyurt', 41.0340, 28.6800),
  IstanbulDistrict('Eyüpsultan', 41.0610, 28.9330),
  IstanbulDistrict('Fatih', 41.0120, 28.9500),
  IstanbulDistrict('Gaziosmanpaşa', 41.0740, 28.9120),
  IstanbulDistrict('Güngören', 41.0190, 28.8710),
  IstanbulDistrict('Kadıköy', 40.9900, 29.0300),
  IstanbulDistrict('Kağıthane', 41.0800, 28.9700),
  IstanbulDistrict('Kartal', 40.8990, 29.1900),
  IstanbulDistrict('Küçükçekmece', 41.0000, 28.7800),
  IstanbulDistrict('Maltepe', 40.9350, 29.1350),
  IstanbulDistrict('Pendik', 40.8780, 29.2350),
  IstanbulDistrict('Sancaktepe', 41.0020, 29.2350),
  IstanbulDistrict('Sarıyer', 41.1700, 29.0500),
  IstanbulDistrict('Silivri', 41.0730, 28.2470),
  IstanbulDistrict('Sultanbeyli', 40.9680, 29.2700),
  IstanbulDistrict('Sultangazi', 41.1060, 28.8680),
  IstanbulDistrict('Şile', 41.1750, 29.6120),
  IstanbulDistrict('Şişli', 41.0600, 28.9870),
  IstanbulDistrict('Tuzla', 40.8170, 29.3000),
  IstanbulDistrict('Ümraniye', 41.0250, 29.1150),
  IstanbulDistrict('Üsküdar', 41.0260, 29.0300),
  IstanbulDistrict('Zeytinburnu', 41.0000, 28.9000),
];

const allIstanbulDistrictLabel = 'Tüm ilçeler';
