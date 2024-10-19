import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sample_admin_panel/Pages/Order_list.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(AdminApp());
}

class AdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: AdminHomePage(),
    );
  }
}

class AdminHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
      ),
      body: OrdersList(),
    );
  }
}
