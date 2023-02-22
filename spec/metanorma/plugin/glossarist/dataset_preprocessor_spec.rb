# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::DatasetPreprocessor do
  let(:document) { Asciidoctor::Document.new }

  describe "#process" do
    context "[glossarist block]" do
      context "[without filters]" do
        let(:reader) do
          Asciidoctor::Reader.new <<~TEMPLATE
            some text before glossarist block

            === Section 1
            [glossarist,./spec/fixtures/dataset1,concepts]
            ----
            ==== {{ concepts['entity'].term }}

            {{ concepts['entity'].eng.definition[0].content }}
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
          expect(subject.process(document, reader).source).to eq(expected_output)
        end
      end

      context "[with filters]" do
        describe "filter='lang=ara'" do
          let(:reader) do
            Asciidoctor::Reader.new <<~TEMPLATE
              some text before glossarist block

              === Section 1
              [glossarist,./spec/fixtures/dataset1,filter='lang=ara',concepts]
              ----
              {% for concept in concepts %}
              ==== {{ concept.term }}

              {{ concept.eng.definition[0].content }}
              {% endfor %}
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
            expect(subject.process(document, reader).source).to eq(expected_output)
          end
        end

        describe "filter='lang=eng;eng.terms.0.designation=entity'" do
          let(:reader) do
            Asciidoctor::Reader.new <<~TEMPLATE
              some text before glossarist block

              === Section 1
              [glossarist,./spec/fixtures/dataset1,filter='lang=eng;eng.terms.0.designation=entity',concepts]
              ----
              {%- for concept in concepts -%}
              ==== {{ concept.term }}

              {{ concept.eng.definition[0].content }}
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
            expect(subject.process(document, reader).source).to eq(expected_output)
          end
        end
      end
    end

    context "[load dataset]" do
      let(:reader) do
        Asciidoctor::Reader.new <<~TEMPLATE
          :glossarist-dataset: dataset1:./spec/fixtures/dataset1

          === Render Section
          {{ dataset1['entity']['eng'].definition[0].content }}
        TEMPLATE
      end

      let(:expected_output) do
        <<~OUTPUT.strip
          === Render Section
          concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things
        OUTPUT
      end

      it "should render correct output" do
        expect(subject.process(document, reader).source.strip).to eq(expected_output)
      end
    end

    context "[render concept]" do
      let(:reader) do
        Asciidoctor::Reader.new <<~TEMPLATE
          :glossarist-dataset: dataset1:./spec/fixtures/dataset1

          === Render Section
          glossarist::render[dataset1, entity]
        TEMPLATE
      end

      let(:expected_output) do
        <<~OUTPUT.strip
          === Render Section
          ==== entity


          concrete or abstract thing that exists, did exist, or can possibly exist, including associations among these things


          [example]
          {{person,Person}}, object, event, idea, process, etc.








          [.source]
          <<ISO_TS_14812_2022,3.1.1.1>>
        OUTPUT
      end

      it "should render correct output" do
        expect(subject.process(document, reader).source.strip).to eq(expected_output)
      end
    end

    context "[render bibliography entry]" do
      let(:reader) do
        Asciidoctor::Reader.new <<~TEMPLATE
          :glossarist-dataset: dataset1:./spec/fixtures/dataset1

          glossarist::render_bibliography_entry[dataset1, entity]
        TEMPLATE
      end

      let(:expected_output) do
        <<~OUTPUT.strip
          * [[[ISO_TS_14812_2022,ISO/TS 14812:2022]]]
        OUTPUT
      end

      it "should render correct output" do
        expect(subject.process(document, reader).source.strip).to eq(expected_output)
      end
    end

    context "[render bibliography]" do
      let(:reader) do
        Asciidoctor::Reader.new <<~TEMPLATE
          :glossarist-dataset: dataset1:./spec/fixtures/dataset1

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
        expect(subject.process(document, reader).source.strip).to eq(expected_output)
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
