package dnode

import (
	"fmt"
	"reflect"
	"strconv"
	"strings"
)

type Callback func(args ...interface{})

// UnmarshalJSON marshals the callback as "nil".
// Value of the callback is not important in dnode protocol.
func (p *Callback) UnmarshalJSON(data []byte) error {
	return nil
}

type CallbackSpec struct {
	// Path represents the callback's path in the arguments structure.
	Path     []string
	Callback Callback
}

func (c *CallbackSpec) Apply(value reflect.Value) error {
	i := 0
	for {
		switch value.Kind() {
		case reflect.Slice:
			if i == len(c.Path) {
				return fmt.Errorf("Callback path too short: %v", c.Path)
			}
			index, err := strconv.Atoi(c.Path[i])
			if err != nil {
				return fmt.Errorf("Integer expected in callback path, got '%v'.", c.Path[i])
			}
			value = value.Index(index)
			i++
		case reflect.Map:
			if i == len(c.Path) {
				return fmt.Errorf("Callback path too short: %v", c.Path)
			}
			if i == len(c.Path)-1 && value.Type().Elem().Kind() == reflect.Interface {
				value.SetMapIndex(reflect.ValueOf(c.Path[i]), reflect.ValueOf(c.Callback))
				return nil
			}
			value = value.MapIndex(reflect.ValueOf(c.Path[i]))
			i++
		case reflect.Ptr:
			value = value.Elem()
		case reflect.Interface:
			if i == len(c.Path) {
				value.Set(reflect.ValueOf(c.Callback))
				return nil
			}
			value = value.Elem()
		case reflect.Struct:
			if innerPartial, ok := value.Addr().Interface().(*Partial); ok {
				innerPartial.Callbacks = append(innerPartial.Callbacks, CallbackSpec{c.Path[i:], c.Callback})
				return nil
			}
			name := c.Path[i]
			value = value.FieldByName(strings.ToUpper(name[0:1]) + name[1:])
			i++
		case reflect.Func:
			value.Set(reflect.ValueOf(c.Callback))
			return nil
		case reflect.Invalid:
			// callback path does not exist, skip
			return nil
		default:
			return fmt.Errorf("Unhandled value of kind '%v' in callback path.", value.Kind())
		}
	}
	return nil
}
