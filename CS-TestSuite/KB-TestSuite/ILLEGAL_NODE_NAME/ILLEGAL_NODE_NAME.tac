ILLEGAL_ENTITY_NAME

# Illegal NODEID. Expected :Entity.*
#  v   
:Ent!ty_0001	type	GPE
:Ent!ty_0001	canonical_mention	"Boston"	NYT_ENG_20131113.0264:402-407	1.0
:Ent!ty_0001	mention	"Boston"	NYT_ENG_20131113.0264:402-407	1.0

# Illegal NODEID. Expected :String.*
#  v   
:Strng_0001	type	STRING
:Strng_0001	mention	"April 15"	NYT_ENG_20131113.0264:624-631	1.0

# Illegal NODEID. Expected :Event.*
#  v   
:Evnt_0001	type	CONFLICT.ATTACK
:Evnt_0001	mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
:Evnt_0001	canonical_mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0

# Illegal NODEID. Expected :Event.*
#  v   
:Event	type	CONFLICT.ATTACK
:Event	mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
:Event	canonical_mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0

# Illegal NODEID due to the presence of a `-` (dash)
#     v
:Event-0001	type	CONFLICT.ATTACK
:Event-0001	mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
:Event-0001	canonical_mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0

# Valid NODEID
:Event_a	type	CONFLICT.ATTACK
:Event_a	mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
:Event_a	canonical_mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0

# Valid NODEID
:Event_0001	type	CONFLICT.ATTACK
:Event_0001	mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
:Event_0001	canonical_mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
