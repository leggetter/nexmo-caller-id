require 'sinatra'
require 'pony'
require_relative 'nexmo.rb'

class NexmoApp < Sinatra::Base

	get '/' do
		erb :phone_form
	end

	post '/lookup' do
		@insight = Nexmo.lookup(params["phone"], "#{request.base_url}/nexmo_insights?email=#{params["email"]}")
		erb	:phone_lookup
	end

	post '/nexmo_insights' do
		phone_info = request.body.read
		email_insight(phone_info, params[:email])
		status 200
	end

	def email_insight(phone_info, email)
		begin
			Pony.mail(:to => email,
			:from => YOUR_EMAIL,
			:subject => "Nexmo insight for #{phone_info["national_format_number"]}", 
			:body => phone_info)
		rescue Exception => e
			puts e
		end
	end

end

NexmoApp.run!