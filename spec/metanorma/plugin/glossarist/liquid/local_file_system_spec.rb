# frozen_string_literal: true

RSpec.describe Metanorma::Plugin::Glossarist::Liquid::LocalFileSystem do
  let(:templates_dir) do
    File.join(File.dirname(__FILE__), "../../../../fixtures/templates")
  end

  before do
    FileUtils.mkdir_p(templates_dir)
  end

  after do
    FileUtils.rm_rf(templates_dir)
  end

  describe "#read_template_file" do
    it "reads an existing template from a single root" do
      File.write(File.join(templates_dir, "_test.liquid"), "hello {{ name }}")
      fs = described_class.new([templates_dir])
      content = fs.read_template_file("test")
      expect(content).to eq("hello {{ name }}")
    end

    it "searches multiple roots in order" do
      dir2 = File.join(templates_dir, "second")
      FileUtils.mkdir_p(dir2)
      File.write(File.join(dir2, "_found.liquid"), "from second")
      fs = described_class.new([templates_dir, dir2])
      expect(fs.read_template_file("found")).to eq("from second")
    end

    it "uses custom patterns" do
      File.write(File.join(templates_dir, "custom_pat.liquid"), "custom")
      fs = described_class.new([templates_dir], ["%s.liquid"])
      expect(fs.read_template_file("custom_pat")).to eq("custom")
    end

    it "raises FileSystemError for missing templates" do
      fs = described_class.new([templates_dir])
      expect { fs.read_template_file("nonexistent") }.to raise_error(Liquid::FileSystemError)
    end
  end

  describe "#full_path" do
    it "resolves templates with subdirectory paths" do
      sub = File.join(templates_dir, "sub")
      FileUtils.mkdir_p(sub)
      File.write(File.join(sub, "_nested.liquid"), "nested")
      fs = described_class.new([templates_dir])
      path = fs.full_path("sub/nested")
      expect(path).to end_with("sub/_nested.liquid")
    end

    it "raises on illegal template names with path traversal" do
      fs = described_class.new([templates_dir])
      expect { fs.full_path("../etc/passwd") }.to raise_error(Liquid::FileSystemError)
    end

    it "raises on template names starting with a dot" do
      fs = described_class.new([templates_dir])
      expect { fs.full_path(".hidden") }.to raise_error(Liquid::FileSystemError)
    end

    it "raises when no matching file exists across roots" do
      fs = described_class.new([templates_dir])
      expect { fs.full_path("missing") }.to raise_error(Liquid::FileSystemError)
    end
  end
end
