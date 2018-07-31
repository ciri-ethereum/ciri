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
