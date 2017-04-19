ILLEGAL_PROVENANCE

# Checking if a provenance needs to be a mention and if the mention is present
# Checking if the provenance list contains the right number of spans

# The provenance list can take various forms depending on a number of conditions:
# (A) If its a type assertion:
#      - No provenance should be provided
# (B) If its a .*mention assertion:
#      - Only one triple is expected and is read to be the value of PREDICATE_JUSTIFICATION
#      - The string should be consistent with text in the document at the provenance span
# (C) If its a non-event non-type assertion with an string object
#      - FILLER_STRING;PREDICATE_JUSTIFICATION is expected
#      - FILLER_STRING should be mention of the string object
# (D) If its a non-event non-type assertion with a non-string object
#      - PREDICATE_JUSTIFICATION is expected
# (E) IF its a event non-type assertion with a string object
#      - FILLER_STRING;PREDICATE_JUSTIFICATION;BASE_FILLER;ADDITIONAL_JUSTIFICATION is expected
#      - FILLER_STRING should be mention of the string object
# (F) If its a event non-type assertion with a non-string object
#      - PREDICATE_JUSTIFICATION;BASE_FILLER;ADDITIONAL_JUSTIFICATION is expected
# (G) If its a sentiment assertion (for e.g., likes, dislikes, is_liked_by, or is_disliked_by)
#      - PREDICATE_JUSTIFICATION is expected,
#      - PREDICATE_JUSTIFICATION must have only one triple, and
#      - The provenance must be a mention of the entity which is the target of the sentiment
#          - for likes and dislikes assertions object is the target of the sentiment
#          - for is_liked_by and is_disliked_by assertions the subject is the target of the sentiment
#
#
# Also note that whereever:
#
# - FILLER_STRING is allowed it must have exactly one triple
# - PREDICATE_JUSTIFICATION is allowed it can have between 1-3 (both inclusive) triples unless its
#   for a .*mention in which case it should only have exactly one triple
# - BASE_FILLER is allowed it can have a only 1 triple (or a NIL)
# - ADDITIONAL_JUSTIFICATION is allowed it can have unlimited number of triples (or a NIL)

# ERROR: Wrong number of entries
:Entity_0001	type	GPE	NYT_ENG_20131113.0264:402-407	1.0

# Following is a mention assertion therefore 
# - only PREDICATE_JUSTIFICATION is expected
# - exactly one triple is expected
#  
# ERROR: Unexpected number of provenance triples: provided=(2) expected=(1)
# Mention assertion is expected to have only one provenance triple
#                                               v
:Entity_0001	canonical_mention	"Boston"	NYT_ENG_20131113.0264:402-409,NYT_ENG_20131113.0264:402-407	1.0
:Entity_0001	mention	"Boston"	NYT_ENG_20131113.0264:402-409,NYT_ENG_20131113.0264:402-407	1.0

# The following is a non-event non-type assertion with a non-string object therefore
# only PREDICATE_JUSTIFICATION is expected which can have [1-3] triples
# 
# ERROR: Unexpected number of provenances in the list: provided=(4) expected=(1)
#                                                       v
:Entity_0001	gpe:residents_of_city	:Entity_0007	NYT_ENG_20131113.0264:402-450;NYT_ENG_20131113.0264:261-431;NYT_ENG_20131113.0264:402-407;NIL	0.5493061443340549
#
# In the following assertion only PREDICATE_JUSTIFICATION is provided but it have four triples
# ERROR: Unexpected number of provenance triples: provided=(4) expected=(3)
#                                                       v
:Entity_0001	gpe:residents_of_city	:Entity_0007	NYT_ENG_20131113.0264:402-450,NYT_ENG_20131113.0264:402-453,NYT_ENG_20131113.0264:402-454,NYT_ENG_20131113.0264:402-455	1.0


:Entity_0001	gpe:conflict.attack_place.actual	:Event_0001	NYT_ENG_20131113.0264:261-431;NYT_ENG_20131113.0264:402-407;NIL	1.0

# The following is a sentiment assertion and the target of the sentiment is the subject, i.e. :Entity_0001
# therefore only PREDICATE_JUSTIFICATION is expected, it must have only one triple which should be a 
# mention of the target of the sentiment
# 
# In the following case the provenance is a mention of the object which is not the target of the sentiment
# ERROR: PREDICATE_JUSTIFICATION: 'NYT_ENG_20131113.0264:684-700' is not a mention of entity :Entity_0001
#                                                   v
:Entity_0001	gpe:is_disliked_by	:Entity_0010	NYT_ENG_20131113.0264:684-700	1.0
#
# In the following case there are multiple triples provided but only one is expected
# ERROR: Unexpected number of provenance triples: provided=(2) expected=(1) 
# ERROR: PREDICATE_JUSTIFICATION: 'NYT_ENG_20131113.0264:402-409,NYT_ENG_20131113.0264:402-407' is not a mention of entity :Entity_0001
:Entity_0001	gpe:is_disliked_by	:Entity_0010	NYT_ENG_20131113.0264:402-409,NYT_ENG_20131113.0264:402-407	1.0

:Entity_0007	type	PER
:Entity_0007	canonical_mention	"Dzhokhar Tsarnaev"	NYT_ENG_20131113.0264:434-450	1.0
:Entity_0007	mention	"Dzhokhar Tsarnaev"	NYT_ENG_20131113.0264:434-450	1.0
:Entity_0007	pronominal_mention	"he"	NYT_ENG_20131113.0264:546-547	1.0

:Entity_0007	per:cities_of_residence	:Entity_0001	NYT_ENG_20131113.0264:402-450	0.5493061443340549
:Entity_0007	per:siblings	:Entity_0010	NYT_ENG_20131113.0264:561-577	0.73588133800021

:Entity_0010	type	PER
:Entity_0010	canonical_mention	"Tamerlan Tsarnaev"	NYT_ENG_20131113.0264:684-700	1.0
:Entity_0010	mention	"Tamerlan Tsarnaev"	NYT_ENG_20131113.0264:684-700	1.0
:Entity_0010	nominal_mention	"brother"	NYT_ENG_20131113.0264:571-577	1.0
:Entity_0010	per:siblings	:Entity_0007	NYT_ENG_20131113.0264:561-577	0.73588133800021


# The following is meant to demonstrate the error reported only and does not correspond to document
# Since the following is a non-event non-type assertion with a string object
# FILLER_STRING;PREDICATE_JUSTIFICATION is expected and FILLER_STRING should be a mention of the object
#
# ERROR: Unexpected number of provenances in the list: provided=(1) expected=(2)
# ERROR: FILLER_STRING: 'NYT_ENG_20131113.0264:620-650' is not a mention of entity :String_0001 
#                                                   v
:Entity_0007	per:date_of_birth	:String_0001	NYT_ENG_20131113.0264:620-650	1.0

# The document does not support or deny the following, however, we are including this
# only to demonstrate how a sentiment would be represented in the KB
#
# The inverse would be inferred by the validator with a warning
:Entity_0001	gpe:is_disliked_by	:Entity_0010	NYT_ENG_20131113.0264:402-407	1.0

# Example showing normalized date string
:String_0001	type	STRING
:String_0001	mention	"April 15"	NYT_ENG_20131113.0264:624-631	1.0
# the provenance of normalized_mention has to be a mention of the subject
:String_0001	normalized_mention	"2014-04-15"	NYT_ENG_20131113.0264:624-631	1.0

# Example showing string for victims
:String_0002	type	STRING
:String_0002	mention	"three people"	NYT_ENG_20131113.0264:642-653	1.0

:Event_0001	type	CONFLICT.ATTACK
:Event_0001	mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0
:Event_0001	canonical_mention.actual	"bombing"	NYT_ENG_20131113.0264:418-424	1.0

# The following is are event non-type assertions with a non-string object therefore
# PREDICATE_JUSTIFICATION;BASE_FILLER;ADDITIONAL_JUSTIFICATION is expected
#
# ERROR: Unexpected number of provenances in the list: provided=(4) expected=(3)
#                                                           v
:Event_0001	conflict.attack:attacker.actual	:Entity_0007	NYT_ENG_20131113.0264:434-450;NYT_ENG_20131113.0264:492-681;NYT_ENG_20131113.0264:546-547;NIL	1.0
#
# ERROR: Unexpected number of provenances in the list: provided=(1) expected=(3)
#                                                           v
:Event_0001	conflict.attack:place.actual	:Entity_0001	NYT_ENG_20131113.0264:261-431	1.0

# The following is are event non-type assertions with a string object therefore
# FILLER_STRING;PREDICATE_JUSTIFICATION;BASE_FILLER;ADDITIONAL_JUSTIFICATION is expected
# and FILLER_STRING needs to be a mention of the object
# 
# ERROR: Unexpected number of provenances in the list: provided=(3) expected=(4) 
#                                                       v
:Event_0001	conflict.attack:time.actual	:String_0001	NYT_ENG_20131113.0264:492-681;NYT_ENG_20131113.0264:624-631;NIL	1.0
#
# ERROR: FILLER_STRING: 'NYT_ENG_20131113.0264:642-654' is not a mention of entity :String_0002 
#                                                           v
:Event_0001	conflict.attack:target.actual	:String_0002	NYT_ENG_20131113.0264:642-654;NYT_ENG_20131113.0264:492-681;NYT_ENG_20131113.0264:642-653;NIL	1.0
