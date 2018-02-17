require 'digest'
require 'net/http'
require 'nokogiri'
require 'uri'

require_relative 'review'

class SourceFeeds

	# The list of country codes is from: 
	# https://affiliate.itunes.apple.com/resources/documentation/linking-to-the-itunes-music-store/
	#
	# The feeds from some countries appear to be identical to those of some other countries.
	# For now I retrieve them all and deduplicate individual reviews.
	COUNTRY_CODES = ["al", "dz", "ao", "ai", "ag", "ar", "am", "au", "at", "az", "bs", 
		"bh", "bb", "bd", "by", "be", "bz", "bj", "bm", "bt", "bo", "bw", "br", "vg",
		"bn", "bg", "bf", "kh", "ca", "cv", "ci", "ky", "td", "cl", "cn", "co", "cg",
		"cr", "hr", "cy", "cz", "dk", "dm", "do", "ec", "eg", "sv", "ee", "fj", "fi",
		"fr", "gm", "de", "gh", "gr", "gd", "gt", "gw", "gy", "hn", "hk", "hu", "is",
		"in", "id", "ie", "il", "it", "jm", "jp", "jo", "kr", "kz", "ke", "kw", "kg",
		"la", "lv", "lb", "lr", "lt", "li", "lu", "mo", "mk", "mg", "mw", "my", "mv",
		"ml", "mt", "mr", "mu", "mx", "fm", "md", "mn", "ms", "mz", "na", "np", "nl",
		"nz", "ni", "ne", "ng", "no", "om", "pk", "pw", "pa", "pg", "py", "pe", "ph",
		"pl", "pt", "qa", "ro", "ru", "st", "sa", "sn", "sc", "sl", "sg", "sk", "si",
		"sb", "za", "kp", "es", "lk", "kn", "lc", "vc", "sr", "sz", "se", "ch", "tw",
		"tj", "tz", "th", "tt", "tn", "tr", "tm", "tc", "ae", "ug", "ua", "gb", "us",
		"uy", "uz", "ve", "vn", "ye", "zw"]

	def self.retrieve_reviews(itunes_app_id, max_days_back, sec_sleep)
		results_by_id = Hash.new
		COUNTRY_CODES.each do |country_code|
			country_reviews = SourceFeeds.retrieve_reviews_for_country(itunes_app_id, max_days_back, country_code)
			country_reviews.each do |review|
				results_by_id[review.review_id] = review
			end
			sleep sec_sleep
		end
		return results_by_id.values
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
					review_id = sha256.hexdigest("#{id}-#{updated_datetime.rfc3339}")
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
