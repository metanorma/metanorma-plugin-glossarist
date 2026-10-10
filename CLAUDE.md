# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Metanorma Asciidoctor plugin for Glossarist terminology datasets. It loads concept datasets (V2 and V3 Glossarist schemas), renders concepts, bibliographies, and non-verbal entities (figures/tables/formulas) into Metanorma AsciiDoc, using Liquid templates.

## Commands

- Run all specs: `bundle exec rspec` (or `bundle exec rake`)
- Run one spec file: `bundle exec rspec spec/metanorma/plugin/glossarist/mention_extractor_spec.rb`
- Run one example: append `:LINE` to the spec file path
- Lint: `bundle exec rubocop`
- Console: `bin/console`

`metanorma-standoc` is in the Gemfile `:test` group only — specs render through the `:standoc` backend, but the released gem does not depend on it. Keep any new test-only dependencies in that group; the release workflow bundles with `--without test`.

## Architecture

`lib/metanorma-plugin-glossarist.rb` is the entry point: it defines all autoloads (no `require_relative` for internal code — new classes get an autoload entry there) and `TEMPLATES_DIR`, and registers the Liquid extensions at load time (indexed-access polyfill, `WithGlossaristContext` block, custom filters).

Processing pipeline (AsciiDoc in → AsciiDoc out):

1. **`DatasetPreprocessor`** — Asciidoctor preprocessor that dispatches all directives:
   - `[glossarist,path,filter=...,template=...,context]` block with a Liquid body
   - `glossarist::import[ds]`, `glossarist::import_sections[ds]`, `glossarist::render[ds,term]`
   - `glossarist::render_bibliography[ds]`, `glossarist::render_bibliography_entry[ds,term]`
   - `glossarist::render_figures|tables|formulas[ds]`
   - `:glossarist-dataset:` document attribute pre-loads datasets globally (`name:path;name:path`)
2. **`DatasetRegistry`** — loads and caches datasets per document, `find_concept` lookup, registers sections from `register.yaml`, exposes per-context collections (concepts, sections, bibliography, non-verbal kinds).
3. **Filters** — `ConceptFilter` (collection filters: `sort_by`, `lang`, `tag`, `domain`/`group`), `FieldFilter` (`path=value`, `path.start_with(v)`), `SectionFilter`; all resolve paths via `ConceptPathResolver`, which navigates dot/bracket notation (`data.localizations['eng'].data.terms[0].designation`) through the Glossarist object graph.
4. **Renderers** — `TemplateRenderer` / `SectionRenderer` (Liquid; builds parent-child trees from broader/narrower refs, auto-detects section depth), `NonVerbalRenderer` + `NonVerbalFormatters::{Figure,Table,Formula}`, `BibliographyRenderer`, `MentionExtractor` (collects xref/cite anchors used to scope bibliographies).
5. **Liquid layer** (`Liquid` submodule) — drops (`ManagedConceptDrop`, `ManagedConceptDataDrop`, `LocalizationCollectionDrop`), custom filters (`sanitize_references`, `format_ref`), `WithGlossaristContext` block, `MultiplyLocalFileSystem` for template lookup. `Sanitize` converts URN-style refs into Metanorma-safe anchor ids.

### Glossarist gem interop

- This plugin's namespace is `Metanorma::Plugin::Glossarist`. Inside it, Ruby resolves `Glossarist::` to this namespace first — always reference gem classes with the `::Glossarist::` prefix.
- Dataset layouts: V2 (UUID-named concept/localized_concept files), V3 (identifier-based files, `register.yaml` with sections, `figures/tables/formulas/` subdirectories). Fixtures: `spec/fixtures/dataset-glossarist-v2`, `-v3`, and `invalid_dataset` for error paths. The non-verbal YAML filename stem is irrelevant; the `id:` field inside is the cross-reference target.

### Spec conventions

- Load real `Glossarist` collections from the fixtures; never use `double()`. For Asciidoctor document objects, simple `Struct`-based stand-ins are the accepted pattern.
- Preprocessor specs drive `Asciidoctor::Reader` with inline template strings; rendering specs compare against the `:standoc` backend using `canon` XML matching (configured in `spec/spec_helper.rb`).

## CI and release

- `rake.yml` calls `metanorma/ci/.github/workflows/generic-rake.yml@v1` (tests Ruby 3.3/3.4/4.0 on linux/macOS/windows).
- `release.yml` calls `metanorma/ci/.github/workflows/rubygems-release.yml@main`, gated: a `workflow_dispatch` bumps the version and pushes a tag, but publishing only happens after CI on the tag passes and dispatches `do-release` back. Publishing steps showing "skipped" in the first run is expected. Version numbers are the owner's decision — never pick or dispatch one unprompted.
