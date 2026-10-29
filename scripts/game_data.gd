extends Node

const UNIT: float = 4.0
const WALL_HEIGHT: float = 3.8
const STATUE_FEAR_RADIUS: float = 9.0
const STEP_THRESH: float = 1.8
const BAIT_MAX: int = 3
const FINAL_TRIGGER: int = 30
const FINAL_TRIGGER_STEPS: int = 30
const HUNTER_MULT: float = 2.0
const TOTAL_DAYS: int = 5
const CRAWLER_BITE_MAX: int = 4
const MOP_HIT_COST: float = 25.0

# Exact HTML Tile Enums:
# 0=Corridor, 1=Wall, 2=Keycard, 3=GateTrap, 4=Exit, 5=BioTank, 6=Spill, 7=Terminal, 8=LoreNote, 9=MapFragment, 10=Artifact, 11=Staircase
enum TileType {
	CORRIDOR = 0,
	WALL = 1,
	KEYCARD = 2,
	TRAP = 3,
	EXIT = 4,
	BIOTANK = 5,
	SPILL = 6,
	TERMINAL = 7,
	LORE_NOTE = 8,
	MAP_FRAGMENT = 9,
	ARTIFACT = 10,
	STAIRCASE = 11
}

# Night 1 (15x15) — Sub-Level 4
const MAZE_DAY1: Array = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,6,0,1,0,5,0,0,7,1,2,0,8,1],
	[1,0,1,0,1,0,1,1,1,0,1,1,1,0,1],
	[1,7,1,0,0,6,0,2,1,10,0,5,0,9,1],
	[1,0,1,1,1,1,1,0,1,1,1,1,1,0,1],
	[1,0,0,8,0,0,0,0,6,0,0,9,1,0,1],
	[1,1,1,0,1,0,1,1,1,1,1,0,1,0,1],
	[1,0,5,0,1,0,3,0,0,0,1,0,10,8,1],
	[1,0,1,0,1,1,1,1,1,0,1,1,1,0,1],
	[1,0,1,0,0,0,0,10,1,0,0,0,0,0,1],
	[1,0,0,0,1,1,1,0,1,1,1,0,1,9,1],
	[1,2,1,0,1,0,0,0,0,0,1,3,1,0,1],
	[1,0,1,0,1,0,1,1,1,0,1,0,1,8,1],
	[1,0,0,0,0,0,0,5,0,0,0,0,0,4,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
]

# Night 2 (19x19) — Sub-Level 6
const MAZE_DAY2: Array = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,0,0,5,0,0,10,1,0,0,0,0,0,2,8,1],
	[1,0,1,0,1,0,1,0,1,1,1,0,1,1,1,0,1,0,1],
	[1,6,1,0,0,0,1,0,0,7,0,0,1,0,0,9,1,0,1],
	[1,0,1,0,1,0,1,1,1,0,1,3,1,10,1,0,1,0,1],
	[1,0,0,0,0,0,0,0,1,0,0,0,0,8,1,0,0,0,1],
	[1,1,1,0,1,1,1,0,1,1,1,0,1,0,1,1,1,0,1],
	[1,0,0,0,0,0,0,6,0,0,1,0,0,0,0,5,0,0,1],
	[1,0,1,1,1,0,1,0,1,0,1,1,1,0,1,0,1,10,1],
	[1,0,1,2,0,0,1,0,1,0,0,0,1,0,0,0,1,0,1],
	[1,0,1,1,1,0,0,0,1,0,1,0,1,1,1,0,1,0,1],
	[1,0,0,0,0,9,1,0,0,0,1,6,0,0,1,0,0,8,1],
	[1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
	[1,0,0,0,1,0,0,0,0,0,1,0,0,0,3,0,0,0,1],
	[1,0,1,1,1,0,1,0,1,1,1,0,1,1,1,0,1,0,1],
	[1,8,1,0,0,0,1,0,0,7,0,0,0,5,0,0,0,2,1],
	[1,0,1,0,1,1,1,0,1,0,1,9,1,0,1,0,1,0,1],
	[1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,4,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
]

# Night 3 (21x21) — Sub-Level 9
const MAZE_DAY3: Array = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,1,0,0,8,0,0,1,0,0,0,1,0,0,10,0,0,1],
	[1,0,1,0,1,0,1,1,1,0,1,0,1,0,1,0,1,1,1,0,1],
	[1,6,1,0,0,0,1,5,0,0,10,0,1,0,0,9,1,0,0,0,1],
	[1,0,1,1,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,1,1],
	[1,0,0,0,1,7,0,0,1,0,0,0,0,0,1,0,3,0,0,0,1],
	[1,0,1,0,1,1,1,0,1,3,1,1,1,0,1,1,1,0,1,0,1],
	[1,0,0,0,0,0,0,6,0,0,0,0,0,0,0,0,1,0,0,2,1],
	[1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,0,1,0,1,0,1],
	[1,0,1,0,0,0,1,0,1,0,0,0,1,0,10,0,0,8,0,0,1],
	[1,0,1,0,1,1,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1],
	[1,9,0,0,1,0,0,0,0,0,1,0,0,0,1,0,0,0,2,0,1],
	[1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,0,1,1,1,0,1],
	[1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,5,0,0,0,0,1],
	[1,1,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,0,1],
	[1,0,0,0,0,7,0,0,1,0,0,0,0,0,0,0,1,2,0,0,1],
	[1,0,1,1,1,0,1,1,1,0,1,1,1,3,1,1,1,0,1,0,1],
	[1,8,1,0,0,0,0,0,0,6,0,0,0,0,0,0,0,0,1,9,1],
	[1,0,1,0,1,0,1,1,1,0,1,1,1,0,1,0,1,0,1,0,1],
	[1,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,4,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
]

# Night 4 (23x23) — Sub-Level 12 · The Archive
const MAZE_DAY4: Array = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,1,0,0,0,0,0,0,0,0,8,0,0,0,0,0,3,0,0,1],
	[1,1,1,0,1,0,1,1,1,1,1,0,1,1,1,1,9,1,1,1,1,0,1],
	[1,0,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,1,0,0,0,1],
	[1,0,1,1,1,0,1,0,1,1,1,6,1,0,1,1,1,0,1,1,1,0,1],
	[1,0,0,0,1,0,1,0,0,0,1,0,0,0,0,6,1,0,0,0,0,0,1],
	[1,1,1,8,1,1,1,1,1,0,1,1,1,0,1,1,1,1,1,0,1,5,1],
	[1,10,1,0,0,0,0,0,1,0,0,3,0,0,1,0,6,0,0,0,1,0,1],
	[1,8,1,1,1,1,1,9,1,0,1,1,1,1,1,0,1,1,1,1,1,0,1],
	[1,0,0,3,0,0,1,0,1,6,0,0,1,0,0,0,1,0,1,0,3,0,1],
	[1,0,1,1,0,1,1,0,1,1,1,0,1,5,1,1,1,7,1,0,1,1,1],
	[1,0,1,0,0,0,0,5,1,0,8,0,1,0,1,0,0,7,2,0,0,5,1],
	[1,0,1,0,1,1,1,1,1,0,1,1,1,0,1,1,1,1,1,1,1,0,1],
	[1,5,0,0,1,0,1,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,1],
	[1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,5,1,1,1,0,1,0,1],
	[1,0,0,0,1,0,0,0,1,0,6,0,0,0,1,0,0,0,1,0,1,0,1],
	[1,1,1,0,1,1,1,1,1,0,1,0,1,1,1,0,1,0,1,0,1,0,1],
	[1,10,1,0,0,6,0,7,1,0,0,0,0,0,0,0,0,0,1,0,1,0,1],
	[1,0,1,0,1,1,1,0,1,0,1,0,1,1,1,1,1,1,1,0,1,0,1],
	[1,0,0,0,0,0,1,0,1,0,0,0,1,0,0,3,0,0,1,0,1,6,1],
	[1,0,1,0,1,1,1,3,1,1,1,0,1,0,1,1,1,0,1,0,1,2,1],
	[1,0,1,0,0,2,0,0,0,9,0,5,0,0,1,10,0,0,0,0,1,4,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
]

# Night 5 (27x27) — Sub-Level 15 · The Tether
const MAZE_DAY5: Array = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,1,0,0,0,0,0,0,0,0,6,1,0,5,0,0,0,6,0,1,0,0,0,1],
	[1,1,1,0,1,0,0,0,1,0,1,1,1,0,1,1,1,0,1,0,1,1,1,0,1,6,1],
	[1,0,1,0,0,0,1,0,1,0,0,0,1,0,0,0,1,0,1,0,1,0,0,0,1,0,1],
	[1,0,1,1,1,1,1,0,1,0,1,0,1,1,1,0,1,0,1,0,1,0,1,1,1,0,1],
	[1,0,0,0,1,0,0,0,1,3,1,0,0,0,0,0,1,0,7,0,0,0,1,0,0,0,1],
	[1,1,1,0,1,0,1,1,1,0,1,1,1,0,1,3,1,1,1,0,1,1,1,0,1,0,1],
	[1,0,0,0,1,0,1,0,1,0,1,0,0,0,1,0,5,0,0,0,0,0,0,0,1,0,1],
	[1,9,1,0,1,0,9,5,1,0,1,0,1,0,1,1,1,1,1,1,1,1,1,1,1,0,1],
	[1,0,0,0,0,0,1,6,0,0,1,0,0,7,1,0,0,0,0,0,0,0,0,2,1,0,1],
	[1,0,1,1,1,0,1,0,1,1,1,1,1,0,0,0,1,1,1,0,1,0,1,0,1,0,1],
	[1,0,1,0,0,0,3,0,0,0,0,0,1,5,1,0,1,0,7,0,1,0,1,0,0,0,1],
	[1,0,1,1,1,0,1,1,1,1,1,1,1,0,3,0,1,1,1,1,1,0,1,1,1,1,1],
	[1,0,0,0,8,0,1,0,0,0,0,0,0,0,1,0,0,6,0,0,1,0,0,5,0,0,1],
	[1,1,1,1,1,0,1,0,1,0,1,1,0,1,1,0,1,0,1,3,1,0,1,0,1,0,1],
	[1,10,1,0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,1,0,0,0,1,0,1,2,1],
	[1,0,1,0,1,1,1,0,1,0,1,0,1,1,1,1,1,1,1,1,1,1,1,0,1,0,1],
	[1,0,1,0,1,0,0,0,1,0,0,0,1,10,1,0,0,0,0,0,0,0,0,0,1,0,1],
	[1,0,1,6,1,0,1,3,1,0,1,1,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1],
	[1,0,0,0,1,0,1,0,1,0,0,0,1,0,0,0,1,0,0,6,0,0,0,0,0,0,1],
	[1,6,1,1,1,1,1,0,1,1,1,5,1,1,1,1,1,1,1,0,1,1,1,0,1,0,1],
	[1,0,8,0,0,0,1,0,0,0,1,0,3,0,0,0,0,0,1,0,1,0,0,0,0,0,1],
	[1,1,1,0,1,0,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,0,1,1,1,0,1],
	[1,0,0,0,1,0,0,5,0,0,1,0,0,0,0,0,1,0,0,9,0,0,1,0,0,0,1],
	[1,0,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,0,1,0,1,0,1,1,1],
	[1,10,1,0,0,2,0,0,0,3,0,0,0,8,0,0,0,5,0,0,0,0,0,8,0,4,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
]

const ALL_MAZES: Array = [MAZE_DAY1, MAZE_DAY2, MAZE_DAY3, MAZE_DAY4, MAZE_DAY5]

# 0-indexed Day Meta matching ALL_MAZES (Nights 1 to 5 at indices 0..4)
const DAY_META: Array = [
	{
		"name": "Night 1: Routine Maintenance",
		"title": "AETHELGARD BIOTECH — SUB-LEVEL 4",
		"label": "NIGHT 1",
		"color": Color(0.13, 0.83, 0.93),
		"wage": 100, "spills": 3, "terms": 2, "blood": 3, "dist": 200,
		"crawlers": 4, "statues": 0, "cultists": 0, "cloaks": 0, "speed": 5.6
	},
	{
		"name": "Night 2: Biological Containment",
		"title": "AETHELGARD BIOTECH — SUB-LEVEL 6",
		"label": "NIGHT 2",
		"color": Color(0.96, 0.62, 0.07),
		"wage": 200, "spills": 3, "terms": 2, "blood": 3, "dist": 200,
		"crawlers": 5, "statues": 2, "cultists": 0, "cloaks": 0, "speed": 5.9
	},
	{
		"name": "Night 3: Structural Collapse",
		"title": "AETHELGARD BIOTECH — SUB-LEVEL 9",
		"label": "NIGHT 3",
		"color": Color(0.94, 0.27, 0.27),
		"wage": 300, "spills": 3, "terms": 2, "blood": 3, "dist": 200,
		"crawlers": 6, "statues": 2, "cultists": 2, "cloaks": 0, "speed": 6.2
	},
	{
		"name": "Night 4: The Archive",
		"title": "AETHELGARD BIOTECH — SUB-LEVEL 12 · THE ARCHIVE",
		"label": "NIGHT 4",
		"color": Color(0.65, 0.55, 0.98),
		"wage": 400, "spills": 3, "terms": 2, "blood": 3, "dist": 200,
		"crawlers": 6, "statues": 3, "cultists": 3, "cloaks": 2, "speed": 6.4
	},
	{
		"name": "Night 5: The Tether",
		"title": "AETHELGARD BIOTECH — SUB-LEVEL 15 · THE TETHER",
		"label": "NIGHT 5",
		"color": Color(0.96, 0.25, 0.37),
		"wage": 500, "spills": 3, "terms": 2, "blood": 3, "dist": 200,
		"crawlers": 6, "statues": 4, "cultists": 3, "cloaks": 3, "speed": 6.7
	}
]

const RELIC_WHISPERS: Array[String] = [
	"a name you almost remember",
	"the floor sighs under you",
	"someone counts your steps",
	"a lullaby in the pipes",
	"your reflection blinks late",
	"warm hands that are not yours",
	"the walls lean closer",
	"a door closes upstairs, far away",
	"it knows your shift number",
	"teeth behind the vents",
	"the mop handle pulses",
	"a choir, very far down",
	"the Tenant turns its head",
	"almost whole now",
	"the last hum — it is nearly time"
]

const CUTSCENES: Dictionary = {
	"intro": [
		{
			"speaker": "NARRATOR",
			"text": "01:45 AM. Room 4B. The rain hasn't stopped in three days. A single bare bulb sways from the ceiling cord, casting weak yellow light over dusty cardboard boxes, tangled wires, and overturned cups.",
			"art": "room_rain_bulb"
		},
		{
			"speaker": "INNER THOUGHT",
			"text": "On the cluttered desk sits a red-stamped letter from the landlord: 'FINAL EVICTION NOTICE — $840 PAST DUE.' Beside it, my phone buzzes violently across the wood—14 missed calls and texts demanding rent by dawn. I only have $4.50 left.",
			"art": "desk_notice_phone"
		},
		{
			"speaker": "NARRATOR",
			"text": "Unable to stay in that suffocating room, you pull on a threadbare coat and step out into the flooded midnight street. Freezing rain hammers the asphalt as you walk past dark storefronts, desperate for any job that pays tonight.",
			"art": "walk_rain_street"
		},
		{
			"speaker": "NARRATOR",
			"text": "Under a flickering streetlamp at 4th and Mercer, a soaked yellow flyer clings to the wet brick wall: 'NIGHT JANITOR WANTED — AETHELGARD BIOTECH — $100 / NIGHT INSTANT WIRE — CALL 555-0199.'",
			"art": "flyer_wall"
		},
		{
			"speaker": "HARLOW (ON PHONE)",
			"text": "You tear off a wet paper tab and dial 555-0199 in the pouring rain. It connects before the first ring finishes: 'We've been waiting for your call, Employee #8. Your eviction ledger is cleared once you clock in. Come to Freight Elevator #4.'",
			"art": "calling_phone"
		},
		{
			"speaker": "NARRATOR",
			"text": "Twenty minutes later, the rusted gates of Elevator #4 groan shut behind you. The cables shudder as you descend deep beneath the city into Sub-Level 4.",
			"art": "elevator"
		}
	],
	"chaseBegin": [
		{ "speaker": "FACILITY ALARM", "text": "ALL CONTAINMENT LOCKS — DISENGAGED. SPECIMEN ZERO UNBOUND.", "art": "alarm" },
		{ "speaker": "ENTITY", "text": "...every step you take, I take two.", "art": "monster_eyes" },
		{ "speaker": "YOU", "text": "Three keycards in the corridors. Find them and RUN.", "art": "run" }
	],
	"entityBlocksDoor": [
		{ "speaker": "SYSTEM", "text": "EXIT GATE: ACCESS DENIED. Insufficient security clearance (3 Keycards required).", "art": "blocked_door" },
		{ "speaker": "ENTITY", "text": "...you thought you could leave before the shift was finished?", "art": "monster_close" }
	],
	"nextDay": [
		{ "speaker": "NARRATOR", "text": "The heavy blast doors slam behind you. On your phone: 'WIRE TRANSFER CONFIRMED: $100.00 — VANCE HOLDINGS LLC.'", "art": "city_pay" },
		{ "speaker": "INNER THOUGHT", "text": "Four more missed calls from Aethelgard HR. One more night, they say. Then my debt is gone.", "art": "phone" }
	],
	"interlude0": [
		{ "speaker": "SYSTEM", "text": "SHIFT 1 COMPLETE. Mandatory Overtime authorised: SUB-LEVEL 6. Refusal penalty: Immediate Eviction & Asset Seizure.", "art": "ledger" },
		{ "speaker": "INNER THOUGHT", "text": "Wait... why was my rent wire routed back into Aethelgard's own bank account? And why does the elevator only go further down?", "art": "stairs" },
		{ "speaker": "ENTITY", "text": "...the stone observers are awake on Floor 6. Do not take your eyes off them.", "art": "eyes" }
	],
	"interlude1": [
		{ "speaker": "NARRATOR", "text": "Sub-Level 9. The stairwell breathes like a living throat. Down here, the concrete walls are fever-warm.", "art": "stairs" },
		{ "speaker": "HARLOW (OVER INTERCOM)", "text": "Exemplary work, Employee #8. You've lasted longer than Janitor #7. Mind the robed Choir in the lower ring—they don't wait for you to move.", "art": "rings" },
		{ "speaker": "YOU", "text": "The wooden mop handle pulses against my palms like a heartbeat. Whatever is down here... it knows my name.", "art": "eyes" }
	],
	"interlude2": [
		{ "speaker": "SYSTEM", "text": "SUB-LEVEL 12 ARCHIVE ACCESS GRANTED — 1,204 JANITORIAL PERSONNEL FILES.", "art": "ledger" },
		{ "speaker": "NARRATOR", "text": "You open the cabinet. Every single file has your photograph, the same Room 4B eviction notice, and the same $4.50 bank balance.", "art": "desk_notice_phone" },
		{ "speaker": "INNER THOUGHT", "text": "Mr. Vance never existed. The flyer on 4th Avenue was printed ten minutes before I walked outside. There is no surface left to return to.", "art": "flyer_wall" }
	],
	"interlude3": [
		{ "speaker": "SYSTEM", "text": "SUB-LEVEL 15 — PROJECT TETHER: FINAL CONVERGENCE. HOST ZERO: AWAKE.", "art": "rings" },
		{ "speaker": "ENTITY", "text": "Bring me the last keycards, little janitor. Take your billion-dollar severance and carry my signal to every screen on Earth.", "art": "monster_close" },
		{ "speaker": "YOU", "text": "...Janitor #7 wrote about a hidden Sanctuary Corridor in the north wall (row 0, col 13). Three pedestals. Fifteen relics. Tonight I break the Tether.", "art": "stairs" }
	],
	"endingFired": [
		{ "speaker": "HARLOW (OVER INTERCOM)", "text": "Sub-level 15 is now closed to staff. Your employment is terminated, effective immediately.", "art": "street" },
		{ "speaker": "SYSTEM", "text": "CONTRACT COMPLETION BONUS: $1,000,000,000.00 ($1 BILLION) CREDITED TO YOUR ACCOUNT.", "art": "bills" },
		{ "speaker": "INNER THOUGHT", "text": "One billion dollars... Every debt paid. I'm finally back on the street. Wait—why is my phone screen glowing blood-red?", "art": "phone" },
		{ "speaker": "ENTITY (BROADCAST SIGNAL)", "text": "Did you think the money was for mopping floors? You were the antenna. You carried our signal to the surface.", "art": "eyes" },
		{ "speaker": "NARRATOR", "text": "Every billboard, television, and smartphone screen across the city flickers crimson. Behind the glass, seven eyes open.", "art": "earth" },
		{ "speaker": "YOU", "text": "The $1,000,000,000 balance dissolves into red static. Through every screen on Earth, Subject Zero steps out.", "art": "earth" }
	],
	"endingEarth": [
		{ "speaker": "NARRATOR", "text": "Fifteen relics recovered. All three Sanctuary Pedestals in the hidden north corridor sealed.", "art": "rings" },
		{ "speaker": "ENTITY", "text": "NO! You found the Omega Sanctuary... You severed the debt ledger from Host Zero!", "art": "monster_eyes" },
		{ "speaker": "NARRATOR", "text": "The biological walls convulse and calcify into silent stone as the blast doors lock permanently from the inside.", "art": "stairs" },
		{ "speaker": "YOU", "text": "The phone on my desk stops buzzing. The rain finally clears over the city. Tonight, the seal holds—and Earth is safe.", "art": "street" }
	]
}

const LORE_NOTES: Dictionary = {
	"note_entry": {
		"day": 1,
		"title": "EMPLOYEE INTAKE MEMO — #8",
		"tag": "HR DOCUMENT • SUB-LEVEL 4",
		"body": "Welcome to your first night shift at Aethelgard Biotech, Employee #8.\n\nPer your 01:52 AM telephone agreement (Ref: 555-0199), your Room 4B eviction order has been stayed pending completion of five (5) mandatory night shifts.\n\nNightly Quota: Mop 3 toxic bio-spills, scrub 3 blood stains, and verify 2 science terminals.\n\nWARNING: Keycards to the exit remain locked in security suppression until containment breach protocols activate.\n\n— Shift Supervisor Harlow"
	},
	"note_warning": {
		"day": 1,
		"title": "TORN STICKY NOTE ON WALL",
		"tag": "PERSONAL NOTE • JANITOR #7",
		"body": "If you answered the yellow flyer on 4th Ave... I'm sorry.\n\nWhen you finish mopping, the main bio-tank shatters. The tall thing (Subject Zero) only moves when YOU move—but it moves TWICE as fast as you.\n\nIf you stand still, it stands still. But the small Crawlers in the cages DO NOT STOP when you stand still!\n\nThree yellow keycards only materialize once the alarm sounds. Grab all 3 or the Entity will slam you back from the Exit.\n\n— Janitor #7"
	},
	"note_map": {
		"day": 1,
		"title": "SECURITY & LOCKER PROTOCOL",
		"tag": "FACILITY MANUAL",
		"body": "1. BLUE LOCKERS: Press [E] to hide inside a locker. If Subject Zero is >12 steps away, it will lose your trail. If it sees you enter up close, it will rip the locker door open.\n\n2. MOP COMBAT [LMB]: Your mop can crush Crawlers (-10% durability), stagger Cultists (-33%), or stun Subject Zero for 4.5s (-33%). At <=30 steps left, Subject Zero enters FINAL RAGE and can no longer be stunned.\n\n3. CHEMICAL BAIT [B]: Toss bait to lure Crawlers and Cultists away."
	},
	"note_trap": {
		"day": 1,
		"title": "HAZMAT GATE & OVERRIDE [R]",
		"tag": "TECHNICAL MANUAL",
		"body": "SECURITY GATES: Press [E] at any gate lever to drop the steel bars for 30 seconds. Neither Subject Zero nor lesser specimens can pass through a closed gate.\n\nCONTAINMENT OVERRIDE [R]: During a breach, press [R] to open the timing bar and press [R] or [SPACE] in the green zone to push Subject Zero back +20 steps (failure costs -25 steps)."
	},
	"note_intake": {
		"day": 1,
		"title": "EMPLOYEE INTAKE MEMO — #8",
		"tag": "HR DOCUMENT • SUB-LEVEL 4",
		"body": "Welcome to your first night shift at Aethelgard Biotech, Employee #8.\n\nPer your 01:52 AM telephone agreement (Ref: 555-0199), your Room 4B eviction order has been stayed pending completion of five (5) mandatory night shifts.\n\nNightly Quota: Mop 3 toxic bio-spills, scrub 3 blood stains, and verify 2 science terminals.\n\n— Shift Supervisor Harlow"
	},
	"note_gate": {
		"day": 1,
		"title": "HAZMAT GATE & OVERRIDE [R]",
		"tag": "TECHNICAL MANUAL",
		"body": "SECURITY GATES: Press [E] at any gate lever to drop the steel bars for 30 seconds. Creatures cannot pass a closed gate.\n\nCONTAINMENT OVERRIDE [R]: Press [R] during chase to hack the containment pulse and drive the Entity back +20 steps."
	},
	"n2_1": {
		"day": 2,
		"title": "SHELL COMPANY LEDGER: 'MR. VANCE'",
		"tag": "CONFIDENTIAL FINANCE",
		"body": "ACQUISITION RECORD — VANCE HOLDINGS LLC (Wholly Owned Subsidiary of Aethelgard Biotech):\n\n• Property: Room 4B Tenement Block\n• Target: Employee #8 — Engineered Bank Balance: $4.50\n• Automated SMS Harassment: 14 missed calls + Final Eviction Notice dispatched at 01:40 AM.\n• Street Flyer Placement (555-0199): 01:42 AM.\n\nSubject took the bait in 7 minutes. Debt is now legally bound to Project Tether."
	},
	"n2_2": {
		"day": 2,
		"title": "INCIDENT #44: THE WEEPING OBSERVERS",
		"tag": "CONTAINMENT REPORT • SUB-LEVEL 6",
		"body": "The calcified stone statues on Sub-Level 6 are former janitors who looked directly into the Tether Core.\n\n1. Keep them in your camera view (or flashlight beam) to freeze them in place.\n2. If you look away while moving, they glide silently behind you and twist your head 180 degrees.\n3. ANOMALY: Subject Zero fears the Observers and will be repelled if lured within 9 meters of one."
	},
	"n3_1": {
		"day": 3,
		"title": "THE SUB-RING CHOIR & THE AUDIENCE",
		"tag": "CULT ARCHIVE • SUB-LEVEL 9",
		"body": "The crimson-robed Cultists patrolling Sub-Level 9 worship Subject Zero as 'The Tenant'.\n\nUnlike Subject Zero, Cultists move in real time even if you stand completely still! Strike them with your mop [LMB] to stagger them for 3.5 seconds, or lure them with Chemical Bait [B].\n\nDo NOT attempt to pause or abandon your shift when the Entity is close—it can cross the UI boundary."
	},
	"n3_2": {
		"day": 3,
		"title": "JANITOR #7 — AUDIO TRANSCRIPT",
		"tag": "PERSONAL LOG",
		"body": "I escaped Night 5 once without the relics. They wired $1,000,000,000 to my phone and let me walk out onto 4th Avenue.\n\nThen my phone screen turned red. Every screen in the city turned red. The $1 Billion wasn't a paycheck—it was a carrier wave that broadcast the Entity through the global financial network.\n\nNext thing I knew, I woke up back in Room 4B with $4.50 on the desk."
	},
	"n4_1": {
		"day": 4,
		"title": "PROJECT TETHER: HOST ZERO",
		"tag": "OMEGA CLASSIFIED • SUB-LEVEL 12",
		"body": "Founder Aldric Aethelgard discovered an extra-dimensional parasite that feeds on human desperation and unpaid obligation.\n\nAldric volunteered as Host Zero—becoming Subject Zero—while 1,204 cloned iterations of the same janitor are cycled through the sub-levels night after night to charge the broadcast array."
	},
	"n5_1": {
		"day": 5,
		"title": "HOW TO REACH THE TRUE ENDING",
		"tag": "JANITOR #7'S FINAL MAP",
		"body": "LISTEN TO ME: Do NOT trust the $1 Billion severance!\n\nOn Night 5 (Sub-Level 15), there is a hidden doorway in the NORTH WALL at Row 0, Column 13 leading into the OMEGA SANCTUARY CORRIDOR.\n\nInside that corridor, the step counter pauses and monsters cannot enter. Walk to the far end and activate all 3 SANCTUARY PEDESTALS (or collect all 15 Relics) BEFORE escaping through the Exit!"
	}
}
