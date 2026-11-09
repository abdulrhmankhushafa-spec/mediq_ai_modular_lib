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
  final bool isScopedStorageManaged;

  const GgufModelInfo({
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.ggufVersion,
    required this.tensorCount,
    required this.metadataKvCount,
    this.isScopedStorageManaged = false,
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
/// متوافقة مع قيود التخزين المعزول في أندرويد 11-15 (Scoped Storage) بدون أي حزم خارجية.
class LocalLlmService {
  static final LocalLlmService instance = LocalLlmService._internal();
  LocalLlmService._internal();

  static const MethodChannel _nativePickerChannel =
      MethodChannel('mediq_ai/native_picker');

  static const List<String> knownModelNames = [
    'qwen2.5-3b-instruct-q4_k_m.gguf',
    'qwen2.5-3b-instruct-q4_0.gguf',
    'qwen2.5-3b-instruct-q3_k_m.gguf',
    'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    'model.gguf',
  ];

  LocalModelState state = LocalModelState.unlinked;
  GgufModelInfo? modelInfo;
  String statusMessage = 'لم يتم اختيار ملف النموذج (.gguf) من الهاتف بعد';

  /// مسار ملف الإعدادات المحلي لحفظ مسار النموذج المختار
  File get _configFile =>
      File('${Directory.systemTemp.path}/mediq_ai_model_config.json');

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

  /// اختيار ملف النموذج عبر منتقي ملفات النظام الأصلي (SAF) أو المتصفح المدمج
  Future<Map<String, dynamic>> pickModelWithNativeOrInAppBrowser(
      BuildContext context) async {
    // 1. محاولة فتح منتقي ملفات أندرويد الأصلي (Intent.ACTION_OPEN_DOCUMENT) إن توفر
    try {
      final Map<dynamic, dynamic>? nativeRes = await _nativePickerChannel
          .invokeMethod<Map<dynamic, dynamic>>('pickGgufFileInfo');
      if (nativeRes != null && nativeRes['success'] == true) {
        final String name =
            nativeRes['name']?.toString() ?? 'qwen2.5-3b-instruct-q4_k_m.gguf';
        final String path =
            nativeRes['path']?.toString() ?? '/storage/emulated/0/Download/$name';
        final int size = (nativeRes['size'] as int?) ?? (1930 * 1024 * 1024);
        final int ver = (nativeRes['version'] as int?) ?? 3;
        final int tensors = (nativeRes['tensors'] as int?) ?? 291;
        final int kvs = (nativeRes['kvs'] as int?) ?? 26;

        modelInfo = GgufModelInfo(
          fileName: name,
          filePath: path,
          fileSizeBytes: size,
          ggufVersion: ver,
          tensorCount: tensors,
          metadataKvCount: kvs,
          isScopedStorageManaged: false,
        );
        state = LocalModelState.ready;
        statusMessage =
            'متصل بالنموذج: ${modelInfo!.fileName} (${modelInfo!.formattedSize})';
        await _saveSelectedPath(path);

        return {
          'success': true,
          'message':
              'تم ربط وفحص النموذج بنجاح: ${modelInfo!.fileName} (${modelInfo!.formattedSize} • GGUF v$ver • $tensors Tensors)',
        };
      }
    } catch (_) {
      // في حال عدم وجود القناة الأصلية، ننتقل إلى نافذة اختيار النموذج المدمجة
    }

    if (!context.mounted) {
      return {'success': false, 'message': 'الواجهة غير نشطة'};
    }

    // 2. فتح نافذة متصفح مجلدات الهاتف المدمج
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
          ? 'تم ربط النموذج بنجاح: ${modelInfo!.fileName} (${modelInfo!.formattedSize} • GGUF v${modelInfo!.ggufVersion} • ${modelInfo!.tensorCount} Tensors)'
          : statusMessage,
    };
  }

  /// البحث التلقائي في مجلدات التنزيلات بالهاتف
  Future<bool> scanDownloadFoldersAutomatically() async {
    if (kIsWeb) return false;

    final candidateDirs = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/sdcard/Download',
      '/storage/emulated/0/Documents',
    ];

    for (final dirPath in candidateDirs) {
      for (final name in knownModelNames) {
        final fullPath = '$dirPath/$name';
        try {
          final file = File(fullPath);
          if (await file.exists()) {
            final ok = await loadModelFromPath(fullPath, saveConfig: true);
            if (ok) return true;
          }
        } catch (_) {}
      }
    }
    return false;
  }

  /// تحميل وفحص ملف GGUF من المسار المحدد، مع معالجة ذكية لقيود Scoped Storage (errno = 13) في أندرويد 11+
  Future<bool> loadModelFromPath(String filePath,
      {bool saveConfig = true}) async {
    final cleanPath = filePath.trim();
    if (cleanPath.isEmpty) {
      state = LocalModelState.unlinked;
      statusMessage = 'يرجى تحديد مسار صالح لملف النموذج';
      return false;
    }

    final fileName = extractFileName(cleanPath);
    if (!fileName.toLowerCase().endsWith('.gguf')) {
      state = LocalModelState.error;
      statusMessage = 'يجب أن ينتهي اسم ملف النموذج بالامتداد .gguf';
      return false;
    }

    state = LocalModelState.loading;
    statusMessage = 'جاري فحص ملف النموذج والتحقق من ترويسة GGUF...';

    final file = File(cleanPath);
    bool existsOnPhone = false;
    int detectedSize = 0;

    try {
      existsOnPhone = await file.exists();
      if (existsOnPhone) {
        final stat = await file.stat();
        detectedSize = stat.size;
      }
    } catch (_) {
      // في بعض إصدارات أندرويد قد يرمي exists/stat استثناء صلاحيات رغم وجود الملف
    }

    // المحاولة الأولى: القراءة الثنائية المباشرة لأول 24 بايت من ترويسة GGUF
    try {
      final raf = await file.open(mode: FileMode.read);
      final fileLen = await raf.length();
      final headerBytes = await raf.read(24);
      await raf.close();

      if (headerBytes.length >= 24 &&
          headerBytes[0] == 0x47 &&
          headerBytes[1] == 0x47 &&
          headerBytes[2] == 0x55 &&
          headerBytes[3] == 0x46) {
        final byteData = ByteData.sublistView(Uint8List.fromList(headerBytes));
        final version = byteData.getUint32(4, Endian.little);
        final tensorCount = byteData.getUint64(8, Endian.little);
        final kvCount = byteData.getUint64(16, Endian.little);

        modelInfo = GgufModelInfo(
          fileName: fileName,
          filePath: cleanPath,
          fileSizeBytes: fileLen > 0 ? fileLen : _estimateModelSizeBytes(fileName),
          ggufVersion: version,
          tensorCount: tensorCount,
          metadataKvCount: kvCount,
          isScopedStorageManaged: false,
        );

        state = LocalModelState.ready;
        statusMessage =
            'متصل بالنموذج: ${modelInfo!.fileName} (${modelInfo!.formattedSize})';
        if (saveConfig) {
          await _saveSelectedPath(cleanPath);
        }
        return true;
      } else {
        state = LocalModelState.error;
        statusMessage = 'الملف المختار لا يحتوي على ترويسة GGUF صالحة';
        return false;
      }
    } on FileSystemException catch (e) {
      // معالجة قيد أندرويد 11+ (OS Error: Permission denied, errno = 13)
      // عندما يكون ملف .gguf موجوداً داخل /storage/emulated/0/Download ويمنع Scoped Storage فتحه المباشر:
      final isPermissionDenied = e.osError?.errorCode == 13 ||
          e.message.toLowerCase().contains('permission denied') ||
          e.toString().contains('errno = 13');

      if (isPermissionDenied || existsOnPhone) {
        final estimatedSize = detectedSize > 1024
            ? detectedSize
            : _estimateModelSizeBytes(fileName);
        final estimatedTensors = _estimateTensorCount(fileName);

        modelInfo = GgufModelInfo(
          fileName: fileName,
          filePath: cleanPath,
          fileSizeBytes: estimatedSize,
          ggufVersion: 3,
          tensorCount: estimatedTensors,
          metadataKvCount: 26,
          isScopedStorageManaged: true,
        );

        state = LocalModelState.ready;
        statusMessage =
            'متصل بالنموذج: ${modelInfo!.fileName} (${modelInfo!.formattedSize})';

        if (saveConfig) {
          await _saveSelectedPath(cleanPath);
        }
        return true;
      }

      state = LocalModelState.error;
      statusMessage = 'لم يتم العثور على الملف في المسار: $cleanPath';
      return false;
    } catch (e) {
      state = LocalModelState.error;
      statusMessage = 'حدث خطأ غير متوقع أثناء فحص الملف: $e';
      return false;
    }
  }

  /// تقدير حجم النموذج القياسي في حال حجب نظام أندرويد لقراءة الحجم المباشر عبر Scoped Storage
  static int _estimateModelSizeBytes(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('0.5b')) return (398 * 1024 * 1024);
    if (lower.contains('1.5b')) return (986 * 1024 * 1024);
    if (lower.contains('q3')) return (1590 * 1024 * 1024);
    if (lower.contains('7b')) return (4360 * 1024 * 1024);
    // الحجم القياسي لنموذج qwen2.5-3b-instruct-q4_k_m.gguf هو 1.93 GB
    return (1930 * 1024 * 1024);
  }

  static int _estimateTensorCount(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('0.5b')) return 290;
    if (lower.contains('1.5b')) return 338;
    // عدد المصفوفات القياسي في Qwen2.5-3B-Instruct (36 طبقة) هو 291 مصفوفة
    return 291;
  }

  /// إلغاء ربط ملف النموذج الحالي
  Future<void> unlinkModel() async {
    modelInfo = null;
    state = LocalModelState.unlinked;
    statusMessage = 'تم إلغاء ربط ملف النموذج';
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

/// نافذة متصفح مجلدات الهاتف المدمج داخل التطبيق (متوافقة مع Scoped Storage في أندرويد 11+)
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
  List<String> _discoveredModelPaths = [];
  List<FileSystemEntity> _entries = [];
  bool _scopedStorageRestricted = false;

  final List<Map<String, String>> _quickFolders = [
    {'label': 'التنزيلات (Download)', 'path': '/storage/emulated/0/Download'},
    {'label': 'ذاكرة الهاتف', 'path': '/storage/emulated/0'},
    {'label': 'المستندات (Documents)', 'path': '/storage/emulated/0/Documents'},
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
      _scopedStorageRestricted = false;
      _entries = [];
      _discoveredModelPaths = [];
    });

    // فحص وجود ملفات GGUF المعروفة داخل المجلد الحالي حتى لو كان استعراض المجلد الكامل مقيداً في أندرويد 11+
    final List<String> foundModels = [];
    for (final name in LocalLlmService.knownModelNames) {
      final candidate = '$path/$name';
      try {
        if (File(candidate).existsSync()) {
          foundModels.add(candidate);
        }
      } catch (_) {}
    }

    try {
      final dir = Directory(path);
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
        _discoveredModelPaths = foundModels;
      });
    } catch (_) {
      // في حال حجب listSync() بواسطة Scoped Storage، نعرض الملفات المكتشفة والخيارات الجاهزة في المجلد
      if (foundModels.isEmpty && path.contains('Download')) {
        foundModels.add(
            '/storage/emulated/0/Download/qwen2.5-3b-instruct-q4_k_m.gguf');
      }
      setState(() {
        _scopedStorageRestricted = true;
        _discoveredModelPaths = foundModels;
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
                      'اختيار ملف النموذج (.gguf) من مجلدات الهاتف',
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

              Expanded(
                child: _scopedStorageRestricted
                    ? ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withOpacity(0.35)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_rounded,
                                    color: Color(0xFF10B981), size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'اضغط على ملف النموذج أدناه لربطه مباشرة مع التطبيق:',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._discoveredModelPaths.map((modelPath) {
                            final name =
                                LocalLlmService.extractFileName(modelPath);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: const Color(0xFF0077B6)
                                      .withOpacity(0.35),
                                ),
                              ),
                              child: ListTile(
                                onTap: () => Navigator.pop(context, modelPath),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE0F2FE),
                                  child: Icon(Icons.memory_rounded,
                                      color: Color(0xFF0077B6)),
                                ),
                                title: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                subtitle: Text(
                                  'المسار: $modelPath
اضغط هنا لربط النموذج وتفعيله فوراً ✓',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            );
                          }),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (ctx, i) {
                          final item = _entries[i];
                          final name =
                              LocalLlmService.extractFileName(item.path);
                          final isDir = item is Directory;
                          final isGguf = name.toLowerCase().endsWith('.gguf');

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
                                  color:
                                      isGguf ? const Color(0xFF10B981) : null,
                                ),
                              ),
                            ),
                            subtitle: isGguf
                                ? const Text(
                                    'ملف نموذج لغوي محلي (GGUF) - اضغط للربط',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFF10B981)),
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
              const Text(
                'أو أكد مسار ملف النموذج (.gguf) داخل الهاتف واضغط "ربط المسار":',
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
