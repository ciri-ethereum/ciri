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

module Shasper
  module Constants
    SHARD_COUNT = 1024
    DEPOSIT_SIZE = 32
    MAX_VALIDATOR_COUNT = 2 ** 22
    SLOT_DURATION = 8
    CYCLE_LENGTH = 64
    MIN_COMMITTEE_SIZE = 128
  end
end
