import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/db/database_service.dart';

class SessionDetailPage extends StatefulWidget {
  final int sessionId;

  const SessionDetailPage({super.key, required this.sessionId});

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class ReplayPoint {
  final LatLng position;
  final int timestamp;
  final double speed;

  ReplayPoint({
    required this.position,
    required this.timestamp,
    required this.speed,
  });
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  List<FlSpot> spots = [];

  List<ReplayPoint> replayPoints = [];

  double maxSpeed = 0;

  LatLng? currentReplayPoint;

  int replayIndex = 0;

  Timer? replayTimer;

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

    List<FlSpot> graph = [];
    List<ReplayPoint> route = [];

    for (int i = 0; i < data.length; i++) {
      final speed = (data[i]['speed'] as num).toDouble();

      final lat = (data[i]['latitude'] as num).toDouble();

      final lng = (data[i]['longitude'] as num).toDouble();

      if (speed > maxSpeed) {
        maxSpeed = speed;
      }

      graph.add(FlSpot(i.toDouble(), speed));

      if (lat != 0 && lng != 0) {
        route.add(
          ReplayPoint(
            position: LatLng(lat, lng),
            timestamp: data[i]['timestamp'] as int,
            speed: speed,
          ),
        );
      }
    }

    setState(() {
      spots = graph;
      replayPoints = route;

      if (route.isNotEmpty) {
        currentReplayPoint = route.first.position;
      }
    });
  }

  void startReplay() async {
    replayTimer?.cancel();

    if (replayPoints.length < 2) return;

    replayIndex = 0;

    while (mounted && replayIndex < replayPoints.length - 1) {
      final current = replayPoints[replayIndex];
      final next = replayPoints[replayIndex + 1];

      final delay = next.timestamp - current.timestamp;

      setState(() {
        currentReplayPoint = current.position;
      });

      await Future.delayed(Duration(milliseconds: delay.clamp(10, 1000)));

      replayIndex++;
    }
  }

  @override
  void dispose() {
    replayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,

        title: Text(
          "SESSION ${widget.sessionId}",
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),

      body: replayPoints.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  /// STATS ROW
                  Row(
                    children: [
                      Expanded(
                        child: telemetryCard(
                          title: "MAX SPEED",
                          value: "${maxSpeed.toStringAsFixed(1)}",
                          unit: "KM/H",
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: telemetryCard(
                          title: "POINTS",
                          value: replayPoints.length.toString(),
                          unit: "LOGS",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// MAP CARD
                  Container(
                    height: 320,

                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),

                      borderRadius: BorderRadius.circular(16),
                    ),

                    clipBehavior: Clip.hardEdge,

                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: replayPoints.first.position,

                            initialZoom: 16,
                          ),

                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.apexlog.telemetry',
                              maxZoom: 19,
                            ),

                            PolylineLayer(polylines: buildHeatmapPolylines()),

                            if (currentReplayPoint != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: currentReplayPoint!,

                                    width: 42,
                                    height: 42,

                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red,

                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),

                                      child: const Icon(
                                        Icons.motorcycle,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        /// MAP LABEL
                        Positioned(
                          top: 12,
                          left: 12,

                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),

                            decoration: BoxDecoration(
                              color: Colors.black54,

                              borderRadius: BorderRadius.circular(6),
                            ),

                            child: const Text(
                              "ROUTE REPLAY",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,

                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// REPLAY BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,

                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),

                            onPressed: startReplay,

                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),

                            label: const Text(
                              "START REPLAY",

                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  /// GRAPH LABEL
                  const Text(
                    "SPEED GRAPH",

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// GRAPH CARD
                  Container(
                    height: 280,

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),

                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: LineChart(
                      LineChartData(
                        minY: 0,

                        gridData: FlGridData(
                          show: true,

                          drawVerticalLine: false,

                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.white10,
                              strokeWidth: 1,
                            );
                          },
                        ),

                        borderData: FlBorderData(show: false),

                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),

                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),

                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,

                            isCurved: true,

                            barWidth: 3,

                            color: Colors.red,

                            dotData: const FlDotData(show: false),

                            belowBarData: BarAreaData(
                              show: true,

                              color: Colors.red.withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// HEATMAP LEGEND
                  Container(
                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),

                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          "HEATMAP LEGEND",

                          style: TextStyle(
                            fontWeight: FontWeight.bold,

                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(height: 14),

                        heatmapLegend(Colors.blue, "< 20 km/h"),

                        heatmapLegend(Colors.green, "20 - 40 km/h"),

                        heatmapLegend(Colors.orange, "40 - 70 km/h"),

                        heatmapLegend(Colors.red, "> 70 km/h"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget telemetryCard({
    required String title,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,

            children: [
              Text(
                value,

                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),

              const SizedBox(width: 6),

              Padding(
                padding: const EdgeInsets.only(bottom: 5),

                child: Text(
                  unit,

                  style: const TextStyle(color: Colors.grey, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget heatmapLegend(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,

            decoration: BoxDecoration(
              color: color,

              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(width: 12),

          Text(label),
        ],
      ),
    );
  }

  List<Polyline> buildHeatmapPolylines() {
    List<Polyline> lines = [];

    if (replayPoints.length < 2) {
      return lines;
    }

    for (int i = 0; i < replayPoints.length - 1; i++) {
      final current = replayPoints[i];
      final next = replayPoints[i + 1];

      final speed = current.speed;

      Color color;

      if (speed < 20) {
        color = Colors.blue;
      } else if (speed < 40) {
        color = Colors.green;
      } else if (speed < 70) {
        color = Colors.orange;
      } else {
        color = Colors.red;
      }

      lines.add(
        Polyline(
          points: [current.position, next.position],
          strokeWidth: 6,
          color: color,
        ),
      );
    }

    return lines;
  }
}
