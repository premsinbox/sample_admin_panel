import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class FullScreenMap extends StatefulWidget {
  final LatLng initialLocation;
  final String orderId;

  FullScreenMap({required this.initialLocation, required this.orderId});

  @override
  _FullScreenMapState createState() => _FullScreenMapState();
}

class _FullScreenMapState extends State<FullScreenMap> {
  late MqttServerClient _client;
  late LatLng _currentLocation;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
    _setupMqttClient();
  }

  Future<void> _setupMqttClient() async {
    _client = MqttServerClient('test.mosquitto.org', 'admin_panel_fullscreen_${DateTime.now().millisecondsSinceEpoch}');
    _client.port = 1883;
    _client.keepAlivePeriod = 20;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.secure = false;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('admin_panel_fullscreen_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
    } catch (e) {
      print('Exception: $e');
    }
  }

  void _onConnected() {
    print('Connected to MQTT broker');
    _client.subscribe('delivery_locations/${widget.orderId}', MqttQos.atLeastOnce);
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      _processLocationUpdate(payload);
    });
  }

  void _onDisconnected() {
    print('Disconnected from MQTT broker');
  }

  void _processLocationUpdate(String payload) {
    final locationData = json.decode(payload);
    setState(() {
      _currentLocation = LatLng(
        locationData['latitude'],
        locationData['longitude'],
      );
    });
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: MarkerId('delivery_location'),
                position: _currentLocation,
                infoWindow: InfoWindow(title: 'Delivery Location'),
              ),
            },
          ),
          Positioned(
            top: 40,
            left: 10,
            child: FloatingActionButton(
              child: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}