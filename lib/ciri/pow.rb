# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


require 'ciri/utils'
require_relative 'ethash'
require 'lru_redux'
require 'concurrent'

module Ciri

  # POW
  # see py-evm https://github.com/ethereum/py-evm/blob/026553da69bbea314fe26c8c34d453f66bfb4d30/evm/consensus/pow.py
  module POW

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
      epoch = block_number / Ethash::EPOCH_LENGTH
      while @cache_seeds.size <= epoch
        @cache_seeds.append(Utils.keccak(@cache_seeds[-1]))
      end

      seed = @cache_seeds[epoch]

      @cache_by_seed.getset(seed) do
        Ethash.mkcache_bytes(block_number)
      end
    end

    def check_pow(block_number, mining_hash, mix_hash, nonce_bytes, difficulty)
      raise ArgumentError.new "mix_hash.length must equal to 32" if mix_hash.size != 32
      raise ArgumentError.new "mining_hash.length must equal to 32" if mining_hash.size != 32
      raise ArgumentError.new "nonce.length must equal to 8" if nonce_bytes.size != 8

      cache = get_cache(block_number)
      out_mix_hash, out_result = Ethash.hashimoto_light(block_number, cache, mining_hash, Utils.big_endian_decode(nonce_bytes))

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
        out_mix_hash, out_result = Ethash.hashimoto_light(block_number, cache, mining_hash, nonce)
        result = Utils.big_endian_decode(out_result)
        result_cap = 2 ** 256 / difficulty
        return [out_mix_hash, Utils.big_endian_encode(nonce).rjust(8, "\x00")] if result <= result_cap
      end

      raise GivingUpError.new("tries too many times, giving up")
    end

  end
end
