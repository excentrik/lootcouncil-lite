-- Author      : Matthew Enthoven (Alias: Blacksen)
-- Create Date : 1/18/2010 1:05:11 AM

local selectedRank;


function RankFrame_EventHandler(self, event, ...)
	if event == "VARIABLES_LOADED" then
		if LootCouncil_minRank > 0 then
			selectedRank = LootCouncil_minRank;
			UIDropDownMenu_SetText(RankDropDown,  " "..LootCouncil_minRank.." - "..GuildControlGetRankName(LootCouncil_minRank))
			UIDropDownMenu_SetText(OptDropDown,  " "..LootCouncil_minRank.." - "..GuildControlGetRankName(LootCouncil_minRank))
			RankDropLabel:SetText(LootCouncilLocalization["MIN_RANK"]);
		else
			selectedRank = 0;
			RankFrame:Show()
		end
	end
end
		

function LootCouncil_Browser.DropDown_OnLoad()
	local rankName = ""
	for ci = 1, GuildControlGetNumRanks() do 
		info = {};
		info.text = " "..ci.." - "..GuildControlGetRankName(ci);
		info.value = ci;
		info.func = function() LootCouncil_Browser.setMinRank(ci) end;
		UIDropDownMenu_AddButton(info);
	end
end

function LootCouncil_Browser.setMinRank(rankNum)
	selectedRank = rankNum;
	UIDropDownMenu_SetText(RankDropDown,  " "..rankNum.." - "..GuildControlGetRankName(rankNum)) 
end

function LootCouncil_Browser.acceptRank()
	if selectedRank > 0 then
		LootCouncil_minRank = selectedRank
		RankFrame:Hide()
	else
		print(LootCouncilLocalization["BAD_GUILD_RANK"])
	end
end

function LootCouncil_Browser.cancelRank()
	UIDropDownMenu_SetText(RankDropDown,  " "..LootCouncil_minRank.." - "..GuildControlGetRankName(LootCouncil_minRank)) 
	RankFrame:Hide()
	selectedRank = LootCouncil_minRank;
end