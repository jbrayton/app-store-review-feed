class Entry

	def initialize( entry_id, author, title, html ) 
		@entry_id = entry_id
		@author = author
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

	def html
		return @html
	end

end