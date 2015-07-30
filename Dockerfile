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

FROM debian:sid
MAINTAINER takahashim

RUN apt-get update \
	&& apt-get install -y --no-install-recommends git-core ruby locales zip \
    && apt-get install -y --no-install-recommends texlive-lang-cjk texlive-lang-japanese texlive-fonts-recommended texlive-latex-extra ghostscript \
	&& rm -rf /var/lib/apt/lists/*
RUN gem install review rake bundler --no-rdoc --no-ri

VOLUME ["/work"]
WORKDIR /work
