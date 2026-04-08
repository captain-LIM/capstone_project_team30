class UserProfile {
  String nickname;
  List<String> allergies;
  String dietaryRestriction;
  List<String> preferredCuisines;

  UserProfile({
    this.nickname = '',
    List<String>? allergies,
    this.dietaryRestriction = '없음',
    List<String>? preferredCuisines,
  })  : allergies = allergies ?? [],
        preferredCuisines = preferredCuisines ?? [];

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        nickname: json['nickname'] ?? '',
        allergies: List<String>.from(json['allergies'] ?? []),
        dietaryRestriction: json['dietaryRestriction'] ?? '없음',
        preferredCuisines: List<String>.from(json['preferredCuisines'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'allergies': allergies,
        'dietaryRestriction': dietaryRestriction,
        'preferredCuisines': preferredCuisines,
      };
}
