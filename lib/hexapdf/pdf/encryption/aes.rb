# -*- encoding: utf-8 -*-

require 'securerandom'
require 'hexapdf/error'

module HexaPDF
  module PDF
    module Encryption

      # Common interface for AES algorithms
      #
      # This module defines the common interface that is used by the security handlers to encrypt or
      # decrypt data with AES. It has to be *prepended* by any AES algorithm class.
      #
      # See the ClassMethods module for available class level methods of AES algorithms.
      #
      # == Implementing an AES Class
      #
      # An AES class needs to define at least the following methods:
      #
      # initialize(key, iv, mode)::
      #   Initializes the AES algorithm with the given key and initialization vector. The mode
      #   determines how the AES algorithm object works: If the mode is :encrypt, the object
      #   encrypts the data, if the mode is :decrypt, the object decrypts the data.
      #
      # process(data)::
      #   Processes the data and returns the encrypted/decrypted data. The method can assume that
      #   the passed in data always has a length that is a multiple of BLOCK_SIZE.
      module AES

        # Valid AES key lengths
        VALID_KEY_LENGTH = [16, 24, 32]

        # The AES block size
        BLOCK_SIZE = 16

        # Convenience methods for decryption and encryption that operate according to the PDF
        # specification.
        #
        # These methods will be available on the class object that prepends the AES module.
        module ClassMethods

          # Encrypts the given +data+ using the +key+ and a randomly generated initialization
          # vector.
          #
          # The data is padded using the PKCS#5 padding scheme and the initialization vector is
          # prepended to the encrypted data,
          #
          # See: PDF1.7 s7.6.2.
          def encrypt(key, data)
            iv = random_bytes(BLOCK_SIZE)
            iv << new(key, iv, :encrypt).process(pad(data))
          end

          # Returns a Fiber object that encrypts the data from the given source fiber with the
          # +key+.
          #
          # Padding and the initialization vector are handled like in #encrypt.
          def encryption_fiber(key, source)
            Fiber.new do
              data = random_bytes(BLOCK_SIZE)
              algorithm = new(key, data, :encrypt)
              Fiber.yield(data)

              data = ''.force_encoding(Encoding::BINARY)
              while source.alive? && (new_data = source.resume)
                data << new_data
                next if data.length < 16
                Fiber.yield(algorithm.process(data.slice!(0, data.length - 16 - data.length % 16)))
              end

              algorithm.process(pad(data))
            end
          end

          # Decrypts the given +data+ using the +key+.
          #
          # It is assumed that the initialization vector is included in the first BLOCK_SIZE bytes
          # of the data. After the decryption the PKCS#5 padding is removed.
          #
          # See: PDF1.7 s7.6.2.
          def decrypt(key, data)
            if data.length % 16 != 0 || data.length < 32
              raise HexaPDF::Error, "Invalid data for decryption, need 32 + 16*n bytes"
            end
            unpad(new(key, data.slice!(0, BLOCK_SIZE), :decrypt).process(data))
          end

          # Returns a Fiber object that decrypts the data from the given source fiber with the
          # +key+.
          #
          # Padding and the initialization vector are handled like in #decrypt.
          def decryption_fiber(key, source)
            Fiber.new do
              data = ''.force_encoding(Encoding::BINARY)
              while data.length < 16 && source.alive? && (new_data = source.resume)
                data << new_data
              end

              algorithm = new(key, data.slice!(0, BLOCK_SIZE), :decrypt)

              while source.alive? && (new_data = source.resume)
                data << new_data
                next if data.length < 16
                Fiber.yield(algorithm.process(data.slice!(0, data.length - 16 - data.length % 16)))
              end

              if data.length < 16 || data.length % 16 != 0
                raise HexaPDF::Error, "Invalid data for decryption, need 32 + 16*n bytes"
              end

              unpad(algorithm.process(data))
            end
          end

          # Returns a string of n random bytes.
          #
          # The specific AES algorithm class can override this class method to provide another
          # method for generating random bytes.
          def random_bytes(n)
            SecureRandom.random_bytes(n)
          end

          private

          # Pads the data to a muliple of BLOCK_SIZE using the PKCS#5 padding scheme and returns the
          # result.
          #
          # See: PDF1.7 s7.6.2
          def pad(data)
            padding_length = BLOCK_SIZE - data.size % BLOCK_SIZE
            data + padding_length.chr * padding_length
          end

          # Removes the padding from the data according to the PKCS#5 padding scheme and returns the
          # result.
          #
          # See: PDF1.7 s7.6.2
          def unpad(data)
            padding_length = data.getbyte(-1)
            if padding_length > 16 || padding_length == 0
              raise HexaPDF::Error, "Invalid AES padding length #{padding_length}"
            end
            data[0...-padding_length]
          end

        end

        # Automatically extends the klass with the necessary class level methods.
        def self.prepended(klass) # :nodoc:
          klass.extend(ClassMethods)
        end

        # Creates a new AES object using the given encryption key and initialization vector.
        #
        # The mode must either be :encrypt or :decrypt.
        #
        # Classes prepending this module have to have their own initialization method as this method
        # just performs basic checks.
        def initialize(key, iv, mode)
          unless VALID_KEY_LENGTH.include?(key.length)
            raise HexaPDF::Error, "AES key length must be 128, 192 or 256 bit"
          end
          unless iv.length == BLOCK_SIZE
            raise HexaPDF::Error, "AES initialization vector length must be 128 bit"
          end
          mode = mode.intern
          super
        end

      end

    end
  end
end