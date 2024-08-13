# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::DatasetPreprocessor do
  let(:document) { Asciidoctor::Document.new }

  it "log" do
    # Valid command should create a log file
    input = <<~TEXT
      = Document title
      Author
      :nodoc:
      :novalid:
      :no-isobib:
      :imagesdir: spec/assets

      == Section 1
      [glossarist,./spec/fixtures/dataset-glossarist-v2,concepts]
      ----
      {%- for concept in concepts %}
      ==== {{ concept.data.localizations['ara'].data.terms[0].designation }}
      {% endfor -%}
      ----
    TEXT
    FileUtils.rm_rf("test.adoc.glossarist.log.txt")
    metanorma_process(input)
    expect(File.exist?("test.adoc.glossarist.log.txt")).to be true

    # Missing command should not create a log file
    input = <<~TEXT
      = Document title
      Author
      :nodoc:
      :novalid:
      :no-isobib:
      :imagesdir: spec/assets

      == Section 1
      ----
      {%- for concept in concepts %}
      ==== {{ concept.data.localizations['ara'].data.terms[0].designation }}
      {% endfor -%}
      ----
    TEXT
    FileUtils.rm_rf("test.adoc.glossarist.log.txt")
    metanorma_process(input)
    expect(File.exist?("test.adoc.glossarist.log.txt")).to be false
  end

  describe "#process" do
    context "Valid concepts" do
      context "[glossarist block]" do
        context "[without filters]" do
          let(:reader) do
            Asciidoctor::Reader.new <<~TEMPLATE
              some text before glossarist block

              === Section 1
              [glossarist,./spec/fixtures/dataset-glossarist-v2,concepts]
              ----
              {%- for concept in concepts -%}
              {%- if concept.data.localizations['eng'].data.terms[0].designation == 'entity' %}
              ==== {{ concept.data.localizations['eng'].data.terms[0].designation }}

              {{ concept.data.localizations['eng'].data.definition[0].content }}
              {% endif -%}
              {%- endfor -%}
              ----

              some text after glossarist block
            TEMPLATE
          end

          let(:expected_output) do
            <<~OUTPUT.strip
              some text before glossarist block

              === Section 1

              ==== entity

              concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things


              some text after glossarist block
            OUTPUT
          end

          it "should render correct output" do
            expect(subject.process(document, reader).source)
              .to eq(expected_output)
          end
        end

        context "[with filters]" do
          describe "filter='lang=ara'" do
            let(:reader) do
              Asciidoctor::Reader.new <<~TEMPLATE
                some text before glossarist block

                === Section 1
                [glossarist,./spec/fixtures/dataset-glossarist-v2,filter='lang=ara',concepts]
                ----
                {%- for concept in concepts %}
                ==== {{ concept.data.localizations['ara'].data.terms[0].designation }}

                {{ concept.data.localizations['ara'].data.definition[0].content }}
                {% endfor -%}
                ----

                some text after glossarist block
              TEMPLATE
            end

            let(:expected_output) do
              <<~OUTPUT.strip
                some text before glossarist block

                === Section 1


                some text after glossarist block
              OUTPUT
            end

            it "should render correct output" do
              expect(subject.process(document, reader).source)
                .to eq(expected_output)
            end
          end

          describe "filter='lang=deu'" do
            let(:reader) do
              Asciidoctor::Reader.new <<~TEMPLATE
                some text before glossarist block

                === Section 1
                [glossarist,./spec/fixtures/dataset-glossarist-v2,filter='lang=deu',concepts]
                ----
                {%- for concept in concepts %}
                ==== {{ concept.data.localizations['deu'].data.terms[0].designation }}

                {{ concept.data.localizations['deu'].data.definition[0].content }}
                {% endfor -%}
                ----

                some text after glossarist block
              TEMPLATE
            end

            let(:expected_output) do
              <<~OUTPUT.strip
                some text before glossarist block

                === Section 1

                ==== persoon

                biologische entiteit dat is een mens wezen


                some text after glossarist block
              OUTPUT
            end

            it "should render correct output" do
              expect(subject.process(document, reader).source)
                .to eq(expected_output)
            end
          end

          describe "filter='sort_by=term'" do
            let(:reader) do
              Asciidoctor::Reader.new <<~TEMPLATE
                some text before glossarist block

                === Section 1
                [glossarist,./spec/fixtures/dataset-glossarist-v2,filter='sort_by=term',concepts]
                ----
                {% for concept in concepts %}
                ==== {{ concept.data.localizations['eng'].data.terms[0].designation }}

                {%- if concept.data.localizations['eng'].data.terms.size > 1 %}
                {%- for term in concept.data.localizations["eng"].data.terms offset:1 %}
                {% if term.normative_status %}{{ term.normative_status }}{% else %}alt{% endif %}:[{{ term.designation }}]
                {%- endfor %}
                {%- endif %}

                {{ concept.data.localizations['eng'].data.definition[0].content }}
                {% endfor %}
                ----

                some text after glossarist block
              TEMPLATE
            end

            let(:expected_output) do
              <<~OUTPUT.strip
                some text before glossarist block

                === Section 1


                ==== biological entity

                {{material entity}} that was or is a living organism

                ==== entity
                admitted:[E]

                concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

                ==== material entity

                {{entity}} that occupies three-dimensional space

                ==== person

                {{biological entity}} that is a human being



                some text after glossarist block
              OUTPUT
            end

            it "should render correct output" do
              expect(subject.process(document, reader).source)
                .to eq(expected_output)
            end
          end

          describe "filter='group=foo;sort_by=term'" do
            let(:reader) do
              Asciidoctor::Reader.new <<~TEMPLATE
                some text before glossarist block

                === Section 1
                [glossarist,./spec/fixtures/dataset-glossarist-v2,filter='group=foo;sort_by=term',concepts]
                ----
                {% for concept in concepts %}
                ==== {{ concept.data.localizations['eng'].data.terms[0].designation }}

                {{ concept.data.localizations['eng'].data.definition[0].content }}
                {% endfor %}
                ----

                some text after glossarist block
              TEMPLATE
            end

            let(:expected_output) do
              <<~OUTPUT.strip
                some text before glossarist block

                === Section 1


                ==== entity

                concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

                ==== material entity

                {{entity}} that occupies three-dimensional space



                some text after glossarist block
              OUTPUT
            end

            it "should render correct output" do
              expect(subject.process(document, reader).source)
                .to eq(expected_output)
            end
          end

          describe "filter='lang=eng;data.localizations['eng'].data" \
                   ".terms[0].designation=entity'" do
            let(:reader) do
              Asciidoctor::Reader.new <<~TEMPLATE
                some text before glossarist block

                === Section 1
                [glossarist,./spec/fixtures/dataset-glossarist-v2,filter='lang=eng;data.localizations['eng'].data.terms[0].designation=entity',concepts]
                ----
                {%- for concept in concepts -%}
                ==== {{ concept.data.localizations['eng'].data.terms[0].designation }}

                {{ concept.data.localizations['eng'].data.definition[0].content }}
                {%- endfor -%}
                ----

                some text after glossarist block
              TEMPLATE
            end

            let(:expected_output) do
              <<~OUTPUT.strip
                some text before glossarist block

                === Section 1
                ==== entity

                concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

                some text after glossarist block
              OUTPUT
            end

            it "should render correct output" do
              expect(subject.process(document, reader).source)
                .to eq(expected_output)
            end
          end

          describe "filter='data.localizations['eng'].data.terms[0]" \
                   ".designation.start_with(enti)'" do
            let(:reader) do
              Asciidoctor::Reader.new <<~TEMPLATE
                some text before glossarist block

                === Section 1
                [glossarist,./spec/fixtures/dataset-glossarist-v2,filter='data.localizations['eng'].data.terms[0].designation.start_with(enti)',concepts]
                ----
                {%- for concept in concepts -%}
                ==== {{ concept.data.localizations['eng'].data.terms[0].designation }}

                {{ concept.data.localizations['eng'].data.definition[0].content }}
                {%- endfor -%}
                ----

                some text after glossarist block
              TEMPLATE
            end

            let(:expected_output) do
              <<~OUTPUT.strip
                some text before glossarist block

                === Section 1
                ==== entity

                concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

                some text after glossarist block
              OUTPUT
            end

            it "should render correct output" do
              expect(subject.process(document, reader).source)
                .to eq(expected_output)
            end
          end
        end
      end

      context "[load dataset]" do
        let(:reader) do
          Asciidoctor::Reader.new <<~TEMPLATE
            :glossarist-dataset: dataset1:./spec/fixtures/dataset-glossarist-v2

            === Render Section
            {%- for concept in dataset1 -%}
            {{ concept.data.localizations['eng'].data.definition[0].content }}
            {%- endfor -%}
          TEMPLATE
        end

        let(:expected_output) do
          <<~OUTPUT.strip
            === Render Section
            {%- for concept in dataset1 -%}
            {{ concept.data.localizations['eng'].data.definition[0].content }}
            {%- endfor -%}
          OUTPUT
        end

        it "should not render dataset as it is not loaded globally" do
          expect(subject.process(document, reader).source.strip)
            .to eq(expected_output)
        end
      end

      context "[load dataset with glossarist block]" do
        let(:reader) do
          Asciidoctor::Reader.new <<~TEMPLATE
            :glossarist-dataset: dataset1:./spec/fixtures/dataset-glossarist-v2

            === Section 1
            [glossarist,dataset1,filter='group=foo;sort_by=term',concepts]
            ----
            {% for concept in concepts %}
            ==== {{ concept.data.localizations['eng'].data.terms[0].designation }}

            {{ concept.data.localizations['eng'].data.definition[0].content }}
            {% endfor %}
            ----
          TEMPLATE
        end

        let(:expected_output) do
          <<~OUTPUT.strip
            === Section 1


            ==== entity

            concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

            ==== material entity

            {{entity}} that occupies three-dimensional space

          OUTPUT
        end

        it "should render correct output" do
          expect(subject.process(document, reader).source.strip)
            .to eq(expected_output)
        end
      end

      context "[render dataset]" do
        let(:reader) do
          Asciidoctor::Reader.new <<~TEMPLATE
            :glossarist-dataset: dataset1:./spec/fixtures/dataset-glossarist-v2

            === Terms and Definitions
            glossarist::import[dataset1,anchor-prefix=urn:iso:std:iso:14812:]
          TEMPLATE
        end

        let(:expected_output) do
          <<~OUTPUT.strip
            === Terms and Definitions
            [[urn_iso_std_iso_14812_3.1.1.5]]
            ==== biological entity



            {{material entity}} that was or is a living organism





            [.source]
            <<ISO_TS_14812_2023,3.1.1.5>>



            [[urn_iso_std_iso_14812_3.1.1.1]]
            ==== entity

            admitted:[E]

            concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

            [example]
            {{person,Person}}, object, event, idea, process, etc.





            [.source]
            <<ISO_TS_14812_2022,3.1.1.1>>



            [[urn_iso_std_iso_14812_3.1.1.3]]
            ==== material entity



            {{entity}} that occupies three-dimensional space



            [NOTE]
            ====
            All material entities have certain characteristics that can be described and therefore this concept is important for ontology purposes.
            ====



            [.source]
            <<ISO_TS_14812_2022,3.1.1.3>>



            [[urn_iso_std_iso_14812_3.1.1.6]]
            ==== person



            {{biological entity}} that is a human being





            [.source]
            <<ISO_TS_14812_2022,3.1.1.6>>
          OUTPUT
        end

        it "should render correct output" do
          expect(subject.process(document, reader).source.strip)
            .to eq(expected_output)
        end
      end

      context "[render concept]" do
        context "with 3 level title depth" do
          let(:reader) do
            Asciidoctor::Reader.new <<~TEMPLATE
              :glossarist-dataset: dataset1:./spec/fixtures/dataset-glossarist-v2

              === Render Section
              glossarist::render[dataset1, entity]
            TEMPLATE
          end

          let(:expected_output) do
            <<~OUTPUT.strip
              === Render Section
              [[3.1.1.1]]
              ==== entity

              admitted:[E]

              concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

              [example]
              {{person,Person}}, object, event, idea, process, etc.





              [.source]
              <<ISO_TS_14812_2022,3.1.1.1>>
            OUTPUT
          end

          it "should render correct output" do
            expect(subject.process(document, reader).source.strip)
              .to eq(expected_output)
          end
        end

        context "with 2 level title depth" do
          let(:reader) do
            Asciidoctor::Reader.new <<~TEMPLATE
              :glossarist-dataset: dataset1:./spec/fixtures/dataset-glossarist-v2

              == Render Section
              glossarist::render[dataset1, entity]
            TEMPLATE
          end

          let(:expected_output) do
            <<~OUTPUT.strip
              == Render Section
              [[3.1.1.1]]
              === entity

              admitted:[E]

              concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

              [example]
              {{person,Person}}, object, event, idea, process, etc.





              [.source]
              <<ISO_TS_14812_2022,3.1.1.1>>
            OUTPUT
          end

          it "should render correct output" do
            expect(subject.process(document, reader).source.strip)
              .to eq(expected_output)
          end
        end

        context "with anchor-prefix" do
          let(:reader) do
            Asciidoctor::Reader.new <<~TEMPLATE
              :glossarist-dataset: dataset1:./spec/fixtures/dataset-glossarist-v2

              == Render Section
              glossarist::render[dataset1, entity, anchor-prefix=identifier-]
            TEMPLATE
          end

          let(:expected_output) do
            <<~OUTPUT.strip
              == Render Section
              [[identifier-3.1.1.1]]
              === entity

              admitted:[E]

              concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

              [example]
              {{person,Person}}, object, event, idea, process, etc.





              [.source]
              <<ISO_TS_14812_2022,3.1.1.1>>
            OUTPUT
          end

          it "should render correct output" do
            expect(subject.process(document, reader).source.strip)
              .to eq(expected_output)
          end
        end
      end

      context "[import dataset]" do
        context "with 3 level title depth" do
          let(:reader) do
            Asciidoctor::Reader.new <<~TEMPLATE
              :glossarist-dataset: dataset1:./spec/fixtures/dataset-glossarist-v2

              glossarist::import[dataset1]
            TEMPLATE
          end

          let(:expected_output) do
            <<~OUTPUT.strip
              [[3.1.1.5]]
              === biological entity



              {{material entity}} that was or is a living organism





              [.source]
              <<ISO_TS_14812_2023,3.1.1.5>>



              [[3.1.1.1]]
              === entity

              admitted:[E]

              concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things

              [example]
              {{person,Person}}, object, event, idea, process, etc.





              [.source]
              <<ISO_TS_14812_2022,3.1.1.1>>



              [[3.1.1.3]]
              === material entity



              {{entity}} that occupies three-dimensional space



              [NOTE]
              ====
              All material entities have certain characteristics that can be described and therefore this concept is important for ontology purposes.
              ====



              [.source]
              <<ISO_TS_14812_2022,3.1.1.3>>



              [[3.1.1.6]]
              === person



              {{biological entity}} that is a human being





              [.source]
              <<ISO_TS_14812_2022,3.1.1.6>>
            OUTPUT
          end

          it "should render correct output" do
            expect(subject.process(document, reader).source.strip)
              .to eq(expected_output)
          end
        end
      end

      context "[render bibliography]" do
        let(:reader) do
          Asciidoctor::Reader.new <<~TEMPLATE
            :glossarist-dataset: dataset1:./spec/fixtures/dataset-glossarist-v2

            glossarist::render_bibliography[dataset1]
          TEMPLATE
        end

        let(:expected_output) do
          <<~OUTPUT.strip
            * [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]
            * [[[ISO_TS_14812_2023,ISO/TS 14812:2023]]]
          OUTPUT
        end

        it "should render correct output" do
          expect(subject.process(document, reader).source.strip)
            .to eq(expected_output)
        end
      end
    end

    context "Invalid concepts" do
      let(:reader) do
        Asciidoctor::Reader.new <<~TEMPLATE
          some text before glossarist block

          === Section 1
          [glossarist,./spec/fixtures/invalid_dataset,concepts]
          ----
          {%- for concept in concepts %}
          ==== {{ concept.data.localizations['ara'].data.terms[0].designation }}
          {% endfor -%}
          ----

          some text after glossarist block
        TEMPLATE
      end

      it "is expected to raise Glossarist::ParseError" do
        expect { subject.process(document, reader) }
          .to raise_error(Glossarist::ParseError)
      end
    end
  end

  def absolute_path(path)
    Metanorma::Cli.root_path.join(path)
  end

  def fixtures_path
    @fixtures_path ||= Metanorma::Cli.root_path.join("spec", "fixtures")
  end
end
