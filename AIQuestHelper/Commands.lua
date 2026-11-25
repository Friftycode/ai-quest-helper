local _, ns = ...
local say, shown, ready = ns.say, ns.shown, ns.ready

BINDING_HEADER_AIQUESTHELPER = "AI Quest Helper"
BINDING_NAME_AIQUESTHELPER_SMART = "Copy what is open (quest, dialog, book)"
BINDING_NAME_AIQUESTHELPER_BAGS = "Copy bag contents (ID | name | count)"
BINDING_NAME_AIQUESTHELPER_GEAR = "Copy equipped gear (item level, stats, enchants)"
_G["BINDING_NAME_CLICK AIQuestHelperTarget:LeftButton"] = "Target quest mob: Mine"
_G["BINDING_NAME_CLICK AIQuestHelperTarget:RightButton"] = "Target quest mob: Party"

function AIQuestHelper_Smart()
	local text = ns.fromQuestDialog() or ns.fromGossip() or ns.fromItemText()
		or ((shown(WorldMapFrame) or shown(QuestLogFrame)) and ns.fromSelectedQuest()) or nil
	ready(text, nil)
end

function AIQuestHelper_Bags() ready(ns.fromBags(false, false), nil) end
function AIQuestHelper_Gear() ready(ns.fromGear(), nil) end

ns.copySmart = AIQuestHelper_Smart
ns.copyBags = AIQuestHelper_Bags
function ns.copyLearned() ready(ns.fromLearned(), nil) end

local function debug(name, file)
	return function()
		if ns[name] then ns[name]() else say(file .. " is not loaded: restart WoW completely.") end
	end
end

local function save()
	ns.snapshot()
	if InCombatLockdown() then say("Not in combat: try again after the fight.") else ReloadUI() end
end

local HELP = "/qc (what is open), /qc bags, /qc ids, /qc gear, /qc quest, /qc quests, /qc done, "
	.. "/qc config, /qc map, /qc threat, /qc tar, /qc arrow, /qc save, /qc ready"

local COMMANDS = {
	bags = function() ready(ns.fromBags(false, false), nil) end,
	ids = function() ready(ns.fromBags(true, false), nil) end,
	gear = function() ready(ns.fromGear(), nil) end,
	quests = function() ready(ns.fromWholeLog(), nil) end,
	quest = function() ready(ns.fromSelectedQuest(), nil) end,
	done = function() ready(ns.fromCompleted(), nil) end,
	threat = debug("threatDebug", "Threat.lua"),
	map = debug("mapDebug", "Map.lua"),
	ready = debug("toggleReady", "Ready.lua"),
	tar = debug("targetDebug", "Target.lua"),
	arrow = debug("arrowDebug", "Arrow.lua"),
	config = function() if ns.toggleOptions then ns.toggleOptions() end end,
	save = save,
	help = function() say(HELP) end,
}
COMMANDS.bag, COMMANDS.bagids, COMMANDS.log = COMMANDS.bags, COMMANDS.ids, COMMANDS.quests
COMMANDS.target, COMMANDS.options = COMMANDS.tar, COMMANDS.config

SLASH_AIQUESTHELPER1 = "/qc"
SLASH_AIQUESTHELPER2 = "/aqh"
SlashCmdList.AIQUESTHELPER = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	local cmd = COMMANDS[msg]
	if cmd then cmd() else AIQuestHelper_Smart() end
end
