# frozen_string_literal: true

# Copyright (c) 2018 by Jiang Jinyang <jjyruby@gmail.com>
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