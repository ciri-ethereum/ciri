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


require 'ciri/core_ext'
require 'ciri/crypto'
require 'digest'

using Ciri::CoreExt

module Ciri
  class EVM
    module PrecompileContract

      class ECRecover
        GAS_ECRECOVER = 3000

        def call(vm)
          vm.consume_gas(GAS_ECRECOVER)
          message_hash = vm.instruction.data[0...32].pad_zero(32)

          v = vm.instruction.data[32...64].decode_big_endian
          r = vm.instruction.data[64...96].decode_big_endian
          s = vm.instruction.data[96...128].decode_big_endian
          unless valid_vrs?(v, r, s)
            return vm.set_exception(Error.new("invalid vrs"))
          end
          raw_v = v - 27
          begin
            signature = Ciri::Crypto::Signature.new(vrs: [raw_v, r, s])
            key = Ciri::Key.ecdsa_recover(message_hash, signature)
          rescue StandardError => e
            return vm.set_exception(e)
          end

          vm.set_output(key.to_address.to_s)
        end

        def valid_vrs?(v, r, s)
          return false unless r < Ciri::Crypto::SECP256K1N
          return false unless s < Ciri::Crypto::SECP256K1N
          return false unless v == 28 || v == 27
          true
        end
      end

      class SHA256
        GAS_SHA256 = 60
        GAS_SHA256WORD = 12

        def call(vm)
          input_bytes = vm.instruction.data
          word_count = input_bytes.size.ceil_div(32) / 32
          gas_fee = GAS_SHA256 + word_count * GAS_SHA256WORD
          vm.consume_gas(gas_fee)
          vm.set_output input_bytes.keccak
        end
      end

      class RIPEMD160
        GAS_RIPEMD160 = 600
        GAS_RIPEMD160WORD = 120

        def call(vm)
          input_bytes = vm.instruction.data
          word_count = input_bytes.size.ceil_div(32) / 32
          gas_fee = GAS_RIPEMD160 + word_count * GAS_RIPEMD160WORD
          vm.consume_gas(gas_fee)
          vm.set_output Digest::RMD160.digest(input_bytes).pad_zero(32)
        end
      end

      class Identity
        GAS_IDENTITY = 15
        GAS_IDENTITYWORD = 3

        def call(vm)
          input_bytes = vm.instruction.data
          word_count = input_bytes.size.ceil_div(32) / 32
          gas_fee = GAS_IDENTITY + word_count * GAS_IDENTITYWORD
          vm.consume_gas(gas_fee)
          computation.output = input_bytes
        end
      end


    end
  end
end