require 'cgi'
require 'date'
require 'digest'
require 'net/http'
require 'securerandom'
require 'uri'

require_relative 'entry'

class SourceFeeds

	# The list of country codes is from: 
	# https://affiliate.itunes.apple.com/resources/documentation/linking-to-the-itunes-music-store/
	#
	# The feeds from some countries appear to be identical to those of some other countries.
	# For now I retrieve them all and deduplicate individual reviews.
	SOURCE_COUNTRIES = [
		"al", "dz", "ao", "ai", "ag", "ar", "am", "au", "at", "az", "bs", 
		"bh", "bb", "by", "be", "bz", "bj", "bm", "bt", "bo", "bw", "br",
		"vg", "bn", "bg", "bf", "kh", "ca", "cv", "ci", "ky", "td", "cl",
		"cn", "co", "cg", "cr", "hr", "cy", "cz", "dk", "dm", "do", "ec",
		"eg", "sv", "ee", "fj", "fi", "fr", "gm", "de", "gh", "gr", "gd",
		"gt", "gw", "gy", "hn", "hk", "hu", "is", "in", "id", "ie", "il",
		"it", "jm", "jp", "jo", "kr", "kz", "ke", "kw", "kg", "la", "lv",
		"lb", "lr", "lt", "lu", "mo", "mk", "mg", "mw", "my", "mv", "ml",
		"mt", "mr", "mu", "mx", "fm", "md", "mn", "ms", "mz", "na", "np",
		"nl", "nz", "ni", "ne", "ng", "no", "om", "pk", "pw", "pa", "pg",
		"py", "pe", "ph", "pl", "pt", "qa", "ro", "ru", "st", "sa", "sn",
		"sc", "sl", "sg", "sk", "si", "sb", "za", "es", "lk", "kn", "lc",
		"vc", "sr", "sz", "se", "ch", "tw", "tj", "tz", "th", "tt", "tn",
		"tr", "tm", "tc", "ae", "ug", "ua", "gb", "us", "uy", "uz", "ve",
		"vn", "ye", "zw"]

	def self.retrieve_entries(itunes_app_id, sec_sleep, dest_translation_setting, source_countries, review_id_seed, prior_entry_dates)
		results_by_id = Hash.new
		if source_countries.nil?
			source_countries = SOURCE_COUNTRIES
		end
		
		# Err on the side of the publish date being in the future, to make sure it is not
		# skipped by a reader/aggregator that ignores publish dates that pre-date the 
		# prior crawl.
		new_time = Time.now.utc + (SOURCE_COUNTRIES.length * sec_sleep) + 300
		new_entry_date = DateTime.parse(new_time.to_s).rfc3339
		source_countries.each do |country_code|
			country_entries = SourceFeeds.retrieve_entries_for_country(itunes_app_id, country_code, dest_translation_setting, review_id_seed, prior_entry_dates, new_entry_date)
			country_entries.each do |entry|
				results_by_id[entry.entry_id] = entry
			end
			# sleep sec_sleep
		end
		return results_by_id.values
	end
	
	private
	
	###
	# I retrieve in a JSON format because that has been more reliable. The format is not JSON Feed -- it appears to be a straight
	# translation of the Atom format into JSON.
	###
	def self.retrieve_entries_for_country(itunes_app_id, country_code, dest_translation_setting, review_id_seed, prior_entry_dates, new_entry_date)
		result = Array.new
		url = "https://itunes.apple.com/#{country_code}/rss/customerreviews/page=1/id=#{itunes_app_id}/sortby=mostrecent/json"
		print "Retrieving #{url}\n"
		begin
			response = SourceFeeds.get_url(url)
		rescue
			return self.create_error_entry_array(country_code, "Unable to retrieve #{url}")
		end
		if response.code != "200"
			return result
		end
		response_body = response.body
		json = JSON.parse(response_body)
		feed = json['feed']
		if feed.has_key?('entry')
			entries = feed['entry']
			if !entries.is_a?(Array)
				entries = [entries]
			end
			entries.each do |entry|
				if entry.has_key?('author') and entry.has_key?('title') and entry.has_key?('content') and entry.has_key?('im:rating')
					id = entry['id']['label']
					author = ""
					if entry.has_key?('author')
						author = entry['author']['name']['label']
					end
					title = entry['title']['label']
					text = entry['content']['label']
					rating_text = entry['im:rating']['label']
					rating = rating_text.to_i
					if ((!id.nil?) and (!author.nil?) and (!title.nil?) and (!text.nil?) and (!rating_text.nil?))
						result.push(SourceFeeds.create_entry_for_review(id, author, title, text, rating, dest_translation_setting, review_id_seed, prior_entry_dates, new_entry_date))
					end
				end
			end
		end
		return result
	end
	
	def self.create_entry_for_review(id, author, title, text, rating, dest_translation_setting, review_id_seed, prior_entry_dates, new_entry_date)
		html_encoder = HTMLEntities.new

		sha256 = Digest::SHA256.new

		# I want to create a new entry id if the review changes at all.
		entry_id_data = "#{review_id_seed}-#{id}-#{author}-#{title}-#{text}"
		entry_id = sha256.hexdigest(entry_id_data)
		
		date = new_entry_date
		if !prior_entry_dates[entry_id].nil?
			date = prior_entry_dates[entry_id]
		end

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
		google_translate_url = "https://translate.google.com/#auto/#{dest_translation_setting}/#{CGI.escape(google_translate_text)}"

		html = "<p>#{escaped_text}</p><p>#{escaped_rating_text}</p><p><a href=\"#{google_translate_url}\">Google Translate</a></p>"
		return Entry.new(entry_id, author, date, title, html)
	end
	
	def self.create_error_entry_array( country_code, error_message )
		uuid = SecureRandom.uuid
		html_encoder = HTMLEntities.new
		error_message_html = html_encoder.encode(error_message)
		entry_html = "<p>#{error_message_html}</p>"
		
		result_array = Array.new
		result_array.push(Entry.new(uuid, "Feed Generator", "Unable to Retrieve Reviews for #{country_code}", entry_html))
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
