import 'common.dart';
import 'tree.dart';

StringBuffer writeTreeToBuffer(Tree tree) {
  final buffer = StringBuffer();
  writeImportsToBuffer(buffer);
  tree
      .then(sortLeafChildrenFirst)
      .then((tree) => SubTree(
            name: 'Strings',
            children: _childrenWithParentNameForLeafChildren(tree.children,
                parentName: 'Strings'),
            parentNames: [],
          ))
      .then(_writeNodeToBuffer.apply(buffer));
  return buffer;
}

List<Node> _childrenWithParentNameForLeafChildren(List<Node> children,
    {required String parentName}) {
  final parentNames = List.filled(1, parentName);
  return children.map((child) {
    switch (child.type) {
      case NodeTypes.subtree:
        return child;
      case NodeTypes.valueLeaf:
        final leaf = child as ValueLeaf;
        return ValueLeaf(
          name: leaf.name,
          value: leaf.value,
          parentNames: parentNames,
          arguments: leaf.arguments,
        );
      case NodeTypes.pluralLeaf:
        final leaf = child as PluralLeaf;
        return PluralLeaf(
          name: leaf.name,
          other: leaf.other,
          zero: leaf.zero,
          one: leaf.one,
          two: leaf.two,
          few: leaf.few,
          many: leaf.many,
          parentNames: parentNames,
          arguments: leaf.arguments,
        );
    }
  }).toList();
}

void writeImportsToBuffer(StringBuffer buffer) {
  buffer.writeln("import 'package:flutter/widgets.dart';");
  buffer.writeln("import 'package:intl/intl.dart';");
}

void _writeNodeToBuffer(StringBuffer buffer, Node node) {
  switch (node.type) {
    case NodeTypes.subtree:
      final subTree = node as SubTree;
      final type = _uniqueTypeNameforNode(subTree);
      buffer.writeln();
      buffer.writeln('class $type {');
      buffer.writeln('  const $type();');
      if (node.isRoot) {
        _writeInheritedWidgetStaticMethodToBuffer(buffer);
      }
      subTree.children //
          .where(nodeIsALeaf)
          .map(nodeAsLeaf)
          .forEach(_writeLeafToBuffer.apply(buffer));
      buffer.writeln();
      subTree.children //
          .where(nodeIsASubtree)
          .map(nodeAsSubtree)
          .forEach(_writeSubtreeGetterToBuffer.apply(buffer));
      buffer.writeln('}');
      subTree.children //
          .where(nodeIsASubtree)
          .forEach(_writeNodeToBuffer.apply(buffer));
      break;
    case NodeTypes.valueLeaf:
    case NodeTypes.pluralLeaf:
      _writeLeafToBuffer(buffer, node as Leaf);
      break;
  }
}

void _writeLeafToBuffer(StringBuffer buffer, Leaf leaf) {
  switch (leaf.type) {
    case NodeTypes.subtree:
      assert(false, 'Leaf cannot be a subtree');
      break;
    case NodeTypes.valueLeaf:
      _writeValueLeafToBuffer(buffer, leaf as ValueLeaf);
      break;
    case NodeTypes.pluralLeaf:
      _writePluralLeafToBuffer(buffer, leaf as PluralLeaf);
      break;
  }
}

void _writeInheritedWidgetStaticMethodToBuffer(StringBuffer buffer) {
  buffer.writeln('''

  static Strings of(BuildContext context) {
    return Localizations.of<Strings>(context, Strings)!;
  }''');
}

final _camelCaseRegex = RegExp(r' (.)');
String camelCasedName(String name) =>
    name.replaceAllMapped(_camelCaseRegex, (m) => m.group(1)!.toUpperCase());

void _writeValueLeafToBuffer(StringBuffer buffer, ValueLeaf leaf) {
  buffer.writeln();
  buffer.writeln('  /// A translated string like:');
  final lines = leaf.value.split('\n').toList();
  for (final line in lines) {
    buffer.writeln('  /// `$line`');
  }
  final name = camelCasedName(leaf.name);
  if (leaf.arguments.isEmpty) {
    buffer.writeln('  String get $name => Intl.message(');
  } else {
    _writeArgumentsToBuffer(buffer, leaf);
    buffer.writeln('      Intl.message(');
  }
  _writeLeafLinesToBuffer(buffer, lines);
  final uniqueName =
      _uniqueLeafNameforNode(leaf, isPrivate: leaf.arguments.isNotEmpty);
  buffer.writeln("        name: '$uniqueName',");
  if (leaf.arguments.isNotEmpty) {
    buffer.writeln('        args: [');
    for (final argument in leaf.arguments) {
      buffer.writeln('          $argument,');
    }
    buffer.writeln('        ],');
  }
  buffer.writeln('      );');
}

void _writePluralLeafToBuffer(StringBuffer buffer, PluralLeaf leaf) {
  buffer.writeln();
  buffer.writeln('  /// A translated plural string like:');
  final lines = leaf.other.split('\n').toList();
  for (final line in lines) {
    buffer.writeln('  /// `$line`');
  }
  _writeArgumentsToBuffer(buffer, leaf, firstArgumentType: 'num');
  buffer.writeln('      Intl.plural(');
  buffer.writeln('        ${leaf.arguments.first},');
  final params = {
    'other': leaf.other,
    'zero': leaf.zero,
    'one': leaf.one,
    'two': leaf.two,
    'few': leaf.few,
    'many': leaf.many,
  };
  for (final param in params.entries) {
    if (param.value == null) continue;
    final lines = param.value!.split('\n').toList();
    _writeLeafLinesToBuffer(buffer, lines, key: param.key);
  }
  final uniqueName = _uniqueLeafNameforNode(leaf, isPrivate: true);
  buffer.writeln("        name: '$uniqueName',");
  if (leaf.arguments.isNotEmpty) {
    buffer.writeln('        args: [');
    for (final argument in leaf.arguments) {
      buffer.writeln('          $argument,');
    }
    buffer.writeln('        ],');
  }
  buffer.writeln('      );');
}

void _writeArgumentsToBuffer(
  StringBuffer buffer,
  Leaf leaf, {
  String firstArgumentType = 'String',
}) {
  final name = camelCasedName(leaf.name);
  buffer.writeln('  String $name({');
  buffer.writeln('    required $firstArgumentType ${leaf.arguments.first},');
  for (final argument in leaf.arguments.skip(1)) {
    buffer.writeln('    required String $argument,');
  }
  buffer.writeln('  }) =>');
  buffer.writeln('      _$name(');
  for (final argument in leaf.arguments) {
    buffer.writeln('        $argument,');
  }
  buffer.writeln('      );');
  buffer.writeln();
  buffer.writeln('  String _$name(');
  buffer.writeln('    $firstArgumentType ${leaf.arguments.first},');
  for (final argument in leaf.arguments.skip(1)) {
    buffer.writeln('    String $argument,');
  }
  buffer.writeln('  ) =>');
}

void _writeLeafLinesToBuffer(StringBuffer buffer, List<String> lines,
    {String? key}) {
  if (lines.length > 1) {
    if (key != null) {
      buffer.writeln("        $key: '''");
    } else {
      buffer.writeln("        '''");
    }
    for (final line in lines.take(lines.length - 1)) {
      buffer.writeln(line);
    }
    buffer.write(lines.last);
    buffer.writeln("''',");
  } else {
    if (key != null) {
      buffer.write("        $key: '");
    } else {
      buffer.write("        '");
    }
    buffer.write(lines.first);
    buffer.writeln("',");
  }
}

void _writeSubtreeGetterToBuffer(StringBuffer buffer, SubTree subTree) {
  final type = _uniqueTypeNameforNode(subTree);
  buffer
      .writeln('  $type get ${camelCasedName(subTree.name)} => const $type();');
}

String _uniqueLeafNameforNode(Node node, {required bool isPrivate}) {
  final buffer = StringBuffer(node.isRoot ? '' : '_');
  for (final name in node.parentNames) {
    name //
        .then(camelCasedName)
        .then(firstLetterUpperCased)
        .then(buffer.write);
  }
  if (isPrivate) buffer.write('_');
  buffer.write('_${camelCasedName(node.name)}');
  return buffer.toString();
}

String _uniqueTypeNameforNode(Node node) {
  final buffer = StringBuffer(node.isRoot ? '' : '_');
  for (final name in node.parentNames.followedBy([node.name])) {
    name //
        .then(camelCasedName)
        .then(firstLetterUpperCased)
        .then(buffer.write);
  }
  return buffer.toString();
}
