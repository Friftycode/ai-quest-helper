local _, ns = ...
local call, clean = ns.call, ns.clean

local ANSWER_FORMAT = "\n## How to answer\n"
	.. "- Research the quest online first; do not answer from memory.\n"
	.. "- Very short. Only quests that belong to the goal we talk about (for example one dungeon), not other quests in the same area.\n"
	.. "- One block per quest, in this exact markdown format:\n\n"
	.. "### Quest name\n"
	.. "**Location:** zone, place (x, y)\n"
	.. "**Objective:** what to do\n"
	.. "**NPC:** who to turn in to (x, y) (only when the objectives are done or the next step is the NPC)\n"
	.. "**Use item in bag:** item name (only when the quest needs an item from the bags)\n"
	.. "**Respawn:** respawn time, or that it spawns again (only for a single named mob or object)\n\n"
	.. "- No /tar or target macros unless asked. No explanations, routes or lore."

function ns.aiHeader(what)
	return "# WoW Forever (Classic+) export: " .. what .. "\n"
		.. "Game: World of Warcraft: Forever, client " .. (call(GetBuildInfo) or "?")
		.. ". Date: " .. (date and date("%Y-%m-%d %H:%M") or "?") .. ".\n"
		.. "Use this data to help with the quest: where to go, what to kill or loot, and what is already in the bags.\n"
		.. ANSWER_FORMAT
end

function ns.playerContext()
	local name = UnitName("player") or "?"
	local level = UnitLevel("player") or "?"
	local race = call(UnitRace, "player") or "?"
	local class = call(UnitClass, "player") or "?"
	local faction = call(UnitFactionGroup, "player") or "?"
	local zone, sub = clean(call(GetZoneText)) or "?", clean(call(GetSubZoneText))
	local where = zone .. ((sub and sub ~= zone) and (", " .. sub) or "")
	local mapID, x, y = ns.playerMapPosition()
	local pos = x and string.format("%.1f, %.1f", x * 100, y * 100) or "unknown"
	local lines = {
		"## Player",
		string.format("- Character: %s, level %s %s %s (%s)", name, level, race, class, faction),
		string.format("- Location: %s, coordinates %s%s", where, pos, mapID and (" (uiMapID " .. mapID .. ")") or ""),
	}
	local range = mapID and AIQuestHelperData and AIQuestHelperData.Zones and AIQuestHelperData.Zones[mapID]
	if range then lines[#lines + 1] = string.format("- Zone level range: %d-%d", range[1], range[2]) end
	return table.concat(lines, "\n")
end

local function section(out, title, lines, empty)
	out[#out + 1] = title
	out[#out + 1] = #lines > 0 and table.concat(lines, "\n") or empty
end

function ns.bagContext(related)
	local list = ns.collectBags and ns.collectBags(false) or {}
	if #list == 0 then return "## Bags\n(empty)" end
	local mine, quest, other = {}, {}, {}
	for _, e in ipairs(list) do
		local line = string.format("- %d | %s | %d", e.id, e.name, e.count)
		if related and related[e.id] then
			mine[#mine + 1] = line
		elseif select(6, call(GetItemInfoInstant, e.id)) == 12 then
			quest[#quest + 1] = line .. " (quest item)"
		else
			other[#other + 1] = line
		end
	end
	local out = {}
	if related then
		section(out, "## Bags: items for this quest (itemID | name | count)", mine, "(none yet)")
		out[#out + 1] = ""
	end
	if #quest > 0 then
		section(out, "## Bags: other quest items", quest)
		out[#out + 1] = ""
	end
	section(out, "## Bags: everything else", other, "(nothing)")
	return table.concat(out, "\n")
end
