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


module Ciri
  module P2P

    class Address
      attr_reader :ip, :udp_port, :tcp_port

      def initialize(ip:, udp_port:, tcp_port: udp_port)
        @ip = ip.is_a?(IPAddr) ? ip : IPAddr.new(ip)
        @udp_port = udp_port
        @tcp_port = tcp_port
      end

      def ==(other)
        self.class == other.class && ip == other.ip && udp_port == other.udp_port
      end

      def <=>(other)
        ip <=> other.ip
      end

      def inspect
        "<PeerStore::Address #{ip.inspect} udp_port: #{udp_port} tcp_port: #{tcp_port}>"
      end
    end

  end
end

