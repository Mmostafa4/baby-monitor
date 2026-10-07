import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool validDoctorName(String value) =>
    value.trim().length >= 3 && !RegExp(r'[0-9٠-٩۰-۹@]').hasMatch(value);

/// Local profile prototype only; no verification, calls, billing or enforcement.
class DoctorMode extends StatefulWidget {
  final VoidCallback? onExit;
  const DoctorMode({super.key, this.onExit});
  @override
  State<DoctorMode> createState() => _DoctorModeState();
}

class _DoctorModeState extends State<DoctorMode> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  String title = 'أخصائي';
  bool loading = true, saving = false, agreed = false, ready = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      name.text = prefs.getString('doctorName') ?? '';
      title = prefs.getString('doctorTitle') == 'استشاري'
          ? 'استشاري'
          : 'أخصائي';
    } catch (_) {
      error = 'تعذر تحميل الملف المحلي. يمكنك إدخاله من جديد.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || !agreed) return;
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('doctorName', name.text.trim()) ||
          !await prefs.setString('doctorTitle', title))
        throw StateError('Save failed');
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ الملف. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> exit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء وضع الطبيب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      if (widget.onExit != null) { widget.onExit!(); } else { Navigator.of(context).pop(); }
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('وضع الطبيب • تجربة'),
          actions: [
            TextButton(
              onPressed: saving ? null : exit,
              child: const Text('إنهاء الوضع'),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'ملف طبيب محلي تجريبي. البيانات غير موثّقة، ولا توجد مكالمات أو استشارات متاحة في هذه النسخة.',
                    ),
                    const SizedBox(height: 16),
                    if (!ready) ...[
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الثنائي أو اسم الشهرة',
                        ),
                        validator: (value) => validDoctorName(value ?? '')
                            ? null
                            : 'أدخل اسمًا بدون رقم هاتف أو بريد إلكتروني.',
                      ),
                      DropdownButtonFormField<String>(
                        value: title,
                        decoration: const InputDecoration(
                          labelText: 'الصفة المهنية',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'أخصائي',
                            child: Text('أخصائي'),
                          ),
                          DropdownMenuItem(
                            value: 'استشاري',
                            child: Text('استشاري'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setState(() => title = value!),
                      ),
                      CheckboxListTile(
                        value: agreed,
                        onChanged: saving
                            ? null
                            : (value) =>
                                  setState(() => agreed = value ?? false),
                        title: const Text(
                          'أوافق على عدم تبادل أرقام الهاتف أو بيانات الاتصال أثناء استخدام الخدمة.',
                        ),
                      ),
                      const Text(
                        'تطبيق السياسة على المكالمات وإجراءات الحساب يتطلبان خدمة متصلة ومراجعة؛ هذه التجربة لا تراقب المكالمات.',
                      ),
                      FilledButton(
                        onPressed: saving || !agreed ? null : save,
                        child: Text(
                          saving ? 'جارٍ الحفظ...' : 'حفظ وفتح وضع الطبيب',
                        ),
                      ),
                    ] else ...[
                      Text(
                        '$title • ${name.text.trim()}',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const Text(
                        'تم حفظ الملف على هذا الجهاز. استقبال الحالات غير مفعّل. الدفع غير مفعّل.',
                      ),
                      TextButton(
                        onPressed: () => setState(() => ready = false),
                        child: const Text('تعديل الملف'),
                      ),
                    ],
                    if (error.isNotEmpty) Text(error),
                  ],
                ),
              ),
      ),
    ),
  );
}
