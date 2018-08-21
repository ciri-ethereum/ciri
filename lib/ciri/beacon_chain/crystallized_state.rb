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

      schema [
        {validators: [ValidatorRecord]},
        {last_state_recalc: [Int64]},
        {indices_for_slots: [[ShardAndCommittee]]},
        {last_justified_slot: Int64},
        {justified_streak: Int64},
        {last_finalized_slot: Int64},
        {current_dynasty: Int64},
        {crosslinking_start_shard: Int16},
        {crosslink_records: [CrosslinkRecord]},
        {total_deposits: Int256},
        {dynasty_seed: Hash32},
        {dynasty_seed_last_reset: Int64},
      ]
    end

  end
end


