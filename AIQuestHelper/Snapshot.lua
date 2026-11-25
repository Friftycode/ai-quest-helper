local _, ns = ...
local call = ns.call

-- The same AI-friendly text as the copy buttons, kept in AIQuestHelperDB.snapshot.
-- WoW writes SavedVariables only on /reload or logout, so "/qc save" reloads.
local DELAY = 5
local EVENTS = {
	"PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP",
	"PLAYER_XP_UPDATE", "PLAYER_MONEY", "ZONE_CHANGED_NEW_AREA", "SKILL_LINES_CHANGED",
	"CHARACTER_POINTS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LOGOUT",
}

local function skills()
	local out = {}
	for i = 1, (call(GetNumSkillLines) or 0) do
		local name, header, _, rank, _, _, max = call(GetSkillLineInfo, i)
		if name and not header and max and max > 1 then out[#out + 1] = string.format("%s %d/%d", name, rank or 0, max) end
	end
	return out
end

-- Classic returns (name, icon, points); newer clients (id, name, description, icon, points).
local function talents()
	local out = {}
	for t = 1, (call(GetNumTalentTabs) or 0) do
		local r = { call(GetTalentTabInfo, t) }
		local name, points = r[1], r[3]
		if type(r[1]) == "number" then name, points = r[2], r[5] end
		out[#out + 1] = string.format("%s %s", tostring(name), tostring(points))
	end
	return out
end

local function build()
	local s = { time = date("%Y-%m-%d %H:%M:%S") }
	s.player = {
		name = UnitName("player"), level = UnitLevel("player"),
		class = select(2, UnitClass("player")), race = select(2, UnitRace("player")),
		xp = UnitXP("player"), xpMax = UnitXPMax("player"), restedXp = GetXPExhaustion and GetXPExhaustion() or 0,
		money = GetMoney(), zone = GetRealZoneText(), subzone = GetSubZoneText(),
	}
	local pt = ns.playerPoint()
	if pt then s.player.map, s.player.x, s.player.y = pt[1], pt[2], pt[3] end
	s.context = call(ns.playerContext)
	s.questLog = call(ns.fromWholeLog)
	s.bagsAndGear = call(ns.fromBags, false, true)
	s.gear = call(ns.fromGear)
	s.skills = skills()
	s.talents = talents()
	ns.db().snapshot = s
end

function ns.snapshot() pcall(build) end

local wait, dirty = 0, true
local frame = CreateFrame("Frame")
for _, e in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, e) end
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGOUT" then ns.snapshot() return end
	if not dirty then wait = DELAY end
	dirty = true
end)
frame:SetScript("OnUpdate", function(_, elapsed)
	if not dirty then return end
	wait = wait - elapsed
	if wait > 0 or InCombatLockdown() then return end
	dirty = false
	ns.snapshot()
end)
