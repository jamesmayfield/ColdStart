MULTIPLE_FILLS

# Tim Samaras
:Entity004	type	PER
:Entity004	mention	"Samaras"	NYT_ENG_20130603.0033:841-847	1.0
:Entity004	mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0
:Entity004	canonical_mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.0

# String used for Paul's age
:String001	type	STRING
:String001	mention	"24"	NYT_ENG_20130603.0033:869-870	1.0
:String001	canonical_mention	"24"	NYT_ENG_20130603.0033:869-870	1.0

# String used for incorrect age of Paul
:String002	type	STRING
:String002	mention	"55"	NYT_ENG_20130603.0033:850-851	1.0
:String002	canonical_mention	"55"	NYT_ENG_20130603.0033:850-851	1.0

# Paul
:Entity005	type	PER
:Entity005	mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0
:Entity005	canonical_mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0
#                       v Entity005 has two different ages specified
#                         Both will be passed on to the validated KB; the best node will be picked by the scorer
#                         Therefore the warning that was generated earlier at this point is no more generated
:Entity005	per:age	:String001	NYT_ENG_20130603.0033:869-870;NYT_ENG_20130603.0033:886-889	1.0	
:Entity005	per:age	:String002	NYT_ENG_20130603.0033:850-851;NYT_ENG_20130603.0033:840-860	1.0
