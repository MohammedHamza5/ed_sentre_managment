
import 'package:flutter/material.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';

class SmartPaymentItemCard extends StatefulWidget {
  final PaymentItem item;
  final Student student;
  final List<PaymentItemType> availableTypes;
  final Function(PaymentItem) onUpdate;
  final VoidCallback onRemove;
  
  // These should be passed from the parent which fetches them based on student enrollments
  final List<Map<String, dynamic>> enrolledSubjects; // {id, name, teacher_id, teacher_name, price}
  final List<Map<String, dynamic>> sessions; // {id, date, status, subject_id}
  final bool isCompact;

  const SmartPaymentItemCard({
    super.key,
    required this.item,
    required this.student,
    required this.availableTypes,
    required this.onUpdate,
    required this.onRemove,
    this.enrolledSubjects = const [],
    this.sessions = const [],
    this.isCompact = false,
  });

  @override
  State<SmartPaymentItemCard> createState() => _SmartPaymentItemCardState();
}

class _SmartPaymentItemCardState extends State<SmartPaymentItemCard> {
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.item.amount > 0 ? widget.item.amount.toString() : '');
    _notesController = TextEditingController(text: widget.item.description);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateType(PaymentItemType? type) {
    if (type == null) return;
    
    // Reset context fields when type changes
    widget.onUpdate(widget.item.copyWith(
      itemType: type,
      teacherId: null,      // Clear teacher
      subjectId: null,      // Clear subject
      relatedEntityId: null, // Clear session/month
      coverageDate: null,
      amount: 0.0,
    ));
    _amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Top Row: Type Selector & Delete
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<PaymentItemType>(
                    value: widget.item.itemType,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      labelText: 'نوع الدفع',
                    ),
                    items: widget.availableTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Text(type.icon),
                            const SizedBox(width: 8),
                            Text(type.arabicName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _updateType,
                  ),
                ),
                if (!widget.isCompact) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: widget.onRemove,
                    tooltip: 'حذف البند',
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // 2. Context Aware Section (The "Smart" part)
            if (widget.item.itemType == PaymentItemType.session)
              _buildSessionContext(isDark)
            else if (widget.item.itemType == PaymentItemType.monthlySubscription)
              _buildMonthContext(isDark)
            else if (widget.item.itemType == PaymentItemType.books)
               _buildBookContext(isDark),

            const SizedBox(height: 16),

            // 3. Amount & Notes
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ (جم)',
                      prefixIcon: Icon(Icons.attach_money, size: 18),
                    ),
                    onChanged: (val) {
                      final amount = double.tryParse(val) ?? 0.0;
                      widget.onUpdate(widget.item.copyWith(amount: amount));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      prefixIcon: Icon(Icons.notes, size: 18),
                    ),
                    onChanged: (val) {
                      widget.onUpdate(widget.item.copyWith(description: val));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget for Session Payments (Hessa)
  Widget _buildSessionContext(bool isDark) {
    // 1. Filter relevant subjects (enrolled ones)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A. Select Subject/Teacher Pair
        DropdownButtonFormField<String>(
          value: widget.item.subjectId,
          hint: const Text('اختر المادة / المدرس'),
          isExpanded: true,
          decoration: const InputDecoration(
             border: OutlineInputBorder(),
             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: widget.enrolledSubjects.map((subject) {
            // value is subject_id
            return DropdownMenuItem(
              value: subject['id'] as String,
              child: Text('${subject['name']} - ${subject['teacher_name']}'),
            );
          }).toList(),
          onChanged: (subjectId) {
            if (subjectId == null) return;
            final selected = widget.enrolledSubjects.firstWhere((s) => s['id'] == subjectId);
            
            // Auto Update Price if available
            final price = (selected['price'] as num?)?.toDouble() ?? 0.0;
            _amountController.text = price.toString();

            widget.onUpdate(widget.item.copyWith(
              subjectId: subjectId,
              subjectName: selected['name'],
              teacherId: selected['teacher_id'],
              amount: price,
            ));
          },
        ),
        
        const SizedBox(height: 12),
        
        // B. Select Specific Session (Optional but recommended)
        if (widget.item.subjectId != null)
           DropdownButtonFormField<String>(
            value: widget.item.relatedEntityId, // session_id
            hint: const Text('تحديد الحصة (اختياري)'),
            isExpanded: true,
             decoration: const InputDecoration(
               border: OutlineInputBorder(),
               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
               helperText: 'يساعد في تتبع الحضور والغياب (مدفوعة/غير مدفوعة)',
            ),
            items: [
               const DropdownMenuItem(value: null, child: Text('بدون تحديد حصة')),
               ...widget.sessions
                   .where((s) => s['subject_id'] == widget.item.subjectId)
                   .map((session) {
                       final date = DateTime.parse(session['date']);
                       final dateStr = DateFormat('dd/MM', 'ar').format(date);
                       return DropdownMenuItem(
                         value: session['id'] as String,
                         child: Text('حصة $dateStr (${session['status'] ?? 'مجدولة'})'),
                       );
                   }),
            ],
            onChanged: (sessionId) {
              widget.onUpdate(widget.item.copyWith(
                relatedEntityId: sessionId,
                relatedEntityType: 'session',
              ));
            },
          ),
      ],
    );
  }

  // Widget for Monthly Subscription
  Widget _buildMonthContext(bool isDark) {
    // Generate next 3 months + previous month
    final now = DateTime.now();
    final months = List.generate(5, (i) {
      return DateTime(now.year, now.month - 1 + i, 1);
    });

    return Column(
      children: [
        Row(
          children: [
            // Subject Selector
            Expanded(
              flex: 3,
               child: DropdownButtonFormField<String>(
                value: widget.item.subjectId,
                hint: const Text('المادة'),
                isExpanded: true,
                items: widget.enrolledSubjects.map((subject) {
                  return DropdownMenuItem(
                    value: subject['id'] as String,
                    child: Text('${subject['name']}'),
                  );
                }).toList(),
                onChanged: (subjectId) {
                   if (subjectId == null) return;
                   final selected = widget.enrolledSubjects.firstWhere((s) => s['id'] == subjectId);
                   // Assuming monthly price might be different? For now using standard price * 4 or defined monthly price
                   // Logic to fetch monthly price would be passed in enrolledSubjects 
                   
                   widget.onUpdate(widget.item.copyWith(
                     subjectId: subjectId,
                     subjectName: selected['name'],
                     teacherId: selected['teacher_id'],
                   ));
                },
              ),
            ),
            const SizedBox(width: 12),
            // Month Selector
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<DateTime>(
                value: widget.item.coverageDate,
                hint: const Text('الشهر'),
                items: months.map((date) {
                  final label = DateFormat('MMMM yyyy', 'ar').format(date);
                  return DropdownMenuItem(
                    value: date,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (date) {
                   widget.onUpdate(widget.item.copyWith(
                     coverageDate: date,
                     relatedEntityType: 'month_subscription',
                   ));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget for Books/Materials
  Widget _buildBookContext(bool isDark) {
      // Could be free text or dropdown of books
       return TextFormField(
          initialValue: widget.item.relatedEntityId, // storing book name or ID here
          decoration: const InputDecoration(
            labelText: 'اسم الكتاب / المذكرة',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) {
             widget.onUpdate(widget.item.copyWith(
               relatedEntityId: val, // treating as string name for simple books
               relatedEntityType: 'book',
             ));
          },
       );
  }
}


