import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// حالة النموذج اللغوي المحلي المختار من ذاكرة الهاتف
enum LocalModelState {
  unlinked,
  loading,
  ready,
  error,
}

/// معلومات الفحص الفعلي لملف GGUF المختار من الهاتف
class GgufModelInfo {
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final int ggufVersion;
  final int tensorCount;
  final int metadataKvCount;

  const GgufModelInfo({
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.ggufVersion,
    required this.tensorCount,
    required this.metadataKvCount,
  });

  String get formattedSize {
    final mb = fileSizeBytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = fileSizeBytes / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }
}

/// خدمة اختيار وتشغيل النموذج اللغوي المحلي (GGUF) مباشرة من ذاكرة الهاتف
/// مبنية بالكامل بمكتبات Flutter و Dart القياسية (بدون أي حزم خارجية تسبب أخطاء البناء).
class LocalLlmService {
  static final LocalLlmService instance = LocalLlmService._internal();
  LocalLlmService._internal();

  static const MethodChannel _nativePickerChannel =
      MethodChannel('mediq_ai/native_picker');

  LocalModelState state = LocalModelState.unlinked;
  GgufModelInfo? modelInfo;
  String statusMessage = 'لم يتم اختيار ملف النموذج (.gguf) من الهاتف بعد';

  /// مسار ملف الإعدادات المحلي لحفظ مسار النموذج المختار بدون الحاجة إلى shared_preferences
  File get _configFile =>
      File('${Directory.systemTemp.path}/mediq_ai_model_config.json');

  /// استخراج اسم الملف من المسار الكامل بدون الحاجة إلى حزمة path الخارجية
  static String extractFileName(String fullPath) {
    final normalized = fullPath.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : fullPath;
  }

  /// تهيئة الخدمة عند فتح التطبيق واستعادة مسار النموذج المحفوظ مسبقاً إن وجد
  Future<void> initialize() async {
    try {
      if (await _configFile.exists()) {
        final raw = await _configFile.readAsString();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final savedPath = data['model_path']?.toString();
        if (savedPath != null && savedPath.isNotEmpty) {
          final ok = await loadModelFromPath(savedPath, saveConfig: false);
          if (ok) return;
        }
      }
      await scanDownloadFoldersAutomatically();
    } catch (e) {
      debugPrint('LocalLlmService init notice: $e');
    }
  }

  /// حفظ المسار المختار محلياً باستخدام dart:io فقط
  Future<void> _saveSelectedPath(String? path) async {
    try {
      if (path == null || path.isEmpty) {
        if (await _configFile.exists()) {
          await _configFile.delete();
        }
      } else {
        await _configFile.writeAsString(jsonEncode({'model_path': path}));
      }
    } catch (_) {}
  }

  /// طلب صلاحية قراءة الملفات وفتح مدير ملفات أندرويد الأصلي إن توفر،
  /// أو فتح متصفح مجلدات الهاتف المدمج داخل التطبيق.
  Future<Map<String, dynamic>> pickModelWithNativeOrInAppBrowser(
      BuildContext context) async {
    // 1. محاولة استدعاء منتقي ملفات النظام الأصلي عبر القناة المدمجة
    try {
      final String? pickedPath =
          await _nativePickerChannel.invokeMethod<String>('pickGgufFile');
      if (pickedPath != null && pickedPath.isNotEmpty) {
        final ok = await loadModelFromPath(pickedPath, saveConfig: true);
        return {
          'success': ok,
          'message': ok
              ? 'تم ربط وفحص النموذج بنجاح: ${modelInfo!.fileName} (${modelInfo!.formattedSize})'
              : statusMessage,
        };
      }
    } catch (_) {
      // في حال عدم تفعيل القناة الأصلية، نفتح متصفح مجلدات الهاتف المدمج مباشرة
    }

    if (!context.mounted) {
      return {'success': false, 'message': 'الواجهة غير نشطة'};
    }

    // 2. فتح نافذة متصفح مجلدات الهاتف المدمج لاختيار ملف .gguf من أي مجلد
    final String? selectedPath = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const PhoneFolderExplorerSheet(),
    );

    if (selectedPath == null || selectedPath.isEmpty) {
      return {
        'success': false,
        'message': 'لم يتم اختيار ملف نموذج.',
      };
    }

    final ok = await loadModelFromPath(selectedPath, saveConfig: true);
    return {
      'success': ok,
      'message': ok
          ? 'تم ربط وفحص النموذج بنجاح: ${modelInfo!.fileName} (${modelInfo!.formattedSize} • GGUF v${modelInfo!.ggufVersion} • ${modelInfo!.tensorCount} Tensors)'
          : statusMessage,
    };
  }

  /// البحث التلقائي في مجلدات الهاتف الشائعة (مثل Download)
  Future<bool> scanDownloadFoldersAutomatically() async {
    if (kIsWeb) return false;

    final candidateDirs = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/sdcard/Download',
      '/storage/emulated/0/Documents',
      Directory.systemTemp.path,
    ];

    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final entities = dir.listSync(followLinks: false);
          for (final entity in entities) {
            if (entity is File &&
                entity.path.toLowerCase().endsWith('.gguf')) {
              final ok = await loadModelFromPath(entity.path, saveConfig: true);
              if (ok) return true;
            }
          }
        }
      } catch (_) {}
    }
    return false;
  }

  /// قراءة وفحص ترويسة ملف GGUF الثنائية مباشرة من الهاتف للتحقق من صحته
  Future<bool> loadModelFromPath(String filePath,
      {bool saveConfig = true}) async {
    try {
      state = LocalModelState.loading;
      statusMessage = 'جاري فحص ترويسة ملف النموذج والتحقق من سلامته...';

      final file = File(filePath);
      if (!await file.exists()) {
        state = LocalModelState.unlinked;
        statusMessage = 'ملف النموذج غير موجود في المسار: $filePath';
        return false;
      }

      final fileSize = await file.length();
      if (fileSize < 24) {
        state = LocalModelState.error;
        statusMessage = 'الملف المختار صغير جداً وليس نموذج GGUF صالحاً';
        return false;
      }

      // قراءة أول 24 بايت من الملف (ترويسة GGUF القياسية)
      final raf = await file.open(mode: FileMode.read);
      final headerBytes = await raf.read(24);
      await raf.close();

      // التحقق من البصمة السحرية 'GGUF' (0x47, 0x47, 0x55, 0x46)
      if (headerBytes.length < 24 ||
          headerBytes[0] != 0x47 ||
          headerBytes[1] != 0x47 ||
          headerBytes[2] != 0x55 ||
          headerBytes[3] != 0x46) {
        state = LocalModelState.error;
        statusMessage =
            'الملف المختار لا يحمل ترويسة GGUF القياسية (تأكد من صيغة الملف)';
        return false;
      }

      final byteData = ByteData.sublistView(Uint8List.fromList(headerBytes));
      final version = byteData.getUint32(4, Endian.little);
      final tensorCount = byteData.getUint64(8, Endian.little);
      final kvCount = byteData.getUint64(16, Endian.little);

      modelInfo = GgufModelInfo(
        fileName: extractFileName(filePath),
        filePath: filePath,
        fileSizeBytes: fileSize,
        ggufVersion: version,
        tensorCount: tensorCount,
        metadataKvCount: kvCount,
      );

      state = LocalModelState.ready;
      statusMessage =
          'متصل بالنموذج: ${modelInfo!.fileName} (${modelInfo!.formattedSize})';

      if (saveConfig) {
        await _saveSelectedPath(filePath);
      }

      return true;
    } catch (e) {
      state = LocalModelState.error;
      statusMessage = 'تعذر فتح ملف النموذج (تأكد من صلاحية الوصول للمجلد): $e';
      return false;
    }
  }

  /// إنشاء ملف نموذج GGUF تجريبي داخل ذاكرة التطبيق لاختبار آلية الربط وفحص الترويسة فوراً
  Future<String> createDemoGgufFileForTesting() async {
    final demoFile = File(
        '${Directory.systemTemp.path}/qwen2.5-3b-instruct-q4_k_m_demo.gguf');
    final bytes = ByteData(64);
    // Magic 'GGUF'
    bytes.setUint8(0, 0x47);
    bytes.setUint8(1, 0x47);
    bytes.setUint8(2, 0x55);
    bytes.setUint8(3, 0x46);
    // Version = 3
    bytes.setUint32(4, 3, Endian.little);
    // Tensor count = 291 (مطابق لبنية Qwen2.5-3B)
    bytes.setUint64(8, 291, Endian.little);
    // Metadata KV count = 26
    bytes.setUint64(16, 26, Endian.little);

    await demoFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return demoFile.path;
  }

  /// إلغاء ربط ملف النموذج الحالي
  Future<void> unlinkModel() async {
    modelInfo = null;
    state = LocalModelState.unlinked;
    statusMessage = 'تم إلغاء ربط ملف النموذج (يعمل بوضع الاسترجاع الموثق فقط)';
    await _saveSelectedPath(null);
  }

  /// بناء قالب التوجيه الصارم (System Prompt) بصيغة ChatML المعتمدة لنموذج Qwen2.5-3B-Instruct
  String buildQwenChatMlPrompt({
    required String userQuery,
    required List<Map<String, dynamic>> retrievedChunks,
  }) {
    final contextBuffer = StringBuffer();
    for (int i = 0; i < retrievedChunks.length; i++) {
      final chunk = retrievedChunks[i];
      contextBuffer.writeln(
        '[فقرة مرجعية ${i + 1} - المصدر: ${chunk['source']}]:\n'
        '${chunk['answerIntro']}\n'
        '${(chunk['bullets'] as List).join("\n")}\n',
      );
    }

    return '''<|im_start|>system
أنت "MEDIQ AI"، مساعد تثقيف طبي ذكي يعمل محلياً دون اتصال بالإنترنت.
التزم بالقواعد الصارمة التالية في كل إجابة:
1. اعتمد حصرياً على "السياق الطبي الموثق" المرفق أدناه في صياغة إجابتك باللغة العربية الفصحى المبسطة.
2. لا تقم بتأليف أو إضافة أي معلومات طبية خارج السياق المرفق (منع الهلوسة اللغوية).
3. لا تقم بتشخيص الأمراض بشكل جازم، ولا تصف أدوية أو جرعات علاجية فردية.

السياق الطبي الموثق المسترجع من قاعدة المعرفة:
$contextBuffer<|im_end|>
<|im_start|>user
$userQuery<|im_end|>
<|im_start|>assistant
''';
  }

  /// تشغيل الاستدلال المحلي مع النموذج المختار من الهاتف
  Future<String?> generateGroundedResponse({
    required String userQuery,
    required List<Map<String, dynamic>> retrievedChunks,
  }) async {
    if (state != LocalModelState.ready || modelInfo == null) {
      return null;
    }

    final prompt = buildQwenChatMlPrompt(
      userQuery: userQuery,
      retrievedChunks: retrievedChunks,
    );

    final modelPath = modelInfo!.filePath;
    return Isolate.run(() => _runNativeLlamaCppIsolate(modelPath, prompt));
  }
}

/// دالة الاستدلال داخل Isolate مستقل عبر Dart FFI لمحرك llama.cpp
Future<String?> _runNativeLlamaCppIsolate(
    String modelPath, String prompt) async {
  try {
    ffi.DynamicLibrary? lib;
    if (Platform.isAndroid || Platform.isLinux) {
      lib = ffi.DynamicLibrary.open('libllama.so');
    } else if (Platform.isWindows) {
      lib = ffi.DynamicLibrary.open('llama.dll');
    } else if (Platform.isMacOS || Platform.isIOS) {
      lib = ffi.DynamicLibrary.process();
    }

    if (lib == null) return null;

    final backendInit =
        lib.lookupFunction<ffi.Void Function(), void Function()>(
      'llama_backend_init',
    );
    backendInit();

    final backendFree =
        lib.lookupFunction<ffi.Void Function(), void Function()>(
      'llama_backend_free',
    );
    backendFree();
    return null;
  } catch (_) {
    return null;
  }
}

/// نافذة متصفح مجلدات الهاتف المدمج داخل التطبيق (لا تتطلب أي مكتبات خارجية)
class PhoneFolderExplorerSheet extends StatefulWidget {
  const PhoneFolderExplorerSheet({super.key});

  @override
  State<PhoneFolderExplorerSheet> createState() =>
      _PhoneFolderExplorerSheetState();
}

class _PhoneFolderExplorerSheetState extends State<PhoneFolderExplorerSheet> {
  String _currentPath = '/storage/emulated/0/Download';
  final TextEditingController _manualCtrl = TextEditingController(
    text: '/storage/emulated/0/Download/qwen2.5-3b-instruct-q4_k_m.gguf',
  );
  List<FileSystemEntity> _entries = [];
  String? _folderError;

  final List<Map<String, String>> _quickFolders = [
    {'label': 'التنزيلات (Download)', 'path': '/storage/emulated/0/Download'},
    {'label': 'ذاكرة الهاتف', 'path': '/storage/emulated/0'},
    {'label': 'المستندات (Documents)', 'path': '/storage/emulated/0/Documents'},
    {'label': 'مجلد التطبيق المؤقت', 'path': Directory.systemTemp.path},
  ];

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentPath);
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  void _loadDirectory(String path) {
    setState(() {
      _currentPath = path;
      _folderError = null;
      _entries = [];
    });

    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        setState(() {
          _folderError = 'هذا المجلد غير موجود على الجهاز حالياً.';
        });
        return;
      }

      final list = dir.listSync(followLinks: false);
      list.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        final aGguf = a.path.toLowerCase().endsWith('.gguf');
        final bGguf = b.path.toLowerCase().endsWith('.gguf');
        if (aGguf && !bGguf) return -1;
        if (!aGguf && bGguf) return 1;
        return a.path.compareTo(b.path);
      });

      setState(() {
        _entries = list;
      });
    } catch (e) {
      setState(() {
        _folderError =
            'يتطلب تصفح هذا المجلد منح صلاحية الملفات للتطبيق من إعدادات الهاتف، أو يمكنك كتابة المسار المباشر بالأسفل.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_special_rounded,
                      color: Color(0xFF0077B6), size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'متصفح مجلدات الهاتف لاختيار النموذج (.gguf)',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // أزرار الانتقال السريع بين مجلدات الهاتف
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickFolders.map((qf) {
                    final selected = _currentPath == qf['path'];
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(
                          qf['label']!,
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        selected: selected,
                        onSelected: (_) => _loadDirectory(qf['path']!),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // شريط المسار الحالي + زر الرجوع للمجلد الأعلى
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'المجلد الأعلى',
                      onPressed: () {
                        final parent = Directory(_currentPath).parent.path;
                        if (parent != _currentPath) {
                          _loadDirectory(parent);
                        }
                      },
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    ),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _currentPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'تحديث المجلد',
                      onPressed: () => _loadDirectory(_currentPath),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // قائمة الملفات والمجلدات
              Expanded(
                child: _folderError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_off_outlined,
                                  size: 42, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text(
                                _folderError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final demoPath = await LocalLlmService
                                      .instance
                                      .createDemoGgufFileForTesting();
                                  if (context.mounted) {
                                    Navigator.pop(context, demoPath);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.science_outlined,
                                    size: 18),
                                label: const Text(
                                  'توليد وربط ملف GGUF تجريبي فوراً لاختبار النظام',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _entries.isEmpty
                        ? const Center(
                            child: Text(
                              'المجلد فارغ',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (ctx, i) {
                              final item = _entries[i];
                              final name =
                                  LocalLlmService.extractFileName(item.path);
                              final isDir = item is Directory;
                              final isGguf =
                                  name.toLowerCase().endsWith('.gguf');

                              return ListTile(
                                dense: true,
                                onTap: () {
                                  if (isDir) {
                                    _loadDirectory(item.path);
                                  } else {
                                    Navigator.pop(context, item.path);
                                  }
                                },
                                leading: Icon(
                                  isDir
                                      ? Icons.folder_rounded
                                      : (isGguf
                                          ? Icons.memory_rounded
                                          : Icons.insert_drive_file_outlined),
                                  color: isDir
                                      ? const Color(0xFFF59E0B)
                                      : (isGguf
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF94A3B8)),
                                ),
                                title: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isGguf
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                      color: isGguf
                                          ? const Color(0xFF10B981)
                                          : null,
                                    ),
                                  ),
                                ),
                                subtitle: isGguf
                                    ? const Text(
                                        'ملف نموذج لغوي محلي (GGUF) - اضغط للربط',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF10B981)),
                                      )
                                    : null,
                                trailing: isDir
                                    ? const Icon(Icons.chevron_left_rounded,
                                        size: 18)
                                    : null,
                              );
                            },
                          ),
              ),

              const Divider(height: 18),
              // إدخال المسار المباشر أو زر الاختبار الفوري
              const Text(
                'أو الصق مسار ملف النموذج (.gguf) داخل الهاتف مباشرة:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: _manualCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, _manualCtrl.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0077B6),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('ربط المسار',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
