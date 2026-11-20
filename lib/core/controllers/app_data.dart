import '../../models/app_user.dart';
import '../repositories/file_repository.dart';
import 'booking_controller.dart';
import 'construction_controller.dart';
import 'customer_controller.dart';
import 'lead_controller.dart';
import 'settings_controller.dart';
import 'site_controller.dart';
import 'user_controller.dart';

/// AppData loads and clears the app's shared data together. Each role fetches
/// only what the server lets it see.
class AppData {
  AppData._();

  /// Throws an ApiException if something could not be fetched.
  static Future<void> loadFor(AppUser user) async {
    final role = user.role;
    await Future.wait([
      SiteController.instance.load(),
      if (role == UserRole.admin || role == UserRole.salesExecutive) BookingController.instance.load(),
      if (role == UserRole.admin || role == UserRole.salesExecutive) LeadController.instance.load(),
      if (role == UserRole.admin || role == UserRole.salesExecutive) CustomerController.instance.load(),
      if (role != UserRole.salesExecutive) ConstructionController.instance.load(),
      if (role == UserRole.admin || role == UserRole.siteManager) UserController.instance.load(),
      if (role == UserRole.admin) SettingsController.instance.load(),
    ]);
  }

  /// Forgets everything on sign-out, so the next user cannot see it.
  static void clear() {
    SiteController.instance.clear();
    BookingController.instance.clear();
    ConstructionController.instance.clear();
    LeadController.instance.clear();
    CustomerController.instance.clear();
    SettingsController.instance.clear();
    UserController.instance.clear();
    FileRepository.instance.clear();
  }
}
