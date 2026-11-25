local _, ns = ...
local opt = ns.opt

ns.icons = {}

local OPTION = {
	quest = "iconDialog", gossip = "iconDialog", itemText = "iconBook",
	questMap = "iconQuestMap", questDetails = "iconQuestMap", questList = "iconQuestMap", questLog = "iconQuestMap",
	bags = "iconBags", bagsCombined = "iconBags", gear = "iconBags",
}

local TIPS = {
	dialog = { "Left-click: copy the text with NPC, quest ID and rewards (item IDs)." },
	book = { "Left-click: copy the book/note (all pages you have turned)." },
	gear = { "Left-click: equipped gear with item level, stats, enchants, gems and durability." },
	quest = {
		"Left-click: selected quest (text, objectives, progress, ID, rewards).",
		"Right-click: whole quest log with IDs and progress.",
		"Shift-click: all completed quest IDs.",
	},
	bags = {
		"Left-click: itemID | name | count.",
		"Right-click: IDs only, comma-separated.",
		"Shift-click: include equipped gear.",
		"The bank is included when it is open.",
	},
}

local function questClick(mouse)
	if IsShiftKeyDown() then return ns.fromCompleted() end
	if mouse == "RightButton" then return ns.fromWholeLog() end
	return ns.fromSelectedQuest() or ns.fromWholeLog()
end

local function bagClick(mouse)
	return ns.fromBags(mouse == "RightButton", IsShiftKeyDown())
end

local function makeIcon(key, parent, onClick, tipLines, size)
	local b = CreateFrame("Button", nil, parent)
	ns.icons[#ns.icons + 1] = { button = b, option = OPTION[key] }
	b:SetSize(size or 18, size or 18)
	b:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetNormalTexture(ns.ICON)
	b:SetPushedTexture(ns.ICON)
	b:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:GetPushedTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:GetPushedTexture():SetVertexColor(0.6, 0.6, 0.6)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetScript("OnClick", function(self, mouse) ns.ready(onClick(mouse), self) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("AI Quest Helper")
		for _, l in ipairs(tipLines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
		GameTooltip:AddLine("Then press Ctrl+C.", 0.6, 0.8, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

local function anchorLeftOfClose(b, f, x)
	local close = f.CloseButton or (f.GetName and f:GetName() and _G[f:GetName() .. "CloseButton"])
	if close then
		b:SetPoint("RIGHT", close, "LEFT", x or 0, 0)
	else
		b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -6)
	end
end

function ns.refreshIcons()
	for _, e in ipairs(ns.icons) do
		local on = (not e.option or opt(e.option)) and not e.forceHidden
		e.button:SetShown(on and true or false)
	end
end

local attached = {}

local function attach(key, frame, build)
	if attached[key] or not frame then return end
	attached[key] = true
	build(frame)
	ns.refreshIcons()
end

local function simple(key, frame, onClick, tip, x)
	attach(key, frame, function(f) anchorLeftOfClose(makeIcon(key, f, onClick, tip), f, x) end)
end

local function tryAttach()
	simple("quest", QuestFrame, ns.fromQuestDialog, TIPS.dialog)
	simple("gossip", GossipFrame, ns.fromGossip, TIPS.dialog)
	simple("itemText", ItemTextFrame, ns.fromItemText, TIPS.book)
	simple("questLog", QuestLogFrame, questClick, TIPS.quest)
	simple("gear", CharacterFrame, ns.fromGear, TIPS.gear)
	simple("bags", ContainerFrame1, bagClick, TIPS.bags, 2)
	simple("bagsCombined", ContainerFrameCombinedBags, bagClick, TIPS.bags, 2)

	attach("questMap", WorldMapFrame, function(f)
		local border = f.BorderFrame or f
		local b = makeIcon("questMap", border, questClick, TIPS.quest, 20)
		ns.questMapIcon = b
		if ns.attachReadyButton then ns.attachReadyButton(b) end
		if border.MaximizeMinimizeFrame then
			b:SetPoint("RIGHT", border.MaximizeMinimizeFrame, "LEFT", -2, 0)
		else
			anchorLeftOfClose(b, border, -2)
		end
	end)
	attach("questDetails", QuestMapFrame and QuestMapFrame.DetailsFrame, function(d)
		local b = makeIcon("questDetails", d.BackFrame or d, questClick, TIPS.quest, 22)
		b:SetPoint("TOPRIGHT", d, "TOPRIGHT", -6, -6)
	end)
	attach("questList", QuestScrollFrame, function(f)
		local b = makeIcon("questList", QuestMapFrame or f, questClick, TIPS.quest, 20)
		b:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -2, 4)
		f:HookScript("OnShow", function() b:SetShown(opt("iconQuestMap") and true or false) end)
		f:HookScript("OnHide", function() b:Hide() end)
	end)
	if WorldMapFrame and not attached.mapHook then
		attached.mapHook = true
		WorldMapFrame:HookScript("OnShow", tryAttach)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", tryAttach)
