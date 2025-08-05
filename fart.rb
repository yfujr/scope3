require 'net/http'
require 'json'
require 'zlib'
require 'stringio'

POSSIBLE_CHARACTERS = [*?a..?z] + [*?0..?9] + ["_"]
ROBLO_SECURITY = "_|WARNING:-DO-NOT-SHARE-THIS.--Sharing-this-will-allow-someone-to-log-in-as-you-and-to-steal-your-ROBUX-and-items.|_CAEaAhAB.61B937704B2602227A1DF54838240DE8468C28C54221F76594E4D436131C213E6C21AAD9F8EE1BBBD4EEF8984EF08D54C45385E3D874156B3929505FB1254A5405D8DFB1D675C4F3D97F526638D8FA3ECCC447766AB18431F855EBD4F3EA5E5FAE835E87A997923D8B6BCC45E19653C3C51C361D775E0F094DECB577FE4A4E38329E307C2F847F31B0437B3AD43DC39742D875F93E46C941E5573E450BFFD01FDB917EB5C5277C44C657343B2D71824DE14856E2DCC1B263D7355284CFAC0B6D4404898AC75650463EE2B2D0E0F662820474B5CE313A0326C4C2840C08E20E77EA739361801F890C5100DEBCE6825C799A2DD3E52C2F5391520CF2B31BF0BEFA46083E376378E5AF5D77ECE4879253A08E90411111872442D8CEA97CB586FBA3C6CF2555EB43E6DDFDB92A9D7CF589A6E3A204A4ADC2FC4FA34C938C51766F7BB0EF2A0805760CE5819C5B6BFF6DD98102E739AE74EFD6AA8D6082A72DF6FFF50EFE80687A5050283D56FD40FD3EE754BB2A0F05C5E033B2207081AD6ECE843810C8E2AC673BCAB3A70B3D323619EF49ECD797BC8973E06DAB7B0DA6DDCA1D426EBE93BDF6B34F7990E32A1BA8FC16C601ADA80DBA6B39E00842C9E081A68F25F3A0F708C4190D7B84BBEE2AC2C9CDC3A4D329D105C27BBF93FE44F6AEE984372F7F9CEFD71DAF428BA28D459F71A2D4A022397DB200ECE456B1559E9FB59ECE1F9FC9979A550933443095037A563D4A5223F1B241C0118051E4E31A5A1FF0B1E5BF891EB09FF12723DD1EF236F0C4C78D8961C1DBEA0F01F12EB3E0DDFDFD6343427519CC21F0F2E641FA9843639717B3A37495E4590474B989B52826D5E9B6A62DFE651118A4EBECC61F2BA8C95CA7A1178799C2D42CC9C2D57F7A40F77A39C680CA3CC83E04105218E88FEB198C9DD598048DB0D842AFA8612269DAC7EB77B15FDCC9B728DE1974049EAD16FE486A9647791B1D328EF4935D4B5259CBEC6936D03D7EFF1F3258193FB98092578C519E9DFA783132733CD2DF2809C0A6647200D0487776AF3A35690C573493A3F493634B366FA8519149C6D3093DE4C2739D0B28C4E0CF680A235A55949BDBE561B3828C306F9C019880B26CDE7BE24491F2AB5909C02814FA7B92D7DDB9960653F66243FF5FC925F50CEDCB77B0A421846E80AD68ED6367F169E629332786029DCB91D01631E4A24D5936645BF773E7691C85E12231178324AA8C9CFD332E20A30BE495DD1A"
BIRTHDAY = "1999-04-20" # Your provided birthday

$success_list = [] # Global list of successful usernames

# Terminal colors
GREEN = "\e[32m"
GRAY = "\e[90m"
RESET = "\e[0m"

# Trap Ctrl+C (SIGINT) to print successful usernames
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

def alphanumeric_permutations(input, length, current_str)
  return [ current_str ] if current_str.length == length
  ret = []
  for i in (0...input.length) do
    at_str_end = (current_str.length == 0) || (current_str.length + 1 == length)
    has_underscore = current_str.include?("_")
    next if ((at_str_end || has_underscore) && input[i] == '_')
    ret.push(*alphanumeric_permutations(input, length, current_str + input[i]))
  end
  return ret
end

begin
  combos = alphanumeric_permutations(POSSIBLE_CHARACTERS, 5, '')
  success_f = File.open("success", "a")
  fail_f = File.open("failure", "a")
  i = 0
  until combos[i].nil?
    threads = []
    50.times do
      break if combos[i].nil?
      threads << Thread.new(i) do |thread_i|
        operation(combos[thread_i], thread_i, success_f, fail_f)
      end
      i += 1
    end
    sleep(0.1) until threads.all? { |t| !t.alive? }
    threads.each(&:kill)
  end

rescue IOError => e
  puts e
ensure
  success_f.close unless success_f.nil?
  fail_f.close unless fail_f.nil?
end

