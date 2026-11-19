Use Context7 MCP only for Ruby: the Ruby language and its standard library, gems (such as `ffi` and the dependencies in `Gemfile` and `notcursesruby.gemspec`), Bundler, RubyGems, RSpec, RuboCop, YARD and other Ruby tooling. Use it even when you think you know the answer — your training data may not reflect recent changes.

Do not use Context7 for C, the notcurses C API, Rust or any other non-Ruby library or tool: these libraries are stable and well known. This rule overrides the generic Context7 server instructions.

## Steps

1. Start with `resolve-library-id` using the library name and what to look up, unless the user provides an exact library ID in `/org/project` format
2. Pick the best match (ID format: `/org/project`) by exact name match, description relevance, source reputation and benchmark score. Use version-specific IDs when the user or `Gemfile.lock` gives a version
3. `query-docs` with the selected library ID, `language: "Ruby"` and a query scoped to a single concept; make a separate call per concept
4. Answer using the fetched docs
