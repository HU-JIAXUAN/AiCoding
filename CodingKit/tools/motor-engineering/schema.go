package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"reflect"
	"strings"
)

func rejectDuplicateKeys(data []byte) error {
	d := json.NewDecoder(bytes.NewReader(data))
	var value func(int) error
	value = func(depth int) error {
		if depth > 128 {
			return fmt.Errorf("JSON nesting exceeds 128")
		}
		tok, err := d.Token()
		if err != nil {
			return err
		}
		switch tok {
		case json.Delim('{'):
			seen := map[string]bool{}
			for d.More() {
				key, err := d.Token()
				if err != nil {
					return err
				}
				name, ok := key.(string)
				if !ok {
					return fmt.Errorf("object key must be a string")
				}
				if seen[name] {
					return fmt.Errorf("duplicate JSON key %q", name)
				}
				seen[name] = true
				if err = value(depth + 1); err != nil {
					return err
				}
			}
			_, err = d.Token()
			return err
		case json.Delim('['):
			for d.More() {
				if err = value(depth + 1); err != nil {
					return err
				}
			}
			_, err = d.Token()
			return err
		}
		return nil
	}
	return value(0)
}

// Schemas are generated from the same Go types decoded by the CLI, preventing
// a separately maintained field catalog. Numeric/method constraints are checked
// by analyze; null required bounds represent unavailable evidence explicitly.
func schemaFor(t reflect.Type) map[string]any {
	if t.Kind() == reflect.Pointer {
		return map[string]any{"anyOf": []any{schemaFor(t.Elem()), map[string]any{"type": "null"}}}
	}
	s := map[string]any{}
	switch t.Kind() {
	case reflect.Struct:
		properties := map[string]any{}
		required := []string{}
		for n := 0; n < t.NumField(); n++ {
			f := t.Field(n)
			tag := strings.Split(f.Tag.Get("json"), ",")
			if tag[0] == "-" || tag[0] == "" {
				continue
			}
			properties[tag[0]] = schemaFor(f.Type)
			if len(tag) == 1 || tag[1] != "omitempty" {
				required = append(required, tag[0])
			}
		}
		s = map[string]any{"type": "object", "properties": properties, "required": required, "additionalProperties": false}
	case reflect.Slice:
		s = map[string]any{"type": "array", "items": schemaFor(t.Elem())}
	case reflect.Map:
		s = map[string]any{"type": "object", "additionalProperties": schemaFor(t.Elem())}
	case reflect.String:
		s["type"] = "string"
	case reflect.Bool:
		s["type"] = "boolean"
	case reflect.Int, reflect.Int64:
		s["type"] = "integer"
	case reflect.Float64:
		s["type"] = "number"
	}
	return s
}

func requiredFields(value any, t reflect.Type, path string) error {
	if t.Kind() == reflect.Pointer {
		if value == nil {
			return nil
		}
		return requiredFields(value, t.Elem(), path)
	}
	if t.Kind() != reflect.Struct {
		return nil
	}
	object, ok := value.(map[string]any)
	if !ok {
		return fmt.Errorf("%s must be an object", path)
	}
	for n := 0; n < t.NumField(); n++ {
		f := t.Field(n)
		tag := strings.Split(f.Tag.Get("json"), ",")
		name := tag[0]
		v, exists := object[name]
		optional := len(tag) > 1 && tag[1] == "omitempty"
		if !exists {
			if optional {
				continue
			}
			return fmt.Errorf("missing required field %s.%s; use null only for unknown nullable bounds", path, name)
		}
		if v == nil && f.Type.Kind() != reflect.Pointer {
			return fmt.Errorf("%s.%s cannot be null", path, name)
		}
		if err := requiredFields(v, f.Type, path+"."+name); err != nil {
			return err
		}
	}
	return nil
}
