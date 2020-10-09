STRIPTARGET = jsarticle.cls jslogo.sty okumacro.sty jsverb.sty okuverb.sty
DOCTARGET = jsclasses jslogo okumacro jsverb okuverb
PDFTARGET = $(addsuffix .pdf,$(DOCTARGET))
DVITARGET = $(addsuffix .dvi,$(DOCTARGET))
KANJI = -kanji=utf8
FONTMAP = -f haranoaji.map -f ptex-haranoaji.map
TEXMF = $(shell kpsewhich -var-value=TEXMFHOME)

default: $(STRIPTARGET) $(DVITARGET)
strip: $(STRIPTARGET)
all: $(STRIPTARGET) $(PDFTARGET)

JSCLASSES = jsarticle.cls jsbook.cls jsreport.cls jspf.cls kiyou.cls \
	minijs.sty

# for generating files, we use pdflatex incidentally.
# otherwise, ptexenc might convert U+2212 -> U+FF0D in okumacro.sty
jsarticle.cls: jsclasses.dtx
	pdflatex jsclasses.ins

jslogo.sty: jslogo.dtx
	pdflatex jslogo.ins

okumacro.sty: okumacro.dtx
	pdflatex okumacro.ins

jsverb.sty: jsverb.dtx
	pdflatex jsverb.ins

okuverb.sty: okuverb.dtx
	pdflatex okuverb.ins

.SUFFIXES: .dtx .dvi .pdf
.dtx.dvi:
	platex $(KANJI) $<
	platex $(KANJI) $<
.dvi.pdf:
	dvipdfmx $(FONTMAP) $<

.PHONY: install clean cleanstrip cleanall cleandoc jisfile
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
jisfile:
	mkdir -p jis0
	cp *.{dtx,ins,cls,sty} jis0/
	# GNU iconv can be used to convert UTF-8 -> ISO-2022-JP
	for x in jis0/*; do \
		if [ -f "$$x" ]; then \
			iconv -f UTF-8 -t ISO-2022-JP "$$x" >"$$x.conv"; \
			mv "$$x.conv" "$$x"; \
		fi \
	done
	# jsclasses and okumacro contain non-ASCII chars also in stripped files
	for x in $(addprefix jis0/,$(JSCLASSES) jsclasses.dtx okumacro.dtx okumacro.sty); do \
		perl -pi.bak -0777 -e 's/(%\n)?\\ifx\\epTeXinputencoding\\undefined.*?\n\\fi\n(%\n)?//s' $$x; \
		rm -f $$x.bak; \
	done
	# others have no non-ASCII chars in stripped files
	for x in $(addprefix jis0/,$(wildcard *.dtx)); do \
		perl -pi.bak -0777 -e 's/(%\n)?% \\ifx\\epTeXinputencoding\\undefined.*?\n% \\fi\n(%\n)?//s' $$x; \
		perl -pi.bak -0777 -e 's/(%\n)?%<\*driver>\n\\ifx\\epTeXinputencoding\\undefined.*?\n\\fi\n%<\/driver>\n//s' $$x; \
		rm -f $$x.bak; \
	done
	rm -f jis/*.{dtx,ins,cls,sty}
	mv jis0/* jis/
	rmdir jis0
