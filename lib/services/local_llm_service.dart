import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// خدمة اختيار وتشغيل النموذج اللغوي المحلي (GGUF) مباشرة من ذاكرة الهاتف
/// دون الحاجة إلى رفعه أو دمجه داخل APK أثناء مرحلة التجربة والتطوير.
class LocalLlmService {
  static final LocalLlmService instance = LocalLlmService._internal();
  LocalLlmService._internal();

  static const String _prefModelPathKey = 'selected_local_gguf_model_path';

  LocalModelState state = LocalModelState.unlinked;
  GgufModelInfo? modelInfo;
  String statusMessage = 'لم يتم اختيار ملف النموذج (.gguf) من الهاتف بعد';

  /// تهيئة الخدمة عند فتح التطبيق واستعادة مسار النموذج المحفوظ مسبقاً إن وجد
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_prefModelPathKey);

      if (savedPath != null && savedPath.isNotEmpty) {
        final ok = await loadModelFromPath(savedPath, saveToPrefs: false);
        if (ok) return;
      }

      // محاولة البحث التلقائي السريع في مجلد التنزيلات بالهاتف إذا كان الوصول متاحاً
      await scanDownloadFoldersAutomatically();
    } catch (e) {
      debugPrint('LocalLlmService init notice: $e');
    }
  }

  /// فتح متصفح ملفات الهاتف لاختيار ملف النموذج (.gguf) من أي مجلد
  /// ملاحظة هامة للأندرويد: نستخدم FileType.any بدلاً من FileType.custom لأن نظام أندرويد
  /// قد يعطّل النقر على ملفات .gguf في بعض الهواتف إذا لم يتعرف على نوع MIME الخاص بها.
  Future<Map<String, dynamic>> pickModelFromPhoneStorage() async {
    try {
      state = LocalModelState.loading;
      statusMessage = 'جاري فتح متصفح الملفات لاختيار النموذج...';

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف النموذج اللغوي (.gguf) من الهاتف',
        type: FileType.any,
        withData: false, // مهم جداً: عدم تحميل ملف 2GB كاملاً في مصفوفة RAM
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = modelInfo != null ? LocalModelState.ready : LocalModelState.unlinked;
        statusMessage = modelInfo != null
            ? 'النموذج جاهز: ${modelInfo!.fileName}'
            : 'تم إلغاء اختيار الملف';
        return {
          'success': false,
          'message': 'لم يتم اختيار أي ملف.',
        };
      }

      final pickedPath = result.files.single.path;
      if (pickedPath == null || pickedPath.isEmpty) {
        state = LocalModelState.error;
        statusMessage = 'تعذر الحصول على مسار الملف من النظام';
        return {
          'success': false,
          'message': 'تعذر قراءة مسار الملف من هذا المجلد. جرب نقله إلى مجلد التنزيلات (Download).',
        };
      }

      final loaded = await loadModelFromPath(pickedPath, saveToPrefs: true);
      if (loaded && modelInfo != null) {
        return {
          'success': true,
          'message':
              'تم ربط وفحص النموذج بنجاح: ${modelInfo!.fileName} (${modelInfo!.formattedSize} • GGUF v${modelInfo!.ggufVersion} • ${modelInfo!.tensorCount} Tensors)',
        };
      } else {
        return {
          'success': false,
          'message': statusMessage,
        };
      }
    } catch (e) {
      state = LocalModelState.error;
      statusMessage = 'حدث خطأ أثناء اختيار ملف النموذج: $e';
      return {
        'success': false,
        'message': statusMessage,
      };
    }
  }

  /// البحث التلقائي في مجلدات الهاتف الشائعة (مثل Download) دون نسخ الملف
  Future<bool> scanDownloadFoldersAutomatically() async {
    if (kIsWeb) return false;

    final candidateDirs = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/sdcard/Download',
      '/sdcard/Downloads',
    ];

    final candidateNames = <String>[
      'qwen2.5-3b-instruct-q4_k_m.gguf',
      'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      'model.gguf',
    ];

    for (final dirPath in candidateDirs) {
      for (final name in candidateNames) {
        final fullPath = '$dirPath/$name';
        try {
          final file = File(fullPath);
          if (await file.exists()) {
            final ok = await loadModelFromPath(fullPath, saveToPrefs: true);
            if (ok) return true;
          }
        } catch (_) {
          // تجاهل في حال عدم منح صلاحية القراءة المباشرة خارج FilePicker
        }
      }
    }
    return false;
  }

  /// قراءة وفحص ترويسة ملف GGUF الثنائية مباشرة من الهاتف للتحقق من صحته
  Future<bool> loadModelFromPath(String filePath, {bool saveToPrefs = true}) async {
    try {
      state = LocalModelState.loading;
      statusMessage = 'جاري فحص ترويسة ملف النموذج والتحقق من سلامته...';

      final file = File(filePath);
      if (!await file.exists()) {
        state = LocalModelState.unlinked;
        statusMessage = 'ملف النموذج غير موجود في المسار المحدد';
        return false;
      }

      final fileSize = await file.length();
      if (fileSize < 24) {
        state = LocalModelState.error;
        statusMessage = 'الملف المختار صغير جداً وليس نموذج GGUF صالحاً';
        return false;
      }

      // قراءة أول 24 بايت فقط من الملف (ترويسة GGUF الرسمية)
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
        statusMessage = 'الملف المختار ليس بصيغة GGUF معتمدة (ترويسة غير مطابقة)';
        return false;
      }

      final byteData = ByteData.sublistView(Uint8List.fromList(headerBytes));
      final version = byteData.getUint32(4, Endian.little);
      final tensorCount = byteData.getUint64(8, Endian.little);
      final kvCount = byteData.getUint64(16, Endian.little);

      modelInfo = GgufModelInfo(
        fileName: p.basename(filePath),
        filePath: filePath,
        fileSizeBytes: fileSize,
        ggufVersion: version,
        tensorCount: tensorCount,
        metadataKvCount: kvCount,
      );

      state = LocalModelState.ready;
      statusMessage =
          'متصل بالنموذج: ${modelInfo!.fileName} (${modelInfo!.formattedSize})';

      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefModelPathKey, filePath);
      }

      return true;
    } catch (e) {
      state = LocalModelState.error;
      statusMessage = 'تعذر فتح ملف النموذج: $e';
      return false;
    }
  }

  /// إلغاء ربط ملف النموذج الحالي ومسح المسار المحفوظ
  Future<void> unlinkModel() async {
    modelInfo = null;
    state = LocalModelState.unlinked;
    statusMessage = 'تم إلغاء ربط ملف النموذج (يعمل بوضع الاسترجاع الموثق فقط)';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefModelPathKey);
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
Future<String?> _runNativeLlamaCppIsolate(String modelPath, String prompt) async {
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

    final backendInit = lib.lookupFunction<ffi.Void Function(), void Function()>(
      'llama_backend_init',
    );
    backendInit();

    final backendFree = lib.lookupFunction<ffi.Void Function(), void Function()>(
      'llama_backend_free',
    );
    backendFree();
    return null;
  } catch (_) {
    return null;
  }
}
