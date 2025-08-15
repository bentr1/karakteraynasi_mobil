import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'analysis_screen.dart';
import 'login_screen.dart';
import 'store_screen.dart';
import 'result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  Future<List<dynamic>>? _analysisHistory;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _analysisHistory = _apiService.getAnalysisHistory();
    });
  }

  Future<void> _logout() async {
    await _apiService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const StoreScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _analysisHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Henüz analiz geçmişiniz yok.'));
          }

          final analyses = snapshot.data!;
          return ListView.builder(
            itemCount: analyses.length,
            itemBuilder: (context, index) {
              final analysis = analyses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: Text('Analiz #${analysis['id']}'),
                  subtitle: Text(
                      'Tarih: ${analysis['created_at'].toString().substring(0, 10)}'),
                  onTap: () {
                    // YORUM: Geçmiş analizi ResultScreen'de açmak için veriyi uygun formata getiriyoruz.
                    final resultData = {'analysis': analysis};
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ResultScreen(analysisResult: resultData),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AnalysisScreen()))
              .then((_) => _loadHistory());
        },
        label: const Text('Yeni Analiz'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
