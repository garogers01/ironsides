TEMPLATES = $(wildcard *.cftemplate)
PURCHASE_AGREEMENTS = $(addsuffix .cform,$(addprefix purchase-agreement-,single-cash single-ip single-mixed double-cash double-ip double-mixed))
FORMS = $(filter-out purchase-agreement.cform,$(TEMPLATES:.cftemplate=.cform)) $(PURCHASE_AGREEMENTS)
COMMONFORM = node_modules/.bin/commonform
CFTEMPLATE = node_modules/.bin/cftemplate
DOCX = $(addprefix build/,$(FORMS:.cform=.docx))
PDF = $(addprefix build/,$(FORMS:.cform=.pdf))
EDITION = $(strip $(shell git tag -l --points-at HEAD))

all: $(DOCX)

pdf: $(PDF)

$(COMMONFORM) $(CFTEMPLATE): package.json
	npm i

%.pdf: %.docx
	doc2pdf $<

build:
	mkdir -p build

build/%.docx: %.cform %.options_with_edition %.sigs.json $(COMMONFORM) build
	$(COMMONFORM) render --format docx --signatures $*.sigs.json $(shell cat $*.options_with_edition) < $< > $@

build/%.docx: %.cform %.options_with_edition $(COMMONFORM) build
	$(COMMONFORM) render --format docx $(shell cat $*.options_with_edition) < $< > $@

%.cform: $(CFTEMPLATE) %.cftemplate %.options.json
	$^ > $@

purchase-agreement-%.sigs.json: purchase-agreement.sigs.json
	cp $< $@

purchase-agreement-%.options.json: generate-options.js
	node $< $@ > $@

purchase-agreement-%.cftemplate: purchase-agreement.cftemplate
	cp $< $@

purchase-agreement-%.options: purchase-agreement.options
	cp $< $@

%.options_with_edition: %.options
ifeq ($(EDITION),)
	cat $< | sed 's/EDITION/Ironsides Development Draft/' > $@
else
	cat $< | sed 's/EDITION/Ironsides $(EDITION)/' > $@
endif

%.options.json:
	echo "{}" > $@

.PHONY: lint critique clean docker

lint: $(FORMS) $(COMMONFORM)
	for form in $(FORMS); do \
		echo ; \
		echo $$form; \
		$(COMMONFORM) lint < $$form; \
	done; \

critique: $(FORMS) $(COMMONFORM)
	for form in $(FORMS); do \
		echo ; \
		echo $$form ; \
		$(COMMONFORM) critique < $$form; \
	done

clean:
	rm -rf $(DOCX) $(PDF) $(FORMS)

docker:
	docker build -t ironsides .
	docker run -v $(shell pwd)/build:/app/build ironsides
	sudo chown -R `whoami`:`whoami` build
