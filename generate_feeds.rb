require 'yaml'

require_relative 'lib/destination_feed'
require_relative 'lib/entry'
require_relative 'lib/source_feeds'

config = YAML.load_file('config.yaml')
sleep_between = config['sleep_between']

# The list of source_countries may be specified in config.yaml in order to speed up 
# testing.
source_countries = config['source_countries']
translation_target_language_code = config['translation_target_language_code']

config['apps'].each do |app|
	itunes_app_id = app['itunes_app_id']
	app_name = app['app_name']
	dest_file_path = app['dest_file_path']
	dest_feed_url = app['dest_feed_url']
	
	print "Retrieving reviews for #{app_name}\n"
	entries = SourceFeeds.retrieve_entries(itunes_app_id, sleep_between, translation_target_language_code, source_countries)
	
	print("Writing #{entries.count} entries to #{dest_file_path}\n")
	DestinationFeed.write_review_feed(app_name, entries, dest_file_path, dest_feed_url)
end

print("Done.\n")
