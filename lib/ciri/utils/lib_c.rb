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


require 'ffi'

module Ciri
  module Utils

    module LibC
      extend FFI::Library
      ffi_lib FFI::Library::LIBC

      # memory allocators
      attach_function :malloc, [:size_t], :pointer
      attach_function :calloc, [:size_t], :pointer
      attach_function :valloc, [:size_t], :pointer
      attach_function :realloc, [:pointer, :size_t], :pointer
      attach_function :free, [:pointer], :void

      # memory movers
      attach_function :memcpy, [:pointer, :pointer, :size_t], :pointer
      attach_function :bcopy, [:pointer, :pointer, :size_t], :void
    end

  end
end
