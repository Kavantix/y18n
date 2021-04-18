import 'dart:async';
import 'dart:io';

import 'common.dart';
import 'tree.dart';

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
  return file;
}

void outputBufferToStdOut(StringBuffer buffer) {
  print(buffer.toString());
}

Tree fixNames(Tree tree) {
  return Tree(
    tree.children.map(_fixNodeNames.apply('')).toList(),
  );
}

Node _fixNodeNames(String parentName, Node node) {
  switch (node.type) {
    case NodeTypes.subtree:
      final subTree = node as SubTree;
      final String name;
      final String publicName;
      final String childTreeParentName;
      final String childLeafParentName;
      if (subTree.publicName != null) {
        name = camelCasedName(subTree.publicName!);
        publicName = firstLetterUpperCased(name) + 'Strings';
        childTreeParentName = '_' + firstLetterUpperCased(name);
        childLeafParentName = publicName;
      } else {
        name = camelCasedName(subTree.name);
        publicName = parentName + '_' + firstLetterUpperCased(name);
        childTreeParentName = publicName;
        childLeafParentName = publicName;
      }
      return SubTree(
        name: name,
        children: subTree.children.map((child) {
          switch (child.type) {
            case NodeTypes.subtree:
              return _fixNodeNames(childTreeParentName, child);
            case NodeTypes.valueLeaf:
            case NodeTypes.pluralLeaf:
              return _fixNodeNames(childLeafParentName, child);
          }
        }).toList(),
        publicName: publicName,
        parentNames: [publicName],
      );
    case NodeTypes.valueLeaf:
      final leaf = node as ValueLeaf;
      return ValueLeaf(
        name: camelCasedName(leaf.name),
        value: leaf.value,
        arguments: leaf.arguments,
        parentNames: [parentName],
      );
    case NodeTypes.pluralLeaf:
      final leaf = node as PluralLeaf;
      return PluralLeaf(
        name: camelCasedName(leaf.name),
        other: leaf.other,
        zero: leaf.zero,
        one: leaf.one,
        two: leaf.two,
        few: leaf.few,
        many: leaf.many,
        arguments: leaf.arguments,
        parentNames: [parentName],
      );
  }
}

Stream<List<String>> watchPaths(List<String> paths) async* {
  final controller = StreamController<List<String>>();
  final files = paths.map((p) => File(p));
  void onUpdate(File file, FileSystemEvent event) {
    if (event.type == FileSystemEvent.delete) {
      file.watch().listen((event) => onUpdate(file, event));
    } else if (event.type == FileSystemEvent.modify) {
      controller.add(paths);
    }
  }

  for (final file in files) {
    file.watch().listen((event) => onUpdate(file, event));
  }
  yield paths;
  yield* controller.stream.debounced(const Duration(milliseconds: 10));
}
