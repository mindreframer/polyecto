# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 98,
  import_deps: [:ecto],
  locals_without_parens: [
    polymorphic_belongs_to: 1,
    polymorphic_belongs_to: 2,
    polymorphic_has_many: 3
  ],
  export: [
    locals_without_parens: [
      polymorphic_belongs_to: 1,
      polymorphic_belongs_to: 2,
      polymorphic_has_many: 3
    ]
  ]
]
