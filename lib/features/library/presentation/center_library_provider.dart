import 'dart:io';
import 'package:flutter/material.dart';
import '../data/center_library_repository.dart';

/// Provider for Center Library feature
class CenterLibraryProvider with ChangeNotifier {
  final CenterLibraryRepository _repository;
  final String centerId;

  List<CenterLibraryBook> _books = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isUploading = false;
  String _uploadStatus = '';

  CenterLibraryProvider({
    required CenterLibraryRepository repository,
    required this.centerId,
  }) : _repository = repository;

  List<CenterLibraryBook> get books => _books;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUploading => _isUploading;
  String get uploadStatus => _uploadStatus;

  Future<void> fetchBooks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _books = await _repository.getCenterBooks(centerId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadBook({
    required File pdfFile,
    required String title,
    required String subject,
    String? academicYear,
  }) async {
    _isUploading = true;
    _uploadStatus = 'جاري استخراج النص من الملف...';
    notifyListeners();

    try {
      _uploadStatus = 'جاري رفع الكتاب ومعالجته بالذكاء الاصطناعي...';
      notifyListeners();

      await _repository.uploadCenterBook(
        centerId: centerId,
        pdfFile: pdfFile,
        title: title,
        subject: subject,
        academicYear: academicYear,
      );

      _uploadStatus = 'تم الرفع والمعالجة بنجاح!';
      notifyListeners();

      await fetchBooks(); // Refresh
      return true;
    } catch (e) {
      _uploadStatus = 'فشل: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> deleteBook(String bookId) async {
    try {
      await _repository.deleteBook(bookId);
      _books.removeWhere((b) => b.id == bookId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete book: $e');
    }
  }
}
