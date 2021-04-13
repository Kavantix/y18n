import 'dart:io';

void outputBuffer(String outputOption, StringBuffer buffer) {
  switch (outputOption) {
    case 'stdout':
      return outputBufferToStdOut(buffer);
    default:
      final file = fileForOutputOption(outputOption);
      return outputBufferToFile(file, buffer);
  }
}

void outputBufferToFile(File file, StringBuffer buffer) {
  file.writeAsStringSync(buffer.toString());
}

File fileForOutputOption(String outputOption) {
  final file = File(outputOption);
  file.createSync(recursive: true);
  // TODO: do some more checks.
  return file;
}

void outputBufferToStdOut(StringBuffer buffer) {
  print(buffer.toString());
}
