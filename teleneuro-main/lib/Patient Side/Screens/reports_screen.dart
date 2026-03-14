import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kPrimaryColor = Color(0xFF1565C0);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<String> reports = [];
  @override void initState() { super.initState(); _loadReports(); }
  Future<void> _loadReports() async {
    final p = await SharedPreferences.getInstance();
    setState(() => reports = p.getStringList('saved_reports') ?? []);
  }
  @override Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("Reports"), backgroundColor: kPrimaryColor),
      body: reports.isEmpty
          ? const Center(child: Text("No Reports Found"))
          : ListView.builder(
          itemCount: reports.length,
          itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(reports[i])
          )
      )
  );
}