import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const fetchBackground = "fetchBackground";

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize Firestore and FlutterLocalNotificationsPlugin
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Retrieve notifications collection
    final CollectionReference notifikasiCollection =
        firestore.collection('notifikasi');

    // Retrieve latest notifications
    final QuerySnapshot snapshot = await notifikasiCollection
        .orderBy('waktu', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      _showNotification(flutterLocalNotificationsPlugin, data);
    }

    return Future.value(true);
  });
}

void _showNotification(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    Map<String, dynamic> message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'ecoFlow_channel_id',
    'EcoFlow Notifications',
    channelDescription: 'Notifications for EcoFlow updates',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    message['judul'],
    message['deskripsi'],
    platformChannelSpecifics,
    payload: 'item x',
  );
}
