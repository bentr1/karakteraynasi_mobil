import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:io';
import '../services/api_service.dart';

// Google Play Console ve App Store Connect'te tanımladığınız ürün kimlikleri.
const Set<String> _kProductIds = <String>{'credit_10', 'credit_50', 'credit_100'};

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isLoading = true;
  // YENİ EKLENDİ: Satın alma işlemi sırasında butonları devre dışı bırakmak için.
  bool _isPurchasing = false; 
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Hata durumunu yönet
      print("Satın alma akışında hata: $error");
    });
    initStoreInfo();
  }

  Future<void> initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _isAvailable = false;
          _products = [];
          _isLoading = false;
        });
      }
      return;
    }

    final ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails(_kProductIds);

    if (mounted) {
      setState(() {
        _isAvailable = true;
        _products = productDetailResponse.productDetails;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Satın alma bekleniyor... Kullanıcıya bir yüklenme göstergesi gösterilebilir.
        setState(() {
          _isPurchasing = true;
        });
      } else {
        // Satın alma işlemi bittiğinde (başarılı veya hatalı), yüklenme durumunu sıfırla.
        setState(() {
          _isPurchasing = false;
        });

        if (purchaseDetails.status == PurchaseStatus.error) {
          _handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // DÜZELTME: Hem yeni satın alımları hem de yarım kalmış/geri yüklenen işlemleri doğrula.
          _verifyAndCreditPurchase(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _handleError(IAPError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Satın alma hatası: ${error.message}')),
    );
  }

  // İYİLEŞTİRME: Fonksiyon adı, amacını daha iyi yansıtacak şekilde değiştirildi.
  Future<void> _verifyAndCreditPurchase(PurchaseDetails purchaseDetails) async {
    // Bu fonksiyon, satın almanın başarılı olduğunu ve sunucuya doğrulatılması gerektiğini belirtir.
    try {
      setState(() {
        _isPurchasing = true; // Sunucu doğrulaması sırasında da yüklenme göster.
      });

      final String receipt = purchaseDetails.verificationData.serverVerificationData;
      final String platform = Platform.isIOS ? 'apple' : 'google';

      // Sunucuya fişi ve platformu göndererek krediyi eklemesini iste.
      final response = await _apiService.purchaseCredits(
          receipt, platform, purchaseDetails.productID);

      if (response.containsKey('new_credit_balance')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Satın alma başarılı! Yeni kredi: ${response['new_credit_balance']}')),
        );
        // İsteğe bağlı: Kullanıcıyı bir önceki ekrana yönlendir.
        // Navigator.of(context).pop();
      } else {
        _handleError(IAPError(
            source: purchaseDetails.verificationData.source,
            code: 'backend_error',
            message: response['error'] ?? 'Bilinmeyen sunucu hatası'));
      }
    } catch (e) {
      _handleError(IAPError(
          source: purchaseDetails.verificationData.source,
          code: 'network_error', 
          message: e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kredi Satın Al'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isAvailable
              ? const Center(child: Text('Mağaza şu anda kullanılamıyor.'))
              : _products.isEmpty
                  ? const Center(child: Text('Satın alınacak ürün bulunamadı.'))
                  : Stack( // YENİ EKLENDİ: Satın alma sırasında ekranı kaplayan bir yüklenme animasyonu için.
                      children: [
                        ListView.builder(
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final ProductDetails productDetails = _products[index];
                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(Icons.monetization_on),
                                title: Text(productDetails.title),
                                subtitle: Text(productDetails.description),
                                trailing: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.green,
                                    // İYİLEŞTİRME: Satın alma sırasında butonu devre dışı bırak.
                                    disabledBackgroundColor: Colors.grey,
                                  ),
                                  onPressed: _isPurchasing ? null : () {
                                    final PurchaseParam purchaseParam =
                                        PurchaseParam(
                                      productDetails: productDetails,
                                    );
                                    _inAppPurchase.buyConsumable(
                                      purchaseParam: purchaseParam,
                                    );
                                  },
                                  child: Text(productDetails.price),
                                ),
                              ),
                            );
                          },
                        ),
                        // YENİ EKLENDİ: Satın alma işlemi sırasında ekranın ortasında bir yüklenme animasyonu gösterir.
                        if (_isPurchasing)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
