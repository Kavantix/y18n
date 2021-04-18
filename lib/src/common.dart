import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import 'result.dart';

extension ObjectContinuation<I extends Object> on I {
  R map<R>(R Function(I) func) => func(this);
}

extension Function2ApplyExtension<T, P1, P2> on T Function(P1, P2) {
  T Function(P2) apply(P1 p1) => (p2) => this(p1, p2);
}

String firstLetterUpperCased(String input) =>
    input.substring(0, 1).toUpperCase() + input.substring(1);

final _camelCaseRegex = RegExp(r' (.)');
String camelCasedName(String name) =>
    name.replaceAllMapped(_camelCaseRegex, (m) => m.group(1)!.toUpperCase());

@immutable
class FileContent {
  FileContent({
    required this.path,
    required this.content,
  });
  final String path;
  final String content;
}

Result<FileContent> retrieveInputFileContent(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return Result.fileNotFound(path);
  } else {
    final content = file.readAsStringSync();
    return FileContent(path: path, content: content).asResult();
  }
}

extension StreamDebounce<T> on Stream<T> {
  Stream<T> debounced(Duration debounceTime) async* {
    final controller = StreamController<T>();
    Timer? debounceTimer;
    listen(
      (data) {
        debounceTimer?.cancel();
        debounceTimer = Timer(debounceTime, () => controller.add(data));
      },
      onError: (error) => controller.addError(error),
      onDone: () => controller.close(),
    );

    yield* controller.stream;
  }
}
