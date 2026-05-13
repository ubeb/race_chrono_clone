import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/db/database_service.dart';

class SessionDetailPage extends StatefulWidget {
  final int sessionId;

  const SessionDetailPage({super.key, required this.sessionId});

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  List<FlSpot> spots = [];

  double maxSpeed = 0;

  @override
  void initState() {
    super.initState();
    loadTelemetry();
  }

  Future<void> loadTelemetry() async {
    final db = await DatabaseService.database;

    final data = await db.query(
      'telemetry',
      where: 'session_id = ?',
      whereArgs: [widget.sessionId],
      orderBy: 'timestamp ASC',
    );

    List<FlSpot> temp = [];

    for (int i = 0; i < data.length; i++) {
      final speed = (data[i]['speed'] as num).toDouble();

      if (speed > maxSpeed) {
        maxSpeed = speed;
      }
      temp.add(FlSpot(i.toDouble(), speed));
    }

    setState(() {
      spots = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Session ${widget.sessionId}")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Max Speed: ${maxSpeed.toStringAsFixed(1)} km/h",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
