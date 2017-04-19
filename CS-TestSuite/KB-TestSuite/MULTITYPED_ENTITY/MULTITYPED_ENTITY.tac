MULTIPLE_TYPES

# Boston
#                       v This entity has two different types
:Entity_0001	type	GPE
:Entity_0001	type	PER
:Entity_0001	canonical_mention	"Boston"	NYT_ENG_20131113.0264:402-407	1.0
:Entity_0001	mention	"Boston"	NYT_ENG_20131113.0264:402-407	1.0
:Entity_0001	gpe:conflict.attack_place.actual	:Event_0001	NYT_ENG_20131113.0264:261-431;NYT_ENG_20131113.0264:402-407;NIL	1.0
#                                                   ^
# :Event_0001 is inferred to be of type CONFLICT.ATTACK

#                   v :Event_0001 is declared as a PER
:Event_0001	type	PER

# correct assertion should be
#:Event_0001	type	CONFLICT.ATTACK

:Event_0001	mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
:Event_0001	canonical_mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
:Event_0001	conflict.attack:place.actual	:Entity_0001	NYT_ENG_20131113.0264:261-431;NYT_ENG_20131113.0264:402-407;NIL	1.0
