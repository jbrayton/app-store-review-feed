# App Store Review Feed

App Store customer reviews are available via Atom feeds, but using those feeds directly has some drawbacks:

* In order to get all feeds across all countries, you need to subscribe to 28 different feeds for each app.
* The feed names do not include the name of the app.
* The feeds include the star rating, but not in a manner that a typical news reader or aggregation service will incorporate.

This script generates JSON feeds based on those Atom feeds, addressing these weaknesses:

* The script will generate one feed per app.
* The feed name will be “App Store Reviews of [PRODUCT_NAME]”
* The feeds will include the star rating in the body of the feed entries.

## Installation

The script requires Ruby 2.3 or later and Bundler 1.11.2 or later. It is intended to run on a Linux or UNIX system that has a web server. To set up the script, do the following:

1. Check out the repository.
2. cd into the directory.
3. Copy “config.yaml.template” to “config.yaml”.
4. Create a directory inside your web server's root directory for the feeds. Ensure that you (or the user account that will run the script) has write access to that directory.
5. Edit the config.yaml file. At minimum you will need to customize the list of apps for which you want feeds.
6. Install dependencies by entering “bundle install”. (I had to jump through some hoops to get the nokogiri dependency installed. Your mileage may vary.)
7. To run the script, type “bundle exec ruby generate_feeds.rb”.
8. To configure the script to run automatically, add a crontab entry such as the following

````
2 */4 * * * cd /home/myaccount/app-store-review-feed && /usr/bin/bundle exec ruby generate_feeds.rb >/dev/null 2>&1
````

This will tell cron to run the script every four hours, at two minutes past the hour. You will want to customize that. You will also need to replace “/home/myaccount/app-store-review-feed” with the appropriate directory.

After you have executed the script at least once, you can subscribe to the resulting JSON feeds via your news reader or aggregation service of choice.

## Notes

* This script will only retrieve the first page of each feed. It will combine all reviews into a one-page feed. This might be inadequate for an app with a very high volume of reviews.
* Not every news reader or aggregation service supports JSON feed.
* If the script encounters any error, it will stop. You may want to configure your monitoring to ensure that the JSON feed file for the last app in your configuration file was generated recently.
* By default the script sleeps for two seconds between every HTTPS request to Apple. This makes the script take just over a minute per app.
* There was some guesswork involved in reducing the [list of all storefront country codes](https://affiliate.itunes.apple.com/resources/documentation/linking-to-the-itunes-music-store/) to the 28 unique feed URLs. I think I got this right, but I cannot be certain of this for countries where none of my apps have reviews.

Pull requests welcome.
