import 'package:flutter/material.dart';

/// UserRole decides which menu, pages and dashboard a user gets.
enum UserRole {
  admin(
    'Admin',
    "Full access: projects, users, approvals, reports and every team's work",
    Icons.admin_panel_settings_outlined,
    Color(0xFF5C7057),
  ),
  salesExecutive(
    'Sales Executive',
    'Customers, leads, bookings, payments and handover',
    Icons.groups_outlined,
    Color(0xFF3F6FB0),
  ),
  siteManager(
    'Site Manager',
    'Construction planning, site assignment, progress and inspection',
    Icons.engineering_outlined,
    Color(0xFF2E8B83),
  ),
  siteIncharge(
    'Site Incharge',
    'Daily construction, labour, materials, photos and site reports',
    Icons.construction_outlined,
    Color(0xFFC98A2E),
  );

  const UserRole(this.label, this.description, this.icon, this.color);

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

/// AppUser is a team member who can sign in.
class AppUser {
  final String id;
  final String name;
  final String username;
  final UserRole role;
  final String phone;

  const AppUser({required this.id, required this.name, required this.username, required this.role, this.phone = ''});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    username: json['username'] as String,
    role: UserRole.values.byName(json['role'] as String),
    phone: json['phone'] as String? ?? '',
  );

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

/// UserChanges is what an Admin changes on an account. The username stays
/// (it is how they sign in); an empty [password] keeps the current one.
class UserChanges {
  final String name;
  final UserRole role;
  final String phone;
  final String password;

  const UserChanges({required this.name, required this.role, this.phone = '', this.password = ''});

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role.name,
    'phone': phone,
    if (password.isNotEmpty) 'password': password,
  };
}

/// NewUser is what an Admin enters to add a team member. The password goes
/// to the server once and is never kept in the app.
class NewUser {
  final String name;
  final String username;
  final String password;
  final UserRole role;
  final String phone;

  const NewUser({
    required this.name,
    required this.username,
    required this.password,
    required this.role,
    this.phone = '',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'username': username,
    'password': password,
    'role': role.name,
    'phone': phone,
  };
}
