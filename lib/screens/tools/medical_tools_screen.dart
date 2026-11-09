import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/constants/app_keys.dart';
import '../../controllers/app_controller.dart';

class MedicalToolsScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenDrawer;

  const MedicalToolsScreen({
    super.key,
    this.embedded = false,
    this.onOpenDrawer,
  });

  @override
  State<MedicalToolsScreen> createState() => _MedicalToolsScreenState();
}

class _MedicalToolsScreenState extends State<MedicalToolsScreen> {
  int _selectedTab = 0; // 0: BMI, 1: Vitals, 2: Lab, 3: Water & Meds, 4: Interactions

  final TextEditingController _weightCtrl = TextEditingController(text: '70');
  final TextEditingController _heightCtrl = TextEditingController(text: '175');
  String _bmiResult = '';

  final TextEditingController _bpCtrl = TextEditingController(text: '120/80');
  String _labType = 'السكر التراكمي (HbA1c)';
  final TextEditingController _labValCtrl = TextEditingController(text: '5.8');
  String _labResult = '';
  int _waterCups = 5;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _bpCtrl.dispose();
    _labValCtrl.dispose();
    super.dispose();
  }

  void _calcBmi() {
    final w = double.tryParse(_weightCtrl.text) ?? 0;
    final h = double.tryParse(_heightCtrl.text) ?? 0;
    if (w <= 0 || h <= 0) return;
    final hm = h / 100;
    final bmi = w / (hm * hm);
    String status = '';
    if (bmi < 18.5) {
      status = 'وزن منخفض (Underweight)';
    } else if (bmi < 25) {
      status = 'وزن مثالي وطبيعي (Normal) ✅';
    } else if (bmi < 30) {
      status = 'زيادة وزن (Overweight)';
    } else {
      status = 'سمنة (Obese) - يُنصح بالمتابعة الغذائية';
    }
    setState(() {
      _bmiResult = 'مؤشر كتلة الجسم (BMI): ${bmi.toStringAsFixed(1)}\nالتصنيف السريري: $status';
    });
  }

  void _interpretLab() {
    final v = double.tryParse(_labValCtrl.text) ?? 0;
    String res = '';
    if (_labType.contains('HbA1c')) {
      if (v < 5.7) {
        res = 'طبيعي (سليم) ✅';
      } else if (v < 6.5) {
        res = 'مرحلة ما قبل السكري (Prediabetes) - يُنصح بتعديل النمط الغذائي والرياضي.';
      } else {
        res = 'مرتفع (مؤشر لمرض السكري) - يرجى مراجعة طبيب الغدد الصماء.';
      }
    } else if (_labType.contains('فيتامين D')) {
      if (v < 20) {
        res = 'نقص حاد (Deficient) - يتطلب مكملات علاجية بإشراف طبي.';
      } else if (v < 30) {
        res = 'نقص غير كافٍ (Insufficient).';
      } else {
        res = 'مستوى طبيعي ومطمئن (Sufficient) ✅';
      }
    } else {
      if (v >= 12 && v <= 16) {
        res = 'مستوى الهيموجلوبين طبيعي ✅';
      } else if (v < 12) {
        res = 'انخفاض في الهيموجلوبين (احتمال فقر دم / أنيميا) - يُنصح بفحص مخزون الحديد Ferritin.';
      } else {
        res = 'ارتفاع فوق المعدل المعتاد - يُنصح بمراجعة الطبيب.';
      }
    }
    setState(() => _labResult = res);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'الملاحظات والحاسبات الطبية السريرية',
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
                _tabBtn('حاسبة BMI', 0),
                _tabBtn('سجل العلامات الحيوية', 1),
                _tabBtn('مفسر التحاليل المخبرية', 2),
                _tabBtn('الماء والأدوية اليومية', 3),
                _tabBtn('التعارضات والبطاقة الطبية', 4),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_selectedTab == 0) _buildBmiCard(isDark),
                if (_selectedTab == 1) _buildVitalsCard(isDark),
                if (_selectedTab == 2) _buildLabCard(isDark),
                if (_selectedTab == 3) _buildWaterAndMedsCard(isDark),
                if (_selectedTab == 4) _buildInteractionsAndIdCard(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _selectedTab = index),
        selectedColor: const Color(0xFF0077B6),
        labelStyle: TextStyle(
          color: active ? Colors.white : null,
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _buildBmiCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حاسبة مؤشر كتلة الجسم والوزن المثالي (BMI)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'الوزن بالكيلوجرام (kg)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'الطول بالسنتيمتر (cm)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calcBmi,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('احسب المؤشر الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0077B6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_bmiResult.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0096C7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _bmiResult,
                style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تسجيل قراءة ضغط الدم أو السكر أو النبض',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bpCtrl,
            decoration: const InputDecoration(
              labelText: 'القراءة (مثال: 120/80 أو 95 mg/dl)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              if (_bpCtrl.text.trim().isEmpty) return;
              appController.addVital('قياس حيوي', _bpCtrl.text.trim(), 'مسجل');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ القراءة في السجل الحيوي المحلي ✓')),
              );
              setState(() {});
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('حفظ في السجل الحيوي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'سجل القراءات السابقة:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ...appController.vitalsLog.map(
            (v) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF0077B6)),
              title: Text('${v['type']}: ${v['val']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('التوقيت: ${v['date']}'),
              trailing: Chip(
                label: Text(v['status'].toString(), style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.green.withOpacity(0.12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مفسر التحاليل المخبرية السريع',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _labType,
            items: const [
              DropdownMenuItem(
                value: 'السكر التراكمي (HbA1c)',
                child: Text('السكر التراكمي (HbA1c %)'),
              ),
              DropdownMenuItem(
                value: 'فيتامين D (Vit D)',
                child: Text('فيتامين D (ng/mL)'),
              ),
              DropdownMenuItem(
                value: 'الهيموجلوبين (Hemoglobin)',
                child: Text('الهيموجلوبين (g/dL) - فقر الدم'),
              ),
            ],
            onChanged: (val) => setState(() => _labType = val!),
            decoration: const InputDecoration(
              labelText: 'نوع التحليل المخبري',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labValCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'النتيجة الرقمية للتحليل',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _interpretLab,
            icon: const Icon(Icons.biotech_rounded),
            label: const Text('قراءة النتيجة المخبرية'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0077B6),
              foregroundColor: Colors.white,
            ),
          ),
          if (_labResult.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _labResult,
                style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaterAndMedsCard(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              const Text(
                'عدّاد شرب الماء اليومي (Hydration Tracker)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _waterCups = math.max(0, _waterCups - 1)),
                    icon: const Icon(Icons.remove_circle_rounded, size: 32, color: Colors.redAccent),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_waterCups / 8 أكواب',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0077B6),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _waterCups += 1),
                    icon: const Icon(Icons.add_circle_rounded, size: 32, color: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (_waterCups / 8).clamp(0.0, 1.0),
                minHeight: 10,
                borderRadius: BorderRadius.circular(10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'منبه المكملات والأدوية اليومية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...List.generate(appController.medsList.length, (i) {
                final med = appController.medsList[i];
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(med['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('الموعد: ${med['time']}'),
                  value: med['status'] as bool,
                  onChanged: (_) => setState(() => appController.toggleMed(i)),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionsAndIdCard(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'دليل التعارضات الدوائية والغذائية الهامة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                '• حبوب الحديد والكالسيوم: لا تتناولها مع الشاي أو القهوة في نفس الوقت لأن التانينات تقلل امتصاص الحديد.\n'
                '• المسكنات (NSAIDs مثل الإيبوبروفين): تؤخذ بعد الطعام لحماية الغشاء المخاطي للمعدة.\n'
                '• أدوية السيولة (الوارفارين): تتطلب ثبات كمية الخضروات الورقية الغنية بفيتامين K.\n'
                '• المضادات الحيوية (التتراسيكلين/السيبروفلوكساسين): تجنب تناولها مع الحليب ومشتقات الألبان.',
                style: TextStyle(height: 1.6, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.badge_rounded, color: Color(0xFFE11D48)),
                  SizedBox(width: 8),
                  Text(
                    'بطاقة الهوية الطبية للطوارئ (Medical ID)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text('الاسم: ${appController.medicalId['name']}'),
              Text('فصيلة الدم: ${appController.medicalId['blood']}'),
              Text('الحساسية الدوائية: ${appController.medicalId['allergies']}'),
              Text('الأمراض المزمنة: ${appController.medicalId['conditions']}'),
              Text('رقم الطوارئ: ${appController.medicalId['contact']}'),
            ],
          ),
        ),
      ],
    );
  }
}
