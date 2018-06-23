# HeaderChain
# store headers

module Ciri
  class Chain
    class HeaderChain
      HEAD = 'head'
      GENESIS = 'genesis'
      HEADER_PREFIX = 'h'
      TD_SUFFIX = 't'
      NUM_SUFFIX = 'n'

      attr_reader :store, :byzantium_block, :homestead_block

      def initialize(store, byzantium_block: nil, homestead_block: nil)
        @store = store
        @byzantium_block = byzantium_block
        @homestead_block = homestead_block
      end

      def head
        encoded = store[HEAD]
        encoded && Header.rlp_decode!(encoded)
      end

      def head=(header)
        store[HEAD] = header.rlp_encode!
      end

      def get_header(hash)
        encoded = store[HEADER_PREFIX + hash]
        encoded && Header.rlp_decode!(encoded)
      end

      def get_header_by_number(number)
        hash = get_header_hash_by_number(number)
        hash && get_header(hash)
      end

      def valid?(header)
        # ignore genesis header if there not exist one
        return true if header.number == 0 && get_header_by_number(0).nil?

        parent_header = get_header(header.parent_hash)
        return false unless parent_header
        # check height
        return false unless parent_header.number + 1 == header.number
        # check timestamp
        return false unless parent_header.timestamp < header.timestamp

        # check gas limit range
        parent_gas_limit = parent_header.gas_limit
        gas_limit_max = parent_gas_limit + parent_gas_limit / 1024
        gas_limit_min = parent_gas_limit - parent_gas_limit / 1024
        gas_limit = header.gas_limit
        return false unless gas_limit >= 5000 && gas_limit > gas_limit_min && gas_limit < gas_limit_max
        return false unless calculate_difficulty(header, parent_header) == header.difficulty

        # check pow
        begin
          POW.check_pow(header.number, header.mining_hash, header.mix_hash, header.nonce, header.difficulty)
        rescue POW::InvalidError
          return false
        end

        true
      end

      # calculate header difficulty
      # you can find explain in Ethereum yellow paper: Block Header Validity section.
      def calculate_difficulty(header, parent_header)
        return header.difficulty if header.number == 0

        x = parent_header.difficulty / 2048
        y = header.ommers_hash == Utils::BLANK_SHA3 ? 1 : 2

        # handle byzantium fork
        # https://github.com/ethereum/EIPs/blob/181867ae830df5419eb9982d2a24797b2dcad28f/EIPS/eip-609.md
        # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-100.md
        byzantium_fork = byzantium_block && header.number > byzantium_block
        # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-2.md
        homestead_fork = homestead_block && header.number > homestead_block

        time_factor = if byzantium_fork
                        [y - (header.timestamp - parent_header.timestamp) / 9, -99].max
                      elsif homestead_fork
                        [1 - (header.timestamp - parent_header.timestamp) / 10, -99].max
                      else
                        (header.timestamp - parent_header.timestamp) < 13 ? 1 : -1
                      end

        # difficulty bomb
        height = byzantium_fork ? [(header.number - 3000000), 0].max : header.number
        height_factor = 2 ** (height / 100000 - 2)

        difficulty = (parent_header.difficulty + x * time_factor + height_factor).to_i
        [header.difficulty, difficulty].max
      end

      # write header
      def write(header)
        hash = header.get_hash
        # get total difficulty
        td = if header.number == 0
               header.difficulty
             else
               parent_header = get_header(header.parent_hash)
               raise "can't find parent from db" unless parent_header
               parent_td = total_difficulty(parent_header.get_hash)
               parent_td + header.difficulty
             end
        # write header and td
        store.batch do |b|
          b.put(HEADER_PREFIX + hash, header.rlp_encode!)
          b.put(HEADER_PREFIX + hash + TD_SUFFIX, RLP.encode(td, Integer))
        end
      end

      def write_header_hash_number(header_hash, number)
        enc_number = Utils.big_endian_encode number
        store[HEADER_PREFIX + enc_number + NUM_SUFFIX] = header_hash
      end

      def get_header_hash_by_number(number)
        enc_number = Utils.big_endian_encode number
        store[HEADER_PREFIX + enc_number + NUM_SUFFIX]
      end

      def total_difficulty(header_hash = head.nil? ? nil : head.get_hash)
        return 0 if header_hash.nil?
        RLP.decode(store[HEADER_PREFIX + header_hash + TD_SUFFIX], Integer)
      end

    end
  end
end