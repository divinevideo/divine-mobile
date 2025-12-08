/// {@template gateway_exception}
/// Exception thrown when gateway request fails
/// {@endtemplate}
class GatewayException implements Exception {

  /// {@macro gateway_exception}
  const GatewayException(this.message, {this.statusCode});

  /// Message describing the exception
  final String message;
  /// Status code of the exception
  final int? statusCode;

  @override
  String toString() => 'GatewayException: $message (status: $statusCode)';
}
