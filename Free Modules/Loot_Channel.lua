
-- Loot Channel | By Shazam

local console = modules.game_console
local tabName = "Loot"

local function getLootTab()
  return console.getTab(tabName)
      or console.addTab(tabName, true)
end

getLootTab()

onTextMessage(function(mode, text)
  if type(text) ~= "string" then return end
  if not text:find("Loot of", 1, true) then return end

  local tab = getLootTab()
  if not tab then return end

  -- Preserva o texto original completo
  local fullText = os.date("%H:%M") .. " " .. text

  -- Adiciona diretamente a mensagem completa
  -- sem dividir por ":" ou manipular partes
  console.addText(fullText, {
    color = "#00EB00"
  }, tabName, "")
end)
