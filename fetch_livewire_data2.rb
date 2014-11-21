# This version fetches the Title, Url, Pub Date and Page Views for Livewire
# articles published between 1.year.ago and 9.days.ago. Page views are collected
# for each day over a week since an article's publication.

def get_details_from_parsely
  article_details = []
  failed_articles = {}

  base_url = "http://talkingpointsmemo.com/livewire/"

  articles = Article.where('article_type = ? AND published_at > ? AND published_at < ?', 'livewire', 1.year.ago, 9.days.ago) # attention to end date

  articles.each_with_index do |a, idx|
    begin
      pub_date = a.published_at
      days_since_pub = Date.today.mjd - pub_date.to_date.mjd
      article_url = base_url + a.slug
      responses = []

      7.times do
        responses << make_request(article_url, days_since_pub)
        days_since_pub -= 1
      end

      details = []
      responses.each do |r|
        details << parse_res(r)
      end

      meta_details = get_meta(details.first)

      page_view_details = {}
      details.each_with_index do |d, idx|
        page_view_details["day_#{idx}"] = get_page_views(d)
      end

      p "article index #{idx}"
      article_details << meta_details.merge(page_view_details)
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
    details["page_views"] = res["data"][0]["_hits"]
    details["url"] = res["data"][0]["url"]
    details["pub_date"] = res["data"][0]["pub_date"]

    details
  end
end

def get_meta(data)
  article = {}
  article["title"] = data["title"]
  article["url"] = data["url"]
  article["pub_date"] = data["pub_date"]

  article
end

def get_page_views(data)
  data ? data["page_views"] : 0
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
