var foo: String {
  let name = "white"
  return name
}

// RUN: %empty-directory(%t.result)
// RUN: mkdir -p %t.result
// RUN: %refactor -find-local-rename-ranges -source-filename %s -pos=2:7 > %t.result/computed_property.swift
// RUN: diff -u %S/Outputs/property/computed_property.swift.expected %t.result/computed_property.swift
