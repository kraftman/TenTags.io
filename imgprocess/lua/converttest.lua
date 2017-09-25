
local fileName = 'bigbuck'
local fileExtension = '.mp4'

local pathIn = 'SES.mp4'
local pathOut = 'processed.gif'

local command = 'ffmpeg -y -i '..pathIn..[[ -filter_complex "scale=iw*min(1\,min(1920/iw\,1080/ih)):-1:flags=lanczos,palettegen=stats_mode=full" ]]..pathOut..' 2>&1'
print(command)
local handle = io.popen(command)
local output = handle:read('*a')
--
--
-- -- get the total length
-- local handle = io.popen('ffprobe '..fileName..fileExtension..' 2>&1')
-- local imgURL = handle:read("*a")

--ffmpeg -i inputfile.mkv -vf "select=eq(n\,0)" -vf scale=320:-2 -q:v 3 output_image.jpg

-- generate the output videos

--local concatST = '-segment_times '..table.concat(segmentTimes, ',')


--ffmpeg -i sample.mp4 -f segment -segment_times 10,20 -c copy -map 0 output02%d.mp4
--local command = 'ffmpeg -y -i '..fileName..fileExtension..' -f segment '..concatST..' -c copy -map 0 output%d.mp4'
--print(command)
--local handle = io.popen(command)
--local handle = io.popen('ffmpeg -y -i giphy sample.mkv 2>&1')
--local output = handle:read('*a')


-- combine them
