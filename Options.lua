-- Author      : Matthew Enthoven (Alias: Blacksen)
-- Create Date : 1/21/2010 4:54:38 PM

local optSelectedRank;

function LCOptionsFrame_EventHandler(self, event, ...)
	if event == "VARIABLES_LOADED" then
		LootCouncil_Browser.private = LootCouncil_privateVoting;
		LootCouncil_Browser.single = LootCouncil_singleVote;
		LootCouncil_Browser.spec = LootCouncil_displaySpec;
		LootCouncil_Browser.self = LootCouncil_selfVoting;
		LootCouncil_Browser.split = LootCouncil_SplitRaids;
		LootCouncil_Browser.confirmEnd = LootCouncil_confirmEnding;
		LootCouncil_Browser.EnchantersList = LootCouncil_convertStringList(LootCouncil_Enchanters); -- make a List of out the string
		LootCouncil_Browser.MLI = LootCouncil_masterLootIntegration;
		LootCouncil_Browser.Channel = LootCouncil_Channel;
		SingleVoteMode:SetChecked(LootCouncil_singleVote)
		PrivateVoteMode:SetChecked(LootCouncil_privateVoting)
		DisplaySpecMode:SetChecked(LootCouncil_displaySpec);
		SelfVoteMode:SetChecked(LootCouncil_selfVoting);
		WhisperLinkMode:SetChecked(LootCouncil_LinkWhisper);
		OfficerLinkMode:SetChecked(LootCouncil_LinkOfficer);
		RaidLinkMode:SetChecked(LootCouncil_LinkRaid);
		GuildLinkMode:SetChecked(LootCouncil_LinkGuild);
		ConfirmEnding:SetChecked(LootCouncil_confirmEnding);
		MasterLootIntegration:SetChecked(LootCouncil_masterLootIntegration);
		ScaleSlider:SetValue(LootCouncil_scale);
		ScaleSliderLabel:SetText(LootCouncil_scale);
		MainFrame:SetScale(LootCouncil_scale);
		EnchantersTable:SetText(LootCouncil_Enchanters);
		EnchantersTable:SetJustifyV("TOP")
		SplitMode:SetChecked(LootCouncil_SplitRaids);

		ConfirmEndingLabel:SetText(LootCouncilLocalization["CONFIRM_END_SESSION"]);
		GuildLinkLabel:SetText(LootCouncilLocalization["LINK_GUILD"]);
		OfficerLinkLabel:SetText(LootCouncilLocalization["LINK_OFFICERS"]);
		RaidLinkLabel:SetText(LootCouncilLocalization["LINK_RAID"]);
		WhisperLinkLabel:SetText(LootCouncilLocalization["LINK_WHISPERS"]);
		ScaleLabel:SetText(LootCouncilLocalization["MAIN_FRAME_SCALE"]);
		MasterLootLabel:SetText(LootCouncilLocalization["MASTER_LOOT_INTEGRATE"]);
		OptDropLabel:SetText(LootCouncilLocalization["MIN_RANK"]);
		PrivateVotingLabel:SetText(LootCouncilLocalization["PRIVATE_VOTING"]);
		SelfVotingLabel:SetText(LootCouncilLocalization["SELF_VOTE"]);
		SingleVotingLabel:SetText(LootCouncilLocalization["SINGLE_VOTE"]);
		DisplaySpecLabel:SetText(LootCouncilLocalization["SPEC_INFO"]);
		EnchantersTableLabel:SetText(LootCouncilLocalization["ENCHANTERS"]);
		SplitLabel:SetText(LootCouncilLocalization["SPLIT_RAIDS"]);
		
		
		if LootCouncil_minRank > 0 then
			optSelectedRank = LootCouncil_minRank;
		else
			optSelectedRank = 0;
		end
	end
end


function LootCouncil_Browser.acceptOptions()
	if optSelectedRank > 0 then
		LootCouncil_minRank = optSelectedRank
		if 	SingleVoteMode:GetChecked() then
			LootCouncil_singleVote = 1;
		else
			LootCouncil_singleVote = 0;
		end
		if PrivateVoteMode:GetChecked() then
			LootCouncil_privateVoting = 1;
		else
			LootCouncil_privateVoting = 0;
		end
		if 	SelfVoteMode:GetChecked() then
			LootCouncil_selfVoting = 1;
		else
			LootCouncil_selfVoting = 0;
		end
		if DisplaySpecMode:GetChecked() then
			LootCouncil_displaySpec = 1;
		else
			LootCouncil_displaySpec = 0;
		end
		if WhisperLinkMode:GetChecked() then
			LootCouncil_LinkWhisper = 1;
		else
			LootCouncil_LinkWhisper = 0;
		end
		if OfficerLinkMode:GetChecked() then
			LootCouncil_LinkOfficer = 1;
		else
			LootCouncil_LinkOfficer = 0;
		end
		if RaidLinkMode:GetChecked() then
			LootCouncil_LinkRaid = 1;
		else
			LootCouncil_LinkRaid = 0;
		end
		if GuildLinkMode:GetChecked() then
			LootCouncil_LinkGuild = 1;
		else
			LootCouncil_LinkGuild = 0;
		end
		
		if ConfirmEnding:GetChecked() then
			LootCouncil_confirmEnding = 1;
		else
			LootCouncil_confirmEnding = 0;
		end
		
		local different = false;
		if MasterLootIntegration:GetChecked() and LootCouncil_masterLootIntegration == 0 then
			different = true;
		end
		
		if (not (MasterLootIntegration:GetChecked())) and LootCouncil_masterLootIntegration == 1 then
			different = true;
		end
		
		if MasterLootIntegration:GetChecked() then
			LootCouncil_masterLootIntegration = 1;
		else
			LootCouncil_masterLootIntegration = 0;
		end
		
		if SplitMode:GetChecked() then
			LootCouncil_SplitRaids = 1;
		else
			LootCouncil_SplitRaids = 0;
		end
		
		LootCouncil_Enchanters = EnchantersTable:GetText();		

		LootCouncil_Browser.private = LootCouncil_privateVoting;
		LootCouncil_Browser.single = LootCouncil_singleVote;
		LootCouncil_Browser.spec = LootCouncil_displaySpec;
		LootCouncil_Browser.self = LootCouncil_selfVoting;
		LootCouncil_Browser.split = LootCouncil_SplitRaids;
		LootCouncil_Browser.confirmEnd = LootCouncil_confirmEnding;
		LootCouncil_Browser.EnchantersList = LootCouncil_convertStringList(LootCouncil_Enchanters);
		LootCouncil_Browser.MLI = LootCouncil_masterLootIntegration;
		LootCouncil_Browser.Channel = LootCouncil_Channel;
		LCOptionsFrame:Hide()
		if different then
			ReloadUI();
		end
	else
		print(LootCouncilLocalization["BAD_GUILD_RANK"])
	end
end

function LootCouncil_Browser.optSetMinRank(rankNum)
	optSelectedRank = rankNum;
	UIDropDownMenu_SetText(OptDropDown,  " "..rankNum.." - "..GuildControlGetRankName(rankNum)) 
end

function LootCouncil_Browser.OptDropDown_OnLoad()
	local rankName = ""
	for ci = 1, GuildControlGetNumRanks() do 
		info = {};
		info.text = " "..ci.." - "..GuildControlGetRankName(ci);
		info.value = ci;
		info.func = function() LootCouncil_Browser.optSetMinRank(ci) end;
		UIDropDownMenu_AddButton(info);
	end
end

function LootCouncil_Browser.cancelOptions()
	UIDropDownMenu_SetText(OptDropDown,  " "..LootCouncil_minRank.." - "..GuildControlGetRankName(LootCouncil_minRank)) 
	LCOptionsFrame:Hide()
	selectedRank = LootCouncil_minRank;
	SingleVoteMode:SetChecked(LootCouncil_singleVote)
	PrivateVoteMode:SetChecked(LootCouncil_privateVoting)
	SplitMode:SetChecked(LootCouncil_SplitRaids)
	WhisperLinkMode:SetChecked(LootCouncil_LinkWhisper);
	OfficerLinkMode:SetChecked(LootCouncil_LinkOfficer);
	RaidLinkMode:SetChecked(LootCouncil_LinkRaid);
	GuildLinkMode:SetChecked(LootCouncil_LinkGuild);
	DisplaySpecMode:SetChecked(LootCouncil_displaySpec);
	SelfVoteMode:SetChecked(LootCouncil_selfVoting);
	ConfirmEnding:SetChecked(LootCouncil_confirmEnding);
	MasterLootIntegration:SetChecked(LootCouncil_masterLootIntegration);
end