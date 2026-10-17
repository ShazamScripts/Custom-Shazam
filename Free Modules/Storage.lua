-- ============================================================================
-- SHAZAM SCRIPTS - STORAGE POR NTO + PERSONAGEM
-- ============================================================================
-- Cada personagem possui seu proprio arquivo, dentro da pasta do NTO:
--   /ShazamScripts/<NomeNTO>/Storage_<NickDoPersonagem>.json
--
-- Ex.: /ShazamScripts/NTO_Imperial/Storage_Shazam.json
--      /ShazamScripts/NTO_Ultimate/Storage_Outro_Nick.json
--
-- O <NomeNTO> vem do nome do mundo do servidor (g_game.getWorldName()), ou do
-- valor que voce escrever em NTO_NAME_OVERRIDE logo abaixo.
--
-- IMPORTANTE: se o personagem ainda NAO tem arquivo nessa pasta, ele comeca
-- LIMPO (Especiais, Combo, Fugas etc. zerados). O storage nativo que veio junto
-- com a pasta da custom (storage/profile_1.json) NAO e mais copiado.
-- ============================================================================

-- Se o nome automatico nao ficar bom, escreva aqui. Ex.: "NTO_Imperial"
local NTO_NAME_OVERRIDE = nil

-- Migracao do formato antigo (/Scripts Shazam/Custom Otimizada/<Nick>_Storage.json).
-- Coloque AQUI so os nicks que ja tinham config boa (ex.: o do Imperial).
-- Nao coloque o nick do Ultimate: o arquivo antigo dele foi contaminado.
local MIGRAR_DO_ANTIGO = {
  -- "NickDoPersonagemImperial",
}

local SHAZAM_ROOT_DIR = "/ShazamScripts"
local SHAZAM_OLD_DIR = "/Scripts Shazam/Custom Otimizada"
local SHAZAM_OWNER = "SHAZAM_SCRIPTS_OTIMIZADA"
local OWNER_KEY = "__shazam_owner"
local shazamStorageDir = nil
local shazamStorageFile = nil
local shazamStorageLastSnapshot = nil

local function sanitizeName(name, fallback)
  name = tostring(name or "")
  name = name:gsub("[^%w_%-]", "_")
  return name ~= "" and name or fallback
end

local function safeCharacterName(name)
  return sanitizeName(name, "Unknown")
end

-- Pasta unica e estavel, independente do estado da conexao.
local function getShazamNtoName()
  return sanitizeName(NTO_NAME_OVERRIDE or "NTOUniverse", "NTOUniverse")
end

-- Exposto para o Jump.lua usar a mesma pasta de NTO.
function ShazamGetNtoName()
  return getShazamNtoName()
end

local function ensureShazamStorageDir()
  shazamStorageDir = SHAZAM_ROOT_DIR .. "/" .. getShazamNtoName()
  if not g_resources.directoryExists(SHAZAM_ROOT_DIR) then
    g_resources.makeDir(SHAZAM_ROOT_DIR)
  end
  if not g_resources.directoryExists(shazamStorageDir) then
    g_resources.makeDir(shazamStorageDir)
  end
end

-- Limpa o storage do personagem MAS mantem a estrutura interna que o core do bot
-- e o CaveBot/TargetBot exigem (storage._macros, _icons e _configs). Se essas
-- tabelas sumirem, macro() e o CaveBot dao erro e o modulo nem termina de carregar.
local function wipeStorage()
  if type(storage) ~= "table" then
    storage = {}
  end

  local keepConfigs = storage._configs

  for key in pairs(storage) do
    storage[key] = nil
  end

  -- estados de macros (ligado/desligado) e posicao dos icones: sempre do zero
  storage._macros = {}
  storage._icons = {}

  -- _configs guarda so QUAL config de cave/target esta selecionada (os arquivos
  -- ficam nas pastas CavebotConfigs / Target Configs).
  if type(keepConfigs) ~= "table" then
    keepConfigs = {}
  end
  if type(keepConfigs.CavebotConfigs) ~= "table" then
    keepConfigs.CavebotConfigs = {data = {}, enabled = false}
  end
  if type(keepConfigs["Target Configs"]) ~= "table" then
    keepConfigs["Target Configs"] = {
      data = {default = {looting = {containers = {}, items = {}, maxDanger = 10, minCapacity = 100, everyItem = false}, targeting = {}}},
      selected = "default",
      enabled = false
    }
  end
  storage._configs = keepConfigs
end

local function getShazamCharacterName()
  local name = nil

  pcall(function()
    if g_game and type(g_game.getCharacterName) == "function" then
      name = g_game.getCharacterName()
    end
  end)

  if not name or tostring(name) == "" then
    pcall(function()
      if g_game and type(g_game.getLocalPlayer) == "function" then
        local creature = g_game.getLocalPlayer()
        if creature and type(creature.getName) == "function" then
          name = creature:getName()
        end
      end
    end)
  end

  if not name or tostring(name) == "" then return nil end
  return safeCharacterName(name)
end

local function snapshotStorage()
  local result = {}
  if type(storage) ~= "table" then
    return result
  end

  for key, value in pairs(storage) do
    -- Jump possui um arquivo proprio (Jump_data.json), mas tambem permanece
    -- no Storage para compatibilidade com scripts que leem storage.jumps.
    result[key] = value
  end

  result[OWNER_KEY] = SHAZAM_OWNER
  return result
end

local function encodeStorage()
  local ok, encoded = pcall(function()
    return json.encode(snapshotStorage())
  end)

  if not ok or type(encoded) ~= "string" then
    return nil, encoded
  end

  return encoded
end

local function normalizeShazamStorage()
  if type(storage) ~= "table" then storage = {} end

  -- Estrutura base usada pelo CaveBot/TargetBot. Arquivos antigos podem ter
  -- esses campos ausentes (ou extras salvo como array), o que gera nil em
  -- operacoes numericas como * / < >.
  if type(storage.extras) ~= "table" then storage.extras = {} end
  storage.extras.talkDelay = tonumber(storage.extras.talkDelay) or 200
  storage.extras.gotoMaxDistance = tonumber(storage.extras.gotoMaxDistance) or 40
  storage.extras.huntRoutes = tonumber(storage.extras.huntRoutes) or 50
  storage.extras.lootDelay = tonumber(storage.extras.lootDelay) or 200
  storage.extras.looting = tonumber(storage.extras.looting) or 40
  storage.extras.killUnder = tonumber(storage.extras.killUnder) or 30

  -- Algumas funcoes da vlib assumem que playerList existe.
  if type(storage.playerList) ~= "table" then storage.playerList = {} end
  if type(storage.playerList.friendList) ~= "table" then storage.playerList.friendList = {} end
  if type(storage.playerList.enemyList) ~= "table" then storage.playerList.enemyList = {} end
  if type(storage.playerList.blackList) ~= "table" then storage.playerList.blackList = {} end
  if storage.playerList.groupMembers == nil then storage.playerList.groupMembers = false end
  if storage.playerList.marks == nil then storage.playerList.marks = false end

  if type(storage.caveBot) ~= "table" then storage.caveBot = {} end
  if type(storage.caveBotTasker) ~= "table" then
    storage.caveBotTasker = {inProgress=false, monster="", monster2="", taskName="", count=0, max=0}
  else
    storage.caveBotTasker.count = tonumber(storage.caveBotTasker.count) or 0
    storage.caveBotTasker.max = tonumber(storage.caveBotTasker.max) or 0
    storage.caveBotTasker.inProgress = storage.caveBotTasker.inProgress == true
    storage.caveBotTasker.monster = tostring(storage.caveBotTasker.monster or "")
    storage.caveBotTasker.monster2 = tostring(storage.caveBotTasker.monster2 or "")
    storage.caveBotTasker.taskName = tostring(storage.caveBotTasker.taskName or "")
  end

  storage.jumps = type(storage.jumps) == "table" and storage.jumps or {}
  storage.fugaSpells = type(storage.fugaSpells) == "table" and storage.fugaSpells or {}
  if type(storage.fugaSettings) ~= "table" then storage.fugaSettings = {isOn=false} end
  if storage.fugaSettings.isOn == nil then storage.fugaSettings.isOn = false end
end

local function setupShazamStorage()
  ensureShazamStorageDir()

  local characterName = getShazamCharacterName()
  if not characterName then
    return false -- nao criar Storage_Unknown durante login/logout
  end
  shazamStorageFile = shazamStorageDir .. "/Storage_" .. characterName .. ".json"
  shazamStorageLastSnapshot = nil

  -- Personagem sem arquivo nesta pasta de NTO: comeca LIMPO.
  -- (Opcional) migra o arquivo antigo, mas SO dos nicks listados em MIGRAR_DO_ANTIGO.
  if not g_resources.fileExists(shazamStorageFile) then
    wipeStorage()

    if table.find(MIGRAR_DO_ANTIGO, characterName) then
      local oldFile = SHAZAM_OLD_DIR .. "/" .. characterName .. "_Storage.json"
      if g_resources.fileExists(oldFile) then
        local ok, content = pcall(g_resources.readFileContents, oldFile)
        if ok and type(content) == "string" and content ~= "" then
          local decodedOk, old = pcall(json.decode, content)
          if decodedOk and type(old) == "table" then
            for key, value in pairs(old) do
              if key ~= OWNER_KEY then storage[key] = value end
            end
            print("[Shazam Scripts] Storage antigo migrado para: " .. shazamStorageFile)
          end
        end
      end
    end

    storage.jumps = storage.jumps or {}
    storage.extras = storage.extras or {}

    local encoded = encodeStorage()
    if encoded then
      pcall(g_resources.writeFileContents, shazamStorageFile, encoded)
      shazamStorageLastSnapshot = encoded
    end
    return
  end

  -- Arquivo existe: carrega.
  local ok, contents = pcall(g_resources.readFileContents, shazamStorageFile)
  if ok and type(contents) == "string" and contents ~= "" then
    local decodedOk, data = pcall(json.decode, contents)

    if decodedOk and type(data) == "table" and data[OWNER_KEY] == SHAZAM_OWNER then
      wipeStorage()
      for key, value in pairs(data) do
        if key ~= OWNER_KEY then
          storage[key] = value
        end
      end
      shazamStorageLastSnapshot = contents
    elseif decodedOk and type(data) == "table" then
      print("[Shazam Scripts] Arquivo ignorado (nao e desta custom): " .. shazamStorageFile)
    else
      print("[Shazam Scripts] Storage invalido: " .. shazamStorageFile)
    end
  end

  if type(storage) ~= "table" then
    storage = {}
  end
  normalizeShazamStorage()
end

function saveMyBotStorage(force)
  if ShazamGuard and not ShazamGuard.check() then
    return false
  end

  if not shazamStorageFile then
    if not setupShazamStorage() then return false end
  end

  local encoded, err = encodeStorage()
  if not encoded then
    print("[Shazam Scripts] Falha ao codificar Storage: " .. tostring(err))
    return false
  end

  if not force and encoded == shazamStorageLastSnapshot then
    return true
  end

  local ok, writeErr = pcall(g_resources.writeFileContents, shazamStorageFile, encoded)
  if not ok then
    print("[Shazam Scripts] Falha ao salvar " .. tostring(shazamStorageFile) .. ": " .. tostring(writeErr))
    return false
  end

  shazamStorageLastSnapshot = encoded
  return true
end

-- Storage e Jump precisam sempre existir como tabelas para os demais modulos.
if type(storage) ~= "table" then
  storage = {}
end
storage.jumps = storage.jumps or {}

setupShazamStorage()
normalizeShazamStorage()

if type(storage) ~= "table" then
  storage = {}
end
storage.jumps = storage.jumps or {}

-- Salva ao deslogar, trocar de personagem e fechar o bot/client.
-- connect protegido: se a Shazam nao estiver rodando, o handler se desliga sozinho
-- (antes ele ficava preso no g_game e podia derrubar o onGameStart de outras customs).
if g_game and ShazamGuard then
  ShazamGuard.connect(g_game, {
    onGameStart = function()
      if not setupShazamStorage() then return end
      normalizeShazamStorage()
      saveMyBotStorage(true)
      print("[Shazam Scripts] Personagem detectado. Storage: " .. tostring(shazamStorageFile))
    end,
    onGameEnd = function()
      saveMyBotStorage(true)
      shazamStorageFile = nil
    end
  })
end

if type(onExitRegister) == "function" then
  onExitRegister(function()
    saveMyBotStorage(true)
  end)
end

print("[Shazam Scripts] Storage ativo: " .. tostring(shazamStorageFile))
