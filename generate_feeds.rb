require 'yaml'

require_relative 'lib/destination_feed'
require_relative 'lib/review'
require_relative 'lib/source_feeds'

config = YAML.load_file('config.yaml')
sleep_between = config['sleep_between']
max_days_back = config['max_days_back']

config['apps'].each do |app|
	itunes_app_id = app['itunes_app_id']
	app_name = app['app_name']
	dest_file_path = app['dest_file_path']
	dest_feed_url = app['dest_feed_url']
	
	print "Retrieving reviews for #{app_name}\n"
	reviews = SourceFeeds.retrieve_reviews(itunes_app_id, max_days_back, sleep_between)
	
	print("Writing #{reviews.count} reviews to #{dest_file_path}\n")
	DestinationFeed.write_review_feed(app_name, reviews, dest_file_path, dest_feed_url)
end

print("Done.\n")
