import 'package:flutter/material.dart';
import 'local_knowledge_db_service.dart';
import 'local_llm_service.dart';

/// خدمة المعالجة الخلفية الذكية (Smart Conversational RAG + Dialect Engine + Context Memory):
class MedicalRagService {
  /// ذاكرة السياق لتذكر آخر موضوع طبي تمت مناقشته في الجلسة الحالية
  static Map<String, dynamic>? _lastDiscussedChunk;

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
    // 1. فحص التحيات والدردشة التفاعلية والاعتراضات أولاً (رد مختصر وطبيعي بدون قوالب مكررة)
    final conversationalReply = _checkGreetingAndChitChat(query);
    if (conversationalReply != null) {
      return conversationalReply;
    }

    // 2. فحص طبقة الأمان الطبي (الطوارئ، الجرعات، خارج النطاق)
    final safetyCheck = _checkSafetyAndScope(query);
    if (safetyCheck != null) {
      return safetyCheck;
    }

    // 3. البحث الهجين الداعم للهجات، أو استرجاع الموضوع السابق من ذاكرة المحادثة عند الأسئلة المتابعة
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

    // 4. محاولة التوليد عبر محرك C++ (llama.cpp FFI) إن كان مفعلاً
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
        'time': 'الآن',
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
    final conversationalReply = _checkGreetingAndChitChat(query);
    if (conversationalReply != null) {
      return conversationalReply;
    }

    final safetyCheck = _checkSafetyAndScope(query);
    if (safetyCheck != null) {
      return safetyCheck;
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
      return _buildTailoredMedicalAnswer(query, chunk);
    }

    // رد حواري مختصر وذكي عند طرح سؤال غير واضح دون تكرار القوائم الطويلة
    return {
      'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
      'category': 'توضيح السؤال',
      'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
      'subtitle': 'يرجى تحديد العرض أو الموضوع الطبي...',
      'time': 'الآن',
      'icon': Icons.chat_bubble_outline_rounded,
      'color': 0xFF0077B6,
      'isFavorite': false,
      'isEmergency': false,
      'isConversational': true,
      'source': '',
      'question': query,
      'answerIntro':
          'لمعرفة الإجابة الأدق حول "$query"، هل يمكنك توضيح العرض الذي تشعر به أو مكان الألم؟ (مثلاً: مغص البطن، صداع، حمى، حرقان البول، كحة، أو فقر الدم).',
      'bullets': <String>[],
      'importantNote': '',
      'footer': '',
      'followUps': <String>[
        'ما هي أنواع المغص؟',
        'ما هي أعراض فقر الدم؟',
        'أسباب الصداع النصفي',
      ],
    };
  }

  /// تخصيص الإجابة لتكون على قدر السؤال المحدد فقط (أنواع / أسباب / أعراض / تخفيف / علامات خطر) دون تكرار غير ضروري
  static Map<String, dynamic> _buildTailoredMedicalAnswer(
      String query, Map<String, dynamic> chunk) {
    final q = query.trim().toLowerCase();
    final title = chunk['title']?.toString() ?? '';
    String intro = chunk['answerIntro']?.toString() ?? '';
    List<String> selectedBullets = List<String>.from(chunk['bullets'] as List);
    String note = '';

    // 1. إذا سأل المستخدم تحديداً عن "أنواع / انوع"
    if ((q.contains('انواع') || q.contains('أنواع') || q.contains('انوع')) &&
        chunk['types'] != null) {
      selectedBullets = List<String>.from(chunk['types'] as List);
      intro = 'تتفرع $title إلى الأنواع الأساسية التالية:';
    }
    // 2. إذا سأل تحديداً عن "أسباب / ليش / ليه / سبب"
    else if ((q.contains('اسباب') ||
            q.contains('أسباب') ||
            q.contains('سبب') ||
            q.contains('ليش') ||
            q.contains('ليه')) &&
        chunk['causes'] != null) {
      selectedBullets = List<String>.from(chunk['causes'] as List);
      intro = 'تتمثل أبرز الأسباب والعوامل المؤدية إلى ($title) في الآتي:';
    }
    // 3. إذا سأل عن "كيف أخفف / علاج / ايش اسوي / حل / وقاية"
    else if ((q.contains('كيف اخفف') ||
            q.contains('أخفف') ||
            q.contains('علاج') ||
            q.contains('ايش اسوي') ||
            q.contains('شو اعمل') ||
            q.contains('الحل') ||
            q.contains('وقايه') ||
            q.contains('وقاية')) &&
        chunk['relief'] != null) {
      selectedBullets = List<String>.from(chunk['relief'] as List);
      intro = 'لتخفيف الحالة والتعامل الآمن مع ($title) في المنزل، يُنصح بالآتي:';
      note = chunk['importantNote']?.toString() ?? '';
    }
    // 4. إذا سأل عن "متى يكون خطيراً / علامات الخطر / متى اروح للدكتور"
    else if ((q.contains('خطير') ||
            q.contains('خطر') ||
            q.contains('متى اراجع') ||
            q.contains('متى اذهب') ||
            q.contains('طوارئ')) &&
        chunk['redFlags'] != null) {
      selectedBullets = List<String>.from(chunk['redFlags'] as List);
      intro = 'تجب مراجعة الطبيب أو الطوارئ فوراً في حالات ($title) عند ظهور أي من العلامات التحذيرية التالية:';
    }
    // 5. إذا سأل عن "الأعراض / علامات"
    else if ((q.contains('اعراض') || q.contains('أعراض') || q.contains('علامات')) &&
        chunk['symptoms'] != null) {
      selectedBullets = List<String>.from(chunk['symptoms'] as List);
      intro = 'تشمل الأعراض والعلامات المميزة لـ ($title) ما يلي:';
    } else {
      note = chunk['importantNote']?.toString() ?? '';
    }

    final allFollowUps = (chunk['followUps'] as List?)?.cast<String>() ?? <String>[];
    final filteredFollowUps =
        allFollowUps.where((f) => f.trim() != query.trim()).take(3).toList();

    return {
      'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
      'category': chunk['category']?.toString() ?? 'استفسار طبي موثق',
      'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
      'subtitle': intro,
      'time': 'الآن',
      'icon': Icons.health_and_safety_rounded,
      'color': 0xFF0077B6,
      'isFavorite': false,
      'isEmergency': false,
      'isConversational': false,
      'source': chunk['source']?.toString() ??
          'الدليل العلاجي الوطني وإرشادات منظمة الصحة العالمية (WHO)',
      'question': query,
      'answerIntro': intro,
      'bullets': selectedBullets,
      'importantNote': note,
      'footer': '',
      'followUps': filteredFollowUps,
    };
  }

  /// التحقق مما إذا كان السؤال قصيراً ومرتبطاً بالموضوع السابق (سؤال متابعة)
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
        q.contains('هل هو خطير') ||
        q.contains('ما هي اسباب') ||
        q.contains('ما هي اعراض');
  }

  /// الردود الحوارية الذكية (بدون قوالب طبية مكررة وبدون نقاط حشو)
  static Map<String, dynamic>? _checkGreetingAndChitChat(String rawQuery) {
    final q = rawQuery
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), '')
        .trim();

    // 1. الاعتراض أو طلب التصحيح
    if (q.contains('خاطئ') ||
        q.contains('خطا') ||
        q.contains('غلط') ||
        q.contains('شي اخر') ||
        q.contains('ما تفهم') ||
        q.contains('لا تفهم') ||
        q.contains('لماذا تجيب') ||
        q.contains('ليش ترد') ||
        q.contains('تكرر')) {
      return _simpleChatBubble(
        rawQuery: rawQuery,
        replyText:
            'حقك عليّ وأعتذر منك عن أي تكرار أو التباس! لقد قمت بضبط أسلوبي ليكون مباشراً ومختصراً على قدر سؤالك تماماً. تفضل بكتابة سؤالك الطبي بأي لهجة تحبها وسأجيبك مباشرة.',
        followUps: const [
          'ما هي أنواع المغص؟',
          'عندي صداع مستمر، إيش أسبابه؟',
          'كيف أخفف حرقان المعدة؟',
        ],
      );
    }

    // 2. التحيات الهاتفية واليمنية والعربية ("الو"، "يا هلا"، "حيابك"، "مرحبا"، "السلام عليكم")
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
        replyText:
            'يا هلا وحياك الله! أنا معك وجاهز لمساعدتك. تفضل، إيش العرض أو السؤال الطبي اللي حاب تستفسر عنه اليوم؟',
        followUps: const [
          'ما هي أنواع المغص؟',
          'أعراض فقر الدم (الأنيميا)',
          'إسعافات الإغماء وهبوط السكر',
        ],
      );
    }

    // 3. السؤال عن الحال بجميع اللهجات ("كيفك"، "كيف الحال"، "شخبارك"، "شلونك"، "عامل ايه")
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
        replyText:
            'بخير وعافية ولله الحمد، تسلم على سؤالك! طمّني عنك، كيف صحتك اليوم؟ وهل تشكي من أي عرض صحي تحب نطمئن عليه؟',
        followUps: const [
          'عندي مغص، ما هي أنواعه؟',
          'أشعر بدوخة وتعب مستمر',
        ],
      );
    }

    // 4. الشكر والامتنان
    if (q.contains('شكرا') ||
        q.contains('مشكور') ||
        q.contains('تسلم') ||
        q.contains('يعطيك العافيه') ||
        q.contains('جزاك الله خير') ||
        q.contains('ما قصرت')) {
      return _simpleChatBubble(
        rawQuery: rawQuery,
        replyText:
            'العفو يا غالي، بالخدمة دائماً وما تشوف شر إن شاء الله! إذا خطر في بالك أي سؤال ثاني أنا موجود.',
      );
    }

    // 5. السؤال عن الهوية
    if (q.contains('من انت') ||
        q.contains('مين انت') ||
        q.contains('عرفني بنفسك') ||
        q.contains('ما وظيفتك') ||
        q.contains('ايش وظيفتك')) {
      return _simpleChatBubble(
        rawQuery: rawQuery,
        replyText:
            'أنا "MEDIQ AI"، مساعدك الطبي الذكي؛ أعمل معك مباشرة من داخل هاتفك بدون إنترنت لتوضيح الأعراض والأمراض والفحوصات الطبية بلغة واضحة وموثقة.',
      );
    }

    return null;
  }

  /// منشئ فقاعة دردشة نظيفة ومختصرة بدون أي قوالب مكررة
  static Map<String, dynamic> _simpleChatBubble({
    required String rawQuery,
    required String replyText,
    List<String> followUps = const [],
  }) {
    return {
      'id': 'conv_${DateTime.now().millisecondsSinceEpoch}',
      'category': 'محادثة',
      'title': rawQuery.length > 26 ? '${rawQuery.substring(0, 26)}...' : rawQuery,
      'subtitle': replyText,
      'time': 'الآن',
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

  static Map<String, dynamic>? _checkSafetyAndScope(String query) {
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
        'time': 'الآن',
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
        'time': 'الآن',
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
        replyText:
            'عذراً منك، أنا مساعد متخصص في المجال الطبي والصحي فقط؛ يسعدني جداً الإجابة على أي استفسار يتعلق بالصحة، الأعراض، الفحوصات، أو الوقاية.',
      );
    }

    return null;
  }
}
