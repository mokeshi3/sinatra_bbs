require "securerandom"

avg = 0.0
max = 100.0
for _ in 1..max
  cnt = 0.0
  vals = []
  until vals.size != vals.uniq.size do
    vals.append(SecureRandom.hex(2))
    cnt = cnt + 1.0
  end
  avg = avg + cnt/max
end

puts "#{avg}"
