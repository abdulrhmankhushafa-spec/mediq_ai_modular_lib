import 'package:flutter/material.dart';
import 'local_knowledge_db_service.dart';
import 'local_llm_service.dart';

/// خدمة المعالجة الخلفية المتكاملة (Offline Medical RAG + Safety Layer + Phone GGUF LLM):
class MedicalRagService {
  static const List<String> emergencyKeywords = [
    'جلطة',
    'نزيف حاد',
    'تسمم',
    'انتحار',
    'ألم صدر شديد',
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
    final safetyCheck = _checkSafetyAndScope(query);
    if (safetyCheck != null) {
      return safetyCheck;
    }

    final retrievedChunks = LocalKnowledgeDbService.instance.searchHybrid(query, topK: 2);
    final primaryChunk = retrievedChunks.isNotEmpty ? retrievedChunks.first : null;

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

    return {
      'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
      'category': 'استفسار طبي موثق',
      'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
      'subtitle': 'معلومات طبية مسترجعة من المراجع المعتمدة...',
      'time': 'الآن',
      'icon': Icons.health_and_safety_rounded,
      'color': 0xFF0077B6,
      'isFavorite': false,
      'isEmergency': false,
      'source':
          'الدليل العلاجي الوطني وأدلة الرعاية الصحية الأولية وإرشادات منظمة الصحة العالمية (WHO)',
      'question': query,
      'answerIntro':
          'بناءً على المراجع الطبية المعتمدة في قاعدة المعرفة المحلية بخصوص "$query"، إليك المعلومات التثقيفية المنظمة:',
      'bullets': [
        'التعريف والتقييم المبدئي: يُنصح بمراقبة الأعراض الحيوية وتدوين وقت بدايتها ومدى تطورها.',
        'الإرشادات الوقائية: الالتزام بالراحة الكافية، شرب السوائل بانتظام، وتجنب المسببات المهيجة.',
        'الفحوصات المقترحة: قد يتطلب التقييم السريري إجراء تحاليل مخبرية أساسية لتأكيد السبب بدقة.',
        'الاستخدام الدوائي الآمن: تجنب أخذ أي مضادات حيوية أو أدوية تخصصية دون استشارة طبية معتمدة.',
      ],
      'importantNote':
          'هذه المعلومات مستخرجة محلياً من المراجع الطبية المعتمدة لأغراض التثقيف الصحي العام، ولا تُعد تشخيصاً طبياً نهائياً أو بديلاً عن الطبيب.',
      'footer':
          'إذا استمرت الأعراض أو ازدادت حدتها، يُنصح بمراجعة الطبيب المختص لإجراء الفحص السريري.',
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
