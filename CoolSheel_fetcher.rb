# encoding: UTF-8
require "net/http"
require "uri"
require "json"
#require 'nokogiri'

Dir.chdir(File.dirname(__FILE__))

def doGetContent(fetchUrl, beginID, id)

	uri = URI(fetchUrl + '?begin=' + beginID + '&id=' + id)
    json = JSON.parse(Net::HTTP.get(uri))	
	return {'hasNext' => json['hasnext'], 'entries' => json['entries']}
end

def parseContent(items)

	res = []
	id = ''
	items.each { |item|
		buffer = []
		buffer.push("<div class = \"title\"><h1>#{item["title"]}</h1></div>\n")
		buffer.push("<div class = \"item\" id=\"wrapper\" class=\"typo typo-selection\">\n")
		buffer.push("<div class = \"author\">#{item["author"]}<div class = \"fetchtime\">#{item["fetchtime"]}</div></div>\n")
		buffer.push("<div class = \"content\">#{item["content"]}</div>\n")
		buffer.push("<hr />")
		buffer.push("<div class = \"link\">source : <a href=\"#{item["link"]}\">#{item["link"]}</a></div>\n")
		buffer.push("</div>\n")
		res.push({'time' => item["fetchtime"], 'title' => item["title"], 'content' => buffer.join})
		id = item['id']
	}
	
	return {'res' => res, 'beginID' => id}
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

feedID = '9324758'
fetchURL = 'http://9.douban.com/reader/j_read_blog_content'
beginID = ''
items = []
3.times do
	contentHash = doGetContent(fetchURL, beginID, feedID)
	itemsHash = parseContent(contentHash['entries'])
	break unless contentHash['hasNext']
	puts "downloaded : #{itemsHash['res'].size} BeginID: #{itemsHash['beginID']}"
	beginID = itemsHash['beginID']
	items += itemsHash['res']
end

saveToFiles(items)


