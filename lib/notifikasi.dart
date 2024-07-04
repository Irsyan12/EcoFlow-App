import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotifikasiPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotifikasiPage> {
  final CollectionReference notifikasiCollection =
      FirebaseFirestore.instance.collection('notifikasi');

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Set<String> _shownNotificationIds = {};
  DateTime? _lastOpenedTime;

  @override
  void initState() {
    super.initState();
    _loadLastOpenedTime();
    _listenToFirestoreChanges();
  }

  void _loadLastOpenedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('lastOpenedTime') ?? 0;
    _lastOpenedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  void _updateLastOpenedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    prefs.setInt('lastOpenedTime', now.millisecondsSinceEpoch);
  }

  void _listenToFirestoreChanges() {
    notifikasiCollection.snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final docId = change.doc.id;
          final docTimestamp = data['waktu'] as Timestamp;

          if (!_shownNotificationIds.contains(docId) &&
              (_lastOpenedTime == null ||
                  docTimestamp.toDate().isAfter(_lastOpenedTime!))) {
            _showNotification(data);
            _shownNotificationIds.add(docId);
          }
        }
      }
    });
  }

  void _showNotification(Map<String, dynamic> message) async {
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

  Color _getLevelColor(String level) {
    switch (level) {
      case 'danger':
        return Colors.red;
      case 'warning':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    String formattedDateTime =
        '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    return formattedDateTime;
  }

  @override
  void dispose() {
    _updateLastOpenedTime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF041D31),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 20.0,
            color: Colors.white,
          ),
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: StreamBuilder(
        stream:
            notifikasiCollection.orderBy('waktu', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          var notifikasi = snapshot.data!.docs;
          return ListView.builder(
            itemCount: notifikasi.length,
            itemBuilder: (context, index) {
              var notif = notifikasi[index].data() as Map<String, dynamic>;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: _getLevelColor(notif['level']!),
                    ),
                    title: Text(notif['judul']),
                    subtitle: Text(notif['deskripsi']),
                    trailing: Text(formatTimestamp(notif['waktu']!)),
                  ),
                  Divider(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
