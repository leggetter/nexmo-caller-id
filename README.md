# How to make your own Caller ID with Number Insight API from Nexmo using Ruby and Sinatra

The [Number Insight Advanced Async API](https://docs.nexmo.com/number-insight/advanced-async)  is a powerful API that looks up roaming information about a phone number on top of the info already returned by the [Number Insight Advanced Standard API](https://docs.nexmo.com/number-insight/standard).

The Number Insight API can lookup:
- A phone number's country name, code, & prefix
- A phone number's carrier
- A phone number's network type (landline/cellular)
- If a phone number is valid
- If a phone number is reachable

...And much more info!

While there are many uses for this API, this tutorial will cover building our own caller id. That's right, we're kicking it old school with this tutorial! Make no mistakes though, the tech we're working with is anything but old.

So let's say you have a database of phone numbers and you want to know as much as you can about the phone number. We're going to build a web app that will look up insights into the number and email you the results.

We're going to build this web app using Ruby and [Sinatra](http://www.sinatrarb.com/). We'll make two pages. The first page will have a form where you can enter a phone number and the email address the insights should be sent to. The second page will have the immediate results from the Number Insights API. We'll need to build three endpoints and a `post` call in total. A `get` for the index page for the form. A `post` endpoint to send the form data back to our Sinatra server. We'll then take that form data and `post` that to Nexmo. We'll also need to give Nexmo a url to receive the `post` from the Number Insights API.

If you'd like to skip to the finished project you can check out the end result of this tutorial [on Github](https://github.com/ChrisGuzman/nexmo-caller-id).

---

## Getting started

What do you need to get started? Well this is a ruby tutorial so you should know a bit of that. We're gonna build this web app in Sinatra so you should have some exposure to that. We'll also need to expose the web app online and for that we're going to use [ngrok](https://ngrok.com/).

Don't forget you'll need your free [Nexmo account](https://dashboard.nexmo.com/sign-up) for your API Key and API Secret.

And with that let's get started!

---

## Sinatra takes the stage

Let's set up our sinatra app. First, make sure you have the correct gems installed. I like to use [shotgun](https://github.com/rtomayko/shotgun) because it reloads the app whenever we make changes to the file.

Make sure you also have the `pony` gem installed. It will help us send email to the user. I'll explain more about it later in the tutorial.

```bash
$ gem install sinatra
$ gem install shotgun
$ gem install pony
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

Now we can view the app in our browser by entering `localhost:4567` into the url bar. `localhost:4567` is the default port that shotgun runs our sinatra app on but your port may vary. Make sure you go to the correct url.

![form screenshot](http://imgur.com/fNGadxl.png)

Awesome!

---

## Taking it to the next level with Nexmo

We need to add a lookup method that will actually hit the Advanced Insights API and return the info we need.

The `Net::HTTP` class and the `URI` module should be included in your distribution of ruby. You won't need to install any gems to use them.

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
		#print it out so we can view the response in the console
		puts response.body
		response.body
	end
end
```
Don't forget to replace `YOUR_API_KEY` and `YOUR_API_SECRET` with the credentials from your account. You can find them in your [account settings](https://dashboard.nexmo.com/settings).

As you can see we need to give the API the phone number we want looked up as well as the url that the webhook should return the data to. This is an async API after all!

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
		#if we don't return a 200 success code, Nexmo will continue to try to hit our endpoint
		status 200
	end
...
```

```html
#demo/views/phone_lookup.erb
<pre> <%= @insight %> </pre>
```

Now, when a user submits the form we'll pass the phone number to the Advance Insights API and redirect the user to a page that shows the immediate info that the API returns.

Remember, we're working with the Async API, so we need to give the API a url for the webhook to return to when Nexmo is done processing the request. That's what we're doing here:

 `Nexmo.lookup(params["phone"], "#{request.base_url}/nexmo_insights?email=#{params["email"]}")`

 The second argument in the `Nexmo.lookup` method is the url we're generating. We're using `request.base_url` so that when we connect tunnel through ngrok, the dynamic base_url will be sent. The query parameter `?email=#{params["email"]}"` is present so that when the insight request from Nexmo is processed and returned to our server, we know which email to send the results to. Our final callback url should look something like: `http://fe894a45.ngrok.io/nexmo_insights?email=test@test.com`

Before we test out our server, we need to tunnel through ngrok. If you don't have ngrok installed, you should install it via [homebrew](http://brew.sh/) or download it from the [ngrok site](https://ngrok.com/).

```bash
#shotgun defaults to port 4567, but change this to whatever port your server is on
$ ngrok http 4567
```

---

## Let's start the show

Now that we've exposed our web app to the internet let's implement the method that will email the results of the Advanced Insights call to the user.

```ruby
#demo/app.rb
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

Using the [`Pony` gem](https://github.com/benprew/pony) we can send an email from our web app. If you're having issues sending or receiving emails from your app look into using [SendGrid](https://larry-price.com/blog/2014/07/08/sending-emails-with-pony-and-sendgrid) or use [SMTP with Gmail](http://deonheyns.com/posts/a-journey-on-sending-emails-the-pony-gem/)

---

## Putting it all together

Now that we've built our Sinatra app, we can visit the url that ngrok gave us. It should look something like `http://fe894a45.ngrok.io/`

We can enter the phone number to look up and pass in the email we want it sent to.

![home page](http://imgur.com/MzpKQyq.png)

![second screen](http://i.imgur.com/A6M4xns.png)

![successful email](http://imgur.com/2yUEpWf.png)

Congrats! You've just implemented the Number Insight Advanced Async API using ruby and Sinatra.

You can view the return parameters for the data that has been returned from the Advanced Number Insights API in the [Nexmo docs](https://docs.nexmo.com/number-insight/advanced-async/api-reference#ni-return-parameters). Feel free to parse the data and only display or email the parts that your users will need.

## Encore!

That's not all to the Nexmo API. If you want to explore more I would recommend checking out the following resources:

- The finished repo for this project can be found [on Github](https://github.com/ChrisGuzman/nexmo-caller-id):

- If you don't need as much info from a phone number and don't want to implement the webhook callback logic you can use the other number insight endpoints:

	- https://docs.nexmo.com/number-insight/basic
	- https://docs.nexmo.com/number-insight/standard
	- https://docs.nexmo.com/number-insight/advanced


- You should also star and watch the [Nexmo Client Library for Ruby](https://github.com/Nexmo/nexmo-ruby) on Github for more updates.

- If you'd like to go a step further you can call users back using the [Text to Speech API](https://docs.nexmo.com/voice/text-to-speech)
