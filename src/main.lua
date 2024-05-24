-- musik by nanobot567. feel free to copy / share this code, just give credit please! :)

print("-----------------------------------------------------------------------")
print("Hey there, friend! Have fun debugging / hacking my app! :D - nanobot567") -- Hi there \\ From Ryder Booth (Funny Racer)
print("-----------------------------------------------------------------------")

-- small text font on card-pressed.png is consolas 9

pd = playdate

------------------------------------------------------------------------------------------------------------ Basic imports

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/nineslice"
import "CoreLibs/timer"
import "funcs"
-- import "crankFuncs"

------------------------------------------------------------------------------------------------------------ Basic var definitions 

local gfx <const> = pd.graphics
local disp <const> = pd.display
local timer <const> = pd.timer
local fs <const> = pd.file

fs.mkdir("/music/")
fs.mkdir("/data/")
dir = "/music/"
lastdirs = {}
files = fs.listFiles(dir, false)

local playingGraphic = gfx.image.new("img/playing")
local pausedGraphic = gfx.image.new("img/paused")
local menuGraphic = gfx.image.new("img/menu")
dosFnt = gfx.font.new("fnt/dos")

pd.setMenuImage(menuGraphic)

currentAudio = pd.sound.fileplayer.new() -- do NOT add a buffer this does infact buffer and takes a long time and can lead to e0 and e1 errors
currentFilePath,currentFileName,currentFileDir = "","","" -- moved modeString over to setting save and load
lastOffset,currentPos,songToHighlightRow,audioLen,lastScreenMode = 0,1,0,0,0
darkMode,showInfoEverywhere = true,false
audioFiles,lastSongDirs,lastSongNames = {},{},{}
lastDirPos = {1}
mode = 0 -- 0 is none, 1 is shuffle, 2 is loop folder, 3 is loop song, 4 is queue
screenMode = 0 -- 0 is files, 1 is playing, 2 is settings
clockMode = false -- true is 24 hr, false is 12 hr
upKeyTimer = nil
downKeyTimer = nil
lockTimer = nil
lockScreenTime = 2 -- minutes
lockScreen = false
locked = false
showVersion = true
screenRoundness = 4
saveSongSpot = 0 -- this helps stom skipping and playback issues | this saves the offset
saveSongSpot2 = 0
canGoNext = false -- this helps stom skipping and playback issues | this stores if the song can switch
updateGetLength = true -- this resets the getLengthVar
getLengthVar = 0 -- this is conected to getLength() 
safeToReset = true
songEndErrorCounter = 0
errorHappened = false
errorCode = ""
local totalCrankDistance = 0

queueList = {}
queueListDirs = {}
queueListNames = {}

bgColor = gfx.kColorBlack
color = gfx.kColorWhite
dMColor1 = gfx.kDrawModeFillWhite
dMColor2 = gfx.kDrawModeCopy

------------------------------------------------------------------------------------------------------------ App setup

for i=1,#files do
  if findSupportedTypes(files[curRow]) then
    table.insert(audioFiles,files[i])
  end
end

loadSettings()
swapColorMode(darkMode)
settings = newSettingsList()

gfx.setColor(color)
gfx.clear(bgColor)

-- moved no files explainer to the (if files[1] == nil then)

fileList = pd.ui.gridview.new(0, 10)
fileList:setNumberOfRows(#files)
fileList:setScrollDuration(250)
fileList:setCellPadding(0, 0, 5, 10)
fileList:setContentInset(24, 24, 13, 11)

function fileList:drawCell(section, row, column, selected, x, y, width, height)
  local toWrite = fixFormatting(files[row])
  if files[row] ~= nil then
    if selected then
      gfx.fillRoundRect(x, y, width, 20, 4)
      gfx.setImageDrawMode(dMColor2)
    else
      gfx.setImageDrawMode(dMColor1)
    end

    if (files[row] == currentFileName and dir == currentFileDir) then
      toWrite = "*"..toWrite.."*"
    elseif inTable(queueList, dir..files[row]) then
      toWrite = "_"..toWrite.."_"
    end
    gfx.drawText(toWrite, x+4, y+2, width, height, nil, "...")
  end
end

settingsList = pd.ui.gridview.new(0, 10)
settingsList:setNumberOfRows(#files)
settingsList:setScrollDuration(250)
settingsList:setCellPadding(0, 0, 5, 10)
settingsList:setContentInset(24, 24, 13, 11)

function settingsList:drawCell(section, row, column, selected, x, y, width, height)
  local toWrite = settings[row]
  if settings[row] ~= nil then
    if selected then
      gfx.fillRoundRect(x, y, width, 20, 4)
      gfx.setImageDrawMode(dMColor2)
    else
      gfx.setImageDrawMode(dMColor1)
    end

    if settings[row] == currentFileName and dir == currentFileDir then
      toWrite = "*"..toWrite.."*"
    end
    gfx.drawText(toWrite, x+4, y+2, width, height, nil, "...")
  end
end

local menu = pd.getSystemMenu()

local playingMenuItem, error = menu:addMenuItem("now playing", swapScreenMode)
modeMenuItem, error = menu:addOptionsMenuItem("mode", {"none","shuffle","loop folder","loop one","queue"}, modeString, handleMode) -- added modeString as the default so the munie shows teh corect setting
local settingsModeMenuItem, error = menu:addMenuItem("settings", function()
  if screenMode ~= 2 then
    lastScreenMode = screenMode
    screenMode = 2
    settingsList:setSelectedRow(1)
  else
    screenMode = lastScreenMode
  end
end)


if files[1] == nil then
  gfx.setImageDrawMode(dMColor1)  -- moved this no files stuff here so that it isnit a issue when there are files
  gfx.drawTextAligned("No files found!", 200, 10, kTextAlignment.center) -- updated the txt
  gfx.drawTextAligned("Scan the code to find out how to add some.", 200, 35, kTextAlignment.center)

  gfx.setImageDrawMode(gfx.kDrawModeNXOR) -- add a QR code to the add audio part of the GitHub repo info thing
  local addSongsQRImg = gfx.image.new("img/addSongsQR")
    assert(addSongsQRImg)

    addSongsQRImg:draw(120,65)

  gfx.setImageDrawMode(dMColor2)

  table.insert(files,"no files!") -- left this intact
  pd.stop()
end

currentAudio:setRate(1.0)

files = fs.listFiles(dir, false)

------------------------------------------------------------------------------------------------------------ update() func

function pd.update()
  timer.updateTimers()
  gfx.clear(bgColor)

  if currentAudio:getLength() ~= nil then -- if its not nil then go ahead
    if getLengthVar < currentAudio:getLength() then -- always take the higher gteLength() and show that
      getLengthVar = currentAudio:getLength()
    end

    if currentAudio:getOffset() >= (getLengthVar*.9) then -- if the song is at or past 90% switch to actual length estimate after it has worked out its kinks
      getLengthVar = currentAudio:getLength()
    end

    if updateGetLength == true then -- reset var for next songs etc
      getLengthVar = 1
      updateGetLength = false
    end
  end

  if locked == true then
    gfx.drawTextInRect("locked! hold a and b to unlock...",0,110,400,240,nil,nil,kTextAlignment.center,nil)
  end

  if showVersion == true and screenMode ~= 1 then
    dosFnt:drawTextAligned("musik Lite "..pd.metadata.version.."", 200, 230, kTextAlignment.center, nil)
  end

  local btnState = pd.getButtonState()

  if btnState ~= 0 and lockScreen == true and locked == false then
    lockTimer:reset()
  end

  if btnState == 48 and locked == true then
    locked = false
    disp.setRefreshRate(30)
    lockTimer = timer.new((lockScreenTime*60)*1000, lockScreenFunc)
    pd.wait(350)
    gfx.clear(bgColor)
  end

  if showInfoEverywhere == true then
    drawInfo()
  end

  if locked ~= true then
    if screenMode == 0 or screenMode == 3 then
      playingMenuItem:setTitle("now playing")
      settingsModeMenuItem:setTitle("settings")

      fileList:setNumberOfRows(#files)
      curRow = fileList:getSelectedRow()

      if fileList.needsDisplay == true then
        fileList:drawInRect(0, 0, 400, 230)
      end

      gfx.drawRoundRect(20,13,360,209,screenRoundness)

      local crankChange = pd.getCrankChange()
      totalCrankDistance += crankChange

      if (totalCrankDistance >= 25) then
        fileList:selectPreviousRow(true)
        totalCrankDistance = 0
      elseif (totalCrankDistance <= -25) then
        fileList:selectNextRow(true)
        totalCrankDistance = 0
      end

      if pd.buttonJustPressed("right") then
        if curRow <= #files-4 then
          fileList:setSelectedRow(curRow+4)
        else
          fileList:setSelectedRow(#files)
        end
        fileList:scrollToRow(fileList:getSelectedRow())
      elseif pd.buttonJustPressed("left") then
        if curRow ~= 1 then
          if curRow > 5 then
            fileList:setSelectedRow(curRow-4)
          else
            fileList:setSelectedRow(1)
          end
          fileList:scrollToRow(fileList:getSelectedRow())
        else
          bAction()
        end
      elseif pd.buttonJustPressed("a") then
        -- If the current row is ".." and it's the first row, perform the bAction function
        if files[curRow] == ".." and curRow == 1 then
          bAction()
        -- If the current row is a directory
        elseif fs.isdir(dir..files[curRow]) == true then
          -- Clear the audioFiles table
          audioFiles = {}
          -- Store the current row position
          table.insert(lastDirPos, curRow)
          -- Set the selected row to the first row
          fileList:setSelectedRow(1)
          fileList:scrollToRow(1)

          -- Store the current directory
          table.insert(lastdirs,dir)
          -- Update the current directory to the selected directory
          dir = dir..files[curRow]

          -- List all files in the new directory
          files = fs.listFiles(dir, false)

          -- For each file in the directory
          for i=1,#files do
            -- If the file is a supported audio type, add it to the audioFiles table
            if findSupportedTypes(files[i]) then
              table.insert(audioFiles,files[i])
            end
          end

          -- If the directory is not the root music directory, add ".." to the start of the files list
          if dir ~= "/music/" then
            table.insert(files,1,"..")
          end

          -- Update the number of rows in the file list to match the number of files
          fileList:setNumberOfRows(#files)
        else
          -- If the selected file is the currently playing file
          if dir..files[curRow] == currentFilePath then
            -- Swap the screen mode
            swapScreenMode()
          else
            -- If the selected file is a supported audio type
            local isCurRowSupported = findSupportedTypes(files[curRow])
            if isCurRowSupported then
              -- Clear the audioFiles table
              audioFiles = {}
              -- For each file in the directory
              for i=1,#files do
                -- If the file is a supported audio type, add it to the audioFiles table
                if isCurRowSupported then
                  table.insert(audioFiles,files[i])
                end
              end
              -- Set the current position to the selected row
              currentPos = curRow

              -- If the screen mode is not 3
              -- Check if the file exists
              if fs.exists(dir..files[curRow]) then
                if screenMode ~= 3 then
                  -- Reset the saved song position
                  saveSongSpot = 0
              
                  -- Set the flag to update the song length
                  updateGetLength = true
                              
                  -- Pause the current audio
                  currentAudio:pause()
              
                  -- Store the current song directory and name
                  table.insert(lastSongDirs,currentFileDir)
                  table.insert(lastSongNames,currentFileName)
              
                  -- Load the selected audio file
                  local success, err = pcall(function() currentAudio:load(dir..files[curRow]) end)
              
                  -- Check if loading the audio file was successful
                  if not success then
                    print("Failed to load audio file: " .. err)
                    return
                  end
              
                  -- Get the length of the audio file
                  audioLen = getLengthVar
                  -- Disable auto lock
                  pd.setAutoLockDisabled(true)
              
                  -- Update the current file name, directory, and path
                  currentFileName = files[curRow]
                  currentFileDir = dir
                  currentFilePath = dir..files[curRow]
              
                  -- Set the audio playback rate to normal speed
                  currentAudio:setRate(1.0)
                  -- Set the audio offset to the start of the file
                  currentAudio:setOffset(0)
                  -- Start playing the audio
                  currentAudio:play()
              
                  -- Swap the screen mode
                  swapScreenMode()
                else
                  -- If the screen mode is 3, add the selected file to the queue
                  table.insert(queueList, dir..files[curRow])
                  table.insert(queueListDirs, dir)
                  table.insert(queueListNames, files[curRow])
                end
              else
                print("File does not exist: " .. dir..files[curRow])  -- small error catching
              end
            end
          end
        end
      elseif pd.buttonJustPressed("b") then
        if screenMode ~= 3 then
          bAction()
        else
          if inTable(queueList, dir..files[curRow]) then
            table.remove(queueList, indexOf(queueList, dir..files[curRow]))
            table.remove(queueListDirs, indexOf(queueList, dir))
            table.remove(queueListNames, indexOf(queueListNames, files[curRow]))
          else
            bAction()
          end
        end
      end
    elseif screenMode == 1 then
      playingMenuItem:setTitle("files")
      settingsModeMenuItem:setTitle("settings")
      gfx.setImageDrawMode(dMColor1)
      audioLen = getLengthVar
      if audioLen ~= nil then
        gfx.drawTextAligned(fixFormatting(currentFileName),200,110,kTextAlignment.center)  -- updated the looks
        gfx.drawTextAligned((formatSeconds(currentAudio:getOffset())),160,213,kTextAlignment.center)
        gfx.drawTextAligned((" / "),200,213,kTextAlignment.center)
        gfx.drawTextAligned((formatSeconds(audioLen)),240,213,kTextAlignment.center)
      else
        gfx.drawTextAligned("nothing playing",200,213,kTextAlignment.center)
      end

      gfx.drawRoundRect(5, 205, 390, 30, screenRoundness)

      if errorHappened == true then
        gfx.drawTextAligned(errorCode,200,160,kTextAlignment.center)
        pd.timer.new(3000, function()
          errorHappened = false
        end)
      end

      gfx.drawTextAligned(modeString,390,213,kTextAlignment.right)

      if showInfoEverywhere == false then
        drawInfo()
      end

      if pd.buttonJustPressed("down") then -- if down pressed
        if currentAudio:getOffset() > 5.5 then -- if offset is over 5.5 sec the go to next song
          canGoNext = true
          actualSongEnd() -- pausing and starting handeled here | changed to actualSongEnd to make sure song ends
        end
      elseif pd.buttonJustPressed("a") then -- if a pressed
        if audioLen ~= nil then -- length nil check
          if currentAudio:isPlaying() == true then -- if playing pause
            lastOffset = currentAudio:getOffset()
            currentAudio:pause()
            pd.setAutoLockDisabled(false)
          else -------------------------------------- else play
            currentAudio:setOffset(lastOffset)
            currentAudio:play()
            pd.setAutoLockDisabled(true)
          end
        end
      elseif pd.buttonJustPressed("b") then -- if you press b then go back a screen
        swapScreenMode()
      end

      if pd.buttonJustPressed("left") or pd.buttonJustPressed("right")or pd.buttonJustPressed("up") or pd.buttonJustPressed("down") or pd.buttonJustPressed("a") or pd.buttonJustPressed("b") then
        saveSongSpot = currentAudio:getOffset()  -- if you press a button save the curnet song play point
        pd.timer.new(40, function()
          if safeToReset == true then
            saveSongSpot2 = saveSongSpot
          end
        end)
      end

    elseif screenMode == 2 then
      playingMenuItem:setTitle("files")
      settingsModeMenuItem:setTitle("back")
      gfx.drawRoundRect(20,13,360,209,screenRoundness)

      curRow = fileList:getSelectedRow()
      settingsList:setNumberOfRows(#settings)

      if settingsList.needsDisplay == true then
        settingsList:drawInRect(0, 0, 400, 230)
      end

      gfx.drawRoundRect(20,13,360,209,screenRoundness)

      local crankChange = pd.getCrankChange()
      totalCrankDistance += crankChange

      if (pd.buttonJustPressed("up")) or (totalCrankDistance >= 25) then
        settingsList:selectPreviousRow()
        settingsList:scrollToRow(settingsList:getSelectedRow())
        totalCrankDistance = 0
      elseif (pd.buttonJustPressed("down")) or (totalCrankDistance <= -25) then
        settingsList:selectNextRow()
        settingsList:scrollToRow(settingsList:getSelectedRow())
        totalCrankDistance = 0
      end

      if pd.buttonJustPressed("a") then
        local row = settingsList:getSelectedRow()
        if row == 1 then
          darkMode = not darkMode
          swapColorMode(darkMode)
        elseif row == 2 then
          clockMode = not clockMode
        elseif row == 3 then
          showInfoEverywhere = not showInfoEverywhere
        elseif row == 4 then
          showVersion = not showVersion
        elseif row == 5 then
          if screenRoundness >= 1 and screenRoundness < 8 then
            if screenRoundness == 1 or screenRoundness == 6 then
              screenRoundness += 2
            else
              screenRoundness += 1
            end
          elseif screenRoundness >= 8 then
            screenRoundness = 1
          end
        elseif row == 6 then
          lockScreen = not lockScreen
          if lockScreen == true then
            lockTimer = timer.new((lockScreenTime*60)*1000, lockScreenFunc)
          end
        elseif row == 7 then
          if lockScreenTime >= 1 and lockScreenTime ~= 5 then
            lockScreenTime += 1
          elseif lockScreenTime == 5 then
            lockScreenTime = 1
          end
          lockTimer = timer.new((lockScreenTime*60)*1000, lockScreenFunc)
        end

        settings = newSettingsList()
      elseif pd.buttonJustPressed("b") then
        screenMode = lastScreenMode
      end
    end
  end
  gfx.setImageDrawMode(gfx.kDrawModeNXOR)
  if currentAudio:isPlaying() == true and screenMode == 1 then
    playingGraphic:draw(10,210)
  elseif currentAudio:isPlaying() == false and screenMode == 1 then
    pausedGraphic:draw(10,210)
  end
  gfx.setImageDrawMode(dMColor1)
  -- updateCrank()

  --pd.drawFPS(0,0) -- only during dev DO NOT SHIP
end

function pd.gameWillTerminate()
  saveSettings()
end

currentAudio:setFinishCallback(handleSongEnd) -- this can cause probloms when didUnderrun() = true and that causes the length and offset to both = o and call this | to fix this i have implimented a stupidly complex sistem to verify that songs are playing at the corect time
currentAudio:setStopOnUnderrun(false)  -- does this actualy matter ## mess around with this
