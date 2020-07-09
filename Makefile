
EXTENSION = londiste

EXT_VERSION = 3.5
EXT_OLD_VERSIONS = 3.2 3.2.3 3.2.4 3.4 3.4.1

base_regress = londiste_provider londiste_subscriber \
	       londiste_fkeys londiste_execute londiste_seqs londiste_merge \
	       londiste_leaf londiste_create_part

Contrib_regress = init_noext $(base_regress)
Extension_regress = init_ext $(base_regress)

include mk/common-pgxs.mk

dox: cleandox
	mkdir -p docs/html
	mkdir -p docs/sql
	$(CATSQL) --ndoc structure/tables.sql > docs/sql/schema.sql
	$(CATSQL) --ndoc structure/functions.sql > docs/sql/functions.sql
	$(NDOC) $(NDOCARGS)

deb:
	make -f debian/rules genfiles
	debuild -us -uc -b

debclean:
	make -f debian/rules debclean

