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

module Ciri
  module EVM

    Account = Struct.new(:address, :balance, :code, :nonce, :storage, keyword_init: true) do
      # EMPTY(σ,a) ≡ σ[a]c =KEC􏰁()􏰂∧σ[a]n =0∧σ[a]b =0
      def empty?
        code == Utils::BLANK_SHA3 && nonce == 0 && balance == 0
      end

      def self.new_empty(address)
        Account.new(address: address, balance: 0, nonce: 0, storage: {})
      end
    end

  end
end
