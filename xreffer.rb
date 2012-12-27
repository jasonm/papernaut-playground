require 'bibtex'
require 'active_support/core_ext/object/blank'
require 'active_model'
require '/Users/jason/dev/journalclub/frontend/app/models/bibtex_import'
require 'digest/md5'

require './crossref_author_title_search'

BibTeX.log.level = Logger::ERROR

# fake replacement for Rails model in journalclub/frontend
class Identifier
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_accessor :article_id, :body

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end
end

# module Enumerable
#   def map_with_progress(&block)
#     bar = ProgressBar.create({
#       total: size,
#       length: 80,
#       format: "%t: |%B| (%c/%C)"
#     })
# 
#     each_with_index do |element, index|
#       bar.increment
#       block.call(element) if block
#     end
#   end
# end


class Crossreffer
  def initialize(bibtex_filename)
    @bibtex_filename = bibtex_filename
  end

  def identify
    batch_size = 10
    which_batch = 0
    all_identifiers = []
    unidentified_entries.each_slice(batch_size) do |entries_batch|
      puts "batch: #{which_batch += 1} containing #{entries_batch.size}"

      each_identified_entry(entries_batch) do |entry, identifiers|
        if identifiers.any?
          puts "Found #{identifiers.size} new identifiers for '#{entry.article_attributes[:title]}' by #{entry.article_attributes[:author]}:"
          all_identifiers << identifiers
        end
      end

      sleep 1
    end

    puts "found #{all_identifiers.size} identifiers in total:"
    p all_identifiers
  end

  def unidentified_entries
    entries.select { |entry|
      entry.article_attributes[:identifiers].none?
    }
  end

  def entries
    @entries ||= bibliography.data.map do |data|
      next if ! data.is_a? BibTeX::Entry
      BibtexImport::Entry.new(data)
    end.compact
  end

  def bibliography
    BibTeX::Bibliography.parse(bibtex_source).convert(:latex)
  end

  def bibtex_source
    File.open(@bibtex_filename).read
  end

  def each_identified_entry(entries, &block)
    indexes = 0..entries.size-1
    entries_with_indices = entries.zip(indexes)

    searches = entries_with_indices.map { |entry, index|
      {
        author: entry.article_attributes[:author],
        title: entry.article_attributes[:title],
        key: index
      }
    }

    results = CrossrefAuthorTitleSearch.new(searches).results

    puts "got #{results.size} results"
    results.each do |key, entry_identifiers|
      block.call(entries[key.to_i], entry_identifiers)
    end
  end
end

bib_filename = ARGV[0]
puts "Reading bibliography #{bib_filename}..."
xreffer = Crossreffer.new(bib_filename)

puts "Counting unidentified entries..."

puts "#{xreffer.entries.count} entries, #{xreffer.unidentified_entries.count} unidentified"

xreffer.identify
