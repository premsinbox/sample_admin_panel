import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:sample_admin_panel/Pages/map.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;

  OrderDetailsPage({required this.orderId});

  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final String _mqttBroker = 'test.mosquitto.org';
  final int _mqttPort = 1883;
  MqttServerClient? _client;
  LatLng? _currentDeliveryLocation;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _setupMqttClient();
  }

  Future<void> _setupMqttClient() async {
    _client = MqttServerClient(_mqttBroker, 'admin_panel_${DateTime.now().millisecondsSinceEpoch}');
    _client!.port = _mqttPort;
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.secure = false;
    _client!.logging(on: true);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('admin_panel_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      print('Exception: $e');
      _reconnect();
    }
  }

  void _onConnected() {
    print('Connected to MQTT broker');
    _client!.subscribe('delivery_locations/${widget.orderId}', MqttQos.atLeastOnce);
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      _processLocationUpdate(payload);
    });
  }

  void _onDisconnected() {
    print('Disconnected from MQTT broker');
    _reconnect();
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void _reconnect() {
    Future.delayed(Duration(seconds: 5), () {
      _setupMqttClient();
    });
  }

  void _processLocationUpdate(String payload) {
    final locationData = json.decode(payload);
    setState(() {
      _currentDeliveryLocation = LatLng(
        locationData['latitude'],
        locationData['longitude'],
      );
    });

    if (_mapController != null && _currentDeliveryLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_currentDeliveryLocation!));
    }
  }

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel Order'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Order not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${widget.orderId}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                _buildDetailItem('Customer', data['customerName']),
                _buildDetailItem('Phone', data['phone']),
                _buildDetailItem('Email', data['email']),
                _buildDetailItem('Address', data['address']),
                _buildDetailItem('Status', data['status']),
                Divider(),
                SizedBox(height: 16),
                Text('Products:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...(data['products'] as List<dynamic>).map((product) => Text('- $product')),
                Divider(),
                SizedBox(height: 16),
                Text('Total Price: ₹${data['totalPrice']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),              
                SizedBox(height: 16),
                Container(
                  height: 300,
                  child: Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        initialCameraPosition: CameraPosition(
                          target: _currentDeliveryLocation ?? LatLng(0, 0),
                          zoom: 15,
                        ),
                        markers: _currentDeliveryLocation != null
                            ? {
                                Marker(
                                  markerId: MarkerId('delivery_location'),
                                  position: _currentDeliveryLocation!,
                                  infoWindow: InfoWindow(title: 'Delivery Location'),
                                ),
                              }
                            : {},
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: FloatingActionButton(
                          child: Icon(Icons.fullscreen),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FullScreenMap(
                                  initialLocation: _currentDeliveryLocation ?? LatLng(0, 0),
                                  orderId: widget.orderId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  

  void _updateOrderStatus(String currentStatus) async {
    String newStatus;
    switch (currentStatus) {
      case 'pending':
        newStatus = 'processing';
        break;
      case 'processing':
        newStatus = 'out_for_delivery';
        break;
      case 'out_for_delivery':
        newStatus = 'delivered';
        break;
      default:
        newStatus = currentStatus;
    }

    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order status updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update order status')));
    }
  }
}
