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
require 'ciri/eth/protocol_messages'
require 'ciri/utils'

RSpec.describe Ciri::Eth::BlockBodies do

  it Ciri::Eth::HashOrNumber do
    encoded = Ciri::Eth::HashOrNumber.rlp_encode Ciri::Eth::HashOrNumber.new(42)
    expect(Ciri::Eth::HashOrNumber.rlp_decode(encoded)).to eq 42

    hash = "\x02".b * 32
    encoded = Ciri::Eth::HashOrNumber.rlp_encode Ciri::Eth::HashOrNumber.new(hash)
    expect(Ciri::Eth::HashOrNumber.rlp_decode(encoded)).to eq hash
  end

  it 'decode block bodies message' do
    payload = Ciri::Utils.dehex 'f904cdf904caf904c6f86e8201d3850df84758008252089432be343b94f860124dc4fee278fdcbd38c102d8888102363ac310a4000801ca043531017f1569ec692c0bf1ad710ddb5158b60505ea33fb7a21245738539e2d5a03856c6a1117ff71e9b769ccb6960674038a3326c3dd84c152fc83ada28145a07f86c09850df84758008252089432be343b94f860124dc4fee278fdcbd38c102d88880ed350879ce50000801ba08219a4f30cb8dd7d5e1163ac433f207b599d804b0d74ee54c8694014db647700a03db2e806986a746d44d675fdbbd7594bb2856946ba257209abfffdd1628141aff86c59850df84758008252089432be343b94f860124dc4fee278fdcbd38c102d88882b0ca8b9f5f02000801ba01ca26859a6eed116312010359c2e8351d126f31b078a0e2e19aae0acc98d9488a0172c1a299737440a9063af6547d567ca7d269bfc2a9e81ec1de21aa8bd8e17b1f86c02850df84758008252089432be343b94f860124dc4fee278fdcbd38c102d88880fd037ba87693800801ba00a5aca100a264a8da4a58bef77c5116a6dde42186ac249623c0edcb30189640aa0783e9439755023b919897574f94337aaac4a1ddc20217e3ac264a7edf813ffddf86d81d9850df84758008252089432be343b94f860124dc4fee278fdcbd38c102d888814bac05c835a5400801ba00b93c6f8dce800a1ec57d70813c4d35e3ffe25a6f1ae9057cf706636cf34d662a06d254a5557b7716ef01dd28aa84cc919f397c0a778f3a109a1ee9df2fc530ec0f86c34850df84758008252089432be343b94f860124dc4fee278fdcbd38c102d88880f258512af0d4000801ba0e9a25c929c26d1a95232ba75aef419a91b470651eb77614695e16c5ba023e383a0679fb2fc0d0b0f3549967c0894ee7d947f07d238a83ef745bc3ced5143a4af36f86c6f850df84758008252089432be343b94f860124dc4fee278fdcbd38c102d88881c54e302456eb400801ca09e0b8360a36d6d0320aef19bd811431b1a692504549da9f05f9b4d9e329993b9a05acff70bd8cf82d9d70b11d4e59dc5d54937475ec394ec846263495f61e5e6eef86c46850df84758008252089432be343b94f860124dc4fee278fdcbd38c102d88880f0447b1edca4000801ca0b2803f1bfa237bda762d214f71a4c71a7306f55df2880c77d746024e81ccbaa2a07aeed35c0cbfbe0ed6552fd55b3f57fdc054eeabd02fc61bf66d9a8843aa593af86d03850ba43b740083015f909426016a2b5d872adc1b131a4cd9d4b18789d0d9eb88016345785d8a0000801ba06dccb1349919662c40455aee04472ae307195580837510ecf2e6fc428876eb03a03b84ea9c3c6462ac086a1d789a167c2735896a6b5a40e85a6e45da8884fe27def8708302a11f850ba43b740083015f90945275c3371ece4d4a5b1e14cf6dbfc2277d58ef92880e93ea6a35f2e000801ba0aa8909295ff178639df961126970f44b5d894326eb47cead161f6910799a98b8a0254d7742eccaf2f4c44bfe638378dcf42bdde9465f231b89003cc7927de5d46ef8708302a120850ba43b740083015f90941c51bf013add0857c5d9cf2f71a7f15ca93d4816880e917c4b10c87400801ca0cfe3ad31d6612f8d787c45f115cc5b43fb22bcc210b62ae71dc7cbf0a6bea8dfa057db8998114fae3c337e99dbd8573d4085691880f4576c6c1f6c5bbfe67d6cf0c0'
    block_bodies = Ciri::Eth::BlockBodies.rlp_decode(payload)
    expect(block_bodies.bodies.size).to eq 1
    expect(block_bodies.bodies[0].transactions.size).to eq 11
  end
end
