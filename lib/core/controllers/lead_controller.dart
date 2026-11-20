import 'package:flutter/foundation.dart';

import '../../models/booking.dart';
import '../../models/customer.dart';
import '../../models/lead.dart';
import '../api/api_client.dart';
import '../repositories/lead_repository.dart';
import 'customer_controller.dart';

/// LeadController holds enquiries and their follow-ups. Sales Executives
/// get the leads they look after; Admins get all of them.
///
/// The app's [instance] loads from and saves to the server, which applies
/// the rules and throws an ApiException if it refuses a change. A
/// controller made with the default constructor keeps sample leads in
/// memory, applying the same rules, for tests and previews.
class LeadController extends ChangeNotifier {
  /// Converted leads become customers in [customers], or a controller of
  /// its own when none is given.
  LeadController({CustomerController? customers}) : _repository = null, customers = customers ?? CustomerController() {
    _seed();
  }

  LeadController._server() : _repository = LeadRepository(), customers = CustomerController.instance;

  static final LeadController instance = LeadController._server();

  /// Where converted leads go.
  final CustomerController customers;

  final LeadRepository? _repository;
  final List<Lead> _leads = [];
  int _nextId = 1;

  /// Newest first.
  List<Lead> get leads => List.unmodifiable([..._leads]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Lead? leadById(String id) {
    for (final lead in _leads) {
      if (lead.id == id) return lead;
    }
    return null;
  }

  String newId(String prefix) => '$prefix-local-${_nextId++}';

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    final leads = await repository.fetchLeads();
    _leads
      ..clear()
      ..addAll(leads);
    notifyListeners();
  }

  /// Forgets everything on sign-out, so the next user cannot see it.
  void clear() {
    _leads.clear();
    notifyListeners();
  }

  void _keep(Lead lead) {
    final index = _leads.indexWhere((l) => l.id == lead.id);
    if (index == -1) {
      _leads.add(lead);
    } else {
      _leads[index] = lead;
    }
    notifyListeners();
  }

  Future<void> addLead(Lead lead) async {
    final repository = _repository;
    if (repository != null) return _keep(await repository.createLead(lead));
    _checkMobile(lead.mobile);
    _keep(lead);
  }

  /// Saves edited basic details; the follow-ups stay.
  Future<void> updateLead(Lead lead) async {
    final repository = _repository;
    if (repository != null) return _keep(await repository.updateLead(lead));
    final before = leadById(lead.id);
    if (before == null) return;
    _checkMobile(lead.mobile, except: lead.id);
    _keep(before.withDetails(lead));
  }

  /// Records a contact; the lead takes its status and next follow-up date.
  Future<void> addFollowUp(String leadId, FollowUp followUp) async {
    final repository = _repository;
    if (repository != null) return _keep(await repository.addFollowUp(leadId, followUp));
    final lead = leadById(leadId);
    if (lead == null) return;
    final now = DateTime.now();
    if (followUp.date.isAfter(DateTime(now.year, now.month, now.day))) {
      throw const ApiException('FUTURE_DATE', 'A follow-up cannot be dated in the future.');
    }
    final next = followUp.status.isClosed ? null : followUp.nextDate;
    if (next != null && next.isBefore(followUp.date)) {
      throw const ApiException('NEXT_BEFORE_DATE', 'The next follow-up must be on or after this one.');
    }
    _keep(lead.withFollowUp(followUp));
  }

  /// Makes the lead a customer with [details]: the lead is Won and the
  /// customer joins [customers]. One customer per mobile number.
  Future<void> convert(String leadId, CustomerProfile details) async {
    final repository = _repository;
    if (repository != null) {
      final (lead, customer) = await repository.convert(leadId, details);
      _keep(lead);
      customers.keep(customer);
      return;
    }
    final lead = leadById(leadId);
    if (lead == null) return;
    if (lead.isConverted) throw ApiException('ALREADY_CONVERTED', '${lead.name} is already a customer.');
    final existing = customers.byMobileKey(details.mobileKey);
    if (existing != null) {
      throw ApiException('DUPLICATE_CUSTOMER', '${existing.name} is already a customer with this mobile number.');
    }
    final customer = CustomerProfile(
      id: newId('c'),
      name: details.name,
      mobile: details.mobile,
      alternateMobile: details.alternateMobile,
      email: details.email,
      address: details.address,
      occupation: details.occupation,
      notes: details.notes,
      leadId: lead.id,
      source: lead.source,
      ownerName: details.ownerName,
      createdAt: DateTime.now(),
    );
    customers.keep(customer);
    _keep(lead.convertedTo(customer.id, customer.createdAt));
  }

  /// The same mobile number may belong to only one lead, as on the server.
  void _checkMobile(String mobile, {String? except}) {
    final key = Lead.mobileKey(mobile);
    for (final other in _leads) {
      if (other.id != except && Lead.mobileKey(other.mobile) == key) {
        throw ApiException(
          'DUPLICATE_LEAD',
          '${other.name} already has this mobile number, looked after by ${other.ownerName}.',
        );
      }
    }
  }

  /// Sample leads, dated around today so some follow-ups are due.
  void _seed() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset) => today.add(Duration(days: offset));

    _leads.addAll([
      Lead(
        id: 'l1',
        name: 'Suresh Babu',
        mobile: '9848011111',
        area: 'Gajuwaka',
        source: LeadSource.walkIn,
        siteId: 's1',
        siteName: 'Kaira Green Meadows',
        interest: BookingType.withConstruction,
        budget: 4500000,
        status: LeadStatus.interested,
        nextFollowUp: day(0),
        ownerName: 'Priya Sharma',
        createdAt: day(-6),
        followUps: [
          FollowUp(
            id: 'f1',
            date: day(-5),
            mode: FollowUpMode.call,
            note: 'Wants an east facing plot with a 2BHK house.',
            status: LeadStatus.interested,
            nextDate: day(0),
            by: 'Priya Sharma',
          ),
        ],
      ),
      Lead(
        id: 'l2',
        name: 'Anitha Reddy',
        mobile: '9000022222',
        email: 'anitha@example.com',
        source: LeadSource.website,
        siteId: 's7',
        siteName: 'Kaira River Front Plots',
        interest: BookingType.withoutConstruction,
        budget: 1500000,
        status: LeadStatus.siteVisit,
        nextFollowUp: day(-2),
        ownerName: 'Priya Sharma',
        createdAt: day(-12),
        followUps: [
          FollowUp(
            id: 'f2',
            date: day(-10),
            mode: FollowUpMode.whatsApp,
            note: 'Sent the layout and price list.',
            status: LeadStatus.contacted,
            nextDate: day(-7),
            by: 'Priya Sharma',
          ),
          FollowUp(
            id: 'f3',
            date: day(-7),
            mode: FollowUpMode.siteVisit,
            note: 'Visited with family; liked plots 4 and 5.',
            status: LeadStatus.siteVisit,
            nextDate: day(-2),
            by: 'Priya Sharma',
          ),
        ],
      ),
      Lead(
        id: 'l3',
        name: 'Mohan Rao',
        mobile: '9701033333',
        area: 'MVP Colony',
        source: LeadSource.referral,
        notes: 'Referred by Ramesh Naidu.',
        nextFollowUp: day(2),
        ownerName: 'Priya Sharma',
        createdAt: day(-1),
      ),
    ]);
  }
}
