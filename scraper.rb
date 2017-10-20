require 'scraperwiki'
require 'mechanize'

class Hash
  def has_blank?
    self.values.any?{|v| v.nil? || v.length == 0}
  end
end

case ENV['MORPH_PERIOD']
  when 'lastmonth'
  	period = "lastmonth"
  	xml_url = 'http://myhorizon.solorient.com.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+MONTH(Applications.Lodged-1)%3DSystemSettings.SearchMonthPrevious+AND+YEAR(Applications.Lodged)%3DSystemSettings.SearchYear+AND+Applications.CanDisclose%3D%27Yes%27+ORDER+BY+Applications.AppYear+DESC%2CApplications.AppNumber+DESC&query_name=SubmittedLastMonth&take=50&skip=0&start=0&pageSize=500'
  when 'thismonth'
  	period = "thismonth"
  	xml_url = 'http://myhorizon.solorient.com.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+MONTH(Applications.Lodged)%3DCURRENT_MONTH+AND+YEAR(Applications.Lodged)%3DCURRENT_YEAR+ORDER+BY+Applications.AppYear+DESC%2CApplications.AppNumber+DESC&query_name=SubmittedThisMonth&take=50&skip=0&start=0&pageSize=500'
  else
    if (ENV['MORPH_PERIOD'].to_i >= 2000)
      period = ENV['MORPH_PERIOD'].to_i.to_s
      xml_url = 'http://myhorizon.solorient.com.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+Applications.AppYear%3D1961+AND+Applications.CanDisclose%3D%27Yes%27+ORDER+BY+Applications.Lodged+DESC%2CApplications.AppYear+DESC%2CApplications.AppNumber+DESC&query_name=Applications_List_Search&take=50&skip=0&start=0&pageSize=500'.gsub("1961", ENV['MORPH_PERIOD'].to_i.to_s)
    else
      period = "thisweek"
  	  xml_url = 'http://myhorizon.solorient.com.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+WEEK(Applications.Lodged)%3DCURRENT_WEEK-1+AND+YEAR(Applications.Lodged)%3DCURRENT_YEAR+AND+Applications.CanDisclose%3D%27Yes%27+ORDER+BY+Applications.AppYear+DESC%2CApplications.AppNumber+DESC&query_name=SubmittedThisWeek&take=50&skip=0&start=0&pageSize=500'
  	end
end
puts "Scraping for " + period + ", changable via MORPH_PERIOD variable"

info_url = 'http://myhorizon.solorient.com.au/Horizon/logonGuest.aw?domain=horizondap_uralla'
comment_url = 'mailto:council@uralla.nsw.gov.au'

agent = Mechanize.new
page = agent.get(info_url)
page = agent.get(xml_url)

xml = Nokogiri::XML(page.body)

xml.xpath('//run_query_action_return/run_query_action_success/dataset/row').each do |app|
  record = {
      'council_reference' => app.xpath('AccountNumber').attribute('org_value').text.length > 0 ? app.xpath('AccountNumber').attribute('org_value').text.strip : nil,
      'address'           => app.xpath('Property').attribute('org_value').text.length > 0 ? (app.xpath('Property').attribute('org_value').text + ' NSW').strip : nil,
      'description'       => app.xpath('Description').attribute('org_value').text.length > 0 ? app.xpath('Description').attribute('org_value').text.strip : nil,
      'info_url'          => info_url,
      'comment_url'       => comment_url,
      'date_scraped'      => Date.today.to_s,
      'date_received'     => DateTime.parse(app.xpath('Lodged').attribute('org_value').text).to_date.to_s
  };

  # Saving data to DB if all value filled
  unless record.has_blank?
    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      puts "Saving record " + record['council_reference'] + ", " + record['address']
#       puts record
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  else
    puts "Something not right here: #{record}"
  end

end
