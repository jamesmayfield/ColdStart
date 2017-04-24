AMBIGUOUS_PREDICATE

# Tim Samaras
:Entity004	type	PER
:Entity004	mention	"Samaras"	NYT_ENG_20130603.0033:841-847	1.0
:Entity004	mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0
:Entity004	canonical_mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0

# Paul
:Entity005	type	PER
:Entity005	mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0
:Entity005	canonical_mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0

#                                                         v 889 comes after 881, so this pair of offsets is illegal
:Entity004	per:parents	:Entity005	NYT_ENG_20130603.0033:889-881	0.47161733042400245
