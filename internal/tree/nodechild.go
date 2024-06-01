package tree

import "strings"

type nodeChild interface {
	nodeChild()
	appendStringAtDepth(builder *strings.Builder, depth int)
}

var _ nodeChild = &Node{}
var _ nodeChild = Leaf{}
var _ nodeChild = PluralLeaf{}
