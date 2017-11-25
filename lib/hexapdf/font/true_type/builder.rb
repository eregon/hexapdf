# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2017 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#++

module HexaPDF
  module Font
    module TrueType

      # Builds a TrueType font file given a hash of TrueType tables.
      module Builder

        # Returns a TrueType font file representing the given TrueType tables (a hash mapping table
        # names (strings) to table data).
        def self.build(tables)
          search_range = 2**(tables.length.bit_length - 1) * 16
          entry_selector = tables.length.bit_length - 1
          range_shift = tables.length * 16 - search_range

          font_data = "\x0\x1\x0\x0".b + \
            [tables.length, search_range, entry_selector, range_shift].pack('n4')

          offset = font_data.length + tables.length * 16
          checksum = Table.calculate_checksum(font_data)

          # prepare head table for checksumming
          tables['head'][8, 4] = "\0\0\0\0"

          tables.each do |tag, data|
            table_checksum = Table.calculate_checksum(data)
            # tag, offset, data.length are all 32bit uint, table_checksum for header and body
            checksum += tag.unpack('N').first + 2 * table_checksum + offset + data.length
            font_data << [tag, table_checksum, offset, data.length].pack('a4N3')
            offset += data.length
          end

          tables['head'][8, 4] = [0xB1B0AFBA - checksum].pack('N')
          tables.each_value {|data| font_data << data }

          font_data
        end

      end

    end
  end
end
