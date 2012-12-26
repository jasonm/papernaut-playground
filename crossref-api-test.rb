require 'faraday'
require 'nokogiri'

class CrossrefAuthorTitleSearch
  API_USER_EMAIL = 'jason.p.morrison@gmail.com'

  def initialize(author, title, api_user_email = API_USER_EMAIL)
    @author = author
    @title = title
    @api_user_email = api_user_email
  end

  def identifiers
    result_xml = search.body
    extract_identifiers(result_xml)
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

  def extract_identifiers(xml)
    doc = Nokogiri::XML.parse(xml)

    identifiers = []

    if doi_record = doc.css('doi_record').first
      if isbn = doi_record.css('isbn').first
        identifiers << "ISBN:#{isbn.text}"
      end

      if doi = doi_record.css('doi').first
        identifiers << "DOI:#{doi.text}"
      end
    end

    identifiers
  end

  def api_http_connection
    Faraday.new(:url => 'http://doi.crossref.org') do |faraday|
      # faraday.request  :url_encoded
      # faraday.response :logger
      faraday.adapter  Faraday.default_adapter
    end
  end

  def xml
    <<-XML
      <?xml version="1.0"?>
      <query_batch version="2.0"
                   xsi:schemaLocation="http://www.crossref.org/qschema/2.0 http://www.crossref.org/qschema/crossref_query_input2.0.xsd"
                   xmlns="http://www.crossref.org/qschema/2.0"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"> 
        <head> 
           <email_address>jason.p.morrison@gmail.com</email_address> 
           <doi_batch_id>ABC_123_fff</doi_batch_id> 
        </head> 
        <body> 
          <query enable-multiple-hits="false" key="key1">
            <article_title match="fuzzy">#{@title}</article_title>
            <author search-all-authors="true">#{@author}</author>
          </query>
        </body> 
      </query_batch>
    XML
  end
end

author = 'Nicolai S Panikov'
title = 'Microbial Activity in Frozen Soils'
searcher = CrossrefAuthorTitleSearch.new(author, title)
identifiers = searcher.identifiers

puts "Identifiers:"
p identifiers


# 
# Synchronous HTTP queries
# 
# Synchronous queries are performed using a URL with encoded parameters as follows:
# http://doi.crossref.org/servlet/query?usr=<USERNAME>&pwd=<PASSWORD>&format=unixref&qdata=|Proc.%20Natl%20Acad.%20Sci.%20USA|Zhou|94|24|13215|1997|||
# http://doi.crossref.org/servlet/query?pid=<USERNAME>:<PASSWORD>&id=10.1577/H02-043
# http://doi.crossref.org/servlet/query?pid=<EMAIL>&id=10.1577/H02-043
# where:
# usr is your CrossRef-supplied login name.
# pwd is your CrossRef password.
# pid is your CrossRef-supplied login name and password or CrossRef Query Services email address.
# format is the desired results format ( xsd_xml | unixref | unixsd)
# qdata is the query data (XML or piped format)
#
#

result_xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
<doi_records>
  <doi_record key="key1" owner="10.1007" timestamp="2008-11-26 07:06:15">
    <crossref>
      <book book_type="other">
        <book_metadata language="en">
          <contributors>
            <person_name contributor_role="editor" sequence="first">
              <given_name>Rosa</given_name>
              <surname>Margesin</surname>
            </person_name>
          </contributors>
          <series_metadata>
            <titles>
              <title>Soil Biology</title>
            </titles>
          </series_metadata>
          <titles>
            <title>Permafrost Soils</title>
          </titles>
          <volume>16</volume>
          <publication_date media_type="print">
            <year>2009</year>
          </publication_date>
          <isbn media_type="print">978-3-540-69370-3</isbn>
          <isbn media_type="electronic">978-3-540-69371-0</isbn>
          <issn media_type="print">1613-3382</issn>
          <publisher>
            <publisher_name>Springer Berlin Heidelberg</publisher_name>
            <publisher_place>Berlin, Heidelberg</publisher_place>
          </publisher>
          <doi_data>
            <doi>10.1007/978-3-540-69371-0</doi>
            <resource>http://www.springerlink.com/index/10.1007/978-3-540-69371-0</resource>
          </doi_data>
        </book_metadata>
        <content_item component_type="chapter" language="en" level_sequence_number="1" publication_type="full_text">
          <contributors>
            <person_name contributor_role="author" sequence="first">
              <given_name>Nicolai S.</given_name>
              <surname>Panikov</surname>
            </person_name>
          </contributors>
          <titles>
            <title>Microbial Activity in Frozen Soils</title>
          </titles>
          <component_number>Chapter 9</component_number>
          <pages>
            <first_page>119</first_page>
            <last_page>147</last_page>
          </pages>
          <doi_data>
            <doi>10.1007/978-3-540-69371-0_9</doi>
            <resource>http://www.springerlink.com/index/10.1007/978-3-540-69371-0_9</resource>
            <collection property="crawler-based" setbyID="springer">
              <item crawler="iParadigms">
                <resource>http://www.springerlink.com/index/pdf/10.1007/978-3-540-69371-0_9</resource>
              </item>
            </collection>
          </doi_data>
        </content_item>
      </book>
    </crossref>
  </doi_record>
</doi_records>
XML


