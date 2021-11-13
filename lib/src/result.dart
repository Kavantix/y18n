import 'package:meta/meta.dart';

enum _FailureTypes {
  fileNotFound,
  yamlParsingFailed,
  yamlStructureInvalid,
}

class FilePath {
  FilePath(this.value);

  final String value;
}

class YamlInvalidExplanation {
  YamlInvalidExplanation(this.value);
  final String value;
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

class Failure {
  Failure._(
    this.type, {
    this.filePath,
    this.fileError,
    this.yamlInvalidExplanation,
  });
  factory Failure.fileNotFound(FilePath filePath) =>
      Failure._(_FailureTypes.fileNotFound, filePath: filePath);
  factory Failure.yamlParsingFailed(FileError fileError) =>
      Failure._(_FailureTypes.yamlParsingFailed, fileError: fileError);
  factory Failure.yamlStructureInvalid(
    YamlInvalidExplanation yamlInvalidExplanation,
  ) =>
      Failure._(
        _FailureTypes.yamlStructureInvalid,
        yamlInvalidExplanation: yamlInvalidExplanation,
      );

  final _FailureTypes type;
  final FilePath? filePath;
  final FileError? fileError;
  final YamlInvalidExplanation? yamlInvalidExplanation;

  T match<T>({
    required T Function(FilePath filePath) fileNotFound,
    required T Function(FileError fileError) yamlParsingFailed,
    required T Function(YamlInvalidExplanation yamlInvalidExplanation)
        yamlStructureInvalid,
  }) {
    switch (type) {
      case _FailureTypes.fileNotFound:
        // ignore: unnecessary_this
        return fileNotFound(this.filePath!);
      case _FailureTypes.yamlParsingFailed:
        // ignore: unnecessary_this
        return yamlParsingFailed(this.fileError!);
      case _FailureTypes.yamlStructureInvalid:
        // ignore: unnecessary_this
        return yamlStructureInvalid(this.yamlInvalidExplanation!);
    }
  }
}

@immutable
class Result<V extends Object> {
  final V? value;
  final Failure? failure;
  bool get _hasValue => value != null;
  bool get _hasFailure => failure != null;

  Result._casted(this.failure) : value = null;

  Result.value(V this.value) : failure = null;
  Result.failure(Failure this.failure) : value = null;

  Result<T> _cast<T extends Object>() {
    assert(_hasFailure, 'Cast is only allowed on results that have an error');
    return Result<T>._casted(failure);
  }

  Result<T> bind<T extends Object>(ResultContinuation<T, V> continuation) =>
      _hasFailure ? _cast<T>() : continuation(value!);

  Result<T> map<T extends Object>(T Function(V value) converter) =>
      _hasFailure ? _cast<T>() : converter(value!).asResult();

  T match<T>({
    required T Function(V value) value,
    required T Function(Failure failure) failure,
  }) {
    if (_hasValue) {
      return value(this.value!);
    } else if (_hasFailure) {
      return failure(this.failure!);
    }
    throw FallThroughError();
  }
}

extension ObjectAsResultExtension<T extends Object> on T {
  Result<T> asResult() => Result<T>.value(this);
}

extension ResultListExtension<V extends Object> on Iterable<Result<V>> {
  Result<List<R>> bindAll<R extends Object>(
      ResultContinuation<R, V> converter) {
    final results = <R>[];
    for (final result in this) {
      if (result._hasFailure) return result._cast<List<R>>();
      final convertedResult = converter(result.value!);
      if (convertedResult._hasFailure) return convertedResult._cast<List<R>>();
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
      if (result._hasFailure) return result._cast<R>();
      output = reducer(output, result.value!);
    }
    return output.asResult();
  }
}

extension ListResultExtension<V extends Object> on Result<Iterable<V>> {
  Result<List<R>> bindAll<R extends Object>(
      ResultContinuation<R, V> converter) {
    if (_hasFailure) return _cast<List<R>>();
    final results = <R>[];
    for (final result in value!) {
      final convertedResult = converter(result);
      if (convertedResult._hasFailure) return convertedResult._cast<List<R>>();
      results.add(convertedResult.value!);
    }
    return results.asResult();
  }

  Result<Iterable<R>> mapAll<R extends Object>(R Function(V value) mapper) {
    if (_hasFailure) return _cast<List<R>>();
    return value!.map(mapper).asResult();
  }

  Result<R> reduce<R extends Object>(
    ResultReducer<R, V> reducer,
    R initialValue,
  ) {
    if (_hasFailure) return _cast<R>();
    var output = initialValue;
    for (final result in value!) {
      output = reducer(output, result);
    }
    return output.asResult();
  }
}
