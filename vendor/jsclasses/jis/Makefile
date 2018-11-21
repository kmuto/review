STRIPTARGET = jsarticle.cls jslogo.sty okumacro.sty jsverb.sty okuverb.sty
DOCTARGET = jsclasses jslogo okumacro jsverb okuverb
PDFTARGET = $(addsuffix .pdf,$(DOCTARGET))
DVITARGET = $(addsuffix .dvi,$(DOCTARGET))
KANJI = -kanji=jis
FONTMAP = -f ipaex.map -f ptex-ipaex.map
TEXMF = $(shell kpsewhich -var-value=TEXMFHOME)

default: $(STRIPTARGET) $(DVITARGET)
strip: $(STRIPTARGET)
all: $(STRIPTARGET) $(PDFTARGET)

JSCLASSES = jsarticle.cls jsbook.cls jsreport.cls jspf.cls kiyou.cls

jsarticle.cls: jsclasses.dtx
	platex $(KANJI) jsclasses.ins

jslogo.sty: jslogo.dtx
	platex $(KANJI) jslogo.ins

okumacro.sty: okumacro.dtx
	platex $(KANJI) okumacro.ins

jsverb.sty: jsverb.dtx
	platex $(KANJI) jsverb.ins

okuverb.sty: okuverb.dtx
	platex $(KANJI) okuverb.ins

.SUFFIXES: .dtx .dvi .pdf
.dtx.dvi:
	platex $(KANJI) $<
	platex $(KANJI) $<
.dvi.pdf:
	dvipdfmx $(FONTMAP) $<

.PHONY: install clean cleanstrip cleanall cleandoc
install:
	mkdir -p ${TEXMF}/doc/platex/jsclasses
	cp ./LICENSE ${TEXMF}/doc/platex/jsclasses/
	cp ./README.md ${TEXMF}/doc/platex/jsclasses/
	cp ./*.pdf ${TEXMF}/doc/platex/jsclasses/
	mkdir -p ${TEXMF}/source/platex/jsclasses
	cp ./Makefile ${TEXMF}/source/platex/jsclasses/
	cp ./*.dtx ${TEXMF}/source/platex/jsclasses/
	cp ./*.ins ${TEXMF}/source/platex/jsclasses/
	mkdir -p ${TEXMF}/tex/platex/jsclasses
	cp ./*.cls ${TEXMF}/tex/platex/jsclasses/
	cp ./*.sty ${TEXMF}/tex/platex/jsclasses/
clean:
	rm -f $(JSCLASSES) \
	jslogo.sty okumacro.sty jsverb.sty okuverb.sty \
	$(DVITARGET)
cleanstrip:
	rm -f $(JSCLASSES) \
	jslogo.sty okumacro.sty jsverb.sty okuverb.sty
cleanall:
	rm -f $(JSCLASSES) \
	jslogo.sty okumacro.sty jsverb.sty okuverb.sty \
	$(DVITARGET) $(PDFTARGET)
cleandoc:
	rm -f $(DVITARGET) $(PDFTARGET)
