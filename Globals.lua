-- Author      : Matthew Enthoven (Alias: Blacksen)
-- Create Date : 1/04/2010 12:24:31 PM


LootCouncil_TheCouncil = {};
LootCouncil_Browser = {}
LootCouncil_Browser.Data = {}
LootCouncil_Browser.Elects = {}
LootCouncil_Browser.Votes = {}
LootCouncil_Browser.WhisperList = {}
LootCouncil_PlayerData = {}
LootCouncil_minRank = 0;
LootCouncil_sawFirstMessage = 0;
LootCouncil_privateVoting = 0;
LootCouncil_singleVote = 0;
LootCouncil_displaySpec = 1;
LootCouncil_selfVoting = 1;
LootCouncil_scale = 1;
LootCouncil_confirmEnding = 1;
LootCouncil_masterLootIntegration = 1;

LootCouncil_awaitingItem = false;

LootCouncil_Browser.private = LootCouncil_privateVoting;
LootCouncil_Browser.single = LootCouncil_singleVote;
LootCouncil_Browser.spec = LootCouncil_displaySpec;
LootCouncil_Browser.self = LootCouncil_selfVoting;
LootCouncil_Browser.confirmEnd = LootCouncil_confirmEnding;
LootCouncil_Browser.MLI = LootCouncil_masterLootIntegration;

LootCouncil_LinkWhisper = 1;
LootCouncil_LinkOfficer = 1;
LootCouncil_LinkRaid = 0;
LootCouncil_LinkGuild = 0;
LootCouncil_Version="2.2"

LootCouncil_debugMode = 0; --NOTE: This is a variable for DEACTIVATING all messages through guild chat or whispers. When you enable it, the addon won't send people messages
-- 1 = debug on (no messages sent)
-- 0 = debug off (messages sent as normal)

RegisterAddonMessagePrefix("L00TCOUNCIL");

do
	----------- Slash Command Manager -----------            
	---------------------------------------------
	SLASH_LOOT_COUNCIL1 = "/ltc";
	SLASH_LOOT_COUNCIL2 = "/lootcouncil";
	SlashCmdList["LOOT_COUNCIL"] = function(msg)
		local cmd, arg = string.split(" ", msg,2); -- Separates the command from the rest
		cmd = cmd:lower(); -- Lower case command
		if cmd == "show" then -- show the main frame
			LootCouncil_Browser.showMainFrame();
		elseif cmd == "hide" then -- hide the main frame
			LootCouncil_Browser.hideMainFrame();
		elseif cmd == "start" then -- try to start a new Loot Council Session
			LootCouncil_Browser.printd("slash start cmd");
			LootCouncil_Browser.initiateLootCouncil(msg:match("^start%s+(.+)"));
		elseif cmd == "end" then
			LootCouncil_Browser.initiateAbort();
		elseif cmd == "add" then
			if arg then
				local thePlayer, item = string.split(" ", arg);
				if item then
					local startLoc = string.find(msg, "Hitem:")
					if startLoc ~= nil then
						LootCouncil_Browser.manualAdd(thePlayer, arg);
					else
						print(LootCouncilLocalization["BAD_MANUAL_ADD"])
					end
				else
					print(LootCouncilLocalization["BAD_MANUAL_ADD"])
				end
			else
				print(LootCouncilLocalization["BAD_MANUAL_ADD"])
			end
		elseif cmd == "rank" then
			RankFrame:Show()
			LCOptionsFrame:Hide()
		elseif cmd == "config" then
			LCOptionsFrame:Show()
			RankFrame:Hide()
			LCTestFrame:Hide()
		elseif cmd == "test" then
			LCTestFrame:Show()
			LootCouncil_Browser.RunTests()
			RankFrame:Hide();
			LCOptionsFrame:Hide()
		elseif cmd == "reset" then
			LootCouncil_Browser.resetMainFrame()
--		elseif cmd == "matthew" then
--			local link = GetContainerItemLink(0, 1);
--			local printable = gsub(link, "\124", "\124\124");
--			ChatFrame1:AddMessage("Here's what it really looks like: \"" .. printable .. "\"");
--			
--			
--			local fullstring = "mainspec " .. link .. " test!";
--			print(fullstring);
--			local testgsub = string.gsub(fullstring, "^|c%x+|H(item[%d:]+)|h%[", "");
--		    printable = gsub(testgsub, "\124", "\124\124");
--			ChatFrame1:AddMessage("Here's what it really looks like: \"" .. printable .. "\"");
--			print("-----");
--			print(string.find(fullstring, "\124h%["));
--			print(string.find(fullstring, "%]\124h"));
		elseif cmd == "" then
			print(LootCouncilLocalization["CMD_MAIN"]);
			print(LootCouncilLocalization["CMD_PREFIX"]);
			print(LootCouncilLocalization["CMD_SHOW"])
			print(LootCouncilLocalization["CMD_HIDE"])
			print(LootCouncilLocalization["CMD_START"]);
			print(LootCouncilLocalization["CMD_END"]);
			print(LootCouncilLocalization["CMD_ADD"])
			print(LootCouncilLocalization["CMD_RANK"]);
			print(LootCouncilLocalization["CMD_CONFIG"]);
			print(LootCouncilLocalization["CMD_TEST"]);
			print(LootCouncilLocalization["CMD_RESET"]);
		else
			print(string.format(LootCouncilLocalization["BAD_CMD"], msg));
		end
	end
end