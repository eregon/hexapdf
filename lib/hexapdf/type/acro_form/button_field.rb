# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
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
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'hexapdf/type/acro_form/field'
require 'hexapdf/type/acro_form/appearance_generator'

module HexaPDF
  module Type
    module AcroForm

      # AcroForm button fields represent interactive controls to be used with the mouse.
      #
      # They are divided into push buttons (things to click on), check boxes and radio buttons. All
      # of these are represented with this class.
      #
      # To create a push button, check box or radio button field, use the appropriate convenience
      # methods on the main Form instance (HexaPDF::Document#acro_form). By using those methods,
      # everything needed is automatically set up.
      #
      # == Type Specific Field Flags
      #
      # :no_toggle_to_off:: Only used with radio buttons fields. If this flag is set, one button
      #                     needs to be selected at all times. Otherwise, clicking on the selected
      #                     button deselects it.
      #
      # :radio:: If this flag is set, the field is a set of radio buttons. Otherwise it is a check
      #          box. Additionally, the :pushbutton flag needs to be clear.
      #
      # :push_button:: The field represents a pushbutton without a permanent value.
      #
      # :radios_in_unison:: A group of radio buttons with the same value for the on state will turn
      #                     on or off in unison.
      #
      # See: PDF1.7 s12.7.4.2
      class ButtonField < Field

        define_field :Opt, type: PDFArray, version: '1.4'

        # All inheritable dictionary fields for button fields.
        INHERITABLE_FIELDS = (superclass::INHERITABLE_FIELDS + [:Opt]).freeze

        # Updated list of field flags.
        FLAGS_BIT_MAPPING = superclass::FLAGS_BIT_MAPPING.merge(
          {
            no_toggle_to_off: 15,
            radio: 16,
            push_button: 17,
            radios_in_unison: 26,
          }
        ).freeze

        # Initializes the button field to be a push button.
        #
        # This method should only be called directly after creating a new button field because it
        # doesn't completely reset the object.
        def initialize_as_push_button
          self[:V] = nil
          flag(:push_button)
          unflag(:radio)
        end

        # Initializes the button field to be a check box.
        #
        # This method should only be called directly after creating a new button field because it
        # doesn't completely reset the object.
        def initialize_as_check_box
          self[:V] = :Off
          unflag(:push_button)
          unflag(:radio)
        end

        # Initializes the button field to be a radio button.
        #
        # This method should only be called directly after creating a new button field because it
        # doesn't completely reset the object.
        def initialize_as_radio_button
          self[:V] = :Off
          unflag(:push_button)
          flag(:radio)
        end

        # Returns +true+ if this button field represents a push button.
        def push_button?
          flagged?(:push_button)
        end

        # Returns +true+ if this button field represents a check box.
        def check_box?
          !push_button? && !flagged?(:radio)
        end

        # Returns +true+ if this button field represents a radio button set.
        def radio_button?
          !push_button? && flagged?(:radio)
        end

        # Returns the field value which depends on the concrete type.
        #
        # Push buttons:: They don't have a value, so +nil+ is always returned.
        #
        # Check boxes:: For check boxes that are in the on state the value +true+ is returned.
        #               Otherwise +false+ is returned.
        #
        # Radio buttons:: If no radio button is selected, +nil+ is returned. Otherwise the name of
        #                 the specific radio button that is selected is returned.
        def field_value
          normalized_field_value(:V)
        end

        # Sets the field value which depends on the concrete type.
        #
        # Push buttons:: Since push buttons don't store any value, the given value is ignored and
        #                nothing is stored for them (e.g a no-op).
        #
        # Check boxes:: Use +true+ for checking the box, i.e. toggling it to the on state, and
        #               +false+ for unchecking it.
        #
        # Radio buttons:: To turn all radio buttons off, provide +nil+ as value. Otherwise provide
        #                 the name of a radio button that should be turned on.
        def field_value=(value)
          normalized_field_value_set(:V, value)
        end

        # Returns the default field value.
        #
        # See: #field_value
        def default_field_value
          normalized_field_value(:DV)
        end

        # Sets the default field value.
        #
        # See: #field_value=
        def default_field_value=(value)
          normalized_field_value_set(:DV, value)
        end

        # Creates a widget for the button field.
        #
        # If +defaults+ is +true+, then default values will be set on the widget so that it uses a
        # default appearance.
        #
        # See: Field#create_widget, AppearanceGenerator button field methods
        def create_widget(page, defaults: true, **values)
          super(page, **values).tap do |widget|
            next unless defaults
            widget.border_style(color: 0, width: 1, style: (push_button? ? :beveled : :solid))
            widget.background_color(push_button? ? 0.5 : 255)
            widget.button_style(check_box? ? :check : :circle) unless push_button?
          end
        end

        # Creates appropriate appearance streams for all widgets.
        #
        # The created streams depend on the actual type of the button field. See AppearanceGenerator
        # for the details.
        def create_appearance_streams!
          each_widget do |widget|
            if check_box?
              AppearanceGenerator.new(widget).create_check_box_appearance_streams
            else
              raise HexaPDF::Error, "Radio buttons and push buttons not yet supported"
            end
          end
        end

        private

        # Returns the normalized field value for the given key which can be :V or :DV.
        #
        # See #field_value for details.
        def normalized_field_value(key)
          if push_button?
            nil
          elsif check_box?
            self[key] == :Yes
          elsif radio_button?
            self[key] == :Off ? nil : self[key]
          end
        end

        # Sets the key, either :V or :DV, to the value. The given normalized value is first
        # transformed into the expected value depending on the specific field type.
        #
        # See #field_value= for details.
        def normalized_field_value_set(key, value)
          return if push_button?
          self[key] = if check_box?
                        value == true ? :Yes : :Off
                      else
                        value.nil? ? :Off : value
                      end
        end

        def perform_validation #:nodoc:
          if field_type != :Btn
            yield("Field /FT of AcroForm button field has to be :Btn", true)
            self[:FT] = :Btn
          end

          super

          unless key?(:V)
            yield("Button field has no value set, defaulting to :Off", true)
            self[:V] = :Off
          end
        end

      end

    end
  end
end
