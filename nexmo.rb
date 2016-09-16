require "net/http"
require "uri"

class Nexmo

	def self.lookup(number, callback_url)
		uri = URI.parse("https://api.nexmo.com/ni/advanced/async/json")
		params = {
		  'api_key' => YOUR_API_KEY,
		  'api_secret' => YOUR_API_SECRET,
		  'number' => number,
		  'callback' => callback_url
		  }

		response = Net::HTTP.post_form(uri, params)
		puts response.body
		response.body
	end
end