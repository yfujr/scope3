require 'net/http'
require 'json'
require 'zlib'
require 'stringio'

POSSIBLE_CHARACTERS = [*?a..?z] + [*?0..?9] + ["_"]

# Put your Roblox security token here (DO NOT share this token publicly!)
ROBLO_SECURITY = "_|WARNING:-DO-NOT-SHARE-THIS.--Sharing-this-will-allow-someone-to-log-in-as-you-and-to-steal-your-ROBUX-and-items.|_YOUR_TOKEN_HERE"

BIRTHDAY = "1999-04-20"

$success_list = []

GREEN = "\e[32m"
GRAY = "\e[90m"
RESET = "\e[0m"

trap("INT") do
  puts "\n\n=== INTERRUPTED! SUCCESSFUL USERNAMES FOUND SO FAR: ==="
  puts $success_list.join("\n")
  puts "Total successes: #{$success_list.size}"
  exit
end

def valid_username?(username)
  url = URI.parse("https://auth.roblox.com/v1/usernames/validate?request.username=#{username}&request.birthday=#{BIRTHDAY}")
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  req = Net::HTTP::Get.new(url.request_uri)
  req["Accept-Encoding"] = "gzip, deflate, br"
  req["Cookie"] = ".ROBLOSECURITY=#{ROBLO_SECURITY}"

  begin
    response = http.request(req)
  rescue
    retry
  end

  body = response.body
  if response['Content-Encoding'] == 'gzip'
    body = Zlib::GzipReader.new(StringIO.new(body)).read
  end

  JSON.parse(body)['data'] == 0
end

def operation(word, i, success_f, fail_f)
  if valid_username?(word)
    puts "#{GREEN}------ #{i}: #{word} SUCCESS#{RESET}"
    success_f.write(word + "\n")
    $success_list << word
  else
    puts "#{GRAY}#{i}: #{word} failed#{RESET}"
    fail_f.write(word + "\n")
  end
end

def alphanumeric_permutations_iter(input, length)
  return to_enum(:alphanumeric_permutations_iter, input, length) unless block_given?

  queue = ['']
  while !queue.empty?
    current = queue.shift
    if current.length == length
      yield current
    else
      input.each do |char|
        at_str_end = current.length == 0 || current.length + 1 == length
        has_underscore = current.include?('_')
        next if ((at_str_end || has_underscore) && char == '_')
        queue.push(current + char)
      end
    end
  end
end

# Ask user for length input
print "Enter the number of characters for the username to check: "
length = gets.chomp.to_i

possible_chars = POSSIBLE_CHARACTERS.reject { |c| c == '_' }
total_usernames = possible_chars.length ** length

puts "Testing usernames of length #{length}."
puts "Estimated total usernames to test (approximate, ignoring underscore rules): #{total_usernames}"

begin
  success_f = File.open("success", "a")
  fail_f = File.open("failure", "a")

  i = 0
  alphanumeric_permutations_iter(POSSIBLE_CHARACTERS, length).each do |username|
    operation(username, i, success_f, fail_f)
    i += 1
    puts "Checked #{i} usernames..." if i % 100 == 0
  end

rescue IOError => e
  puts e
ensure
  success_f.close unless success_f.nil?
  fail_f.close unless fail_f.nil?
end


