#!/usr/bin/env ruby
Bundler.require
require 'active_support/all'

url = 'http://myhorizon.solorient.com.au/Horizon/@@horizondap_uralla@@/atdis/1.0/applications.json'
feed = ATDIS::Feed.new(url)
applications = feed.applications(lodgement_date_start: Date.today, lodgement_date_end: 1.month.ago.to_date)

p applications
