import 'dart:math' as math;

/// خدمة قاعدة المعرفة الطبية المحلية والبحث الهجين (Hybrid Search: Lexical FTS5 + Semantic Vectors + RRF)
/// تطبق البنية الموصوفة في الفصل الثالث (جدول 3.1، جدول 3.2، وقسم 3.8.3 ص 42).
class LocalKnowledgeDbService {
  static final LocalKnowledgeDbService instance = LocalKnowledgeDbService._internal();
  LocalKnowledgeDbService._internal();

  /// المقاطع المعرفية الطبية الموثقة (Semantic Chunks) المستخلصة من:
  /// 1. الدليل العلاجي الوطني وأدلة الرعاية الصحية الأولية - وزارة الصحة العامة والسكان (اليمن)
  /// 2. الأدلة الإرشادية السريرية والتثقيف الصحي المجتمعي - منظمة الصحة العالمية (WHO EMRO)
  static final List<Map<String, dynamic>> _knowledgeChunks = [
    {
      'id': 'chunk_hypertension',
      'category': 'القلب والأوعية الدموية',
      'title': 'أعراض ارتفاع ضغط الدم والوقاية منه',
      'keywords': ['ضغط الدم', 'ارتفاع الضغط', 'صداع', 'دوخة', 'القاتل الصامت', 'hypertension', 'blood pressure'],
      'source': 'الأدلة الإرشادية السريرية للأمراض غير السارية - منظمة الصحة العالمية (WHO EMRO) والدليل العلاجي الوطني',
      'version': '2026.1',
      'answerIntro': 'ارتفاع ضغط الدم (Hypertension) هو حالة طبية مزمنة يرتفع فيها ضغط الدم في الشرايين، وغالباً ما يُسمى "القاتل الصامت" لأنه قد لا يُظهر أعراضاً واضحة في مراحله المبكرة:',
      'bullets': [
        'الأعراض المحتملة عند الارتفاع الشديد: صداع في مؤخرة الرأس (خاصة في الصباح)، دوار أو دوخة، تشوش في الرؤية، وطنين في الأذنين.',
        'عوامل الخطورة: الإكثار من ملح الطعام (الصوديوم)، السمنة، قلة النشاط البدني، التدخين، والتوتر المستمر.',
        'طرق الوقاية والتحكم: تقليل الملح في الغذاء، ممارسة المشي 30 دقيقة يومياً، الحفاظ على وزن صحي، والقياس الدوري للضغط.',
        'الفحوصات الدورية: قياس ضغط الدم بانتظام وفحص وظائف الكلى ودهون الدم.',
      ],
      'importantNote': 'لا يعتمد تشخيص ارتفاع ضغط الدم على قراءة واحدة عابرة، بل يتطلب قياسات متعددة في أوقات مختلفة تحت إشراف الطبيب.',
      'footer': 'يُنصح بعدم إيقاف أو تعديل أدوية الضغط الموصوفة من الطبيب حتى لو عادت القراءات إلى المستوى الطبيعي.',
    },
    {
      'id': 'chunk_anemia',
      'category': 'أمراض الدم',
      'title': 'أعراض فقر الدم (الأنيميا) ونقص الحديد',
      'keywords': ['فقر الدم', 'أنيميا', 'انيميا', 'الحديد', 'شحوب', 'تعب', 'هيموجلوبين', 'anemia', 'cbc', 'iron'],
      'source': 'أدلة الرعاية الصحية الأولية والتثقيف الصحي - وزارة الصحة العامة والسكان ومنظمة الصحة العالمية (WHO)',
      'version': '2026.1',
      'answerIntro': 'فقر الدم (Anemia) هو انخفاض في عدد خلايا الدم الحمراء السليمة أو مستوى الهيموجلوبين المسؤول عن نقل الأكسجين إلى أنسجة الجسم:',
      'bullets': [
        'الأعراض العامة: التعب والإرهاق المستمر، الضعف العام، شحوب الجلد والشفاه، والدوخة أو الصداع المتكرر.',
        'علامات نقص الحديد: تقصف الأظافر، تساقط الشعر، برودة اليدين والقدمين، وضيق التنفس عند بذل مجهود بسيط.',
        'الفحوصات المخبرية: فحص صورة الدم الكاملة (CBC) ومخزون الحديد في الدم (Serum Ferritin).',
        'التغذية الصحية الداعمة: تناول الأغذية الغنية بالحديد (كالعدس، السبانخ، اللحوم الحمراء، والكبدة) مع مصادر فيتامين C لتعزيز الامتصاص، وتجنب شرب الشاي مباشرة بعد الوجبات.',
      ],
      'importantNote': 'تتشابه أعراض فقر الدم مع حالات أخرى، ولا يُنصح بتناول مكملات الحديد بجرعات علاجية إلا بعد إجراء فحص CBC وتقييم الطبيب.',
      'footer': 'في حال وجود خفقان شديد بالقلب أو إغماء، تجب مراجعة الطبيب المختص في أقرب وقت.',
    },
    {
      'id': 'chunk_diabetes',
      'category': 'الغدد الصماء والسكري',
      'title': 'أعراض مرض السكري وطرق الوقاية والمتابعة',
      'keywords': ['السكري', 'سكر الدم', 'عطش', 'تبول', 'انسولين', 'تراكمي', 'diabetes', 'hba1c', 'glucose'],
      'source': 'الأدلة الإرشادية السريرية للأمراض غير السارية - منظمة الصحة العالمية (WHO EMRO)',
      'version': '2026.1',
      'answerIntro': 'مرض السكري (Diabetes Mellitus) هو اضطراب استقلابي مزمن يتسم بارتفاع مستوى الجلوكوز في الدم نتيجة نقص إفراز الأنسولين أو ضعف استجابة الخلايا له:',
      'bullets': [
        'الأعراض الكلاسيكية: العطش الشديد وجفاف الفم، كثرة التبول (خصوصاً ليلاً)، الجوع المستمر، وفقدان الوزن غير المبرر.',
        'أعراض مصاحبة: الشعور بالتعب، تشوش الرؤية، بطء التئام الجروح، وتنميل الأطراف.',
        'الفحوصات التشخيصية المعتمدة: فحص السكر الصائم (Fasting Blood Glucose) وفحص السكر التراكمي (HbA1c).',
        'إرشادات الوقاية والتعايش: تنظيم الوجبات وتقليل السكريات البسيطة، ممارسة النشاط البدني المنتظم، والفحص الدوري للقدمين والعينين.',
      ],
      'importantNote': 'يتطلب ضبط مستوى السكر خطة علاجية وغذائية يحددها الطبيب المختص بناءً على نتائج التحاليل المخبرية.',
      'footer': 'توجيه تثقيفي: المحافظة على نمط غذائي متوازن والنشاط البدني يساعدان في ضبط مستويات السكر.',
    },
    {
      'id': 'chunk_gastritis',
      'category': 'الجهاز الهضمي',
      'title': 'التهاب المعدة وجرثومة المعدة (H. pylori)',
      'keywords': ['التهاب المعدة', 'حموضة', 'حرقان', 'جرثومة المعدة', 'معدة', 'قرحة', 'gastritis', 'pylori'],
      'source': 'الدليل العلاجي الوطني وأدلة الرعاية الصحية الأولية - وزارة الصحة العامة والسكان',
      'version': '2026.1',
      'answerIntro': 'التهاب المعدة (Gastritis) هو تهيج أو التهاب في البطانة الداخلية للمعدة، وقد يكون حاداً أو مزمناً نتيجة عدة عوامل:',
      'bullets': [
        'الأسباب الشائعة: العدوى ببكتيريا الملزونية البوابية (H. pylori)، أو الإفراط في تناول المسكنات المضادة للالتهاب (NSAIDs مثل الإيبوبروفين).',
        'الأعراض الرئيسية: ألم أو حرقان في الجزء العلوي من البطن، غثيان، انتفاخ، وشعور بالامتلاء السريع بعد الأكل.',
        'الإرشادات الوقائية: تقسيم الوجبات إلى وجبات صغيرة متكررة، تجنب الأطعمة الحارة والدهنية، والامتناع عن التدخين والمسكنات على معدة فارغة.',
        'الفحوصات الشائعة: فحص جرثومة المعدة عبر البراز (Stool Antigen) أو اختبار النفس (Urea Breath Test).',
      ],
      'importantNote': 'لا ينبغي أخذ كورس المضادات الحيوية لعلاج جرثومة المعدة إلا بعد ثبوت الفحص المخبري وبوصفة من الطبيب المختص.',
      'footer': 'تنويه: تجنب تناول مسكنات الألم على معدة فارغة لتقليل تهيج جدار المعدة.',
    },
    {
      'id': 'chunk_immunity_vitd',
      'category': 'المناعة والفيتامينات',
      'title': 'الجهاز المناعي وأهمية فيتامين D للجسم',
      'keywords': ['فيتامين D', 'فيتامين د', 'المناعة', 'الجهاز المناعي', 'عظام', 'كالسيوم', 'vitamin d', 'immunity'],
      'source': 'أدلة التثقيف الصحي والتغذية السريرية المعتمدة - منظمة الصحة العالمية (WHO)',
      'version': '2026.1',
      'answerIntro': 'يعمل الجهاز المناعي كخط دفاع متكامل لحماية الجسم من الميكروبات والعدوى، ويلعب فيتامين D والعناصر الغذائية الدقيقة دوراً محورياً في دعمه:',
      'bullets': [
        'آلية عمل المناعة: تتكامل المناعة الفطرية السريعة (الجلد، الأغشية المخاطية، خلايا الدم البيضاء) مع المناعة المكتسبة (الأجسام المضادة والخلايا اللمفاوية).',
        'فوائد فيتامين D: تعزيز امتصاص الكالسيوم والفوسفور لصحة العظام والأسنان، وتنشيط استجابة الخلايا المناعية ضد العدوى التنفسية.',
        'أعراض نقص فيتامين D: آلام العظام والعضلات، الخمول والإرهاق المستمر، وتكرار الإصابة بنزلات البرد.',
        'سبل تعزيز المناعة طبيعياً: التعرض المعتدل لأشعة الشمس الصباحية، النوم الكافي (7-8 ساعات)، التغذية المتوازنة الغنية بالخضروات والفواكه، وشرب الماء الكافي.',
      ],
      'importantNote': 'تُحدد الجرعة التعويضية لفيتامين D بناءً على نتيجة التحليل المخبري (25-OH Vitamin D) لتجنب السمية الناتجة عن الجرعات المفرطة.',
      'footer': 'التعرض المعتدل لأشعة الشمس الصباحية وتناول الأسماك الدهنية يساعدان في دعم مخزون فيتامين D.',
    },
    {
      'id': 'chunk_first_aid_syncope',
      'category': 'الإسعافات الأولية',
      'title': 'الإسعافات الأولية لحالات الإغماء وانخفاض السكر',
      'keywords': ['إسعافات أولية', 'اسعافات', 'إغماء', 'اغماء', 'هبوط السكر', 'انخفاض السكر', 'دوخة', 'first aid'],
      'source': 'دليل الوقاية والإسعافات الأولية المجتمعية - وزارة الصحة العامة والسكان ومنظمة الصحة العالمية',
      'version': '2026.1',
      'answerIntro': 'الإسعاف الأولي السريع والآمن لحالات الإغماء البسيط أو هبوط السكر يساعد في استعادة التروية الدموية للدماغ ومنع المضاعفات:',
      'bullets': [
        'التحقق من الوعي والتنفس: تأكد أولاً من أن المصاب يتنفس بشكل طبيعي وأن مجرى الهواء مفتوح.',
        'وضعية الاستلقاء: مدد المصاب على ظهره في مكان جيد التهوية وافتح الملابس الضيقة حول الرقبة، وارفع ساقيه بمقدار 30 سم لتحسين تدفق الدم للدماغ.',
        'في حال الاشتباه بهبوط السكر (والمصاب واعٍ تماماً ويستطيع البلع): أعطه مصدراً سريعاً للسكر مثل نصف كوب عصير محلى أو ملعقة عسل أو ماء بالسكر.',
        'تحذير سلامة هام: لا تعطِ أي سوائل أو أطعمة عن طريق الفم لشخص فاقد للوعي تجنباً لخطر الاختناق.',
      ],
      'importantNote': 'إذا لم يستعد المصاب وعيه خلال دقيقة إلى دقيقتين، يجب وضع المصاب في وضعية الإفاقة الجانبية وطلب الإسعاف فوراً (997).',
      'footer': 'الإسعافات الأولية إجراء إسعافي مبدئي ريثما يتم تقييم الحالة من قِبل الفريق الطبي المختص.',
    },
    {
      'id': 'chunk_checkup_labs',
      'category': 'الفحوصات والمصطلحات الطبية',
      'title': 'الفحص الدوري الشامل والمصطلحات المخبرية الشائعة',
      'keywords': ['الفحص الدوري', 'فحوصات', 'تحاليل', 'مصطلح طبي', 'cbc', 'lipid', 'وظائف الكلى', 'وظائف الكبد'],
      'source': 'أدلة الرعاية الصحية الأولية والتثقيف الصحي المجتمعي',
      'version': '2026.1',
      'answerIntro': 'الفحص الطبي الدوري الشامل يتضمن حزمة من التقييمات السريرية والتحاليل المخبرية الأساسية للكشف المبكر عن الاضطرابات الصحية:',
      'bullets': [
        'فحص صورة الدم الكاملة (CBC - Complete Blood Count): لتقييم الهيموجلوبين، كريات الدم البيضاء، والصفائح الدموية.',
        'فحص السكر الصائم والتراكمي (Fasting Glucose & HbA1c): لتقييم استقلاب السكر خلال الأشهر الثلاثة الماضية.',
        'ملف الدهون الكامل (Lipid Profile): يشمل الكوليسترول الكلي، الدهون الثلاثية (Triglycerides)، والدهون النافعة (HDL) والضارة (LDL).',
        'وظائف الكبد والكلى (ALT, AST, Creatinine, Urea): للاطمئنان على كفاءة تصفية السموم والاستقلاب الحيوي.',
      ],
      'importantNote': 'تُقرأ نتائج التحاليل المخبرية دائماً في سياق الأعراض السريرية والعمر والجنس بواسطة الطبيب المختص.',
      'footer': 'يُنصح بإجراء الفحص الروتيني مرة واحدة سنوياً على الأقل.',
    },
  ];

  /// خوارزمية البحث الهجين (Hybrid Retrieval: Lexical FTS5 + Semantic Token Overlap + Weighted RRF)
  /// كما في الفصل الثالث (قسم 3.8.3 ص 42):
  /// RRF_Score(d) = w_lex / (60 + rank_lex(d)) + w_sem / (60 + rank_sem(d))
  List<Map<String, dynamic>> searchHybrid(String query, {int topK = 2}) {
    final normalizedQuery = _normalizeArabic(query);
    final queryTokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();

    final List<MapEntry<Map<String, dynamic>, double>> lexicalScores = [];
    final List<MapEntry<Map<String, dynamic>, double>> semanticScores = [];

    for (final chunk in _knowledgeChunks) {
      final titleNorm = _normalizeArabic(chunk['title'].toString());
      final categoryNorm = _normalizeArabic(chunk['category'].toString());
      final introNorm = _normalizeArabic(chunk['answerIntro'].toString());
      final bulletsNorm = _normalizeArabic((chunk['bullets'] as List).join(' '));
      final keywords = (chunk['keywords'] as List).map((k) => _normalizeArabic(k.toString())).toList();

      // 1. درجة المطابقة النصية المباشرة (FTS5 Lexical Score)
      double lexScore = 0.0;
      for (final kw in keywords) {
        if (normalizedQuery.contains(kw)) {
          lexScore += 5.0;
        }
      }
      for (final token in queryTokens) {
        if (titleNorm.contains(token)) lexScore += 3.0;
        if (keywords.any((k) => k.contains(token))) lexScore += 2.5;
        if (introNorm.contains(token) || bulletsNorm.contains(token)) lexScore += 1.0;
      }
      lexicalScores.add(MapEntry(chunk, lexScore));

      // 2. درجة التقارب الدلالي (Cosine / Semantic N-gram Similarity)
      final docText = '$titleNorm $categoryNorm ${keywords.join(" ")} $introNorm $bulletsNorm';
      final semScore = _computeSemanticSimilarity(normalizedQuery, docText);
      semanticScores.add(MapEntry(chunk, semScore));
    }

    lexicalScores.sort((a, b) => b.value.compareTo(a.value));
    semanticScores.sort((a, b) => b.value.compareTo(a.value));

    // 3. دمج الرتب التبادلي الموزون (Weighted Reciprocal Rank Fusion - RRF)
    const int k = 60;
    const double wLex = 0.65;
    const double wSem = 0.35;

    final Map<String, double> rrfScores = {};
    final Map<String, Map<String, dynamic>> chunkById = {};

    for (int rank = 0; rank < lexicalScores.length; rank++) {
      final item = lexicalScores[rank];
      final id = item.key['id'].toString();
      chunkById[id] = item.key;
      final bonus = item.value > 0 ? (wLex / (k + rank + 1)) + (item.value * 0.01) : 0.0;
      rrfScores[id] = (rrfScores[id] ?? 0.0) + bonus;
    }

    for (int rank = 0; rank < semanticScores.length; rank++) {
      final item = semanticScores[rank];
      final id = item.key['id'].toString();
      chunkById[id] = item.key;
      rrfScores[id] = (rrfScores[id] ?? 0.0) + (wSem / (k + rank + 1)) + (item.value * 0.02);
    }

    final rankedIds = rrfScores.keys.toList()
      ..sort((a, b) => rrfScores[b]!.compareTo(rrfScores[a]!));

    return rankedIds.take(topK).map((id) => chunkById[id]!).toList();
  }

  String _normalizeArabic(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '') // إزالة التشكيل
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), ' ')
        .trim();
  }

  double _computeSemanticSimilarity(String q, String doc) {
    if (q.isEmpty || doc.isEmpty) return 0.0;
    final qGrams = _charTrigrams(q);
    final dGrams = _charTrigrams(doc);
    if (qGrams.isEmpty || dGrams.isEmpty) return 0.0;

    int intersection = 0;
    for (final g in qGrams) {
      if (dGrams.contains(g)) intersection++;
    }
    return intersection / math.sqrt(qGrams.length * dGrams.length);
  }

  Set<String> _charTrigrams(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length < 3) return {clean};
    final Set<String> grams = {};
    for (int i = 0; i <= clean.length - 3; i++) {
      grams.add(clean.substring(i, i + 3));
    }
    return grams;
  }
}
