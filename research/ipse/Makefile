TYPST = typst compile --root ../.. --font-path ../../paper/fonts/
ipse.pdf: ipse.typ refs.bib $(wildcard sections/*.typ)
	$(TYPST) ipse.typ ipse.pdf
watch:
	typst watch --root ../.. --font-path ../../paper/fonts/ ipse.typ ipse.pdf
clean:
	rm -f ipse.pdf
