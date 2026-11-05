# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe Metanorma::Plugin::Glossarist::DatasetRegistry do
  let(:registry) { described_class.new }
  let(:dataset) do
    File.expand_path("../../../fixtures/dataset-glossarist-v3", __dir__)
  end
  let(:v2_dataset) do
    File.expand_path("../../../fixtures/dataset-glossarist-v2", __dir__)
  end
  let(:cache_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(cache_dir) }

  it "writes nothing when the cache is not opted into" do
    described_class.new.concepts_at(dataset)
    expect(Dir.children(cache_dir)).to be_empty
  end

  it "round-trips concepts through the cache identically" do
    ENV["GLOSSARIST_CACHE_DIR"] = cache_dir
    begin
      first = described_class.new.concepts_at(v2_dataset)
      expect(first.size).to eq(4)
      second = described_class.new.concepts_at(v2_dataset)
      expect(second.map(&:id)).to eq(first.map(&:id))
      expect(second).not_to equal(first) # a distinct object graph
    ensure
      ENV.delete("GLOSSARIST_CACHE_DIR")
    end
  end

  it "recovers from a corrupt cache file" do
    ENV["GLOSSARIST_CACHE_DIR"] = cache_dir
    begin
      expected = described_class.new.concepts_at(dataset).map(&:id).sort
      Dir.children(cache_dir).each do |f|
        File.binwrite(File.join(cache_dir, f), "\xFF\xFEinvalid-marshal")
      end
      reloaded = described_class.new.concepts_at(dataset)
      expect(reloaded.map(&:id).sort).to eq(expected)
    ensure
      ENV.delete("GLOSSARIST_CACHE_DIR")
    end
  end

  it "bypasses the cache for datasets with non-verbal directories" do
    ENV["GLOSSARIST_CACHE_DIR"] = cache_dir
    begin
      # dataset-glossarist-v3 carries figures/tables/formulas/
      registry.concepts_at(v2_dataset) # warm nothing for v3
      expect(Dir.children(cache_dir).grep(/concepts-/)).not_to be_empty

      described_class.new.concepts_at(dataset)
      cache_files = Dir.children(cache_dir).grep(/concepts-/)
      # the v3 dataset must not add a cache entry of its own
      expect(cache_files.size).to eq(1)
    ensure
      ENV.delete("GLOSSARIST_CACHE_DIR")
    end
  end

  it "serves a plain v2 dataset through the cache stand-in" do
    ENV["GLOSSARIST_CACHE_DIR"] = cache_dir
    begin
      first = registry.concepts_at(v2_dataset)
      second = registry.concepts_at(v2_dataset)
      expect(second.map(&:id)).to eq(first.map(&:id))
    ensure
      ENV.delete("GLOSSARIST_CACHE_DIR")
    end
  end

  it "hits the same cache entry when identical content is rewritten" do
    dir = Dir.mktmpdir
    ENV["GLOSSARIST_CACHE_DIR"] = cache_dir
    begin
      FileUtils.cp_r(File.join(v2_dataset, "."), dir)
      registry.concepts_at(dir)
      before = Dir.children(cache_dir).grep(/concepts-/)

      # Regenerated in place: identical bytes, fresh mtimes.
      sleep 1.1 # cross the filesystem's mtime granularity
      Dir.glob(File.join(dir, "**", "*.{yaml,yml}")).each do |f|
        FileUtils.touch(f)
      end

      described_class.new.concepts_at(dir)
      expect(Dir.children(cache_dir).grep(/concepts-/)).to eq(before)
    ensure
      ENV.delete("GLOSSARIST_CACHE_DIR")
      FileUtils.rm_rf(dir)
    end
  end

  it "keys the cache on content: changed bytes yield a distinct entry" do
    dir = Dir.mktmpdir
    ENV["GLOSSARIST_CACHE_DIR"] = cache_dir
    begin
      FileUtils.cp_r(File.join(v2_dataset, "."), dir)
      registry.concepts_at(dir)
      before = Dir.children(cache_dir).grep(/concepts-/)

      target = Dir.glob(File.join(dir, "**", "*.yaml")).first
      File.write(target, File.read(target) + "\n# changed\n")

      described_class.new.concepts_at(dir)
      after = Dir.children(cache_dir).grep(/concepts-/)
      expect(after - before).not_to be_empty
    ensure
      ENV.delete("GLOSSARIST_CACHE_DIR")
      FileUtils.rm_rf(dir)
    end
  end
end
