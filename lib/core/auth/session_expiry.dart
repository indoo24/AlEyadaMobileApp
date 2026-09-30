/// A one-way signal from the transport layer to the session layer.
///
/// It exists to break a dependency cycle that would otherwise be real, not just
/// an inference complaint: the API client needs to report "the refresh token was
/// rejected", and the auth controller needs to act on it — but the auth
/// controller is built *on top of* the API client, so it cannot also be a
/// dependency of it.
///
/// Routing this through a tiny object both can depend on keeps the direction of
/// dependency honest: transport knows nothing about sessions, and the session
/// layer subscribes to a fact rather than being called into.
class SessionExpiry {
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Reports that a refresh was genuinely rejected — not that the network
  /// failed, which the caller must distinguish before calling this.
  void signal() {
    // Iterate a copy: a listener may remove itself in response.
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}
