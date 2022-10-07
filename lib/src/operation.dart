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

  FirebaseApiException? get error => get('error');

  Map<String, dynamic> get metadata => get('metadata');
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
      throw res.error!;
    }

    return res.getResult<T>()!;
  }
}
