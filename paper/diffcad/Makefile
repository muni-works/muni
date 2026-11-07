.PHONY: all clean watch png

# Fonts: IBM Plex via fonts/ -> ../vision/fonts (OFL 1.1). System fonts ignored so builds are reproducible.
HERE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TYPST ?= typst
TYPST_C = $(TYPST) compile --root $(HERE) --font-path $(HERE)fonts --ignore-system-fonts
TYPST_W = $(TYPST) watch --root $(HERE) --font-path $(HERE)fonts --ignore-system-fonts

all: diffcad.pdf

diffcad.pdf: diffcad.typ refs.bib
	cd $(HERE) && $(TYPST_C) diffcad.typ

png: diffcad.typ
	cd $(HERE) && mkdir -p out && rm -f out/p*.png && $(TYPST_C) --ppi 110 diffcad.typ 'out/p{0p}.png'

watch:
	cd $(HERE) && $(TYPST_W) diffcad.typ

clean:
	rm -f diffcad.pdf
