import 'package:flutter/foundation.dart';

import '../../models/customer.dart';
import '../repositories/customer_repository.dart';

/// CustomerController holds customers made from leads. Customers who only
/// have bookings come from the bookings themselves.
class CustomerController extends ChangeNotifier {
  /// In memory, for tests and previews.
  CustomerController() : _repository = null;

  CustomerController._server() : _repository = CustomerRepository();

  static final CustomerController instance = CustomerController._server();

  final CustomerRepository? _repository;
  final List<CustomerProfile> _customers = [];

  /// Newest first.
  List<CustomerProfile> get customers =>
      List.unmodifiable([..._customers]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  CustomerProfile? byMobileKey(String key) {
    for (final customer in _customers) {
      if (customer.mobileKey == key) return customer;
    }
    return null;
  }

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    final customers = await repository.fetchCustomers();
    _customers
      ..clear()
      ..addAll(customers);
    notifyListeners();
  }

  /// Keeps a customer the server (or a local conversion) just made.
  void keep(CustomerProfile customer) {
    _customers
      ..removeWhere((c) => c.id == customer.id)
      ..add(customer);
    notifyListeners();
  }

  /// Forgets everything on sign-out, so the next user cannot see it.
  void clear() {
    _customers.clear();
    notifyListeners();
  }
}
