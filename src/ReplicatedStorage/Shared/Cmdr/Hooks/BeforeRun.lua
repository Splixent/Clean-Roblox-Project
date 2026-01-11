local Admin = {
    128466825,
}
local BabyAdmin = {
}

return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		if table.find(Admin, context.Executor.UserId) == nil and table.find(BabyAdmin, context.Executor.UserId) == nil and context.Executor.UserId > 0 then
			return "You don't have permission to run this command"
		end

        local group = table.find(Admin, context.Executor.UserId) and "Admin" or "BabyAdmin"
        if context.Group == "Admin" and group == "BabyAdmin" then
            return "You don't have permission to run this command"
        end
	end)
end
