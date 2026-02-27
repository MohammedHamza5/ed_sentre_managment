# دليل استخدام مكونات البحث والفلترة

## نظرة عامة

تم تطوير مجموعة من المكونات القابلة لإعادة الاستخدام لتحسين تجربة البحث والفلترة في التطبيق. هذه المكونات مصممة لتكون متجاوبة مع جميع أحجام الشاشات وتقدم أداءً عالياً حتى مع مجموعات البيانات الكبيرة.

## المكونات المتاحة

### 1. AppSearchBar
شريط البحث الموحد مع دعم التنظيف التلقائي والفلاتر.

**الخصائص:**
- `hintText`: نص التلميح
- `onSearch`: دالة عند البحث
- `onClear`: دالة عند التنظيف
- `width`: عرض الشريط
- `height`: ارتفاع الشريط
- `showFilterButton`: إظهار زر الفلاتر
- `onFilterPressed`: دالة عند الضغط على زر الفلاتر

**مثال الاستخدام:**
```dart
AppSearchBar(
  hintText: 'ابحث عن طالب...',
  onSearch: (query) {
    // تنفيذ البحث
  },
  showFilterButton: true,
  onFilterPressed: () {
    // فتح لوحة الفلاتر
  },
)
```

### 2. FilterPanel
لوحة الفلاتر المتقدمة مع أنواع مختلفة من عناصر التحكم.

**أنواع الفلاتر المدعومة:**
- `text`: حقول نصية
- `dropdown`: قوائم منسدلة
- `dateRange`: نطاق تواريخ
- `checkbox`: مربعات اختيار
- `slider`: شريط تمرير

**مثال الاستخدام:**
```dart
final filters = [
  FilterOption(
    key: 'stage',
    label: 'المرحلة',
    type: FilterType.dropdown,
    options: [
      FilterOptionItem(value: '', label: 'الكل'),
      FilterOptionItem(value: 'ابتدائي', label: 'ابتدائي'),
      FilterOptionItem(value: 'متوسط', label: 'متوسط'),
      FilterOptionItem(value: 'ثانوي', label: 'ثانوي'),
    ],
  ),
];

FilterPanel(
  filters: filters,
  onApply: () {
    // تطبيق الفلاتر
  },
  onReset: () {
    // إعادة تعيين الفلاتر
  },
)
```

### 3. SortWidget
مكون ترتيب النتائج مع دعم الأجهزة المحمولة وسطح المكتب.

**الخصائص:**
- `sortOptions`: قائمة خيارات الترتيب
- `onSortChanged`: دالة عند تغيير الترتيب
- `initialSort`: الخيار الافتراضي

**مثال الاستخدام:**
```dart
final sortOptions = [
  SortOption(key: 'name', label: 'الاسم'),
  SortOption(key: 'stage', label: 'المرحلة'),
];

SortWidget(
  sortOptions: sortOptions,
  onSortChanged: (option) {
    // تطبيق الترتيب
  },
)
```

### 4. SearchFilterBar
شريط البحث والفلترة الكامل الذي يجمع جميع المكونات.

**الخصائص:**
- يجمع بين AppSearchBar و FilterPanel و SortWidget
- يدعم التصميم المتجاوب
- يوفر تجربة موحدة عبر التطبيق

### 5. InfiniteListView
قائمة مع دعم التحميل التدريجي والتمرير اللانهائي.

**الخصائص:**
- `loadData`: دالة لتحميل البيانات حسب الصفحة
- `itemBuilder`: دالة لبناء عناصر القائمة
- `pageSize`: عدد العناصر في كل صفحة
- `enablePullToRefresh`: تمكين السحب للتحديث

### 6. PerformanceOptimizedList
قائمة محسنة للأداء مع دعم التخزين المؤقت.

**الخصائص:**
- `itemId`: دالة لتحديد معرف العنصر
- `enableCaching`: تمكين التخزين المؤقت
- `cacheSize`: حجم التخزين المؤقت

## كيفية التكامل مع BLoC

### 1. تحديث Events
```dart
abstract class StudentsEvent {}

class SearchStudents extends StudentsEvent {
  final String query;
  SearchStudents(this.query);
}

class FilterStudents extends StudentsEvent {
  final Map<String, dynamic> filters;
  FilterStudents(this.filters);
}

class SortStudents extends StudentsEvent {
  final SortOption sortOption;
  SortStudents(this.sortOption);
}
```

### 2. تحديث State
```dart
class StudentsState {
  final List<Student> students;
  final String searchQuery;
  final Map<String, dynamic> filters;
  final SortOption? sortOption;
  
  // ... باقي الخصائص
}
```

### 3. تحديث Bloc
```dart
class StudentsBloc extends Bloc<StudentsEvent, StudentsState> {
  StudentsBloc() : super(StudentsState.initial()) {
    on<SearchStudents>(_onSearchStudents);
    on<FilterStudents>(_onFilterStudents);
    on<SortStudents>(_onSortStudents);
  }
  
  void _onSearchStudents(SearchStudents event, Emitter<StudentsState> emit) {
    // تنفيذ البحث
  }
  
  void _onFilterStudents(FilterStudents event, Emitter<StudentsState> emit) {
    // تنفيذ الفلترة
  }
  
  void _onSortStudents(SortStudents event, Emitter<StudentsState> emit) {
    // تنفيذ الترتيب
  }
}
```

## أفضل الممارسات

### 1. الأداء
- استخدم `PerformanceOptimizedList` للقوائم الكبيرة
- قم بتنفيذ التخزين المؤقت المناسب
- استخدم التحميل التدريجي للبيانات

### 2. تجربة المستخدم
- قدم مؤشرات تحميل واضحة
- قم بتنفيذ رسائل خطأ مفيدة
- اجعل الفلاتر سهلة الوصول

### 3. التصميم المتجاوب
- استخدم `MediaQuery` للكشف عن حجم الشاشة
- قم بتعديل التخطيط حسب الجهاز
- اختبر على أحجام شاشات مختلفة

## أمثلة عملية

### مثال كامل لشاشة البحث
```dart
class StudentsSearchScreen extends StatefulWidget {
  @override
  _StudentsSearchScreenState createState() => _StudentsSearchScreenState();
}

class _StudentsSearchScreenState extends State<StudentsSearchScreen> {
  final List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];
  
  void _performSearch(String query) {
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        return student.name.contains(query) || 
               student.email.contains(query);
      }).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الطلاب')),
      body: Column(
        children: [
          SearchFilterBar(
            onSearch: _performSearch,
            // ... باقي الخصائص
          ),
          Expanded(
            child: InfiniteListView<Student>(
              loadData: (page, pageSize) async {
                // تحميل البيانات من API
                return await _loadStudents(page, pageSize);
              },
              itemBuilder: (context, student) {
                return StudentCard(student: student);
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## استكشاف الأخطاء وإصلاحها

### مشاكل الأداء
- تحقق من استخدام التخزين المؤقت
- تأكد من تطبيق التحميل التدريجي
- راقب استهلاك الذاكرة

### مشاكل التصميم
- تحقق من التوافق مع أحجام الشاشات المختلفة
- تأكد من وضوح العناصر على الشاشات الصغيرة
- اختبر التفاعل باللمس

### مشاكل البيانات
- تحقق من صحة البيانات المُرجعة
- تأكد من معالجة الأخطاء بشكل صحيح
- قم بتنفيذ إعادة المحاولة عند الفشل