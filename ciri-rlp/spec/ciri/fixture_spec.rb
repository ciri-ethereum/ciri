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
require 'json'
require 'ciri/rlp'
require 'ciri/utils'

RSpec.describe Ciri::RLP do

  fixture_path = File.join(File.dirname(__FILE__), "..", "..", "..", "fixtures")

  before(:all) do
    `git submodule init #{fixture_path}`
    `git submodule update #{fixture_path}`
  end

  decode_types = proc do |value|
    if value.is_a?(Array)
      value.map {|i| decode_types[i]}
    elsif value.is_a?(String)
      Ciri::RLP::Raw
    else
      value.class
    end
  end

  skip_tests = %w{
  }.map {|f| [f, true]}.to_h

  run_test_case = proc do |test_case, prefix: nil, tags: {}|
    test_case.each do |name, t|
      tags2 = tags.dup

      if skip_tests.include?(name)
        tags2[:skip] = true
      end

      it "#{prefix} #{name}", **tags2 do
        # in
        in_value = t['in']
        if in_value.is_a?(String) && in_value.start_with?('#')
          in_value = in_value[1..-1].to_i
        end
        out_value = t['out']

        if in_value == 'INVALID'
          expect {
            rlp_decoded = Ciri::RLP.decode(Ciri::Utils.to_bytes out_value)
            if Ciri::Utils.to_hex(Ciri::RLP.encode(rlp_decoded)) != out_value
              raise Ciri::RLP::InvalidError, "not invalid encoding"
            end
          }.to raise_error(Ciri::RLP::InvalidError)
        elsif in_value == 'VALID'
          expect {Ciri::RLP.decode(Ciri::Utils.to_bytes out_value)}.to_not raise_error
        else
          rlp_encoded = Ciri::RLP.encode(in_value)
          expect(Ciri::Utils.to_hex(rlp_encoded)[2..-1]).to eq out_value

          rlp_decoded = Ciri::RLP.decode(Ciri::Utils.to_bytes(out_value), decode_types[in_value])
          expect(rlp_decoded).to eq in_value
        end

      end

    end
  end

  Dir.glob("#{fixture_path}/RLPTests/**/*.json").each do |topic|
    tags = {}

    run_test_case[JSON.load(open topic), prefix: 'fixtures/RLPTests', tags: tags]
  end

end
