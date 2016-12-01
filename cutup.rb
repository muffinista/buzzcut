#!/usr/bin/env ruby
# coding: utf-8

require "rubygems"
require "bundler/setup"

require 'open-uri'
require 'nokogiri'
require 'addressable'
require 'json'
require 'pry'


# how many words to try and load before generating output
TARGET_WORD_COUNT = 120000

# how many words to we want to generate?
OUTPUT_COUNT = 50000

# how long to sleep between HTTP requests?
SLEEP_RATE = 1.0

# here's a list of xpath lookups for elements we
# want to remove from HTML before parsing. this is a way
# to remove menus, footers, other junk that we don't want in the
# output.

REMOVABLE_ELEMENTS = [
  "//script",
  "//style",
  "//*[@style='display:none;']",
  "//*[@id='toc']",
  "//*[@id='respond']",
  "//*[@id='social-actions']",
  "//*[@id='nav-signin']",
  "//ol",
  "//*[@id='mw-navigation']",
  "//*[@id='catlinks']",
  "//*[@id='footer']",
  "//div[contains(@class, 'navbox')]",
  "//*[contains(@class, 'mw-editsection')]",
  "//*[contains(@class, 'user-bylines')]",
  "//*[contains(@class, 'user-bio')]",
  "//*[contains(@class, 'buzz_superlist_item')]",
  "//*[contains(@class, 'views-tags')]",
  "//*[contains(@class, 'effect-fade-in-scale')]",
  "//*[contains(@class, 'buzz_superlist_item_image')]"
]


#
# load a URL and write it to a cache directory
#
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

#
# wrap text to the specified width, preserving words/etc.
#
def wrap(s, width=40)
  s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
end

#
# find the element that hopefully contains the main chunk
# of text for this html page
#
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

#
# get a count of words in the specified input
#
def wordcount(content=@data)
  if content.respond_to?(:join)
    content = content.join("\n")
  end
  content.split.size
end


#
# split a chunk of text into `count` arrays representing columns of text
#
def chunk_text(t, count = 4, width = 120)
  lines = wrap(t, width).split(/\n/)

  tmp = lines.map { |x|
    words = x.split(/((?<=[a-z0-9)][.?!])|(?<=[a-z0-9][.?!]"))\s+(?="?[A-Z])/)
    next if words.count == 0
    length = (words.count / count).to_i + 1

    words.each_slice(length).to_a
  }.compact

  result = Array.new(count) { [] }

  tmp.each { |row|
    row.each_with_index { |r, i|
      result[i].push(r.join(" "))
    }
  }

  result
end



# here's the starting URL
url = ARGV.last

# limit to the host we started on
@host = Addressable::URI.parse(url).host

@data = []

# here's a list of urls that we can load
@urls = [
  url
]

# track the list of URLs used to generate output
@visited_urls = []

#
# load HTML pages until we hit our target word count for output generation
#
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
    # reject visited URLs and anything that looks like a non-html link
    # @todo buzzfeed is hardcoded here, which is obvs bad
    @visited_urls.include?(l) || l !~ /#{@host}/ || l =~ /.png/ ||
      l =~ /.gif/ || l =~ /.jpg/ || l =~ /.jpeg/ ||
      l =~ /mailto:/
  }

  @data << text
  
  @urls = (@urls + links).flatten
  
  puts "WORD COUNT: #{wordcount}"
  
  sleep SLEEP_RATE
end

# now we have our raw data

puts @data.count

#
# make some cutups
#
@data = @data.map { |chunk| chunk_text(chunk) }


#@data.each { |chunk|
#  puts "!!! #{chunk}"
#  puts chunk_text(chunk).inspect
#}


@output = ""
output_count = 0


# At this point, data should be an array of content from the pages
# that we've downloaded, and each entry in the array should be a split
# column of text. so if we started with:
#
#  word1 word2 word3
#  word4 word5 word6
#  word7 word8 word9
#
# then the first element of @data should be:
# [
#   ["word1", "word4", "word7"],
#   ["word2", "word5", "word8"],
#   ["word3", "word6", "word9"]
# ]
#
# we can take that data and sample from it to output in a vaguely
# cut-up style. there's a couple different ways of doing that, which
# might be worth exploring at some point!
# 


while output_count < OUTPUT_COUNT
  index1 = rand(0...@data.length)
  index2 = rand(0...@data[index1].length)


  # find some text, and remove it so we don't use it again
  chunk = @data[index1][index2].shift rescue nil

  # non-destructive check:
  #chunk = @data.sample.sample.shift
  
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
