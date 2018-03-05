require 'digest'
require 'net/http'
require 'nokogiri'
require 'securerandom'
require 'uri'

require_relative 'entry'

class SourceFeeds

	# The list of country codes is from: 
	# https://affiliate.itunes.apple.com/resources/documentation/linking-to-the-itunes-music-store/
	#
	# The feeds from some countries appear to be identical to those of some other countries.
	# For now I retrieve them all and deduplicate individual reviews.
	SOURCE_COUNTRIES = ["al", "dz", "ao", "ai", "ag", "ar", "am", "au", "at", "az", "bs", 
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

	def self.retrieve_entries(itunes_app_id, max_days_back, sec_sleep, dest_translation_setting, source_countries=nil)
		results_by_id = Hash.new
		if source_countries.nil?
			source_countries = SOURCE_COUNTRIES
		end
		source_countries.each do |country_code|
			country_entries = SourceFeeds.retrieve_entries_for_country(itunes_app_id, max_days_back, country_code, dest_translation_setting)
			country_entries.each do |entry|
				results_by_id[entry.entry_id] = entry
			end
			sleep sec_sleep
		end
		return results_by_id.values
	end
	
	private
	
	def self.retrieve_entries_for_country(itunes_app_id, max_days_back, country_code, dest_translation_setting)
		result = Array.new
		html_encoder = HTMLEntities.new
		url = "https://itunes.apple.com/#{country_code}/rss/customerreviews/page=1/id=#{itunes_app_id}/sortby=mostrecent/xml?urlDesc=/customerreviews/page=1/id=#{itunes_app_id}/sortBy=mostRecent/xml"
		print "Retrieving #{url}\n"
		begin
			response = SourceFeeds.get_url(url)
		rescue
			return self.create_error_entry_array(country_code, "Unable to retrieve #{url}")
		end
		if response.code != "200"
			return self.create_error_entry_array(country_code, "Unexpected status code: #{response.code}")
		end
		response_body = response.body
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
 			rating = rating_text.to_i
			updated_text = entry.at_xpath('updated').content
			if ((!id.nil?) and (!author.nil?) and (!title.nil?) and (!text.nil?) and (!rating_text.nil?) and (!updated_text.nil?))
				rating = rating_text.to_i
				updated_datetime = DateTime.parse(updated_text).new_offset(0)
				if DateTime.now - updated_datetime <= max_days_back
					review_id = sha256.hexdigest("#{id}-#{updated_datetime.rfc3339}")
					
					
					escaped_text = html_encoder.encode(text, :decimal)
					# Convert double \n sequences to paragraph breaks, and single \n sequences 
					# to line breaks
					escaped_text = escaped_text.gsub("&#10;&#10;", "</p><p>")
					escaped_text = escaped_text.gsub("&#10;", "<br>")
					
					rating_text = ""
					rating.times do
						rating_text += "★"
					end
					if ((rating > 0) and (rating < 5))
						num_empty_stars = 5 - rating
						num_empty_stars.times do
							rating_text += "☆"
						end
					end
					escaped_rating_text = html_encoder.encode(rating_text, :decimal)
					
					google_translate_text = "#{title}\n\n#{text}"
					google_translate_url = "https://translate.google.com/#auto|#{dest_translation_setting}|#{URI::encode(google_translate_text)}"
					escaped_google_translate_url = html_encoder.encode(google_translate_url, :decimal)
					
					html = "<p>#{escaped_text}</p><p>#{escaped_rating_text}</p><p><a href=\"#{escaped_google_translate_url}\">Google Translate</p>"

					result.push(Entry.new(review_id, author, title, html, updated_datetime))
				end
			end
		end
		return result
	end
	
	def self.create_error_entry_array( country_code, error_message )
		uuid = SecureRandom.uuid
		date_time = DateTime.now
		html_encoder = HTMLEntities.new
		error_message_html = html_encoder.encode(error_message)
		entry_html = "<p>#{error_message_html}</p>"
		
		result_array = Array.new
		result_array.push(Entry.new(uuid, "Feed Generator", "Unable to Retrieve Reviews for #{country_code}", entry_html, date_time))
		return result_array
	end
	
	def self.element_content(parent_element, child_element_xpath)
		child = parent_element.at_xpath(child_element_xpath)
		if child.nil?
			return nil
		end
		return child.content
	end
	
	# Must be an HTTPS URL
	def self.get_url(url)
		uri = URI.parse(url)
		http_object = Net::HTTP.new(uri.host, uri.port)
		http_object.use_ssl = true
		http_object.read_timeout = 500
		request = Net::HTTP::Get.new uri.request_uri
		return http_object.request request
	end

end
