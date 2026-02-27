import '../../../../core/offline/network_monitor.dart';
import '../sources/support_remote_source.dart';

class SupportRepository {
  final SupportRemoteSource _remoteSource;
  final NetworkMonitor _networkMonitor;

  SupportRepository({
    SupportRemoteSource? remoteSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? SupportRemoteSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<String> openSupportTicket({
    required String subject,
    required String description,
    required String category,
    required String priority,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Support tickets can only be created online');
    }
    return await _remoteSource.openSupportTicket(
      subject: subject,
      description: description,
      category: category,
      priority: priority,
    );
  }

  Future<List<Map<String, dynamic>>> getCenterTickets() async {
    if (!_networkMonitor.isOnline) {
      return []; // TODO: Implement local caching
    }
    return await _remoteSource.getCenterTickets();
  }

  Future<Map<String, dynamic>> getTicketDetails(String ticketId) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Ticket details available only online');
    }
    return await _remoteSource.getTicketDetails(ticketId);
  }

  Future<void> addTicketReply({
    required String ticketId,
    required String message,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Replies can only be sent online');
    }
    await _remoteSource.addTicketReply(ticketId: ticketId, message: message);
  }
}


