
import '../../../shared/models/models.dart';

/// نتيجة فحص التعارض
enum ConflictType {
  none,
  roomOccupied,    // القاعة مشغولة (Blocking)
  teacherBusy,     // المعلم مشغول (Blocking)
  gradeConcurrency, // نفس المرحلة (Warning)
}

class ValidationResult {
  final ConflictType type;
  final String? message;
  final ScheduleSession? conflictingSession;

  ValidationResult({
    required this.type,
    this.message,
    this.conflictingSession,
  });

  bool get isBlocking => 
      type == ConflictType.roomOccupied || type == ConflictType.teacherBusy;
      
  bool get isWarning => 
      type == ConflictType.gradeConcurrency;
}

class ScheduleValidator {
  
  /// التحقق من جميع التعارضات
  static ValidationResult validateSession({
    required ScheduleSession newSession,
    required List<ScheduleSession> existingSessions,
  }) {
    // 1. تجاهل الحصص الملغاة أثناء الفحص
    final activeSessions = existingSessions.where(
      (s) => s.status != SessionStatus.cancelled && s.id != newSession.id
    ).toList();

    // 2. فحص تضارب القاعات (Room Conflict)
    final roomConflict = activeSessions.firstWhere(
      (s) => 
        s.roomId == newSession.roomId && 
        s.dayOfWeek == newSession.dayOfWeek &&
        _isOverlapping(s, newSession),
      orElse: () => _emptySession,
    );

    if (roomConflict != _emptySession) {
      return ValidationResult(
        type: ConflictType.roomOccupied,
        message: 'القاعة مشغولة في هذا التوقيت بواسطة ${roomConflict.subjectName}',
        conflictingSession: roomConflict,
      );
    }

    // 3. فحص تضارب المعلم (Teacher Conflict)
    final teacherConflict = activeSessions.firstWhere(
      (s) => 
        s.teacherId == newSession.teacherId && 
        s.dayOfWeek == newSession.dayOfWeek &&
        _isOverlapping(s, newSession),
      orElse: () => _emptySession,
    );

    if (teacherConflict != _emptySession) {
      return ValidationResult(
        type: ConflictType.teacherBusy,
        message: 'المعلم لديه حصة أخرى (${teacherConflict.subjectName}) في نفس التوقيت',
        conflictingSession: teacherConflict,
      );
    }

    // 4. فحص تزامن المرحلة (Grade Concurrency) - تحذير فقط
    if (newSession.gradeLevel != null) {
      final gradeConflict = activeSessions.firstWhere(
        (s) => 
          s.gradeLevel == newSession.gradeLevel && 
          s.dayOfWeek == newSession.dayOfWeek &&
          _isOverlapping(s, newSession),
        orElse: () => _emptySession,
      );

      if (gradeConflict != _emptySession) {
        return ValidationResult(
          type: ConflictType.gradeConcurrency,
          message: 'يوجد حصة أخرى لنفس المرحلة (${gradeConflict.subjectName}) في نفس التوقيت',
          conflictingSession: gradeConflict,
        );
      }
    }

    return ValidationResult(type: ConflictType.none);
  }

  /// هل يوجد تداخل في الوقت؟
  static bool _isOverlapping(ScheduleSession s1, ScheduleSession s2) {
    // تحويل الوقت إلى دقائق للمقارنة (HH:mm)
    final start1 = _toMinutes(s1.startTime);
    final end1 = _toMinutes(s1.endTime);
    final start2 = _toMinutes(s2.startTime);
    final end2 = _toMinutes(s2.endTime);

    return start1 < end2 && start2 < end1;
  }

  static int _toMinutes(String time) {
    try {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  // Session فارغة للمقارنة
  static final _emptySession = ScheduleSession(
    id: 'temp',
    subjectId: '',
    subjectName: '',
    teacherId: '',
    teacherName: '',
    roomId: '',
    roomName: '',
    dayOfWeek: -1,
    startTime: '',
    endTime: '',
    status: SessionStatus.cancelled,
  );
}


