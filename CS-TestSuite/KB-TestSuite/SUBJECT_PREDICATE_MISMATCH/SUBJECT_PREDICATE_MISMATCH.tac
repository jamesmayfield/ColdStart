SUBJECT_PREDICATE_MISMATCH

# Tim Samaras
:Entity004	type	PER
:Entity004	mention	"Samaras"	NYT_ENG_20130603.0033:841-847	1.0
:Entity004	mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0
:Entity004	canonical_mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0
#           v Entity004 is a PER, but this predicate requires an ORG as its subject
:Entity004	org:parents	:Entity005	NYT_ENG_20130603.0033:881-889	0.47161733042400245

# Paul
:Entity005	type	PER
:Entity005	mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0
:Entity005	canonical_mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0
:Entity005	per:children	:Entity004	NYT_ENG_20130603.0033:881-889	0.47161733042400245
