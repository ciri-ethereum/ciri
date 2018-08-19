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


require 'ffi'

module Ciri
  module POWChain
    module Ethash
      module FFIEthash

        # Ethash Algorithm
        # from https://github.com/ethereum/ethash/blob/master/src/python/core.c

        module LibC
          extend FFI::Library
          ffi_lib FFI::Library::LIBC

          # memory allocators
          attach_function :malloc, [:size_t], :pointer
          attach_function :calloc, [:size_t], :pointer
          attach_function :valloc, [:size_t], :pointer
          attach_function :realloc, [:pointer, :size_t], :pointer
          attach_function :free, [:pointer], :void

          # memory movers
          attach_function :memcpy, [:pointer, :pointer, :size_t], :pointer
          attach_function :bcopy, [:pointer, :pointer, :size_t], :void
        end

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

            def put_bytes(s)
              self[:b].to_ptr.put_array_of_uint8(0, s.each_byte.to_a)
            end

            def get_bytes
              self[:b].to_ptr.get_array_of_uint8(0, 32).pack("c*")
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

          cache_ptr = LibC.malloc(cache_size)
          cache_ptr.write_string_length(cache_bytes, cache_size)

          light = Lib::Light.new
          light[:cache] = cache_ptr
          light[:cache_size] = cache_size
          light[:block_number] = block_number

          h = Lib::H256.new
          h.put_bytes(header[0..32])

          value = Lib.ethash_light_compute(light, h, nonce)
          raise Error.new "compute not success, return: #{value[:success]}" unless value[:success]

          result = [value[:mix_hash].get_bytes, value[:result].get_bytes]

          # release memory *_*
          LibC.free cache_ptr

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
  end
end
