FROM ruby:2.6.0-preview2 AS build

LABEL maintainer="Jiang Jinyang <jjyruby@gmail.com>"

# install RocksDB
RUN apt-get update && apt-get install -y libgflags-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev
COPY ./rocksdb /build/rocksdb
WORKDIR /build/rocksdb
RUN make shared_lib
RUN make install-shared

# install bitcoin secp256k1
COPY . /app
WORKDIR /app
RUN rake install:secp256k1

# Runtime image
FROM ruby:2.6.0-preview2
ENV RUBY_THREAD_VM_STACK_SIZE=52428800

# install runtime dependencies libraries
RUN apt-get update && apt-get install -y libsnappy-dev libgflags-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev

# copy header files and shared libraries
COPY --from=build /usr/local/include /usr/local/include
COPY --from=build /usr/local/lib/ /usr/local/lib

WORKDIR /app
COPY . /app

# bundle install
RUN bundle install
