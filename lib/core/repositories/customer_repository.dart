import '../../models/customer.dart';
import '../api/api_client.dart';

/// Customers on the server. They are made by converting a lead.
class CustomerRepository {
  CustomerRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<CustomerProfile>> fetchCustomers() async {
    final page = await _api.get('/customers');
    return [for (final json in page!['items'] as List<dynamic>) CustomerProfile.fromJson(json as Map<String, dynamic>)];
  }
}
