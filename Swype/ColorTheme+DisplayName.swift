import Foundation

extension ColorTheme {
    var displayName: String { displayName(in: .english) }

    // Order matches AppLanguage.allCases: en, tr, es, fr, it, pt, de, ja, ko, zh, ar, ru
    func displayName(in language: AppLanguage) -> String {
        let names: [String]
        switch self {
        case .blue:    names = ["Blue","Mavi","Azul","Bleu","Blu","Azul","Blau","ブルー","블루","蓝色","أزرق","Синий"]
        case .purple:  names = ["Purple","Mor","Morado","Violet","Viola","Roxo","Lila","パープル","퍼플","紫色","بنفسجي","Фиолетовый"]
        case .mint:    names = ["Mint","Nane","Menta","Menthe","Menta","Menta","Minze","ミント","민트","薄荷","نعناعي","Мятный"]
        case .orange:  names = ["Orange","Turuncu","Naranja","Orange","Arancione","Laranja","Orange","オレンジ","오렌지","橙色","برتقالي","Оранжевый"]
        case .pink:    names = ["Pink","Pembe","Rosa","Rose","Rosa","Rosa","Pink","ピンク","핑크","粉色","وردي","Розовый"]
        case .red:     names = ["Red","Kırmızı","Rojo","Rouge","Rosso","Vermelho","Rot","レッド","레드","红色","أحمر","Красный"]
        case .gold:    names = ["Gold","Altın","Dorado","Doré","Oro","Dourado","Gold","ゴールド","골드","金色","ذهبي","Золотой"]
        case .cyan:    names = ["Cyan","Turkuaz","Cian","Cyan","Ciano","Ciano","Türkis","シアン","시안","青色","سماوي","Бирюзовый"]
        case .indigo:  names = ["Indigo","İndigo","Índigo","Indigo","Indaco","Índigo","Indigo","インディゴ","인디고","靛蓝","نيلي","Индиго"]
        case .emerald: names = ["Emerald","Zümrüt","Esmeralda","Émeraude","Smeraldo","Esmeralda","Smaragd","エメラルド","에메랄드","翡翠绿","زمردي","Изумрудный"]
        }
        let i = AppLanguage.allCases.firstIndex(of: language) ?? 0
        return i < names.count ? names[i] : names[0]
    }
}
