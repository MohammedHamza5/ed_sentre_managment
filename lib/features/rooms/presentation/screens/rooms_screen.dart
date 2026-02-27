import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/models/models.dart';
import '../../data/repositories/rooms_repository.dart';
import '../../bloc/rooms_bloc.dart';

/// شاشة إدارة القاعات
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final centerProvider = context.watch<CenterProvider>();

    if (!centerProvider.hasCenter) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 64),
            SizedBox(height: 16),
            Text('لم يتم العثور على بيانات السنتر'),
          ],
        ),
      );
    }

    return BlocProvider(
      create: (context) => RoomsBloc(
        repository: context.read<RoomsRepository>(),
        centerId: centerProvider.centerId!,
      )..add(LoadRooms()),
      child: const _RoomsView(),
    );
  }
}

class _RoomsView extends StatelessWidget {
  const _RoomsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ResponsiveUtils.getPagePadding(context);
    final strings = AppStrings.of(context);

    return BlocListener<RoomsBloc, RoomsState>(
      listener: (context, state) {
        if (state.status == RoomsStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? strings.errorOccurred),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<RoomsBloc, RoomsState>(
        builder: (context, state) {
          if (state.status == RoomsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final availableRooms = state.rooms
              .where((r) => r.status == RoomStatus.available)
              .length;
          final occupiedRooms = state.rooms
              .where((r) => r.status == RoomStatus.occupied)
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              context.read<RoomsBloc>().add(LoadRooms());
            },
            child: SingleChildScrollView(
              padding: padding,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Region
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.roomsManagement,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.roomsManagementSubtitle,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      AppButton(
                        text: strings.addRoom,
                        icon: Icons.add_rounded,
                        onPressed: () => _showAddRoomDialog(context, strings),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Stats Overlay
                  _RoomsStats(
                    total: state.rooms.length,
                    available: availableRooms,
                    occupied: occupiedRooms,
                    strings: strings,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Rooms List
                  if (state.rooms.isEmpty)
                    _buildEmptyState(context, strings, isDark)
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.rooms.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final room = state.rooms[index];
                        return _RoomCard(
                          room: room,
                          isDark: isDark,
                          strings: strings,
                          onToggleStatus: () =>
                              _toggleRoomStatus(context, room, strings),
                          onEdit: () =>
                              _showEditRoomDialog(context, room, strings),
                          onDelete: () =>
                              _showDeleteDialog(context, room, strings),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppStrings strings,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.meeting_room_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              strings.noRooms,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.isArabic
                  ? 'قم بإضافة قاعات دراسية لبدء تنظيم الجدول'
                  : 'Add classrooms to start organizing the schedule',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRoomStatus(BuildContext context, Room room, AppStrings strings) {
    final newStatus = room.status == RoomStatus.available
        ? RoomStatus.occupied
        : RoomStatus.available;

    final updatedRoom = Room(
      id: room.id,
      number: room.number,
      name: room.name,
      capacity: room.capacity,
      equipment: room.equipment,
      status: newStatus,
    );

    context.read<RoomsBloc>().add(UpdateRoom(updatedRoom));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${strings.statusUpdated}: "${room.name}"'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context, AppStrings strings) {
    final roomsBloc = context.read<RoomsBloc>();
    final numberController = TextEditingController();
    final nameController = TextEditingController();
    final capacityController = TextEditingController();
    final List<String> selectedEquipment = [];
    final equipmentOptions = strings.equipmentList;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.meeting_room,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(strings.addRoom),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: numberController,
                          decoration: InputDecoration(
                            labelText: strings.roomNumber,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: capacityController,
                          decoration: InputDecoration(
                            labelText: strings.capacity,
                            suffixText: strings.students,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: strings.roomName,
                      helperText: strings.isArabic
                          ? 'مثال: القاعة الرئيسية، قاعة الكيمياء'
                          : 'e.g. Main Hall, Chemistry Lab',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    strings.equipment,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: equipmentOptions.map((eq) {
                      final isSelected = selectedEquipment.contains(eq);
                      return FilterChip(
                        label: Text(eq),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedEquipment.add(eq);
                            } else {
                              selectedEquipment.remove(eq);
                            }
                          });
                        },
                        backgroundColor: Theme.of(context).cardColor,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (numberController.text.isEmpty ||
                    nameController.text.isEmpty ||
                    capacityController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.fillRequiredFields)),
                  );
                  return;
                }

                // Check for duplicates
                final isDuplicate = roomsBloc.state.rooms.any(
                  (r) =>
                      r.name.trim().toLowerCase() ==
                      nameController.text.trim().toLowerCase(),
                );

                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.isArabic
                            ? 'هذا الاسم موجود بالفعل'
                            : 'Room name already exists',
                      ),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final newRoom = Room(
                  id: '',
                  number: numberController.text,
                  name: nameController.text,
                  capacity: int.tryParse(capacityController.text) ?? 30,
                  equipment: selectedEquipment,
                  status: RoomStatus.available,
                );

                roomsBloc.add(AddRoom(newRoom));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${strings.success}: "${newRoom.name}"'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: Text(strings.add),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRoomDialog(
    BuildContext context,
    Room room,
    AppStrings strings,
  ) {
    final roomsBloc = context.read<RoomsBloc>();
    final nameController = TextEditingController(text: room.name);
    final capacityController = TextEditingController(
      text: room.capacity.toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${strings.edit}: ${room.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: strings.roomName,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: capacityController,
                decoration: InputDecoration(
                  labelText: strings.capacity,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedRoom = Room(
                id: room.id,
                number: room.number,
                name: nameController.text,
                capacity:
                    int.tryParse(capacityController.text) ?? room.capacity,
                equipment: room.equipment,
                status: room.status,
              );
              roomsBloc.add(UpdateRoom(updatedRoom));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(strings.success),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Room room, AppStrings strings) {
    final roomsBloc = context.read<RoomsBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.delete),
        content: Text(
          '${strings.isArabic ? "هل أنت متأكد من حذف القاعة" : "Are you sure you want to delete room"} "${room.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              roomsBloc.add(DeleteRoom(room.id));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${strings.delete}: ${room.name}')),
              );
            },
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }
}

class _RoomsStats extends StatelessWidget {
  final int total;
  final int available;
  final int occupied;
  final AppStrings strings;
  final bool isDark;

  const _RoomsStats({
    required this.total,
    required this.available,
    required this.occupied,
    required this.strings,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: strings.allRooms,
            value: total.toString(),
            color: AppColors.primary,
            icon: Icons.meeting_room,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            title: strings.available,
            value: available.toString(),
            color: AppColors.success,
            icon: Icons.check_circle_outline,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            title: strings.occupied,
            value: occupied.toString(),
            color: AppColors.warning,
            icon: Icons.access_time,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final bool isDark;
  final AppStrings strings;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoomCard({
    required this.room,
    required this.isDark,
    required this.strings,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getStatusColor() {
    switch (room.status) {
      case RoomStatus.available:
        return AppColors.success;
      case RoomStatus.occupied:
        return AppColors.warning;
      case RoomStatus.maintenance:
        return AppColors.error;
    }
  }

  String _getStatusText() {
    switch (room.status) {
      case RoomStatus.available:
        return strings.available;
      case RoomStatus.occupied:
        return strings.occupied;
      case RoomStatus.maintenance:
        return strings.maintenance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(right: BorderSide(color: statusColor, width: 4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleStatus,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // Room Number Badge
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        room.number,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            room.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _getStatusText(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Details Row
                      Row(
                        children: [
                          _buildDetailItem(
                            Icons.people_outline,
                            '${room.capacity} ${strings.students}',
                            isDark,
                          ),
                          const SizedBox(width: 16),
                          if (room.equipment.isNotEmpty)
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: room.equipment.map((eq) {
                                    return Container(
                                      margin: const EdgeInsetsDirectional.only(
                                        end: 4,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.grey[300]!,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        eq,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                Row(
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        size: 20,
                      ),
                      tooltip: strings.edit,
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      tooltip: strings.delete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
