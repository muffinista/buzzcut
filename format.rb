#!/usr/bin/env ruby

@data = File.read("output.txt")

@data = @data.
  gsub(/p\.m\./i, "PM").
  gsub(/@buzzfeed.com/, " @ buzzfeed dot com")

@joined_output = ""


def wrap(s, width=40)
  s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
end


output = @data.scan(/[^\.!?]+[\.!?]/)
output.each { |s|
  #puts s
  @joined_output << s
  if rand > 0.8
    @joined_output << "##BREAK##"
  end
}

result = wrap(@joined_output, 80).gsub(/##BREAK##/, "\n\n")
puts result

