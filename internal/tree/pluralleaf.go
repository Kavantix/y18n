package tree

import "strings"

type PluralLeaf struct {
	ParentNames []string
	Name        string
	Description string
	Zero        string
	One         string
	Other       string
}

func (PluralLeaf) nodeChild() {}

func (l PluralLeaf) appendStringAtDepth(builder *strings.Builder, depth int) {
	builder.WriteString(strings.Repeat("  ", depth))
	if len(l.ParentNames) > 0 {
		builder.WriteString(strings.Join(l.ParentNames, "."))
		builder.WriteRune('.')
		builder.WriteString(l.Name)
	} else {
		builder.WriteString(l.Name)
	}
	builder.WriteString(": (")
	if l.Zero != "" {
		builder.WriteString(" 0: ")
		builder.WriteString(l.Zero)
	}
	if l.One != "" {
		builder.WriteString(" 1: ")
		builder.WriteString(l.One)
	}
	builder.WriteString(" x: ")
	builder.WriteString(l.Other)
	builder.WriteString(" )")
	if l.Description != "" {
		builder.WriteString(" `")
		builder.WriteString(l.Description)
		builder.WriteRune('`')
	}
	builder.WriteRune('\n')
}
