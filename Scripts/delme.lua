delme = class()

function delme.server_onCreate(self)self.delTime = sm.game.getCurrentTick() end

function delme.server_onFixedUpdate( self )
	if sm.game.getCurrentTick()+1 >= sm.game.getCurrentTick() then
		self.shape:destroyShape()
	end
end