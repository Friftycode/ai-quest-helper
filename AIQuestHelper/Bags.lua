local _, ns = ...
local call = ns.call

local bankOpen = false
local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

local function slotItem(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = call(C_Container.GetContainerItemInfo, bag, slot)
		if type(info) ~= "table" then return end
		return info.itemID, info.stackCount or 1, info.hyperlink
	end
	local _, count, _, _, _, _, link, _, _, id = call(GetContainerItemInfo, bag, slot)
	if not link then return end
	return id or ns.itemIDFromLink(link), count or 1, link
end

local function bagList()
	local bags = {}
	for bag = 0, (NUM_BAG_SLOTS or 4) do bags[#bags + 1] = bag end
	if bankOpen then
		bags[#bags + 1] = BANK_CONTAINER or -1
		local first = (NUM_BAG_SLOTS or 4) + 1
		for bag = first, first + (NUM_BANKBAGSLOTS or 6) - 1 do bags[#bags + 1] = bag end
	end
	return bags
end

-- Items stacked by itemID and sorted by name: { id, name, count, where }.
function ns.collectBags(withGear)
	local byID, list = {}, {}
	local function add(id, count, link, where)
		local e = byID[id]
		if not e then
			e = { id = id, count = 0, name = (link and link:match("%[(.-)%]")) or (call(GetItemInfo, id)) or "?" }
			byID[id] = e
			list[#list + 1] = e
		end
		e.count = e.count + (count or 1)
		if where then e.where = where end
	end
	for _, bag in ipairs(bagList()) do
		for slot = 1, (call(NumSlots, bag) or 0) do
			local id, count, link = slotItem(bag, slot)
			if id then add(id, count, link) end
		end
	end
	if withGear then
		for slot = 1, 19 do
			local link = call(GetInventoryItemLink, "player", slot)
			local id = ns.itemIDFromLink(link)
			if id then add(id, 1, link, "equipped") end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

function ns.fromBags(idsOnly, withGear)
	local list = ns.collectBags(withGear)
	if #list == 0 then return nil end
	if idsOnly then
		local ids = {}
		for i, e in ipairs(list) do ids[i] = e.id end
		return table.concat(ids, ", ")
	end
	local lines = {
		"Bag" .. (bankOpen and " + bank" or "") .. (withGear and " + gear" or "")
			.. " for " .. (UnitName("player") or "?") .. " (level " .. (UnitLevel("player") or "?") .. ")",
		"Format: itemID | name | count",
	}
	for _, e in ipairs(list) do
		lines[#lines + 1] = string.format("%d | %s | %d%s", e.id, e.name, e.count, e.where and ("  (" .. e.where .. ")") or "")
	end
	lines[#lines + 1] = "(" .. #list .. " different items)"
	return table.concat(lines, "\n")
end

local events = CreateFrame("Frame")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("BANKFRAME_CLOSED")
events:SetScript("OnEvent", function(_, event) bankOpen = event == "BANKFRAME_OPENED" end)
