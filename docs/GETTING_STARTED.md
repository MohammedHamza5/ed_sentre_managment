# البداية السريعة - EdSentre Project
# Getting Started Guide

## 📋 المتطلبات (Prerequisites)

### Flutter SDK
```bash
flutter --version
# يجب أن يكون Flutter 3.24.0 أو أحدث
```

### Supabase Project
1. قم بإنشاء حساب على [Supabase](https://supabase.com)
2. أنشئ مشروع جديد
3. احصل على:
   - Project URL
   - Anon Key

---

## 🚀 خطوات التشغيل (Setup Steps)

### الخطوة 1: نسخ المستودع
```bash
git clone <repository-url>
cd ed_sentre
```

### الخطوة 2: تثبيت الحزم
```bash
flutter pub get
```

### الخطوة 3: إعداد Supabase

#### 3.1 نسخ ملف الإعدادات
```bash
cp supabase.env.example supabase.env
```

#### 3.2 تعبئة البيانات
افتح `supabase.env` وأضف بياناتك:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

⚠️ **مهم**: لا ترفع ملف `supabase.env` إلى Git (موجود في .gitignore)

### الخطوة 4: إعداد قاعدة البيانات

#### 4.1 تطبيق Schema
1. افتح Supabase Dashboard
2. اذهب إلى SQL Editor
3. انسخ محتوى `full_schema.sql`
4. نفذ الأمر

#### 4.2 تطبيق RLS Policies
1. في SQL Editor
2. انسخ محتوى `docs/rls_policies.sql`
3. نفذ الأمر

#### 4.3 إنشاء مستخدم تجريبي
```sql
-- في Supabase SQL Editor
INSERT INTO auth.users (
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data
) VALUES (
  'admin@test.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"role": "center_admin", "center_id": "your-center-uuid"}'::jsonb
);
```

### الخطوة 5: توليد Drift Code
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### الخطوة 6: تشغيل التطبيق
```bash
# Windows
flutter run -d windows --dart-define-from-file=supabase.env

# Android
flutter run -d android --dart-define-from-file=supabase.env

# iOS
flutter run -d ios --dart-define-from-file=supabase.env
```

---

## 🧪 الاختبار (Testing)

### تشغيل الاختبارات
```bash
flutter test
```

### اختبار التغطية
```bash
flutter test --coverage
```

---

## 📱 البيئات (Environments)

### Development
```bash
flutter run --dart-define-from-file=supabase.env
```

### Staging (المستقبل)
```bash
flutter run --dart-define-from-file=supabase.staging.env
```

### Production (المستقبل)
```bash
flutter run --dart-define-from-file=supabase.prod.env --release
```

---

## 🔐 الأمان (Security)

### ملفات يجب عدم رفعها لـ Git
- `supabase.env`
- `*.env` (جميع ملفات الإعدادات)
- `*.g.dart` (ملفات مولدة)

### التحقق من .gitignore
```bash
cat .gitignore | grep env
# يجب أن تظهر *.env
```

---

## 📚 الوثائق (Documentation)

### الملفات المهمة
- [`architecture.md`](./architecture.md) - البنية المعمارية
- [`project_analysis_and_plan.md`](./project_analysis_and_plan.md) - التحليل والخطة
- [`rls_policies.md`](./rls_policies.md) - سياسات الأمان
- [`sync_design.md`](./sync_design.md) - تصميم المزامنة
- [`runbook.md`](./runbook.md) - دليل التشغيل

---

## 🐛 استكشاف الأخطاء (Troubleshooting)

### خطأ: "Supabase URL not configured"
**الحل**: تأكد من وجود ملف `supabase.env` وتشغيل التطبيق مع `--dart-define-from-file`

### خطأ: "RLS policy prevents access"
**الحل**: 
1. تحقق من تطبيق RLS policies
2. تأكد من أن JWT يحتوي على `role` و `center_id`

### خطأ: "Table does not exist"
**الحل**: تأكد من تطبيق `full_schema.sql`

### خطأ في Build Runner
```bash
# احذف الملفات المولدة القديمة
flutter clean
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
```

---

## 🎯 الخطوات التالية (Next Steps)

1. ✅ اقرأ [`project_analysis_and_plan.md`](./project_analysis_and_plan.md)
2. ✅ راجع التوثيق في مجلد `docs/`
3. ✅ ابدأ بتطبيق RLS (أولوية قصوى)
4. ✅ طور SyncService
5. ✅ اكتب الاختبارات

---

## 👥 المساهمة (Contributing)

### Git Workflow
```bash
# إنشاء فرع جديد
git checkout -b feature/your-feature-name

# عمل Commit
git add .
git commit -m "وصف واضح للتغييرات"

# Push
git push origin feature/your-feature-name

# ثم افتح Pull Request
```

### معايير الكود
- اتبع [Effective Dart](https://dart.dev/guides/language/effective-dart)
- استخدم `flutter analyze` قبل الـ commit
- اكتب اختبارات للميزات الجديدة

---

## 📞 الدعم (Support)

### روابط مفيدة
- [Flutter Documentation](https://flutter.dev/docs)
- [Supabase Documentation](https://supabase.com/docs)
- [Drift Documentation](https://drift.simonbinder.eu/)

---

**آخر تحديث**: 15 ديسمبر 2025  
**الحالة**: ✅ جاهز للاستخدام
