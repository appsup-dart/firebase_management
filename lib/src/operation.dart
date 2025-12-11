import 'package:retry/retry.dart';
import 'package:snapshot/snapshot.dart';

import 'api.dart';

class OperationResult extends UnmodifiableSnapshotView {
  OperationResult(super.snapshot);

  OperationResult.error(FirebaseApiException exception)
      : super(Snapshot.fromJson({
          'error': exception,
        }, decoder: FirebaseApiClient.decoder));

  bool get done => get('done') ?? false;

  T? getResult<T>() => get('response');

  Status? get error => get('error');

  Map<String, dynamic> get metadata => get('metadata');
}

/// The Status type defines a logical error model that is suitable for different
/// programming environments, including REST APIs and RPC APIs.
///
/// Each Status message contains three pieces of data: error code, error message,
/// and error details.
class Status extends UnmodifiableSnapshotView {
  Status(super.snapshot);

  /// The status code, which should be an enum value of google.rpc.Code.
  int get code => get('code');

  /// A developer-facing error message, which should be in English. Any user-facing
  /// error message should be localized and sent in the google.rpc.Status.details
  /// field, or localized by the client.
  String get message => get('message');

  /// A list of messages that carry the error details.  There is a common set of
  /// message types for APIs to use.
  List<Map<String, dynamic>> get details => getList('details') ?? [];
}

class OperationPoller<T> {
  final FirebaseApiClient apiClient;

  OperationPoller(this.apiClient);

  Future<OperationResult> _doPoll(String operationResourceName) async {
    try {
      var res = await apiClient.get<OperationResult>(operationResourceName);

      if (!res.done) {
        throw Exception(
            'Polling incomplete, should trigger retry with backoff');
      }
      return res;
    } on FirebaseApiException catch (err) {
      // Responses with 500 or 503 status code are treated as retriable errors.
      if (err.status == 500 || err.status == 503) {
        rethrow;
      }
      return OperationResult.error(err);
    }
  }

  Future<T> poll(String operationResourceName,
      {Duration maxDelay = const Duration(seconds: 30)}) async {
    var res = await retry<OperationResult>(() => _doPoll(operationResourceName),
        maxDelay: maxDelay);

    if (res.error != null) {
      throw FirebaseOperationException(
        status: res.error!,
      );
    }

    return res.getResult<T>()!;
  }
}
