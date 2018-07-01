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
              raise Ciri::RLP::InvalidValueError, "not invalid encoding"
            end
          }.to raise_error(Ciri::RLP::InvalidValueError)
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
