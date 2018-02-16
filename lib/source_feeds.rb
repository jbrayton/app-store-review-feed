require 'digest'
require 'net/http'
require 'nokogiri'
require 'uri'

require_relative 'review'

class SourceFeeds

	# There are 130 different country codes at:
	# https://affiliate.itunes.apple.com/resources/documentation/linking-to-the-itunes-music-store/
	# Some countries have feeds that are identical to those of other countries. It looks 
	# like we can get all reviews by retrieving feeds for these country codes:
	COUNTRY_CODES = ["ar","au","br","by","ca","ch","cn","de","es","fi","fr","gb","hk","hr","ie","il","in","it","jp","lv","my","nl","pl","ru","se","th","ua","us"]

	def self.retrieve_reviews(itunes_app_id, max_days_back, sec_sleep)
		result = Array.new
		COUNTRY_CODES.each do |country_code|
			result = result + SourceFeeds.retrieve_reviews_for_country(itunes_app_id, max_days_back, country_code)
			sleep sec_sleep
		end
		return result
	end
	
	private
	
	def self.retrieve_reviews_for_country(itunes_app_id, max_days_back, country_code)
		result = Array.new
		url = "https://itunes.apple.com/#{country_code}/rss/customerreviews/page=1/id=#{itunes_app_id}/sortby=mostrecent/xml?urlDesc=/customerreviews/page=1/id=#{itunes_app_id}/sortBy=mostRecent/xml"
		print "Retrieving #{url}\n"
		response_body = SourceFeeds.get_contents_of_url(url)
		doc = Nokogiri::XML(response_body)
		doc.remove_namespaces!
		sha256 = Digest::SHA256.new
		entries = doc.xpath('//entry')
		entries.each do |entry|
			id = SourceFeeds.element_content(entry, "id")
			author = SourceFeeds.element_content(entry, "author/name")
			title = SourceFeeds.element_content(entry, "title")
			text = SourceFeeds.element_content(entry, "content[@type='text']")
 			rating_text = SourceFeeds.element_content(entry, "rating")
			updated_text = entry.at_xpath('updated').content
			if ((!id.nil?) and (!author.nil?) and (!title.nil?) and (!text.nil?) and (!rating_text.nil?) and (!updated_text.nil?))
				rating = rating_text.to_i
				updated_datetime = DateTime.parse(updated_text).new_offset(0)
				if DateTime.now - updated_datetime <= max_days_back
					review_id = sha256.hexdigest("#{id}-#{country_code}-#{updated_datetime.rfc3339}")
					result.push(Review.new(review_id, author, title, text, rating, updated_datetime))
				end
			end
		end
		return result
	end
	
	def self.element_content(parent_element, child_element_xpath)
		child = parent_element.at_xpath(child_element_xpath)
		if child.nil?
			return nil
		end
		return child.content
	end
	
	# Must be an HTTPS URL
	def self.get_contents_of_url(url)
		uri = URI.parse(url)
		http_object = Net::HTTP.new(uri.host, uri.port)
		http_object.use_ssl = true
		http_object.read_timeout = 500
		request = Net::HTTP::Get.new uri.request_uri
		response = http_object.request request
		return response.body
	end

end