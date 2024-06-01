package tree

import "strings"

type Leaf struct {
	ParentNames []string
	Name        string
	Description string
	Value       string
}

func (Leaf) nodeChild() {}

func (l Leaf) appendStringAtDepth(builder *strings.Builder, depth int) {
	builder.WriteString(strings.Repeat("  ", depth))
	if len(l.ParentNames) > 0 {
		builder.WriteString(strings.Join(l.ParentNames, "."))
		builder.WriteRune('.')
		builder.WriteString(l.Name)
	} else {
		builder.WriteString(l.Name)
	}
	if l.Description != "" {
		builder.WriteString(" `")
		builder.WriteString(l.Description)
		builder.WriteRune('`')
	}
	builder.WriteString(": ")
	builder.WriteString(l.Value)
	builder.WriteRune('\n')
}
