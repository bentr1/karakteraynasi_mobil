import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> analysisResult;

  const ResultScreen({super.key, required this.analysisResult});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isDownloadingPdf = false;
  bool _isDownloadingAudio = false;

  Future<void> _listenToAnalysis() async {
    setState(() {
      _isDownloadingAudio = true;
    });
    try {
      final token = await _apiService.getToken();
      final url = Uri.parse(
          '${_apiService.baseUrl}/analyses/${widget.analysisResult['analysis']['id']}/audio');

      final response =
          await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/analysis_audio.mp3');
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          _isDownloadingAudio = false;
          _isPlaying = true;
        });

        await _audioPlayer.play(DeviceFileSource(file.path));

        _audioPlayer.onPlayerStateChanged.listen((state) {
          if (mounted &&
              (state == PlayerState.completed ||
                  state == PlayerState.stopped)) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      } else {
        throw Exception('Ses dosyası indirilemedi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isDownloadingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seslendirme hatası: $e')),
        );
      }
    }
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isDownloadingPdf = true;
    });
    try {
      final file = await _apiService.downloadPdf(
          widget.analysisResult['analysis']['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF başarıyla indirildi: ${file.path}')),
      );

      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF indirme hatası: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysisText = widget.analysisResult['analysis']?['analysis_text'] ??
        'Analiz sonucu bulunamadı.';

    return Scaffold(
      appBar: AppBar(title: const Text('Analiz Sonucu')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Karakter Analiziniz',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  analysisText,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isDownloadingPdf ? null : _downloadPdf,
                    icon: _isDownloadingPdf
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF Olarak Kaydet'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: (_isPlaying || _isDownloadingAudio)
                        ? () => _audioPlayer.stop()
                        : _listenToAnalysis,
                    icon: _isDownloadingAudio
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(_isPlaying
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up),
                    label: Text(_isPlaying ? 'Durdur' : 'Sesli Dinle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlaying
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}