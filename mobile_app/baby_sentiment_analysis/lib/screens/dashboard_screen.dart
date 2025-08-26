import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String emotion = "Loading...";
  double confidence = 0.0;
  String time = "--:--:--";
  String imageUrl = "";
  String lastEmotion = "";

  List<FlSpot> emotionHistory = [];
  double timeCounter = 0;

  final Map<String, double> emotionMap = {
    "cry": 0,
    "neutral": 1,
    "happy": 2,
    "sleeping": 3,
  };

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 3), (_) => fetchEmotion());
  }

  Future<void> fetchEmotion() async {
    try {
      final response =
          await http.get(Uri.parse("http://10.0.2.2:5000/emotion"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("📦 API response: $data"); // debug print

        final newEmotion = data["emotion"] ?? "Unknown";
        final newConfidence = (data["confidence"] ?? 0.0).toDouble();
        final newTime = data["timestamp"] ?? "--:--:--";
        final newImageUrl = data["image_url"] ?? "";

        if (newEmotion.toLowerCase() == "cry" &&
            lastEmotion.toLowerCase() != "cry") {
          showCryAlert(newImageUrl);
        }

        setState(() {
          emotion = newEmotion;
          confidence = newConfidence;
          time = newTime;
          imageUrl = newImageUrl;

          if (emotionMap.containsKey(emotion.toLowerCase())) {
            emotionHistory
                .add(FlSpot(timeCounter, emotionMap[emotion.toLowerCase()]!));
            if (emotionHistory.length > 30) {
              emotionHistory.removeAt(0);
            }
            timeCounter += 1;
          }

          lastEmotion = newEmotion;
        });
      } else {
        print("❌ API returned status: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetching emotion: $e");
    }
  }

  void showCryAlert(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("⚠️ Crying Detected"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("The baby seems to be crying!"),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  "$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}",
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Text("📷 No image available"),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Dismiss"),
            ),
          ],
        );
      },
    );
  }

  String getEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case "cry":
        return "😢";
      case "happy":
        return "😊";
      case "neutral":
        return "😐";
      case "sleeping":
        return "😴";
      default:
        return "❓";
    }
  }

  @override
  Widget build(BuildContext context) {
    final String emoji = getEmoji(emotion);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        title: const Text("Live Emotion Monitoring"),
        centerTitle: true,
        elevation: 4,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
            shadowColor: Colors.blueAccent.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 10),
                  Text("Current Emotion",
                      style:
                          TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                  Text(emotion,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("Confidence: ${confidence.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 16)),
                  Text("Last update: $time",
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Emotion Trend (last updates)",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: -0.5,
                  maxY: 3.5,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (y, _) {
                          final label = emotionMap.entries
                              .firstWhere(
                                (e) => e.value == y,
                                orElse: () => const MapEntry("?", 999),
                              )
                              .key;
                          return Text(label,
                              style: const TextStyle(fontSize: 12));
                        },
                        reservedSize: 42,
                      ),
                    ),
                    bottomTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: emotionHistory,
                      isCurved: true,
                      barWidth: 4,
                      dotData: FlDotData(show: false),
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}






// http://10.0.2.2:5000/emotion