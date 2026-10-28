/// Optional API diagnostics, independent of Flutter and desktop storage.
abstract interface class ApiRequestLogger {
  Future<void> logRequest(String title, String details);
  Future<void> logResponse(String title, String details);
  Future<void> logError(String title, String details);
}
