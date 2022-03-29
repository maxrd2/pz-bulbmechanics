BulbMechanics = BulbMechanics or {}
BulbMechanics.optVerbose = false;

function BulbMechanics.debug(text)
	if not BulbMechanics.optVerbose then return; end
	print(text)
end
