################################################################################
# Settings
################################################################################

COMPILER := pdflatex
INDEXER  := makeindex
BIBTEXER := biber

DOCUMENT   = dissertation
REFERENCES = body/bibgraph.bib
#FONTS      = Myriad Minion

PDFDEP := $(wildcard head/*.tex) \
          $(wildcard body/*.tex) \
          $(wildcard code/*) \
          $(wildcard figures/*.tex)


################################################################################
# Variables
################################################################################

ifdef FONTS
  TEXMFLOCAL := $(shell kpsewhich -var-value TEXMFLOCAL)
endif

ifndef VERBOSE
  PIPE     := 1>/dev/null 2>/dev/null
  INDENT   := 2>&1 | sed 's/^/    /'
  COMPILER := $(COMPILER) -interaction=nonstopmode
endif

ifdef REFERENCES
  BIBDEP := $$@.bbl
endif


################################################################################
# Functions
################################################################################

check_error = \
  if [ ! $(1) -eq 0 ]; then \
    cat $(2).log | \
      perl -0777 -ne 'print m/\n! .*?\nl\.\d.*?\n.*?(?=\n)/gs' $(INDENT); \
    exit 1; \
  fi

compile = $(COMPILER) -shell-escape $(1).tex $(PIPE) || \
            $(call check_error, $$?, $(1))


################################################################################
# Targets
################################################################################

.PHONY: all $(DOCUMENT) clean distclean
.PRECIOUS: %.pdf %.bcf %.bbl
.SECONDEXPANSION:

all: $(DOCUMENT)

status:
	@echo "Building $(DOCUMENT).pdf"

# .tex -> .pdf and .bcf
%.pdf %.bcf: %.tex $(PDFDEP) | status
	@# Initial compile
	@echo "  Compiling $*.tex"
	@$(call compile, $*)
ifdef INDEXER
	@# Create index
	@echo "  Running $(INDEXER)"
	@$(INDEXER) -s $*.mst $*.idx $(PIPE)
endif

# .bcf -> .bbl
%.bbl: %.bcf $(REFERENCES) | status
	@# Bibliography
	@echo "  Running $(BIBTEXER)"
	-@$(BIBTEXER) $* $(PIPE)
	@# Update references
	@echo "  Updating references"
	@$(call compile, $*)
	@# Reset time stamp of .bbl to newer than .bcf
	@touch $@

$(DOCUMENT): $$@.pdf $(BIBDEP)
	@# Fill in missing references
	@if test -e $*.log \
	      && ( grep -q "There were undefined references." $*.log \
	        || grep -q "Rerun to get outlines right" $*.log ); then  \
	  echo "  Filling in missing references"; \
	  $(call compile, $*); \
	fi
	@# Fix cross-references
	@while test -e $*.log \
	      && grep -q "Rerun to get cross-references right." $*.log; do \
	  echo "  Fixing cross-references"; \
	  $(call compile, $*); \
	done

ifdef FONTS
fontinstall:
	@for f in $(FONTS); do \
	  echo "Installing font $$f to $(TEXMFLOCAL)"; \
	  sudo cp -r fonts/$$f/* $(TEXMFLOCAL) $(PIPE); \
	  if [ ! $$? -eq 0 ]; then exit 1; fi; \
	done
	@sudo $$(which mktexlsr)
	@for f in $(FONTS); do \
	  echo "Enabling font $$f"; \
	  updmap -user --disable $$f.map $(PIPE); \
	  updmap -user --enable Map=$$f.map $(PIPE); \
	  if [ ! $$? -eq 0 ]; then exit 1; fi; \
  done
endif

# Create a single source version
single: $(DOCUMENT).tex $(PDFDEP) $(REFERENCES)
	@echo "Creating single source version"
	@# Call Latexpand to create a single source file
	@echo "  Running Latexpand"
	@latexpand --keep-comments $(DOCUMENT).tex -o $@.tex $(PIPE)
	@# Search library includes and replace by a single unified include
	@echo "  Patching TikZ and PGFPlots library includes"
	@for LIB in tikz pgfplots; do \
	  grep use$${LIB}library $@.tex | \
	    sed 's/\\use'$${LIB}'library{\(.*\)}/\1/g' | tr -d ' ' | \
	    sed 's/,/\n/g' | sort | uniq | xargs | tr ' ' ',' > libs.$${LIB}; \
	  sed -i '/use'$${LIB}'library.*/d' $@.tex; \
	  if [ -s libs.$${LIB} ]; then \
	    sed -i 's/\(\\usepackage{'$${LIB}'}\)/\1\n\\use'$${LIB}'library{'$$(cat libs.$${LIB})'}/g' $@.tex; \
	  fi; \
	  rm -f libs.$${LIB}; \
	done
	@# Create output folder and stage all files into it
	@echo "  Staging files to '$@'"
	@mkdir -p $@
	@rsync -a * $@/ --exclude $@ $(PIPE)
	@mv $@.tex $@/$(DOCUMENT).tex
	@# Delete dependent TeX files, resulting empty folders, and intermediate files
	@echo "  Cleanup"
	@cd $@; rm $@.tex $$(echo "$(PDFDEP)" | \
	  sed 's/\ /\n/g' | grep "tex$$" | grep -v "$(DOCUMENT).tex" | xargs)
	@find $@/ -type d -empty ! -path "$@/figures" -delete

clean:
	rm -rf *.aux *.auxlock *.ind *.idx *.toc *.out *.log *.lot *.ilg *.dvi *.bbl \
	  *.blg *.sub *.suc *.syc *.sym *.syg *.syi *.synctex *.slg *.lol *.lof \
	  *.ist *.gls *.glo *.gli *.glg *.alg *.acr *.acn *.ps *.defn *.nlo *.satz \
	  *.nav *.snm *.xml *.synctex.gz *.synctex *.vrb *.bcf *.makefile *.figlist \
	  $$(ls figures/$(DOCUMENT)-figure[0-9]*.* 2>/dev/null | grep -v pdf) single

distclean: clean
	rm -f $(DOCUMENT).pdf figures/$(DOCUMENT)-figure[0-9]*.*

