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


require 'spec_helper'
require 'ciri/db/account_db'
require 'ciri/rlp'
require 'ciri/utils'


# copy from https://github.com/ethereum/py-trie/blob/master/tests/test_proof.py
RSpec.describe Ciri::DB::AccountDB do

  let(:account1) do
    [Ciri::Utils.to_bytes('0x8888f1f195afa192cfee860698584c030f4c9db1'), Ciri::Types::Account.new_empty]
  end

  it 'find_account' do
    address, account = account1
    account.nonce = 3
    account_db = Ciri::DB::AccountDB.new({})
    account_db.set_nonce(address, account.nonce)
    expect(account_db.find_account(address)).to eq account
  end

  it 'store' do
    address, account = account1

    account_db = Ciri::DB::AccountDB.new({})
    account_db.store(address, 42, 1530984410)
    expect(account_db.fetch(address, 42)).to eq 1530984410
  end

end
