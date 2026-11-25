local _, ns = ...

ns.DEFAULTS = {
	iconQuestMap = true, iconDialog = true, iconBags = true, iconBook = true,
	mapZoneLevels = true, mapDungeons = true, mapRaids = true, mapColors = true, mapSearch = true, mapPinScale = 1,
	exportQuestie = true, exportBags = true, learnItems = true, threatPlates = true,
	questArrow = true, questArrowLock = false,
	questTarget = true, questTargetLock = false, questTargetMarker = 8, questTargetFullHp = true, questTargetFallback = false,
}

local TABLES = { "givers", "options", "minimap", "learned", "kills" }

function ns.db()
	if type(AIQuestHelperDB) ~= "table" then AIQuestHelperDB = {} end
	for _, key in ipairs(TABLES) do
		if type(AIQuestHelperDB[key]) ~= "table" then AIQuestHelperDB[key] = {} end
	end
	return AIQuestHelperDB
end

function ns.opt(key)
	local v = ns.db().options[key]
	if v == nil then return ns.DEFAULTS[key] end
	return v
end

local REFRESH = { "refreshIcons", "refreshMap", "refreshThreat", "refreshArrow", "refreshTarget" }

function ns.setOpt(key, value)
	ns.db().options[key] = value
	for _, name in ipairs(REFRESH) do
		if ns[name] then ns[name]() end
	end
end
