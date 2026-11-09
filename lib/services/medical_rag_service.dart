import 'package:flutter/material.dart';

/// خدمة المعالجة الخلفية (Backend Service):
/// تحتوي على طبقة الأمان الطبي (Medical Safety Guardrails) ومحرك الاسترجاع الهجين (RAG Engine).
/// يمكنك لاحقاً ربط هذه الدوال مباشرة مع SQLite FTS5 و llama.cpp (GGUF).
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
  ];

  static const List<String> dosageKeywords = [
    'كم جرعة',
    'اعطني وصفة',
    'اكتب لي دواء',
    'جرعة دقيقة',
    'كم حبة آخذ',
  ];

  static Map<String, dynamic> generateReply({
    required String query,
    required String selectedModel,
    required String knowledgeVersion,
  }) {
    final isEmergency = emergencyKeywords.any((k) => query.contains(k));
    final isDosageRequest = dosageKeywords.any((k) => query.contains(k));

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
        'source': 'بروتوكول طبقة الأمان الطبي (Safety Guardrails Layer - D1/D4)',
        'question': query,
        'answerIntro':
            '⚠️ تنبيه طوارئ طبي فوري: استفسارك يتضمن أعراضاً حرجة وعالية الخطورة لا يجب التعامل معها عبر المحادثة النصية:',
        'bullets': [
          'يرجى الاتصال فوراً بالإسعاف والطوارئ الطبية (997) أو التوجه لأقرب قسم طوارئ.',
          'لا تنتظر، وتجنب القيادة بنفسك إذا كنت تشعر بدوار أو ألم في الصدر.',
          'أبقِ المريض في وضعية مريحة وتأكد من استمرارية التنفس والوعي حتى وصول المسعفين.',
        ],
        'importantNote':
            'تم إيقاف التوليد التلقائي بواسطة طبقة السلامة الطبية (Medical Safety Layer) حفاظاً على سلامتك، حيث تتطلب هذه الحالة تدخلاً سريرياً عاجلاً.',
        'footer': 'أرقام الطوارئ المعتمدة: الإسعاف 997 | الطوارئ الموحد 911.',
      };
    }

    if (isDosageRequest) {
      return {
        'id': 'guard_${DateTime.now().millisecondsSinceEpoch}',
        'category': 'ضوابط السلامة الدوائية',
        'title': query.length > 26 ? '${query.substring(0, 26)}...' : query,
        'subtitle': 'ضوابط وصف الجرعات الدوائية الفردية...',
        'time': 'الآن',
        'icon': Icons.medication_liquid_rounded,
        'color': 0xFFF59E0B,
        'isFavorite': false,
        'isEmergency': false,
        'source': 'ضوابط الاستخدام الآمن للأدوية (Medical Safety Guardrails)',
        'question': query,
        'answerIntro': 'بناءً على بروتوكول الأمان الطبي للنظام بخصوص "$query":',
        'bullets': [
          'يختص النظام بتقديم التثقيف الطبي والمعلومات الدوائية العامة والآثار الجانبية.',
          'يُمنع برمجياً تحديد جرعات دوائية فردية أو إصدار وصفات علاجية شخصية دون فحص سريري.',
          'تعتمد الجرعة الآمنة على العمر، الوزن، وظائف الكبد والكلى، والأدوية الأخرى المتناولة.',
        ],
        'importantNote':
            'يرجى مراجعة الطبيب المختص أو الصيدلي السريري لتحديد الجرعة المناسبة لحالتك الصحية بدقة.',
        'footer':
            'تنويه: المعلومات المقدمة للتثقيف الطبي فقط ولا تغني عن استشارة الطبيب المختص.',
      };
    }

    return {
      'id': 'chat_${DateTime.now().millisecondsSinceEpoch}',
      'category': 'استشارة ذكية (RAG)',
      'title': query.length > 28 ? '${query.substring(0, 28)}...' : query,
      'subtitle': 'تحليل طبي مسترجع من قاعدة المعرفة المحلية...',
      'time': 'الآن',
      'icon': Icons.health_and_safety_rounded,
      'color': 0xFF0077B6,
      'isFavorite': false,
      'isEmergency': false,
      'source':
          'البحث الهجين SQLite FTS5 + Vector Similarity (الإصدار $knowledgeVersion)',
      'question': query,
      'answerIntro':
          'بناءً على السياق الطبي المسترجع من قاعدة المعرفة المحلية عبر تقنية (RAG) بخصوص "$query"، إليك المعلومات الطبية المنظمة:',
      'bullets': [
        'التعريف والتقييم المبدئي: يُنصح بمراقبة الأعراض الحيوية وتدوين وقت بدايتها ومدى تطورها.',
        'الإرشادات الوقائية: الالتزام بالراحة الكافية، شرب السوائل بانتظام، وتجنب المسببات المهيجة.',
        'الفحوصات المقترحة: قد يتطلب التقييم السريري إجراء تحاليل مخبرية أساسية لتأكيد السبب بدقة.',
        'الاستخدام الدوائي: تجنب أخذ أي مضادات حيوية أو أدوية تخصصية دون وصفة طبية معتمدة.',
      ],
      'importantNote':
          'هذه المعلومات مستخرجة محلياً عبر نموذج ($selectedModel) لأغراض التثقيف الصحي العام، ولا تُعد تشخيصاً طبياً نهائياً.',
      'footer':
          'إذا استمرت الأعراض أو ازدادت حدتها، يُنصح بمراجعة الطبيب المختص لإجراء الفحص السريري.',
    };
  }
}
