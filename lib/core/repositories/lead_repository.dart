import '../../models/customer.dart';
import '../../models/lead.dart';
import '../api/api_client.dart';

/// Leads and their follow-ups on the server.
class LeadRepository {
  LeadRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Lead>> fetchLeads() async {
    final page = await _api.get('/leads');
    return [for (final json in page!['items'] as List<dynamic>) Lead.fromJson(json as Map<String, dynamic>)];
  }

  Future<Lead> createLead(Lead lead) async => Lead.fromJson((await _api.post('/leads', body: lead.toJson()))!);

  Future<Lead> updateLead(Lead lead) async =>
      Lead.fromJson((await _api.patch('/leads/${lead.id}', body: lead.toJson()))!);

  /// Makes the lead a customer with [details]; returns both.
  Future<(Lead, CustomerProfile)> convert(String leadId, CustomerProfile details) async {
    final json = (await _api.post('/leads/$leadId/convert', body: details.toJson()))!;
    return (
      Lead.fromJson(json['lead'] as Map<String, dynamic>),
      CustomerProfile.fromJson(json['customer'] as Map<String, dynamic>),
    );
  }

  Future<Lead> addFollowUp(String leadId, FollowUp followUp) async =>
      Lead.fromJson((await _api.post('/leads/$leadId/follow-ups', body: followUp.toJson()))!);
}
