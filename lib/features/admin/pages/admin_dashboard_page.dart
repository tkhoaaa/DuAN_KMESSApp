import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../repositories/admin_repository.dart';
import 'admin_appeals_page.dart';
import 'admin_bans_page.dart';
import 'admin_reports_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminRepository _adminRepository = AdminRepository();
  bool _isAdmin = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final user = authRepository.currentUser();
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _isChecking = false;
      });
      return;
    }

    final isAdmin = await _adminRepository.isAdmin(user.uid);
    setState(() {
      _isAdmin = isAdmin;
      _isChecking = false;
    });

    if (!isAdmin && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền truy cập trang này'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text('Bạn không có quyền truy cập'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.report),
              text: 'Reports',
            ),
            Tab(
              icon: Icon(Icons.block),
              text: 'Bans',
            ),
            Tab(
              icon: Icon(Icons.gavel),
              text: 'Appeals',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminReportsPage(),
          AdminBansPage(),
          AdminAppealsPage(),
        ],
      ),
    );
  }
}

