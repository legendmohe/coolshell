# encoding: UTF-8
require "net/http"
require 'fileutils'
require "uri"
require "json"
require 'digest'
require 'nokogiri'

Dir.chdir(File.dirname(__FILE__))

def hash_url(url)
	return Digest::MD5.hexdigest("#{url}")
end

def login(http, usr, pwd)
    path = "/login"
    data = "email=#{usr}&password=#{pwd}"
    headers = {
      'Content-Type' => 'application/x-www-form-urlencoded'
    }
	resp = http.post(path, data, headers)

    cookies_array = Array.new
    resp.get_fields('set-cookie').each { | cookie |
        cookies_array.push(cookie.split('; ')[0])
    }
    cookies = cookies_array.join('; ')
    puts resp.body

    return cookies
end

def getContent(http, cookies, id, page, pageSize)
    path = "/rssreader?method=FeedItem.getFeedItemList"
    data = "params={\"feedIdList\":\"#{id}\",\"page\":#{page},\"pageSize\":#{pageSize}}"
    headers = {
      'Cookie' => cookies,
      'Content-Type' => 'application/x-www-form-urlencoded'
    }
	resp = http.post(path, data, headers)
    return JSON.parse(resp.body)["data"]
end

def parseContent(items)

	res = []
	items.each { |item|
        puts "save: #{item["title"]}"
        
		buffer = []
		buffer.push("<div class = \"title\"><h1>#{item["title"]}</h1></div>\n")
		buffer.push("<div class = \"item\" id=\"wrapper\" class=\"typo typo-selection\">\n")
		buffer.push("<div class = \"author\">#{item["author"]}<div class = \"fetchtime\">#{item["time"]}</div></div>\n")
		doc = Nokogiri::HTML(item["description"])
		content = doImageCache("ImageCache", doc).to_html # image cache
		buffer.push("<div class = \"content\">#{content}</div>\n")
		buffer.push("<hr />")
		buffer.push("<div class = \"link\">source : <a href=\"#{item["url"]}\">#{item["url"]}</a></div>\n")
		buffer.push("</div>\n")
		res.push({'time' => item["time"], 'title' => item["title"], 'content' => buffer.join})
	}
	
	return res
end

def doImageCache(title, doc)
	path = "./res/#{title}_file/"
	FileUtils.mkpath(path) unless File.exists?(path)
	
	imgEntities = []
	
	doc.css("img").each do |img| 
		uri = URI.parse(img["src"])
		filename = hash_url("#{uri.to_s}") # hash url for save files
		img["src"] = "./#{title}_file/" + filename
		
        #begin
        #    Net::HTTP.start(uri.hostname) { |http|
        #        resp = http.get(uri.to_s)
        #        File.open(path + filename, "wb") { |file|
        #            file.write(resp.body)
        #            print "."
        #        }
        #    }
        #rescue
        #    puts "error: \n    #{uri}"
        #end

		imgEntities << {'uri'=>uri, 'hash'=>filename}
	end

	imgEntities.each_slice(6).to_a.each{ |group|
		threads = []
	
		group.each {|entity|
			threads << Thread.new { 
				begin
					uri = entity['uri']
					filename = entity['hash']
					Net::HTTP.start(uri.hostname) { |http|
						resp = http.get(uri.to_s)
						File.open(path + filename, "wb") { |file|
							file.write(resp.body)
							print "."
						}
					}
				rescue
					puts "error: \n    #{uri}"
				end
			}
		}
		
		threads.each { |t| t.join }
	}

    print "\n"

	return doc
end

def saveToFiles(items)
	template = File.open("template.html", "r:UTF-8").read() # for Windows
	category = ["<div class=\"category\">\n"]
	items.each{ |item| 
		filename = "#{item["time"]}-#{item["title"].gsub(/[\x00\/\\:\*\?\"<>\|]/, "_")}.html"
        File.open("res/#{filename}", 'w') { |file| 
            file.write(template.sub("<!-- this is template-->", item['content']).sub!("<!-- this is title-->", item["title"])) 
        }
		
		category.push("<p><a href=\"#{filename}\">#{item["time"]}-#{item["title"]}</a></p>\n")
    }
	category.push("</div>") 
	
	template = File.open("category_template.html", "r:UTF-8").read()
	File.open("res/目录.html", 'w') { |file| 
		file.write(template.gsub!("<!-- this is template-->", category.join)) 
	}
end

feedId = "8086"
usr = "legendmohe@126.com"
pwd = "891010"
pagesize = "30"
items = []

http = Net::HTTP.new('xianguo.com', 80)
cookies = login(http, usr, pwd)
0.upto(10) do |page|
    jContent = getContent(http, cookies, feedId, page, pagesize)
    items += parseContent(jContent['list'])

    puts "current: \
        #{jContent["pageSize"]*jContent["page"] + jContent["currentPageSize"]} \
        / \
        #{jContent["total"]}"

    break if jContent["page"] >= jContent["totalPage"]
end

saveToFiles(items)
