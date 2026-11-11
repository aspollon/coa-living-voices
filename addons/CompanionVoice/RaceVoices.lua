-- CoA Custom races: which stock voice each one speaks with. The race key is ChrRaces' client file name
-- (UnitRace's second value). The player's own choices (db.raceVoices, AFK Realm's page) win over this table.
local MAP = {
  Goblin = "gnome", Worgen = "human", KulTiran = "human", DarkIronDwarf = "dwarf", DarkIron = "dwarf",
  Vulpera = "gnome", VulperaEsteria = "gnome", Pandaren = "dwarf", HighElf = "bloodelf", VoidElf = "bloodelf",
  Nightborne = "nightelf", Lightforged = "draenei", LightforgedDraenei = "draenei", Eredar = "draenei",
  Broken = "draenei", MagharOrc = "orc", FelOrc = "orc", Highmountain = "tauren", HighmountainTauren = "tauren",
  Taunka = "tauren", ZandalariTroll = "troll", DrakkariTroll = "troll", ForestTroll = "troll", IceTroll = "troll",
  LeperTroll = "troll", Mechagnome = "gnome", Earthen = "dwarf", Tuskarr = "dwarf", Troglodyte = "dwarf",
  Vrykul = "human", ThinHuman = "human", HumanCultist = "human", Skeleton = "undead", NorthrendSkeleton = "undead",
  Naga = "nightelf", Sylvari = "nightelf", Ogre = "orc", Centaur = "tauren", Saberon = "orc", Satyr = "nightelf",
  Dracthyr = "bloodelf", Faceless = "undead", FacelessOne = "undead", Nerubian = "undead", Sporeling = "gnome",
  Grummle = "gnome", Kyrian = "human", Venthyr = "bloodelf", Titan = "dwarf", Qiraji = "undead",
}
-- a name not listed: by what it contains (ZandalariTroll -> troll), else nil (the add-on then speaks as a human)
local PARTS = { { "elf", "bloodelf" }, { "troll", "troll" }, { "orc", "orc" }, { "dwarf", "dwarf" },
                { "gnome", "gnome" }, { "draenei", "draenei" }, { "tauren", "tauren" }, { "undead", "undead" },
                { "skeleton", "undead" }, { "human", "human" } }

CompanionVoiceRaces = {}

function CompanionVoiceRaces.lookup(race, own)
  if own and own[race] then return own[race] end
  if MAP[race] then return MAP[race] end
  local l = race:lower()
  for _, p in ipairs(PARTS) do if l:find(p[1], 1, true) then return p[2] end end
end

-- AFK Realm writes AFKDefaults.lua; a new stamp means its page changed, so its values replace the saved ones once.
-- Settings changed in game afterwards stay until AFK's page changes again.
function CompanionVoiceRaces.applyAFK(db)
  local a = CompanionVoiceAFK
  if type(a) ~= "table" or not a.stamp or db.afkStamp == a.stamp then return end
  for k, v in pairs(a.settings or {}) do db[k] = v end
  for race, voice in pairs(a.raceVoices or {}) do db.raceVoices[race] = voice end
  db.afkStamp = a.stamp
end
