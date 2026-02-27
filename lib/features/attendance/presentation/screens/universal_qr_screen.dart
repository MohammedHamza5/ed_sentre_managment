import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/repositories/attendance_repository.dart';

class UniversalQrScreen extends StatefulWidget {
  const UniversalQrScreen({super.key});

  @override
  State<UniversalQrScreen> createState() => _UniversalQrScreenState();
}

class _UniversalQrScreenState extends State<UniversalQrScreen> {
  String? _qrData;
  Timer? _qrTimer;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refreshQr();
    _qrTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshQr());
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshQr() async {
    try {
      final qr = await context.read<AttendanceRepository>().getUniversalQr();
      if (mounted) {
        setState(() {
          _qrData = qr;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل تحميل QR';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تسجيل الحضور العام',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Text(
                'امسح الكود لتسجيل الحضور',
                style: GoogleFonts.cairo(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                ),
              ),
            ),
            SizedBox(height: 40.h),
            _isLoading
                ? const CircularProgressIndicator()
                : _errorMessage != null
                ? Column(
                    children: [
                      Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                      SizedBox(height: 10.h),
                      Text(_errorMessage!, style: GoogleFonts.cairo()),
                      TextButton(
                        onPressed: () => setState(() => _isLoading = true),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  )
                : Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 300.w,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.purple,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.purple,
                      ),
                    ),
                  ),
            SizedBox(height: 40.h),
            Text(
              'يتغير الكود تلقائياً كل 15 ثانية',
              style: GoogleFonts.cairo(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
