/// Schedule Models - EdSentre
library;

import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SCHEDULE - نموذج الحصة
// ═══════════════════════════════════════════════════════════════════════════

enum SessionStatus { scheduled, ongoing, completed, cancelled }

class ScheduleSession extends Equatable {
  final String id;
  final String subjectId;
  final String subjectName;
  final String teacherId;
  final String teacherName;
  final String roomId;
  final String roomName;
  final int dayOfWeek; // 0 = السبت
  final String startTime;
  final String endTime;
  final SessionStatus status;
  final String? gradeLevel; // Restored
  final String? groupName; // NEW: To identify group sessions
  final String? groupId;   // NEW: Link to parent group

  const ScheduleSession({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.roomId,
    required this.roomName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.gradeLevel, // Restored
    this.groupName,
    this.groupId,
  });

  ScheduleSession copyWith({
    String? id,
    String? subjectId,
    String? subjectName,
    String? teacherId,
    String? teacherName,
    String? roomId,
    String? roomName,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    SessionStatus? status,
    String? gradeLevel,
    String? groupName,
    String? groupId,
  }) {
    return ScheduleSession(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      groupName: groupName ?? this.groupName,
      groupId: groupId ?? this.groupId,
    );
  }

  /// Create from JSON map
  factory ScheduleSession.fromJson(Map<String, dynamic> json) {
    // Correct mapping for courses/subjects and classrooms/rooms
    // API returns 'courses' but model expecting 'subjects' logic
    final subjName = json['subject_name'] ?? 
                     json['courses']?['name'] ?? 
                     json['subjects']?['name'];
                     
    final grpName = json['group_name'] ?? json['groups']?['group_name'];
    
    // Fallback: If subject name is missing, use group name
    final finalSubjectName = (subjName?.toString().isNotEmpty == true) 
        ? subjName 
        : (grpName ?? 'مادة غير محددة');

    return ScheduleSession(
      id: json['id'] ?? '',
      subjectId: json['subject_id'] ?? json['course_id'] ?? '',
      subjectName: finalSubjectName,
      teacherId: json['teacher_id'] ?? '',
      teacherName: json['teacher_name'] ?? json['teachers']?['full_name'] ?? json['teachers']?['name'] ?? '', // Handle full_name from users join if applicable
      roomId: json['room_id'] ?? json['classroom_id'] ?? '',
      roomName: json['room_name'] ?? json['classrooms']?['name'] ?? json['rooms']?['name'] ?? '',
      dayOfWeek: _parseDay(json['day_of_week']),
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      status: _parseStatus(json['status']),
      gradeLevel: json['grade_level'],
      groupName: grpName,
      groupId: json['group_id'],
    );
  }
  
  static int _parseDay(dynamic day) {
    if (day is int) return day;
    if (day is String) {
      switch(day.toLowerCase()) {
        case 'saturday': return 0;
        case 'sunday': return 1;
        case 'monday': return 2;
        case 'tuesday': return 3;
        case 'wednesday': return 4;
        case 'thursday': return 5;
        case 'friday': return 6;
      }
    }
    return 0;
  }

  static SessionStatus _parseStatus(String? value) {
    switch (value) {
      case 'ongoing':
        return SessionStatus.ongoing;
      case 'completed':
        return SessionStatus.completed;
      case 'cancelled':
        return SessionStatus.cancelled;
      default:
        return SessionStatus.scheduled;
    }
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'room_id': roomId,
      'room_name': roomName,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'status': status.name,
      'grade_level': gradeLevel,
      'group_name': groupName,
      'group_id': groupId,
    };
  }

  @override
  List<Object?> get props => [id, subjectId, dayOfWeek, startTime, gradeLevel, status, groupId];
}


