import 'package:meta/meta.dart';

enum NodeTypes {
  subtree,
  valueLeaf,
  pluralLeaf,
}

@immutable
abstract class Node {
  Node({
    required this.name,
    required this.parentNames,
  });

  final String name;
  final List<String> parentNames;
  NodeTypes get type;
}

@immutable
abstract class Leaf extends Node {
  Leaf({
    required String name,
    required List<String> parentNames,
    required this.arguments,
  }) : super(name: name, parentNames: parentNames);

  final Set<String> arguments;
}

@immutable
class Tree {
  Tree(this.children);
  final List<Node> children;
}

@immutable
class SubTree extends Node {
  SubTree({
    required String name,
    required List<String> parentNames,
    required this.children,
    required this.publicName,
  }) : super(name: name, parentNames: parentNames);

  final List<Node> children;
  final String? publicName;

  @override
  NodeTypes get type => NodeTypes.subtree;
}

@immutable
class ValueLeaf extends Leaf {
  ValueLeaf({
    required String name,
    required List<String> parentNames,
    required Set<String> arguments,
    required this.value,
  }) : super(name: name, parentNames: parentNames, arguments: arguments);

  final String value;

  @override
  NodeTypes get type => NodeTypes.valueLeaf;
}

@immutable
class PluralLeaf extends Leaf {
  PluralLeaf({
    required String name,
    required List<String> parentNames,
    required Set<String> arguments,
    required this.other,
    required this.zero,
    required this.one,
    required this.two,
    required this.few,
    required this.many,
  }) : super(name: name, parentNames: parentNames, arguments: arguments);

  final String other;
  final String? zero;
  final String? one;
  final String? two;
  final String? few;
  final String? many;

  @override
  NodeTypes get type => NodeTypes.pluralLeaf;
}

bool nodeIsALeaf(Node node) => node is Leaf;
bool nodeIsASubtree(Node node) => node.type == NodeTypes.subtree;
SubTree nodeAsSubtree(Node node) => node as SubTree;
Leaf nodeAsLeaf(Node node) => node as Leaf;

Tree sortLeafChildrenFirst(Tree tree) {
  return Tree(
    tree //
        .children
        .map(_sortLeafChildrenFirst)
        .toList(),
  );
}

Node _sortLeafChildrenFirst(Node node) {
  int compareNodes(Node lhs, Node rhs) {
    if (lhs.type == rhs.type) return 0;
    if (lhs.type == NodeTypes.valueLeaf) return -1;
    return 1;
  }

  switch (node.type) {
    case NodeTypes.subtree:
      final subtree = node as SubTree;
      subtree.children.sort(compareNodes);
      return subtree;
    case NodeTypes.valueLeaf:
    case NodeTypes.pluralLeaf:
      return node;
  }
}

Tree mergeTrees(Iterable<Tree> trees) =>
    Tree([for (final tree in trees) ...tree.children]);
