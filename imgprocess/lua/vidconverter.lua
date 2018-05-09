local M = {}

local utils = require 'utils'
local bb = require 'lib.backblaze'

function loader:ConvertStaticImage(image)

  local imageData =  bb:GetImage(image.rawID)
  image.data =  assert(magick.load_image_from_blob(imageData.data))

  -- optimise
  image.data:set_format('jpg')
  image.data:set_quality(90)
  local bbID, err = self:SendImage(image.data:get_blob(), image.id)

  if bbID then
    print('sent to bb, adding to image')
    self:AddBBIDToImage(image.id, 'imgID', bbID)
  else
    print(err)
  end

  -- add this as imgID

  -- shrink
  image.data:resize_and_crop(1000,1000)

  bbID, err = self:SendImage(image.data:get_blob(), image.id)
  if bbID then
    print('sent to bb, adding to image big')
    self:AddBBIDToImage(image.id, 'bigID', bbID)
  else
    print(err)
  end

  image.data:resize_and_crop(100,100)

  bbID, err = self:SendImage(image.data:get_blob(), image.id)
  if bbID then
    print('sent to bb, adding to image icon')
    self:AddBBIDToImage(image.id, 'iconID', bbID)
  else
    print(err)
  end

  return true
end

function loader:ConvertImage(image)


  if image.type == 'vid' then
    local ok, err = self:ConvertRawVideo(image)
    if not ok then
      print('failed to process:', err)
    end
    return ok, err
  else
    local ok, err = self:ConvertStaticImage(image)
    return ok, err
  end

end

function M:GetFirstFrame(image, pathIn)
  --https://stackoverflow.com/questions/4425413/how-to-extract-the-1st-frame-and-restore-as-an-image-with-ffmpeg
  local ok, err, fileData
  local pathOut = pathIn..'-icon.jpg'
  local command = 'ffmpeg -i '..pathIn..' -vf '..[["select=eq(n\,0)"]]..' -vf scale=100:-2 -q:v 3 '..pathOut..' 2>&1'
  local handle = io.popen(command)
  local output = handle:read('*a')
  print(output)
  --TODO check output

  fileData, err = ReadFile(pathOut)
  if not fileData then
    return fileData, err
  end

  ok, err = utils:SendImage(fileData, image.id..'-'..'icon')
  if not ok then
    return ok, err
  end

  return self:AddBBIDToImage(image.id, 'iconID', ok)


end

function M:GeneratePreview(image, pathIn, pathOut)
  local hours, minutes, seconds = imgURL:match('Duration: (%d%d):(%d%d):(%d%d)%.%d%d')
  local totalTime = seconds + minutes*60 + hours*60*60

  -- calculate what we need
  local segmentCount = 10
  local startTime, command, handle, output
  for i = 1, segmentCount do
    startTime = math.floor((totalTime/segmentCount)*i)
    command = 'ffmpeg -y -ss '..startTime..' -i '..pathIn..' -t 1 -f mpegts '..pathIn..'-out'..i..'.ts'
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

  command = 'ffmpeg -y -i "'..concat..'" -c copy '..pathOut

  handle = io.popen(command)
  output = handle:read('*all')
  io.popen('rm '..pathIn..'-out')

  --TODO check for errors

  return true
end

function M:ConvertAndUpload(image, pathIn, pathOut, width, height, tag)
  local fileData, ok, err
  print('converting==', pathIn, '===', pathOut,'====')
  local command = 'ffmpeg -y -i '..pathIn..[[ -filter_complex "scale=iw*min(1\,min(]]
                        ..height..[[/iw\,]]..width..[[/ih)):-1" ]]..pathOut..' 2>&1'
  local handle = io.popen(command)
  local output = handle:read('*a')
  print('output for ', tag)
  print(output)
  --TODO check output


  fileData, err = utils:ReadFile(pathOut)
  if not fileData then
    print('couldnt read file: ', pathOut)
    return fileData, err
  end

  ok, err = utils:SendImage(fileData, image.id..'-'..tag)
  print(tag, ' - ', ok)
  if not ok then
    return ok, err
  end

  return utils:AddBBIDToImage(image.id, tag, ok)

end


function M:IsGif(fileName)
  local handle = io.popen('ffprobe '..fileName..' 2>&1')
  local imgURL = handle:read("*a")

  local hours, minutes, seconds = imgURL:match('Duration: (%d%d):(%d%d):(%d%d)%.%d%d')
  local totalTime = seconds + minutes*60 + hours*60*60
  if totalTime > 15 then
    return false
  end
end

function M:ConvertRawVideo(image)

    -- download the raw file
    local file, ok, err
    file, err = bb:GetImage(image.rawID)
    if not file then
      return file, err
    end
    print('got raw')

    --write locally
    ok, err = utils:WriteFile('out/'..image.id, file.data)
    if not ok then
      return ok, err
    end

    print('wrote locally')

    local pathIn = 'out/'..image.id
    local pathOut = 'out/'..image.id..'-processed.mp4'

    -- convert to mp4 and upload
    ok, err = self:ConvertAndUpload(image, pathIn, pathOut, 1920, 1080, 'videoID')
    if not ok then
      return ok, err
    end
    print('converted to mp4')


    -- create preview and upload
    pathOut = 'out/'..image.id..'-preview.mp4'
    if self:IsGif(pathIn) then
      ok, err = self:GeneratePreview(pathIn, pathOut)
      if not ok then
        return ok, err
      end
    else
      ok, err = self:ConvertAndUpload(image, pathIn, pathOut, 854, 480, 'previewID')
      if not ok then
        return ok, err
      end
    end
    print('converted to preview')

    -- by now we have either a condensed 10 sec preview or just a shrunk 15 sec vid
    -- convert to gif as fallback

    -- use the output from above
    pathIn = pathOut
    pathOut = 'out/'..image.id..'-processed.gif'
    ok, err = self:ConvertAndUpload(image, pathIn, pathOut, 854, 480, 'gifID')
    if not ok then
      return ok, err
    end
    print('converted to gif')
    -- use the preview for image as its already smaller
    ok, err = self:GetFirstFrame(image, pathIn)
    if not ok then
      return ok, err
    end
    print('converted icon')

    --TODO cleanup local files
    --TODO remove raw from image/backblaze.


    return true
  end

return M