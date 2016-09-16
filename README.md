# How to make your own Caller ID with Number Insight API from Nexmo using Ruby and Sinatra

I want introduce you to the [Number Insight Advanced Async API](https://docs.nexmo.com/number-insight/advanced-async). It's a powerful API that looks up roaming information about a phone number on top of the info already returned by the [Number Insight Advanced Standard API](https://docs.nexmo.com/number-insight/standard).

The Number Insight API can lookup:
- A phone number's country name, code, prefix
- A phone number's carrier
- A phone number's network type (landline/cellular)
- If a phone number is valid
- If a phone number is reachable
...And many other insights!

While there are many uses for this API, this tutorial will cover building our own caller id. That's right we're kicking it old school with this tutorial! Make no mistakes though, the tech we're working with is anything but old.

So let's say you database of phone numbers. You want to know as much as you can about the phone number. We're going to build a web app that will look up insights into the number and email you the results.

We're going to build this web app using Ruby and [Sinatra](http://www.sinatrarb.com/). We'll make two pages. The first will have a form where you can enter a phone number and the email address the insights should be sent to. The second page will have the immediate results from the Number Insights API. We'll need to build three insights in total. An `index` page for the form. A `post` endpoint to send the form data back to our Sinatra server. We'll then take that form data and `post` that to Nexmo. We'll also need to give Nexmo a url to post back the data from the Number Insights API. So we'll need the third endpoint to receive a `post` from Nexmo.

---

## Getting started

So what do you need to get started? Well this is a ruby tutorial so you should know a bit of that. We're gonna build this web app in Sinatra so you should have some exposure to that. We'll also need to expose the web app online so we're going to use [ngrok](https://ngrok.com/).

Don't forget you'll need your free [Nexmo account](https://dashboard.nexmo.com/sign-up) for your API Key and API Secret.

And with that let's get started!

---

## Sinatra takes the stage

Let's set up our sinatra app. First, make sure you have the correct gems installed.

```bash
$ gem install sinatra
$ gem install shotgun
```

Our first page will have the form where users can enter the phone number and the email they want the info sent to.

```ruby
# demo/app.rb
require 'sinatra'

class NexmoApp < Sinatra::Base

	get '/' do
		erb :phone_form
	end
end

NexmoApp.run!
```

```html
<!-- demo/views/phone_form.erb -->
<form method="POST" action="/lookup">
	<p>Lookup a phone number</p>
  	<p>Phone Number:<input type="tel" name="phone" required></p>
  	<p>Email to send the info to:<input type="email" name="email" required></p>
  <input type="submit">
</form>
```

Great! Now let's startup the server and see what we've got.

```bash
$ cd demo/
$ shotgun app.rb
```

![form](http://imgur.com/fNGadxl.png)

Awesome!

---

## Taking it to the next level with Nexmo

```ruby
#demo/nexmo.rb
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
		#log it out so we can see what the response was
		puts response.body
		response.body
	end
end
```
Don't forget to replace `YOUR_API_KEY` and `YOUR_API_SECRET` with the credentials from your account. You can find them in your [account settings](https://dashboard.nexmo.com/settings).

```ruby
#demo/app.rb

#don't forget to add this since we added a new file
require_relative 'nexmo.rb'
...	
	post '/lookup' do
		@insight = Nexmo.lookup(params["phone"], "#{request.base_url}/nexmo_insights?email=#{params["email"]}")
		erb	:phone_lookup
	end
	post '/nexmo_insights' do
		phone_info = request.body.read
		puts phone_info
		#TODO: implement method to email the results to the user
		email_insight(phone_info, params[:email])
		#need to return a 200 success code to Nexmo when the webhook hits our endpoint
		status 200
	end
...
```

```html
<pre> <%= @insight %> </pre>
```

Now, when a user submits the form we'll pass the phone the the Advance Insights API and redirect the user to a page that shows the immediate info that the API returns.

Remember, we're working with the Async API, so we need to give the API a url for the webhook to return to when Nexmo is done processing the request. That's what we're doing here `Nexmo.lookup(params["phone"], "#{request.base_url}/nexmo_insights?email=#{params["email"]}")` The second argument in that method is the url we're generating. We're using `request.base_url` so that when we connect tunnel through ngrok, the dynamic base_url will be sent. The query parameter `?email=#{params["email"]}"` is present so that when the insight request from Nexmo is processed and returned to our server, we know which email to send the results to. Our final callback url should look something like: `http://fe894a45.ngrok.io/nexmo_insights?email=test@test.com`

Now before we test out our server, we need to tunnel through ngrok. If you don't have ngrok installed, you should install it via [homebrew](http://brew.sh/) or download it from the [ngrok site](https://ngrok.com/).

```bash
#shotgun defaults to port 4567, but change this to whatever port your server is on
$ ngrok http 4567
```

---

## Let's start the show

Now that we've exposed our web app to the internet let's implement the method that will email the results of the Advanced Insights call to the user. 

```ruby
#We need to require the pony gem so we can use it
require 'pony'

...
	def email_insight(phone_info, email)
		begin
			Pony.mail(
				:to => email, 
				:via => :sendmail,
				:from => 'youremail@test.com', 
				:subject => "Nexmo insight for #{phone_info["national_format_number"]}",
				:headers => { 'Content-Type' => "text/html" },
				:body => phone_info)
			rescue Exception => e
				puts e
			end
	end
```

Using the [`Pony` gem](https://github.com/benprew/pony) we can send an email from our web app. If you're having issues sending or receiving emails form your app look into using [SendGrid](https://larry-price.com/blog/2014/07/08/sending-emails-with-pony-and-sendgrid) or use [SMTP with Gmail](http://deonheyns.com/posts/a-journey-on-sending-emails-the-pony-gem/)

---

## Putting it all together

Now that we've built our Sinatra app, we can visit the url that ngrok gave us. It should look something like `http://fe894a45.ngrok.io/` 

We can enter the phone number to look up and pass in the email we want it sent to. 

![home page](http://imgur.com/MzpKQyq.png)

![second screen](http://i.imgur.com/A6M4xns.png)

![successful email](http://imgur.com/2yUEpWf.png)

Congrats! You've just implemented the Number Insight Advanced Async API using ruby and Sinatra.

## Sinatra's Encore

That's not all to the Nexmo API. If you want to explore more I would recommend checking out the following resources.

The finished repo for this project can be found here: 

If don't need as much info from a phone number and don't want to implement the webhook callback logic you can use the other number insight endpoints:
- https://docs.nexmo.com/number-insight/basic
- https://docs.nexmo.com/number-insight/standard
- https://docs.nexmo.com/number-insight/advanced

You should also star and watch the [Nexmo Client Library for Ruby](https://github.com/Nexmo/nexmo-ruby) on github for more updates.

If you'd like to go a step further you can call users back using the [Text to Speech API](https://docs.nexmo.com/voice/text-to-speech)

> Written with [StackEdit](https://stackedit.io/).
