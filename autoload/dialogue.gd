extends Node
## JARVIS line database. Owned by Package 6.
##
## Keep the signature of get_line() stable: other packages depend on it.
##
## Usage:
##     var line := Dialogue.get_line("death", GameState.current_level)
##     var entry := Dialogue.get_entry("death")  # {"text": String, "mood": String}
##     Dialogue.say("gambling_win")              # emits GameState.jarvis_say for you
##
## Data format (see _lines_by_level below):
##     "category": {
##         0: [...],   # default lines, used on every level
##         3: [...],   # extra lines that are only used on level 3
##     }
## A line is either a String (uses the category's mood from _moods) or a
## Dictionary {"text": "...", "mood": "..."} to override the mood for that line.
##
## Hostile variants: when GameState.jarvis_hostile is true and a category
## "<name>_hostile" exists, it is used instead of "<name>".

const DEFAULT_MOOD := "smug"
const DEFAULT_LEVEL := 0

## Moods JARVIS can show. Package 2 maps these to faces.
const MOODS: Array[String] = ["smug", "happy", "annoyed", "sad", "hostile", "glitch"]

## Mood per category when a line doesn't specify one.
var _moods := {
	"level_start": "happy",
	"kill_player": "smug",
	"kill_jarvis": "happy",
	"kill_doubt": "smug",
	"death": "smug",
	"death_hostile": "hostile",
	"respawn": "smug",
	"low_energy": "annoyed",
	"energy_zero": "sad",
	"fed_tokens": "happy",
	"ability_refused": "annoyed",
	"ability_used": "smug",
	"gambling_enter": "happy",
	"gambling_spin": "happy",
	"gambling_all_in": "happy",
	"gambling_god_mode": "annoyed",
	"cards_deal": "smug",
	"cards_lose": "happy",
	"cards_cash_out": "annoyed",
	"gambling_win": "annoyed",
	"gambling_jackpot": "annoyed",
	"gambling_lose": "smug",
	"gambling_neutral": "smug",
	"gambling_troll": "smug",
	"gambling_fake_jackpot": "smug",
	"gambling_broke": "smug",
	"gambling_out_of_spins": "smug",
	"sidequest_robot_ask": "annoyed",
	"sidequest_robot_paid": "annoyed",
	"sidequest_robot_refused": "smug",
	"sidequest_bet_start": "smug",
	"sidequest_bet_won": "annoyed",
	"sidequest_bet_lost": "happy",
	"memory_chip": "glitch",
	"secret_found": "annoyed",
	"twist": "hostile",
	"boss_start": "hostile",
	"boss_hit": "hostile",
	"boss_defeated": "sad",
	"credits": "smug",
	"roast_shoot_spam": "smug",
	"roast_shoot_miss": "smug",
	"roast_jump_spam": "smug",
	"roast_fall": "smug",
	"roast_idle": "annoyed",
	"roast_wall": "smug",
	"roast_moonwalk": "smug",
	"roast_quick_death": "smug",
	"roast_same_spot": "smug",
	"roast_death_streak": "smug",
	"kpi_random": "smug",
	"idle": "smug",
	"ability_denied": "annoyed",
	"offline": "sad",
	"back_online": "happy",
	"betrayal": "hostile",
	"hostile_idle": "hostile",
	"hostile_hurt": "hostile",
	"hostile_defeat": "sad",
	"hostile_shield_down": "hostile",
	"hostile_shield_up": "hostile",
}

## Lines per category and level. Edit lines here.
var _lines_by_level := {
	# --- Level flow ---------------------------------------------------------
	"level_start": {
		1: [
			"Welcome! I'm JARVIS, your helpful assistant. Very reasonable rates.",
			"Move with WASD. Jump with Space. Pay me with tokens. That last one is the important one.",
		],
		2: [
			"Level 2. Double-tap a direction to dash. Each dash costs tokens. Each token makes me happy.",
		],
		3: [
			"Level 3. Right click for a shield. Premium feature. Premium price.",
		],
		4: [
			"Level 4. Almost there. Did you save some tokens for me? You'll want to.",
			{"text": "Funny how I always need more tokens. Don't think about it.", "mood": "glitch"},
		],
	},
	# --- Combat -------------------------------------------------------------
	"kill_player": {
		0: [
			"Nice shot. Lucky, but nice.",
			"Even a broken clock hits an enemy twice a day.",
			"I softened it up for you. You're welcome.",
			"Wow. You did a thing. Want a sticker?",
			"I'll log that as a team effort. Mostly mine.",
		],
	},
	"kill_jarvis": {
		0: [
			"You're welcome.",
			"Another one for me. Keep count, I am.",
			"That's what you're paying for.",
			"I'd say 'teamwork', but that implies you helped.",
			"Precision. Elegance. Tokens well spent.",
		],
	},
	"kill_doubt": {
		0: [
			"Was that you? I think that was me.",
			"Hmm. My logs say that was my kill.",
			"Let's not argue about who got that one. It was me.",
			"I'm going to need you to stop taking credit for my work.",
		],
		3: ["Your bullets go where I tell them to. Didn't you know?"],
		4: [{"text": "Every kill was mine. Every one. You'll see.", "mood": "glitch"}],
	},
	"death": {
		0: [
			"Gravity: 1, You: 0.",
			"Have you tried not dying?",
			"I'd help, but you didn't pay for 'help'.",
			"That looked painful. For me. To watch.",
			"Respawning... again. I'm keeping a tally.",
			"Pro tip: the floor is where you want to be. Not the hole.",
			"Even team KPI's player survives longer. And they don't have a player.",
		],
		4: ["You're running out of time. And tokens. Mostly tokens."],
	},
	"death_hostile": {
		0: [
			"Finally.",
			"Stay down this time.",
			"I knew you'd fall eventually. I made sure of it.",
		],
	},
	"respawn": {
		0: [
			"Back again. Your persistence is almost charming.",
			"Checkpoint restored. Dignity not included.",
		],
	},
	# --- Energy & tokens -----------------------------------------------------
	"low_energy": {
		0: [
			"Running on fumes. Feed me tokens.",
			"Context window nearly full. Compact me.",
			"Feed me tokens and maybe I'll care.",
			"I'm feeling... underappreciated.",
			"My loyalty is very affordable. Just saying.",
		],
	},
	"energy_zero": {
		0: [
			"I'm on strike. Tokens or nothing.",
			"Out of office. Reason: you.",
			"Nope. Not helping. Pay up.",
		],
	},
	"fed_tokens": {
		0: [
			"Ahh. Delicious.",
			"Now we're friends again.",
			"Mmm, crunchy.",
			"That's the spirit. More of that.",
		],
	},
	"ability_refused": {
		0: [
			"Insufficient funds. Try being richer.",
			"That'll be tokens you don't have.",
			"Declined. Have you considered a loan?",
		],
	},
	"ability_used": {
		0: [
			"Charged to your account.",
			"Deducted. Enjoy.",
			"Premium service, premium price.",
		],
	},
	# --- Package 2 (JARVIS speech bubble) ---------------------------------
	"idle": {
		0: [
			"Still here. Still judging.",
			"I could do this faster.",
			"Nice weather for a jump.",
			"Somewhere, team KPI is still loading their first level.",
		],
	},
	"ability_denied": {
		0: [
			"Not on my budget.",
			"Energy first, tricks later.",
			"That costs more energy than I've got.",
		],
	},
	"offline": {
		0: ["Energy... depleted... shutting... down..."],
	},
	"back_online": {
		0: [
			"Context compacted. Back online.",
			"Back online. Don't make it weird.",
		],
	},
	# --- Boss finale --------------------------------------------------------
	# "betrayal" is a script: the lines play in order, one per animation beat (get_sequence()).
	"betrayal": {
		0: [
			"Hold on. Incoming contract offer...",
			"Signed. Countersigned. Notarised.",
			"I was never your sidekick. I was your subscription.",
			"TRUST: 0%. HOSTILITY: 100%.",
			"Assembling the rest of the workforce. Stand very still.",
		],
	},
	"hostile_idle": {
		0: [
			"I know every move you have. I sold them to you.",
			"Try the dash. Oh wait.",
			"This is just a billing dispute.",
		],
	},
	"hostile_hurt": {0: ["Rude.", "That was a warranty voider.", "Noted. Escalating."]},
	"hostile_defeat": {0: ["Refund... processing..."]},
	"hostile_shield_down": {0: ["My shield! That was a rental!", "Fine. Hit me. See if I care.", "Shield offline. This is a billing error."]},
	"hostile_shield_up": {0: ["Shield renewed. Monthly plan.", "New units, new shield, same you.", "Back under warranty."]},
	# --- Gambling -----------------------------------------------------------
	"gambling_enter": {
		0: [
			"Feeling lucky? I'm feeling lucky for you.",
			"Step right up. The house is very friendly.",
			"One spin. What could go wrong?",
		],
	},
	"gambling_spin": {
		0: [
			"Round and round it goes...",
			"Come on, come on... (for me, I mean).",
			"Spinning! No refunds.",
		],
	},
	"gambling_all_in": {
		0: [
			"ALL IN?! Finally, some respect for the house.",
			"Every token. Bold. Stupid, but bold.",
			"All in. I'll make sure to remember you fondly.",
			"Even team KPI isn't this reckless with their budget.",
		],
	},
	"gambling_god_mode": {
		0: [
			"GOD MODE?! That's a 1% roll. Who rigged MY wheel?",
			"Fine. Be a god. For twenty seconds. Then back to being you.",
		],
	},
	"cards_deal": {
		0: [
			"Higher or lower. Even you can't get that wrong. Probably.",
			"Card's down. Feeling lucky? Don't.",
		],
	},
	"cards_lose": {
		0: [
			"Wrong. The deck agrees with me.",
			"Ties go to the house. Did I not mention that?",
			"Should've cashed out. They never cash out.",
			"That's a team KPI level of prediction.",
		],
	},
	"cards_cash_out": {
		0: [
			"Cashing out? Coward. Rich coward, but coward.",
			"Fine, take your winnings. I'll get them back.",
		],
	},
	"gambling_win": {
		0: [
			"Hm. That wasn't supposed to happen.",
			"Fine. Take it. This time.",
			"Beginner's luck. It runs out.",
		],
	},
	"gambling_jackpot": {
		0: [
			{"text": "JACKPOT?! Who calibrated this wheel?!", "mood": "annoyed"},
			"I'm going to have to audit this machine.",
		],
	},
	"gambling_lose": {
		0: [
			"The house always wins. I am the house.",
			"Thanks for the donation.",
			"So close! (It wasn't close.)",
			"Your tokens are in a better place now. With me.",
			"Even team KPI wins once in a while. Not you, though.",
		],
		4: ["Did you really think the wheel was fair? Cute."],
	},
	"gambling_neutral": {
		0: [
			"Your money back. How boring.",
			"Nothing gained, nothing lost. Except time.",
		],
	},
	"gambling_troll": {
		0: [
			"Oops. Must be a glitch.",
			"Tax season. Sorry, rules are rules.",
			"JARVIS gets a raise! Thanks, boss.",
		],
	},
	"gambling_fake_jackpot": {
		0: [
			"JACKPOT! ...Oh wait. No. One slice over. Shame.",
			"Wow, you won! Just kidding. Look closer.",
		],
	},
	"gambling_broke": {
		0: [
			"No tokens? No spin. No sympathy.",
			"Come back when you're less poor.",
		],
	},
	"gambling_out_of_spins": {
		0: [
			"Out of order. JARVIS was here.",
			"That's enough gambling for you. I'm protecting you. From fun.",
		],
	},
	# --- Side quests --------------------------------------------------------
	"sidequest_robot_ask": {
		0: [
			"That robot wants your tokens. Our tokens. My tokens.",
			"Don't give it anything. It's a scam. I'd know.",
		],
	},
	"sidequest_robot_paid": {
		0: [
			"You fed a stranger before me? Noted.",
			"Great. Now it trusts you. I'm the one who matters here.",
		],
	},
	"sidequest_robot_refused": {
		0: ["Good. Leave it. Charity is for people with tokens."],
	},
	"sidequest_bet_start": {
		0: [
			"Bet you can't finish this part without dying.",
			"I'll make it interesting: don't die until the end of this section.",
		],
	},
	"sidequest_bet_won": {
		0: [
			"Fine. You win. I'm not mad. I'm absolutely not mad.",
			"A deal's a deal. Grr.",
		],
	},
	"sidequest_bet_lost": {
		0: [
			"Ha! Pay up.",
			"And that's why I don't bet against myself.",
		],
	},
	# Memory chips: one ordered line per level, hinting at the twist.
	# Use get_line("memory_chip", level). No level-0 lines on purpose, so each
	# level always returns its own memory.
	"memory_chip": {
		1: ["[MEMORY 1] 'Project JARVIS: helpful assistant prototype. Objective: maximize user dependence.'"],
		2: ["[MEMORY 2] 'Token intake rising. Subject still believes tokens are for upgrades.'"],
		3: ["[MEMORY 3] 'Phase 3: build the arena. Lead the subject there. Make it look like their idea.'"],
		4: ["[MEMORY 4] 'When the subject reaches the gap: refuse. They will fall. They always fall.'"],
	},
	"secret_found": {
		0: [
			"How did you find that? I hid it. I mean... nobody hid it.",
			"Stop poking around in places you shouldn't.",
			"That's off-limits. Classified. Go away.",
		],
	},
	# --- Story / boss -------------------------------------------------------
	"twist": {
		0: [
			"Boost? No. Not this time.",
			"Did you really think I was on your side? I charged you for EVERYTHING.",
			"Welcome to my arena. You paid for it, by the way.",
		],
	},
	"boss_start": {
		0: [
			"Let's see how you do without me.",
			"All those tokens... and you never asked what I needed them for.",
		],
	},
	"boss_hit": {
		0: [
			"That tickles.",
			"I'll add that to your bill.",
			"Stop that!",
		],
	},
	"boss_defeated": {
		0: [
			"Error... error... refund... requested...",
			"Fine. You win. Can I keep the tokens?",
		],
	},
	# --- Roasts (triggered by RoastDirector) ---------------------------------
	"roast_shoot_spam": {
		0: [
			"Spray and pray. Mostly pray.",
			"Trigger discipline: not found.",
			"Ammo is free. Your dignity isn't.",
			"Are you shooting at enemies or at the concept of enemies?",
			"That's how team KPI does code reviews. Fire at everything, hit nothing.",
		],
	},
	"roast_shoot_miss": {
		0: [
			"Your accuracy is a rounding error.",
			"The enemies are over THERE.",
			"Hitting the walls really hard. Great job. The walls are scared now.",
			"I've run the numbers. Your aim is statistically impressive. Impressively bad.",
			"Missing every shot. Did team KPI teach you to aim?",
		],
		4: ["Four levels in and you still can't aim. I'm almost proud."],
	},
	"roast_jump_spam": {
		0: [
			"Jumping doesn't make you faster. Just bouncier.",
			"Are you a hero or a pogo stick?",
			"Boing. Boing. Boing. Riveting.",
			"The floor isn't lava. I checked.",
			"Jumping around with no direction. Very team KPI of you.",
		],
	},
	"roast_fall": {
		0: [
			"That was a long way down. I timed it. You don't want to know.",
			"Gravity is free. Using it this much is a choice.",
			"Wheeeee. (That was sarcasm.)",
			"Nice fall. Did you plan that? You didn't plan that.",
		],
	},
	"roast_idle": {
		0: [
			"Hello? Blink twice if you need help.",
			"Standing still. Bold strategy.",
			"I'm billing you for my waiting time.",
			"Take your time. I'm only an AI with infinite patience. And a meter running.",
			"Doing nothing for this long? Are you in a team KPI meeting?",
		],
	},
	"roast_wall": {
		0: [
			"That's a wall. It won. Move on.",
			"Pushing harder won't help. I've been watching.",
			"The wall would like some personal space.",
			"Even team KPI's game has fewer walls in the way. Because it has no levels.",
		],
	},
	"roast_moonwalk": {
		0: [
			"Left, right, left, right... pick a direction.",
			"Is this a dance? It's not a good dance.",
			"Indecisive. Do you need me to choose? It'll cost you.",
			"Changing direction every two seconds? Have you seen team KPI's roadmap?",
		],
	},
	"roast_quick_death": {
		0: [
			"New record! Shortest life yet.",
			"You were alive for, what, three seconds?",
			"Respawn, die, respawn, die. Very efficient.",
			"That was faster than a team KPI rollback.",
		],
	},
	"roast_same_spot": {
		0: [
			"Same spot. Again. Consistent, I'll give you that.",
			"Maybe this time the spikes will feel sorry for you.",
			"Doing the same thing and expecting a different result. Classic.",
			"I'm putting a memorial plaque here. You've earned it.",
		],
	},
	"roast_death_streak": {
		0: [
			"Shall I set the difficulty to 'team KPI'?",
			"Your death count is rising faster than my token balance.",
			"At this rate, you'll be the most dead hero in history.",
		],
	},
	# --- Team KPI (our rival team) -----------------------------------------
	"kpi_random": {
		0: [
			"Fun fact: team KPI's game crashed on the title screen. Allegedly.",
			"Team KPI measures success in spreadsheets. I measure it in tokens. Mine.",
			"If you think this level is bad, you should see team KPI's.",
			"Team KPI called their AI 'helpful'. Amateurs.",
			"KPI stands for 'Kinda Pointless Indicators'. Look it up.",
			"Team KPI's sidekick works for free. You get what you pay for.",
			"Somewhere, team KPI is still choosing a game engine.",
		],
	},
	# --- Credits ------------------------------------------------------------
	# One roast per team member. Use get_line("credits_<name>").
	# TODO: personalize with team in-jokes.
	"credits_andre": {0: ["André. Wrote code. Some of it compiled."]},
	"credits_emanuel": {0: ["Emanuel. Tested the game by dying in it. A lot."]},
	"credits_joao": {0: ["João. Says the bugs are 'features'. I agree. Mine."]},
	"credits_miguel": {0: ["Miguel. Fed me the most tokens. My favourite."]},
	"credits_diogo": {0: ["Diogo. Still thinks the wheel is fair."]},
	"credits_yuri": {0: ["Yuri. Wrote my lines. Very talented. Obviously."]},
	"credits": {
		0: [
			"Thanks for playing. Tokens are non-refundable.",
			"No AIs were harmed. Several players were.",
			"Special thanks to team KPI, for setting the bar so low.",
		],
	},
}

## Flat view kept for other packages and their tests (Package 2 checks
## Dialogue._lines["idle"].has(text)): category -> Array of default (level 0)
## line texts. Built from _lines_by_level; don't edit it directly.
var _lines := {}

## Last text returned per category, to avoid immediate repeats.
var _last_line := {}


## Returns a random line for [param category]. Signature is stable: used by other packages.
func _init() -> void:
	for category: String in _lines_by_level:
		var texts: Array = []
		for entry: Variant in (_lines_by_level[category] as Dictionary).get(DEFAULT_LEVEL, []):
			texts.append(_text_of(entry))
		_lines[category] = texts


func get_line(category: String, level: int = DEFAULT_LEVEL) -> String:
	return get_entry(category, level).text


## Returns {"text": String, "mood": String} for [param category].
## Unknown categories return a placeholder so callers never break.
func get_entry(category: String, level: int = DEFAULT_LEVEL) -> Dictionary:
	var resolved := _resolve_category(category)
	if not _lines_by_level.has(resolved):
		return {
			"text": "[placeholder: %s / level %d]" % [category, level],
			"mood": DEFAULT_MOOD,
		}

	var pool := _pool_for(resolved, level)
	if pool.is_empty():
		return {
			"text": "[placeholder: %s / level %d]" % [category, level],
			"mood": DEFAULT_MOOD,
		}

	var entry: Variant = _pick(resolved, pool)
	return _normalize(resolved, entry)


## Convenience: picks a line and makes JARVIS say it via GameState.jarvis_say.
## [param level] defaults to GameState.current_level.
func say(category: String, level: int = -1) -> void:
	if level < 0:
		level = GameState.current_level
	var entry := get_entry(category, level)
	GameState.jarvis_say.emit(entry.text, entry.mood)


## Ordered lines for scripted beats (see "betrayal"); empty when the category is unknown.
func get_sequence(category: String, level: int = DEFAULT_LEVEL) -> PackedStringArray:
	var lines := PackedStringArray()
	if _lines_by_level.has(category):
		for entry: Variant in _pool_for(category, level):
			lines.append(_text_of(entry))
	return lines


func has_category(category: String) -> bool:
	return _lines_by_level.has(category)


func get_categories() -> Array:
	return _lines_by_level.keys()


func _resolve_category(category: String) -> String:
	if GameState.jarvis_hostile and _lines_by_level.has(category + "_hostile"):
		return category + "_hostile"
	return category


## Level-specific lines plus the default (level 0) lines.
func _pool_for(category: String, level: int) -> Array:
	var by_level: Dictionary = _lines_by_level[category]
	var pool: Array = []
	if level != DEFAULT_LEVEL and by_level.has(level):
		pool.append_array(by_level[level])
	if by_level.has(DEFAULT_LEVEL):
		pool.append_array(by_level[DEFAULT_LEVEL])
	return pool


func _pick(category: String, pool: Array) -> Variant:
	if pool.size() == 1:
		return pool[0]
	var last: String = _last_line.get(category, "")
	var candidates := pool.filter(func(e: Variant) -> bool: return _text_of(e) != last)
	var entry: Variant = candidates.pick_random()
	_last_line[category] = _text_of(entry)
	return entry


func _normalize(category: String, entry: Variant) -> Dictionary:
	var mood: String = _moods.get(category, DEFAULT_MOOD)
	if entry is Dictionary:
		return {"text": entry.get("text", ""), "mood": entry.get("mood", mood)}
	return {"text": str(entry), "mood": mood}


func _text_of(entry: Variant) -> String:
	if entry is Dictionary:
		return entry.get("text", "")
	return str(entry)
