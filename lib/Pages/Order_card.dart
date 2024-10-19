import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sample_admin_panel/Pages/Order_detailed_page.dart';

class OrderCard extends StatelessWidget {
  final QueryDocumentSnapshot order;

  const OrderCard({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = order.data() as Map<String, dynamic>;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text('My Order #${order.id}'),
        subtitle: Text('Status: ${data['status']}'),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailsPage(orderId: order.id),
            ),
          );
        },
      ),
    );
  }
}