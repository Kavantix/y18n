package main

import (
	"flag"
	"fmt"
	"os"
	"slices"
	"strings"

	"github.com/rsc/getopt"
	"gopkg.in/yaml.v3"
)

var (
	help = flag.Bool("help", false, "Shows this help message.")
	path = flag.String("file", "", `(required) The path to the strings file e.g. './strings.yaml'`)
)

func eprintln(line string) {
	fmt.Fprintln(os.Stderr, line)
}

func eprintf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format, args...)
}

func failWithUsage() {
	flag.Usage()
	os.Exit(1)
}

func setupArgs() {
	getopt.Alias("h", "help")
	getopt.Alias("f", "file")
	getopt.Parse()

	if *help {
		failWithUsage()
	}
}

func main() {
	setupArgs()

	if *path == "" {
		eprintln("ERROR: file is required")
		failWithUsage()
	}

	file, err := os.Open(*path)
	if err != nil {
		eprintf("ERROR: failed to open file '%s': %s", *path, err)
		os.Exit(1)
	}

	content := &yaml.Node{}
	decoder := yaml.NewDecoder(file)
	err = decoder.Decode(content)
	if err != nil {
		eprintf("ERROR: failed to parse file '%s': %s", *path, err)
		os.Exit(1)
	}
	root := &Node{}
	parseYamlNode(content, root, 0)
	fmt.Printf("%+v", root)
}

type nodeChild interface {
	nodeChild()
	appendStringAtDepth(builder *strings.Builder, depth int)
}

var _ nodeChild = &Node{}
var _ nodeChild = Leaf{}
var _ nodeChild = PluralLeaf{}

type Node struct {
	PublicName  string
	ParentNames []string
	Name        string
	Description string
	Children    []nodeChild
}

func (*Node) nodeChild() {}

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

func parseYamlNode(yamlNode *yaml.Node, node *Node, depth int) {
	switch yamlNode.Kind {
	case yaml.DocumentNode:
		for _, child := range yamlNode.Content {
			parseYamlNode(child, node, depth)
		}
	case yaml.ScalarNode:
		// fmt.Printf("%s%s `%s`\n", strings.Repeat("  ", depth), yamlNode.Value, yamlNode.LineComment)
	case yaml.MappingNode:
		for i := range len(yamlNode.Content) / 2 {
			key := yamlNode.Content[i*2]
			value := yamlNode.Content[i*2+1]
			parentNames := slices.Clone(node.ParentNames)
			if depth > 0 {
				parentNames = append(parentNames, node.Name)
			}
			if value.Kind == yaml.ScalarNode {
				node.Children = append(node.Children, Leaf{
					Name:        key.Value,
					Value:       value.Value,
					Description: key.HeadComment,
					ParentNames: parentNames,
				})
				// fmt.Printf("%s%s: `%s` %s `%s`\n", strings.Repeat("  ", depth), key.Value, key.HeadComment, value.Value, value.LineComment)
				// fmt.Printf("%s%+v`\n", strings.Repeat("  ", depth), leaf)
			} else {
				// fmt.Printf("%s%s: `%s` {\n", strings.Repeat("  ", depth), key.Value, key.HeadComment)
				childNode := Node{
					Name:        key.Value,
					Description: key.HeadComment,
					ParentNames: parentNames,
				}
				parseYamlNode(value, &childNode, depth+1)
				if slices.ContainsFunc(childNode.Children, func(child nodeChild) bool {
					leaf, isLeaf := child.(Leaf)
					return isLeaf && leaf.Name == "$plural"
				}) {
					leafs := map[string]string{}
					for _, child := range childNode.Children {
						leaf, isLeaf := child.(Leaf)
						if isLeaf {
							leafs[leaf.Name] = leaf.Value
						}
					}
					node.Children = append(node.Children, PluralLeaf{
						Name:        key.Value,
						Description: key.HeadComment,
						ParentNames: parentNames,
						Zero:        leafs["$zero"],
						One:         leafs["$one"],
						Other:       leafs["$plural"],
					})
				} else {
					node.Children = append(node.Children, &childNode)
					for i, child := range childNode.Children {
						leaf, isLeaf := child.(Leaf)
						if isLeaf && leaf.Name == "$name" {
							childNode.PublicName = leaf.Value
							childNode.Children = slices.Delete(childNode.Children, i, i+1)
							break
						}
					}
				}
				// fmt.Printf("%s} [%s]\n", strings.Repeat("  ", depth), key.Value)
			}
		}
	}
}

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
