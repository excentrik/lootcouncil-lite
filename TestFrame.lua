
local councilString = "";
local insuffPrivString = "";

function LootCouncil_Browser.RunTests()
	InsuffPrivList:SetText("");
	councilString = LootCouncil_Browser.getUnitName("player") .. "\n";
	CouncilApprovedList:SetText(councilString);
	insuffPrivString = "";
	SendAddonMessage("L00TCOUNCIL", "testCouncil", "GUILD")
end
	
	
function TestFrame_EventHandler(self, event, ...)
	if event == "CHAT_MSG_ADDON" then
		local prefix, msg, channel, sender = ...
		if prefix == "L00TCOUNCIL" and sender ~= LootCouncil_Browser.getUnitName("player") then
			local cmd = msg;
			if cmd == "testReplyGood" then
				for ci = 1, GetNumGuildMembers() do -- otherwise, start looping through the guild list
					--local theName, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(ci);
					local theName, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = LootCouncil_Browser.getCharInfo(ci);
					if sender == theName then -- if we find them
						if (rankIndex+1) <= (LootCouncil_minRank + 0.1) then -- check if they're above the minimum rank
							councilString = councilString .. sender .. "\n";
							CouncilApprovedList:SetText(councilString);
						else
							insuffPrivString = insuffPrivString .. string.format(LootCouncilLocalization["LOW_RANK"], sender)
							InsuffPrivList:SetText(insuffPrivString);
						end
						break;
					end
				end
			elseif cmd == "testReplyBad" then
				insuffPrivString = insuffPrivString .. string.format(LootCouncilLocalization["INVALID_INIT"], sender);
				InsuffPrivList:SetText(insuffPrivString);
			end
		end
	elseif event == "VARIABLES_LOADED" then
		local theInfoString = "";
		theInfoString = "|cff33cc00" .. LootCouncilLocalization["INFO_APPROVED1"] .. "|r - " .. LootCouncilLocalization["INFO_APPROVED2"];
		theInfoString = theInfoString .. "\n|cffffcc66" .. LootCouncilLocalization["INFO_LOWRANK1"] .. "|r - " .. LootCouncilLocalization["INFO_LOWRANK2"];
		theInfoString = theInfoString .. "\n|cffffcc66" .. LootCouncilLocalization["INFO_INVALIDINIT1"] .. "|r - " .. LootCouncilLocalization["INFO_INVALIDINIT2"];
		theInfoString = theInfoString .. "\n|cff9d9d9d" .. LootCouncilLocalization["INFO_NOTSHOWN1"] .. "|r - " .. LootCouncilLocalization["INFO_NOTSHOWN2"];
		LCInfoString:SetText(theInfoString);
	end
end
