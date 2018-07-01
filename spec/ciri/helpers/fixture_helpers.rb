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


require 'yaml'
require 'json'

module FixtureHelpers
  FIXTURE_DIR = "spec/fixtures"

  def fixture(file)
    path = FIXTURE_DIR + '/' + file
    extname = File.extname(path)

    # guess file
    if extname.empty? && !File.exist?(path)
      if File.exist? path + '.json'
        extname = '.json'
      elsif File.exist? path + '.yaml'
        extname = '.yaml'
      elsif File.exist? path + '.yml'
        extname = '.yml'
      end
      path += extname
    end

    f = open(path)
    if extname == '.yaml' || extname == '.yml'
      YAML.load(f.read)
    elsif extname == '.json'
      JSON.parse(f.read)
    else
      f.read
    end
  end

  def raw_hash_to_block(b)
    data = b.map {|k, v| [Ciri::Utils.to_underscore(k).to_sym, v]}.to_h
    # convert hex to binary
    %i{extra_data hash logs_bloom miner mix_hash nonce parent_hash receipts_root sha3_uncles state_root transactions_root}.each do |k|
      data[k] = Ciri::Utils.to_bytes(data[k])
    end
    # fix key name
    data[:ommers_hash] = data[:sha3_uncles]
    data[:beneficiary] = data[:miner]
    transactions = data[:transactions]
    uncles = data[:uncles].map {|u| raw_hash_to_block(u).header}
    data = data.select {|k, v| Ciri::Chain::Header.schema.keys.include? k}.to_h
    header = Ciri::Chain::Header.new(**data)
    Ciri::Chain::Block.new(header: header, transactions: transactions, ommers: uncles)
  end

  def load_blocks(file)
    require 'ciri/chain'

    fixture(file).map do |b|
      raw_hash_to_block(b)
    end
  end

end
