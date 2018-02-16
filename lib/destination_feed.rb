require 'htmlentities'
require 'json'

require_relative 'review'

class DestinationFeed

	def self.write_review_feed( app_name, reviews, dest_file_path, dest_feed_url )
		json_structure = Hash.new
		json_structure['version'] = 'https://jsonfeed.org/version/1'
		json_structure['title'] = "App Store Reviews of #{app_name}"
		json_structure['home_page_url'] = 'https://itunesconnect.apple.com/'
		json_structure['feed_url'] = dest_feed_url
		items = Array.new
		
		item_url = "https://itunesconnect.apple.com/"
		
		html_encoder = HTMLEntities.new
		
		if (reviews.length == 0) 
			review_element = {'id' => 'placeholder', 'title' => '(placeholder)', 'content_html' => '<p>This is a placeholder, because some services will not allow you to subscribe to a JSON Feed that has an empty list of items.</p>', 'url' => item_url, 'date_modified' => DateTime.now.rfc3339 }
			items.push(review_element)
		end
		
		reviews = reviews.sort_by { |review| [ review.updated_datetime ] }.reverse

		reviews.each do |review|
			author_element = {'name' => review.author}
			rating_text = ""
			review.rating.times do
				rating_text += "★"
			end
			if ((review.rating > 0) and (review.rating < 5))
				num_empty_stars = 5 - review.rating
				num_empty_stars.times do
					rating_text += "☆"
				end
			end
			
			text = review.text
			escaped_text = html_encoder.encode(text, :decimal)
			
			# Convert double \n sequences to paragraph breaks, and single \n sequences 
			# to line breaks
			escaped_text = escaped_text.gsub("&#10;&#10;", "</p><p>")
			escaped_text = escaped_text.gsub("&#10;", "<br>")
			
			escaped_rating = html_encoder.encode(rating_text, :decimal)
			
			html = "<p>#{escaped_text}</p><p>#{escaped_rating}</p>"
			
			review_element = {'id' => review.review_id, 'title' => review.title, 'content_html' => html, 'url' => item_url, 'date_modified' => review.updated_datetime.rfc3339, 'author' => author_element}
			items.push(review_element)
		end
		json_structure['items'] = items
		
		tmp_file_path = "#{dest_file_path}.tmp"
		File.open(tmp_file_path,"w") do |f|
			f.write(JSON.pretty_generate(json_structure))
		end
		File.rename(tmp_file_path, dest_file_path)
	end

end