import 'dart:async';

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

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),

        cardColor: const Color(0xFF1A1A1A),

        colorScheme: const ColorScheme.dark(primary: Colors.red),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F0F),
          elevation: 0,
        ),
      ),

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
  List<Map<String, dynamic>> _buffer = [];

  final GPSService _gpsService = GPSService();

  final SessionService _sessionService = SessionService();

  bool _startingSession = false;

  bool recording = false;

  int? currentSessionId;

  final ValueNotifier<double> speedNotifier = ValueNotifier(0);
  final ValueNotifier<double> gpsNotifier = ValueNotifier(999);

  List<Map<String, dynamic>> sessions = [];

  Timer? clockTimer;

  String localTime = "";

  @override
  void initState() {
    super.initState();

    loadSessions();

    updateClock();

    clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateClock(),
    );
    startLiveGps();
  }

  Future<void> startLiveGps() async {
    if (_gpsService.isRunning) {
      return;
    }

    await _gpsService.start(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 250),

        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "ApexLog speedometer active",
          notificationTitle: "ApexLog Running",
          enableWakeLock: true,
          enableWifiLock: true,
        ),
      ),

      onData: (position) {
        double speedKmh = position.speed * 3.6;

        if (speedKmh.isNaN || speedKmh.isInfinite || speedKmh < 2) {
          speedKmh = 0;
        }

        speedNotifier.value = speedKmh.clamp(0, 999);

        gpsNotifier.value = position.accuracy;

        /// save telemetry if recording
        if (recording && currentSessionId != null) {
          _buffer.add({
            'session_id': currentSessionId,
            'timestamp':
                position.timestamp?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speed': speedKmh,
          });
        }
      },
    );
  }

  void updateClock() {
    final now = DateTime.now();

    setState(() {
      localTime =
          "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}:"
          "${now.second.toString().padLeft(2, '0')}";
    });
  }

  Future<void> loadSessions() async {
    final data = await _sessionService.getSessions();

    setState(() {
      sessions = data;
    });
  }

  Future<void> startRecording() async {
    if (_startingSession || recording) {
      return;
    }

    _startingSession = true;

    try {
      final sessionId = await _sessionService.createSession();

      currentSessionId = sessionId;

      _buffer.clear();

      _gpsService.start(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,

          distanceFilter: 1,

          intervalDuration: const Duration(milliseconds: 100),

          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: "ApexLog is logging telemetry...",

            notificationTitle: "Recording Active",
          ),
        ),

        onData: (Position position) async {
          final kmh = (position.speed * 3.6).clamp(0, 999);

          _buffer.add({
            'session_id': sessionId,
            'timestamp':
                position.timestamp?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speed': kmh,
          });

          if (_buffer.length >= 20) {
            final db = await DatabaseService.database;

            final batch = db.batch();

            for (final point in _buffer) {
              batch.insert('telemetry', point);
            }

            await batch.commit(noResult: true);

            _buffer.clear();
          }
        },
      );

      if (mounted) {
        setState(() {
          recording = true;
        });
      }
    } catch (e) {
      debugPrint("START RECORDING ERROR: $e");
    } finally {
      _startingSession = false;
    }
  }

  Future<void> stopRecording() async {
    if (!recording) return;

    try {
      /// flush remaining telemetry
      if (_buffer.isNotEmpty) {
        final db = await DatabaseService.database;

        final batch = db.batch();

        for (final point in _buffer) {
          batch.insert('telemetry', point);
        }

        await batch.commit(noResult: true);

        _buffer.clear();
      }

      await _gpsService.stop();

      if (currentSessionId != null) {
        await _sessionService.endSession(currentSessionId!);
      }

      currentSessionId = null;

      if (mounted) {
        setState(() {
          recording = false;
        });
      }

      await loadSessions();
    } catch (e) {
      debugPrint("STOP RECORDING ERROR: $e");
    }
  }

  String gpsStatus() {
    if (gpsNotifier.value < 5) {
      return "GPS STRONG";
    }

    if (gpsNotifier.value < 15) {
      return "GPS MEDIUM";
    }

    return "GPS WEAK";
  }

  Color gpsColor() {
    if (gpsNotifier.value < 5) {
      return Colors.green;
    }

    if (gpsNotifier.value < 15) {
      return Colors.orange;
    }

    return Colors.red;
  }

  @override
  void dispose() {
    _gpsService.stop();

    clockTimer?.cancel();

    speedNotifier.dispose();

    gpsNotifier.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "APEXLOG",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),

        centerTitle: false,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),

                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),

                  child: ValueListenableBuilder<double>(
                    valueListenable: gpsNotifier,

                    builder: (_, __, ___) {
                      return Row(
                        children: [
                          Icon(Icons.gps_fixed, size: 16, color: gpsColor()),

                          const SizedBox(width: 8),

                          Text(
                            gpsStatus(),
                            style: TextStyle(
                              color: gpsColor(),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                Text(
                  localTime,
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            /// SPEED DISPLAY
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,

                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                ),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: speedNotifier,
                      builder: (_, speed, __) {
                        return Text(
                          speed.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 96,
                            height: 1,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    ),
                    const Text(
                      "KM/H",
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 4,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: recording ? Colors.red : Colors.grey,

                        borderRadius: BorderRadius.circular(6),
                      ),

                      child: Text(
                        recording ? "RECORDING" : "IDLE",

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// BUTTON
            SizedBox(
              width: double.infinity,
              height: 60,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: recording ? Colors.red : Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                onPressed: recording ? stopRecording : startRecording,

                child: Text(
                  recording ? "STOP SESSION" : "START SESSION",

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: recording ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// SESSIONS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "SESSIONS",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                Text(
                  "${sessions.length} TOTAL",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// SESSION LIST
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: sessions.length,

                itemBuilder: (context, index) {
                  final session = sessions[index];

                  final started = DateTime.fromMillisecondsSinceEpoch(
                    session['started_at'],
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),

                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),

                      title: Text(
                        "SESSION ${session['id']}",

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),

                      subtitle: Text(
                        "${started.day}/${started.month}/${started.year} "
                        "${started.hour}:${started.minute.toString().padLeft(2, '0')}",
                      ),

                      trailing: const Icon(Icons.chevron_right),

                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) =>
                                SessionDetailPage(sessionId: session['id']),
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
