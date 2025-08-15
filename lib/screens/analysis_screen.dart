import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/ad_service.dart';
import 'result_screen.dart';
import 'store_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  _AnalysisScreenState createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  XFile? _photo1;
  XFile? _photo2;
  // DÜZELTME: 'Imagepicker()' olan yazım hatası 'ImagePicker()' olarak düzeltildi.
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  final AdService _adService = AdService();
  bool _isAnalyzing = false; // Analiz işlemi için yüklenme durumu
  bool _isScreenLoading = true; // Ekranın ilk yüklenmesi için durum
  Map<String, dynamic>? _userInfo; // Kullanıcı bilgilerini ve krediyi tutacak

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Ekran açıldığında kullanıcının kredi bilgisini sunucudan çeker.
  Future<void> _fetchUserData() async {
    // İYİLEŞTİRME: Fonksiyonun başında yüklenme durumunu tekrar true yapalım ki
    // mağazadan dönüldüğünde de doğru çalışsın.
    if (!_isScreenLoading && mounted) {
      setState(() {
        _isScreenLoading = true;
      });
    }

    try {
      final userInfo = await _apiService.getUserProfile();
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kullanıcı bilgileri alınamadı: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScreenLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage(int photoNumber, ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        if (photoNumber == 1) {
          _photo1 = pickedFile;
        } else {
          _photo2 = pickedFile;
        }
      });
    }
  }

  void _showImageSourceActionSheet(BuildContext context, int photoNumber) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(photoNumber, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamerayla Çek'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(photoNumber, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _analyze() async {
    if (_photo1 == null || _photo2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen 2 fotoğraf seçin.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result = await _apiService.analyzeImages(_photo1!, _photo2!);
      // Analiz sonrası kredi bilgisini tekrar güncelleyelim.
      await _fetchUserData();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ResultScreen(analysisResult: result)),
        );
      }
    } catch (e) {
      if (e.toString().contains('NO_CREDITS')) {
        _showNoCreditsDialog();
      } else {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Analiz hatası: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showNoCreditsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Krediniz Bitti'),
          content: const Text(
              'Analiz yapmak için krediniz bulunmamaktadır. Kredi satın almak veya reklam izleyerek bir analiz hakkı kazanmak ister misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Kredi Satın Al'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StoreScreen()));
              },
            ),
            TextButton(
              child: const Text('Reklam İzle'),
              onPressed: () {
                Navigator.of(context).pop();
                _adService.showRewardedAd(onAdFailedToLoad: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Reklam yüklenemedi, lütfen tekrar deneyin.')),
                  );
                }, onRewardEarned: () {
                  _analyzeWithAd();
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _analyzeWithAd() async {
    if (_photo1 == null || _photo2 == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result =
          await _apiService.analyzeImages(_photo1!, _photo2!, useAd: true);
      // Reklam sonrası kredi bilgisini tekrar güncelleyelim.
      await _fetchUserData();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ResultScreen(analysisResult: result)),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analiz hatası: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analiz Yap')),
      body: _isScreenLoading
          ? const Center(child: SpinKitCircle(color: Colors.blue, size: 50.0))
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: _isAnalyzing
          ? const SpinKitCircle(color: Colors.blue, size: 50.0)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCreditInfoBar(),
                  const SizedBox(height: 20),
                  _buildPhotoSelector(1, _photo1),
                  const SizedBox(height: 20),
                  _buildPhotoSelector(2, _photo2),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _analyze,
                    child: const Text('Analiz Et'),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildCreditInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mevcut Krediniz: ${_userInfo?['credits'] ?? 0}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StoreScreen()),
              ).then((_) => _fetchUserData()); // Mağazadan dönünce krediyi güncelle
            },
            child: const Text('Kredi Yükle'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSelector(int number, XFile? photo) {
    return GestureDetector(
      onTap: () => _showImageSourceActionSheet(context, number),
      child: Container(
        height: 200,
        width: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: photo == null
            ? Center(child: Text('Fotoğraf $number Seç'))
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }
}
