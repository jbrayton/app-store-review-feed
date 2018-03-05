class Entry

	def initialize( entry_id, author, title, html, updated_datetime ) 
		@entry_id = entry_id
		@author = author
		@title = title
		@html = html
		@updated_datetime = updated_datetime
	end
	
	def entry_id
		return @entry_id
	end

	def author
		return @author
	end

	def title
		return @title
	end

	def html
		return @html
	end

	def updated_datetime
		return @updated_datetime
	end

end