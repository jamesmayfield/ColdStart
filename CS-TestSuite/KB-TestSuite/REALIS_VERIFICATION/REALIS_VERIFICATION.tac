REALIS_VERIFICATION

# Realis is not expected
#                    v
:Entity_0001	type.actual	GPE
:Entity_0001	canonical_mention	"Boston"	NYT_ENG_20131113.0264:402-407	1.0
# Realis is not expected
#                       v
:Entity_0001	mention.actual	"Boston"	NYT_ENG_20131113.0264:402-407	1.0
# Realis is missing
#                                        v
:Entity_0001	gpe:conflict.attack_place	:Event_0001	NYT_ENG_20131113.0264:261-431;NYT_ENG_20131113.0264:402-407;NIL	1.0
:String_0001	type	STRING
# Realis is not expected
#                      v
:String_0001	mention.actual	"April 15"	NYT_ENG_20131113.0264:624-631	1.0
:String_0001	normalized_mention	"2014-04-15"	NYT_ENG_20131113.0264:624-631	1.0
:Event_0001	type	CONFLICT.ATTACK
# Unexpected value of realis
#                   v
:Event_0001	mention.mango	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
