require 'htmlentities'
require 'json'

require_relative 'entry'

class DestinationFeed

	def self.write_review_feed( app_name, entries, dest_file_path, dest_feed_url )
		json_structure = Hash.new
		json_structure['version'] = 'https://jsonfeed.org/version/1'
		json_structure['title'] = "App Store Reviews of #{app_name}"
		json_structure['home_page_url'] = 'https://itunesconnect.apple.com/'
		json_structure['feed_url'] = dest_feed_url
		items = Array.new
		
		item_url = "https://itunesconnect.apple.com/"
		
		html_encoder = HTMLEntities.new
		
		if (entries.length == 0) 
			placeholder_date_string = '2018-01-01T00:00:00+00:00'
			entry_element = {'id' => 'placeholder', 'title' => '(placeholder)', 'content_html' => '<p>This is a placeholder, because some services will not allow you to subscribe to a JSON Feed that has an empty list of items.</p>', 'url' => item_url }
			items.push(entry_element)
		end
		
		entries.each do |entry|
			author_element = {'name' => entry.author}
			entry_element = {'id' => entry.entry_id, 'title' => entry.title, 'content_html' => entry.html, 'url' => item_url, 'author' => author_element, 'date_published' => entry.date}
			items.push(entry_element)
		end
		json_structure['items'] = items
		
		tmp_file_path = "#{dest_file_path}.tmp"
		File.open(tmp_file_path,"w") do |f|
			f.write(JSON.pretty_generate(json_structure))
		end
		File.rename(tmp_file_path, dest_file_path)
	end

end