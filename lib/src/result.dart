import 'package:meta/meta.dart';

enum Errors {
  fileNotFound,
  yamlParsingFailed,
}

@immutable
class FileError {
  FileError({
    required this.path,
    required this.error,
  });
  final String path;
  final Object error;
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
  Result.yamlParsingFailed(FileError this.errorData)
      : error = Errors.yamlParsingFailed,
        value = null;

  String get fileNotFoundPath => errorData as String;
  FileError get yamlParsingFailedError => errorData as FileError;

  Result<T> _cast<T extends Object>() {
    assert(hasError, 'Cast is only allowed on results that have an error');
    return Result<T>._casted(error, errorData);
  }

  Result<T> bind<T extends Object>(ResultContinuation<T, V> continuation) =>
      hasError ? _cast<T>() : continuation(value!);

  Result<T> map<T extends Object>(T Function(V value) converter) =>
      hasError ? _cast<T>() : converter(value!).asResult();
}

extension ObjectAsResultExtension<T extends Object> on T {
  Result<T> asResult() => Result<T>.value(this);
}

extension ResultListExtension<V extends Object> on Iterable<Result<V>> {
  Result<List<R>> bindAll<R extends Object>(
      ResultContinuation<R, V> converter) {
    final results = <R>[];
    for (final result in this) {
      if (result.hasError) return result._cast<List<R>>();
      final convertedResult = converter(result.value!);
      if (convertedResult.hasError) return convertedResult._cast<List<R>>();
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
      if (result.hasError) return result._cast<R>();
      output = reducer(output, result.value!);
    }
    return output.asResult();
  }
}

extension ListResultExtension<V extends Object> on Result<Iterable<V>> {
  Result<Iterable<R>> mapAll<R extends Object>(R Function(V value) mapper) {
    if (hasError) return _cast<List<R>>();
    return value!.map(mapper).asResult();
  }

  Result<R> reduce<R extends Object>(
    ResultReducer<R, V> reducer,
    R initialValue,
  ) {
    if (hasError) return _cast<R>();
    var output = initialValue;
    for (final result in value!) {
      output = reducer(output, result);
    }
    return output.asResult();
  }
}
