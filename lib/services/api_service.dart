import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class ApiService {
  // Sunucunuzun ana URL'si
  final String baseUrl = 'https://api.nazlihw.com/api';

  // Cihaz hafızasından JWT token'ını okur.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Sunucudan mevcut kullanıcının profil bilgilerini (kredi dahil) çeker.
  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Yetkilendirme token\'ı bulunamadı. Lütfen giriş yapın.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/user-profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Kullanıcı profili alınamadı.');
    }
  }

  // Yeni kullanıcı kaydı yapar.
  Future<Map<String, dynamic>> register(
      String username, String email, String password, String passwordConfirmation) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Accept': 'application/json'},
      body: {
        'username': username,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    final data = json.decode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Kayıt sırasında bir hata oluştu.');
    }
    return data;
  }

  // Kullanıcı girişi yapar ve token'ı kaydeder.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Accept': 'application/json'},
      body: {'email': email, 'password': password},
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data.containsKey('access_token')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['access_token']);
    } else {
      throw Exception(data['error'] ?? 'E-posta veya şifre hatalı.');
    }
    return data;
  }

  // Kullanıcı çıkışı yapar ve token'ı siler.
  Future<void> logout() async {
    final token = await getToken();
    if (token == null) return;

    await http.post(
      Uri.parse('$baseUrl/logout'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // Resimleri sunucuya göndererek analiz başlatır.
  Future<Map<String, dynamic>> analyzeImages(XFile photo1, XFile photo2, {bool useAd = false}) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Yetkilendirme token\'ı bulunamadı.');
    }

    final url = useAd ? '$baseUrl/analyze-with-ad' : '$baseUrl/analyze';
    var request = http.MultipartRequest('POST', Uri.parse(url));
    
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.files.add(await http.MultipartFile.fromPath('front_profile', photo1.path));
    request.files.add(await http.MultipartFile.fromPath('side_profile', photo2.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = json.decode(response.body);

    if (response.statusCode == 402) {
        throw Exception('NO_CREDITS');
    } else if (response.statusCode != 201 && response.statusCode != 202) {
        throw Exception(data['error'] ?? 'Bilinmeyen bir hata oluştu.');
    }

    return data;
  }

  // Satın alma işlemini sunucuya doğrulatır.
  Future<Map<String, dynamic>> purchaseCredits(String receipt, String platform, String productId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Yetkilendirme token\'ı bulunamadı.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/store/add-credits'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'receipt': receipt,
        'platform': platform,
        'product_id': productId,
        'credits': int.tryParse(productId.split('_').last) ?? 1,
      }),
    );

    return json.decode(response.body);
  }

  // Kullanıcının geçmiş analizlerini sunucudan çeker.
  Future<List<dynamic>> getAnalysisHistory() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Yetkilendirme token\'ı bulunamadı.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/analyses'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Analiz geçmişi alınamadı.');
    }
  }

  // Analiz sonucunu PDF olarak indirir.
  Future<File> downloadPdf(int analysisId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Yetkilendirme token\'ı bulunamadı.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/analysis/$analysisId/pdf'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/analiz_$analysisId.pdf');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      throw Exception('PDF indirilemedi.');
    }
  }
}