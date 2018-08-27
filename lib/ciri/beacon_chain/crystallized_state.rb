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


require 'ciri/rlp'
require 'ciri/types/int'
require 'ciri/types/hash'
require 'ciri/types/bytes'
require 'ciri/types/address'
require 'forwardable'
require_relative 'validator_record'
require_relative 'shard_and_committee'
require_relative 'crosslink_record'

module Ciri
  module BeaconChain

    class CrystallizedState
      include RLP::Serializable
      include Types

      schema(
          validators: [ValidatorRecord],
          last_state_recalc: [Int64],
          indices_for_slots: [[ShardAndCommittee]],
          last_justified_slot: Int64,
          justified_streak: Int64,
          last_finalized_slot: Int64,
          current_dynasty: Int64,
          crosslinking_start_shard: Int16,
          crosslink_records: [CrosslinkRecord],
          total_deposits: Int256,
          dynasty_seed: Hash32,
          dynasty_seed_last_reset: Int64,
      )
    end

  end
end


