import 'package:meta/meta.dart';

enum Errors {
  fileNotFound,
  yamlParsingFailed,
}

typedef ResultContinuation<T extends Object, V extends Object> = Result<T>
    Function(V value);
typedef ResultReducer<R extends Object, V extends Object> = R Function(
    R total, V value);

@immutable
class Result<V extends Object> {
  final V? value;
  final Errors? error;
  final Object? errorData;
  bool get hasValue => value != null;
  bool get hasError => error != null;

  Result._casted(this.error, this.errorData) : value = null;

  Result.value(V this.value)
      : error = null,
        errorData = null;
  Result.fileNotFound(String this.errorData)
      : error = Errors.fileNotFound,
        value = null;
  Result.yamlParsingFailed(Object this.errorData)
      : error = Errors.yamlParsingFailed,
        value = null;

  String get fileNotFoundPath => errorData as String;
  Object get yamlParsingFailedError => errorData as Object;

  Result<T> cast<T extends Object>() {
    assert(hasError, 'Cast is only allowed on results that have an error');
    return Result<T>._casted(error, errorData);
  }

  Result<T> then<T extends Object>(ResultContinuation<T, V> continuation) =>
      hasError ? cast<T>() : continuation(value!);
}

extension ObjectAsResultExtension<T extends Object> on T {
  Result<T> asResult() => Result<T>.value(this);
}

extension ResultListExtension<V extends Object> on Iterable<Result<V>> {
  Result<List<R>> then<R extends Object>(ResultContinuation<R, V> converter) {
    final results = <R>[];
    for (final result in this) {
      if (result.hasError) return result.cast<List<R>>();
      final convertedResult = converter(result.value!);
      if (convertedResult.hasError) return convertedResult.cast<List<R>>();
      results.add(convertedResult.value!);
    }
    return results.asResult();
  }

  Result<R> reduceResult<R extends Object>(
    ResultReducer<R, V> reducer,
    R initialValue,
  ) {
    var output = initialValue;
    for (final result in this) {
      if (result.hasError) return result.cast<R>();
      output = reducer(output, result.value!);
    }
    return output.asResult();
  }
}

extension ListResultExtension<V extends Object> on Result<Iterable<V>> {
  Result<Iterable<R>> map<R extends Object>(R Function(V value) mapper) {
    if (hasError) return cast<List<R>>();
    return value!.map(mapper).asResult();
  }

  Result<R> reduce<R extends Object>(
    ResultReducer<R, V> reducer,
    R initialValue,
  ) {
    if (hasError) return cast<R>();
    var output = initialValue;
    for (final result in value!) {
      output = reducer(output, result);
    }
    return output.asResult();
  }
}
