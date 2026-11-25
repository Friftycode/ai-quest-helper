local _, ns = ...
local call, shown = ns.call, ns.shown
local G = C_GossipInfo or {}

local function titles(numFn, titleFn)
	local out = {}
	for i = 1, (call(numFn) or 0) do
		local t = call(titleFn, i)
		if t and t ~= "" then out[#out + 1] = "- " .. t end
	end
	return table.concat(out, "\n")
end

local function requiredItems()
	local req = {}
	for i = 1, (call(GetNumQuestItems) or 0) do
		local c = select(3, call(GetQuestItemInfo, "required", i))
		local l = ns.itemLine(call(GetQuestItemLink, "required", i), c)
		if l then req[#req + 1] = l end
	end
	return table.concat(req, "\n")
end

function ns.fromQuestDialog()
	if not shown(QuestFrame) then return nil end
	local doc = ns.newDoc()
	doc.add(ns.npcHeader("questnpc", "npc"))
	local title, qid = call(GetTitleText), call(GetQuestID)
	if title then doc.add(title .. ((qid and qid > 0) and ("  (Quest ID " .. qid .. ")") or "")) end

	if shown(QuestFrameGreetingPanel) then
		doc.add(call(GetGreetingText))
		doc.add(titles(GetNumActiveQuests, GetActiveTitle), "Active quests:")
		doc.add(titles(GetNumAvailableQuests, GetAvailableTitle), "Available quests:")
	elseif shown(QuestFrameProgressPanel) then
		doc.add(call(GetProgressText))
		doc.add(requiredItems(), "Requires (ID | name | count):")
	elseif shown(QuestFrameRewardPanel) then
		doc.add(call(GetRewardText))
		doc.add(ns.rewardLines(false), "Rewards (ID | name | count):")
	else
		doc.add(call(GetQuestText))
		doc.add(call(GetObjectiveText), "Objective:")
		doc.add(ns.rewardLines(false), "Rewards (ID | name | count):")
	end
	return doc.result()
end

local function gossipList(fn, field)
	local out, items = {}, call(fn)
	for _, it in ipairs(type(items) == "table" and items or {}) do
		local t = type(it) == "table" and it[field]
		if t and t ~= "" then
			out[#out + 1] = "- " .. t .. (it.questID and ("  (Quest ID " .. it.questID .. ")") or "")
		end
	end
	return table.concat(out, "\n")
end

function ns.fromGossip()
	if not shown(GossipFrame) then return nil end
	local doc = ns.newDoc()
	doc.add(ns.npcHeader("npc"))
	doc.add(call(G.GetText) or call(GetGossipText))
	doc.add(gossipList(G.GetActiveQuests, "title"), "Active quests:")
	doc.add(gossipList(G.GetAvailableQuests, "title"), "Available quests:")
	doc.add(gossipList(G.GetOptions, "name"), "Options:")
	return doc.result()
end
