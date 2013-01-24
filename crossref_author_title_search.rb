# encoding: utf-8

require 'faraday'
require 'nokogiri'
require 'erb'
require 'logger'

class CrossrefAuthorTitleSearch
  API_USER_EMAIL = 'jason.p.morrison@gmail.com'

  # 'searches' is an array of queries, each including a key for batch result retrieval:
  # [{ author: '...', title: '...', key: '...'}, {...}, ...]
  def initialize(searches, api_user_email = API_USER_EMAIL)
    @searches = searches
    @api_user_email = api_user_email
  end

  def results
    result_xml = search.body
    logger.debug("response xml: " + result_xml)
    extract_identifiers_by_keys(result_xml)
  end

  private

  def search
    api_http_connection.get do |req|
      req.url '/servlet/query'
      req.params = {
        pid: @api_user_email,
        qdata: xml,
        format: 'unixref'
      }
    end
  end

  def extract_identifiers_by_keys(xml)
    doc = Nokogiri::XML.parse(xml)

    identifiers_by_key = {}

    doc.css('doi_record').each do |doi_record|
      key = doi_record.attr('key')

      identifiers_by_key[key] = []

      if isbn = doi_record.css('isbn').first
        identifiers_by_key[key] << "ISBN:#{isbn.text}"
      end

      if doi = doi_record.css('doi').first
        identifiers_by_key[key] << "DOI:#{doi.text}"
      end
    end

    identifiers_by_key
  end

  def api_http_connection
    Faraday.new(:url => 'http://doi.crossref.org') do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.response :logger, logger
      faraday.request :url_encoded
      faraday.request :retry, {
        max: 5,
        interval: 5.0,
        exceptions: [
          Errno::EINVAL,
          Errno::ECONNRESET,
          Errno::ETIMEDOUT,
          EOFError,
          Net::HTTPBadResponse,
          Net::HTTPHeaderSyntaxError,
          Net::ProtocolError
        ]
      }
    end
  end

  def xml
    template = <<-XML
      <?xml version="1.0"?>
      <query_batch version="2.0"
                   xsi:schemaLocation="http://www.crossref.org/qschema/2.0 http://www.crossref.org/qschema/crossref_query_input2.0.xsd"
                   xmlns="http://www.crossref.org/qschema/2.0"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"> 
        <head> 
           <email_address><%= @api_user_email %></email_address> 
           <doi_batch_id>batch-at-<%= Time.now.to_s.gsub(' ','-') %></doi_batch_id> 
        </head> 
        <body> 
        <% @searches.each do |search| %>
          <query enable-multiple-hits="false" key="<%= search[:key] %>">
            <article_title match="fuzzy"><%= search[:title] %></article_title>
            <author search-all-authors="true"><%= search[:author] %></author>
          </query>
        <% end %>
        </body>
      </query_batch>
    XML

    res = ERB.new(template).result(binding)
    logger.debug("Query: #{res}")
    res
  end

  def logger
    @@logger ||= Logger.new(File.open('/tmp/crossref-author-title-search.log', File::WRONLY | File::APPEND | File::CREAT))
  end
end

if $0 == __FILE__
  author = 'Nicolai S Panikov'
  title = 'Microbial Activity in Frozen Soils'

  searcher = CrossrefAuthorTitleSearch.new([{author: author, title: title, key: 'search1' }])
  identifiers = searcher.results['search1']

  puts "Identifiers:"
  p identifiers
end
