FROM ruby:2.6.0-preview2
LABEL maintainer="Jiang Jinyang <jjyruby@gmail.com>"

RUN apt-get update -y
RUN apt-get install -y cmake

# install bitcoin secp256k1
COPY ./secp256k1 /build/secp256k1
WORKDIR /build/secp256k1
RUN ./autogen.sh
RUN ./configure --enable-module-recovery --enable-experimental --enable-module-ecdh
RUN make && make install

# install ethash
COPY ./ethash /build/ethash
WORKDIR /build/ethash/src/libethash
RUN cmake CMakeLists.txt
RUN make install

# install RocksDB
RUN apt-get install -y libgflags-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev
COPY ./rocksdb /build/rocksdb
WORKDIR /build/rocksdb
RUN make shared_lib
RUN make install-shared

# install snappy
RUN apt-get install -y libsnappy-dev

WORKDIR /app
COPY . /app

ENV RUBY_THREAD_VM_STACK_SIZE=52428800

# bundle install
RUN bundle install

