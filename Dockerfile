# This file is a sample Dockerfile to build Re:VIEW documents.
#
# Build:
#   $ docker build -t review .
#
# Usage:
#   $ cd path/to/review/project
#   $ docker run -it --rm -v `pwd`:/work review rake pdf
#
# cf. https://github.com/vvakame/docker-review/blob/master/Dockerfile

FROM debian:buster
MAINTAINER takahashim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      locales git-core curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN locale-gen en_US.UTF-8 && update-locale en_US.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      texlive-lang-japanese texlive-fonts-recommended texlive-latex-extra lmodern fonts-lmodern cm-super tex-gyre fonts-texgyre texlive-pictures texlive-plain-generic \
      ghostscript gsfonts \
      zip ruby-zip \
      ruby-nokogiri mecab ruby-mecab mecab-ipadic-utf8 poppler-data \
      mecab-jumandic- mecab-jumandic-utf8- \
      texlive-extra-utils poppler-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN kanji-config-updmap-sys ipaex

RUN gem install review rake bundler --no-rdoc --no-ri

VOLUME ["/work"]
WORKDIR /work
