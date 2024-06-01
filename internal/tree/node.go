package tree

import "strings"

type Node struct {
	PublicName  string
	ParentNames []string
	Name        string
	Description string
	Children    []nodeChild
}

func (*Node) nodeChild() {}

func (n *Node) String() string {
	builder := strings.Builder{}
	n.appendStringAtDepth(&builder, 0)
	return builder.String()
}

func (n *Node) appendStringAtDepth(builder *strings.Builder, depth int) {
	if depth == 0 && n.Name == "" {
		for _, child := range n.Children {
			child.appendStringAtDepth(builder, 0)
		}
	} else {
		builder.WriteString(strings.Repeat("  ", depth))
		if n.PublicName != "" {
			builder.WriteString(n.PublicName)
		} else {
			if len(n.ParentNames) > 0 {
				builder.WriteString(strings.Join(n.ParentNames, "."))
				builder.WriteRune('.')
				builder.WriteString(n.Name)
			} else {
				builder.WriteString(n.Name)
			}
		}
		if n.Description != "" {
			builder.WriteString(" `")
			builder.WriteString(n.Description)
			builder.WriteRune('`')
		}
		builder.WriteRune(':')
		builder.WriteRune('\n')
		for _, child := range n.Children {
			child.appendStringAtDepth(builder, depth+1)
		}
	}
}
