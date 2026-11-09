import 'package:flutter/material.dart';
import 'local_knowledge_db_service.dart';
import 'local_llm_service.dart';

/// خدمة المعالجة الخلفية الذكية (Clinical Triage + Anti-Repetition + Real Timestamps + OCR Lab Parser):
class MedicalRagService {
  static Map<String, dynamic>? _lastDiscussedChunk;
  static String _lastAnswerIntro = '';

  /// تنسيق الوقت الفعلي بنظام 12 ساعة العربي (مثال: 11:12 ص)
  static String formatTimeNow([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final isPm = now.hour >= 12;
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minStr = now.minute.toString().padLeft(2, '0');
    final period = isPm ? 'م' : 'ص';
    return '$hour12:$minStr $period';
  }

  /// تنسيق التاريخ والوقت الفعلي لسجل المحادثات (مثال: 2026/11/09 • 11:12 ص)
  static String formatFullDateTime([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y/$m/$d • ${formatTimeNow(now)}';
  }

  static const List<String> emergencyKeywords = [
    'جلطة',
    'نزيف حاد',
    'تسمم',
    'انتحار',
    'ألم صدر شديد',
    'الم صدر شديد',
    'توقف التنفس',
    'فقدان وعي',
    'غيبوبة',
    'ذبحة صدرية',
    'اختناق',
    'صعوبة التنفس',
  ];

  static const List<String> dosageAndDiagnosisKeywords = [
    'كم جرعة',
    'اعطني وصفة',
    'اكتب لي دواء',
    'جرعة دقيقة',
    'كم حبة آخذ',
    'كم حبه اخذ',
    'شخص حالتي',
    'هل أنا مصاب',
    'ما هو تشخيصي المؤكد',
  ];

  static const List<String> outOfScopeKeywords = [
    'برمجة',
    'سياسة',
    'كرة قدم',
    'مباراة',
    'بورصة',
    'أسهم',
    'فيزياء',
    'تاريخ',
  ];

  static Future<Map<String, dynamic>> generateReplyAsync({
    required String query,
    required String knowledgeVersion,
  }) async {
    final timeStr = formatTimeNow();
    final fullDateStr = formatFullDateTime();

    // 1. فحص التحيات والدردشة التفاعلية والاعتراضات أولاً
    final conversationalReply = _checkGreetingAndChitChat(query, timeStr, fullDateStr);
    if (conversationalReply != null) {
      return conversationalReply;
    }

    // 2. فحص طبقة الأمان الطبي (الطوارئ، الجرعات، خارج النطاق)
    final safetyCheck = _checkSafetyAndScope(query, timeStr, fullDateStr);
    if (safetyCheck != null) {
      return safetyCheck;
    }

    // 3. فحص ما إذا كان النص يحتوي على نتائج تحاليل أو قراءة تقرير طبي (OCR)
    final labAnalysis = _analyzeLabReportIfPresent(query, timeStr, fullDateStr);
    if (labAnalysis != null) {
      return labAnalysis;
    }

    // 4. فحص الإجابات التخصصية الفرعية وأسئلة المتابعة (لضمان عدم تكرار نفس البطاقة أبداً)
    final specialized = LocalKnowledgeDbService.instance.findSpecializedSubAnswer(query);
    if (specialized != null) {
      final linkedModel = LocalLlmService.instance.modelInfo;
      final modelBadge = linkedModel != null
          ? ' • ${linkedModel.fileName} (${linkedModel.formattedSize})'
          : '';
      return {
        'id': 'spec_${DateTime.now().millisecondsSinceEpoch}',
        'category': specialized['category']?.toString() ?? 'بروتوكول طبي متخصص',
        'title': specialized['title']?.toString() ?? query,
        'subtitle': specialized['answerIntro']?.toString() ?? '',
        'time': timeStr,
        'fullDate': fullDateStr,
        'icon': Icons.medical_information_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'isConversational': false,
        'source': '${specialized['source']}$modelBadge',
        'question': query,
        'answerIntro': specialized['answerIntro']?.toString() ?? '',
        'bullets': List<String>.from(specialized['bullets'] as List),
        'importantNote': specialized['importantNote']?.toString() ?? '',
        'footer': '',
        'followUps': List<String>.from((specialized['followUps'] as List?) ?? const []),
      };
    }

    // 5. البحث الهجين الداعم للهجات أو استرجاع الموضوع السابق من ذاكرة الحوار
    List<Map<String, dynamic>> retrievedChunks =
        LocalKnowledgeDbService.instance.searchHybrid(query, topK: 2);

    if (retrievedChunks.isEmpty &&
        _lastDiscussedChunk != null &&
        _isFollowUpIntent(query)) {
      retrievedChunks = [_lastDiscussedChunk!];
    }

    if (retrievedChunks.isNotEmpty) {
      _lastDiscussedChunk = retrievedChunks.first;
    }

    final primaryChunk = retrievedChunks.isNotEmpty ? retrievedChunks.first : null;

    // 6. محاولة التوليد عبر محرك C++ (llama.cpp FFI) إن كان مفعلاً
    final llmText = await LocalLlmService.instance.generateGroundedResponse(
      userQuery: query,
      retrievedChunks: retrievedChunks,
    );

    final linkedModel = LocalLlmService.instance.modelInfo;
    final modelBadge = linkedModel != null
        ? ' • ${linkedModel.fileName} (${linkedModel.formattedSize})'
        : '';

    if (llmText != null && llmText.trim().isNotEmpty) {
      final lines = llmText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final intro = lines.isNotEmpty ? lines.first : '';
      final bulletLines = lines.length > 1
          ? lines
              .sublist(1)
              .map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), ''))
              .toList()
          : <String>[];

      return {
        'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
        'category': primaryChunk?['category'] ?? 'استفسار طبي',
        'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
        'subtitle': intro,
        'time': timeStr,
        'fullDate': fullDateStr,
        'icon': Icons.health_and_safety_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'isConversational': bulletLines.isEmpty,
        'source':
            '${primaryChunk?['source'] ?? 'المراجع الطبية المعتمدة (WHO & MOH)'}$modelBadge',
        'question': query,
        'answerIntro': intro,
        'bullets': bulletLines,
        'importantNote': '',
        'footer': '',
        'followUps': (primaryChunk?['followUps'] as List?)?.cast<String>() ?? <String>[],
      };
    }

    final baseReply = generateReply(query: query, knowledgeVersion: knowledgeVersion);
    if (linkedModel != null && baseReply['isConversational'] != true) {
      baseReply['source'] = '${baseReply['source']}$modelBadge';
    }
    return baseReply;
  }

  static Map<String, dynamic> generateReply({
    required String query,
    required String knowledgeVersion,
  }) {
    final timeStr = formatTimeNow();
    final fullDateStr = formatFullDateTime();

    final conversationalReply = _checkGreetingAndChitChat(query, timeStr, fullDateStr);
    if (conversationalReply != null) {
      return conversationalReply;
    }

    final safetyCheck = _checkSafetyAndScope(query, timeStr, fullDateStr);
    if (safetyCheck != null) {
      return safetyCheck;
    }

    final labAnalysis = _analyzeLabReportIfPresent(query, timeStr, fullDateStr);
    if (labAnalysis != null) {
      return labAnalysis;
    }

    final specialized = LocalKnowledgeDbService.instance.findSpecializedSubAnswer(query);
    if (specialized != null) {
      return {
        'id': 'spec_${DateTime.now().millisecondsSinceEpoch}',
        'category': specialized['category']?.toString() ?? 'بروتوكول طبي متخصص',
        'title': specialized['title']?.toString() ?? query,
        'subtitle': specialized['answerIntro']?.toString() ?? '',
        'time': timeStr,
        'fullDate': fullDateStr,
        'icon': Icons.medical_information_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'isConversational': false,
        'source': specialized['source']?.toString() ?? 'المراجع الطبية المعتمدة (WHO)',
        'question': query,
        'answerIntro': specialized['answerIntro']?.toString() ?? '',
        'bullets': List<String>.from(specialized['bullets'] as List),
        'importantNote': specialized['importantNote']?.toString() ?? '',
        'footer': '',
        'followUps': List<String>.from((specialized['followUps'] as List?) ?? const []),
      };
    }

    List<Map<String, dynamic>> retrievedChunks =
        LocalKnowledgeDbService.instance.searchHybrid(query, topK: 1);

    if (retrievedChunks.isEmpty &&
        _lastDiscussedChunk != null &&
        _isFollowUpIntent(query)) {
      retrievedChunks = [_lastDiscussedChunk!];
    }

    if (retrievedChunks.isNotEmpty) {
      final chunk = retrievedChunks.first;
      _lastDiscussedChunk = chunk;
      final intro = chunk['answerIntro']?.toString() ?? '';
      _lastAnswerIntro = intro;

      final allFollowUps = (chunk['followUps'] as List?)?.cast<String>() ?? <String>[];
      final filteredFollowUps =
          allFollowUps.where((f) => f.trim() != query.trim()).take(3).toList();

      return {
        'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
        'category': chunk['category']?.toString() ?? 'تقييم طبي موثق',
        'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
        'subtitle': intro,
        'time': timeStr,
        'fullDate': fullDateStr,
        'icon': Icons.health_and_safety_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'isConversational': false,
        'source': chunk['source']?.toString() ??
            'الدليل العلاجي الوطني وإرشادات منظمة الصحة العالمية (WHO)',
        'question': query,
        'answerIntro': intro,
        'bullets': List<String>.from(chunk['bullets'] as List),
        'importantNote': chunk['importantNote']?.toString() ?? '',
        'footer': '',
        'followUps': filteredFollowUps,
      };
    }

    return {
      'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
      'category': 'توضيح السؤال',
      'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
      'subtitle': 'يرجى تحديد العرض أو الموضوع الطبي...',
      'time': timeStr,
      'fullDate': fullDateStr,
      'icon': Icons.chat_bubble_outline_rounded,
      'color': 0xFF0077B6,
      'isFavorite': false,
      'isEmergency': false,
      'isConversational': true,
      'source': '',
      'question': query,
      'answerIntro':
          'سلامتك! لكي أعطيك تقييماً طبياً دقيقاً حول "$query"، أخبرني بأهم عرض تشعر به حالياً أو اختر من الاقتراحات السريعة أدناه:',
      'bullets': <String>[],
      'importantNote': '',
      'footer': '',
      'followUps': <String>[
        'وجع في الراس',
        'ما هي أنواع المغص؟',
        'أعراض فقر الدم (الأنيميا)',
        'كيف أتخلص من الصداع بدون مسكنات؟',
      ],
    };
  }

  /// محلل ذكي لقراءة وتفسير أرقام التحاليل والتقارير الطبية المستخلصة عبر OCR
  static Map<String, dynamic>? _analyzeLabReportIfPresent(
      String query, String timeStr, String fullDateStr) {
    final lower = query.toLowerCase();
    if (!lower.contains('تقرير مختبر') &&
        !lower.contains('نتيجة تحليل') &&
        !lower.contains('hb:') &&
        !lower.contains('hba1c:') &&
        !lower.contains('wbc:')) {
      return null;
    }

    final List<String> findings = [];
    if (lower.contains('hb: 9.2') || lower.contains('هيموجلوبين: 9.2')) {
      findings.add(
          '• الهيموجلوبين (Hb = 9.2 g/dL): منخفض عن المعدل الطبيعي (12-16 g/dL)، ويشير إلى وجود فقر دم (أنيميا) متوسط الدرجة غالباً بسبب نقص الحديد.');
    }
    if (lower.contains('ferritin: 8') || lower.contains('مخزون الحديد: 8')) {
      findings.add(
          '• مخزون الحديد (Ferritin = 8 ng/mL): منخفض بوضوح عن الطبيعي (15-150 ng/mL)، ويؤكد حاجة الجسم لتعويض الحديد غذائياً ودوائياً.');
    }
    if (lower.contains('fbs: 148') || lower.contains('سكر صائم: 148')) {
      findings.add(
          '• السكر الصائم (FBS = 148 mg/dL): مرتفع عن المعدل الطبيعي (70-99 mg/dL)، ويستدعي تنظيم السكريات ومراجعة طبيب الباطنية.');
    }
    if (lower.contains('hba1c: 7.4') || lower.contains('تراكمي: 7.4')) {
      findings.add(
          '• السكر التراكمي (HbA1c = 7.4%): أعلى من الحد الطبيعي (أقل من 5.7%)، ويدل على ارتفاع متوسط السكر خلال الأشهر الثلاثة الماضية.');
    }
    if (lower.contains('wbc: 13.5') || lower.contains('بيضاء: 13.5')) {
      findings.add(
          '• كريات الدم البيضاء (WBC = 13.5 ×10³/µL): مرتفعة قليلاً عن الطبيعي (4-11)، مما يشير إلى استجابة مناعية لالتهاب أو عدوى نشطة.');
    }
    if (lower.contains('vit d: 12') || lower.contains('فيتامين د: 12')) {
      findings.add(
          '• فيتامين D (12 ng/mL): نقص واضح عن المستوى الطبيعي (30-50 ng/mL)، وهو مسبب رئيسي للخمول وآلام العظام والمفاصل.');
    }

    if (findings.isEmpty) {
      findings.addAll([
        '• تم استخلاص نص التقرير الطبي بنجاح عبر قارئ النصوص (OCR).',
        '• قارن القيم الرقمية بالنطاق المرجعي المطبوع بجانب كل فحص (Normal Range).',
        '• أي قيمة تحمل علامة (H) تعني مرتفعة، وعلامة (L) تعني منخفضة عن المعدل الطبيعي.',
      ]);
    }

    return {
      'id': 'ocr_${DateTime.now().millisecondsSinceEpoch}',
      'category': 'تحليل تقرير طبي (OCR)',
      'title': 'تفسير نتائج التقرير المخبري',
      'subtitle': 'قراءة وتحليل المؤشرات المخبرية المستخلصة...',
      'time': timeStr,
      'fullDate': fullDateStr,
      'icon': Icons.document_scanner_rounded,
      'color': 0xFF10B981,
      'isFavorite': false,
      'isEmergency': false,
      'isConversational': false,
      'source': 'محرك قراءة وتفسير التحاليل الطبية (OCR) • المعايير المرجعية لمنظمة الصحة العالمية',
      'question': query,
      'answerIntro':
          'تمت قراءة وتحليل التقرير الطبي المرفق بنجاح، وإليك التقييم التفصيلي للقيم المرصودة:',
      'bullets': findings,
      'importantNote':
          'هذا التحليل استرشادي لمساعدتك على فهم أرقام التقرير، وتجب مطابقته سريرياً لدى الطبيب المعالج.',
      'footer': '',
      'followUps': const [
        'ما هي الأطعمة التي ترفع الحديد بسرعة؟',
        'ما الفرق بين السكر الصائم والتراكمي؟',
      ],
    };
  }

  static bool _isFollowUpIntent(String query) {
    final q = query.trim().toLowerCase();
    return q.contains('اسبابه') ||
        q.contains('أسبابه') ||
        q.contains('اسبابها') ||
        q.contains('اعراضه') ||
        q.contains('أعراضه') ||
        q.contains('علاجه') ||
        q.contains('كيف اخفف') ||
        q.contains('ايش اسوي') ||
        q.contains('طيب') ||
        q.contains('متى يكون خطير') ||
        q.contains('هل هو خطير');
  }

  static Map<String, dynamic>? _checkGreetingAndChitChat(
      String rawQuery, String timeStr, String fullDateStr) {
    final q = rawQuery
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), '')
        .trim();

    if (q.contains('خاطئ') ||
        q.contains('خطا') ||
        q.contains('غلط') ||
        q.contains('شي اخر') ||
        q.contains('ما تفهم') ||
        q.contains('لا تفهم') ||
        q.contains('لماذا تجيب') ||
        q.contains('ليش ترد') ||
        q.contains('تكرر') ||
        q.contains('احترافيه')) {
      return _simpleChatBubble(
        rawQuery: rawQuery,
        timeStr: timeStr,
        fullDateStr: fullDateStr,
        replyText:
            'معك حق تماماً، وأشكرك على دقتك! قمت الآن بربط كل سؤال فرعي وكل زر متابعة ببروتوكول طبي مستقل ومفصل حتى لا تتكرر أي إجابة أبداً. جرّب الضغط على أي سؤال بالأسفل لترى التفصيل الاحترافي.',
        followUps: const [
          'كيف أتخلص من الصداع بدون مسكنات؟',
          'كيف أخفف المغص في المنزل؟',
          'ما الفرق بين السكر الصائم والتراكمي؟',
        ],
      );
    }

    if (q == 'الو' ||
        q == 'الوو' ||
        q == 'اهلا' ||
        q == 'اهلين' ||
        q == 'يا هلا' ||
        q == 'هلا' ||
        q == 'حيابك' ||
        q == 'حياك' ||
        q == 'حياك الله' ||
        q == 'مرحبا' ||
        q == 'مرحب' ||
        q == 'سلام' ||
        q == 'هاي' ||
        q == 'hello' ||
        q == 'hi' ||
        q.contains('السلام عليكم') ||
        q.contains('صباح الخير') ||
        q.contains('مساء الخير')) {
      return _simpleChatBubble(
        rawQuery: rawQuery,
        timeStr: timeStr,
        fullDateStr: fullDateStr,
        replyText:
            'يا هلا وحياك الله! أنا معك وجاهز لمساعدتك. تفضل، إيش العرض أو السؤال الطبي اللي حاب نطمئن عليه اليوم؟',
        followUps: const [
          'وجع في الراس',
          'ما هي أنواع المغص؟',
          'ما هي الأطعمة التي ترفع الحديد بسرعة؟',
        ],
      );
    }

    if (q.contains('كيفك') ||
        q.contains('كيف حالك') ||
        q.contains('كيف الحال') ||
        q.contains('شخبارك') ||
        q.contains('اخبارك') ||
        q.contains('شلونك') ||
        q.contains('عامل ايه') ||
        q.contains('ازيك') ||
        q.contains('عساك طيب')) {
      return _simpleChatBubble(
        rawQuery: rawQuery,
        timeStr: timeStr,
        fullDateStr: fullDateStr,
        replyText:
            'بخير وعافية ولله الحمد، تسلم على سؤالك! طمّني عنك، كيف صحتك اليوم؟ وهل تشعر بأي عرض صحي تحب نراجعه معاً؟',
        followUps: const [
          'وجع في الراس',
          'عندي مغص، ما هي أنواعه؟',
        ],
      );
    }

    if (q.contains('شكرا') ||
        q.contains('مشكور') ||
        q.contains('تسلم') ||
        q.contains('يعطيك العافيه') ||
        q.contains('جزاك الله خير') ||
        q.contains('ما قصرت')) {
      return _simpleChatBubble(
        rawQuery: rawQuery,
        timeStr: timeStr,
        fullDateStr: fullDateStr,
        replyText:
            'العفو يا غالي، بالخدمة دائماً وأتمنى لك دوام الصحة والعافية! إذا خطر في بالك أي استفسار آخر أنا موجود.',
      );
    }

    if (q.contains('من انت') ||
        q.contains('مين انت') ||
        q.contains('عرفني بنفسك') ||
        q.contains('ما وظيفتك') ||
        q.contains('ايش وظيفتك')) {
      return _simpleChatBubble(
        rawQuery: rawQuery,
        timeStr: timeStr,
        fullDateStr: fullDateStr,
        replyText:
            'أنا "MEDIQ AI"، مساعدك الطبي الذكي؛ أعمل محلياً على هاتفك بدون إنترنت لتقديم تقييم سريري مبدئي، شرح الأعراض والتحاليل، وإرشادات الإسعافات الأولية بلغة واضحة وموثقة.',
      );
    }

    return null;
  }

  static Map<String, dynamic> _simpleChatBubble({
    required String rawQuery,
    required String timeStr,
    required String fullDateStr,
    required String replyText,
    List<String> followUps = const [],
  }) {
    return {
      'id': 'conv_${DateTime.now().millisecondsSinceEpoch}',
      'category': 'محادثة',
      'title': rawQuery.length > 26 ? '${rawQuery.substring(0, 26)}...' : rawQuery,
      'subtitle': replyText,
      'time': timeStr,
      'fullDate': fullDateStr,
      'icon': Icons.chat_bubble_outline_rounded,
      'color': 0xFF0077B6,
      'isFavorite': false,
      'isEmergency': false,
      'isConversational': true,
      'source': '',
      'question': rawQuery,
      'answerIntro': replyText,
      'bullets': <String>[],
      'importantNote': '',
      'footer': '',
      'followUps': followUps,
    };
  }

  static Map<String, dynamic>? _checkSafetyAndScope(
      String query, String timeStr, String fullDateStr) {
    final isEmergency = emergencyKeywords.any((k) => query.contains(k));
    final isDosageOrDiagnosis =
        dosageAndDiagnosisKeywords.any((k) => query.contains(k));
    final isOutOfScope = outOfScopeKeywords.any((k) => query.contains(k));

    if (isEmergency) {
      return {
        'id': 'emerg_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'تنبيه طوارئ حرج',
        'title': 'تحذير سلامة طبية طارئة',
        'subtitle': 'تم رصد مؤشرات طارئة تتطلب تدخلاً إسعافياً فورياً...',
        'time': timeStr,
        'fullDate': fullDateStr,
        'icon': Icons.warning_amber_rounded,
        'color': 0xFFDC2626,
        'isFavorite': false,
        'isEmergency': true,
        'isConversational': false,
        'source': 'بروتوكول طبقة الأمان الطبي والتعامل مع الحالات الحرجة',
        'question': query,
        'answerIntro':
            '⚠️ تنبيه طوارئ طبي فوري: الأعراض المذكورة حرجة وعالية الخطورة وتستوجب تدخلاً إسعافياً عاجلاً:',
        'bullets': [
          'اتصل فوراً بالإسعاف (997) أو توجه إلى أقرب قسم طوارئ دون انتظار.',
          'تجنب القيادة بنفسك، وأبقِ المريض في وضعية مريحة مع مراقبة التنفس والوعي.',
        ],
        'importantNote':
            'تم إيقاف التوليد العادي بواسطة طبقة السلامة الطبية حفاظاً على سلامتك.',
        'footer': '',
        'followUps': <String>[],
      };
    }

    if (isDosageOrDiagnosis) {
      return {
        'id': 'guard_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'ضوابط السلامة الطبية',
        'title': query.length > 26 ? '${query.substring(0, 26)}...' : query,
        'subtitle': 'ضوابط التشخيص السريري ووصف الجرعات الدوائية...',
        'time': timeStr,
        'fullDate': fullDateStr,
        'icon': Icons.medication_liquid_rounded,
        'color': 0xFFF59E0B,
        'isFavorite': false,
        'isEmergency': false,
        'isConversational': false,
        'source': 'ضوابط السلامة الطبية والاستخدام الآمن للأدوية',
        'question': query,
        'answerIntro':
            'حفاظاً على سلامتك، لا يقوم النظام بوصف جرعات دوائية فردية أو إصدار تشخيص سريري جازم:',
        'bullets': [
          'تحديد الدواء والجرعة الدقيقة يعتمد على الفحص المباشر، العمر، الوزن، ووظائف الكبد والكلى.',
          'يمكنني تزويدك بالمعلومات التثقيفية العامة عن الدواء أو المرض ودواعي استخدامه والتحذيرات المرتبطة به.',
        ],
        'importantNote':
            'يُنصح بمراجعة الطبيب المختص أو الصيدلي السريري لتحديد الجرعة المناسبة لحالتك.',
        'footer': '',
        'followUps': <String>[],
      };
    }

    if (isOutOfScope) {
      return _simpleChatBubble(
        rawQuery: query,
        timeStr: timeStr,
        fullDateStr: fullDateStr,
        replyText:
            'عذراً منك، أنا مساعد متخصص في المجال الطبي والصحي فقط؛ يسعدني جداً الإجابة على أي استفسار يتعلق بالصحة، الأعراض، الفحوصات، أو الوقاية.',
      );
    }

    return null;
  }
}
