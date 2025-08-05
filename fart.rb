require 'net/http'
require 'json'
require 'zlib'
require 'stringio'
require 'thread'

POSSIBLE_CHARACTERS = [*?a..?z] + [*?0..?9] + ["_"]
ROBLO_SECURITY = "_|WARNING:-DO-NOT-SHARE-THIS.--YOUR_TOKEN_HERE"
BIRTHDAY = "1999-04-20"

GREEN = "\e[32m"
GRAY = "\e[90m"
RESET = "\e[0m"

$success_list = []
$mutex = Mutex.new

trap("INT") do
  puts "\n\n=== INTERRUPTED! SUCCESSFUL USERNAMES FOUND SO FAR: ==="
  puts $success_list.join("\n")
  puts "Total successes: #{$success_list.size}"
  exit
end

def valid_username?(http, username)
  url = URI("https://auth.roblox.com/v1/usernames/validate?request.username=#{username}&request.birthday=#{BIRTHDAY}")
  req = Net::HTTP::Get.new(url)
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

def random_username(length)
  username = ''
  has_underscore = false
  length.times do |i|
    chars = POSSIBLE_CHARACTERS.select do |c|
      !(c == '_' && (has_underscore || i == 0 || i == length - 1))
    end
    c = chars.sample
    username << c
    has_underscore ||= (c == '_')
  end
  username
end

puts "Enter username length:"
length = gets.chomp.to_i

THREAD_COUNT = 50
queue = Queue.new

# Pre-fill queue with random usernames
THREAD_COUNT * 100.times do
  queue << random_username(length)
end

threads = []

Net::HTTP.start("auth.roblox.com", 443, use_ssl: true) do |http|
  THREAD_COUNT.times do
    threads << Thread.new do
      loop do
        username = queue.pop(true) rescue nil
        break unless username

        if valid_username?(http, username)
          $mutex.synchronize do
            puts "#{GREEN}Valid username found: #{username}#{RESET}"
            $success_list << username
            File.open("success", "a") { |f| f.puts username }
          end
        else
          $mutex.synchronize do
            print "#{GRAY}#{username} failed...#{RESET}\r"
            File.open("failure", "a") { |f| f.puts username }
          end
        end

        # Refill the queue continuously
        queue << random_username(length)
      end
    end
  end

  threads.each(&:join)
end


