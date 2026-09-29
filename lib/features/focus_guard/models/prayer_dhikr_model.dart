class PrayerNoteItem {
  final String id;
  final String title;
  final String arabic;
  final String transliteration;
  final String translation;
  final String reference;
  final String note;
  final bool isCustom;
  final bool isFavorite;
  final DateTime createdAt;

  const PrayerNoteItem({
    required this.id,
    required this.title,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.reference,
    this.note = '',
    this.isCustom = false,
    this.isFavorite = false,
    required this.createdAt,
  });

  PrayerNoteItem copyWith({
    String? id,
    String? title,
    String? arabic,
    String? transliteration,
    String? translation,
    String? reference,
    String? note,
    bool? isCustom,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    return PrayerNoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      arabic: arabic ?? this.arabic,
      transliteration: transliteration ?? this.transliteration,
      translation: translation ?? this.translation,
      reference: reference ?? this.reference,
      note: note ?? this.note,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'arabic': arabic,
        'transliteration': transliteration,
        'translation': translation,
        'reference': reference,
        'note': note,
        'isCustom': isCustom,
        'isFavorite': isFavorite,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PrayerNoteItem.fromJson(Map<String, dynamic> json) => PrayerNoteItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        arabic: json['arabic'] as String? ?? '',
        transliteration: json['transliteration'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        note: json['note'] as String? ?? '',
        isCustom: json['isCustom'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  static final List<PrayerNoteItem> curatedPrayers = [
    PrayerNoteItem(
      id: 'prayer_laziness',
      title: 'Seeking Protection from Helplessness & Laziness',
      arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ، وَالْجُبْنِ وَالْهَرَمِ وَالْبُخْلِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، وَمِنْ فِتْنَةِ الْمَحْيَا وَالْمَمَاتِ',
      transliteration: "Allahumma inni a'udhu bika minal-'ajzi wal-kasal, wal-jubni wal-harami wal-bukhl, wa a'udhu bika min 'adhabil-qabr, wa min fitnatil-mahya wal-mamat.",
      translation: 'O Allah, I seek refuge in You from helplessness, laziness, cowardice, senility, and miserliness; and I seek refuge in You from the punishment of the grave, and from the trials of life and death.',
      reference: 'Sahih al-Bukhari 6367 & Sahih Muslim 2706',
      note: 'Recite with sincere presence whenever an impulse to mindlessly scroll or procrastinate on your real goals strikes.',
      createdAt: DateTime(2026, 1, 1),
    ),
    PrayerNoteItem(
      id: 'prayer_anxiety',
      title: 'Relief from Stress, Anxiety & Heavy Thoughts',
      arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
      transliteration: "Allahumma inni a'udhu bika minal-hammi wal-hazan, wal-'ajzi wal-kasal, wal-bukhli wal-jubn, wa dala'id-dayni wa ghalabatir-rijal.",
      translation: 'O Allah, I seek refuge in You from anxiety and sorrow, weakness and laziness, miserliness and cowardice, the burden of debt and from being overpowered by men.',
      reference: 'Sahih al-Bukhari 2893',
      note: 'Social media triggers subtle anxiety and feelings of insufficiency. Ground your soul in divine protection.',
      createdAt: DateTime(2026, 1, 1),
    ),
    PrayerNoteItem(
      id: 'prayer_knowledge',
      title: 'Seeking Beneficial Knowledge & Pure Purpose',
      arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلاً مُتَقَبَّلاً',
      transliteration: "Allahumma inni as'aluka 'ilman nafi'an, wa rizqan tayyiban, wa 'amalan mutaqabbalan.",
      translation: 'O Allah, I ask You for beneficial knowledge, wholesome sustenance, and deeds that are accepted.',
      reference: 'Sunan Ibn Majah 925',
      note: 'Focus only on knowledge that builds your intellect, wealth, and character.',
      createdAt: DateTime(2026, 1, 1),
    ),
    PrayerNoteItem(
      id: 'prayer_steadfast',
      title: 'Steadfastness of the Heart & Willpower',
      arabic: 'يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ',
      transliteration: 'Ya Muqallibal-qulub, thabbit qalbi \'ala deenik.',
      translation: 'O Turner of the hearts, make my heart firm upon Your religion and truth.',
      reference: 'Jami` at-Tirmidhi 2140',
      note: 'Our willpower fluctuates easily. Ask the Controller of hearts to anchor your discipline.',
      createdAt: DateTime(2026, 1, 1),
    ),
    PrayerNoteItem(
      id: 'prayer_ease',
      title: 'Dua for Ease in Tasks & Hard Challenges',
      arabic: 'اللَّهُمَّ لَا سَهْلَ إِلَّا مَا جَعَلْتَهُ سَهْلاً، وَأَنْتَ تَجْعَلُ الْحَزْنَ إِذَا شِئْتَ سَهْلاً',
      transliteration: "Allahumma la sahla illa ma ja'altahu sahla, wa anta taj'alul-hazna idha shi'ta sahla.",
      translation: 'O Allah, there is no ease except that which You make easy, and You can make difficulty easy if You will.',
      reference: 'Sahih Ibn Hibban 974',
      note: 'When work or coding feels overwhelming and tempts you to escape to social media, recite this.',
      createdAt: DateTime(2026, 1, 1),
    ),
    PrayerNoteItem(
      id: 'prayer_yunus',
      title: 'Dua of Prophet Yunus (Overcoming Regret & Darkness)',
      arabic: 'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
      transliteration: 'La ilaha illa Anta subhanaka inni kuntu minaz-zalimeen.',
      translation: 'There is no deity worthy of worship except You; exalted are You. Indeed, I have been of the wrongdoers.',
      reference: 'Surah Al-Anbiya 21:87',
      note: 'Whenever you slip into wasted hours, turn immediately back to Allah without despair.',
      createdAt: DateTime(2026, 1, 1),
    ),
    PrayerNoteItem(
      id: 'prayer_ayat_kursi',
      title: 'Ayat al-Kursi (The Throne Verse – Divine Armor)',
      arabic: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      transliteration: 'Allahu la ilaha illa Huwal-Hayyul-Qayyum. La ta’khudhuhu sinatuw-wa la nawm. Lahu ma fis-samawati wa ma fil-ard...',
      translation: 'Allah! There is no deity except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep...',
      reference: 'Surah Al-Baqarah 2:255',
      note: 'The greatest verse in the Qur’an. Protects the mind, spirit, and environment from heedlessness.',
      createdAt: DateTime(2026, 1, 1),
    ),
    PrayerNoteItem(
      id: 'prayer_istighfar',
      title: 'Chief of Forgiveness (Sayyid al-Istighfar)',
      arabic: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      transliteration: "Allahumma Anta Rabbi la ilaha illa Anta, khalaqtani wa ana 'abduka, wa ana 'ala 'ahdika wa wa'dika mastata'tu, a'udhu bika min sharri ma sana'tu, abu'u laka bini'matika 'alayya, wa abu'u laka bidhanbi faghfir li, fa innahu la yaghfirudh-dhunuba illa Anta.",
      translation: 'O Allah, You are my Lord; there is no god but You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done...',
      reference: 'Sahih al-Bukhari 6306',
      note: 'Whoever recites this with conviction during day or night enters Paradise if they pass away.',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];
}

class DhikrItem {
  final String id;
  final String arabic;
  final String transliteration;
  final String translation;
  final String virtue;
  final int targetCount;
  final int currentCount;
  final int completedCycles;
  final bool isCustom;
  final DateTime createdAt;

  const DhikrItem({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    this.virtue = '',
    this.targetCount = 33,
    this.currentCount = 0,
    this.completedCycles = 0,
    this.isCustom = false,
    required this.createdAt,
  });

  DhikrItem copyWith({
    String? id,
    String? arabic,
    String? transliteration,
    String? translation,
    String? virtue,
    int? targetCount,
    int? currentCount,
    int? completedCycles,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    return DhikrItem(
      id: id ?? this.id,
      arabic: arabic ?? this.arabic,
      transliteration: transliteration ?? this.transliteration,
      translation: translation ?? this.translation,
      virtue: virtue ?? this.virtue,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      completedCycles: completedCycles ?? this.completedCycles,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'arabic': arabic,
        'transliteration': transliteration,
        'translation': translation,
        'virtue': virtue,
        'targetCount': targetCount,
        'currentCount': currentCount,
        'completedCycles': completedCycles,
        'isCustom': isCustom,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DhikrItem.fromJson(Map<String, dynamic> json) => DhikrItem(
        id: json['id'] as String? ?? '',
        arabic: json['arabic'] as String? ?? '',
        transliteration: json['transliteration'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
        virtue: json['virtue'] as String? ?? '',
        targetCount: json['targetCount'] as int? ?? 33,
        currentCount: json['currentCount'] as int? ?? 0,
        completedCycles: json['completedCycles'] as int? ?? 0,
        isCustom: json['isCustom'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  static final List<DhikrItem> curatedDhikr = [
    DhikrItem(
      id: 'dhikr_subhanallah',
      arabic: 'سُبْحَانَ اللَّهِ',
      transliteration: 'SubhanAllah',
      translation: 'Glory be to Allah',
      virtue: 'Light on the tongue, heavy on the Scales of good deeds.',
      targetCount: 33,
      createdAt: DateTime(2026, 1, 1),
    ),
    DhikrItem(
      id: 'dhikr_alhamdulillah',
      arabic: 'الْحَمْدُ لِلَّهِ',
      transliteration: 'Alhamdulillah',
      translation: 'All praise is due to Allah',
      virtue: 'Fills the scale of deeds and brings immense gratitude.',
      targetCount: 33,
      createdAt: DateTime(2026, 1, 1),
    ),
    DhikrItem(
      id: 'dhikr_allahuakbar',
      arabic: 'اللَّهُ أَكْبَرُ',
      transliteration: 'Allahu Akbar',
      translation: 'Allah is the Greatest',
      virtue: 'Nothing in this world or your desires is greater than Allah.',
      targetCount: 34,
      createdAt: DateTime(2026, 1, 1),
    ),
    DhikrItem(
      id: 'dhikr_astaghfirullah',
      arabic: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
      transliteration: "Astaghfirullaha wa atubu ilayh",
      translation: 'I seek forgiveness from Allah and repent to Him',
      virtue: 'Brings relief from grief, opens provisions, and cleanses the heart.',
      targetCount: 100,
      createdAt: DateTime(2026, 1, 1),
    ),
    DhikrItem(
      id: 'dhikr_tahlil',
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illallah',
      translation: 'There is no deity worthy of worship except Allah',
      virtue: 'The best remembrance and key to eternal peace.',
      targetCount: 100,
      createdAt: DateTime(2026, 1, 1),
    ),
    DhikrItem(
      id: 'dhikr_hawqala',
      arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      transliteration: 'La hawla wa la quwwata illa billah',
      translation: 'There is no power nor strength except with Allah',
      virtue: 'A treasure from the treasures of Paradise.',
      targetCount: 33,
      createdAt: DateTime(2026, 1, 1),
    ),
    DhikrItem(
      id: 'dhikr_bihamdihi',
      arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
      transliteration: 'SubhanAllahi wa bihamdihi, SubhanAllahil-Azeem',
      translation: 'Glory be to Allah and His praise, Glory be to Allah the Supreme',
      virtue: 'Beloved to the Most Merciful and heavy on the balance.',
      targetCount: 33,
      createdAt: DateTime(2026, 1, 1),
    ),
    DhikrItem(
      id: 'dhikr_salawat',
      arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ',
      transliteration: "Allahumma salli 'ala Muhammadin wa 'ala ali Muhammad",
      translation: 'O Allah, send blessings upon Muhammad and the family of Muhammad',
      virtue: 'Whoever sends blessings once, Allah sends blessings tenfold.',
      targetCount: 10,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];
}
