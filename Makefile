#------------------------------------------------------------------------
# Makefile for maintenance of the Technocracy web pages
#
# 
#------------------------------------------------------------------------
PROJ=tw
# where are the web pages??
WEBHOME=$(shell pwd)

PATH := $(WEBHOME)/bin:/u/trent/bin:$(PATH)
export PATH
SUM=md5sum
HOSTNAME=$(shell uname -n)

# some things that vary from site to site
ifeq ($(HOSTNAME),gnurd)
    HTTPLOG=/usr/local/www/logs/access_log
    URL=http://localhost/~trent/technocracy
    TDIR=technocracy
    PERL=perl
endif
ifeq ($(patsubst %.cs.pdx.edu,cs.pdx.edu,$(HOSTNAME)),cs.pdx.edu)
    HTTPLOG=/u/www/logs/httpd-access
    URL=http://www.cs.pdx.edu/~trent/technocracy
    TDIR=technocracy
    PERL=perl
endif
ifeq ($(patsubst %.pacifier.com,pacifier.com,$(HOSTNAME)),pacifier.com)
    HTTPLOG=/home2/www/logs/access_log.www.technocracy.org
    URL=http://www.technocracy.org/
    TDIR=
    PERL=perl5.003
endif

#------------------------------------------------------------------------
# get a list of all checked in files
CFILES=$(shell $(PERL) -ne '$$in=1 if /^\(Files\b/; $$in=0 if /^\)\b/; \
		   s/;.*//; next if /^\s*$$/; \
		   next if /\(.*\s:(directory|symlink)\s*\)/; \
		   print $$1 if /^\s+\((\S+\s+)\(.*\).*\)/;' $(PROJ).prj)

# get a list of moved files (old ones forward to new location)
FFILES=$(shell grep -l '<META HTTP-EQUIV="Refresh" CONTENT=".*URL=.*">' $(CFILES))

# list of real html files (no forwarding files)
HTMLFILES=$(filter %.html, $(filter-out $(FFILES), $(CFILES)))
# files to be indexed by glimpse (or whatever search engine)
INDEXFILES=$(filter-out master-index%.html %template.html %ghindex.html, \
		$(HTMLFILES))
# files likely to be articles (above less indexes)
ARTICLEFILES=$(filter-out %index.html, $(INDEXFILES))

all: verify index .articles cron master-index.html master-author-index.html master-date-index.html

#------------------------------------------------------------------------
# these are for testing the file lists above
#
test:
	@echo CFILES = $(CFILES)
	@echo FFILES = $(FFILES)
	@echo HTMLFILES = $(HTMLFILES)
	@echo INDEXFILES = $(INDEXFILES)
	@echo ARTICLEFILES = $(ARTICLEFILES)

counts:
	@echo -n "CFILES       ="; echo $(CFILES) | wc -w
	@echo -n "FFILES       ="; echo $(FFILES) | wc -w
	@echo -n "HTMLFILES    ="; echo $(HTMLFILES) | wc -w
	@echo -n "INDEXFILES   ="; echo $(INDEXFILES) | wc -w
	@echo -n "ARTICLEFILES ="; echo $(ARTICLEFILES) | wc -w

wc:
	@wc $(HTMLFILES)
#------------------------------------------------------------------------
# what is the previous version??
#
PREV=$(shell $(PERL) -ne 'printf "%d.%d", $$1, $$2 \
		if /^\(Project-Version $(PROJ) (\d+) (\d+)\)/;' $(PROJ).prj)
# run diff -q on each file (via prcs) to produre a list of each new
# or changed file
changedfiles=$(shell prcs diff -N -r $(PREV) $(PROJ) -- -q | \
		$(PERL) -ne 'next            if /^Only in $(PREV):\s*(\S+)/; \
			  print $$1, "\n" if /^Only in .*:\s*(\S+)/; \
			  print $$1, "\n" if /^The file .(\S+). differs/;')

.FORCE: patch.tar
patch.tar: force-checksum .checksum
	tar cvf $@ .checksum $(changedfiles)
.PHONY: newstuff
newstuff:
	indexer $(changedfiles)

.PHONY: changerpt
changerpt:
	@prcs diff -N -r $(PREV) $(PROJ) -- -q | \
		$(PERL) -pe '$$new++ if /^Only in $(PREV):\s*(\S+)/; \
			     $$old++ if /^Only in .*:\s*(\S+)/; \
			     $$chg++ if /^The file .(\S+). differs/; \
		END {printf "new %d, del %d, chg %d\n", $$old,$$new,$$chg;}'

#------------------------------------------------------------------------
# Make sure that everything is intact
#
.FORCE: force-checksum
force-checksum:
	rm -f .checksum
.checksum:
	@echo Generating checksum file
	@$(SUM) $(CFILES) > $@

.PHONY: verify
verify: .checksum
	@echo Generating current checksums
	@$(SUM) $(CFILES) > .checking
	diff .checksum .checking
	rm -f .checking
#------------------------------------------------------------------------
# conversion to the new format
conversion:
	@for i in $(HTMLFILES); \
	do \
		echo -n "$$i: "; \
		grep -q 'meta.*copyright' $$i && echo -n "copyright "; \
		grep -q 'Navigation bar' $$i && echo -n "navbar "; \
		grep -q 'mailto:webmaster' $$i && echo -n "tail"; \
		echo ""; \
	done | awk '/: copyright navbar tail/ {d++} {print} \
		    END { printf "%d done, %d total, %d%%\n", d, NR, d/NR*100}'

#------------------------------------------------------------------------
# show files that are here but not checked in
#
.PHONY: lspriv
lspriv:
	@echo $(filter-out $(CFILES) $(PROJ).prj .$(PROJ).prcs_aux, \
	        $(shell find . -type f -print | sed -e 's/^\.\///'))

# clean out anything that can be regenerated
.PHONY: clean
clean:
	-find . -type f \( -name '*~' -o -name core \) -print | xargs rm
	rm -f .glimpse_filenames .glimpse_filenames_index .glimpse_filetimes
	rm -f .glimpse_filetimes.index .glimpse_index .glimpse_messages
	rm -f .glimpse_partitions .glimpse_statistics .glimpse_turbo
	rm -f patch.tar .checksum archive.cfg
	rm -f master-index.html master-author-index.html master-date-index.html
#------------------------------------------------------------------------
# look at the http logs
#
# what was last month??
MON=$(shell $(PERL) -e 'require "ctime.pl"; package ctime; print $$MoY[((localtime(time))[4]-1)%12]')

# number of accesses
.PHONY: acc
acc:
	@echo Number of accesses in $(MON)
	@awk '/$(MON).*$(TDIR).* 200 / {sum += $$10; count++} \
		  END {printf "hits %d, bytes %d\n", count, sum}' $(HTTPLOG)

hist:
	@echo Generating histogram of files accessed
	@$(PERL) -ne 'next unless m,GET .*/$(TDIR).* (304|200) ,;\
		  $$_=(split)[6]; \
		  s,\"$$,,;s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;\
		  s,/$$,/index.html,; \
		  $$hist{$$_}++; \
		  END { foreach $$i (keys %hist) \
		 	{ printf "%8d %s\n", $$hist{$$i}, $$i;}}' $(HTTPLOG) |\
	sort -nr

# check to see what forwarding files are still being accessed
frexp=$(shell $(PERL) -e 'print "(", join("|", @ARGV), ")"' $(FFILES))
forw:
	egrep '/technocracy/$(frexp)' $(HTTPLOG)

#------------------------------------------------------------------------
#physical-font
lint:
	weblint -d heading-order,empty-container,title-length \
		-e bad-link,img-size,mailto-link \
		-x Netscape .

#------------------------------------------------------------------------
# make the glimpse indexes
#
.PHONY: index
index: archive.cfg
	@echo building glimpse index
	@for i in $(INDEXFILES); do echo $$i; done | \
		glimpseindex -F -H $(WEBHOME) -b -X -t
	chmod a+r $(WEBHOME)/.glimpse_*

# this is needed to make glimpseHTTP work
archive.cfg:
	echo "Technocracy Web Page Search	$(URL)	1" > $@
.FORCE: .articles
.articles:
	@echo $(ARTICLEFILES) | fmt -1 > $@

master-index.html: $(PROJ).prj
	indexer -ati "Master Article Index" \
		-s title $(ARTICLEFILES) >master-index.html
master-author-index.html: $(PROJ).prj
	indexer -ati "Master Article Index (sorted by author)" \
		-s author $(ARTICLEFILES) >master-author-index.html
master-date-index.html: $(PROJ).prj
	indexer -ati "Master Article Index (sorted by date)" \
		-s date $(ARTICLEFILES) >master-date-index.html

.PHONY: feature
feature:
	getcal -lr featurelist | repltag features.html
	getcal -c featurelist  | repltag index.html

.PHONY: cron
cron:
	crontab crontab
