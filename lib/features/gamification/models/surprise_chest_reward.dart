enum ChestRewardType {
  gold,
  diamond,
  bird,
  legendaryBonus,
}

class SurpriseChestReward {
  final ChestRewardType type;
  final int goldAmount;
  final int diamondAmount;
  final String? birdFileName;
  final String? birdName;
  final String? birdBadge;
  final String message;
  final bool isPendingYatsi;

  const SurpriseChestReward({
    required this.type,
    this.goldAmount = 0,
    this.diamondAmount = 0,
    this.birdFileName,
    this.birdName,
    this.birdBadge,
    required this.message,
    this.isPendingYatsi = false,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'goldAmount': goldAmount,
    'diamondAmount': diamondAmount,
    'birdFileName': birdFileName,
    'birdName': birdName,
    'birdBadge': birdBadge,
    'message': message,
    'isPendingYatsi': isPendingYatsi,
  };
}
