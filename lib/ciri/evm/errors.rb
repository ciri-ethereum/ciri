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


module Ciri
  class EVM

    class Error < StandardError
    end

    class InvalidTransition < Error
    end

    class InvalidTransaction < Error
    end

    # VM errors
    class VMError < Error
    end

    class InvalidOpCodeError < VMError
    end

    class GasNotEnoughError < VMError
    end

    class StackError < VMError
    end

    class InvalidJumpError < VMError
    end

    class ReturnError < VMError
    end

  end
end
