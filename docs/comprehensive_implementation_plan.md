# خطة شاملة لإصلاح جميع الشاشات وإكمال المشروع
# EdSentre - Comprehensive Implementation Plan

**تاريخ الخطة**: 15 ديسمبر 2025  
**الإصدار**: 2.0  
**الحالة**: جاهز للتنفيذ الفوري

---

## 🎯 الهدف الرئيسي (Main Objective)

تحويل التطبيق من **نموذج تجريبي مع بيانات وهمية** إلى **تطبيق إنتاجي كامل** مع:
- ✅ عزل كامل للبيانات بين السناتر (Multi-tenancy)
- ✅ جميع الشاشات تعمل ببيانات حقيقية من Supabase
- ✅ شاشة Settings كاملة الوظائف
- ✅ أمان كامل مع RLS
- ✅ مزامنة موثوقة Offline-First
- ✅ جاهز للاستخدام الفعلي من قبل السناتر

---

## 📊 الوضع الحالي (Current Status)

### ✅ ما تم إنجازه
- ✅ **CenterProvider**: تم إنشاؤه لإدارة بيانات السنتر الحالي
- ✅ **Database Schema**: Schema كامل في Supabase
- ✅ **Local Database (Drift)**: للعمل Offline
- ✅ **BLoC Architecture**: لجميع الميزات
- ✅ **Basic UI**: جميع الشاشات موجودة
- ✅ **Repositories**: DatabaseRepository و SupabaseRepository

### ❌ المشاكل الحالية
- ❌ **Dummy Data**: معظم الشاشات تستخدم MockDataRepository
- ❌ **Settings غير فعال**: معظم الخيارات لا تعمل
- ❌ **لا يوجد عزل للبيانات**: center_id غير مستخدم بشكل صحيح
- ❌ **RLS غير مفعل**: خطر أمني كبير
- ❌ **Sync غير مكتمل**: المزامنة بها مشاكل
- ❌ **No Notifications**: نظام الإشعارات غير موجود
- ❌ **No File Upload**: لا يوجد رفع للصور/ملفات
- ❌ **No Advanced Search**: البحث محدود جداً
- ❌ **No Reports Export**: لا يوجد تصدير PDF/Excel

---

## 🗺️ خريطة الطريق الشاملة (Complete Roadmap)

---

## 🔥 PHASE 0: الأساسيات الحرجة (CRITICAL - أولوية قصوى)

> **⚠️ يجب البدء بهذه المرحلة قبل أي شيء آخر**

### Week 1: RLS & Security 🔐

**الهدف**: تأمين قاعدة البيانات وضمان عزل البيانات بين السناتر

#### المهام التفصيلية:

##### 1.1 تفعيل RLS على جميع الجداول
```sql
-- في Supabase SQL Editor
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_subjects ENABLE ROW LEVEL SECURITY;
```

##### 1.2 كتابة سياسات RLS لكل دور

**الأدوار المطلوبة**:
- `super_admin`: وصول كامل لجميع البيانات
- `center_admin`: وصول لبيانات السنتر فقط
- `teacher`: وصول للطلاب والحضور والدرجات
- `student`: عرض بياناته فقط
- `parent`: عرض بيانات أبنائه فقط

**مثال لسياسة Students**:
```sql
-- Center Admin: يرى طلاب سنتره فقط
CREATE POLICY "center_admin_select_students"
ON students FOR SELECT
TO authenticated
USING (
  center_id IN (
    SELECT center_id FROM user_centers 
    WHERE user_id = auth.uid() 
    AND role = 'center_admin'
  )
);

-- Center Admin: يضيف طلاب لسنتره فقط
CREATE POLICY "center_admin_insert_students"
ON students FOR INSERT
TO authenticated
WITH CHECK (
  center_id IN (
    SELECT center_id FROM user_centers 
    WHERE user_id = auth.uid() 
    AND role = 'center_admin'
  )
);

-- Student: يرى بياناته فقط
CREATE POLICY "student_select_own"
ON students FOR SELECT
TO authenticated
USING (id = auth.uid());
```

##### 1.3 تحسين RoleProvider

**الملف**: `lib/core/auth/role_provider.dart`

**التحسينات المطلوبة**:
```dart
class RoleProvider extends ChangeNotifier {
  String? _role;
  List<String> _permissions = [];
  List<String> _centerIds = [];
  
  // Permission checks
  bool canViewStudents() => _permissions.contains('view_students');
  bool canEditStudents() => _permissions.contains('edit_students');
  bool canDeleteStudents() => _permissions.contains('delete_students');
  bool canTakeAttendance() => _permissions.contains('take_attendance');
  bool canViewReports() => _permissions.contains('view_reports');
  bool canManagePayments() => _permissions.contains('manage_payments');
  
  Future<void> loadPermissions() async {
    // جلب الصلاحيات من user_centers
    final response = await Supabase.instance.client
        .from('user_centers')
        .select('role, access_permissions')
        .eq('user_id', auth.currentUser!.id);
    
    // تحميل الصلاحيات
    _permissions = _parsePermissions(response);
    notifyListeners();
  }
}
```

##### 1.4 تحديث AuthBloc

**الملف**: `lib/features/auth/bloc/auth_bloc.dart`

```dart
// في AuthEvent
class AuthLoadUserData extends AuthEvent {}

// في AuthBloc
Future<void> _onAuthLoadUserData(
  AuthLoadUserData event,
  Emitter<AuthState> emit,
) async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    // جلب بيانات المستخدم من جدول users
    final userData = await Supabase.instance.client
        .from('users')
        .select('*, user_centers(*)')
        .eq('id', user.id)
        .single();
    
    // تحميل الدور والصلاحيات
    final role = userData['user_centers'][0]['role'];
    final centerId = userData['default_center_id'];
    
    // تحديث RoleProvider
    context.read<RoleProvider>().setRole(role);
    context.read<RoleProvider>().loadPermissions();
    
    // تحديث CenterProvider
    context.read<CenterProvider>().setCenterId(centerId);
    await context.read<CenterProvider>().loadCenterData();
    
    emit(AuthAuthenticated(user: user, userData: userData));
  } catch (e) {
    emit(AuthError(message: e.toString()));
  }
}
```

**التسليمات (Deliverables)**:
- ✅ RLS مفعل على جميع الجداول
- ✅ سياسات RLS موثقة في `docs/rls_policies.sql`
- ✅ RoleProvider محسّن مع permission checks
- ✅ AuthBloc يحمل البيانات تلقائياً
- ✅ اختبارات للتحقق من RLS

---

### Week 2-3: Offline Sync Service 🔄

**الهدف**: بناء نظام مزامنة موثوق وقابل للتوسع

#### المهام التفصيلية:

##### 2.1 تحسين SyncService الموجود

**الملف**: `lib/core/sync/sync_service.dart`

**التحسينات**:
```dart
class SyncService extends ChangeNotifier {
  final AppDatabase _db;
  final _syncQueue = <SyncOperation>[];
  bool _isSyncing = false;
  
  // إضافة Sync Queue
  Future<void> addToQueue(SyncOperation operation) async {
    _syncQueue.add(operation);
    await _saveSyncQueue(); // حفظ في SQLite
    if (!_isSyncing) {
      await _processSyncQueue();
    }
  }
  
  // معالجة الطابور
  Future<void> _processSyncQueue() async {
    if (_syncQueue.isEmpty) return;
    
    _isSyncing = true;
    notifyListeners();
    
    while (_syncQueue.isNotEmpty) {
      final operation = _syncQueue.first;
      
      try {
        await _executeOperation(operation);
        _syncQueue.removeAt(0);
        await _saveSyncQueue();
      } catch (e) {
        // إذا فشلت، أعد المحاولة لاحقاً
        if (operation.retryCount < 3) {
          operation.retryCount++;
          await Future.delayed(_getBackoffDuration(operation.retryCount));
        } else {
          // فشل نهائي - انقل للـ Failed Queue
          await _moveToFailedQueue(operation);
          _syncQueue.removeAt(0);
        }
      }
    }
    
    _isSyncing = false;
    notifyListeners();
  }
  
  // Exponential Backoff
  Duration _getBackoffDuration(int retryCount) {
    return Duration(seconds: math.pow(2, retryCount).toInt());
  }
}
```

##### 2.2 Conflict Resolution Strategy

**استراتيجية**: Last-Write-Wins مع Manual Override للحالات الحرجة

```dart
class ConflictResolver {
  Future<T> resolveConflict<T>({
    required T localData,
    required T remoteData,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    bool forceLocal = false,
  }) async {
    if (forceLocal) return localData;
    
    // Last-Write-Wins
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return localData;
    } else {
      return remoteData;
    }
  }
  
  // للحالات الحرجة - عرض UI للمستخدم للاختيار
  Future<T> resolveManually<T>({
    required T localData,
    required T remoteData,
    required BuildContext context,
  }) async {
    return await showDialog<T>(
      context: context,
      builder: (context) => ConflictResolutionDialog(
        localData: localData,
        remoteData: remoteData,
      ),
    ) ?? localData;
  }
}
```

##### 2.3 Background Sync

**Android**: استخدام WorkManager
```dart
// في android/app/src/main/kotlin/MainActivity.kt
// إضافة WorkManager

// في lib/core/sync/background_sync.dart
class BackgroundSyncService {
  static const syncTaskName = "syncTask";
  
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    
    // جدولة مزامنة دورية كل 15 دقيقة
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case BackgroundSyncService.syncTaskName:
        await _performBackgroundSync();
        return true;
      default:
        return false;
    }
  });
}

Future<void> _performBackgroundSync() async {
  final db = AppDatabase();
  final syncService = SyncService(db);
  await syncService.syncAll();
}
```

##### 2.4 Sync Status UI

**في AppShell** - إضافة مؤشر الحالة:
```dart
// في lib/shared/widgets/app_shell.dart
Consumer<SyncService>(
  builder: (context, syncService, child) {
    if (syncService.isSyncing) {
      return LinearProgressIndicator(
        value: syncService.syncProgress,
      );
    }
    
    if (syncService.hasFailedOperations) {
      return Material(
        color: Colors.red,
        child: ListTile(
          leading: Icon(Icons.error, color: Colors.white),
          title: Text('فشلت ${syncService.failedCount} عمليات'),
          trailing: TextButton(
            onPressed: () => syncService.retryFailed(),
            child: Text('إعادة المحاولة'),
          ),
        ),
      );
    }
    
    return SizedBox.shrink();
  },
)
```

**التسليمات**:
- ✅ SyncService محسّن مع Sync Queue
- ✅ Conflict Resolution مطبق
- ✅ Retry Mechanism مع Exponential Backoff
- ✅ Background Sync مع WorkManager
- ✅ Sync Status UI في AppShell
- ✅ توثيق في `docs/sync_implementation.md`

---

### Week 4: Error Handling & Validation ⚠️

**الهدف**: معالجة موحدة للأخطاء وتحقق شامل من البيانات

#### المهام:

##### 4.1 بناء ErrorHandler مركزي

**الملف**: `lib/core/error/error_handler.dart`

```dart
class ErrorHandler {
  static void handleError(dynamic error, {StackTrace? stackTrace}) {
    if (error is PostgrestException) {
      _handleSupabaseError(error);
    } else if (error is DioException) {
      _handleNetworkError(error);
    } else if (error is ValidationException) {
      _handleValidationError(error);
    } else {
      _handleGenericError(error, stackTrace);
    }
    
    // إرسال للـ Logger
    AppLogger.error(error.toString(), error, stackTrace);
  }
  
  static String getUserFriendlyMessage(dynamic error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '42P17':
          return 'مشكلة في صلاحيات قاعدة البيانات';
        case '23505':
          return 'البيانات مكررة';
        default:
          return 'خطأ في قاعدة البيانات';
      }
    }
    return 'حدث خطأ غير متوقع';
  }
}
```

##### 4.2 Result/Either Pattern

**الملف**: `lib/core/utils/result.dart`

```dart
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final dynamic error;
  const Failure(this.message, [this.error]);
}

// Extension للاستخدام السهل
extension ResultExtension<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  
  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  String? get errorOrNull => this is Failure<T> ? (this as Failure<T>).message : null;
  
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Failure(:final message) => failure(message),
    };
  }
}
```

##### 4.3 Logger System

```dart
class AppLogger {
  static final _logger = Logger(
    printer: PrettyPrinter(),
    output: MultiOutput([
      ConsoleOutput(),
      FileOutput(),
    ]),
  );
  
  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error, stackTrace);
    // إرسال لـ Sentry في Production
    if (kReleaseMode) {
      Sentry.captureException(error, stackTrace: stackTrace);
    }
  }
}
```

##### 4.4 Form Validation

تحسين `lib/core/utils/form_validators.dart`:

```dart
class AppValidators {
  static String? required(String? value, {String fieldName = 'الحقل'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName مطلوب';
    }
    return null;
  }
  
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'البريد الإلكتروني غير صحيح';
    }
    return null;
  }
  
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;
    final phoneRegex = RegExp(r'^01[0-2,5]{1}[0-9]{8}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'رقم الهاتف غير صحيح (يجب أن يبدأ بـ 01x)';
    }
    return null;
  }
  
  static String? minLength(String? value, int min) {
    if (value == null || value.isEmpty) return null;
    if (value.length < min) {
      return 'الحد الأدنى $min أحرف';
    }
    return null;
  }
  
  static String? number(String? value) {
    if (value == null || value.isEmpty) return null;
    if (double.tryParse(value) == null) {
      return 'يجب إدخال رقم صحيح';
    }
    return null;
  }
}
```

**التسليمات**:
- ✅ `lib/core/error/error_handler.dart`
- ✅ `lib/core/utils/result.dart`
- ✅ `lib/core/logging/app_logger.dart`
- ✅ Form Validation محسّن في جميع الشاشات

---

### Week 5: Search, Filter & Pagination 🔍

#### المهام:

##### 5.1 SearchBar Component

**الملف**: `lib/shared/widgets/search/app_search_bar.dart`

```dart
class AppSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search),
        suffixIcon: onClear != null 
            ? IconButton(icon: Icon(Icons.clear), onPressed: onClear)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
```

##### 5.2 تحسين البحث في الشاشات

```dart
// في StudentsBloc
class StudentsSearchChanged extends StudentsEvent {
  final String query;
  const StudentsSearchChanged(this.query);
}

Future<void> _onSearchChanged(
  StudentsSearchChanged event,
  Emitter<StudentsState> emit,
) async {
  if (event.query.isEmpty) {
    emit(state.copyWith(filteredStudents: state.allStudents));
    return;
  }
  
  final filtered = state.allStudents.where((student) {
    return student.name.toLowerCase().contains(event.query.toLowerCase()) ||
           student.phone.contains(event.query) ||
           (student.email?.contains(event.query) ?? false);
  }).toList();
  
  emit(state.copyWith(filteredStudents: filtered));
}
```

##### 5.3 Advanced Filters

```dart
class FilterPanel extends StatelessWidget {
  final List<FilterOption> options;
  final Function(Map<String, dynamic>) onApply;
  
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('تصفية'),
      children: [
        // Stage filter
        DropdownButtonFormField(
          items: ['الكل', 'ثانوي 1', 'ثانوي 2', 'ثانوي 3'],
          onChanged: (value) { },
        ),
        // Status filter
        DropdownButtonFormField(
          items: ['الكل', 'نشط', 'معلق', 'متوقف'],
          onChanged: (value) { },
        ),
        // Apply button
        ElevatedButton(
          onPressed: () => onApply(filters),
          child: Text('تطبيق'),
        ),
      ],
    );
  }
}
```

##### 5.4 Pagination

```dart
class PaginatedListView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page, int pageSize) fetchData;
  final Widget Function(T item) itemBuilder;
  final int pageSize;
  
  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final _scrollController = ScrollController();
  final _items = <T>[];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  
  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }
  
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);
    
    final newItems = await widget.fetchData(_currentPage, widget.pageSize);
    
    setState(() {
      _items.addAll(newItems);
      _currentPage++;
      _hasMore = newItems.length == widget.pageSize;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Center(child: CircularProgressIndicator());
        }
        return widget.itemBuilder(_items[index]);
      },
    );
  }
}
```

**التسليمات**:
- ✅ `lib/shared/widgets/search/app_search_bar.dart`
- ✅ `lib/shared/widgets/filters/filter_panel.dart`
- ✅ `lib/shared/widgets/pagination/paginated_list_view.dart`
- ✅ تحديث جميع BLoCs لدعم Search & Pagination

---

### Week 6: Storage & File Management 📁

#### المهام:

##### 6.1 StorageService

**الملف**: `lib/core/storage/storage_service.dart`

```dart
class StorageService {
  final _storage = Supabase.instance.client.storage;
  
  Future<String> uploadImage({
    required File file,
    required String bucket,
    required String path,
    Function(double)? onProgress,
  }) async {
    try {
      // ضغط الصورة أولاً
      final compressedFile = await _compressImage(file);
      
      // رفع للـ Storage
      final uploadPath = '$path/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _storage.from(bucket).upload(
        uploadPath,
        compressedFile,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );
      
      // الحصول على الـ Public URL
      final url = _storage.from(bucket).getPublicUrl(uploadPath);
      
      return url;
    } catch (e) {
      throw StorageException('فشل رفع الصورة: $e');
    }
  }
  
  Future<File> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.path}_compressed.jpg',
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    );
    
    return result ?? file;
  }
  
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await _storage.from(bucket).remove([path]);
  }
}
```

##### 6.2 Image Picker Integration

```dart
class ImagePickerService {
  final _picker = ImagePicker();
  
  Future<File?> pickFromGallery() async {
    final result = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    
    return result != null ? File(result.path) : null;
  }
  
  Future<File?> pickFromCamera() async {
    final result = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    
    return result != null ? File(result.path) : null;
  }
  
  Future<File?> showPickerDialog(BuildContext context) async {
    return await showModalBottomSheet<File>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('اختيار من المعرض'),
              onTap: () async {
                final file = await pickFromGallery();
                Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('التقاط صورة'),
              onTap: () async {
                final file = await pickFromCamera();
                Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

##### 6.3 Upload Progress UI

```dart
class UploadProgressDialog extends StatelessWidget {
  final double progress;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('جاري رفع الصورة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          SizedBox(height: 16),
          Text('${(progress * 100).toInt()}%'),
        ],
      ),
    );
  }
}
```

**التسليمات**:
- ✅ `lib/core/storage/storage_service.dart`
- ✅ `lib/core/storage/image_picker_service.dart`
- ✅ تحديث Students/Teachers screens لرفع الصور
- ✅ Upload Progress UI

---

### Week 7: Notifications System 🔔

#### المهام:

##### 7.1 Firebase Cloud Messaging

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^16.2.0
```

```dart
// lib/core/notifications/fcm_service.dart
class FCMService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    
    final messaging = FirebaseMessaging.instance;
    
    // طلب الإذن
    await messaging.requestPermission();
    
    // الحصول على الـ Token
    final token = await messaging.getToken();
    print('FCM Token: $token');
    
    // حفظ الـ Token في Supabase
    await _saveFCMToken(token);
    
    // الاستماع للرسائل
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }
  
  static Future<void> _saveFCMToken(String? token) async {
    if (token == null) return;
    
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    
    await Supabase.instance.client
        .from('user_fcm_tokens')
        .upsert({
          'user_id': userId,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        });
  }
  
  static void _handleForegroundMessage(RemoteMessage message) {
    // عرض Notification محلي
    LocalNotificationService.show(
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      payload: message.data,
    );
  }
}
```

##### 7.2 Local Notifications

```dart
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    
    await _notifications.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }
  
  static Future<void> show({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'General Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(payload),
    );
  }
  
  static void _onNotificationTap(NotificationResponse response) {
    // Handle navigation
    final payload = jsonDecode(response.payload ?? '{}');
    // Navigate based on payload
  }
}
```

##### 7.3 Notification Center

تحديث `NotificationsScreen`:

```dart
// في NotificationsBloc
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(status: NotificationsStatus.loading));
    
    try {
      final centerId = context.read<CenterProvider>().centerId;
      
      // جلب الإشعارات من Supabase
      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('center_id', centerId)
          .order('created_at', ascending: false)
          .limit(50);
      
      final notifications = response.map((n) => Notification.fromJson(n)).toList();
      
      emit(state.copyWith(
        status: NotificationsStatus.loaded,
        notifications: notifications,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: NotificationsStatus.error,
        error: e.toString(),
      ));
    }
  }
  
  Future<void> _onMarkAsRead(
    MarkNotificationAsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', event.notificationId);
    
    // إعادة تحميل
    add(LoadNotifications());
  }
}
```

**التسليمات**:
- ✅ `lib/core/notifications/fcm_service.dart`
- ✅ `lib/core/notifications/local_notification_service.dart`
- ✅ NotificationsScreen محدّث
- ✅ Push Notifications للمدفوعات والحضور

---

### Week 8: Advanced Reports & Export 📊

#### المهام:

##### 8.1 تحسين Reports UI

```dart
// في ReportsScreen
class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Financial Summary Card
            _buildFinancialSummary(),
            
            // Revenue Chart
            _buildRevenueChart(),
            
            // Attendance Chart
            _buildAttendanceChart(),
            
            // Export Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.picture_as_pdf),
                  label: Text('تصدير PDF'),
                  onPressed: () => _exportToPDF(),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.table_chart),
                  label: Text('تصدير Excel'),
                  onPressed: () => _exportToExcel(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRevenueChart() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(show: true),
            borderData: FlBorderData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: _getRevenueSpots(),
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

##### 8.2 PDF Export

```dart
class PDFExportService {
  Future<File> generateFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> data,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Text('التقرير المالي'),
          ),
          pw.Divider(),
          
          // Period
          pw.Text('الفترة: ${DateFormat('yyyy-MM-dd').format(startDate)} - ${DateFormat('yyyy-MM-dd').format(endDate)}'),
          pw.SizedBox(height: 20),
          
          // Summary
          pw.Table.fromTextArray(
            headers: ['البند', 'المبلغ'],
            data: [
              ['الإيرادات', '${data['revenue']} ج.م'],
              ['المصروفات', '${data['expenses']} ج.م'],
              ['الصافي', '${data['profit']} ج.م'],
            ],
          ),
          
          // Details
          pw.SizedBox(height: 20),
          pw.Header(level: 1, child: pw.Text('التفاصيل')),
          _buildPaymentsTable(data['payments']),
        ],
      ),
    );
    
    // حفظ
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/financial_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
}
```

##### 8.3 Excel Export

```dart
class ExcelExportService {
  Future<File> exportStudentsList(List<Student> students) async {
    final excel = Excel.createExcel();
    final sheet = excel['Students'];
    
    // Headers
    sheet.appendRow([
      'الرقم',
      'الاسم',
      'الهاتف',
      'المرحلة',
      'الحالة',
      'تاريخ التسجيل',
    ]);
    
    // Data
    for (var student in students) {
      sheet.appendRow([
        student.id,
        student.name,
        student.phone,
        student.stage,
        student.status.name,
        DateFormat('yyyy-MM-dd').format(student.createdAt),
      ]);
    }
    
    // Save
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/students_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(excel.encode()!);
    
    return file;
  }
}
```

**التسليمات**:
- ✅ Reports UI محسّن مع Charts
- ✅ `lib/features/reports/services/pdf_service.dart`
- ✅ `lib/features/reports/services/excel_service.dart`
- ✅ تقارير مالية تفصيلية
- ✅ تقارير حضور متقدمة

---

### Week 9: Performance Optimization ⚡

#### المهام:

##### 9.1 Caching Strategy

```dart
class CacheService {
  final _cache = <String, CachedData>{};
  final _maxAge = Duration(minutes: 5);
  
  T? get<T>(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    
    if (DateTime.now().difference(cached.timestamp) > _maxAge) {
      _cache.remove(key);
      return null;
    }
    
    return cached.data as T;
  }
  
  void set<T>(String key, T data) {
    _cache[key] = CachedData(data: data, timestamp: DateTime.now());
  }
  
  void clear() => _cache.clear();
}

class CachedData {
  final dynamic data;
  final DateTime timestamp;
  
  CachedData({required this.data, required this.timestamp});
}
```

##### 9.2 Lazy Loading

```dart
// في StudentsBloc
class StudentsState {
  final List<Student> students;
  final bool hasMore;
  final bool isLoadingMore;
  final int currentPage;
  
  const StudentsState({
    this.students = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.currentPage = 0,
  });
}

Future<void> _onLoadMore(
  LoadMoreStudents event,
  Emitter<StudentsState> emit,
) async {
  if (state.isLoadingMore || !state.hasMore) return;
  
  emit(state.copyWith(isLoadingMore: true));
  
  final newStudents = await _repository.getStudents(
    page: state.currentPage + 1,
    pageSize: 20,
  );
  
  emit(state.copyWith(
    students: [...state.students, ...newStudents],
    hasMore: newStudents.length == 20,
    currentPage: state.currentPage + 1,
    isLoadingMore: false,
  ));
}
```

##### 9.3 Image Caching

```dart
// استخدام cached_network_image
CachedNetworkImage(
  imageUrl: student.imageUrl ?? '',
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.person),
  fit: BoxFit.cover,
  cacheKey: student.id,
  maxWidthDiskCache: 400,
  maxHeightDiskCache: 400,
)
```

**التسليمات**:
- ✅ CacheService مطبق
- ✅ Lazy Loading في القوائم
- ✅ Image Caching
- ✅ Performance Monitoring

---

## 📱 SCREENS PHASE: إصلاح جميع الشاشات

### الهدف: ربط كل شاشة بـ CenterProvider واستخدام بيانات حقيقية

---

### 1. Dashboard Screen 📊

**الملف**: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**التغييرات**:
```dart
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final centerProvider = Provider.of<CenterProvider>(context);
    final centerId = centerProvider.centerId;
    
    return BlocProvider(
      create: (context) => DashboardBloc(
        repository: context.read<SupabaseRepository>(),
        centerId: centerId!, // ✅ تمرير center_id
      )..add(LoadDashboardData()),
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.status == DashboardStatus.loading) {
            return Center(child: CircularProgressIndicator());
          }
          
          return SingleChildScrollView(
            child: Column(
              children: [
                // Center Info Card
                _buildCenterInfoCard(centerProvider),
                
                // Stats Cards (من قاعدة البيانات)
                Row(
                  children: [
                    _buildStatCard('الطلاب', state.studentsCount),
                    _buildStatCard('المعلمين', state.teachersCount),
                    _buildStatCard('الإيرادات', '${state.revenue} ج.م'),
                  ],
                ),
                
                // Recent Activity
                _buildRecentActivity(state.recentActivities),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCenterInfoCard(CenterProvider provider) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.business)),
        title: Text(provider.centerName),
        subtitle: Text('${provider.centerAddress} - ${provider.centerCity}'),
        trailing: Chip(
          label: Text(provider.isActive ? 'نشط' : 'معلق'),
          backgroundColor: provider.isActive ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
```

**في DashboardBloc**:
```dart
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final SupabaseRepository repository;
  final String centerId;
  
  DashboardBloc({required this.repository, required this.centerId}) : super(DashboardState.initial()) {
    on<LoadDashboardData>(_onLoadData);
  }
  
  Future<void> _onLoadData(
    LoadDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(status: DashboardStatus.loading));
    
    try {
      // جلب الإحصائيات من Supabase
      final studentsCount = await repository.getStudentsCount(centerId);
      final teachersCount = await repository.getTeachersCount(centerId);
      final revenue = await repository.getMonthlyRevenue(centerId);
      final recentActivities = await repository.getRecentActivities(centerId, limit: 10);
      
      emit(state.copyWith(
        status: DashboardStatus.loaded,
        studentsCount: studentsCount,
        teachersCount: teachersCount,
        revenue: revenue,
        recentActivities: recentActivities,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        error: e.toString(),
      ));
    }
  }
}
```

**في SupabaseRepository** - إضافة:
```dart
Future<int> getStudentsCount(String centerId) async {
  final response = await _client
      .from('students')
      .select('id', count: CountOption.exact)
      .eq('center_id', centerId);
  
  return response.count ?? 0;
}

Future<int> getTeachersCount(String centerId) async {
  final response = await _client
      .from('teachers')
      .select('id', count: CountOption.exact)
      .eq('center_id', centerId);
  
  return response.count ?? 0;
}

Future<double> getMonthlyRevenue(String centerId) async {
  final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  
  final response = await _client
      .from('payments')
      .select('amount')
      .eq('center_id', centerId)
      .eq('status', 'paid')
      .gte('created_at', startOfMonth.toIso8601String());
  
  return response.fold<double>(0, (sum, payment) => sum + (payment['amount'] as num).toDouble());
}
```

---

### 2. Students Screen 👨‍🎓

**الملف**: `lib/features/students/presentation/screens/students_screen.dart`

**التغييرات**:
```dart
class StudentsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final centerId = context.read<CenterProvider>().centerId;
    
    return BlocProvider(
      create: (context) => StudentsBloc(
        repository: context.read<SupabaseRepository>(),
        centerId: centerId!,
      )..add(LoadStudents()),
      child: Scaffold(
        appBar: AppBar(title: Text('الطلاب')),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: EdgeInsets.all(16),
              child: AppSearchBar(
                hintText: 'البحث عن طالب...',
                onChanged: (query) {
                  context.read<StudentsBloc>().add(SearchStudents(query));
                },
              ),
            ),
            
            // Filter Panel
            FilterPanel(
              options: [
                FilterOption('stage', 'المرحلة', ['الكل', 'ثانوي 1', 'ثانوي 2', 'ثانوي 3']),
                FilterOption('status', 'الحالة', ['الكل', 'نشط', 'معلق']),
              ],
              onApply: (filters) {
                context.read<StudentsBloc>().add(FilterStudents(filters));
              },
            ),
            
            // Students List
            Expanded(
              child: BlocBuilder<StudentsBloc, StudentsState>(
                builder: (context, state) {
                  if (state.status == StudentsStatus.loading) {
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  if (state.students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school, size: 64, color: Colors.grey),
                          Text('لا يوجد طلاب بعد'),
                          ElevatedButton(
                            onPressed: () => _showAddStudentDialog(context),
                            child: Text('إضافة طالب'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: state.students.length,
                    itemBuilder: (context, index) {
                      final student = state.students[index];
                      return StudentCard(
                        student: student,
                        onTap: () => _navigateToDetails(context, student),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddStudentDialog(context),
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
```

**في StudentsBloc**:
```dart
Future<void> _onLoadStudents(
  LoadStudents event,
  Emitter<StudentsState> emit,
) async {
  emit(state.copyWith(status: StudentsStatus.loading));
  
  try {
    // ✅ جلب من Supabase بناءً على center_id
    final students = await repository.getStudents(centerId);
    
    emit(state.copyWith(
      status: StudentsStatus.loaded,
      students: students,
      filteredStudents: students,
    ));
  } catch (e) {
    emit(state.copyWith(
      status: StudentsStatus.error,
      error: e.toString(),
    ));
  }
}

Future<void> _onAddStudent(
  AddStudent event,
  Emitter<StudentsState> emit,
) async {
  try {
    // ✅ إضافة مع center_id
    final newStudent = event.student.copyWith(
      centerId: centerId, // هام جداً!
    );
    
    await repository.addStudent(newStudent);
    
    // إعادة تحميل القائمة
    add(LoadStudents());
  } catch (e) {
    emit(state.copyWith(error: e.toString()));
  }
}
```

---

### 3. Teachers Screen 👨‍🏫

**نفس النمط مع Students**:
```dart
class TeachersBloc extends Bloc<TeachersEvent, TeachersState> {
  final SupabaseRepository repository;
  final String centerId;
  
  Future<void> _onLoadTeachers(
    LoadTeachers event,
    Emitter<TeachersState> emit,
  ) async {
    final teachers = await repository.getTeachers(centerId);
    emit(state.copyWith(teachers: teachers));
  }
}
```

---

### 4. Subjects Screen 📚

```dart
class SubjectsBloc extends Bloc<SubjectsEvent, SubjectsState> {
  final String centerId;
  
  Future<void> _onLoadSubjects(...) async {
    final subjects = await repository.getSubjects(centerId);
    emit(state.copyWith(subjects: subjects));
  }
}
```

---

### 5. Rooms Screen 🏫

```dart
class RoomsBloc extends Bloc<RoomsEvent, RoomsState> {
  final String centerId;
  
  Future<void> _onLoadRooms(...) async {
    final rooms = await repository.getRooms(centerId);
    emit(state.copyWith(rooms: rooms));
  }
}
```

---

### 6. Schedule Screen 📅

```dart
class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final String centerId;
  
  Future<void> _onLoadSchedule(...) async {
    final sessions = await repository.getSessions(centerId);
    emit(state.copyWith(sessions: sessions));
  }
}
```

---

### 7. Attendance Screen ✅

```dart
class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final String centerId;
  
  Future<void> _onLoadAttendance(...) async {
    final attendance = await repository.getAttendance(
      centerId: centerId,
      date: event.date,
    );
    emit(state.copyWith(attendance: attendance));
  }
  
  Future<void> _onTakeAttendance(...) async {
    // تسجيل حضور حقيقي
    await repository.recordAttendance(
      centerId: centerId,
      sessionId: event.sessionId,
      studentId: event.studentId,
      status: event.status,
    );
  }
}
```

---

### 8. Payments Screen 💰

```dart
class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  final String centerId;
  
  Future<void> _onLoadPayments(...) async {
    final payments = await repository.getPayments(centerId);
    emit(state.copyWith(payments: payments));
  }
  
  Future<void> _onRecordPayment(...) async {
    await repository.recordPayment(
      centerId: centerId,
      studentId: event.studentId,
      amount: event.amount,
      method: event.method,
    );
  }
}
```

---

### 9. Reports Screen 📈

```dart
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final String centerId;
  
  Future<void> _onGenerateReport(...) async {
    final data = await repository.getReportData(
      centerId: centerId,
      startDate: event.startDate,
      endDate: event.endDate,
    );
    
    emit(state.copyWith(reportData: data));
  }
}
```

---

### 10. Settings Screen ⚙️ (الأهم!)

**الملف**: `lib/features/settings/presentation/screens/settings_screen.dart`

**إصلاح كامل**:

```dart
class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedSection = 0;
  bool _hasChanges = false;
  
  // Controllers - ✅ سيتم ملؤها من CenterProvider
  late TextEditingController _centerNameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _licenseController;
  
  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _autoBackup = true;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
  
  void _initializeControllers() {
    final centerProvider = context.read<CenterProvider>();
    
    _centerNameController = TextEditingController(text: centerProvider.centerName);
    _addressController = TextEditingController(text: centerProvider.centerAddress);
    _phoneController = TextEditingController(text: centerProvider.centerPhone);
    _emailController = TextEditingController(text: centerProvider.centerEmail);
    _licenseController = TextEditingController(text: centerProvider.licenseNumber);
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<CenterProvider>(
      builder: (context, centerProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('الإعدادات'),
            actions: [
              if (_hasChanges)
                TextButton(
                  onPressed: _saveChanges,
                  child: Text('حفظ'),
                ),
            ],
          ),
          body: Row(
            children: [
              // Sidebar
              _buildSidebar(),
              
              // Content
              Expanded(
                child: _buildContent(centerProvider),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildContent(CenterProvider provider) {
    switch (_selectedSection) {
      case 0:
        return _buildCenterInfo(provider);
      case 1:
        return _buildAppearance();
      case 2:
        return _buildNotifications();
      case 3:
        return _buildBackup();
      case 4:
        return _buildAccount();
      default:
        return SizedBox();
    }
  }
  
  Widget _buildCenterInfo(CenterProvider provider) {
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Text('معلومات السنتر', style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: 24),
        
        // ✅ Center Name
        TextFormField(
          controller: _centerNameController,
          decoration: InputDecoration(labelText: 'اسم السنتر'),
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
        SizedBox(height: 16),
        
        // ✅ Address
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(labelText: 'العنوان'),
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
        SizedBox(height: 16),
        
        // ✅ Phone
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(labelText: 'الهاتف'),
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
        SizedBox(height: 16),
        
        // ✅ Email
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(labelText: 'البريد الإلكتروني'),
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
        SizedBox(height: 16),
        
        // ✅ License Number
        TextFormField(
          controller: _licenseController,
          decoration: InputDecoration(labelText: 'رقم الترخيص'),
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
        SizedBox(height: 24),
        
        // ✅ Subscription Info
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('معلومات الاشتراك', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('النوع: ${provider.subscriptionType}'),
                Text('الحالة: ${provider.isActive ? "نشط" : "معلق"}'),
                Text('عدد الطلاب: ${provider.studentCount}'),
                Text('عدد المعلمين: ${provider.teacherCount}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildNotifications() {
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Text('الإشعارات', style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: 24),
        
        // ✅ Email Notifications
        SwitchListTile(
          title: Text('إشعارات البريد الإلكتروني'),
          subtitle: Text('تلقي إشعارات عبر البريد'),
          value: _emailNotifications,
          onChanged: (value) async {
            setState(() => _emailNotifications = value);
            await _saveNotificationSettings();
          },
        ),
        
        // ✅ SMS Notifications
        SwitchListTile(
          title: Text('إشعارات SMS'),
          subtitle: Text('تلقي رسائل نصية'),
          value: _smsNotifications,
          onChanged: (value) async {
            setState(() => _smsNotifications = value);
            await _saveNotificationSettings();
          },
        ),
      ],
    );
  }
  
  Widget _buildBackup() {
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Text('النسخ الاحتياطي', style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: 24),
        
        // ✅ Auto Backup
        SwitchListTile(
          title: Text('نسخ احتياطي تلقائي'),
          subtitle: Text('نسخ احتياطي يومي للبيانات'),
          value: _autoBackup,
          onChanged: (value) async {
            setState(() => _autoBackup = value);
            await _saveBackupSettings();
          },
        ),
        
        SizedBox(height: 24),
        
        // ✅ Manual Backup
        ElevatedButton.icon(
          icon: Icon(Icons.backup),
          label: Text('نسخ احتياطي الآن'),
          onPressed: _performBackup,
        ),
        
        SizedBox(height: 16),
        
        // ✅ Restore
        OutlinedButton.icon(
          icon: Icon(Icons.restore),
          label: Text('استعادة من نسخة احتياطية'),
          onPressed: _showRestoreDialog,
        ),
      ],
    );
  }
  
  Widget _buildAccount() {
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        Text('الحساب', style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: 24),
        
        // ✅ Change Password
        ListTile(
          leading: Icon(Icons.lock),
          title: Text('تغيير كلمة المرور'),
          trailing: Icon(Icons.chevron_right),
          onTap: _showChangePasswordDialog,
        ),
        
        Divider(),
        
        // ✅ Logout
        ListTile(
          leading: Icon(Icons.logout, color: Colors.red),
          title: Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
          onTap: _logout,
        ),
        
        Divider(),
        
        // ✅ Delete Account (خطير!)
        ListTile(
          leading: Icon(Icons.delete_forever, color: Colors.red),
          title: Text('حذف الحساب', style: TextStyle(color: Colors.red)),
          subtitle: Text('هذا الإجراء لا يمكن التراجع عنه'),
          onTap: _showDeleteAccountDialog,
        ),
      ],
    );
  }
  
  // ✅ Save Methods
  Future<void> _saveChanges() async {
    final provider = context.read<CenterProvider>();
    
    final success = await provider.updateCenterInfo(
      name: _centerNameController.text,
      address: _addressController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      licenseNumber: _licenseController.text,
    );
    
    if (success) {
      setState(() => _hasChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ التغييرات بنجاح')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ التغييرات')),
      );
    }
  }
  
  Future<void> _saveNotificationSettings() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client
          .from('user_centers')
          .update({
            'notification_preferences': {
              'email': _emailNotifications,
              'sms': _smsNotifications,
            },
          })
          .eq('user_id', userId!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ إعدادات الإشعارات')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ الإعدادات')),
      );
    }
  }
  
  Future<void> _performBackup() async {
    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('جاري النسخ الاحتياطي...'),
          ],
        ),
      ),
    );
    
    try {
      // Backup logic here
      await Future.delayed(Duration(seconds: 2)); // Simulate
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم النسخ الاحتياطي بنجاح')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل النسخ الاحتياطي')),
      );
    }
  }
  
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تسجيل الخروج'),
        content: Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      context.read<CenterProvider>().clear();
      context.read<RoleProvider>().clear();
      // Navigate to login
      GoRouter.of(context).go('/login');
    }
  }
}
```

---

### 11. Notifications Screen 🔔

```dart
class NotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final centerId = context.read<CenterProvider>().centerId;
    
    return BlocProvider(
      create: (context) => NotificationsBloc(
        repository: context.read<SupabaseRepository>(),
        centerId: centerId!,
      )..add(LoadNotifications()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('الإشعارات'),
          actions: [
            IconButton(
              icon: Icon(Icons.done_all),
              onPressed: () {
                context.read<NotificationsBloc>().add(MarkAllAsRead());
              },
            ),
          ],
        ),
        body: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            if (state.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 64),
                    Text('لا توجد إشعارات'),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              itemCount: state.notifications.length,
              itemBuilder: (context, index) {
                final notification = state.notifications[index];
                return NotificationCard(
                  notification: notification,
                  onTap: () {
                    context.read<NotificationsBloc>().add(
                      MarkAsRead(notification.id),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
```

---

## 🧹 CLEANUP PHASE: التنظيف النهائي

### المهام:

#### 1. حذف MockDataRepository

```bash
# حذف الملف
rm lib/shared/data/mock_repository.dart
```

#### 2. إزالة جميع الـ imports

```dart
// البحث والاستبدال في جميع الملفات
// ❌ حذف
import 'package:ed_sentre/shared/data/mock_repository.dart';

// ❌ حذف أي استخدام لـ
MockDataRepository.students
MockDataRepository.teachers
// إلخ...
```

#### 3. التحقق من عزل البيانات

**اختبارات يدوية**:
1. إنشاء سنترين مختلفين
2. إضافة بيانات لكل سنتر
3. التحقق من أن كل سنتر يرى بياناته فقط

**اختبار RLS**:
```sql
-- في Supabase SQL Editor
-- تسجيل دخول كمستخدم من سنتر 1
SELECT * FROM students WHERE center_id = 'center_1_id';
-- يجب أن يرجع بيانات سنتر 1 فقط

SELECT * FROM students WHERE center_id = 'center_2_id';
-- يجب أن يرجع فارغ (RLS يمنع)
```

---

## 📦 المتطلبات الإضافية (Dependencies)

```yaml
# pubspec.yaml
dependencies:
  # Existing...
  
  # Week 2-3: Sync
  workmanager: ^0.5.2
  
  # Week 4: Error Handling
  logger: ^2.0.2+1
  sentry_flutter: ^7.14.0
  
  # Week 5: Search & Filter
  # (no new packages)
  
  # Week 6: Storage
  file_picker: ^6.1.1
  image_picker: ^1.0.5
  flutter_image_compress: ^2.1.0
  
  # Week 7: Notifications
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^16.2.0
  
  # Week 8: Reports
  pdf: ^3.10.7
  excel: ^4.0.2
  fl_chart: ^0.65.0
  
  # Week 9: Performance
  cached_network_image: ^3.3.0
```

---

## ✅ قائمة المراجعة النهائية (Final Checklist)

### الأمان
- [ ] RLS مفعل على جميع الجداول
- [ ] جميع السياسات مكتوبة ومختبرة
- [ ] Environment variables آمنة
- [ ] لا توجد مفاتيح مكشوفة في الكود

### البيانات
- [ ] جميع الشاشات تستخدم CenterProvider
- [ ] لا توجد dummy data
- [ ] عزل كامل بين السناتر
- [ ] المزامنة تعمل بشكل صحيح

### الواجهة
- [ ] جميع الشاشات responsive
- [ ] Loading states موجودة
- [ ] Error handling موحد
- [ ] رسائل واضحة للمستخدم

### الوظائف
- [ ] Settings تعمل بالكامل
- [ ] Notifications حقيقية
- [ ] Search & Filter يعملان
- [ ] Reports Export يعمل
- [ ] File Upload يعمل

### الأداء
- [ ] Caching مطبق
- [ ] Lazy Loading للقوائم
- [ ] Image Caching يعمل
- [ ] لا توجد مشاكل في الأداء

### الاختبارات
- [ ] Unit Tests للـ BLoCs
- [ ] Widget Tests للشاشات الرئيسية
- [ ] Integration Tests
- [ ] RLS Tests

---

## 🚀 خطة التنفيذ الموصى بها

### الأولوية القصوى (هذا الأسبوع)

**اليوم 1-2**: 
1. ✅ تطبيق سكريبت RLS في Supabase (المهم جداً!)
2. ✅ اختبار RLS مع مستخدمين مختلفين

**اليوم 3-4**:
1. إصلاح Settings Screen بالكامل
2. ربط Dashboard بـ CenterProvider

**اليوم 5-7**:
1. ربط Students & Teachers بالبيانات الحقيقية
2. اختبار إضافة/تعديل/حذف

### الأسبوع الثاني

1. إصلاح بقية الشاشات (Attendance, Payments, Reports)
2. تحسين SyncService
3. إضافة Search & Filter

### الأسبوع الثالث

1. إضافة File Upload
2. تحسين Error Handling
3. حذف Dummy Data
4. اختبار شامل

---

## 📊 مؤشرات النجاح

### قصيرة المدى (أسبوع 1)
- ✅ RLS يعمل بنجاح
- ✅ عزل بيانات 100%
- ✅ Settings فعّال بالكامل
- ✅ 3 شاشات على الأقل تعمل ببيانات حقيقية

### متوسطة المدى (أسبوع 2-3)
- ✅ جميع الشاشات تعمل ببيانات حقيقية
- ✅ Sync موثوق
- ✅ Search & Filter يعملان
- ✅ File Upload يعمل

### طويلة المدى (شهر 1-2)
- ✅ Notifications System كامل
- ✅ Advanced Reports مع Export
- ✅ Performance Optimization
- ✅ جاهز للإنتاج

---

## ⚠️ ملاحظات هامة

### أخطاء شائعة يجب تجنبها

1. **عدم تمرير center_id**: تأكد دائماً من تمرير `centerId` في كل استعلام
2. **RLS غير صحيح**: اختبر السياسات جيداً قبل الإنتاج
3. **Dummy Data**: احذفها تماماً، لا تعلقها فقط
4. **Error Handling**: لا تترك try-catch فارغة
5. **Performance**: لا تحمّل كل البيانات مرة واحدة

### نصائح للنجاح

1. **اختبر باستمرار**: بعد كل تغيير
2. **Commit بشكل متكرر**: لا تفقد عملك
3. **وثّق التغييرات**: علق في الكود
4. **اطلب المراجعة**: من شخص آخر إن أمكن
5. **ابدأ بسيط**: ثم أضف الميزات تدريجياً

---

## 📞 الدعم والمتابعة

إذا واجهت أي مشاكل:
1. راجع documentation في `/docs`
2. تحقق من logs في Supabase Dashboard
3. استخدم AppLogger للتتبع
4. اسأل في GitHub Issues

---

**التوقيع**: AI Assistant  
**التاريخ**: 15 ديسمبر 2025  
**الحالة**: جاهز للتنفيذ الفوري 🚀  
**الأولوية**: CRITICAL - ابدأ الآن!

---

## 🎯 الخلاصة

هذه الخطة شاملة لـ:
- ✅ **9 أسابيع** من العمل المكثف
- ✅ **13 شاشة** كاملة الوظائف
- ✅ **9 نقاط** من المشاكل الحالية (من الملف الأصلي)
- ✅ تحويل التطبيق من **نموذج** إلى **منتج جاهز للإنتاج**

**الخطوة الأولى**: تطبيق سكريبت RLS - هل أنت جاهز؟ 💪