-- Companion Voice: party, whisper, say and yell spoken aloud, each speaker in a voice that fits their race and sex.
-- CoA64 fork: say/yell (players and NPCs), CoA Custom races (RaceVoices.lua) and AFK Realm defaults (AFKDefaults.lua).
-- The speech runs on this machine (the LivingVoices64 plugin's CompanionVoiceEngine and its helper process). Channels
-- are never spoken. Every line is cloned from the speaker's neutral reference; the text's own punctuation
-- moves the voice (the excited delivery references drifted too far, 2026-11-05). On a realm with the server add-on
-- (mod-companion-voice), every line a bot's language model writes comes with a hidden label, and the realm says which
-- group members are bots: a bot's line WITHOUT a label is one nobody wrote for speaking (playerbots' "Quest
-- Incompleted: ..." status whispers) and stays silent; players are always spoken. On any other server the settings
-- decide (Options.lua: who is heard, the lines never to speak, voices per person, speed and limits).

local ADDON_PREFIX = "CVOX"
local MAX_QUEUE = 6          -- lines waiting at most; past that the oldest is dropped (a busy party, not a bot's two-part line)
local LABEL_WAIT = 1.5       -- seconds a known bot's line waits for its label before it counts as unlabelled
local LABEL_AGE = 60         -- seconds a delivery label waits for its line (the realm sends it when the line is
                             -- queued, which can be well before the bot says it)
local VOICE_DIR = "Interface\\AddOns\\CompanionVoice\\voices\\"
local DELIVERIES = { neutral = true, urgent = true, amused = true, weary = true }
local RACES = { Human = "human", Dwarf = "dwarf", Gnome = "gnome", NightElf = "nightelf", Draenei = "draenei",
                Orc = "orc", Scourge = "undead", Tauren = "tauren", Troll = "troll", BloodElf = "bloodelf" }

-- stock playerbots' status whispers and party lines (its TellMaster texts), never meant to be heard: the skip list
-- starts with these, and the player edits it. "^" means "starts with"; anything else matches anywhere. No case.
local DEFAULT_SKIP = { "^Quest Incompleted", "^Quest Available", "^Quest Failed", "^Quest completed", "^Quest accepted",
                       "^Quest shared", "^Quest removed", "^Quest log is full", "^Reward pending", "^Choose reward",
                       "^Cannot accept", "^Cannot talk to quest giver", "^Bags are full", "^Already completed",
                       "^Already on" }

local DEFAULTS = { on = true, volume = 1, speed = 1.0, party = true, whisper = true, say = true, yell = true,
                   npcSay = true, npcYell = true, fromGroup = true,
                   fromFriends = true, fromGuild = true, fromOthers = true, companionsOnly = false,
                   quietInCombat = false, maxChars = 300, maxWait = 30 }

local CV = {}            -- shared with Options.lua
CompanionVoice = CV
local db
local queue, labels = {}, {}
local warned = {}
local friends, guild = {}, {}
local engine = CompanionVoiceEngine   -- nil without LivingVoices.dll 0.5+

local function say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffCompanion Voice|r: " .. msg) end
local function warnOnce(key, msg) if not warned[key] then warned[key] = true; say(msg) end end
CV.say = say

-- FNV-1a, 32 bits: the server add-on hashes a line's text the same way, so a label finds its line. Plain arithmetic,
-- exact in Lua's doubles (the client's bit library is not trusted with values above 2^31).
local function xor8(a, b)
  local r, p = 0, 1
  for _ = 1, 8 do
    local x, y = a % 2, b % 2
    if x ~= y then r = r + p end
    a, b, p = (a - x) / 2, (b - y) / 2, p * 2
  end
  return r
end
local function fnv(s)
  local h = 2166136261
  for i = 1, #s do
    local lo = h % 256
    h = h - lo + xor8(lo, s:byte(i))
    h = ((h % 256) * 16777216 + h * 403) % 4294967296   -- h * 16777619 mod 2^32 (2^24 + 403)
  end
  return h
end

local function shortName(name) return name and (name:match("^([^%-]+)") or name) end

-- what is said, as it would be heard: links become their text, colours, icons and raid marks go, and so does
-- an *action* (the bot does it, as an emote; it is not spoken)
local function clean(s)
  s = s:gsub("%*[^%*]*%*", " ")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("|H.-|h%[?(.-)%]?|h", "%1")
  s = s:gsub("|T.-|t", ""):gsub("|K.-|k", ""):gsub("{.-}", "")
  s = s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  return s
end

-- what the voice reads: Living Voices' pronunciation guide (Pronounce.lua) -- whole-word respellings (Dalaran ->
-- Dahlarawn; a possessive keeps its ending), '-shire' place names by the voice's accent, and the troll dialect for a
-- troll's voice. Only the text sent to the engine; chat, labels and the skip list see the line as written.
local function speakable(text, take)
  local P = CompanionVoicePronounce
  if not P then return text end
  local race = take and take:match("^r%d_(%a+)_%a_%a$")
  text = text:gsub("\226\128\153", "'")                          -- a typographic apostrophe, as the guide keys are plain
  text = text:gsub("[%a][%w']*", function(w)
    local r = P.words[w]
    if r then return r end
    local base, tail = w:match("^(.-)('%a*)$")                  -- Dalaran's -> Dahlarawn's
    if base and P.words[base] then return P.words[base] .. tail end
  end)
  text = text:gsub("[Xx]%-52", function(w) return P.words[w] end)
  for suf, r in pairs(P.suffix) do
    local said = (race and P.british[race]) and r.british or r.neutral
    text = text:gsub("(%u%l+)" .. suf .. "(%f[%A])", "%1" .. said .. "%2")
    text = text:gsub("(%u%l+)" .. suf .. "$", "%1" .. said)
  end
  local D = race and P.dialect[race]
  if D then
    text = text:gsub("[%a]+", function(w)
      local r = D.words[w] or D.words[w:lower()]
      if r then return w:sub(1, 1):match("%u") and (r:sub(1, 1):upper() .. r:sub(2)) or r end
      if D.ing and #w >= 6 and w:match("[^aeiouAEIOU]ing$") then return w:sub(1, -4) .. "in'" end   -- as the guide: 6+ letters
    end)
  end
  return text
end
CV.speakable = speakable

CV.clean = clean

-- the player's own list of lines never to speak (Options: "Lines not spoken")
local function skipped(text)
  local t = text:lower()
  for _, e in ipairs(db.skip) do
    local s = e:lower()
    if s:sub(1, 1) == "^" then
      s = s:sub(2)
      if s ~= "" and t:sub(1, #s) == s then return true end
    elseif s ~= "" and t:find(s, 1, true) then return true end
  end
end

local function partyUnit(name)
  for i = 1, 4 do
    local unit = "party" .. i
    if UnitExists(unit) and UnitName(unit) == name then return unit end
  end
end

-- who may be heard: group members, friends, guild, and everyone else, each switched on or off
local function allowedSender(name)
  local any, inGroup = false, partyUnit(name) ~= nil
  if inGroup then any = true; if db.fromGroup then return true end end
  if friends[name] then any = true; if db.fromFriends then return true end end
  if guild[name] then any = true; if db.fromGuild then return true end end
  return not any and db.fromOthers
end

-- race and sex: a party member's unit, or the whisper's sender GUID (the client knows it once it has seen them)
local function raceVoice(race)
  if not race then return nil end
  return RACES[race] or (CompanionVoiceRaces and CompanionVoiceRaces.lookup(race, db and db.raceVoices))
end
CV.raceVoice = raceVoice

local function unitNamed(name)   -- a unit the client can ask about, for nearby speakers outside the group
  local unit = partyUnit(name)
  if unit then return unit end
  for _, u in ipairs({ "target", "focus", "mouseover", "targettarget" }) do
    if UnitExists(u) and UnitName(u) == name then return u end
  end
end

local function senderInfo(name, guid)
  local unit = unitNamed(name)
  if unit and UnitIsPlayer(unit) then
    local _, race = UnitRace(unit)
    return raceVoice(race), UnitSex(unit)
  end
  if guid and guid ~= "" and GetPlayerInfoByGUID then
    local _, _, _, race, sex = GetPlayerInfoByGUID(guid)
    if race then return raceVoice(race), sex end
  end
end

-- an NPC: its sex from a unit naming it, else from its name (it then always sounds the same); its race is unknown
local function npcInfo(name)
  local unit = unitNamed(name)
  if unit then
    local sex = UnitSex(unit)
    if sex == 2 or sex == 3 then return nil, sex end
  end
  return nil, fnv(name:lower()) % 3 == 0 and 3 or 2
end

local function hasTake(take)
  for _, list in pairs(CompanionVoiceVoices.takes) do
    for _, t in ipairs(list) do if t == take then return true end end
  end
end

-- a speaker's voice: the player's choice for them if any (Options: "Voices"); else a take of their race and sex and
-- one of its variants, both from their name, so they always sound the same (an unknown race speaks as a human of that
-- sex; an unknown sex is not spoken)
local function voiceFor(name, race, sex)
  local pick = db and db.voices[name:lower()]
  if pick and hasTake(pick.take) then return pick.take, math.min(pick.variant or 0, CompanionVoiceVoices.variants - 1) end
  local key = (race or "human") .. (sex == 3 and "_f" or "_m")
  local takes = CompanionVoiceVoices.takes[key] or CompanionVoiceVoices.takes["human" .. (sex == 3 and "_f" or "_m")]
  if not takes or (sex ~= 2 and sex ~= 3) then return nil end
  local h = fnv(name:lower())
  return takes[h % #takes + 1], math.floor(h / 7) % CompanionVoiceVoices.variants
end
CV.voiceFor = voiceFor

local function refFor(take, variant)
  return VOICE_DIR .. take .. "_" .. variant .. "_neutral.mp3"
end

local function realmDB()
  local realm = GetRealmName()
  db.realms[realm] = db.realms[realm] or { labels = false, bots = {} }
  return db.realms[realm]
end

local function takeLabel(sender, text)
  local list = labels[sender]
  if not list then return nil end
  local h, now = fnv(text), GetTime()
  for i = #list, 1, -1 do
    local l = list[i]
    if now - l.t > LABEL_AGE then table.remove(list, i)
    elseif l.hash == h then table.remove(list, i); return l.delivery end
  end
end

local CHANNEL = { CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_WHISPER = "whisper",
                  CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell",
                  CHAT_MSG_MONSTER_SAY = "npcSay", CHAT_MSG_MONSTER_YELL = "npcYell" }
local NPC = { npcSay = true, npcYell = true }

local function onChat(event, msg, author, guid)
  local channel = CHANNEL[event]
  if not db.on or not engine or not db[channel] then return end
  local name = shortName(author)
  if not name or name == UnitName("player") or db.muted[name:lower()] then return end
  local npc = NPC[channel]
  if not npc and not allowedSender(name) then return end
  local text = clean(msg)
  if not text:find("%a") or #text > db.maxChars or skipped(text) then return end
  local race, sex
  if npc then race, sex = npcInfo(name) else race, sex = senderInfo(name, guid) end
  local take, variant = voiceFor(name, race, sex)
  if not take then return end
  queue[#queue + 1] = { name = name, raw = msg, take = take, variant = variant, text = text, t = GetTime(), npc = npc }
  while #queue > MAX_QUEUE do table.remove(queue, 1) end
end

-- a line in a chosen voice, now (Options' preview and /cvoice test)
function CV.preview(take, variant, text)
  if not engine then return say("the client patch is missing (LivingVoices.dll 0.5 or later).") end
  table.insert(queue, 1, { ref = refFor(take, variant), text = text, t = GetTime() })
end

function CV.stop()
  queue = {}
  if engine then engine.Stop() end
end

function CV.apply()   -- settings that act at once
  if engine then engine.SetVolume(db.volume) end
  if not db.on then CV.stop() end
end

local function muted()   -- the game's own sound settings: all sound off, or in the background with that sound off
  if GetCVar("Sound_EnableAllSound") == "0" then return true end
  if GetCVar("Sound_EnableSoundWhenGameIsInBG") == "0" and LivingVoices and LivingVoices.IsForeground
     and not LivingVoices.IsForeground() then return true end
end

local function busy()
  if engine.IsSpeaking() then return true end
  return LivingVoices and LivingVoices.IsPlaying and LivingVoices.IsPlaying()   -- never over a quest voice line
end

local elapsed = 0
local function onUpdate(self, dt)
  elapsed = elapsed + dt
  if elapsed < 0.1 then return end
  elapsed = 0
  if #queue == 0 or busy() then return end
  local now = GetTime()
  local item = table.remove(queue, 1)
  while item and now - item.t > db.maxWait do item = table.remove(queue, 1) end
  if not item or muted() then return end
  if item.name and db.quietInCombat and UnitAffectingCombat("player") then return end
  -- the label is looked up now: on the realm it may have come before the line, or just after it
  local labelled = item.name and not item.npc and takeLabel(item.name, item.raw)
  if item.name and not item.npc and not labelled then
    local r = realmDB()
    if r.labels and r.bots[item.name] then                -- a bot's line nobody labelled: wait briefly, then skip
      if now - item.t < LABEL_WAIT then table.insert(queue, 1, item) end
      return
    end
    if db.companionsOnly then return end
  end
  local ref = item.ref or refFor(item.take, item.variant)
  local master = tonumber(GetCVar("Sound_MasterVolume")) or 1
  local ok, err = engine.Speak(ref, speakable(item.text, item.take), master, db.speed)
  if not ok then warnOnce("speak", "cannot speak: " .. tostring(err)) end
end

local function readFriends()
  wipe(friends)
  for i = 1, GetNumFriends() do
    local name = GetFriendInfo(i)
    if name then friends[name] = true end
  end
end

local function readGuild()
  wipe(guild)
  if not IsInGuild() then return end
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    if name then guild[name] = true end
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
for _, e in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
                     "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_ADDON",
                     "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE" }) do f:RegisterEvent(e) end
f:SetScript("OnEvent", function(self, event, a1, a2, a3, a4, ...)
  if event == "PLAYER_LOGIN" then
    CompanionVoiceDB = CompanionVoiceDB or {}
    db = CompanionVoiceDB
    CV.db = db
    for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
    if db.who == "companions" then db.companionsOnly = true end   -- (0.1's setting)
    db.who = nil
    db.muted = db.muted or {}
    db.realms = db.realms or {}
    db.voices = db.voices or {}
    db.raceVoices = db.raceVoices or {}
    if CompanionVoiceRaces then CompanionVoiceRaces.applyAFK(db) end
    if not db.skip then db.skip = {}; for i, e in ipairs(DEFAULT_SKIP) do db.skip[i] = e end end
    readFriends()
    if IsInGuild() then GuildRoster() end
    if CV.optionsReady then CV.optionsReady() end
    if not engine then
      say("needs the Living Voices client patch (LivingVoices.dll 0.5 or later). Nothing will be spoken.")
      return
    end
    engine.SetVolume(db.volume)
    self:SetScript("OnUpdate", onUpdate)
  elseif event == "FRIENDLIST_UPDATE" then
    readFriends()
  elseif event == "GUILD_ROSTER_UPDATE" then
    readGuild()
  elseif event == "CHAT_MSG_ADDON" then
    if a1 ~= ADDON_PREFIX or a3 ~= "WHISPER" or not db then return end
    local name = shortName(a4)
    local bots = a2:match("^bots\t(.*)$")
    if bots then                                          -- the realm, to me: the bots in my group
      if name ~= UnitName("player") then return end
      local r = realmDB(); r.labels = true
      for b in bots:gmatch("[^,]+") do r.bots[b] = true end
      return
    end
    local delivery, hash = a2:match("^(%a+)\t(%d+)$")
    if not delivery or not DELIVERIES[delivery] then return end
    local r = realmDB(); r.bots[name] = true   -- only a bot's language-model line is labelled
    -- (r.labels, the filter, is switched on only by the bot list: only a realm that sends it labels every line)
    labels[name] = labels[name] or {}
    table.insert(labels[name], { delivery = delivery, hash = tonumber(hash), t = GetTime() })
  elseif db then
    onChat(event, a1, a2, select(8, ...))   -- arg12: the sender's GUID
  end
end)

CV.DEFAULTS, CV.DEFAULT_SKIP = DEFAULTS, DEFAULT_SKIP

SLASH_COMPANIONVOICE1 = "/cvoice"
SlashCmdList.COMPANIONVOICE = function(input)
  if not db then return end
  local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "on" or cmd == "off" then
    db.on = cmd == "on"; CV.apply()
    say(db.on and "on." or "off.")
  elseif cmd == "volume" and tonumber(rest) then
    db.volume = math.max(0, math.min(100, tonumber(rest))) / 100; CV.apply()
    say(("volume %d%%."):format(db.volume * 100))
  elseif cmd == "speed" and tonumber(rest) then
    db.speed = math.max(0.7, math.min(1.5, tonumber(rest)))
    say(("speed %.2f."):format(db.speed))
  elseif (cmd == "mute" or cmd == "unmute") and rest ~= "" then
    db.muted[rest:lower()] = cmd == "mute" or nil
    say(rest .. (cmd == "mute" and " muted." or " unmuted."))
  elseif cmd == "stop" then
    CV.stop()
  elseif cmd == "test" then
    local _, race = UnitRace("player")
    local take, variant = voiceFor(UnitName("player"), raceVoice(race), UnitSex("player"))
    CV.preview(take, variant, "Right, that's the last of them. Shall we move on?")
    say("your own voice, if you were a companion: " .. (CV.takeLabel and CV.takeLabel(take) or take) .. ", variant " .. (variant + 1) .. ".")
  elseif cmd == "status" then
    if not engine then return say("the client patch is missing (LivingVoices.dll 0.5 or later).") end
    local st, why = engine.Status()
    say(("%s; engine %s%s; volume %d%%; speed %.2f; %d waiting."):format(db.on and "on" or "off", st,
        why and (" (" .. why .. ")") or "", db.volume * 100, db.speed, #queue))
  elseif cmd == "" or cmd == "options" or cmd == "config" then
    if CV.openOptions then CV.openOptions() end
  else
    say("/cvoice (options) | on | off | volume 0-100 | speed 0.7-1.5 | mute <name> | unmute <name> | stop | test | status")
  end
end
