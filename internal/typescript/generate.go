package typescript

import (
	"bufio"
	"io"
	"strings"

	"github.com/Kavantix/y18n/internal/tree"
)

type Encoder struct {
	writer *bufio.Writer
}

func NewEncoder(writer io.Writer) *Encoder {
	return &Encoder{
		writer: bufio.NewWriter(writer),
	}
}

func (e *Encoder) Encode(root tree.RootNode) error {
	_, err := e.writer.WriteString(`
// THIS FILE IS GENERATED
// DO NOT EDIT!!

import { useI18n } from "vue-i18n"
const { t } = useI18n()

`)
	if err != nil {
		return err
	}
	_, err = e.writer.WriteString("export const strings = {\n")
	if err != nil {
		return err
	}

	for _, child := range root.Children {
		e.encodeChild(child, 0)
	}

	_, err = e.writer.WriteString("}\n")
	if err != nil {
		return err
	}

	return e.writer.Flush()
}

func (e *Encoder) encodeChild(child tree.NodeChild, depth int) error {
	if node, childIsNode := child.(*tree.Node); childIsNode {
		buffer := strings.Builder{}
		buffer.WriteString(strings.Repeat("  ", depth+1))
		buffer.WriteRune('"')
		buffer.WriteString(node.Name)
		buffer.WriteString("\": {\n")
		_, err := e.writer.WriteString(buffer.String())
		if err != nil {
			return err
		}
		buffer.Reset()
		for _, child := range node.Children {
			e.encodeChild(child, depth+1)
		}
		buffer.WriteString(strings.Repeat("  ", depth+1))
		buffer.WriteString("}\n")
		_, err = e.writer.WriteString(buffer.String())
		if err != nil {
			return err
		}
	}
	if leaf, childIsLeaf := child.(tree.Leaf); childIsLeaf {
		buffer := strings.Builder{}
		buffer.WriteString(strings.Repeat("  ", depth+1))
		buffer.WriteRune('"')
		buffer.WriteString(leaf.Name)
		buffer.WriteString("\": () => t(\"")
		buffer.WriteString(strings.Join(leaf.ParentNames, "."))
		buffer.WriteString("\", \"")
		buffer.WriteString(strings.ReplaceAll(leaf.Value, "\"", "\\\""))
		buffer.WriteString("\"),\n")
		_, err := e.writer.WriteString(buffer.String())
		if err != nil {
			return err
		}
	}

	return nil
}
