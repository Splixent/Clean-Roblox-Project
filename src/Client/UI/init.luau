--[[
	Client UI entry point.

	There is no master ScreenGui. Every interface mounts its own ScreenGui
	straight into PlayerGui, so each one owns its ZIndex, its screen insets and
	its own lifetime, and a screen can appear or go away without touching a
	shared root.

	Layout under src/Client:

		Client/*.luau              client-wide infrastructure (Replication, ...)
		Client/UI/                 UI infrastructure shared by components
		Client/UI/Components/      one self-contained component each
		Client/<Feature>Handler/   gameplay controllers that drive components

	Components are a library, not a set of screens: each takes props and returns
	a Fusion.Child, and whoever uses one decides where and when it mounts. Do not
	require them in a loop from here — a component returns a constructor, and
	handing Fusion a bare function throws unrecognisedChildType.

	UIPostProcess is deliberately not wired to anything. It rescales UI authored
	in 1920x1080 offsets (stroke thickness, corner radius, list padding), which
	is wrong for scale-authored UI and would also reach any third-party console
	parented into PlayerGui. It takes a root, so pass it one specific ScreenGui
	if offset-authored UI is added.

	Start client UI systems (prompt UI, HUD controllers) from here by requiring
	them; mount screens from the feature that owns them.
]]

return nil
