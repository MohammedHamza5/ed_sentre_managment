import 'package:equatable/equatable.dart';

/// حالة جلسة QR للحضور — مختلفة عن SessionStatus في schedule_models.dart
/// { scheduled, ongoing, completed, cancelled } تلك للجدول الدراسي
/// هذه مخصصة لجلسات QR Code فقط
enum QrSessionStatus { scheduled, open, locked, closed }

class AttendanceSession extends Equatable {
  final String id;
  final String groupId;
  final QrSessionStatus status;
  final DateTime opensAt;
  final DateTime? closesAt;
  final DateTime? onTimeUntil;
  final String? qrCodeRotationKey;
  final DateTime createdAt;

  const AttendanceSession({
    required this.id,
    required this.groupId,
    required this.status,
    required this.opensAt,
    this.closesAt,
    this.onTimeUntil,
    this.qrCodeRotationKey,
    required this.createdAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      status: QrSessionStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'scheduled'),
        orElse: () => QrSessionStatus.scheduled,
      ),
      opensAt: DateTime.parse(json['opens_at'] as String),
      closesAt: json['closes_at'] != null
          ? DateTime.parse(json['closes_at'] as String)
          : null,
      onTimeUntil: json['on_time_until'] != null
          ? DateTime.parse(json['on_time_until'] as String)
          : null,
      qrCodeRotationKey: json['qr_code_rotation_key'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'status': status.name,
      'opens_at': opensAt.toIso8601String(),
      'closes_at': closesAt?.toIso8601String(),
      'on_time_until': onTimeUntil?.toIso8601String(),
      'qr_code_rotation_key': qrCodeRotationKey,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// هل الجلسة مفتوحة حالياً لتسجيل الحضور؟
  bool get isOpen => status == QrSessionStatus.open;

  /// هل الجلسة مقفلة (لا يمكن تسجيل حضور جديد)؟
  bool get isLocked => status == QrSessionStatus.locked;

  /// هل الجلسة مغلقة نهائياً؟
  bool get isClosed => status == QrSessionStatus.closed;

  @override
  List<Object?> get props => [
        id,
        groupId,
        status,
        opensAt,
        closesAt,
        onTimeUntil,
        qrCodeRotationKey,
        createdAt,
      ];
}
