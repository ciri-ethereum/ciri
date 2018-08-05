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


require 'ciri/evm/op'

module Ciri
  module Forks
    module Frontier

      include Ciri::EVM::OP

      OPCODES = [
          STOP,
          ADD,
          MUL,
          SUB,
          DIV,
          SDIV,
          MOD,
          SMOD,
          ADDMOD,
          MULMOD,
          EXP,
          SIGNEXTEND,
          LT,
          GT,
          SLT,
          SGT,
          EQ,
          ISZERO,
          AND,
          OR,
          XOR,
          NOT,
          BYTE,
          SHA3,
          ADDRESS,
          BALANCE,
          ORIGIN,
          CALLER,
          CALLVALUE,
          CALLDATALOAD,
          CALLDATASIZE,
          CALLDATACOPY,
          CODESIZE,
          CODECOPY,
          GASPRICE,
          EXTCODESIZE,
          EXTCODECOPY,
          BLOCKHASH,
          COINBASE,
          TIMESTAMP,
          NUMBER,
          DIFFICULTY,
          GASLIMIT,
          POP,
          MLOAD,
          MSTORE,
          MSTORE8,
          SLOAD,
          SSTORE,
          JUMP,
          JUMPI,
          PC,
          MSIZE,
          GAS,
          JUMPDEST,
          *(PUSH1..PUSH32),
          *(DUP1..DUP16),
          *(SWAP1..SWAP16),
          *(LOG0..LOG4),
          CREATE,
          CALL,
          CALLCODE,
          RETURN,
          INVALID,
          SELFDESTRUCT,
      ].map do |op|
        [op, Ciri::EVM::OP.get(op)]
      end.to_h.freeze


    end
  end
end