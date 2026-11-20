import '../../models/booking.dart';
import '../api/api_client.dart';

/// Bookings and their payments on the server.
class BookingRepository {
  BookingRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Booking>> fetchBookings() async {
    final page = await _api.get('/bookings');
    return [for (final json in page!['items'] as List<dynamic>) Booking.fromJson(json as Map<String, dynamic>)];
  }

  Future<Booking> createBooking(Booking booking) async =>
      Booking.fromJson((await _api.post('/bookings', body: booking.toCreateJson()))!);

  Future<Booking> approve(String id) async => Booking.fromJson((await _api.post('/bookings/$id/approve'))!);

  Future<Booking> reject(String id) async => Booking.fromJson((await _api.post('/bookings/$id/reject'))!);

  Future<Booking> updateBooking(Booking booking) async =>
      Booking.fromJson((await _api.patch('/bookings/${booking.id}', body: booking.toUpdateJson()))!);

  Future<Booking> resubmit(Booking booking) async =>
      Booking.fromJson((await _api.post('/bookings/${booking.id}/resubmit', body: booking.toUpdateJson()))!);

  Future<Booking> updateLoanStatus(String id, PaymentPart part, LoanStatus status) async =>
      Booking.fromJson((await _api.patch('/bookings/$id/loans/${part.name}', body: {'status': status.name}))!);

  Future<Booking> addPayment(String id, PaymentEntry payment) async =>
      Booking.fromJson((await _api.post('/bookings/$id/payments', body: payment.toJson()))!);
}
