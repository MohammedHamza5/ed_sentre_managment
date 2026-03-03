import 'dart:io';
import 'package:ed_sentre/core/supabase/supabase_client.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Model for a library book
class CenterLibraryBook {
  final String id;
  final String title;
  final String subject;
  final String? academicYear;
  final String? centerId;
  final bool isProcessed;
  final DateTime createdAt;

  CenterLibraryBook({
    required this.id,
    required this.title,
    required this.subject,
    this.academicYear,
    this.centerId,
    required this.isProcessed,
    required this.createdAt,
  });

  factory CenterLibraryBook.fromJson(Map<String, dynamic> json) {
    return CenterLibraryBook(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      academicYear: json['academic_year'] as String?,
      centerId: json['center_id'] as String?,
      isProcessed: json['is_processed'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Repository handling Center-specific book operations
class CenterLibraryRepository {
  SupabaseClient get _supabase => SupabaseClientManager.client;

  /// Fetch books belonging to a specific center
  Future<List<CenterLibraryBook>> getCenterBooks(String centerId) async {
    final response = await _supabase
        .from('library_books')
        .select('*')
        .eq('center_id', centerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => CenterLibraryBook.fromJson(json))
        .toList();
  }

  /// Delete a book
  Future<void> deleteBook(String bookId) async {
    await _supabase.from('library_books').delete().eq('id', bookId);
  }

  /// Extract text from a PDF file using Syncfusion (runs in a background isolate)
  Future<String?> extractTextFromPdf(String filePath) async {
    return await compute(_extractTextIsolate, filePath);
  }

  static String? _extractTextIsolate(String filePath) {
    try {
      final file = File(filePath);
      final bytes = file.readAsBytesSync();
      final document = PdfDocument(inputBytes: bytes);
      final String fullText = PdfTextExtractor(document).extractText();
      document.dispose();
      return fullText.trim().isEmpty ? null : fullText;
    } catch (e) {
      debugPrint('❌ PDF Extraction Error: $e');
      return null;
    }
  }

  /// Upload a center-specific book and process it via Edge Function
  Future<void> uploadCenterBook({
    required String centerId,
    required File pdfFile,
    required String title,
    required String subject,
    String? academicYear,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception('المستخدم غير مسجل الدخول');

    // 1. Create book record in DB
    final bookResponse = await _supabase
        .from('library_books')
        .insert({
          'title': title,
          'subject': subject,
          'academic_year': academicYear,
          'uploaded_by': currentUser.id,
          'center_id': centerId, // ← Center-specific!
        })
        .select()
        .single();

    final bookId = bookResponse['id'] as String;

    // 2. Extract text locally (in a background isolate)
    final rawText = await extractTextFromPdf(pdfFile.path);
    if (rawText == null || rawText.trim().isEmpty) {
      await deleteBook(bookId); // Cleanup
      throw Exception(
        'فشل في استخراج النص من الملف. ربما هو عبارة عن صور فقط وليس نصوص.',
      );
    }

    // 3. Send to process-book Edge Function
    try {
      final response = await _supabase.functions.invoke(
        'process-book',
        body: {'book_id': bookId, 'raw_text': rawText},
      );

      if (response.status != 200) {
        throw Exception(
          'فشل الذكاء في معالجة الكتاب (HTTP ${response.status})',
        );
      }
    } catch (e) {
      debugPrint('❌ Edge Function Error: $e');
      rethrow;
    }
  }
}
