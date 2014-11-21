# This version fetches the Title, Url, and Page Views for Livewire articles
# published between 1.year.ago and 9.days.ago. It aggregates the page views
# over a week starting the day after it was published.

def get_details_from_parsely
  article_details = []
  failed_articles = {}

  base_url = "http://talkingpointsmemo.com/livewire/"

  articles = Article.where('article_type = ? AND published_at > ? AND published_at < ?', 'livewire', 1.year.ago, 9.days.ago) # attention to end date

  articles[0..1000].each do |a|
    begin
      pub_date = a.published_at
      day_after_pub = pub_date + 1.day
      ndays_after_pub = pub_date + 8.days

      days_since_day_after_pub = Date.today.mjd - day_after_pub.to_date.mjd
      days_since_ndays_after_pub = Date.today.mjd - ndays_after_pub.to_date.mjd

      article_url = base_url + a.slug

      res_for_day_after = make_request(article_url, days_since_day_after_pub)
      res_for_ndays_after = make_request(article_url, days_since_ndays_after_pub)

      details_for_day_after = parse_res(res_for_day_after)
      details_for_ndays_after = parse_res(res_for_ndays_after)

      article_detail = build_detail(details_for_day_after, details_for_ndays_after)

      p "article_detail #{article_detail}"
      article_details << article_detail
    rescue => error
      p "failed articles #{failed_articles}"
      failed_articles[a.slug] = error.message
      next
    end
  end

  article_details
end

def make_request(url, days)
  parsely_url = "http://api.parsely.com/v2/analytics/post/detail?apikey=talkingpointsmemo.com&secret=6D6Zf4WG22Xbu2M3o2sXSrtzCFVAWrF3GEZHR84dlx0&url=#{url}&days=#{days}"
  HTTParty.get(parsely_url)
end

def parse_res(res)
  if res.code == 200 && res["data"][0]
    details = {}
    details["title"] = res["data"][0]["title"]
    details["url"] = res["data"][0]["url"]
    details["page_views"] = res["data"][0]["_hits"]

    details
  end
end

def build_detail(details_for_day_after, details_for_ndays_after)
  article_detail = {}
  article_detail["title"] = details_for_day_after["title"]
  article_detail["url"] = details_for_day_after["url"]
  if details_for_ndays_after
    article_detail["page_views"] = details_for_day_after["page_views"] - details_for_ndays_after["page_views"]
  else
    article_detail["page_views"] = details_for_day_after["page_views"]
  end

  article_detail
end


require 'csv'

def save_as_csv(data)
  headers = data.first.keys

  CSV.open("/tmp/livewire_hits.csv", "w") do |csv|
    csv << headers
    data.each do |d|
      csv << headers.map { |h| d[h] }
    end
  end
end

article_details = get_details_from_parsely
save_as_csv(article_details)
