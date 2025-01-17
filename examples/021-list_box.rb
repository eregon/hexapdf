# # List Box
#
# This example shows how [HexaPDF::Layout::ListBox] can be used to place
# contents into lists.
#
# The list box class provides several options to style the item marker
# and its general appearance.
#
# Usage:
# : `ruby list_box.rb`
#

require 'hexapdf'

HexaPDF::Composer.create("list_box.pdf") do |composer|
  composer.box(:list, content_indentation: 40, item_spacing: 20) do |list|
    list.lorem_ipsum_box
    list.image(File.join(__dir__, 'machupicchu.jpg'), height: 100)
    list.box(:list, item_type: :decimal) do |sub_list|
      1.upto(10) {|i| sub_list.text("Item #{i}") }
    end
    list.box(:column) do |column|
      column.lorem_ipsum_box(count: 3)
    end
  end
end
