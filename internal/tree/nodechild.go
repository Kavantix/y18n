package tree

import "strings"

type NodeChild interface {
	nodeChild()
	appendStringAtDepth(builder *strings.Builder, depth int)
}

var _ NodeChild = &Node{}
var _ NodeChild = Leaf{}
var _ NodeChild = PluralLeaf{}
