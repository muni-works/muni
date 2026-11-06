.PHONY: all clean watch png

# Fonts: IBM Plex via fonts/ -> ../vision/fonts (OFL 1.1). System fonts ignored so builds are reproducible.
HERE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TYPST ?= typst
TYPST_C = $(TYPST) compile --root $(HERE) --font-path $(HERE)fonts --ignore-system-fonts

all: tang-ir.pdf

tang-ir.pdf: tang-ir.typ refs.bib
	cd $(HERE) && $(TYPST_C) tang-ir.typ

png: tang-ir.typ
	cd $(HERE) && mkdir -p out && rm -f out/p*.png && $(TYPST_C) --ppi 110 tang-ir.typ 'out/p{0p}.png'

watch:
	cd $(HERE) && $(TYPST) watch --root $(HERE) --font-path $(HERE)fonts --ignore-system-fonts tang-ir.typ

clean:
	rm -f tang-ir.pdf
