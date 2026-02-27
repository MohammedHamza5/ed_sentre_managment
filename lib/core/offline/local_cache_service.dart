import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../shared/models/models.dart';

/// خدمة التخزين المحلي (Cache)
/// تستخدم SharedPreferences للتخزين البسيط والسريع
class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  // Keys للتخزين
  static const String _keyStudents = 'cache_students';
  static const String _keyTeachers = 'cache_teachers';
  static const String _keySubjects = 'cache_subjects';
  static const String _keyRooms = 'cache_rooms';
  static const String _keySessions = 'cache_sessions';
  static const String _keyPayments = 'cache_payments';
  static const String _keyCacheTimestamp = 'cache_timestamp';
  static const String _keyCenterId = 'cache_center_id';

  SharedPreferences? _prefs;

  /// تهيئة الخدمة
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    debugPrint('💾 [Cache] تم تهيئة خدمة التخزين المحلي');
  }

  /// التأكد من التهيئة
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  Future<String> _composeKey(String base) async {
    final cid = await getCenterId();
    if (cid == null || cid.isEmpty) return base;
    return '${base}_$cid';
  }

  // ═══════════════════════════════════════════════════════════════
  // الطلاب
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveStudents(List<Student> students) async {
    final prefs = await _getPrefs();
    final data = students.map((s) => _studentToMap(s)).toList();
    final key = await _composeKey(_keyStudents);
    await prefs.setString(key, jsonEncode(data));
    await _updateTimestamp();
    debugPrint('💾 [Cache] حفظ ${students.length} طالب');
  }

  Future<List<Student>> getStudents() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keyStudents);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    
    try {
      final list = jsonDecode(data) as List;
      final students = list.map((m) => _mapToStudent(m)).toList();
      debugPrint('💾 [Cache] جلب ${students.length} طالب من Cache');
      return students;
    } catch (e) {
      debugPrint('⚠️ [Cache] خطأ في قراءة الطلاب: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // المعلمين
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveTeachers(List<Teacher> teachers) async {
    final prefs = await _getPrefs();
    final data = teachers.map((t) => _teacherToMap(t)).toList();
    final key = await _composeKey(_keyTeachers);
    await prefs.setString(key, jsonEncode(data));
    await _updateTimestamp();
    debugPrint('💾 [Cache] حفظ ${teachers.length} معلم');
  }

  Future<List<Teacher>> getTeachers() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keyTeachers);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    
    try {
      final list = jsonDecode(data) as List;
      final teachers = list.map((m) => _mapToTeacher(m)).toList();
      debugPrint('💾 [Cache] جلب ${teachers.length} معلم من Cache');
      return teachers;
    } catch (e) {
      debugPrint('⚠️ [Cache] خطأ في قراءة المعلمين: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // المواد
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveSubjects(List<Subject> subjects) async {
    final prefs = await _getPrefs();
    final data = subjects.map((s) => _subjectToMap(s)).toList();
    final key = await _composeKey(_keySubjects);
    await prefs.setString(key, jsonEncode(data));
    await _updateTimestamp();
    debugPrint('💾 [Cache] حفظ ${subjects.length} مادة');
  }

  Future<List<Subject>> getSubjects() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keySubjects);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    
    try {
      final list = jsonDecode(data) as List;
      final subjects = list.map((m) => _mapToSubject(m)).toList();
      debugPrint('💾 [Cache] جلب ${subjects.length} مادة من Cache');
      return subjects;
    } catch (e) {
      debugPrint('⚠️ [Cache] خطأ في قراءة المواد: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // القاعات
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveRooms(List<Room> rooms) async {
    final prefs = await _getPrefs();
    final data = rooms.map((r) => _roomToMap(r)).toList();
    final key = await _composeKey(_keyRooms);
    await prefs.setString(key, jsonEncode(data));
    await _updateTimestamp();
    debugPrint('💾 [Cache] حفظ ${rooms.length} قاعة');
  }

  Future<List<Room>> getRooms() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keyRooms);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    
    try {
      final list = jsonDecode(data) as List;
      final rooms = list.map((m) => _mapToRoom(m)).toList();
      debugPrint('💾 [Cache] جلب ${rooms.length} قاعة من Cache');
      return rooms;
    } catch (e) {
      debugPrint('⚠️ [Cache] خطأ في قراءة القاعات: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // الحصص (ScheduleSession)
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveSessions(List<ScheduleSession> sessions) async {
    final prefs = await _getPrefs();
    final data = sessions.map((s) => _sessionToMap(s)).toList();
    final key = await _composeKey(_keySessions);
    await prefs.setString(key, jsonEncode(data));
    await _updateTimestamp();
    debugPrint('💾 [Cache] حفظ ${sessions.length} حصة');
  }

  Future<List<ScheduleSession>> getSessions() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keySessions);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    
    try {
      final list = jsonDecode(data) as List;
      final sessions = list.map((m) => _mapToSession(m)).toList();
      debugPrint('💾 [Cache] جلب ${sessions.length} حصة من Cache');
      return sessions;
    } catch (e) {
      debugPrint('⚠️ [Cache] خطأ في قراءة الحصص: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // المدفوعات
  // ═══════════════════════════════════════════════════════════════

  Future<void> savePayments(List<Payment> payments) async {
    final prefs = await _getPrefs();
    final data = payments.map((p) => _paymentToMap(p)).toList();
    final key = await _composeKey(_keyPayments);
    await prefs.setString(key, jsonEncode(data));
    await _updateTimestamp();
    debugPrint('💾 [Cache] حفظ ${payments.length} دفعة');
  }

  Future<List<Payment>> getPayments() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keyPayments);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    
    try {
      final list = jsonDecode(data) as List;
      final payments = list.map((m) => _mapToPayment(m)).toList();
      debugPrint('💾 [Cache] جلب ${payments.length} دفعة من Cache');
      return payments;
    } catch (e) {
      debugPrint('⚠️ [Cache] خطأ في قراءة المدفوعات: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // أدوات عامة
  // ═══════════════════════════════════════════════════════════════

  Future<void> _updateTimestamp() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keyCacheTimestamp);
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }

  Future<DateTime?> getLastCacheTime() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keyCacheTimestamp);
    final timestamp = prefs.getInt(key);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> saveCenterId(String centerId) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyCenterId, centerId);
  }

  Future<String?> getCenterId() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyCenterId);
  }

  Future<bool> hasCache() async {
    final prefs = await _getPrefs();
    final key = await _composeKey(_keyCacheTimestamp);
    return prefs.containsKey(key);
  }

  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys();
    for (final k in keys) {
      if (k.startsWith('cache_')) {
        await prefs.remove(k);
      }
    }
    await prefs.remove(_keyCenterId);
    debugPrint('🗑️ [Cache] تم مسح كل البيانات المخزنة');
  }

  // ═══════════════════════════════════════════════════════════════
  // تحويلات Models - Student
  // ═══════════════════════════════════════════════════════════════

  Map<String, dynamic> _studentToMap(Student s) => {
    'id': s.id,
    'name': s.name,
    'phone': s.phone,
    'studentNumber': s.studentNumber,
    'email': s.email,
    'imageUrl': s.imageUrl,
    'birthDate': s.birthDate.toIso8601String(),
    'address': s.address,
    'stage': s.stage,
    'subjectIds': s.subjectIds,
    'parentId': s.parentId,
    'status': s.status.name,
    'createdAt': s.createdAt.toIso8601String(),
    'lastAttendance': s.lastAttendance?.toIso8601String(),
  };

  Student _mapToStudent(Map<String, dynamic> m) => Student(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    studentNumber: m['studentNumber'],
    email: m['email'],
    imageUrl: m['imageUrl'],
    birthDate: DateTime.tryParse(m['birthDate'] ?? '') ?? DateTime.now(),
    address: m['address'] ?? '',
    stage: m['stage'] ?? '',
    subjectIds: List<String>.from(m['subjectIds'] ?? []),
    parentId: m['parentId'],
    status: _parseStudentStatus(m['status']),
    createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    lastAttendance: m['lastAttendance'] != null 
        ? DateTime.tryParse(m['lastAttendance']) 
        : null,
  );

  StudentStatus _parseStudentStatus(String? status) {
    switch (status) {
      case 'active': return StudentStatus.active;
      case 'suspended': return StudentStatus.suspended;
      case 'overdue': return StudentStatus.overdue;
      case 'inactive': return StudentStatus.inactive;
      default: return StudentStatus.active;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // تحويلات Models - Teacher
  // ═══════════════════════════════════════════════════════════════

  Map<String, dynamic> _teacherToMap(Teacher t) => {
    'id': t.id,
    'name': t.name,
    'phone': t.phone,
    'email': t.email,
    'imageUrl': t.imageUrl,
    'subjectIds': t.subjectIds,
    'salaryType': t.salaryType.name,
    'salaryAmount': t.salaryAmount,
    'isActive': t.isActive,
    'createdAt': t.createdAt.toIso8601String(),
    'rating': t.rating,
    'courseCount': t.courseCount,
    'studentCount': t.studentCount,
  };

  Teacher _mapToTeacher(Map<String, dynamic> m) => Teacher(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    email: m['email'],
    imageUrl: m['imageUrl'],
    subjectIds: List<String>.from(m['subjectIds'] ?? []),
    salaryType: _parseSalaryType(m['salaryType']),
    salaryAmount: (m['salaryAmount'] ?? 0).toDouble(),
    isActive: m['isActive'] ?? true,
    createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    rating: (m['rating'] ?? 0).toDouble(),
    courseCount: m['courseCount'] ?? 0,
    studentCount: m['studentCount'] ?? 0,
  );

  SalaryType _parseSalaryType(String? type) {
    switch (type) {
      case 'fixed': return SalaryType.fixed;
      case 'percentage': return SalaryType.percentage;
      case 'perSession': return SalaryType.perSession;
      default: return SalaryType.fixed;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // تحويلات Models - Subject
  // ═══════════════════════════════════════════════════════════════

  Map<String, dynamic> _subjectToMap(Subject s) => {
    'id': s.id,
    'name': s.name,
    'description': s.description,
    'monthlyFee': s.monthlyFee,
    'teacherIds': s.teacherIds,
    'isActive': s.isActive,
    'studentCount': s.studentCount,
  };

  Subject _mapToSubject(Map<String, dynamic> m) => Subject(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    description: m['description'],
    monthlyFee: (m['monthlyFee'] ?? 0).toDouble(),
    teacherIds: List<String>.from(m['teacherIds'] ?? []),
    isActive: m['isActive'] ?? true,
    studentCount: m['studentCount'] ?? 0,
  );

  // ═══════════════════════════════════════════════════════════════
  // تحويلات Models - Room
  // ═══════════════════════════════════════════════════════════════

  Map<String, dynamic> _roomToMap(Room r) => {
    'id': r.id,
    'number': r.number,
    'name': r.name,
    'capacity': r.capacity,
    'equipment': r.equipment,
    'status': r.status.name,
  };

  Room _mapToRoom(Map<String, dynamic> m) => Room(
    id: m['id'] ?? '',
    number: m['number'] ?? '',
    name: m['name'] ?? '',
    capacity: m['capacity'] ?? 0,
    equipment: List<String>.from(m['equipment'] ?? []),
    status: _parseRoomStatus(m['status']),
  );

  RoomStatus _parseRoomStatus(String? status) {
    switch (status) {
      case 'available': return RoomStatus.available;
      case 'occupied': return RoomStatus.occupied;
      case 'maintenance': return RoomStatus.maintenance;
      default: return RoomStatus.available;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // تحويلات Models - ScheduleSession
  // ═══════════════════════════════════════════════════════════════

  Map<String, dynamic> _sessionToMap(ScheduleSession s) => {
    'id': s.id,
    'subjectId': s.subjectId,
    'subjectName': s.subjectName,
    'teacherId': s.teacherId,
    'teacherName': s.teacherName,
    'roomId': s.roomId,
    'roomName': s.roomName,
    'dayOfWeek': s.dayOfWeek,
    'startTime': s.startTime,
    'endTime': s.endTime,
    'status': s.status.name,
  };

  ScheduleSession _mapToSession(Map<String, dynamic> m) => ScheduleSession(
    id: m['id'] ?? '',
    subjectId: m['subjectId'] ?? '',
    subjectName: m['subjectName'] ?? '',
    teacherId: m['teacherId'] ?? '',
    teacherName: m['teacherName'] ?? '',
    roomId: m['roomId'] ?? '',
    roomName: m['roomName'] ?? '',
    dayOfWeek: m['dayOfWeek'] ?? 0,
    startTime: m['startTime'] ?? '',
    endTime: m['endTime'] ?? '',
    status: _parseSessionStatus(m['status']),
  );

  SessionStatus _parseSessionStatus(String? status) {
    switch (status) {
      case 'scheduled': return SessionStatus.scheduled;
      case 'ongoing': return SessionStatus.ongoing;
      case 'completed': return SessionStatus.completed;
      case 'cancelled': return SessionStatus.cancelled;
      default: return SessionStatus.scheduled;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // تحويلات Models - Payment
  // ═══════════════════════════════════════════════════════════════

  Map<String, dynamic> _paymentToMap(Payment p) => {
    'id': p.id,
    'studentId': p.studentId,
    'studentName': p.studentName,
    'amount': p.amount,
    'paidAmount': p.paidAmount,
    'method': p.method.name,
    'status': p.status.name,
    'month': p.month,
    'dueDate': p.dueDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
    'paidDate': p.paidDate?.toIso8601String(),
    'notes': p.notes,
  };

  Payment _mapToPayment(Map<String, dynamic> m) => Payment(
    id: m['id'] ?? '',
    studentId: m['studentId'] ?? '',
    studentName: m['studentName'] ?? '',
    amount: (m['amount'] ?? 0).toDouble(),
    paidAmount: (m['paidAmount'] ?? 0).toDouble(),
    method: _parsePaymentMethod(m['method']),
    status: _parsePaymentStatus(m['status']),
    month: m['month'] ?? '',
    dueDate: DateTime.tryParse(m['dueDate'] ?? '') ?? DateTime.now(),
    paidDate: m['paidDate'] != null ? DateTime.tryParse(m['paidDate']) : null,
    notes: m['notes'],
  );

  PaymentMethod _parsePaymentMethod(String? method) {
    switch (method) {
      case 'cash': return PaymentMethod.cash;
      case 'vodafoneCash': return PaymentMethod.vodafoneCash;
      case 'bankTransfer': return PaymentMethod.bankTransfer;
      case 'instaPay': return PaymentMethod.instaPay;
      default: return PaymentMethod.cash;
    }
  }

  PaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'paid': return PaymentStatus.paid;
      case 'partial': return PaymentStatus.partial;
      case 'pending': return PaymentStatus.pending;
      case 'overdue': return PaymentStatus.overdue;
      default: return PaymentStatus.pending;
    }
  }
}


