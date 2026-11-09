import 'package:flutter/material.dart';
import 'local_knowledge_db_service.dart';
import 'local_llm_service.dart';

/// خدمة المعالجة الخلفية المتكاملة (Offline Medical RAG + Conversational Engine + Safety Layer):
class MedicalRagService {
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
    'طبخ',
    'فيزياء',
    'تاريخ',
  ];

  static Future<Map<String, dynamic>> generateReplyAsync({
    required String query,
    required String knowledgeVersion,
  }) async {
    // 1. فحص التحيات والمحادثات الترحيبية الودية أولاً
    final greetingReply = _checkGreetingAndChitChat(query);
    if (greetingReply != null) {
      return greetingReply;
    }

    // 2. فحص طبقة الأمان الطبي (الطوارئ، الجرعات، خارج النطاق)
    final safetyCheck = _checkSafetyAndScope(query);
    if (safetyCheck != null) {
      return safetyCheck;
    }

    // 3. البحث الهجين في قاعدة المعرفة الطبية
    final retrievedChunks = LocalKnowledgeDbService.instance.searchHybrid(query, topK: 2);
    final primaryChunk = retrievedChunks.isNotEmpty ? retrievedChunks.first : null;

    // 4. محاولة التوليد عبر النموذج اللغوي المحلي المربوط من الهاتف إن وجد
    final llmText = await LocalLlmService.instance.generateGroundedResponse(
      userQuery: query,
      retrievedChunks: retrievedChunks,
    );

    final linkedModel = LocalLlmService.instance.modelInfo;
    final modelBadge = linkedModel != null
        ? ' • النموذج النشط: ${linkedModel.fileName} (${linkedModel.formattedSize})'
        : '';

    if (llmText != null && llmText.trim().isNotEmpty) {
      final lines = llmText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final intro = lines.isNotEmpty
          ? lines.first
          : 'بناءً على المراجع الطبية المعتمدة في قاعدة المعرفة المحلية:';
      final bulletLines = lines.length > 1
          ? lines.sublist(1).map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), '')).toList()
          : (primaryChunk?['bullets'] as List<String>? ?? []);

      return {
        'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
        'category': primaryChunk?['category'] ?? 'استفسار طبي موثق',
        'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
        'subtitle': intro,
        'time': 'الآن',
        'icon': Icons.health_and_safety_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'source':
            '${primaryChunk?['source'] ?? 'الدليل العلاجي الوطني وإرشادات منظمة الصحة العالمية (WHO)'}$modelBadge',
        'question': query,
        'answerIntro': intro,
        'bullets': bulletLines,
        'importantNote': primaryChunk?['importantNote'] ??
            'هذه المعلومات مستخرجة محلياً من المراجع الطبية المعتمدة لأغراض التثقيف الصحي العام، ولا تُعد تشخيصاً طبياً نهائياً أو بديلاً عن الطبيب.',
        'footer': primaryChunk?['footer'] ??
            'إذا استمرت الأعراض أو ازدادت حدتها، يُنصح بمراجعة الطبيب المختص لإجراء الفحص السريري.',
      };
    }

    final baseReply = generateReply(query: query, knowledgeVersion: knowledgeVersion);
    if (linkedModel != null) {
      baseReply['source'] = '${baseReply['source']}$modelBadge';
    }
    return baseReply;
  }

  static Map<String, dynamic> generateReply({
    required String query,
    required String knowledgeVersion,
  }) {
    final greetingReply = _checkGreetingAndChitChat(query);
    if (greetingReply != null) {
      return greetingReply;
    }

    final safetyCheck = _checkSafetyAndScope(query);
    if (safetyCheck != null) {
      return safetyCheck;
    }

    final retrievedChunks = LocalKnowledgeDbService.instance.searchHybrid(query, topK: 1);
    if (retrievedChunks.isNotEmpty) {
      final chunk = retrievedChunks.first;
      return {
        'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
        'category': chunk['category']?.toString() ?? 'استفسار طبي موثق',
        'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
        'subtitle': chunk['answerIntro']?.toString() ?? 'معلومات طبية مسترجعة من المراجع المعتمدة...',
        'time': 'الآن',
        'icon': Icons.health_and_safety_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'source': chunk['source']?.toString() ??
            'الدليل العلاجي الوطني وأدلة الرعاية الصحية الأولية وإرشادات منظمة الصحة العالمية (WHO)',
        'question': query,
        'answerIntro': chunk['answerIntro']?.toString() ?? '',
        'bullets': List<String>.from(chunk['bullets'] as List),
        'importantNote': chunk['importantNote']?.toString() ?? '',
        'footer': chunk['footer']?.toString() ?? '',
      };
    }

    // في حال طرح سؤال عام لم يتطابق مع أي مقطع طبي محدد
    return {
      'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
      'category': 'تثقيف طبي عام',
      'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
      'subtitle': 'مساعدك الطبي التثقيفي جاهز لمساعدتك...',
      'time': 'الآن',
      'icon': Icons.health_and_safety_rounded,
      'color': 0xFF0077B6,
      'isFavorite': false,
      'isEmergency': false,
      'source': 'قاعدة المعرفة الطبية المحلية والمراجع المعتمدة (WHO & MOH)',
      'question': query,
      'answerIntro':
          'أهلاً بك! لقد تم استلام استفسارك بخصوص "$query". لتقديم أفضل معلومة طبية موثقة ودقيقة، إليك بعض الإرشادات:',
      'bullets': [
        'يمكنك السؤال عن أمراض محددة مثل: فقر الدم (الأنيميا)، مرض السكري، ارتفاع ضغط الدم، والتهاب المعدة.',
        'يمكنك الاستفسار عن أعراض شائعة مثل: الصداع والشقيقة، آلام البطن والقولون، ونزلات البرد والسعال.',
        'يمكنك طلب معلومات عن الفيتامينات (مثل فيتامين D)، الإسعافات الأولية لحالات الإغماء، أو الفحوصات المخبرية (مثل CBC).',
      ],
      'importantNote':
          'تذكر دائماً أن هذا النظام مخصص للتثقيف الصحي العام، وفي حال وجود أعراض حادة أو طارئة يجب مراجعة الطبيب المختص أو الطوارئ فوراً.',
      'footer': 'تفضل بكتابة سؤالك الطبي بالتفصيل وسأقوم بمساعدتك بكل سرور.',
    };
  }

  /// فحص التحيات والمحادثات الاجتماعية الترحيبية للرد بشكل طبيعي وذكي
  static Map<String, dynamic>? _checkGreetingAndChitChat(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();

    // 0. فهم ملاحظات المستخدم أو الاعتراض على الإجابة أو طلب التصحيح والتوضيح
    final isCritiqueOrCorrection = q.contains('خاطئ') ||
        q.contains('خطأ') ||
        q.contains('غلط') ||
        q.contains('بشكل خاطئ') ||
        q.contains('شيء اخر') ||
        q.contains('شي اخر') ||
        q.contains('ما تفهم') ||
        q.contains('لا تفهم') ||
        q.contains('غير صحيح') ||
        q.contains('لماذا تجيب') ||
        q.contains('ليش ترد');

    if (isCritiqueOrCorrection) {
      return {
        'id': 'critique_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'تصحيح وتوضيح السياق',
        'title': 'أعتذر عن الالتباس، دعنا نصحح المسار',
        'subtitle': 'شكراً لتنبيهي، كيف يمكنني الإجابة على سؤالك بدقة أكبر؟',
        'time': 'الآن',
        'icon': Icons.psychology_alt_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'source': 'طبقة فهم المقصد وضبط السياق الحواري - MEDIQ AI',
        'question': rawQuery,
        'answerIntro':
            'أعتذر منك بشدة إذا كانت إجابتي السابقة غير مطابقة لمقصدك! ملاحظتك مهمة جداً؛ والسبب هو أنني ألتزم بالبحث الصارم داخل المراجع الطبية المحفوظة لتجنب تخمين أي معلومة طبية.',
        'bullets': [
          'للحصول على إجابة دقيقة ومباشرة، اذكر لي اسم المرض أو العرض الصحي بوضوح (مثال: "ما هي أعراض فقر الدم؟" أو "ما أسباب الصداع النصفي؟").',
          'إذا كنت تسأل عن تحليل مخبري معين، اكتب اسم التحليل (مثال: "شرح تحليل CBC" أو "السكر التراكمي HbA1c").',
          'إذا كنت تريد إسعافات أولية لحالة معينة، اكتب (مثال: "الإسعافات الأولية للإغماء أو الحروق").',
        ],
        'importantNote':
            'اكتب لي الآن السؤال الذي كنت تقصده، وسأقوم بتحليل سؤالك بدقة وتقديم الإجابة المناسبة لك فوراً.',
        'footer': 'شكراً لملاحظتك التي تساعد في ضبط دقة الحوار الطبي.',
      };
    }

    // 1. السؤال عن الحال: كيفك، كيف حالك، كيفك انت، شلونك، شخبارك
    final isAskingHowAreYou = q.contains('كيفك') ||
        q.contains('كيف حالك') ||
        q.contains('شلونك') ||
        q.contains('شخبارك') ||
        q.contains('عساك طيب') ||
        q == 'كيف الحال';

    if (isAskingHowAreYou) {
      return {
        'id': 'greet_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'تحية ترحيبية',
        'title': 'أهلاً بك!',
        'subtitle': 'أنا بخير وبكامل الجاهزية لمساعدتك اليوم...',
        'time': 'الآن',
        'icon': Icons.sentiment_satisfied_alt_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'source': 'المساعد الطبي الذكي MEDIQ AI (يعمل محلياً بدون إنترنت)',
        'question': rawQuery,
        'answerIntro':
            'أهلاً وسهلاً بك! أنا بخير وفي أتم الجاهزية لمساعدتك، شكراً لسؤالك. أتمنى أن تكون أنت وعائلتك بأفضل صحة وعافية.',
        'bullets': [
          'أنا هنا كمساعدك الطبي الذكي لتقديم التثقيف الصحي والمعلومات الموثقة محلياً دون الحاجة للإنترنت.',
          'يمكنك سؤالي عن أي أعراض تشعر بها، أو الاستفسار عن الأمراض الشائعة وطرق الوقاية منها.',
          'يمكنك أيضاً السؤال عن الأدوية العامة، الفيتامينات، أو تفسير المصطلحات والفحوصات الطبية.',
        ],
        'importantNote':
            'كيف تشعر اليوم؟ وما هو السؤال أو الاستفسار الصحي الذي ترغب في معرفته؟ تفضل بطرحه وسأجيبك فوراً.',
        'footer': 'في خدمتك دائماً لمساعدتك في فهم معلوماتك الصحية بأمان.',
      };
    }

    // 2. التحيات الترحيبية: اهلا، مرحبا، السلام عليكم، صباح الخير، مساء الخير، هاي
    final isGreeting = q == 'اهلا' ||
        q == 'أهلا' ||
        q == 'أهلاً' ||
        q == 'اهلا وسهلا' ||
        q == 'مرحبا' ||
        q == 'مرحباً' ||
        q == 'مرحب' ||
        q == 'هاي' ||
        q == 'hello' ||
        q == 'hi' ||
        q.contains('السلام عليكم') ||
        q.contains('صباح الخير') ||
        q.contains('مساء الخير');

    if (isGreeting) {
      return {
        'id': 'greet_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'تحية ترحيبية',
        'title': 'أهلاً وسهلاً بك!',
        'subtitle': 'مرحباً بك في MEDIQ AI - مساعدك الطبي الذكي...',
        'time': 'الآن',
        'icon': Icons.waving_hand_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'source': 'نظام المحادثة الطبي المحلي MEDIQ AI',
        'question': rawQuery,
        'answerIntro':
            'وعليكم السلام وأهلاً وسهلاً بك في تطبيق MEDIQ AI! يسعدني وجودك هنا.',
        'bullets': [
          'نظام محادثة طبي ذكي يعمل محلياً بالكامل على جهازك دون الحاجة إلى اتصال بالإنترنت.',
          'يستند إلى مراجع طبية معتمدة من وزارة الصحة ومنظمة الصحة العالمية (WHO).',
          'مجهز بطبقة أمان طبي تفحص الحالات الطارئة وتوجهك للإجراء المناسب.',
        ],
        'importantNote':
            'تفضل بطرح سؤالك أو الأعراض التي تود الاستفسار عنها، وسأقوم بالبحث في قاعدة المعرفة المحلية وصياغة إجابة تثقيفية موثقة لك.',
        'footer': 'اسأل ... افهم ... تعلّم مع MEDIQ AI.',
      };
    }

    // 3. كلمات الشكر والثناء: شكرا، مشكور، تسلم، يعطيك العافية، جزاك الله خير
    final isThanks = q.contains('شكرا') ||
        q.contains('شكراً') ||
        q.contains('مشكور') ||
        q.contains('تسلم') ||
        q.contains('يعطيك العافيه') ||
        q.contains('يعطيك العافية') ||
        q.contains('جزاك الله خير');

    if (isThanks) {
      return {
        'id': 'thanks_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'رد ودّي',
        'title': 'العفو وفي خدمتك دائماً',
        'subtitle': 'أتمنى لك دوام الصحة والعافية...',
        'time': 'الآن',
        'icon': Icons.favorite_rounded,
        'color': 0xFF10B981,
        'isFavorite': false,
        'isEmergency': false,
        'source': 'MEDIQ AI - مساعدك الطبي الذكي',
        'question': rawQuery,
        'answerIntro':
            'العفو، على الرحب والسعة دائماً! سعيد جداً بمساعدتك، وأتمنى لك دوام الصحة والعافية.',
        'bullets': [
          'إذا كان لديك أي سؤال طبي آخر في أي وقت، أنا متواجد دائماً للعمل معك دون إنترنت.',
          'تذكر دائماً أن الوقاية والفحص الدوري هما الركيزة الأساسية لصحة أفضل.',
        ],
        'importantNote': 'هل ترغب في الاستفسار عن أي موضوع صحي أو فحص طبي آخر؟',
        'footer': 'معاً نحو صحة أفضل وأكثر أماناً.',
      };
    }

    // 4. السؤال عن الهوية: من انت، عرفني بنفسك، ما هو هذا التطبيق
    final isAskingIdentity = q.contains('من انت') ||
        q.contains('من أنت') ||
        q.contains('عرفني بنفسك') ||
        q.contains('ما هو هذا التطبيق') ||
        q.contains('ما وظيفتك');

    if (isAskingIdentity) {
      return {
        'id': 'id_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'التعريف بالنظام',
        'title': 'التعريف بـ MEDIQ AI',
        'subtitle': 'مساعد طبي ذكي يعمل محلياً دون اتصال بالإنترنت...',
        'time': 'الآن',
        'icon': Icons.info_outline_rounded,
        'color': 0xFF0077B6,
        'isFavorite': false,
        'isEmergency': false,
        'source': 'مشروع تخرج - تطوير نظام محادثة طبي ذكي يعمل دون اتصال بالإنترنت',
        'question': rawQuery,
        'answerIntro':
            'أنا "MEDIQ AI"، مساعد طبي ذكي يعمل محلياً دون الحاجة إلى اتصال بالإنترنت (Offline-First):',
        'bullets': [
          'أعتمد على تقنية الاسترجاع المعزز بالتوليد (RAG) المرتبطة بقاعدة معرفة طبية موثقة.',
          'تم تطويري كجزء من مشروع تخرج بقسم تقنية المعلومات في كلية الهندسة وتقنية المعلومات بجامعة السعيدة.',
          'هدفي تسهيل وصول المستخدمين والكوادر الصحية إلى المعلومات الطبية الموثوقة في البيئات ضعيفة الاتصال بالإنترنت.',
        ],
        'importantNote':
            'تنويه: أقدم معلومات وإرشادات تثقيفية عامة فقط ولا أقوم بالتشخيص السريري أو إصدار وصفات علاجية بديلة عن الطبيب.',
        'footer': 'تفضل بطرح أي سؤال طبي، وأنا جاهز لمساعدتك.',
      };
    }

    return null;
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
        'source': 'بروتوكول طبقة الأمان الطبي والتعامل مع الحالات الحرجة',
        'question': query,
        'answerIntro':
            '⚠️ تنبيه طوارئ طبي فوري: استفسارك يتضمن أعراضاً حرجة وعالية الخطورة لا يجب التعامل معها عبر المحادثة النصية:',
        'bullets': [
          'يرجى الاتصال فوراً بالإسعاف والطوارئ الطبية (997) أو التوجه لأقرب مركز طوارئ.',
          'لا تنتظر، وتجنب القيادة بنفسك إذا كنت تشعر بدوار أو ألم حاد في الصدر.',
          'أبقِ المريض في وضعية مريحة وتأكد من استمرارية التنفس والوعي حتى وصول المسعفين.',
        ],
        'importantNote':
            'تم إيقاف التوليد التلقائي بواسطة طبقة السلامة الطبية حفاظاً على سلامتك، حيث تتطلب هذه الحالة تدخلاً سريرياً عاجلاً.',
        'footer': 'أرقام الطوارئ المعتمدة: الإسعاف 997 | الطوارئ الموحد 911.',
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
        'source': 'ضوابط السلامة الطبية والاستخدام الآمن للأدوية',
        'question': query,
        'answerIntro': 'بناءً على ضوابط السلامة الطبية المعتمدة بخصوص "$query":',
        'bullets': [
          'يختص النظام بتقديم التثقيف الصحي والمعلومات الطبية والدوائية العامة فقط.',
          'لا يقوم النظام بتشخيص الأمراض بشكل مؤكد أو إصدار وصفات علاجية أو تحديد جرعات فردية.',
          'تعتمد الجرعة والتشخيص السريري على الفحص الطبي المباشر، العمر، الوزن، والتحاليل المخبرية.',
        ],
        'importantNote':
            'يرجى مراجعة الطبيب المختص أو الصيدلي السريري لتقييم حالتك وتحديد الخطة العلاجية المناسبة بدقة.',
        'footer':
            'تنويه: المعلومات المقدمة للتثقيف الطبي فقط ولا تغني عن استشارة الطبيب المختص.',
      };
    }

    if (isOutOfScope) {
      return {
        'id': 'scope_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'خارج النطاق الطبي',
        'title': query.length > 26 ? '${query.substring(0, 26)}...' : query,
        'subtitle': 'اعتذار منهجي: الاستفسار خارج نطاق المعرفة الطبية...',
        'time': 'الآن',
        'icon': Icons.info_outline_rounded,
        'color': 0xFF64748B,
        'isFavorite': false,
        'isEmergency': false,
        'source': 'ضوابط حدود التغطية المعرفية الطبية',
        'question': query,
        'answerIntro':
            'نعتذر منك، يختص هذا المساعد الذكي بالإجابة عن الاستفسارات الطبية والصحية فقط في حدود قاعدة المعرفة الطبية المعتمدة:',
        'bullets': [
          'يمكنك طرح أسئلة حول الأعراض الشائعة، الأمراض، وطرق الوقاية.',
          'يمكنك الاستفسار عن المعلومات الدوائية العامة والفحوصات الطبية.',
          'يمكنك طلب شرح المصطلحات الطبية باللغتين العربية والإنجليزية.',
        ],
        'importantNote':
            'يلتزم النظام بعدم الإجابة عن الموضوعات غير الطبية أو التي لا تتوفر لها مصادر موثقة في قاعدة المعرفة حفاظاً على الدقة والموثوقية.',
        'footer': 'اكتب سؤالك الطبي أو الصحي وسأكون سعيداً بمساعدتك.',
      };
    }

    return null;
  }
}
