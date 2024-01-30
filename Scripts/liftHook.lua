liftHook = class()

--HOOKS

dofile("$GAME_DATA/Scripts/game/Lift.lua")

sm.o_liftHook = sm.o_liftHook or sm.player.placeLift
_G.__lifts = _G.__lifts or {}

function sm.player.placeLift( player, selectedBodies, liftPos, liftLvl, rotInd )
	_G.__lifts[player.id] = {
		player = player,
		selectedBodies = selectedBodies,
		position = liftPos,
		level = liftLvl,
		rotation = rotInd
	}

	sm.o_liftHook(player, selectedBodies, liftPos, liftLvl, rotInd)
end
