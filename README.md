
To get this project up and running you have to:

1. Create your own Twilio account (https://www.twilio.com/) and insert your
   Twilio Account ID, Auth Token, Live API Key and API Secret found in your
   programmable video console (https://www.twilio.com/console/video/dashboard)
   into the server/.env.ts placeholder. (If server/.env.ts isn't visible in
   your finder, press Command+Shift+Dot to reveal it and other hidden files.) If
   you choose to upgrade your free Twilio account, you can use my referral link
   to receive a $10 credit: www.twilio.com/referral/vSmWfp

2. Next, install the gems in server/Gemfile.

   To do so, first confirm Ruby's installed on your computer by running
   "ruby -v" in Terminal to view your system's Ruby version. If it's not yet
   installed you can do so using Homebrew. Install Homebrew by entering:

   /usr/bin/ruby -e \ "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)

   in Terminal. Then enter "brew update && brew install ruby" in Terminal to
   install Ruby.

   Next, confirm Xcode Command Line Tools (CLT) are installed by entering
   "xcode-select --install".

   Finally, after navigating to the server directory in Terminal,
   ex. cd ~/Path/To/Folder/Containing/TwilioVideoSample/server, run
   "bundle install" to install the necessary Gems.

3. Create a web server to host the contents of the server directory. I recommend
   using Heroku (https://www.heroku.com/) since its free tier offers enough
   capabilities to host your app for testing purposes. Follow these instructions
   to deploy this project's server app coded in Ruby onto your Heroku server:
   https://devcenter.heroku.com/articles/getting-started-with-ruby

   Once you've set up your server, insert its web URL into the Xcode project's
   baseURL placeholder in ViewController.swift

4. Install Cocoapods if it's not yet on your system by entering
   "sudo gem install cocoapods" then "pod setup --verbose" into your Mac's
   Terminal. Also in Terminal, navigate to the project's root directory,
   ex. cd ~/Path/To/Folder/Containing/TwilioVideoSample, containing the Xcode
   project and Podfile; then run "pod install" to install the TwilioVideo SDK
   as specified in the Podfile.
   
