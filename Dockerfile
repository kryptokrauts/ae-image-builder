FROM elixir:1.10

# Versions to build the image with
# IMPORTANT: currently it's also needed to change the tag in the github action manually to push the image with the right tags
ENV NODE_VERSION="v6.1.0"
ENV INDAEX_VERSION="1.0.7"

# Install required dependencies
RUN apt-get -qq update && apt-get -qq -y install curl libncurses5 libsodium-dev jq build-essential gcc g++ make libgmp10 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*

# Prepare working folder
RUN mkdir -p /home/aeternity/node
WORKDIR /home/aeternity/node

# Download, and unzip latest aeternity release archive
ENV NODEDIR=/home/aeternity/node/local/rel/aeternity
RUN mkdir -p ./local/rel/aeternity/data/mnesia
RUN curl -s https://api.github.com/repos/aeternity/aeternity/releases/tags/${NODE_VERSION} | \
       jq '.assets[1].browser_download_url' | \
       xargs curl -L --output aeternity.tar.gz  && tar -C ./local/rel/aeternity -xf aeternity.tar.gz

RUN chmod +x ${NODEDIR}/bin/aeternity
RUN cp -r ./local/rel/aeternity/lib local/

# Download the indaex release and copy files needed to build the project
RUN mkdir /tmp-indaex
RUN curl -s https://api.github.com/repos/aeternity/ae_mdw/releases/tags/${INDAEX_VERSION} | \
       jq '.tarball_url' | \
       xargs curl -L --output indaex.tar.gz  && tar -C /tmp-indaex -xf indaex.tar.gz 

RUN mkdir ae_mdw

# Copy all files, needed to build the project
RUN cp -r /tmp-indaex/*/config ./ae_mdw/config
RUN cp -r /tmp-indaex/*/lib ./ae_mdw/lib
RUN cp -r /tmp-indaex/*/mix.exs ./ae_mdw
RUN cp -r /tmp-indaex/*/mix.lock ./ae_mdw
RUN cp -r /tmp-indaex/*/Makefile ./ae_mdw
COPY entrypoint.sh ae_mdw/entrypoint.sh

# Remove tmp files and folders
RUN rm aeternity.tar.gz
RUN rm indaex.tar.gz
RUN rm -rf /tmp-indaex

# Start building indaex
WORKDIR /home/aeternity/node/ae_mdw
RUN  mix local.hex --force && mix local.rebar --force

# Fetch the application dependencies and build it
RUN mix deps.get
RUN mix deps.compile
ENV NODEROOT=/home/aeternity/node/local
RUN make compile-backend

RUN chmod +x ./entrypoint.sh
ENTRYPOINT [ "./entrypoint.sh" ]
