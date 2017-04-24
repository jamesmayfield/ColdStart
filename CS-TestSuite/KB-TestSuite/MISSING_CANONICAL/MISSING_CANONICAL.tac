MISSING_CANONICAL

# Tim Samaras
:Entity004	type	PER
#           v This entity is mentioned twice in document NYT_ENG_20130603.0033, but none of these mentions are identified as the canonical_mention
:Entity004	mention	"Samaras"	NYT_ENG_20130603.0033:841-847	1.0
:Entity004	mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0
:Entity004	per:parents	:Entity005	NYT_ENG_20130603.0033:881-889	0.47161733042400245

# Paul
:Entity005	type	PER
#               v This entity is mentioned once in document NYT_ENG_20130603.0033, but the mention is not identified as the canonical_mention
:Entity005	mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0
:Entity005	per:children	:Entity004	NYT_ENG_20130603.0033:881-889	0.47161733042400245
