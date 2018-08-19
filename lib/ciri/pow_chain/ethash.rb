# frozen_string_literal: true

# Copyright 2018 Jiang Jinyang <https://justjjy.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require_relative 'ethash/ffi_ethash'
require 'ciri/utils'
require 'lru_redux'
require 'concurrent'

module Ciri
  module POWChain

    # FFIEthash POW
    # see py-evm https://github.com/ethereum/py-evm/blob/026553da69bbea314fe26c8c34d453f66bfb4d30/evm/consensus/pow.py
    module Ethash

      extend self

      class Error < StandardError
      end

      class InvalidError < Error
      end

      class GivingUpError < Error
      end

      # thread safe caches
      @cache_seeds = Concurrent::Array.new(['\x00'.b * 32])
      @cache_by_seed = LruRedux::ThreadSafeCache.new(10)

      def get_cache(block_number)
        epoch = block_number / FFIEthash::EPOCH_LENGTH
        while @cache_seeds.size <= epoch
          @cache_seeds.append(Utils.keccak(@cache_seeds[-1]))
        end

        seed = @cache_seeds[epoch]

        @cache_by_seed.getset(seed) do
          FFIEthash.mkcache_bytes(block_number)
        end
      end

      def check_pow(block_number, mining_hash, mix_hash, nonce_bytes, difficulty)
        raise ArgumentError.new "mix_hash.length must equal to 32" if mix_hash.size != 32
        raise ArgumentError.new "mining_hash.length must equal to 32" if mining_hash.size != 32
        raise ArgumentError.new "nonce.length must equal to 8" if nonce_bytes.size != 8

        cache = get_cache(block_number)
        out_mix_hash, out_result = FFIEthash.hashimoto_light(block_number, cache, mining_hash, Utils.big_endian_decode(nonce_bytes))

        if out_mix_hash != mix_hash
          raise InvalidError.new("mix hash mismatch; #{Utils.to_hex(out_mix_hash)} != #{Utils.to_hex(mix_hash)}")
        end

        result = Utils.big_endian_decode(out_result)
        unless result < 2 ** 256 / difficulty
          raise InvalidError.new("difficulty not enough, need difficulty #{difficulty}, but result #{result}")
        end
      end

      MAX_TEST_MINE_ATTEMPTS = 1000

      def mine_pow_nonce(block_number, mining_hash, difficulty)
        cache = get_cache(block_number)
        MAX_TEST_MINE_ATTEMPTS.times do |nonce|
          out_mix_hash, out_result = FFIEthash.hashimoto_light(block_number, cache, mining_hash, nonce)
          result = Utils.big_endian_decode(out_result)
          result_cap = 2 ** 256 / difficulty
          return [out_mix_hash, Utils.big_endian_encode(nonce).rjust(8, "\x00")] if result <= result_cap
        end

        raise GivingUpError.new("tries too many times, giving up")
      end

    end
  end
end
