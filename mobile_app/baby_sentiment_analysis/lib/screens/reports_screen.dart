import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<dynamic> logs = [];
  String selectedFilter = "All";
  DateTimeRange? selectedRange;

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    final url = Uri.parse("http://10.0.2.2:5000/emotion-logs");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          logs = data;
        });
      }
    } catch (e) {
      print("❌ Error fetching logs: $e");
    }
  }

  List<dynamic> get filteredLogs {
    List<dynamic> filtered = selectedFilter == "All"
        ? logs
        : logs.where((log) => log["emotion"] == selectedFilter).toList();

    if (selectedRange != null) {
      final start = selectedRange!.start;
      final endInc = selectedRange!.end.add(const Duration(days: 1)); // شامل
      filtered = filtered.where((log) {
        final logTime = DateTime.parse(log["timestamp"]).toLocal();
        return logTime.isAfter(start) && logTime.isBefore(endInc);
      }).toList();
    }
    return filtered;
  }

  Map<String, int> get dailySummary {
    final summary = {"Happy": 0, "Cry": 0, "Neutral": 0, "Sleeping": 0};
    for (var log in filteredLogs) {
      if (summary.containsKey(log["emotion"])) {
        summary[log["emotion"]] = summary[log["emotion"]]! + 1;
      }
    }
    return summary;
  }

  Future<void> generatePdfReport() async {
    try {
      // 1. Create a new PDF document
      final document = PdfDocument();
      final page = document.pages.add();

      // 2. Add title
      page.graphics.drawString(
        'Nursery Emotion Report',
        PdfStandardFont(PdfFontFamily.helvetica, 18),
        bounds: const Rect.fromLTWH(0, 0, 500, 40),
      );

      // 3. Add each emotion entry
      double top = 40;
      for (var log in filteredLogs) {
        final line =
            '${log["timestamp"]} - ${log["emotion"]} (${(log["confidence"] * 100).toStringAsFixed(0)}%)';
        page.graphics.drawString(
          line,
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: Rect.fromLTWH(0, top, 500, 20),
        );
        top += 20;
      }

      // 4. Save PDF to file
      final bytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/emotion_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
// 5. Open PDF using native viewer
      await OpenFile.open(file.path);
    } catch (e) {
      print("❌ PDF export error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to generate PDF: $e")),
        );
      }
    }
  }

  void showImageFullScreen(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Emotion Reports"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: generatePdfReport,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: selectedFilter,
                  items: const [
                    DropdownMenuItem(value: "All", child: Text("All")),
                    DropdownMenuItem(value: "Cry", child: Text("Cry")),
                    DropdownMenuItem(value: "Happy", child: Text("Happy")),
                    DropdownMenuItem(value: "Neutral", child: Text("Neutral")),
                    DropdownMenuItem(
                        value: "Sleeping", child: Text("Sleeping")),
                  ],
                  onChanged: (value) => setState(() => selectedFilter = value!),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedRange = picked);
                    }
                  },
                  child: const Text("Select Date Range"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: dailySummary.entries
                      .map((e) => Column(
                            children: [
                              Text(e.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(e.value.toString()),
                            ],
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                final log = filteredLogs[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () => showImageFullScreen(log["image_url"]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(log["image_url"],
                            height: 50, width: 50, fit: BoxFit.cover),
                      ),
                    ),
                    title: Text("Emotion: ${log["emotion"]}"),
                    subtitle: Text(
                        "Confidence: ${log["confidence"]} | ${log["timestamp"]}"),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
