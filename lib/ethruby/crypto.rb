# frozen_string_literal: true
#
# this module include several methods translated from pydevp2p.devp2p.crypto

require 'openssl'
require 'ethruby/utils'

module Eth
  module Crypto
    extend self

    class ECIESDecryptionError < StandardError
    end

    ECIES_CIPHER_NAME = 'aes-128-ctr'

    def ecies_encrypt(message, raw_pubkey, shared_mac_data = '')
      pubkey = raw_pubkey.is_a?(OpenSSL::PKey::EC) ? raw_pubkey : ec_pkey_from_raw(raw_pubkey)

      # compute keys
      ephem_key = OpenSSL::PKey::EC.new('secp256k1')
      ephem_key.generate_key
      shared_secret = ephem_key.dh_compute_key(pubkey.public_key)
      key = ecies_kdf(shared_secret, 32)
      key_enc, key_mac = key[0...16], key[16..-1]

      key_mac = Digest::SHA256.digest(key_mac)
      ephem_raw_pubkey = ephem_key.public_key.to_bn.to_s(2)

      cipher = OpenSSL::Cipher.new(ECIES_CIPHER_NAME)
      cipher.encrypt
      iv = cipher.random_iv
      cipher.key = key_enc
      cipher_text = cipher.update(message) + cipher.final
      msg = ephem_raw_pubkey + iv + cipher_text
      tag = hmac_sha256(key_mac, msg[ephem_raw_pubkey.size..-1] + shared_mac_data)
      msg + tag
    end

    def ecies_decrypt(data, priv_key, shared_mac_data = '')
      raise ECIESDecryptionError.new('invalid header') if data[0] != "\x04"

      # compute shared_secret
      ephem_raw_pubkey = data[0..64]
      # add first byte tag
      ephem_pubkey = ec_pkey_from_raw(ephem_raw_pubkey)
      shared_secret = priv_key.dh_compute_key(ephem_pubkey.public_key)

      key = ecies_kdf(shared_secret, 32)
      key_enc, key_mac = key[0...16], key[16..-1]

      # verify data
      key_mac = Digest::SHA256.digest(key_mac)
      tag = data[-32..-1]
      unless Eth::Utils.secret_compare(hmac_sha256(key_mac, data[65...-32] + shared_mac_data), tag)
        raise ECIESDecryptionError.new("Fail to verify data")
      end

      # decrypt data
      cipher = OpenSSL::Cipher.new(ECIES_CIPHER_NAME)

      iv_start = 65
      iv_end = iv_start + cipher.iv_len
      iv = data[iv_start...iv_end]
      ciphertext = data[iv_end...-32]

      cipher.decrypt
      cipher.key = key_enc
      cipher.iv = iv
      cipher.update(ciphertext) + cipher.final
    end

    private
    def ecies_kdf(key_material, key_len)
      s1 = ''.b
      key = ''.b
      hash_block_size = 64
      reps = ((key_len + 7) * 8) / (hash_block_size * 8)
      counter = 0
      while counter <= reps
        counter += 1
        ctx = Digest::SHA256.new
        ctx.update([counter].pack("I>*"))
        ctx.update(key_material)
        ctx.update(s1)
        key += ctx.digest
      end
      key
    end

    def hmac_sha256(key, data)
      OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, data)
    end

    def ec_pkey_from_raw(raw_pubkey, raw_privkey: nil)
      Eth::Utils.create_ec_pk(raw_pubkey: raw_pubkey, raw_privkey: raw_privkey)
    end

  end
end