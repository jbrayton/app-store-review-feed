class Entry

	def initialize( entry_id, author, date, title, html ) 
		@entry_id = entry_id
		@author = author
		@date = date
		@title = title
		@html = html
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
	
	def date
		return @date
	end

	def html
		return @html
	end

end