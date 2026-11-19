---
name: notcurses-man
description: Look up the notcurses C API in the installed man pages and headers before writing, reviewing or debugging code that touches it. Use this skill whenever the task involves a notcurses C function, struct, flag or constant — adding or checking `attach_function` signatures, structs, enums or constants in `lib/notcurses/ffi/`, reimplementing a `static inline` function in `inline_reimpl.rb`, deciding what a wrapper in `lib/notcurses/` should return or raise, ownership and lifetime of returned pointers, or a question like "what does ncplane_putstr_yx return on error?" — even if the user does not mention man pages. Do not use it for Ruby, gems or Ruby tooling (that is the context7-mcp skill).
---

# notcurses man pages

`Notcurses::FFI` maps the C API 1:1 and has no YARD documentation: the project
delegates its semantics to the notcurses man pages (README, `memory/fase4-design.md`).
So read the C documentation instead of answering from memory — notcurses has many
near-identical functions (`_yx`, `_aligned`, `_stained` variants) and details like
error returns or who frees a pointer are easy to misremember.

## Look up a symbol

Run the bundled script from the repository root (the same path works in worktrees):

```sh
.claude/skills/notcurses-man/scripts/ncman.sh ncplane_putstr_yx
```

It accepts any C identifier: function, struct, typedef, flag or macro. Output:

1. a version line for the installed man pages and headers (they must match);
2. **MAN PAGES**: for each `notcurses*(3)` page that mentions the symbol, its
   SYNOPSIS line, the paragraphs that name it (or its base form, e.g.
   `ncplane_putstr()` for `ncplane_putstr_yx`), and the generic RETURN VALUES rules;
3. **HEADERS**: the comment and definition in `/usr/include/notcurses/*.h`,
   including the full body of `static inline` functions and struct fields.

Other modes:

```sh
.claude/skills/notcurses-man/scripts/ncman.sh --search 'scroll(ing)?'   # concept search, all pages
.claude/skills/notcurses-man/scripts/ncman.sh --page plane              # whole notcurses_plane(3)
.claude/skills/notcurses-man/scripts/ncman.sh --list                    # pages and descriptions
```

Use `--page` when the excerpt is not enough: some paragraphs describe a whole
family ("`ncplane_putc_yx()`, etc.") without naming every member.

## Reconcile man page and header

The man pages and the headers sometimes disagree. Both come from the same
release (3.0.17), so the disagreement is in notcurses itself, not a version skew.
Decide by what the question is about:

- **Linkage and signature → header.** A function defined `static inline` in the
  header is not exported by `libnotcurses`, so `attach_function` cannot bind it,
  even when the man page SYNOPSIS shows a plain prototype. Example:
  `notcurses_output(3)` lists `int ncplane_putstr_yx(...)`, but `notcurses.h`
  defines it `static inline`. Reimplement such functions in Ruby
  (`lib/notcurses/ffi/inline_reimpl.rb`) following the header body. Take
  parameter and return types from the header too.
- **Behavior → the code that runs.** For `static inline` code the header body is
  the implementation. For exported functions, check the source in the
  `notcurses/` submodule (`notcurses/src/lib/`) if the texts conflict. Example:
  for `ncplane_putstr_yx` the man page says a negative return is an input error,
  while the header body returns `-ret`, the negated count of columns written
  before the failure (so `0` can also mean an error after zero columns).
- **Intent and guarantees → man page.** Thread safety, ownership ("heap-allocated
  copy, the caller must free it"), and when a call is valid are usually described
  only in the man page.

When they conflict, say so in your answer and name both sources. A silent pick
hides a trap for the next reader.

## Symbols without a man page

About 20 notcurses functions bound in `lib/notcurses/ffi/functions.rb` appear in no
man page (e.g. `ncdirect_flush`, `ncblit_rgba`, `notcurses_version`). The script then prints
`no man page mentions …`; the header comment is the only documentation. State
that in the answer instead of filling the gap from memory. Symbols that are not
in the notcurses headers at all (`free`, `wcwidth`, `tcgetattr`) belong to libc:
use the libc man pages (`man 3 wcwidth`).

## Raw sources

- `notcurses/doc/man/man3/*.md`: pandoc sources of the same pages, identical to
  the installed ones at tag `v3.0.17`. Handy for Grep across pages.
- `notcurses/include/notcurses/`: same headers as `/usr/include/notcurses`, except
  `version.h`, which CMake generates.
- `notcurses/src/lib/`: implementation, for behavior the documentation leaves open.

## Citing

Cite the page as `notcurses_plane(3)` and the header as `path:line` (the script
prints both), so the user can check the claim.
