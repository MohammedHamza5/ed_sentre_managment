import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/monitoring/app_logger.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;

class SystemDebugLogsScreen extends StatefulWidget {
  const SystemDebugLogsScreen({super.key});

  @override
  State<SystemDebugLogsScreen> createState() => _SystemDebugLogsScreenState();
}

class _SystemDebugLogsScreenState extends State<SystemDebugLogsScreen> {
  List<LogEntry> _logs = [];
  LogType? _filterType;
  LogLevel? _filterLevel;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _logs = AppLogger.getAllLogs().reversed.toList(); // Newest first
    });
  }

  void _clearLogs() {
    AppLogger.clearLogs();
    _refreshLogs();
  }

  List<LogEntry> get _filteredLogs {
    return _logs.where((log) {
      if (_filterType != null && log.type != _filterType) return false;
      if (_filterLevel != null && log.level != _filterLevel) return false;
      return true;
    }).toList();
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return Colors.grey;
      case LogLevel.info: return Colors.blue;
      case LogLevel.warning: return Colors.orange;
      case LogLevel.error: return Colors.red;
      case LogLevel.critical: return Colors.purple;
    }
  }

  String _getTypeEmoji(LogType type) {
    switch (type) {
      case LogType.auth: return '🔐';
      case LogType.database: return '💾';
      case LogType.navigation: return '🧭';
      case LogType.ui: return '🎨';
      case LogType.error: return '❌';
      case LogType.success: return '✅';
      case LogType.info: return 'ℹ️';
      case LogType.warning: return '⚠️';
      case LogType.network: return '🌐';
      case LogType.performance: return '⚡';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجلات النظام (Debug Logs) 🐛'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'نسخ الكل',
            onPressed: () {
              final text = AppLogger.exportLogsAsText();
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ السجلات')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'مسح السجلات',
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Types'),
                  selected: _filterType == null,
                  onSelected: (selected) => setState(() => _filterType = null),
                ),
                const SizedBox(width: 8),
                ...LogType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${_getTypeEmoji(type)} ${type.name}'),
                    selected: _filterType == type,
                    onSelected: (selected) => setState(() => _filterType = selected ? type : null),
                  ),
                )),
              ],
            ),
          ),
          
          Expanded(
            child: _filteredLogs.isEmpty
                ? const Center(child: Text('لا توجد سجلات'))
                : ListView.builder(
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[index];
                      return ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getLevelColor(log.level).withValues(alpha: 0.1),
                          child: Text(_getTypeEmoji(log.type)),
                        ),
                        title: Text(
                          log.message,
                          style: TextStyle(
                            color: log.level == LogLevel.error ? Colors.red : null,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${timeago.format(log.timestamp, locale: 'en_short')} • ${log.level.name.toUpperCase()}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        children: [
                          if (log.data != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              color: isDark ? Colors.black12 : Colors.grey[50],
                              child: SelectableText(
                                'DATA:\n${log.data.toString()}',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          if (log.errorSource != null)
                            ListTile(
                              dense: true,
                              title: Text('Source: ${log.errorSource?.name}'),
                              leading: const Icon(Icons.source, size: 16),
                            ),
                          if (log.stackTrace != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              color: Colors.red.withValues(alpha: 0.05),
                              child: SelectableText(
                                'Stack Trace:\n${log.stackTrace}',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.red),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


