------------------------------------------------------------------------------------------------------------ basic var definitions

local gfx <const> = pd.graphics
local disp <const> = pd.display
local timer <const> = pd.timer
local fs <const> = pd.file

------------------------------------------------------------------------------------------------------------ bAction catch all

function bAction()
  curRow = fileList:getSelectedRow()

  if dir == "/music/" then
    swapScreenMode()
  else
    local x = string.find(dir, "/")-1
    local splitted = split(dir, "/")
    table.remove(splitted)
    for i = x, 0, -1 do
      lastdirs[i] = "/"..table.concat(splitted,"/").."/"
      table.remove(splitted,#splitted)
    end

    dir = table.remove(lastdirs,#lastdirs)

    files = fs.listFiles(dir, false)

    if dir ~= "/music/" then
      table.insert(files, 1, "..")
    end

    local selRow = table.remove(lastDirPos)

    fileList:setSelectedRow(selRow)
    fileList:scrollToRow(selRow)
  end

  audioFiles = {}

  for i=1,#files do
    if files[curRow] ~= nil then
      if findSupportedTypes(files[curRow]) then
        table.insert(audioFiles,files[i])
      end
    end
  end
end

------------------------------------------------------------------------------------------------------------ tables?

function indexOf(tab, str)
  for i, s in ipairs(tab) do
    if s == str then
      return i
    end
  end
  return nil
end

function inTable(tab, str)
  for i, v in ipairs(tab) do
    if v == str then
      return true
    end
  end

  return false
end

------------------------------------------------------------------------------------------------------------ fomats etc

function findSupportedTypes(str)
  if str ~= nil then
    if (string.find(str,"%.mp3",#str-3) ~= nil or string.find(str,"%.pda",#str-3) ~= nil) and string.find(str,"/",#str-1) == nil then
      return true
    end
    return false
  end
end

function fixFormatting(string)
  return string.gsub(string.gsub(string,"*","**"),"_","__")
end

------------------------------------------------------------------------------------------------------------ screens

function lockScreenFunc()
  locked = true
  gfx.clear(bgColor)
  disp.setRefreshRate(5)
end

function swapScreenMode()
  if screenMode == 0 or screenMode == 3 then
    screenMode = 1

    if mode == 4 and currentAudio:isPlaying() == false then
      actualSongEnd() -- switch to actualSongEnd to make sure the song ends
    end
  elseif screenMode == 1 then
    if mode == 4 then
      screenMode = 3
    else
      screenMode = 0
    end

    if currentFileDir == "" then
      dir = "/music/"

      for i=1,#files do
        if findSupportedTypes(files[curRow]) then
          table.insert(audioFiles,files[i])
        end
      end
    else
      dir = currentFileDir
      files = fs.listFiles(dir, false)

      for i=1,#files do
        if findSupportedTypes(files[curRow]) then
          table.insert(audioFiles,files[i])
        end
      end
      -- set directory to currentFileDir

      for i,v in ipairs(files) do
        if v == currentFileName then
          fileList:setSelectedRow(i)
          fileList:scrollToRow(i, true)
        end
      end
    end
    if dir ~= "/music/" then
      table.insert(files, 1, "..")
      fileList:selectNextRow()
    end
  end
end

function swapColorMode(mode)
  if mode == false then
    bgColor = gfx.kColorWhite
    color = gfx.kColorBlack
    dMColor1 = gfx.kDrawModeCopy
    dMColor2 = gfx.kDrawModeFillWhite
    gfx.setColor(color)
    darkMode = false
  else
    bgColor = gfx.kColorBlack
    color = gfx.kColorWhite
    dMColor1 = gfx.kDrawModeFillWhite
    dMColor2 = gfx.kDrawModeCopy
    gfx.setColor(color)
    darkMode = true
  end
end

------------------------------------------------------------------------------------------------------------ settings

function saveSettings()
  local settingsFile = fs.open("/data/settings.json", fs.kFileWrite)
  settingsFile:write(json.encode({darkMode,clockMode,showInfoEverywhere,screenRoundness,lockScreen,lockScreenTime,modeString}))
  settingsFile:close()
end

function loadSettings()
  local settingsFile, err = fs.open("/data/settings.json", fs.kFileRead)

  if err == nil then
    local settings = json.decode(settingsFile:read(100000))

    darkMode = settings[1]
    clockMode = settings[2]
    showInfoEverywhere = settings[3]
    screenRoundness = tonumber(settings[4])
    lockScreen = settings[5]
    lockScreenTime = tonumber(settings[6])
    modeString = settings[7]  -- add modeString to the settingsFile

    if lockScreen == true then
      lockTimer = timer.new((lockScreenTime*60)*1000, lockScreenFunc)
    end
  else
    darkMode = true
    clockMode = false
    showInfoEverywhere = false
    lockScreen = false
    screenRoundness = 4
    lockScreenTime = 2
    modeString = "none" -- added modeString to the default of settingsFile
    if lockScreen == true then
      lockTimer = timer.new((lockScreenTime*60)*1000, lockScreenFunc)
    end
  end

  handleMode(modeString) -- when loading settings rember to load the modeString
end

------------------------------------------------------------------------------------------------------------ next song modes

function handleMode(str)
  if str == nil then -- because people might have had a pre modeString settings file you need to not load when the modeString is nil
    return
  end
  
  print("mode is now "..str)
  modeString = str

  if str == "shuffle" then
    mode = 1
  elseif str == "loop folder" then
    mode = 2
  elseif str == "loop one" then
    mode = 3
  elseif str == "queue" then
    screenMode = 3
    mode = 4
    currentAudio:setFinishCallback(nil)
    currentAudio:stop()
    currentAudio = pd.sound.fileplayer.new()
    currentAudio:setFinishCallback(handleSongEnd)
    currentFileName = ""
    currentFileDir = ""
    currentFilePath = ""
  else
    mode = 0
  end

  if mode ~= 4 then
    queueList = {}
    queueListDirs = {}
    queueListNames = {}
  end
end

function split(inputstr,sep)
  t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    -- "([^"..sep.."]+)"
    table.insert(t, str)
  end

  return t
end

------------------------------------------------------------------------------------------------------------ settings list

function newSettingsList()
  local setList = ({"dark mode - "..tostring(darkMode),
  "24 hour clock - "..tostring(clockMode),
  "show extra info everywhere - "..tostring(showInfoEverywhere),
  "show version - "..tostring(showVersion),
  "screen roundness - "..tostring(screenRoundness),
  "lock screen - "..tostring(lockScreen)})

  if lockScreen == true then
    table.insert(setList,"   lock after "..tostring(lockScreenTime).." minute(s)")
  end

  return setList
end

------------------------------------------------------------------------------------------------------------ draw info

function drawInfo()
  local extension
  local time = pd.getTime()
  if #tostring(time["hour"]) == 1 then
    time["hour"] = "0"..time["hour"]
  end

  if clockMode == false then
    if tonumber(time["hour"]) > 12 then
      time["hour"] -= 12
    end
  end

  if #tostring(time["minute"]) == 1 then
    time["minute"] = "0"..time["minute"]
  end

  local batteryPercent = pd.getBatteryPercentage()

  if string.find(batteryPercent,"100.") then
    batteryPercent = "100"
  else
    batteryPercent = string.sub(string.gsub(batteryPercent,"%.",""),1,2)
  end

  if screenMode == 1 then
    dosFnt:drawTextAligned(time["hour"]..":"..time["minute"],10,10,kTextAlignment.left)
    dosFnt:drawTextAligned(batteryPercent.."%",390,10,kTextAlignment.right)
    gfx.drawRoundRect(5, 5, 390, 17, screenRoundness)
  else
    dosFnt:drawTextAligned(time["hour"]..":"..time["minute"],3,3,kTextAlignment.left)
    dosFnt:drawTextAligned(batteryPercent.."%",397,3,kTextAlignment.right)
  end
  -- gfx.setImageDrawMode(dMColor2)
end

------------------------------------------------------------------------------------------------------------ handleSongEnd components

-- Helper function to load audio files
function loadAudioFiles(files) 
  local audioFiles = {}
  for i=1,#files do
    if findSupportedTypes(files[i]) then
      table.insert(audioFiles,files[i])
    end
  end
  return audioFiles
end

-- Helper function to handle mode 2
function handleMode2(audioFiles)
  if currentFileName == audioFiles[1] then  -- checks if the current file being played (currentFileName) is the first file in (audioFiles)
    currentPos = 1
  end
  if currentFileName == audioFiles[#audioFiles] then -- checks if the current file is the last file in (audioFiles)
    if not pd.buttonIsPressed("a") then
      if fs.isdir(dir..audioFiles[1]) == false then
        currentFileName = audioFiles[1]
        currentAudio:load(dir..audioFiles[1])
      end
    end
  else
    local isdir = fs.isdir(dir..audioFiles[currentPos+1])
    if isdir == true then
      currentPos += 2
    else
      currentPos += 1
    end

    currentFileName = audioFiles[currentPos]
    currentAudio:load(dir..audioFiles[currentPos])
  end
end

-- Helper function to handle mode 1
function handleMode1(audioFiles)
  local randthing = math.random(1,#audioFiles)
  if dir..audioFiles[randthing] == currentFilePath and #audioFiles ~= 1 then
    while dir..audioFiles[randthing] == currentFilePath do
      randthing = math.random(1,#audioFiles)
    end
  end
  currentFileName = audioFiles[randthing]
  currentAudio:load(dir..audioFiles[randthing])
end

-- Helper function to handle mode 0
function handleMode0()
  currentAudio = pd.sound.fileplayer.new()
  currentAudio:setFinishCallback(handleSongEnd)
  currentFileName = ""
  currentFileDir = ""
  currentFilePath = ""
end

-- Helper function to handle mode 4
function handleMode4()
  if #queueList == 1 then
    mode = 1
    modeMenuItem:setValue("shuffle")
    modeString = "shuffle"
    justInQueue = true
  end

  if #queueList ~= 0 then
    currentFileName = queueListNames[1]
    currentFileDir = queueListDirs[1]
    currentFilePath = queueList[1]
    table.remove(queueList, 1)
    table.remove(queueListDirs, 1)
    table.remove(queueListNames, 1)
    currentAudio:load(currentFilePath)
  else
    mode = 0
    modeMenuItem:setValue("none")
    modeString = "none"
  end
end

function actualSongEnd()

  updateGetLength = true

  local justInQueue = false

  -- Load audio files
  local audioFiles = loadAudioFiles(files)

  currentAudio:pause()

  -- Handle different modes
  if mode == 2 then
    handleMode2(audioFiles)
  elseif mode == 1 then
    handleMode1(audioFiles)
  elseif mode == 0 then
    handleMode0()
  elseif mode == 4 then
    handleMode4()
  end

  
  if mode ~= 4 then
    if justInQueue == false then
      currentFilePath = dir..currentFileName
      currentFileDir = dir
    end
  end
  table.insert(lastSongNames,currentFileName)
  table.insert(lastSongDirs,currentFileDir)

  audioLen = getLengthVar

  currentAudio:setRate(1.0)

  if mode ~= 0 then
    pd.timer.new(10, function()
      currentAudio:pause()
      currentAudio:setOffset(0)
      currentAudio:play()
    end)
    currentAudio:play()
  else
    currentFilePath = ""
    pd.setAutoLockDisabled(false)
  end
  
end

-- Main function
function handleSongEnd() -- fix literally everything :) have fun future aiden - i did it past me! aren't you proud of me?

  --print("please change songs???")

  -- Increment the counter each time the function is called
  songEndErrorCounter = songEndErrorCounter + 1

  -- If the function has been called more than once in 100 frames, return immediately
  if songEndErrorCounter > 5 then
    --print("way too much!")
    errorCode = "That was not good! :)"
    errorHappened = true
    actualSongEnd()
    return
  end

  -- Reset the counter after 100 frames
  pd.timer.new(300, function()
    songEndErrorCounter = 0
  end)

  if (math.abs(currentAudio:getOffset() - currentAudio:getLength()) <= 5) and (math.abs(getLengthVar - currentAudio:getLength()) <= 5) then
    --print("actual song change")
    actualSongEnd()
  else
    --print("averting crisis?")
    errorCode = "Oops..."
    errorHappened = true
    currentAudio:pause()
    currentAudio:setOffset(math.floor(saveSongSpot2 + 0.5))
    currentAudio:play()

    safeToReset = false
    pd.timer.new(100, function()
      safeToReset = true
    end)
  end
  
end

------------------------------------------------------------------------------------------------------------ seconds formating

function formatSeconds(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "0:00"
  else
    hours = string.format("%02.f", math.floor(seconds/3600))
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)))
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60))
    return mins..":"..secs
  end
end

------------------------------------------------------------------------------------------------------------ button funcs

function pd.downButtonDown()
  local function timerCallback()
    fileList:selectNextRow(true)
  end
  if screenMode == 0 or screenMode == 3 then
    downKeyTimer = timer.keyRepeatTimerWithDelay(300,50,timerCallback)
  end
end

function pd.downButtonUp()
  if screenMode == 0 or screenMode == 3 then
    downKeyTimer:remove()
  end
end

function pd.upButtonDown()
  local function timerCallback()
    fileList:selectPreviousRow(true)
  end
  if screenMode == 0 or screenMode == 3 then
    upKeyTimer = timer.keyRepeatTimerWithDelay(300,50,timerCallback)
  end
end

function pd.upButtonUp()
  if screenMode == 0 or screenMode == 3 then
    upKeyTimer:remove()
  end
end
