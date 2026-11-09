import 'package:flutter/material.dart';
import '../../core/constants/app_keys.dart';

class MedicalStudentHubScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenDrawer;

  const MedicalStudentHubScreen({
    super.key,
    this.embedded = false,
    this.onOpenDrawer,
  });

  @override
  State<MedicalStudentHubScreen> createState() => _MedicalStudentHubScreenState();
}

class _MedicalStudentHubScreenState extends State<MedicalStudentHubScreen> {
  int _tab = 0; // 0: GCS, 1: Abbreviations, 2: ECG & XRay, 3: Flashcards
  int _gcsE = 4;
  int _gcsV = 5;
  int _gcsM = 6;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalGcs = _gcsE + _gcsV + _gcsM;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white : const Color(0xFF0A192F),
          ),
          onPressed: () {
            if (widget.onOpenDrawer != null) {
              widget.onOpenDrawer!();
            } else {
              mainScaffoldKey.currentState?.openDrawer();
            }
          },
        ),
        title: Text(
          'بوابة طالب الطب والتدريب السريري (OSCE)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: isDark ? Colors.white : const Color(0xFF0A192F),
          ),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _tabBtn('مقياس الوعي GCS', 0),
                _tabBtn('الاختصارات الطبية', 1),
                _tabBtn('منهجية ECG والأشعة', 2),
                _tabBtn('بطاقات OSCE السريرية', 3),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_tab == 0)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حاسبة غلاسكو للغيبوبة (GCS Score): $totalGcs / 15',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: Color(0xFF0077B6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          totalGcs >= 13
                              ? 'التقييم: إصابة خفيفة / وعي جيد (Mild)'
                              : totalGcs >= 9
                                  ? 'التقييم: إصابة متوسطة (Moderate)'
                                  : 'التقييم: غيبوبة / إصابة شديدة حرجة (Severe ≤ 8)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        _gcsDropdown(
                          'استجابة فتح العين (Eye Opening - E)',
                          _gcsE,
                          {
                            4: 'تلقائية (Spontaneous)',
                            3: 'عند المناداة (To Speech)',
                            2: 'عند الألم (To Pain)',
                            1: 'لا توجد استجابة (None)'
                          },
                          (v) => setState(() => _gcsE = v),
                        ),
                        _gcsDropdown(
                          'الاستجابة اللفظية (Verbal Response - V)',
                          _gcsV,
                          {
                            5: 'مدرك للزمان والمكان (Oriented)',
                            4: 'مشوش الذهن (Confused)',
                            3: 'كلمات غير مترابطة (Inappropriate words)',
                            2: 'أصوات غير مفهومة (Incomprehensible sounds)',
                            1: 'لا توجد استجابة (None)'
                          },
                          (v) => setState(() => _gcsV = v),
                        ),
                        _gcsDropdown(
                          'الاستجابة الحركية (Motor Response - M)',
                          _gcsM,
                          {
                            6: 'يطيع الأوامر الحركية (Obeys commands)',
                            5: 'يحدد موضع الألم (Localizes pain)',
                            4: 'يسحب الطرف عند الألم (Normal withdrawal)',
                            3: 'انثناء غير طبيعي (Decorticate flexion)',
                            2: 'انبساط غير طبيعي (Decerebrate extension)',
                            1: 'لا توجد استجابة (None)'
                          },
                          (v) => setState(() => _gcsM = v),
                        ),
                      ],
                    ),
                  ),
                if (_tab == 1)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'قاموس الاختصارات الطبية السريرية (Medical Abbreviations)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '• OD / QD: مرة واحدة يومياً (Once daily)\n'
                          '• BID: مرتان يومياً كل 12 ساعة (Twice a day)\n'
                          '• TID: ثلاث مرات يومياً كل 8 ساعات (Three times a day)\n'
                          '• QID: أربع مرات يومياً كل 6 ساعات\n'
                          '• PRN: عند اللزوم فقط (As needed)\n'
                          '• STAT: فوراً وبشكل طارئ وعاجل (Immediately)\n'
                          '• NPO: صائم تماماً عن الفم (Nothing by mouth)\n'
                          '• PO / IV / IM / SC: فموي / وريدي / عضلي / تحت الجلد\n'
                          '• SOB: ضيق التنفس (Shortness of breath)\n'
                          '• CBC / LFT / RFT: صورة الدم الكاملة / وظائف الكبد / وظائف الكلى',
                          style: TextStyle(height: 1.65, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                if (_tab == 2)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'منهجية قراءة تخطيط القلب (ECG) وأشعة الصدر (CXR)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: Color(0xFF0077B6),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'أولاً: خطوات قراءة تخطيط القلب (ECG):\n'
                          '1. السرعة (Rate): 300 مقسومة على عدد المربعات الكبيرة بين قمتي R-R.\n'
                          '2. النظم (Rhythm): انتظام المسافات R-R ووجود موجة P قبل كل QRS.\n'
                          '3. المحور الكهربائي (Axis): فحص اتجاه QRS في الاتجاهين Lead I و aVF.\n'
                          '4. الفواصل (PR & QT Intervals) وعرض مركب QRS.\n'
                          '5. قطعة ST (ST-Segment): البحث عن أي ارتفاع (STEMI) أو انخفاض (Ischemia).\n\n'
                          'ثانياً: منهجية أشعة الصدر (ABCDEF):\n'
                          '• A (Airways): استقامة القصبة الهوائية في المنتصف.\n'
                          '• B (Bones): الأضلاع والترقوة والفقرات.\n'
                          '• C (Cardiac): حجم ظل القلب (CTR < 50%).\n'
                          '• D (Diaphragm): الحجاب الحاجز والزوايا الضلعية الحجابية.\n'
                          '• E (Effusion / Edges) & F (Lung Fields): نقاء الساحتين الرئويتين.',
                          style: TextStyle(height: 1.55, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                if (_tab == 3)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'بطاقات العلامات السريرية السريعة (Clinical Flashcards)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '• علامة ميرفي (Murphy\'s Sign): توقف الشهيق بسبب الألم عند جس الربع العلوي الأيمن للبطن -> التهاب المرارة الحاد (Acute Cholecystitis).\n\n'
                          '• نقطة ماكبرني (McBurney\'s Point): ألم ارتدادي في الربع السفلي الأيمن -> التهاب الزائدة الدودية الحاد (Acute Appendicitis).\n\n'
                          '• علامة بابينسكي (Babinski Sign): انبساط أصابع القدم للأعلى عند البالغين -> إصابة العصبون الحركي العلوي (UMN Lesion).\n\n'
                          '• ثالوث بيك (Beck\'s Triad): انخفاض الضغط + احتقان أوردة العنق + خفوت أصوات القلب -> الاندحاس القلبي (Cardiac Tamponade).',
                          style: TextStyle(height: 1.6, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _tab = index),
        selectedColor: const Color(0xFF0077B6),
        labelStyle: TextStyle(
          color: active ? Colors.white : null,
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _gcsDropdown(
    String title,
    int currentVal,
    Map<int, String> options,
    Function(int) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF0096C7),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: currentVal,
            items: options.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.key} - ${e.value}', style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (val) => onChanged(val!),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
