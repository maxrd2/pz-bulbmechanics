require "BulbMechanics"
require "TimedActions/BulbMechanics_FutureAction"

local original_ISVehicleMechanics_doPartContextMenu = ISVehicleMechanics.doPartContextMenu

function ISVehicleMechanics:doPartContextMenu(part, x, y)
	if UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then return; end

	original_ISVehicleMechanics_doPartContextMenu(self, part, x, y)

	if part:getId():find("Headlight", 1, true) ~= 1 then
		BulbMechanics.debug("BulbMechanics:doPartContextMenu not on Headlight")
		return
	end

	local vehicleID = self.vehicle:getMechanicalID();
	BulbMechanics.debug("BulbMechanics:doPartContextMenu vehicle id:" .. vehicleID)

	local typeToItem = VehicleUtils.getItems(self.chr:getPlayerNum())
	local countItems = 0
	local countItemsXP = 0
	if typeToItem["Base.LightBulb"] then
		for i, item in ipairs(typeToItem["Base.LightBulb"]) do
			local giveXP_I = self.chr:getMechanicsItem(item:getID() .. vehicleID .. "1") == nil
			local giveXP_U = self.chr:getMechanicsItem(item:getID() .. vehicleID .. "0") == nil
			countItems = countItems + 1
			if giveXP_I then
				countItemsXP = countItemsXP + 1
			end
			BulbMechanics.debug("BulbMechanics:doPartContextMenu Base.LightBulb#" .. i .. " - instXP:" .. (giveXP_I and "yes" or "no") .. " uninstXP:" .. (giveXP_U and "yes" or "no"))
		end
	end

	if not self.context then self.context = ISContextMenu.get(self.playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY()); end

	local trainOption = self.context:addOption(getText("ContextMenu_BulbMechanics"), self, BulbMechanics.onTrainMechanics, self.chr, self.vehicle, part)
	local description = getText("Tooltip_craft_Needs") .. " : <LINE>";

	description = description .. BulbMechanics.getTooltipLine(self.chr, "Screwdriver")

	local itemName = InventoryItemFactory.CreateItem("Base.LightBulb"):getDisplayName();
	if countItemsXP > 0 then
		description = description .. "<RGB:1,1,1>" .. itemName .. " " .. countItemsXP .. "/" .. countItems .. " <LINE>"
		description = description .. "<LINE>Train for " .. (countItemsXP * 2) .. " XP ticks"
	else
		description = description .. "<RED>" .. itemName .. " 0/" .. countItems .. " <LINE>"
		if countItems > 0 then
			description = description .. "<LINE>All reachable " .. itemName .. "s (" .. countItems .. ") were already installed today and won't give any XP ticks"
		else
			description = description .. "<LINE>Training requires " .. itemName .. " in reachable inventory"
		end
	end

	local tooltip = ISToolTip:new();
	tooltip:initialise();
	tooltip:setVisible(false);
	tooltip.description = description
	trainOption.toolTip = tooltip
	BulbMechanics.debug("BulbMechanics:doPartContextMenu tooltip: " .. description)
end

function BulbMechanics:onTrainMechanics(playerObj, vehicle, part)
	if part:getId():find("Headlight", 1, true) ~= 1 then
		print("BulbMechanics.onTrainMechanics not on Headlight")
		return
	end

	BulbMechanics.debug("BulbMechanics:onTrainMechanics START")

	local typeToItem = VehicleUtils.getItems(playerObj:getPlayerNum())
	if typeToItem["Base.LightBulb"] then
		local vehicleID = vehicle:getMechanicalID();
		BulbMechanics.debug("BulbMechanics:onTrainMechanics vehicle id:" .. vehicleID)

		local first = true; -- call base function first time so stuff gets equipped correctly etc

		local time = tonumber(part:getTable("install").time) or 50

		local playerInventory = playerObj:getInventory()

		local installedItem = part:getInventoryItem()
		if installedItem then
			-- remove existing item
			BulbMechanics.debug("BulbMechanics:onTrainMechanics remove existing item id:" .. installedItem:getID())
			ISVehiclePartMenu.onUninstallPart(playerObj, part)
			first = false;
		end

		for i, item in ipairs(typeToItem["Base.LightBulb"]) do
			local itemID = item:getID()
			local giveXP = playerObj:getMechanicsItem(itemID .. vehicleID .. "1") == nil
			BulbMechanics.debug("BulbMechanics:onTrainMechanics Base.LightBulb#" .. i .. " - id:" .. itemID .. " giveXP:" .. (giveXP and "true" or "false"))

			if giveXP then
				-- transfer item to player's inventory
				local itemContainer = item:getContainer()
				local transferItem = itemContainer and itemContainer ~= playerInventory
				if transferItem then
					ISTimedActionQueue.add(BulbMechanics_FutureAction:new(function(d)
						BulbMechanics.debug("BulbMechanics:onTrainMechanics transfer item " .. d.item:getID() .. " to player inventory")
						return ISInventoryTransferAction:new(d.player, d.item, d.invSrc, d.invDst)
					end, {
						player = playerObj,
						item = item,
						invSrc = itemContainer,
						invDst = playerInventory
					}))
				end

				-- install inventory item
				if first then
					ISVehiclePartMenu.onInstallPart(playerObj, part, item)
				else
					ISTimedActionQueue.add(BulbMechanics_FutureAction:new(function(d)
						BulbMechanics.debug("BulbMechanics:onTrainMechanics install item " .. d.item:getID())
						return ISInstallVehiclePart:new(d.player, d.part, d.item, d.time)
					end, {
						player = playerObj,
						item = item,
						part = part,
						time = time
					}))
				end

				-- uninstall inventory item
				ISTimedActionQueue.add(BulbMechanics_FutureAction:new(function(d)
					BulbMechanics.debug("BulbMechanics:onTrainMechanics uninstall item " .. d.item:getID())
					d.part:setInventoryItem(d.item) -- seems there's a delay with client updates or something
					return ISUninstallVehiclePart:new(d.player, d.part, d.time)
				end, {
					player = playerObj,
					item = item,
					part = part,
					time = time
				}))

				-- transfer item back to original inventory
				if transferItem then
					ISTimedActionQueue.add(BulbMechanics_FutureAction:new(function(d)
						BulbMechanics.debug("BulbMechanics:onTrainMechanics transfer item " .. d.item:getID() .. " back to original inventory")
						-- again... seems there's a delay with client updates or something
						d.invDst:removeItemWithID(d.item:getID())
						d.invSrc:addItem(d.item)
						d.item:setContainer(d.invSrc)
						return ISInventoryTransferAction:new(d.player, d.item, d.invSrc, d.invDst)
					end, {
						player = playerObj,
						item = item,
						invSrc = playerInventory,
						invDst = itemContainer
					}))
				end
			end
		end

		if installedItem then
			-- install previously installed item
			ISTimedActionQueue.add(BulbMechanics_FutureAction:new(function(d)
				BulbMechanics.debug("BulbMechanics:onTrainMechanics reinstall previously installed item id:" .. d.item:getID())
				local item = d.player:getInventory():getItemById(d.item:getID())
				return ISInstallVehiclePart:new(d.player, d.part, item, d.time)
			end, {
				player = playerObj,
				part = part,
				item = installedItem,
				time = time
			}))
		end
	end

	BulbMechanics.debug("BulbMechanics:onTrainMechanics onTrainMechanics DONE")
end

function BulbMechanics.getTooltipLine(player, itemType)
	local item = InventoryItemFactory.CreateItem("Base." .. itemType)
	if player:getInventory():getFirstTypeRecurse(itemType) then
		BulbMechanics.debug("BulbMechanics.getTooltipLine with " .. itemType)
		return " <RGB:1,1,1>" .. item:getDisplayName() .. " 1/1 <LINE>";
	else
		BulbMechanics.debug("BulbMechanics.getTooltipLine miss " .. itemType)
		return " <RED>" .. item:getDisplayName() .. " 0/1 <LINE>";
	end
end
