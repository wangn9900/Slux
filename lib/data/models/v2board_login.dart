class V2BoardLoginResponse {
  final String token;
  final int expireAt;
  final int planId;
  final String email;

  V2BoardLoginResponse({
    required this.token,
    required this.expireAt,
    required this.planId,
    required this.email,
  });

  factory V2BoardLoginResponse.fromJson(Map<String, dynamic> json) {
    return V2BoardLoginResponse(
      token: json['token'] ?? '',
      expireAt: json['expire_at'] ?? 0,
      planId: json['plan_id'] ?? 0,
      email: json['email'] ?? '',
    );
  }
}
