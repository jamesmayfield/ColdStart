UNASSERTED_CANONICAL

# Tim Samaras
:Entity004	type	PER
#               v There are multiple mentions but no canonical_mention specified
:Entity004	nominal_mention	"son"	NYT_ENG_20130603.0033:881-883	1.0
:Entity004	mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0
:Entity004	per:parents	:Entity005	NYT_ENG_20130603.0033:881-889	0.47161733042400245

# Paul
:Entity005	type	PER
#               v There should be a canonical_mention matching this mention
:Entity005	mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0
:Entity005	per:children	:Entity004	NYT_ENG_20130603.0033:881-889	0.47161733042400245
