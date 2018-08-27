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