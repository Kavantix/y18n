package tree

import (
	"io"
	"slices"

	"gopkg.in/yaml.v3"
)

type RootNode = *Node

func ParseYaml(reader io.Reader) (RootNode, error) {
	yamlNode := &yaml.Node{}
	decoder := yaml.NewDecoder(reader)
	err := decoder.Decode(yamlNode)
	if err != nil {
		return nil, err
	}
	root := &Node{}
	parseYamlNode(yamlNode, root, 0)
	return root, nil
}

func parseYamlNode(yamlNode *yaml.Node, node *Node, depth int) {
	switch yamlNode.Kind {
	case yaml.DocumentNode:
		for _, child := range yamlNode.Content {
			parseYamlNode(child, node, depth)
		}
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
			} else {
				childNode := Node{
					Name:        key.Value,
					Description: key.HeadComment,
					ParentNames: parentNames,
				}
				parseYamlNode(value, &childNode, depth+1)
				if slices.ContainsFunc(childNode.Children, func(child NodeChild) bool {
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
			}
		}
	}
}
