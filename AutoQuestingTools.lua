local AQT_Version = "1.1.10";
local AQT_Name = "Auto Questing Tools";
local AQT_BLUE = "|c000099ff";
local AQT_YELLOW = "|cffffff55";
local AQT_END_COLOR = "|r";
local AQT_Title = AQT_BLUE .. AQT_Name .. ":" .. AQT_END_COLOR .. " ";

local EVENTS = {};
local MAX_LEVEL = 110;

-- Event ADDON_LOADED
EVENTS.ADDON_LOADED = "ADDON_LOADED";
EVENTS.QUEST_DETAIL = "QUEST_DETAIL";
EVENTS.QUEST_GREETING = "QUEST_GREETING";
EVENTS.QUEST_ACCEPTED = "QUEST_ACCEPTED";
EVENTS.QUEST_COMPLETE = "QUEST_COMPLETE";
EVENTS.QUEST_PROGRESS = "QUEST_PROGRESS";
EVENTS.GOSSIP_SHOW = "GOSSIP_SHOW";
EVENTS.TRAINER_SHOW = "TRAINER_SHOW";
EVENTS.QUEST_FINISHED = "QUEST_FINISHED";

local lastActiveQuest = 1;
local lastAvailableQuest = 1;
local lastNPC = nil;

local options = {
	debug = {message = "Debug messages"},
	security = {message = "Security key"},
	compare = {message = "Character frame"},
	auto_complete = {message = "Auto Quest Complete", status = {"always ON", "only ON while ALT key is down"}},
	announce = {message = "Announce to party channel"},
	share = {message = "Auto share new quests"},
}

function AQT_OnLoad(self)
	for _,v in pairs(EVENTS) do
		self:RegisterEvent(strupper(v));
	end

	AQT_RegisterSlashCommands();
	AQT_LocalMessage(AQT_BLUE .. AQT_Name .. " v" .. AQT_Version .. " by Tiago Costa." .. AQT_END_COLOR);
	AQT_LocalMessage("Type /aqt or /autoquestingtools for options.");
end

function AQT_RegisterSlashCommands()
	SlashCmdList["AQT4832_"] = AQT_ProcessSlashCommand;
	SLASH_AQT4832_1 = "/autoquestingtools";
	SLASH_AQT4832_2 = "/aqt";
end

function AQT_ProcessSlashCommand(option)
	option = strlower(option);

	if option == "security" or option == "debug" or option == "compare" or option == "auto_complete" or option == "announce" or option == "share" then
		AQT_Toggle(option);
	elseif option == "status" then
		AQT_ShowStatus("security");
		AQT_ShowStatus("auto_complete");
		AQT_ShowStatus("announce");
		AQT_ShowStatus("share");
	else
		AQT_ShowHelp();
	end
end

function AQT_Toggle(option)
	AQT_Options[option] = not AQT_Options[option];
	AQT_ShowStatus(option);
end

function AQT_ShowStatus(option)
	local message = AQT_Title;
	message = message .. options[option].message .. " is ";
	message = message .. (AQT_Options[option] and ((options[option].status and options[option].status[1]) or "enabled") or ((options[option].status and options[option].status[2]) or "disabled")) .. ".";

	AQT_LocalMessage(message);
	AQT_HUDMsg(message);
end

function AQT_ShowHelp()
	AQT_LocalMessage(AQT_BLUE .. AQT_Name .." v" .. AQT_Version .. AQT_END_COLOR);
	AQT_LocalMessage(AQT_YELLOW .. "Usage:");
	AQT_LocalMessage(AQT_YELLOW .. "    /aqt security -" .. AQT_END_COLOR .. " Enables / Disables the use of the security key CTRL. Default: ON");
	AQT_LocalMessage(AQT_YELLOW .. "    /aqt auto_complete" .. AQT_END_COLOR .. " - Enables / Disables auto completing quests with more than one reward choice when the addon QuestReward is present. If disabled you can use the ALT key to temporarily enable this feature. Default: OFF");
	AQT_LocalMessage(AQT_YELLOW .. "    /aqt announce" .. AQT_END_COLOR .. " - Enables / Disables party announces when automatically accepting quests. Default: ON");
	AQT_LocalMessage(AQT_YELLOW .. "    /aqt share" .. AQT_END_COLOR .. " - Enables / Disables sharing quests automatically with party members. Default: ON");
	AQT_LocalMessage(AQT_YELLOW .. "    /aqt status" .. AQT_END_COLOR .. " - Shows your current settings.");
end

function AQT_OnEvent(self, event, ...)
	if event == EVENTS.ADDON_LOADED and ... == "AutoQuestingTools" then
		if not AQT_Options then
			AQT_Options = {
				security = true,
				debug = false,
				compare = false,
				auto_complete = false,
				announce = true,
				share = true,
			};
		end
	elseif (not AQT_Options.security and not IsControlKeyDown()) or (AQT_Options.security and IsControlKeyDown()) then
		if event == EVENTS.QUEST_GREETING or event == EVENTS.GOSSIP_SHOW then
			AQT_HandleNPCInteraction(event);
		elseif event == EVENTS.QUEST_DETAIL then
			AQT_HandleQuestDetail();
		elseif event == EVENTS.QUEST_ACCEPTED then
			AQT_HandleQuestAccepted(...);
		elseif event == EVENTS.QUEST_PROGRESS then
			AQT_HandleQuestProgress();
		elseif event == EVENTS.QUEST_COMPLETE then
			AQT_HandleQuestComplete();
		elseif event == EVENTS.TRAINER_SHOW then
			AQT_HandleTrainerShow();
		elseif event == EVENTS.QUEST_FINISHED then
			AQT_HandleQuestFinished();
		end
	end
end

function AQT_HandleQuestDetail()
	if GetRewardXP() > 0 or UnitLevel("player") == MAX_LEVEL then
		if not QuestGetAutoAccept() then
			AcceptQuest();
		end

		CloseQuest();
	end
end

function AQT_HandleNPCInteraction(event)
	if GetNumGossipOptions() == 0 then
		local numAvailableQuests = 0;
		local numActiveQuests = 0;

		if event == EVENTS.QUEST_GREETING then
			numAvailableQuests = GetNumAvailableQuests();
			numActiveQuests = GetNumActiveQuests();
		elseif event == EVENTS.GOSSIP_SHOW then
			numAvailableQuests = GetNumGossipAvailableQuests();
			numActiveQuests = GetNumGossipActiveQuests();
		end

		if numAvailableQuests > 0 or numActiveQuests > 0 then
			local guid = UnitGUID("target");

			if lastNPC ~= guid then
				lastActiveQuest = 1;
				lastAvailableQuest = 1;
				lastNPC = guid;
			end

			if lastAvailableQuest > numAvailableQuests then
				lastAvailableQuest = 1;
			end

			for i = lastAvailableQuest, numAvailableQuests do
				lastAvailableQuest = i;

				if event == EVENTS.QUEST_GREETING then
					SelectAvailableQuest(i);
				elseif event == EVENTS.GOSSIP_SHOW then
					SelectGossipAvailableQuest(i);
				end
			end

			if lastActiveQuest > numActiveQuests then
				lastActiveQuest = 1;
			end

			for i = lastActiveQuest, numActiveQuests do
				lastActiveQuest = i;

				if event == EVENTS.QUEST_GREETING then
					SelectActiveQuest(i);
				elseif event == EVENTS.GOSSIP_SHOW then
					SelectGossipActiveQuest(i);
				end
			end
		end
	end
end

function AQT_HandleQuestProgress()
	if IsQuestCompletable() then
		CompleteQuest();
	end

	CloseQuest();
end

function AQT_HandleQuestAccepted(questIndex)
	if GetNumGroupMembers() >= 1 then
		if AQT_Options.announce then
			SendChatMessage("[" .. AQT_Name .. "] Quest accepted: " .. GetQuestLink(questIndex), "PARTY");
		end

		SelectQuestLogEntry(questIndex);

		if AQT_Options.share then
			if GetQuestLogPushable() then
				QuestLogPushQuest();
			end
		end
	end
end

function AQT_HandleQuestComplete()
	if GetNumQuestChoices() == 0 then
		GetQuestReward(nil);
    elseif GetNumQuestChoices() == 1 then
        GetQuestReward(1);
	else
		if IsAddOnLoaded("QuestReward") and (AQT_Options.auto_complete or (not AQT_Options.auto_complete and IsAltKeyDown())) then
			GetQuestReward(QuestInfoFrame.itemChoice);
		else
			if AQT_Options.compare and not CharacterFrame:IsVisible() then
				CharacterFrame:SetPoint("TOPLEFT", QuestFrame, "TOPRIGHT", 20, -20);
				CharacterFrame:Show();
			end
		end
	end
end

function AQT_HandleQuestFinished()
	if AQT_Options.compare and CharacterFrame:IsVisible() then
		CharacterFrame:Hide();
	end
end

function AQT_HandleTrainerShow()
	if not IsTradeskillTrainer() then
		SetTrainerServiceTypeFilter("available", 1, 1);

		if GetNumTrainerServices() > 0 then
			if strlower(GetTrainerServiceSkillLine(1)) ~= "riding" then
				for i = 1, GetNumTrainerServices() do
					BuyTrainerService(i);
				end

				CloseTrainer();
			end
		end
	end
end

function AQT_HUDMsg(message)
   UIErrorsFrame:AddMessage(message, 1.0, 1.0, 1.0, 1.0, UIERRORS_HOLD_TIME);
end

function AQT_LocalMessage(message)
	DEFAULT_CHAT_FRAME:AddMessage(tostring(message));
end

function AQT_Debug(message)
	if AQT_Options.debug then
		AQT_LocalMessage("[" .. AQT_BLUE .. AQT_Name .. "]" .. AQT_END_COLOR .. " Debug: " .. message);
	end
end
