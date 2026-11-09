import 'package:flutter/material.dart';
import '../data/initial_medical_data.dart';
import '../services/medical_rag_service.dart';

/// وحدة التحكم بالحالة والبيانات (MVVM ViewModel)
class AppController extends ChangeNotifier {
  bool isDarkMode = false;
  String language = 'العربية';
  String fontSizeLabel = 'متوسط';
  bool saveChats = true;
  bool notificationsEnabled = true;
  bool isLocalServerConnected = true;
  String selectedModel = 'Llama 3.1 (8B)';
  String ggufModelPath = '/storage/emulated/0/Models/llama-3.1-8b-med-q4_k_m.gguf';
  String knowledgeVersion = 'v2.4.0 (2026-10)';
  String userName = 'مستخدم';
  String userHandle = 'mediq_user';
  String userRole = 'مستخدم محلي (Local User)'; // أو مدير المعرفة (Knowledge Admin)
  String searchQuery = '';
  bool showFavoritesOnly = false;

  // الهوية الطبية والعلامات الحيوية
  Map<String, String> medicalId = InitialMedicalData.defaultMedicalId;
  List<Map<String, dynamic>> vitalsLog = InitialMedicalData.defaultVitalsLog;
  List<Map<String, dynamic>> medsList = InitialMedicalData.defaultMedsList;
  List<Map<String, String>> knowledgeDocs = InitialMedicalData.defaultKnowledgeDocs;
  final List<Map<String, dynamic>> chats = InitialMedicalData.defaultChats;

  double get fontScale {
    switch (fontSizeLabel) {
      case 'صغير':
        return 0.90;
      case 'كبير':
        return 1.12;
      default:
        return 1.0;
    }
  }

  List<Map<String, dynamic>> get filteredChats {
    return chats.where((chat) {
      final q = searchQuery.trim();
      final matchesSearch = q.isEmpty ||
          chat['title'].toString().contains(q) ||
          chat['subtitle'].toString().contains(q) ||
          chat['question'].toString().contains(q) ||
          (chat['category']?.toString().contains(q) ?? false);
      final matchesFav = !showFavoritesOnly || (chat['isFavorite'] == true);
      return matchesSearch && matchesFav;
    }).toList();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  void cycleFontSize() {
    fontSizeLabel = fontSizeLabel == 'صغير'
        ? 'متوسط'
        : fontSizeLabel == 'متوسط'
            ? 'كبير'
            : 'صغير';
    notifyListeners();
  }

  void cycleModel() {
    selectedModel = selectedModel.contains('Llama')
        ? 'Meditron (7B) - GGUF'
        : selectedModel.contains('Meditron')
            ? 'Gemma 2 (9B) - Med'
            : 'Llama 3.1 (8B)';
    notifyListeners();
  }

  void toggleRole() {
    userRole = userRole.contains('مدير')
        ? 'مستخدم محلي (Local User)'
        : 'مدير المعرفة (Knowledge Admin)';
    notifyListeners();
  }

  void toggleServerStatus() {
    isLocalServerConnected = !isLocalServerConnected;
    notifyListeners();
  }

  void toggleSaveChats(bool v) {
    saveChats = v;
    notifyListeners();
  }

  void toggleNotifications(bool v) {
    notificationsEnabled = v;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = chats.indexWhere((c) => c['id'] == id);
    if (idx != -1) {
      chats[idx]['isFavorite'] = !(chats[idx]['isFavorite'] ?? false);
      notifyListeners();
    }
  }

  void setSearchQuery(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setShowFavoritesOnly(bool v) {
    showFavoritesOnly = v;
    notifyListeners();
  }

  void addVital(String type, String val, String status) {
    vitalsLog.insert(0, {'date': 'الآن', 'type': type, 'val': val, 'status': status});
    notifyListeners();
  }

  void toggleMed(int index) {
    medsList[index]['status'] = !medsList[index]['status'];
    notifyListeners();
  }

  void addKnowledgeDocument(String title, String chunks) {
    knowledgeDocs.insert(0, {
      'title': title,
      'chunks': chunks,
      'status': 'مفهرس (FTS5 + Vector)',
      'version': 'v2.5-local',
    });
    knowledgeVersion = 'v2.5.0 (محدث محلياً)';
    notifyListeners();
  }

  // استدعاء طبقة الأمان والفلترة الطبية + محرك RAG الهجين من خدمة الـ Backend
  Map<String, dynamic> generateReply(String q) {
    final reply = MedicalRagService.generateReply(
      query: q,
      selectedModel: selectedModel,
      knowledgeVersion: knowledgeVersion,
    );

    if (saveChats) {
      chats.insert(0, reply);
      notifyListeners();
    }
    return reply;
  }
}

final AppController appController = AppController();
