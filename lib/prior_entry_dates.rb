require 'json'
require_relative 'entry'

class PriorEntryDates

	def self.get_prior_entry_dates( dest_file_path )
		result = Hash.new
		if File.exist?(dest_file_path)
			json = File.read(dest_file_path)
			json_obj = JSON.parse(json)
			entries = json_obj["items"]
			if !entries.nil?
				entries.each do |entry|
					if !entry["date_published"].nil?
						result[entry["id"]] = entry["date_published"]
					end
				end
			end
		end
		return result
	end

end