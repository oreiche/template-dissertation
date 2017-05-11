pdflatex.exe -shell-escape dissertation.tex
makeindex.exe -s dissertation.mst dissertation.idx
biber.exe dissertation
pdflatex.exe -shell-escape dissertation.tex
pdflatex.exe -shell-escape dissertation.tex

pause
