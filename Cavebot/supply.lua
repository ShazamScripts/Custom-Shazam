CaveBot.Extensions.SupplyCheck = {}

local supplyRetries = 0
local missedChecks = 0
local rawRound = 0
local time = now
tyrBot.CaveBotData =
tyrBot.CaveBotData or
  {
    refills = 0,
    rounds = 0,
    time = {},
    lastRefill = os.time(),
    refillTime = {}
  }

local function setCaveBotData(hunting)
  if hunting then
    supplyRetries = supplyRetries + 1
  else
    supplyRetries = 0
    table.insert(tyrBot.CaveBotData.refillTime, os.difftime(os.time() - tyrBot.CaveBotData.lastRefill))
    tyrBot.CaveBotData.lastRefill = os.time()
    tyrBot.CaveBotData.refills = tyrBot.CaveBotData.refills + 1
  end

  table.insert(tyrBot.CaveBotData.time, rawRound)
  tyrBot.CaveBotData.rounds = tyrBot.CaveBotData.rounds + 1
  missedChecks = 0
end

CaveBot.Extensions.SupplyCheck.setup = function()
  CaveBot.registerAction(
    "supplyCheck",
    "#db5a5a",
    function(value)
      local data = string.split(value, ",")
      local round = 0
      rawRound = 0
      local label = data[1]:trim()
      local pos = nil
      if #data == 4 then
        pos = {x = tonumber(data[2]), y = tonumber(data[3]), z = tonumber(data[4])}
      end

      if pos then
        if missedChecks >= 4 then
          missedChecks = 0
          supplyRetries = 0
          print("CaveBot[SupplyCheck]: Missed 5 supply checks, proceeding with waypoints")
          return true
        end
        if getDistanceBetween(player:getPosition(), pos) > 10 then
          missedChecks = missedChecks + 1
          print("CaveBot[SupplyCheck]: Missed supply check! " .. 5 - missedChecks .. " tries left before skipping.")
          return CaveBot.gotoLabel(label)
        end
      end

      if time then
        rawRound = math.ceil((now - time) / 1000)
        round = rawRound .. "s"
      else
        round = ""
      end
      time = now

      local softCount = itemAmount(6529) + itemAmount(3549)


      if storage.forceRefill then
        print("CaveBot[SupplyCheck]: User forced, going back on refill. Last round took: " .. round)
        storage.forceRefill = false
        supplyRetries = 0
        missedChecks = 0
        return false
      elseif storage.backStop then
        print("CaveBot[SupplyCheck]: User forced, going back to city and turning off CaveBot. Last round took: " .. round)
        supplyRetries = 0
        missedChecks = 0
        return false
      elseif storage.backTrainers then
        print("CaveBot[SupplyCheck]: User forced, going back to city, then on trainers. Last round took: " .. round)
        supplyRetries = 0
        missedChecks = 0
        return false
      elseif storage.backOffline then
        print("CaveBot[SupplyCheck]: User forced, going back to city, then on offline training. Last round took: " .. round)
        supplyRetries = 0
        missedChecks = 0
        return false
      elseif supplyRetries > (50) then
        print("CaveBot[SupplyCheck]: Round limit reached, going back on refill. Last round took: " .. round)
        setCaveBotData()
        return false
      else
        print("CaveBot[SupplyCheck]: Enough supplies. Hunting. Round (" .. supplyRetries .. "/" .. (50) .. "). Last round took: " .. round)
        setCaveBotData(true)
        return CaveBot.gotoLabel(label)
      end
    end
  )

  CaveBot.Editor.registerAction(
    "supplycheck",
    "supply check",
    {
      value = function()
        return "startHunt," .. posx() .. "," .. posy() .. "," .. posz()
      end,
      title = "Supply check label",
      description = "Insert here hunting start label",
      validation = [[[^,]+,\d{1,5},\d{1,5},\d{1,2}$]]
    }
  )
end