/// Base exception for CozoDB errors.
class CozoException implements Exception {
  final String message;
  const CozoException(this.message);

  @override
  String toString() => 'CozoException: $message';
}

/// Exception thrown when a CozoScript query fails.
class CozoQueryException extends CozoException {
  final String? rawResponse;

  const CozoQueryException({
    required String message,
    this.rawResponse,
  }) : super(message);

  @override
  String toString() => 'CozoQueryException: $message';
}

/// Exception thrown when a database operation fails (open, close, backup, etc.).
class CozoDatabaseException extends CozoException {
  const CozoDatabaseException(super.message);

  @override
  String toString() => 'CozoDatabaseException: $message';
}
