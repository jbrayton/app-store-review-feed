class Review

	def initialize( review_id, author, title, text, rating, updated_datetime ) 
		@review_id = review_id
		@author = author
		@title = title
		@text = text
		@rating = rating
		@updated_datetime = updated_datetime
	end
	
	def review_id
		return @review_id
	end

	def author
		return @author
	end

	def title
		return @title
	end

	def text
		return @text
	end

	def rating
		return @rating
	end

	def updated_datetime
		return @updated_datetime
	end

end