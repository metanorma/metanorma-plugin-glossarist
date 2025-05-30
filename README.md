# Metanorma::Plugin::Glossarist

Metanorma plugin that allows you to access data from the glossarist dataset inside a Metanorma document.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'metanorma-plugin-glossarist'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install metanorma-plugin-glossarist

## Usage

In order to use the macros in Metanorma, add the gem `metanorma-plugin-glossarist` in your Gemfile.

## Available Macros

Currently, there are 6 macros available for this plugin and all of them support all [Liquid syntax expressions](https://shopify.github.io/liquid/basics/introduction/), including:

- Loading Dataset
  - `:glossarist-dataset: <dataset name>:<dataset path>`
  - `[glossarist,<dataset path>, [filters], <dataset name>]`
- Rendering a single term from loaded dataset `glossarist::render[<dataset name>, <term>]`
- Rendering all terms from loaded dataset `glossarist::import[<dataset name>]`
- Rendering bibliography for a single term in the dataset `glossarist::render_bibliography_entry[<dataset name>, <term>]`
- Rendering bibliography for all terms in the dataset`glossarist::render_bibliography[<dataset name>]`

### Loading Dataset

There are 2 ways of loading a dataset
1. Global syntax `:glossarist-dataset: <dataset name>:<dataset path>`
2. Block syntax `[glossarist,<dataset path>, [filters], <dataset name>]`

### Global syntax `:glossarist-dataset: <dataset name>:<dataset path>`

This will load the glossarist data from `<dataset path>` into `<dataset name>` which can be used anywhere in the document after this line.

#### Example

Suppose we have a term named `foobar` in our dataset with the definition `The term foobar is used as metasyntactic variables and placeholder names in computer programming`

```adoc
:glossarist-dataset: dataset:./path/to/glossarist-dataset

=== Section 1
{%- for concept in dataset -%}
{{ concept.data.localizations['eng'].data.definition[0].content }}
{%- endfor -%}
```

this will output

```adoc
=== Section 1
The term foobar is used as metasyntactic variables and placeholder names in computer programming
```

### Block syntax`[glossarist,<dataset path>, [filters], <dataset name>]`

This will load the glossarist data from `<dataset path>` into `<dataset name>` which can be used in the given block. Filters are optional and can be used to filter and/or sort the loaded concepts from the glossarist dataset multiple filters can be added by separating them with a semicolon `;`. Filter can be added by adding `filter='<filters to apply>;<another filter>'`

Available filters are:
- `sort_by=<field name>`: will sort the dataset in ascending order of the given field values e.g `sort_by=term` will sort concepts in ascending order based on the default term (`data.localizations['eng'].data.terms[0].designation`).
- `<field name>=<values>`: will only load a concept if the value of the given field name is equal to the given value e.g `group=foo` will only load a concept if it has a group named `foo` or `lang=ara` will only load Arabic translations for all concepts.

#### Example

Suppose we have the following terms in our dataset

| Name | Definition | Groups |
| ----- | ----- | ----- |
| foo | The term foo is used as metasyntactic variables and placeholder names in computer programming | foo |
| bar | The term bar is used as metasyntactic variables and placeholder names in computer programming | foo, bar |
| baz | The term baz is used as metasyntactic variables and placeholder names in computer programming | baz |

```adoc
=== Section 1
[glossarist, /path/to/glossarist-dataset, dataset]
----
{%- for concept in dataset -%}
==== {{ concept.data.localizations['eng'].data.terms[0].designation }}

{{ concept.data.localizations['eng'].data.definition[0].content }}
{%- endfor -%}
----
```

this will output

```adoc
=== Section 1

==== foo

The term foo is used as metasyntactic variables and placeholder names in computer programming

==== bar

The term bar is used as metasyntactic variables and placeholder names in computer programming

==== baz

The term baz is used as metasyntactic variables and placeholder names in computer programming
```

Applying sorting and filtering by group

```adoc
=== Section 1
[glossarist, /path/to/glossarist-dataset, filter='group=foo;sort_by=term', dataset]
----
{%- for concept in dataset -%}
==== {{ concept.data.localizations['eng'].data.terms[0].designation }}

{{ concept.data.localizations['eng'].data.definition[0].content }}
{%- endfor -%}
----
```

this will output

```adoc
=== Section 1

==== bar

The term bar is used as metasyntactic variables and placeholder names in computer programming

==== foo

The term foo is used as metasyntactic variables and placeholder names in computer programming
```

The full concept model (a concept can have multiple localized concepts) is available via the gem [Glossarist](https://github.com/glossarist/glossarist-ruby).

The language codes used are ISO 639-* 3-character codes, as described in the
[Glossarist Concept model](https://github.com/glossarist/concept-model).


### Rendering a single term from loaded dataset

This can be used to render a single concept from the loaded dataset. See [Loading Dataset](#loading-dataset) to load a dataset.
This will use the [default template for rendering concepts](#default-template-for-rendering-concepts)

#### Syntax

`glossarist::render[<dataset name>, <term>]`

#### Example

Suppose we have a term named `foobar` in our dataset with the definition `The term foobar is used as metasyntactic variables and placeholder names in computer programming`

```adoc
:glossarist-dataset: dataset:./path/to/glossarist-dataset

=== Section
glossarist::render[dataset, foobar]
```

then the output will be

```adoc
=== Section
==== entity
concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things
```

### Rendering all terms from loaded dataset

This will render all the concepts from the [loaded dataset](#loading-dataset) using [default template for rendering concepts](#default-template-for-rendering-concepts)

#### Syntax

`glossarist::import[<dataset name>]`


### Rendering bibliography for a single term in the dataset

This will render a bibliography for a single term in the [loaded dataset](#loading-dataset) using the [default template for bibliography](#default-template-for-bibliography)

#### Syntax

`glossarist::render_bibliography_entry[<dataset name>, <term>]`

#### Example

Suppose we have a concept `foo` with the ref `ISO/TS 14812:2022`, then we can render the bibliography for this like

```adoc
:glossarist-dataset: dataset:./path/to/glossarist-dataset

glossarist::render_bibliography_entry[dataset, foo]
```

then the output will be

```adoc
* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]
```

### Rendering bibliography for all terms in the dataset

This will render all the bibliographies for the given dataset

#### Syntax

`glossarist::render_bibliography[<dataset name>]`

#### Example

Suppose we have following concepts in dataset

- `foo` with ref `ISO/TS 14812:2022`
- `bar` with ref `ISO/TS 14812:2023`

then we can render the bibliography for this like

```adoc
:glossarist-dataset: dataset:./path/to/glossarist-dataset

glossarist::render_bibliography[dataset]
```

then the output will be

```adoc
* [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]
* [[[ISO_TS_14812_2023,ISO/TS 14812:2023]]]
```


### Default template for rendering concepts

```adoc
==== {{ concept.data.localizations['eng'].data.terms[0].designation }}
<type>:[designation for the type]

{{ concept.data.localizations['eng'].data.definition[0].content }}

{% for example in <concept.data.localizations['eng'].data.examples> %}
[example]
{{ example.content }}

{% endfor %}

{% for note in <concept.data.localizations['eng'].data.notes> %}
[NOTE]
====
{{ note.content }}
====

{% endfor %}

{% for source in <concept.data.localizations['eng'].data.sources> %}
[.source]
<<{{ <source.origin.text.gsub(" ", "_").gsub("/", "_").gsub(":", "_")>,<source.origin.clause> }}>>

{% endfor %}
```

#### Example

```adoc
==== foobar
admitted:[E]

The term foobar is used as metasyntactic variables and placeholder names in computer programming

[example]
example for the term

[NOTE]
====
note for the term
====

[.source]
<<ISO_TS_14812_2022,foo_bar_id>>
```

### Default template for bibliography

```adoc
* [[[{{ <source.origin.text.gsub(" ", "_").gsub("/", "_").gsub(":", "_")>,<source.origin.clause> }},{{source.origin.text}}]]]
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/metanorma-plugin-glossarist. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/metanorma-plugin-glossarist/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the
[2-Clause BSD License](https://opensource.org/licenses/BSD-2-Clause).

## Code of Conduct

Everyone interacting in the Metanorma::Plugin::Glossarist project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/metanorma-plugin-glossarist/blob/master/CODE_OF_CONDUCT.md).
