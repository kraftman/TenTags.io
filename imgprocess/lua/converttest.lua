
local fileName = 'bigbuck'
local fileExtension = '.mp4'


-- get the total length
local handle = io.popen('ffprobe '..fileName..fileExtension..' 2>&1')
local imgURL = handle:read("*a")

local hours, minutes, seconds = imgURL:match('Duration: (%d%d):(%d%d):(%d%d)%.%d%d')
local totalTime = seconds + minutes*60 + hours*60*60


-- calculate what we need
local segmentCount = 10
local startTime, command, handle, output
for i = 1, segmentCount do
  startTime = math.floor((totalTime/segmentCount)*i)
  command = 'ffmpeg -y -ss '..startTime..' -i '..fileName..fileExtension..' -t 1 -f mpegts output'..i..'.ts'
  print(command)
  handle = io.popen(command)
  output = handle:read('*all')
  print(output)
end

local concat = 'concat:'

for i = 1, segmentCount do
  if i == 1 then
    concat = concat..'output'..i..'.ts'
  else
    concat = concat..'|output'..i..'.ts'
  end
end

command = 'ffmpeg -y -i "'..concat..'" -c copy  finished.mp4'
print(command)
handle = io.popen(command)
output = handle:read('*all')
print(output)

-- generate the output videos

--local concatST = '-segment_times '..table.concat(segmentTimes, ',')


--ffmpeg -i sample.mp4 -f segment -segment_times 10,20 -c copy -map 0 output02%d.mp4
--local command = 'ffmpeg -y -i '..fileName..fileExtension..' -f segment '..concatST..' -c copy -map 0 output%d.mp4'
--print(command)
--local handle = io.popen(command)
--local handle = io.popen('ffmpeg -y -i giphy sample.mkv 2>&1')
--local output = handle:read('*a')


-- combine them
