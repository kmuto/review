#!/bin/sh

PROJECT=jsclasses
TMP=/tmp
PWDF=`pwd`
LATESTRELEASEDATE=`git tag | sort -r | head -n 1`
RELEASEDATE=`git tag --points-at HEAD | sort -r | head -n 1`

if [ -z "$RELEASEDATE" ]; then
    RELEASEDATE="**not tagged**; later than $LATESTRELEASEDATE?"
fi

echo " * Create $PROJECT.tds.zip"
git archive --format=tar --prefix=$PROJECT/ HEAD | (cd $TMP && tar xf -)
rm $TMP/$PROJECT/.gitignore
rm $TMP/$PROJECT/create_archive.sh
rm -rf $TMP/$PROJECT/tests
rm -rf $TMP/$PROJECT/jis
perl -pi.bak -e "s/\\\$RELEASEDATE/$RELEASEDATE/g" $TMP/$PROJECT/README.md
rm -f $TMP/$PROJECT/README.md.bak

mkdir -p $TMP/$PROJECT/doc/platex/jsclasses
mv $TMP/$PROJECT/LICENSE $TMP/$PROJECT/doc/platex/jsclasses/
mv $TMP/$PROJECT/README.md $TMP/$PROJECT/doc/platex/jsclasses/
mv $TMP/$PROJECT/*.pdf $TMP/$PROJECT/doc/platex/jsclasses/

mkdir -p $TMP/$PROJECT/source/platex/jsclasses
mv $TMP/$PROJECT/Makefile $TMP/$PROJECT/source/platex/jsclasses/
mv $TMP/$PROJECT/*.dtx $TMP/$PROJECT/source/platex/jsclasses/
mv $TMP/$PROJECT/*.ins $TMP/$PROJECT/source/platex/jsclasses/

# winjis.sty should be removed for CTAN
mkdir -p $TMP/$PROJECT/tex/platex/jsclasses
mv $TMP/$PROJECT/*.cls $TMP/$PROJECT/tex/platex/jsclasses/
rm $TMP/$PROJECT/winjis.sty
mv $TMP/$PROJECT/*.sty $TMP/$PROJECT/tex/platex/jsclasses/

cd $TMP/$PROJECT && zip -r $TMP/$PROJECT.tds.zip *
cd $PWDF
rm -rf $TMP/$PROJECT

echo
echo " * Create $PROJECT.zip ($RELEASEDATE)"
git archive --format=tar --prefix=$PROJECT/ HEAD | (cd $TMP && tar xf -)
# Remove generated and auxiliary files
# winjis.sty should be removed for CTAN
rm $TMP/$PROJECT/.gitignore
rm $TMP/$PROJECT/create_archive.sh
rm -rf $TMP/$PROJECT/tests
rm -rf $TMP/$PROJECT/jis
rm $TMP/$PROJECT/*.cls
rm $TMP/$PROJECT/*.sty
perl -pi.bak -e "s/\\\$RELEASEDATE/$RELEASEDATE/g" $TMP/$PROJECT/README.md
rm -f $TMP/$PROJECT/README.md.bak

cd $TMP && zip -r $PWDF/$PROJECT.zip $PROJECT $PROJECT.tds.zip
rm -rf $TMP/$PROJECT $TMP/$PROJECT.tds.zip
echo
echo " * Done: $PROJECT.zip ($RELEASEDATE)"
