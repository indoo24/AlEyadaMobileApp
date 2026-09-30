import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../api/envelope.dart';
import 'models.dart';

/// Thin wrapper over the auth endpoints. No decisions live here — it maps calls
/// to DTOs and lets the backend rule on everything else.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Phone **or** email plus password. The backend accepts either as the
  /// identifier and normalises phone formats itself, so the app does not have
  /// to guess which the user typed.
  Future<({AuthTokens tokens, Me user})> login({
    String? phone,
    String? email,
    required String password,
  }) async {
    final body = <String, dynamic>{
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      'password': password,
    };
    final data = unwrapObject(await _api.post(Endpoints.login, body: body, skipAuth: true));
    return (
      tokens: AuthTokens.fromJson(data),
      user: Me.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
    );
  }

  Future<Me> me() async => Me.fromJson(unwrapObject(await _api.get(Endpoints.me)));

  Future<Me> updateMe(Map<String, dynamic> changes) async =>
      Me.fromJson(unwrapObject(await _api.patch(Endpoints.meUpdate, body: changes)));

  /// Blacklists this device's refresh token server-side.
  Future<void> logout(String refreshToken) =>
      _api.post(Endpoints.logout, body: {'refresh': refreshToken});

  Future<List<LegalPolicy>> currentPolicies() async {
    final data = await _api.get(Endpoints.currentPolicies, skipAuth: true);
    final obj = unwrapObjectOrNull(data);
    // The endpoint returns {policies: [...]} — tolerate a bare list too.
    final raw = obj != null ? obj['policies'] : null;
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => LegalPolicy.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return unwrapList(data).map(LegalPolicy.fromJson).toList();
  }

  /// Re-accept policies whose version moved on. Clears `requires_reacceptance`.
  Future<void> acceptConsents(List<String> versionIds) =>
      _api.post(Endpoints.consents, body: {'accepted_policy_versions': versionIds});

  // --- registration -------------------------------------------------------

  /// Creates a patient account. The phone is unverified until an OTP is
  /// confirmed, so the caller moves to the OTP step next.
  Future<void> registerPatient(Map<String, dynamic> payload) =>
      _api.post(Endpoints.registerPatient, body: payload, skipAuth: true);

  /// The doctor join application.
  ///
  /// Returns any imported directory profiles that look like this person, so the
  /// app can offer a claim instead of leaving them with a duplicate. Sent as
  /// multipart because the form may carry a document.
  Future<List<ClaimCandidate>> registerDoctorRequest({
    required Map<String, dynamic> fields,
    Object? multipart,
    void Function(int, int)? onProgress,
  }) async {
    final dynamic body;
    if (multipart != null) {
      body = multipart;
    } else {
      body = fields;
    }
    final res = multipart != null
        ? await _api.upload(
            Endpoints.registerDoctorRequest,
            form: multipart as dynamic,
            onProgress: onProgress,
          )
        : await _api.post(Endpoints.registerDoctorRequest, body: body, skipAuth: true);
    final data = unwrapObjectOrNull(res);
    final candidates = data?['claim_candidates'];
    if (candidates is List) {
      return candidates
          .whereType<Map>()
          .map((e) => ClaimCandidate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  // --- OTP ----------------------------------------------------------------

  /// Ask for a code. Throttled server-side (3/hour by default), which surfaces
  /// as a `throttled` code the UI explains rather than retries.
  Future<void> requestOtp({required String phone, required String purpose}) =>
      _api.post(Endpoints.otpRequest, body: {'phone': phone, 'purpose': purpose}, skipAuth: true);

  /// Verify a code. For signup and login purposes the backend returns a token
  /// pair with the response, so confirming the phone also signs the user in —
  /// which is why this returns tokens rather than just a boolean.
  Future<({bool verified, AuthTokens? tokens, Me? user})> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    final data = unwrapObject(
      await _api.post(
        Endpoints.otpVerify,
        body: {'phone': phone, 'purpose': purpose, 'code': code},
        skipAuth: true,
      ),
    );
    final tokensRaw = data['tokens'];
    final userRaw = data['user'];
    AuthTokens? tokens;
    if (tokensRaw is Map) {
      final t = AuthTokens.fromJson(Map<String, dynamic>.from(tokensRaw));
      if (t.isUsable) tokens = t;
    } else {
      // Some responses inline access/refresh at the top level.
      final t = AuthTokens.fromJson(data);
      if (t.isUsable) tokens = t;
    }
    return (
      verified: data['verified'] == true || tokens != null,
      tokens: tokens,
      user: userRaw is Map ? Me.fromJson(Map<String, dynamic>.from(userRaw)) : null,
    );
  }

  // --- password reset -----------------------------------------------------

  /// Always succeeds from the caller's side: the backend never reveals whether
  /// a phone is registered. The UI must not imply otherwise.
  Future<void> forgotPassword(String phone) =>
      _api.post(Endpoints.passwordForgot, body: {'phone': phone}, skipAuth: true);

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) => _api.post(
    Endpoints.passwordReset,
    body: {'phone': phone, 'code': code, 'new_password': newPassword},
    skipAuth: true,
  );
}

/// An imported profile the applicant may already own.
///
/// Shown *before* any identity has been proven, so it carries only what a
/// stranger could already read on the public profile page.
class ClaimCandidate {
  const ClaimCandidate({
    required this.id,
    required this.slug,
    required this.fullNameAr,
    required this.professionalTitleAr,
    required this.matchScore,
    required this.matchReason,
    this.photo,
  });

  final String id;
  final String slug;
  final String fullNameAr;
  final String professionalTitleAr;
  final int matchScore;
  final String matchReason;
  final String? photo;

  factory ClaimCandidate.fromJson(Map<String, dynamic> j) => ClaimCandidate(
    id: parseString(j['id']),
    slug: parseString(j['slug']),
    fullNameAr: parseString(j['full_name_ar']),
    professionalTitleAr: parseString(j['professional_title_ar']),
    matchScore: parseInt(j['match_score']) ?? 0,
    matchReason: parseString(j['match_reason']),
    photo: j['photo'] as String?,
  );
}
