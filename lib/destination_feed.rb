require 'json'

require_relative 'review'

class DestinationFeed

	def self.write_review_feed( itunes_app_id, app_name, reviews, dest_file_path, dest_feed_url )
		json_structure = Hash.new
		json_structure['version'] = 'https://jsonfeed.org/version/1'
		json_structure['title'] = "App Store Reviews of #{app_name}"
		json_structure['home_page_url'] = 'https://itunesconnect.apple.com/'
		json_structure['feed_url'] = dest_feed_url
		items = Array.new
		
		item_url = "https://itunesconnect.apple.com/WebObjects/iTunesConnect.woa/ra/ng/app/#{itunes_app_id}/activity/ios/ratingsResponses"
		
		reviews.each do |review|
			author_element = {'name' => review.author}
			text = review.text + "\n\n"
			review.rating.times do
				text += "★"
			end
			if ((review.rating > 0) and (review.rating < 5))
				num_empty_stars = 5 - review.rating
				num_empty_stars.times do
					text += "☆"
				end
			end
			review_element = {'id' => review.review_id, 'title' => review.title, 'content_text' => text, 'url' => item_url, 'date_modified' => review.updated_datetime.rfc3339, 'author' => author_element}
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