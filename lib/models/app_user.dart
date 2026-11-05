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
  final String password;
  final UserRole role;
  final String phone;

  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.role,
    this.phone = '',
  });

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
