import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecoflow/historyAngkat.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firestore_service.dart';
import 'package:flutter/material.dart';
import 'notifikasi.dart';
import 'dart:async';
import 'history.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:d_info/d_info.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:firebase_core/firebase_core.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isFirebaseInitialized = false;

  @override
  void initState() {
    super.initState();
    // Panggil fungsi untuk memeriksa koneksi Firebase saat widget diinisialisasi
    _checkFirebaseConnection();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
      if (status.isGranted) {
        print("Notification permission granted");
      } else if (status.isDenied) {
        print("Notification permission denied");
      } else if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      // Inisialisasi Firebase
      await Firebase.initializeApp();
      // Jika berhasil terhubung, set _isFirebaseInitialized menjadi true
      setState(() {
        _isFirebaseInitialized = true;
      });
      // print('Firebase connected successfully');
    } catch (e) {
      // Jika gagal terhubung, cetak pesan kesalahan
      // print('Error connecting to Firebase: $e');
    }
  }

  void _goToNotificationsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotifikasiPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF041D31),
        automaticallyImplyLeading: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
        ),
        title: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Text('EcoFlow',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 20.0,
                  color: Colors.white)),
        ),
        actions: [
          IconButton(
            icon: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            onPressed: () {
              _goToNotificationsPage(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              _isFirebaseInitialized
                  ? Container()
                  : AlertDialog(
                      title: Text('Error'),
                      content: Text('Error connecting to Firebase'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('OK'),
                        ),
                      ],
                    ),
              SizedBox(height: 12.0),
              HeaderContent(),
              BarStatusSampah(),
              TampungSampahSekarang(),
              RiwayatAngkat(),
              Riwayat(),
              SizedBox(height: 10.0),
            ],
          ),
        ),
      ),
    );
  }
}

class HeaderContent extends StatefulWidget {
  @override
  _HeaderContentState createState() => _HeaderContentState();
}

class _HeaderContentState extends State<HeaderContent> {
  late Stream<DateTime> _dateTimeStream;
  late StreamController<DateTime> _controller;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _controller = StreamController<DateTime>();
    _dateTimeStream = _controller.stream;
    _startTimer();
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _startTimer() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      _controller.add(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hii,\nSelamat datang di aplikasi EcoFlow',
                      style: TextStyle(
                          fontSize: 14.0, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(
                        height: 8), // Tambahkan jarak antara teks dan tanggal
                    StreamBuilder<DateTime>(
                      stream: _dateTimeStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          String formattedDate =
                              DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                                  .format(snapshot.data!);
                          return Text(
                            formattedDate,
                            style: TextStyle(
                                fontSize: 12.0, fontWeight: FontWeight.w600),
                          );
                        } else {
                          return Text(
                              '.........................................................',
                              style: TextStyle(
                                  fontSize: 12.0, fontWeight: FontWeight.w600));
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 30),
              Hero(
                tag: 'logo',
                child: Image.asset('images/ecoflow_logo.png',
                    width: 70, height: 70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BarStatusSampah extends StatefulWidget {
  @override
  _BarStatusSampahState createState() => _BarStatusSampahState();
}

class _BarStatusSampahState extends State<BarStatusSampah> {
  final databaseReference = FirebaseDatabase.instance.ref('status_sampah');
  double statusPenampungan = 0.0;
  double statusJaring = 0.0;
  bool _isNotificationSent = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    initFirebaseData();
  }

  void initFirebaseData() {
    final firebaseApp = Firebase.app();
    final rtdb = FirebaseDatabase.instanceFor(
        app: firebaseApp,
        databaseURL:
            'https://ecoflow-11-7-default-rtdb.asia-southeast1.firebasedatabase.app/');
    databaseReference.keepSynced(true);

    DatabaseReference ref =
        rtdb.ref().child('status_sampah').child('status_jaring');
    Stream<DatabaseEvent> stream = ref.onValue;
    stream.listen((DatabaseEvent event) {
      var snapshot = event.snapshot;
      if (snapshot.value != null) {
        setState(() {
          statusJaring = double.parse(snapshot.value.toString());
        });
      }
    });

    DatabaseReference ref2 =
        rtdb.ref().child('status_sampah').child('status_penampungan');
    Stream<DatabaseEvent> stream2 = ref2.onValue;
    stream2.listen((DatabaseEvent event) {
      var snapshot = event.snapshot;
      if (snapshot.value != null) {
        if (_debounce?.isActive ?? false) _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 2), () {
          setState(() {
            statusPenampungan = double.parse(snapshot.value.toString());
            checkPenampunganStatus();
          });
        });
      }
    });
  }

  void checkPenampunganStatus() async {
    double maxLoad = 4.0;
    double warningLoad = 3.0;
    bool shouldSendNotification = false;
    String title = '';
    String description = '';
    String level = '';

    if (statusPenampungan >= maxLoad && !_isNotificationSent) {
      shouldSendNotification = true;
      title = 'Penampungan Sampah Penuh';
      description = 'Penampungan sampah telah mencapai kapasitas maksimal.';
      level = 'danger';
    } else if (statusPenampungan >= warningLoad &&
        statusPenampungan < maxLoad &&
        !_isNotificationSent) {
      shouldSendNotification = true;
      title = 'Penampungan Sampah Hampir Penuh';
      description =
          'Penampungan sampah hampir mencapai kapasitas maksimal. Segera kosongkan penampungan sampah.';
      level = 'warning';
    }

    if (shouldSendNotification) {
      _isNotificationSent = true;
      QuerySnapshot existingNotifications = await FirebaseFirestore.instance
          .collection('notifikasi')
          .where('judul', isEqualTo: title)
          .get();

      if (existingNotifications.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('notifikasi').add({
          'judul': title,
          'deskripsi': description,
          'level': level,
          'waktu': Timestamp.now(),
        });
      }
    } else if (statusPenampungan < warningLoad) {
      _isNotificationSent = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxLoad = 4.0;
    double value = (statusPenampungan / maxLoad) * 100;

    double maxCapacity = 1.8;
    if (statusJaring > 1.8) {
      statusJaring = 1.8;
    }
    double valueCapacity = (statusJaring / maxCapacity) * 100;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      margin: const EdgeInsets.all(16.0),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.7),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Penampungan Sampah',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6.0),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: LinearProgressIndicator(
                    value: value / 100,
                    backgroundColor: const Color(0xFFD9D9D9),
                    minHeight: 7.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      getValueColor(value),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${statusPenampungan.toStringAsFixed(1)} Kg / ${maxLoad.toStringAsFixed(1)} Kg',
                    style: const TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14.0),
            const Text(
              'Status Jaring Sampah',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6.0),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: LinearProgressIndicator(
                    value: valueCapacity / 100,
                    minHeight: 7.0,
                    backgroundColor: const Color(0xFFD9D9D9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      getValueColor(valueCapacity, isCapacity: true),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${valueCapacity.toStringAsFixed(1)} %',
                    style: const TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
          ],
        ),
      ),
    );
  }
}

class TampungSampahSekarang extends StatefulWidget {
  final VoidCallback? onLiftingCompleted;

  const TampungSampahSekarang({Key? key, this.onLiftingCompleted})
      : super(key: key);

  @override
  State<TampungSampahSekarang> createState() => _TampungSampahSekarangState();
}

class _TampungSampahSekarangState extends State<TampungSampahSekarang> {
  final FirestoreService _firestoreService = FirestoreService();

  void _customProgress(BuildContext context) async {
    ProgressDialog pd = ProgressDialog(context: context);

    try {
      // Ambil data status penampungan sebelum proses angkat sampah dimulai
      double statusPenampunganSebelum = await _getStatusPenampungan();

      // Set 'angkat' value to true in Firebase when the lifting process starts
      await FirebaseDatabase.instance.ref('angkat').set("ON");

      // Show progress dialog
      pd.show(
        max: 100,
        msg: 'Menyiapkan...',
        progressType: ProgressType.valuable,
        backgroundColor: Colors.white,
        progressValueColor: Color.fromARGB(255, 29, 47, 111),
        progressBgColor: Colors.white12,
        msgColor: Colors.black,
        valueColor: Colors.black45,
        barrierColor: Colors.black.withOpacity(0.7),
      );

      // Simulate lifting process delay
      await Future.delayed(Duration(milliseconds: 1000));

      for (int i = 0; i <= 100; i++) {
        pd.update(value: i, msg: 'Mengangkat sampah...');
        i++;
        await Future.delayed(Duration(milliseconds: 100));
      }

      pd.close();

      // Set 'angkat' value back to false when the lifting process finishes
      await Future.delayed(Duration(milliseconds: 500));
      await FirebaseDatabase.instance.ref('angkat').set("OFF");

      // Ambil data status penampungan setelah proses angkat sampah selesai
      double statusPenampunganSesudah = await _getStatusPenampungan();

      // Hitung berat sampah yang diangkat
      double beratSampah = double.parse(
          (statusPenampunganSesudah - statusPenampunganSebelum)
              .toStringAsFixed(1));

      // Show success dialog
      DInfo.dialogSuccess(
          context, 'Sampah berhasil diangkat!\nHistori akan disimpan...');
      DInfo.closeDialog(context,
          durationBeforeClose: const Duration(seconds: 2));

      // Wait for 10 seconds before saving to Firestore
      await Future.delayed(Duration(seconds: 10));

      // Save lifting status and timestamp to Firestore
      await _saveToFirestore(beratSampah);

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Histori berhasil disimpan'),
          duration: Duration(seconds: 3),
        ),
      );

      // Setelah proses pengangkatan sampah selesai
      widget.onLiftingCompleted?.call();
    } catch (e) {
      // print('Error in _customProgress: $e');
    }
  }

  Future<double> _getStatusPenampungan() async {
    DatabaseReference reference = FirebaseDatabase.instance
        .ref()
        .child('status_sampah')
        .child('status_penampungan');

    try {
      DataSnapshot snapshot = (await reference.once()).snapshot;

      if (snapshot.value != null) {
        // Convert the snapshot value to a double type before returning
        return double.parse(snapshot.value.toString());
      } else {
        throw Exception('Snapshot does not have a value');
      }
    } catch (e) {
      // print('Error in _getStatusPenampungan: $e');
      throw Exception('Failed to get status penampungan');
    }
  }

  Future<void> _saveToFirestore(double beratSampah) async {
    // Simpan berat sampah ke Firestore
    await _firestoreService.addHistoryAngkat(beratSampah.toString());

    // print('Data saved to Firestore: Berat Sampah: $beratSampah');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      margin: EdgeInsets.all(16.0),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.7),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.delete,
                  color: const Color.fromRGBO(0, 0, 0, 0.451),
                  size: 30.0,
                ),
                SizedBox(height: 15),
                Text(
                  'Tampung Sampah Sekarang',
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.0),
              ],
            ),
            GestureDetector(
              onTap: () async {
                bool? isYes = await DInfo.dialogConfirmation(
                  context,
                  'Tampung Sampah Sekarang?',
                  'Apakah anda yakin ingin mengambil sampah?',
                );
                if (isYes ?? false) {
                  print('user click yes');
                  _customProgress(context);
                } else {
                  print('user click no');
                }
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                margin: EdgeInsets.all(0),
                child: SizedBox(
                  width: 84,
                  height: 60,
                  child: Center(
                    child: Icon(
                      // Icons.power_settings_new_rounded,
                      Icons.power_settings_new_sharp,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RiwayatAngkat extends StatefulWidget {
  RiwayatAngkat({Key? key}) : super(key: key);

  @override
  _RiwayatAngkatState createState() => _RiwayatAngkatState();
}

class _RiwayatAngkatState extends State<RiwayatAngkat> {
  List<Map<String, dynamic>> historyAngkatData = []; // Menyimpan data riwayat

  @override
  void initState() {
    super.initState();
    _fetchHistoryAngkatData();
  }

  Future<void> _fetchHistoryAngkatData() async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await _firestore
          .collection('riwayatAngkat')
          .orderBy('waktu',
              descending:
                  true) // Sorting berdasarkan 'tanggal' dengan descending true
          .get();

      List<Map<String, dynamic>> fetchedData = [];

      querySnapshot.docs.forEach((doc) {
        Timestamp timestamp = doc['waktu'];
        DateTime dateTime = timestamp.toDate();
        String formattedDate =
            DateFormat('EEEE dd/MM/yyyy', 'id_ID').format(dateTime);
        String formattedTime = DateFormat('HH:mm').format(dateTime);
        fetchedData.add({
          'tanggal': formattedDate,
          'waktu': formattedTime,
          'berat': doc['berat'].toString(),
        });
      });

      setState(() {
        historyAngkatData = fetchedData;
      });
    } catch (e) {
      // print('Error fetching history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> limitedData =
        historyAngkatData.isNotEmpty ? historyAngkatData.take(2).toList() : [];

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat angkat sampah',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.history,
              ),
            ],
          ),
          SizedBox(height: 16.0),
          _buildTableHeader(),
          SizedBox(height: 8.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: limitedData.map((item) {
              return _buildDataRow(
                  item['tanggal'], item['waktu'], item['berat']);
            }).toList(),
          ),
          SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: InkWell(
                  onTap: _navigateToHistoryAngkatPage,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 8.0,
                          ),
                        ),
                        SizedBox(width: 3.0),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Hari/Tanggal',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Waktu',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Berat/Kg',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String date, String time, String weight) {
    return Row(
      children: [
        Container(
          width: 180,
          child: Text(
            date,
            style: TextStyle(fontSize: 14.0),
          ),
        ),
        Container(
          width: 50,
          child: Text(
            time,
            style: TextStyle(fontSize: 14.0),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            weight,
            style: TextStyle(fontSize: 14.0),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _navigateToHistoryAngkatPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => HistoryAngkatPage(data: historyAngkatData)),
    ).then((_) {
      // Panggil _fetchHistoryAngkatData setelah kembali dari halaman histori
      _fetchHistoryAngkatData();
    });
  }
}

class Riwayat extends StatefulWidget {
  Riwayat({Key? key}) : super(key: key);

  @override
  _RiwayatState createState() => _RiwayatState();
}

class _RiwayatState extends State<Riwayat> {
  List<Map<String, dynamic>> historyData = []; // Menyimpan data riwayat

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await _firestore
          .collection('riwayat')
          .orderBy('tanggal',
              descending:
                  true) // Sorting berdasarkan 'tanggal' dengan descending true
          .get();

      List<Map<String, dynamic>> fetchedData = [];

      querySnapshot.docs.forEach((doc) {
        Timestamp timestamp = doc['tanggal'];
        DateTime dateTime = timestamp.toDate();
        String formattedDate =
            DateFormat('EEEE dd/MM/yyyy', 'id_ID').format(dateTime);
        fetchedData.add({
          'tanggal': formattedDate,
          'berat': doc['berat'].toString(),
        });
      });

      setState(() {
        historyData = fetchedData;
      });
    } catch (e) {
      // print('Error fetching history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> limitedData =
        historyData.isNotEmpty ? historyData.take(2).toList() : [];

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat buang sampah',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.history,
              ),
            ],
          ),
          SizedBox(height: 16.0),
          _buildTableHeader(),
          SizedBox(height: 8.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: limitedData.map((item) {
              return _buildDataRow(item['tanggal'], item['berat']);
            }).toList(),
          ),
          SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: InkWell(
                  onTap: _navigateToHistoryPage,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4.0, horizontal: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 8.0,
                          ),
                        ),
                        SizedBox(width: 3.0),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Hari/Tanggal',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Jumlah/Kg',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String date, String weight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          date,
          style: TextStyle(fontSize: 14.0),
        ),
        Text(
          weight,
          style: TextStyle(fontSize: 14.0),
        ),
      ],
    );
  }

  void _navigateToHistoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HistoryPage(data: historyData)),
    ).then((_) {
      // Panggil _fetchHistoryData setelah kembali dari halaman histori
      _fetchHistoryData();
    });
  }
}

Color getValueColor(double value, {bool isCapacity = false}) {
  if (isCapacity) {
    if (value <= 45) {
      return Colors.green;
    } else if (value <= 80) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  } else {
    if (value <= 45) {
      return Colors.green;
    } else if (value <= 80) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }
}
