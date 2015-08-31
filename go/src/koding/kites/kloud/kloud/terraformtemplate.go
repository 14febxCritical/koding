package kloud

import (
	"encoding/json"
	"fmt"
	"reflect"
	"strings"

	"github.com/fatih/structs"
	hclmain "github.com/hashicorp/hcl"
	"github.com/hashicorp/hcl/hcl"
	hcljson "github.com/hashicorp/hcl/json"
	"github.com/hashicorp/terraform/config"
	"github.com/hashicorp/terraform/config/lang"
)

type terraformTemplate struct {
	Resource map[string]interface{} `json:"resource,omitempty"`
	Provider map[string]interface{} `json:"provider,omitempty"`
	Variable map[string]interface{} `json:"variable,omitempty"`
	Output   map[string]interface{} `json:"output,omitempty"`

	h *hcl.Object `json:"-"`
}

// newTerraformTemplate parses the content and returns a terraformTemplate
// instance
func newTerraformTemplate(content string) (*terraformTemplate, error) {
	var template *terraformTemplate
	err := json.Unmarshal([]byte(content), &template)
	if err != nil {
		return nil, err
	}

	if err := template.hclParse(content); err != nil {
		return nil, err
	}

	return template, nil
}

// hclParse parses the given JSON input and updates the internal hcl object
// representation
func (t *terraformTemplate) hclParse(jsonIn string) error {
	var err error
	t.h, err = hcljson.Parse(jsonIn)
	return err
}

// hclUpdate update the internal hcl object
func (t *terraformTemplate) hclUpdate() error {
	out, err := t.jsonOutput()
	if err != nil {
		return err
	}

	return t.hclParse(out)
}

// detectUserVariables parses the template for any ${var.foo}, ${var.bar},
// etc.. user variables. It returns a list of found variables with, example:
// []string{"foo", "bar"}. The returned list only contains unique names, so any
// user variable which declared multiple times is neglected, only the last
// occurence is being added.
func (t *terraformTemplate) detectUserVariables() ([]string, error) {
	out, err := t.jsonOutput()
	if err != nil {
		return nil, err
	}

	// get AST first, is capable of parsing json
	a, err := lang.Parse(out)
	if err != nil {
		return nil, err
	}

	// read the variables from the given AST. This is basically just iterating
	// over the AST node and does the heavy lifting for us
	vars, err := config.DetectVariables(a)
	if err != nil {
		return nil, err
	}

	// filter out duplicates
	set := make(map[string]bool, 0)
	for _, v := range vars {
		// be sure we only get userVariables, as there is many ways of
		// declaring variables
		u, ok := v.(*config.UserVariable)
		if !ok {
			continue
		}

		if !set[u.Name] {
			set[u.Name] = true
		}
	}

	userVars := []string{}
	for u := range set {
		userVars = append(userVars, u)
	}

	return userVars, nil
}

// DecodeProvider decodes the provider block to the given out struct
func (t *terraformTemplate) DecodeProvider(out interface{}) error {
	return t.decode("provider", out)
}

// DecodeResource decodes the resource block to the given out struct
func (t *terraformTemplate) DecodeResource(out interface{}) error {
	return t.decode("resource", out)
}

// DecodeVariable decodes the resource block to the given out struct
func (t *terraformTemplate) DecodeVariable(out interface{}) error {
	return t.decode("variable", out)
}

func (t *terraformTemplate) decode(resource string, out interface{}) error {
	obj := t.h.Get(resource, true)
	return hclmain.DecodeObject(out, obj)
}

func (t *terraformTemplate) String() string {
	out, err := t.jsonOutput()
	if err != nil {
		return "<ERROR>"
	}

	return out
}

// jsonOutput returns a JSON formatted output of the template
func (t *terraformTemplate) jsonOutput() (string, error) {
	out, err := json.MarshalIndent(t, "", "  ")
	if err != nil {
		return "", err
	}

	return string(out), nil
}

func (t *terraformTemplate) injectCustomVariables(prefix string, data map[string]string) error {
	for key, val := range data {
		varName := fmt.Sprintf("%s_%s", prefix, key)
		t.Variable[varName] = map[string]interface{}{
			"default": val,
		}
	}

	return t.hclUpdate()
}

func (t *terraformTemplate) injectKodingVariables(data *kodingData) error {
	var properties = []struct {
		collection string
		fieldToAdd map[string]bool
	}{
		{"User",
			map[string]bool{
				"username": true,
				"email":    true,
			},
		},
		{"Account",
			map[string]bool{
				"profile": true,
			},
		},
		{"Group",
			map[string]bool{
				"title": true,
				"slug":  true,
			},
		},
	}

	for _, p := range properties {
		model, ok := structs.New(data).FieldOk(p.collection)
		if !ok {
			continue
		}

		for _, field := range model.Fields() {
			fieldName := strings.ToLower(field.Name())
			// check if the user set a field tag
			if field.Tag("bson") != "" {
				fieldName = field.Tag("bson")
			}

			exists := p.fieldToAdd[fieldName]

			// we need to declare to call it recursively
			var addVariable func(*structs.Field, string, bool)

			addVariable = func(field *structs.Field, varName string, allow bool) {
				if !allow {
					return
				}

				// nested structs, call again
				if field.Kind() == reflect.Struct {
					for _, f := range field.Fields() {
						fieldName := strings.ToLower(f.Name())
						// check if the user set a field tag
						if f.Tag("bson") != "" {
							fieldName = f.Tag("bson")
						}

						newName := varName + "_" + fieldName
						addVariable(f, newName, true)
					}
					return
				}

				t.Variable[varName] = map[string]interface{}{
					"default": field.Value(),
				}
			}

			varName := "koding_" + strings.ToLower(p.collection) + "_" + fieldName
			addVariable(field, varName, exists)
		}
	}

	return t.hclUpdate()
}
