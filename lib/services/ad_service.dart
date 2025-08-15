import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdService {
  RewardedAd? _rewardedAd;

  final String _rewardedAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  void showRewardedAd({
    required Function onRewardEarned,
    required Function onAdFailedToLoad,
  }) {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _setAdCallbacks(
              onRewardEarned: onRewardEarned,
              onAdFailedToLoad: onAdFailedToLoad);
          _rewardedAd?.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              onRewardEarned();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          onAdFailedToLoad();
        },
      ),
    );
  }

  void _setAdCallbacks({
    required Function onRewardEarned,
    required Function onAdFailedToLoad,
  }) {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        onAdFailedToLoad();
      },
    );
  }
}
