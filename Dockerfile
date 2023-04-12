# Create by Antares https://github.com/Antares-RXD/
# The purpose of this image is to be able to host ElectrumX and novod together.
# Build with: `docker build -t electrumxNovonode .`

FROM ubuntu:20.04

LABEL maintainer="code@radiant4people.com"
LABEL version="1.0.0"
LABEL description="Docker image for electrumx and novo node"

ARG DEBIAN_FRONTEND=nointeractive
RUN apt update
RUN apt-get install -y curl

ENV PACKAGES="\
  build-essential \
  libcurl4-openssl-dev \
  software-properties-common \
  ubuntu-drivers-common \
  build-essential \
  git \
  libtool \
  autotools-dev \
  automake \
  pkg-config \
  libssl-dev \
  libevent-dev \
  bsdmainutils \
  libboost-system-dev \
  libboost-filesystem-dev \
  libboost-chrono-dev \
  libboost-program-options-dev \
  libboost-test-dev \
  libboost-thread-dev \
  libzmq3-dev \
  libminiupnpc-dev \
  python3 \
  python3-pip \
  librocksdb-dev \
  libsnappy-dev \
  libbz2-dev \
  libz-dev \
  liblz4-dev \
"
RUN apt update && apt install --no-install-recommends -y $PACKAGES  && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean

####################################################### INSTALL novo
WORKDIR /root
RUN git clone https://github.com/novochain/novo.git
WORKDIR /root/novo

RUN ./autogen.sh
RUN ./configure --disable-wallet
RUN make
RUN make install

# Remove novo folder, not need more
RUN rm /root/novo -Rf

RUN mkdir "/root/.novo/"
RUN touch "/root/.novo/novo.conf"

RUN echo '\
rpcuser=NovoDockerUser\n\
rpcpassword=NovoDockerPassword\n\
\n\
listen=1\n\
daemon=1\n\
server=1\n\
rpcworkqueue=512\n\
rpcthreads=64\n\
rpcallowip=0.0.0.0/0\
' >/root/.novo/novo.conf 

####################################################### INSTALL ELECTRUMX WITH SSL

# Create directory for DB
RUN mkdir /root/novodb

WORKDIR /root

# ORIGINAL SOURCE
#RUN git clone https://github.com/3untz/novo-electrumx.git
RUN git clone https://github.com/expiredhotdog/novo-electrumx

WORKDIR /root/novo-electrumx

RUN python3 -m pip install -r requirements.txt

ENV DAEMON_URL=http://NovoDockerUser:NovoDockerPassword@localhost:8665/
ENV COIN=Novo
ENV REQUEST_TIMEOUT=60
ENV DB_DIRECTORY=/root/novodb
ENV DB_ENGINE=leveldb
ENV SERVICES=tcp://0.0.0.0:50010,ssl://0.0.0.0:50012,rpc://0.0.0.0:8000
ENV SSL_CERTFILE=/root/novodb/server.crt
ENV SSL_KEYFILE=/root/novodb/server.key
ENV HOST=""
ENV ALLOW_ROOT=true
ENV CACHE_MB=10000
ENV MAX_SESSIONS=10000
ENV MAX_SEND=100000000
ENV MAX_RECV=100000000
ENV BANDWIDTH_UNIT_COST=20000
ENV RESOURCE_USAGE_LIMIT=200000

# Create SSL
WORKDIR /root/novodb
RUN openssl genrsa -out server.key 2048
RUN openssl req -new -key server.key -out server.csr -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=radiant4people.com"
RUN openssl x509 -req -days 1825 -in server.csr -signkey server.key -out server.crt

EXPOSE 50010 50012

ENTRYPOINT ["/bin/sh", "-c" , "novod && python3 /root/novo-electrumx/electrumx_server"]
