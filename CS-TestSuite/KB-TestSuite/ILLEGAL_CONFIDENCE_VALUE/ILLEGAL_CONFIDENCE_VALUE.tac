ILLEGAL_CONFIDENCE_VALUE

# Tim Samaras
:Entity004	type	PER

#                                                               v WARNING: Decimal point missing
:Entity004	mention	"Samaras"	NYT_ENG_20130603.0033:841-847	1

#                                                                    v ERROR: Confidence values must be between 0.0 and 1.0
:Entity004	mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	1.1

#                                                                                v ERROR: Confidence values must be between 0.0 and 1.0
:Entity004	canonical_mention	"Tim Samaras"	NYT_ENG_20130603.0033:1959-1969	0.0

# Paul
:Entity005	type	PER
#                                                            v ERROR: Confidence values must be between 0.0 and 1.0
:Entity005	mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0e02

# Confidence values in scientific notation are acceptable as long as the value is between 0.0 and 1.0
# A warning will be generated after which the value would be converted to standard notation
:Entity005	canonical_mention	"Paul"	NYT_ENG_20130603.0033:886-889	1.0e+02
:Entity004	per:parents	:Entity005	NYT_ENG_20130603.0033:881-889	4.7e-01
