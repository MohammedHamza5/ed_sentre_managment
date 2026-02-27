import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// مخطط الحضور الأسبوعي (Bar Chart)
class WeeklyAttendanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const WeeklyAttendanceChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int maxVal = 0;
    for (var item in data) {
      if (item['present'] > maxVal) maxVal = item['present'];
      if (item['absent'] > maxVal) maxVal = item['absent'];
    }
    final calculatedMaxY = maxVal == 0 ? 10.0 : (maxVal * 1.2).ceilToDouble();
    final interval = (calculatedMaxY / 5).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : null,
        gradient: isDark ? null : AppColors.cardGradientLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الحضور الأسبوعي',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  _LegendItem(color: AppColors.success, label: 'حاضر'),
                  const SizedBox(width: AppSpacing.md),
                  _LegendItem(color: AppColors.error, label: 'غائب'),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: calculatedMaxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: isDark 
                        ? AppColors.darkSurfaceVariant 
                        : AppColors.lightSurfaceVariant,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = data[groupIndex];
                      return BarTooltipItem(
                        '${item['day']}\n',
                        TextStyle(
                          color: isDark 
                              ? AppColors.darkTextPrimary 
                              : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: rodIndex == 0 
                                ? 'حاضر: ${item['present']}' 
                                : 'غائب: ${item['absent']}',
                            style: TextStyle(
                              color: rodIndex == 0 
                                  ? AppColors.success 
                                  : AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[value.toInt()]['day'].toString().substring(0, 3),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark 
                                    ? AppColors.darkTextSecondary 
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark 
                                ? AppColors.darkTextTertiary 
                                : AppColors.lightTextTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                          .withValues(alpha: 0.5),
                      strokeWidth: 1,
                    );
                  },
                  drawVerticalLine: false,
                ),
                barGroups: data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: (item['present'] as int).toDouble(),
                        color: AppColors.success,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: (item['absent'] as int).toDouble(),
                        color: AppColors.error,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// مخطط توزيع الطلاب (Pie Chart)
class StudentDistributionChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;

  const StudentDistributionChart({super.key, required this.data});

  @override
  State<StudentDistributionChart> createState() => _StudentDistributionChartState();
}

class _StudentDistributionChartState extends State<StudentDistributionChart> {
  int touchedIndex = -1;

  final _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.success,
    AppColors.warning,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : null,
        gradient: isDark ? null : AppColors.cardGradientLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع الطلاب حسب المرحلة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: widget.data.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isTouched = index == touchedIndex;
                      final radius = isTouched ? 50.0 : 40.0;
                      final color = _colors[index % _colors.length];
                      
                      // Check transparency/contrast for text
                      final isYellowish = color == AppColors.warning;

                      return PieChartSectionData(
                        color: color,
                        value: (item['percentage'] as num).toDouble(),
                        title: '${item['percentage'].toStringAsFixed(0)}%',
                        radius: radius,
                        titleStyle: TextStyle(
                          fontSize: isTouched ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: isYellowish ? Colors.black : AppColors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _colors[index % _colors.length],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${item['stage']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark 
                                    ? AppColors.darkTextSecondary 
                                    : AppColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            '${item['count']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// مخطط الإيرادات الشهرية (Line Chart)
class MonthlyRevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const MonthlyRevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double maxVal = 0;
    for (var item in data) {
      if ((item['revenue'] as num).toDouble() > maxVal) {
        maxVal = (item['revenue'] as num).toDouble();
      }
    }
    final calculatedMaxY = maxVal == 0 ? 10000.0 : (maxVal * 1.2);
    final interval = calculatedMaxY / 5;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : null,
        gradient: isDark ? null : AppColors.cardGradientLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإيرادات الشهرية',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                          .withValues(alpha: 0.5),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[value.toInt()]['month'].toString().substring(0, 3),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark 
                                    ? AppColors.darkTextSecondary 
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          value >= 1000 ? '${(value / 1000).toInt()}k' : value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark 
                                ? AppColors.darkTextTertiary 
                                : AppColors.lightTextTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: calculatedMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        (entry.value['revenue'] as num).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: AppColors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: isDark 
                        ? AppColors.darkSurfaceVariant 
                        : AppColors.lightSurfaceVariant,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final item = data[spot.x.toInt()];
                        return LineTooltipItem(
                          '${item['month']}\n',
                          TextStyle(
                            color: isDark 
                                ? AppColors.darkTextPrimary 
                                : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: item['revenue'] >= 1000 
                                  ? '${(item['revenue'] / 1000).toStringAsFixed(1)} ألف ج'
                                  : '${item['revenue']} ج',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Legend Item مكون
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}


