# Re:VIEW catalog.yml Guide

This article describes Re:VIEW catalog file catalog.yml.

## What's catalog.yml

Catalog file shows the structure of files to generate books (such as PDF or EPUB) in Re:VIEW format.
Now we use catalog.yml as catalog file.

## How to write catalog.yml

In catalog.yaml, you can write `PREDEF`(frontmatter), `CHAPS`(bodymatter), `APPENDIX`(appendix) and `POSTDEF`(backmater). `CHAPS` is required.

```yaml
  PREDEF:
    - intro.re
  
  CHAPS:
    - ch01.re
    - ch02.re
  
  APPENDIX:
    - appendix.re
  
  POSTDEF:
    - postscript.re
```

You can add parts in body to use `CHAPS` in a hierarchy. You can use both title name and file name to specify parts.

```yaml
  CHAPS:
    - ch01.re
    - TITLE_OF_PART1:
      - ch02.re
      - ch03.re
    - pt02.re:
      - ch04.re
```

(For old version user: there is no `PART`. You write them in `CHAPS`.)

## About version 1.3 or earlier

You can not use `APPENDIX`. Use `POSTDEF`.

## About version 1.2 or earlier

Before version 1.2 or earlier, Re:VIEW use 4 files PREDEF, CHAPS, POSTDEF, PART as catalog files.
So you must use these files instead of catalog.yml when you use these versions of Re:VIEW.

Current Re:VIEW supports both catalog.yml and old catalog files. When there are both files, catalog.yml is used.
