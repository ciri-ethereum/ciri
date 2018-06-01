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


module Ciri
  module EVM
    module Cost
      #   fee schedule, start with G
      G_ZERO = 0
      G_BASE = 2
      G_VERYLOW = 3
      G_LOW = 5
      G_MID = 8
      G_HIGH = 10
      G_EXTCODE = 700
      G_BALANCE = 400
      G_SLOAD = 200
      G_JUMPDEST = 1
      G_SSET = 20000
      G_RESET = 5000
      R_SCLEAR = 15000
      R_SELFDESTRUCT = 24000
      G_SELFDESTRUCT = 5000
      G_CREATE = 32000
      G_CODEDEPOSIT = 200
      G_CALL = 700
      G_CALLVALUE = 9000
      G_CALLSTIPEND = 2300
      G_NEWACCOUNT = 25000
      G_EXP = 10
      G_EXPBYTE = 50
      G_MEMORY = 3
      G_TXCREATE = 32000
      G_TXDATAZERO = 4
      G_TXDATANONZERO = 68
      G_TRANSACTION = 21000
      G_LOG = 375
      G_LOGDATA = 8
      G_TOPIC = 375
      G_SHA3 = 30
      G_SHA3WORD = 6
      G_COPY = 3
      G_BLOCKHASH = 20
      G_QUADDIVISOR = 100


      class << self
        # C(σ,μ,I)
        def cost(state, sub_state, instruction)
          0
        end
      end
    end
  end
end