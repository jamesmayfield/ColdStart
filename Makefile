all: validate-all
#########################################################################################
# set defaults
OUTPUT=tac:edl:sen:eal:nug
KB=NO_ERRORS
SF=NO_ERRORS
JUSTIFICATIONS=1:3
QB=CSSF17
DIR=CS-TestSuite
DOCS=-docs $(DIR)/AUX-Files/doclength.txt
#########################################################################################

score-sf:
	perl CS-Score-MASTER.pl \
	  -expand $(QB) \
	  -error_file $(DIR)/SF-TestSuite/$(SF)/$(SF)_score.errlog \
	  -output_file $(DIR)/SF-TestSuite/$(SF)/$(SF)_score \
	  $(DIR)/SF-TestSuite/$(SF)/ldc-query.xml \
	  $(DIR)/SF-TestSuite/$(SF)/qrel.txt \
	  $(DIR)/SF-TestSuite/$(SF)/$(SF).valid.ldc.tab.txt

expand-sfkb:
	perl CS-ExpandKB-MASTER.pl \
	  -output_file $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/SFSystem1KB.tac \
	  -kbname $(SF) \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/SFSystem1KB.cpt

validate-all: validate-all-kbs validate-all-sfs

diff-all: diff-all-kbs diff-all-sfs

validate-kb-basic:
	perl CS-ValidateKB-MASTER.pl \
	  $(DOCS) \
	  -output $(OUTPUT) \
	  -output_file $(DIR)/KB-TestSuite/$(KB)/$(KB).valid \
	  -error_file $(DIR)/KB-TestSuite/$(KB)/$(KB).errlog \
	  $(DIR)/KB-TestSuite/$(KB)/$(KB).tac

validate-kb-full:
	if [ -d $(DIR)/KB-TestSuite/$(KB)/event_arguments ]; \
	  then rm -rf $(DIR)/KB-TestSuite/$(KB)/event_arguments; \
	fi
	if [ -d $(DIR)/KB-TestSuite/$(KB)/sentiments ]; \
	  then rm -rf $(DIR)/KB-TestSuite/$(KB)/sentiments; \
	fi
	if [ -f $(DIR)/KB-TestSuite/$(KB)/$(KB).tac.valid ]; \
	  then rm $(DIR)/KB-TestSuite/$(KB)/$(KB).tac.valid; \
	fi
	if [ -f $(DIR)/KB-TestSuite/$(KB)/$(KB).edl.valid ]; \
	  then rm $(DIR)/KB-TestSuite/$(KB)/$(KB).edl.valid; \
	fi
	if [ -f $(DIR)/KB-TestSuite/$(KB)/$(KB).nug.valid ]; \
	  then rm $(DIR)/KB-TestSuite/$(KB)/$(KB).nug.valid; \
	fi
	perl CS-ValidateKB-MASTER.pl \
	  $(DOCS) \
	  -output $(OUTPUT) \
	  -error_file $(DIR)/KB-TestSuite/$(KB)/$(KB).errlog \
	  $(DIR)/KB-TestSuite/$(KB)/$(KB).tac

validate-kb: validate-kb-full

setup-sf:
	if [ -f $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/SFSystem1KB.tac.valid ]; \
	  then rm $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/SFSystem1KB.tac.valid; \
	fi
	perl CS-ValidateKB-MASTER.pl \
	  $(DOCS) \
	  -output tac \
	  -error_file $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/SFSystem1KB.errlog \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/SFSystem1KB.tac
	if [ -f $(DIR)/SF-TestSuite/$(SF)/sf-query.xml ]; \
	  then rm $(DIR)/SF-TestSuite/$(SF)/sf-query.xml; \
	fi
	perl CS-ValidateQueries-MASTER.pl \
	  -expand \
	  -query_base $(QB) \
	  $(DIR)/SF-TestSuite/$(SF)/ldc-query.xml \
	  $(DIR)/SF-TestSuite/$(SF)/sf-query.xml
	perl CS-GenerateQueries-MASTER.pl \
	  $(DOCS) \
	  -valid \
	  $(DIR)/SF-TestSuite/$(SF)/sf-query.xml \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/sf-query-r1.xml
	perl CS-ResolveQueries-MASTER.pl \
	  $(DIR)/SF-TestSuite/$(SF)/sf-query.xml \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/SFSystem1KB.tac.valid \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq
	if [ -f $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq.valid.errlog ]; \
          then rm $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq.valid.errlog; \
        fi
	perl CS-ValidateSF-MASTER.pl \
          -error_file $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq.valid.errlog \
          $(DOCS) \
          -justifications $(JUSTIFICATIONS) \
          -output_file $(DIR)/SF-TestSuite/$(SF)/$(SF).valid.ldc.tab.txt \
          $(DIR)/SF-TestSuite/$(SF)/sf-query.xml \
          $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq
	awk 'length($$1)<25{print}' $(DIR)/SF-TestSuite/$(SF)/$(SF).valid.ldc.tab.txt > $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq-r1
	awk 'length($$1)>25{print}' $(DIR)/SF-TestSuite/$(SF)/$(SF).valid.ldc.tab.txt > $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq-r2
	perl CS-GenerateQueries-MASTER.pl \
	  $(DOCS) \
	  -valid \
	  $(DIR)/SF-TestSuite/$(SF)/sf-query.xml \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/sf-query-r2.xml \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq-r1
	if [ -f $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).sf ]; \
	  then rm $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).sf; \
	fi
	if [ -f $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq-packaged_output.errlog ]; \
	  then rm $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq-packaged_output.errlog; \
	fi
	perl CS-PackageOutput-MASTER.pl \
	  -error_file $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq-packaged_output.errlog \
	  $(DIR)/SF-TestSuite/$(SF)/sf-query.xml \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq-r1 \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).rq-r2 \
	  $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).sf
	cp $(DIR)/SF-TestSuite/$(SF)/GeneratorKB/$(SF).sf $(DIR)/SF-TestSuite/$(SF)/$(SF)

validate-sf:
	if [ -f $(DIR)/SF-TestSuite/$(SF)/$(SF).errlog ]; \
	  then rm $(DIR)/SF-TestSuite/$(SF)/$(SF).errlog; \
	fi
	perl CS-ValidateSF-MASTER.pl \
	  -error_file $(DIR)/SF-TestSuite/$(SF)/$(SF).errlog \
	  $(DOCS) \
	  -justifications $(JUSTIFICATIONS) \
	  -output_file $(DIR)/SF-TestSuite/$(SF)/$(SF).valid.ldc.tab.txt \
	  $(DIR)/SF-TestSuite/$(SF)/sf-query.xml \
	  $(DIR)/SF-TestSuite/$(SF)/$(SF)

validate-all-sfs:
	ls $(DIR)/SF-TestSuite | awk '{print "make validate-sf SF=" $$1}' | sh

validate-all-kbs:
	ls $(DIR)/KB-TestSuite | awk '{print "make validate-kb KB=" $$1}' | sh

diff-all-kbs:
	ls $(DIR)/KB-TestSuite | awk '{print "diff -I HASH $(DIR)/KB-TestSuite/" $$1 "/"  $$1 ".errlog $(DIR)/KB-TestSuite/" $$1 "/" $$1  ".orig_err" }' | sh

diff-all-sfs:
	ls $(DIR)/SF-TestSuite | awk '{print "diff -I HASH $(DIR)/SF-TestSuite/" $$1 "/"  $$1 ".errlog $(DIR)/SF-TestSuite/" $$1 "/" $$1  ".orig_err" }' | sh
