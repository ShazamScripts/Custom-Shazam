-- Auto Summon - OTCv8
-- Configuracao por janela, sem dependencias externas.

storage.shazamSummon = storage.shazamSummon or {
  jutsu = "",
  mensagem = "",
  nomes = "",
  intervalo = 850,
  quantidade = 2
}
local cfg = storage.shazamSummon
local ultimoCast = 0
local confirmado = false
local aguardando = false
local vistoNaTela = false
local proximaTentativa = 0

local function normalizar(s)
  return tostring(s or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

-- Quantidade escolhida na janela; tambem aceita override Nome x2.
-- Cada criatura e contada separadamente, mesmo com o mesmo nome.
local nomesCacheTexto, nomesCache, totalNecessario = nil, {}, 0
local function nomesConfigurados()
  local qtdPadrao = math.max(1, math.min(20, math.floor(tonumber(cfg.quantidade) or 1)))
  local texto = normalizar(cfg.nomes)
  local chave = texto .. "|" .. qtdPadrao
  if chave ~= nomesCacheTexto then
    nomesCacheTexto, nomesCache, totalNecessario = chave, {}, 0
    for entrada in texto:gmatch("[^,\n]+") do
      entrada = normalizar(entrada)
      local nome, qtd = entrada:match("^(.-)%s+x%s*(%d+)$")
      if not nome then nome, qtd = entrada, qtdPadrao end
      nome = normalizar(nome)
      qtd = math.min(tonumber(qtd) or 1, 20)
      if nome ~= "" and qtd > 0 then
        nomesCache[nome] = (nomesCache[nome] or 0) + qtd
        totalNecessario = totalNecessario + qtd
      end
    end
  end
  return nomesCache, totalNecessario
end

local function verificar()
  local exigidos, total = nomesConfigurados()
  if total == 0 then return nil end
  local encontrados, presentes = {}, 0
  for _, criatura in ipairs(getSpectators() or {}) do
    if criatura:isMonster() then
      local nome = normalizar(criatura:getName())
      local limite = exigidos[nome]
      if limite and (encontrados[nome] or 0) < limite then
        encontrados[nome] = (encontrados[nome] or 0) + 1
        presentes = presentes + 1
        if presentes >= total then break end
      end
    end
  end
  return presentes >= total, presentes
end

-- Mesma disposicao do Travel System: macro a esquerda, Config a direita.
local janela = setupUI([[
Panel
  height: 17

  BotSwitch
    id: ativar
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr("Auto Summon")

  Button
    id: config
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Config
]])

local configUI = setupUI([[
MainWindow
  id: summonWindow
  size: 340 305
  text: Auto Summon - Config
  @onSetup: self:hide()
  @onEscape: self:hide()

  Label
    text: Nome do Jutsu
    anchors.top: parent.top
    anchors.left: parent.left
    margin-top: 12
    margin-left: 12
  TextEdit
    id: jutsu
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-top: 3
    height: 24

  Label
    text: Mensagem laranja (trecho)
    anchors.top: jutsu.bottom
    anchors.left: parent.left
    margin-top: 9
    margin-left: 12
  TextEdit
    id: mensagem
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-top: 3
    height: 24

  Label
    text: Nomes dos summons (separados por virgula)
    anchors.top: mensagem.bottom
    anchors.left: parent.left
    margin-top: 9
    margin-left: 12
  TextEdit
    id: nomes
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-top: 3
    height: 24

  Label
    text: Quantidade por nome (1 a 20)
    anchors.top: nomes.bottom
    anchors.left: parent.left
    margin-top: 9
    margin-left: 12
  TextEdit
    id: quantidade
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-top: 3
    height: 24

  Button
    id: salvar
    text: Salvar e fechar
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-bottom: 10
    height: 25
]], g_ui.getRootWidget())

local jaViuSummon = false

local function salvar()
  cfg.jutsu = configUI.jutsu:getText()
  cfg.mensagem = configUI.mensagem:getText()
  cfg.nomes = configUI.nomes:getText()
  cfg.quantidade = math.max(1, math.min(20, math.floor(tonumber(configUI.quantidade:getText()) or 1)))
  confirmado = false
  aguardando = false
  vistoNaTela = false
  proximaTentativa = 0
  jaViuSummon = false
  configUI:hide()
end

janela.config.onClick = function()
  configUI.jutsu:setText(cfg.jutsu or "")
  configUI.mensagem:setText(cfg.mensagem or "")
  configUI.nomes:setText(cfg.nomes or "")
  configUI.quantidade:setText(tostring(cfg.quantidade or 2))
  configUI:show()
  configUI:raise()
  configUI:focus()
end
configUI.salvar.onClick = salvar

-- Invocacao insistente durante combate, baseada na macro Katsuyu.
-- Intervalo curto entre tentativas; a presenca dos summons encerra o spam.
local proximoJutsu = 0
local proximoKai = 0
local liberarJutsuEm = 0
local intervaloJutsu = 200 -- ms; ajuste se o servidor limitar o chat
local intervaloKai = 1200
local esperaAposKai = 250

local summonMacro = macro(50, function()
  if not g_game.isOnline() or normalizar(cfg.jutsu) == "" then return end
  local todos, presentes = verificar()
  if todos == nil then return end
  local tempo = now

  if presentes > 0 then jaViuSummon = true end
  if todos then
    confirmado = true
    aguardando = false
    return
  end

  -- Quando todos desaparecerem depois de vistos, libera invocacao com kai.
  if presentes == 0 and jaViuSummon then
    if tempo < proximoKai then return end
    say("kai")
    proximoKai = tempo + intervaloKai
    liberarJutsuEm = tempo + esperaAposKai
    proximoJutsu = liberarJutsuEm
    jaViuSummon = false
    confirmado = false
    aguardando = false
    return
  end

  if tempo < liberarJutsuEm or tempo < proximoJutsu then return end
  proximoJutsu = tempo + intervaloJutsu
  ultimoCast = tempo
  aguardando = true
  -- Nao aguarda resposta do servidor: insiste mesmo atacando monstros.
  say(cfg.jutsu)
end)

-- Botao esquerdo alterna o macro, como no Travel System.
-- A cor segue o estilo do botao da custom (ativo/inativo).
cfg.ativo = cfg.ativo == true
summonMacro.setOn(cfg.ativo)
local function atualizarBotao()
  janela.ativar:setOn(cfg.ativo)
end
atualizarBotao()
janela.ativar.onClick = function()
  cfg.ativo = not cfg.ativo
  summonMacro.setOn(cfg.ativo)
  atualizarBotao()
end

onTextMessage(function(mode, texto)
  if not summonMacro:isOn() then return end
  local trecho = normalizar(cfg.mensagem)
  if trecho == "" or not aguardando then return end
  if normalizar(texto):find(trecho, 1, true) then
    confirmado = true
    aguardando = false
  end
end)
