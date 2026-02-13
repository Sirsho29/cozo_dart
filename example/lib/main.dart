import 'package:flutter/material.dart';

import 'services/db_service.dart';
import 'tabs/compare_tab.dart';
import 'tabs/presets_tab.dart';
import 'tabs/query_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.init();
  await DbService.open();
  runApp(const CozoExampleApp());
}

class CozoExampleApp extends StatelessWidget {
  const CozoExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CozoDB SDK',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const CozoHomePage(),
    );
  }
}

class CozoHomePage extends StatefulWidget {
  const CozoHomePage({super.key});

  @override
  State<CozoHomePage> createState() => _CozoHomePageState();
}

class _CozoHomePageState extends State<CozoHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    DbService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CozoDB SDK'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Query'),
            Tab(icon: Icon(Icons.dashboard), text: 'DB Presets'),
            Tab(icon: Icon(Icons.compare_arrows), text: 'Compare'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          QueryTab(),
          PresetsTab(),
          CompareTab(),
        ],
      ),
    );
  }
}
