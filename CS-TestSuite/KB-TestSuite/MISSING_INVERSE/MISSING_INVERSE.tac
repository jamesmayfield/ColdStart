MISSING_INVERSE

# Tim Samaras
:Entity004	type	PER
:Entity004	mention	"Samaras"	NYT_ENG_20130603.0033:841-847	1.0
:Entity004	mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0
:Entity004	canonical_mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0

# String used for Paul's age
:String001	type	STRING
:String001	mention	"24"	NYT_ENG_20130603.0033:869-870	1.0
:String001	canonical_mention	"24"	NYT_ENG_20130603.0033:869-870	1.0

# Paul
:Entity005	type	PER
:Entity005	mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0
:Entity005	canonical_mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0

# Both the assertions below are same (albeit with different provenance) and their inverse is not specified.
# The inverses will be infered with a warning
:Entity004	per:parents	:Entity005	NYT_ENG_20130603.0033:881-889	0.47161733042400245
:Entity004	per:parents	:Entity005	NYT_ENG_20130603.0033:800-900	1.0
