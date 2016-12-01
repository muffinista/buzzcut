#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"

require 'open-uri'
require 'nokogiri'
require 'addressable'
require 'json'


TARGET_WORD_COUNT = 120000
SLEEP_RATE = 1.0
OUTPUT_COUNT = 50000

def read_url(url, force=false)
  cachename = Digest::SHA256.hexdigest(url)
  puts cachename

  dest = "cache/#{cachename}"
    
  if File.exist?(dest) && force != true
    return File.read(dest)
  end

  puts "load #{url}"
  text = open(url) do |f|
    f.read
  end rescue nil

  return nil if text.nil?

  File.open(dest, 'w') {|f| f.write(text) }

  text
end

def wrap(s, width=40)
  s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
end

REMOVABLE_ELEMENTS = [
  "//script",
  "//style",
  "//*[@style='display:none;']",
  "//*[@id='toc']",
  "//*[@id='respond']",
  "//*[@id='social-actions']",
  "//*[@id='nav-signin']",
  "//*[@class='mw-editsection']",
  "//*[@class='user-bylines']",
  "//*[@class='user-bio']",
  "//*[@class='buzz_superlist_item']",
  "//*[@class='views-tags']",
  "//ol",
  "//*[@id='mw-navigation']",
  "//*[@id='catlinks']",
  "//*[@id='footer']",
  "//div[@class='navbox']",
  "//*[@class='effect-fade-in-scale']"
]

def guts_of_page(html)
  doc = Nokogiri::HTML(html)
  REMOVABLE_ELEMENTS.each { |p|
    doc.xpath(p).remove
  }

  el = nil
  doc.css('body > *').each { |e|
    if el.nil? || e.text.length > el.text.length
      el = e
    end
  }
  
  el
end

def wordcount
  @data.join("\n").split.size
end

require 'pry'

#
# split a chunk of text into `count` arrays representing columns of text
#
def chunk_text(t, count = 4, width = 120)
  lines = wrap(t, width).split(/\n/)
#  tmp = lines.map { |x|
#    x.split(/[^[[:word:]]]+/)
#  }
  tmp = lines.map { |x|
    #words = x.split(/[^[[:word:]]]+/)
    words = x.split(/((?<=[a-z0-9)][.?!])|(?<=[a-z0-9][.?!]"))\s+(?="?[A-Z])/)
    next if words.count == 0
    length = (words.count / count).to_i + 1

    words.each_slice(length).to_a
  }.compact

  #result = [[], [], []]
  result = Array.new(4) { [] }
  #result = [[], [], [], []]
  #puts result.inspect

  tmp.each { |row|
    #puts "ROW #{row.inspect}"
    row.each_with_index { |r, i|
      #puts "#{i} -- #{r.inspect}"
      result[i].push(r.join(" "))
      #puts result.inspect
    }
  }

  result
end

@data = []
url = ARGV.last
#puts url

@urls = [
  url
]


@visited_urls = []

while wordcount < TARGET_WORD_COUNT && ! @urls.empty?
  @urls = @urls.shuffle
  url = @urls.shift
  puts url

  @visited_urls << url
  
  data = read_url(url)
  next if data.nil?
  el = guts_of_page(data)

  text = el.xpath("//text()").to_s
  links = el.css('a').map { |l|
    u = Addressable::URI.join( url, l['href'].to_s ).to_s.gsub(/#.+/, "") rescue nil
    u
  }.compact.uniq.reject { |l|
    @visited_urls.include?(l) || l !~ /buzzfeed.com/ || l =~ /.png/ ||
      l =~ /.gif/ || l =~ /.jpg/ || l =~ /.jpeg/      
      
  }

  @data << text
  
  @urls = (@urls + links).flatten
  
  puts "WORD COUNT: #{wordcount}"
  
  sleep SLEEP_RATE
end

# now we have our raw data

puts @data.count


@data = @data.map { |chunk| chunk_text(chunk) }

#binding.pry

#@data.each { |chunk|
#  puts "!!! #{chunk}"
#  puts chunk_text(chunk).inspect
#}


@output = ""
output_count = 0


while output_count < OUTPUT_COUNT
  index1 = rand(0...@data.length)
  index2 = rand(0...@data[index1].length)

  #puts @data[index1][index2].inspect
  
  chunk = @data.sample.sample.shift
#  puts chunk
  next if chunk.nil?

  @output << chunk
  @output << " "
  output_count = @output.split.size
end


puts "=================================="
puts @visited_urls.inspect
puts @output

File.write("output.txt", @output)
File.write("urls.json", JSON.generate(@visited_urls))
