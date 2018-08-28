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
require 'ciri/pow_chain/transaction'
require 'ciri/utils'
require 'ciri/db/backend/memory'
require 'ciri/forks'

RSpec.describe Ciri::POWChain::Transaction do

  before(:all) do
    prepare_ethereum_fixtures
  end

  choose_fork_schema = proc do |fork_name|
    case fork_name
    when 'Frontier'
      Ciri::Forks::Frontier::Schema.new
    when 'Homestead'
      Ciri::Forks::Homestead::Schema.new(support_dao_fork: false)
    when 'EIP150'
      Ciri::Forks::TangerineWhistle::Schema.new
    when 'EIP158'
      Ciri::Forks::SpuriousDragon::Schema.new
    when 'Byzantium'
      Ciri::Forks::Byzantium::Schema.new
    when 'Constantinople'
      Ciri::Forks::Constantinople::Schema.new
    else
      raise ArgumentError.new("unknown fork #{fork_name}")
    end
  end

  run_test_case = proc do |test_case, prefix: nil|
    test_case.each do |name, t|

      %w{Byzantium Constantinople EIP150 EIP158 Frontier Homestead}.each do |fork_name|

        it "#{prefix} #{name} #{fork_name}" do
          expect_result = t[fork_name]

          fork_schema = choose_fork_schema[fork_name]

          transaction = begin
            rlp = Ciri::Utils.to_bytes(t['rlp'])
            transaction = fork_schema.transaction_class.rlp_decode rlp

            # encoded again and check rlp encoding
            fork_schema.transaction_class.rlp_encode(transaction) == rlp ? transaction : nil

          rescue Ciri::RLP::InvalidError, Ciri::Types::Errors::InvalidError
            nil
          end

          error_or_nil = begin
            raise Ciri::POWChain::Transaction::InvalidError if transaction.nil?
            transaction.validate!
          rescue Ciri::POWChain::Transaction::InvalidError => e
            e
          end

          unless expect_result.empty?
            expect(Ciri::Utils.to_hex transaction.get_hash).to eq "0x#{expect_result['hash']}"
            expect(Ciri::Utils.to_hex transaction.sender).to eq "0x#{expect_result['sender']}"
          end

        end

      end
    end
  end

  skip_topics = %w{}.map {|f| [f, true]}.to_h

  Dir.glob("fixtures/TransactionTests/*").each do |topic|
    # skip topics
    if skip_topics.include? topic
      skip topic
      next
    end

    Dir.glob("#{topic}/*.json").each do |t|
      run_test_case[JSON.load(open t), prefix: topic]
    end
  end

end
