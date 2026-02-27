
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../shared/models/models.dart';

class StudentExportService {
  static Future<Uint8List> generateStudentProfilePdf({
    required Student student,
    required List<Map<String, dynamic>> subjects,
    required double attendanceRate,
    List<AttendanceRecord>? attendance,
  }) async {
    final pdf = pw.Document();
    
    // Load Arabic Font
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    
    // Theme
    final theme = pw.ThemeData.withFont(
      base: font,
      bold: boldFont,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(32),
        ),
        header: (context) => _buildHeader(student),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(student, attendanceRate),
          pw.SizedBox(height: 20),
          _buildSubjectsSection(subjects),
          if (attendance != null && attendance.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildAttendanceSection(attendance),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(Student student) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('EdSentre', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.Text('مركز إد سنتر التعليمي', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
             pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('ملف الطالب', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildInfoSection(Student student, double attendanceRate) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('الاسم', student.name),
                _buildInfoRow('المرحلة', student.stage),
                _buildInfoRow('رقم الهاتف', student.phone),
                if (student.email != null) _buildInfoRow('البريد الإلكتروني', student.email!),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('الحالة', student.status.name == 'active' ? 'نشط' : 'غير نشط'),
                _buildInfoRow('تاريخ الميلاد', student.birthDate.toString().substring(0, 10)),
                _buildInfoRow('العنوان', student.address),
                _buildInfoRow('نسبة الحضور', '${attendanceRate.toStringAsFixed(1)}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.Text(value, style: const pw.TextStyle(color: PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _buildSubjectsSection(List<Map<String, dynamic>> subjects) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('المواد المسجلة', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('المادة', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('الرسوم', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('المعلم', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ],
            ),
            if (subjects.isEmpty)
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('لا توجد مواد', textAlign: pw.TextAlign.center)),
                pw.Text(''),
                pw.Text(''),
              ])
            else
              ...subjects.map((data) {
                final subject = data['subject'] as Subject?;
                final teacherNames = (data['teacher_names'] as List<dynamic>?)?.cast<String>() ?? [];
                
                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(subject?.name ?? '-', textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${subject?.monthlyFee ?? 0} ج', textAlign: pw.TextAlign.center)),
                     pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(teacherNames.isNotEmpty ? teacherNames.join(', ') : '-', textAlign: pw.TextAlign.center)),
                  ],
                );
              }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAttendanceSection(List<AttendanceRecord> attendance) {
    // Show only last 10 records
    final recentAttendance = attendance.take(10).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('سجل الحضور (آخر 10)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('التاريخ', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('الحالة', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('ملاحظات', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ],
            ),
             ...recentAttendance.map((record) {
                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(record.date.toString().substring(0, 10), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(_translateStatus(record.status), textAlign: pw.TextAlign.center)),
                     pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(record.notes ?? '-', textAlign: pw.TextAlign.center)),
                  ],
                );
              }),
          ],
        ),
      ],
    );
  }

  static String _translateStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present: return 'حاضر';
      case AttendanceStatus.absent: return 'غائب';
      case AttendanceStatus.late: return 'متأخر';
      case AttendanceStatus.excused: return 'بعذر';
    }
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('EdSentre Management System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }
}


