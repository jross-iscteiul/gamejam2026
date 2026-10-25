extends Node
## JARVIS line database. Stub owned by Package 6 — keep get_line() signature stable.

var _lines := {
	"kill_player": ["Nice shot. Lucky, but nice."],
	"kill_jarvis": ["You're welcome."],
	"kill_doubt": ["Was that you? I think that was me."],
	"death": ["Gravity: 1, You: 0."],
	"gambling": ["The house always wins. I am the house."],
	"low_trust": ["Feed me tokens and maybe I'll care."],
	# Package 2 (JARVIS speech bubble) categories; placeholder lines.
	"idle": ["Still here. Still judging.", "I could do this faster.", "Nice weather for a jump."],
	"ability_denied": ["Not on my budget.", "Trust first, tricks later.", "That costs more than you've got."],
	"offline": ["Battery... of trust... empty..."],
	"back_online": ["Back online. Don't make it weird."],
}


func get_line(category: String, level: int = 0) -> String:
	var options: Array = _lines.get(category, ["[placeholder: %s / level %d]" % [category, level]])
	return options.pick_random()
