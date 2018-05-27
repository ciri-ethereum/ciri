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


require 'ffi'
require 'ciri/utils/lib_c'

module Ciri

  # Ethash Algorithm
  # from https://github.com/ethereum/ethash/blob/master/src/python/core.c
  module Ethash

    module Lib
      extend FFI::Library
      ffi_lib 'libethash'

      # struct ethash_light {
      #   void* cache;
      #   uint64_t cache_size;
      #   uint64_t block_number;
      # };
      class Light < FFI::Struct
        layout :cache, :pointer,
               :cache_size, :uint64,
               :block_number, :uint64
      end

      # struct ethash_h256 { uint8_t b[32]; }
      class H256 < FFI::Struct
        layout :b, [:uint8, 32]

        def put_b(s)
          self[:b].to_ptr.put_array_of_uint8(0, s.each_byte.to_a)
        end

        def get_b
          self[:b].to_ptr.get_array_of_uint8(0, 32).join
        end
      end

      # struct ethash_return_value {
      #   ethash_h256_t result;
      #   ethash_h256_t mix_hash;
      #   bool success;
      # }
      class ReturnValue < FFI::Struct
        layout :result, H256,
               :mix_hash, H256,
               :success, :bool
      end

      attach_function :ethash_light_new, [:int], Light
      attach_function :ethash_light_delete, [Light], :void
      attach_function :ethash_light_compute, [Light, H256.by_value, :uint64], ReturnValue.by_value
    end

    EPOCH_LENGTH = 30000

    class Error < StandardError
    end

    # use methods as module methods
    extend self

    # return [mix_hash, result]
    def hashimoto_light(block_number, cache_bytes, header, nonce)
      header_size = header.size
      cache_size = cache_bytes.size
      raise Error.new("seed must be 32 bytes long, (was #{header_size})") if header_size != 32

      cache_ptr = Utils::LibC.malloc(cache_size)
      cache_ptr.write_string_length(cache_bytes, cache_size)

      light = Lib::Light.new
      light[:cache] = cache_ptr
      light[:cache_size] = cache_size
      light[:block_number] = block_number

      h = Lib::H256.new
      h.put_b(header[0..32])

      value = Lib.ethash_light_compute(light, h, nonce)
      raise Error.new "compute not success, return: #{value[:success]}" unless value[:success]

      result = [value[:mix_hash], value[:result]]

      # release memory *_*
      Utils::LibC.free cache_ptr

      result
    end

    def mkcache_bytes(block_number)
      ptr = Lib.ethash_light_new(block_number)
      light = Lib::Light.new(ptr)
      cache_ptr = light[:cache]
      bytes = cache_ptr.read_string(light[:cache_size])
      Lib.ethash_light_delete(light)
      bytes
    end

  end
end
