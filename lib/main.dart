import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'core/db/database_service.dart';
import 'core/db/session_service.dart';
import 'core/gps/gps_service.dart';
import 'screens/session_detail_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GPSService _gpsService = GPSService();
  final SessionService _sessionService = SessionService();

  bool recording = false;

  int? currentSessionId;

  String speed = "0";

  List<Map<String, dynamic>> sessions = [];

  @override
  void initState() {
    super.initState();
    loadSessions();
  }

  Future<void> loadSessions() async {
    final data = await _sessionService.getSessions();

    setState(() {
      sessions = data;
    });
  }
  Future<void> startRecording() async {
    final sessionId = await _sessionService.createSession();

    currentSessionId = sessionId;

    _gpsService.start(
      onData: (Position position) async {
        setState(() {
          speed = (position.speed * 3.6).toStringAsFixed(1);
        });

        final db = await DatabaseService.database;

        await db.insert(
          'telemetry',
          {
            'session_id': sessionId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speed': position.speed * 3.6,
          },
        );
      },
    );

    setState(() {
      recording = true;
    });
  }

  Future<void> stopRecording() async {
    _gpsService.stop();

    if (currentSessionId != null) {
      await _sessionService.endSession(currentSessionId!);
    }

    setState(() {
      recording = false;
    });

    await loadSessions();
  }
 @override
 Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Race Telemetry"),
      ),
      body: Padding(padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            Text(
              "$speed km/h",
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed:
                  recording
                      ? stopRecording
                      : startRecording,
              child: Text(
                recording
                    ? "STOP RECORDING"
                    : "START RECORDING",
              ),
            ),
            const SizedBox(height: 30),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Sessions",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];

                  final start = DateTime.fromMillisecondsSinceEpoch(
                    session['started_at'],
                  );
                   return Card(
                    child: ListTile(
                      title: Text(
                        "Session #${session['id']}",
                      ),
                      subtitle: Text(start.toString()),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => SessionDetailPage(
                                  sessionId: session['id'],
                                ),
                          ),
                        );
                      },
                       ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}