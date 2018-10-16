#!/bin/sh
cd sty
for f in ../../../templates/latex/review-jsbook/*.cls \
         ../../../templates/latex/review-jsbook/review-*.sty; do
  ln -sf $f
done
ln -sf ../../../vendor/gentombow/gentombow.sty gentombow09j.sty
