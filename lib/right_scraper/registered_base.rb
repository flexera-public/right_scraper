#--
# Copyright: Copyright (c) 2013 RightScale, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

# ancestor
require 'right_scraper'

module RightScraper

  # Abstract base class for a registered type.
  #
  # Example:
  #
  #  class Foo < RegisteredBase
  #    ...
  #
  #    register_self(:foo)
  #  end
  class RegisteredBase

    # exceptions
    class RegisteredTypeError < ::StandardError; end

    # Provides a module from which a specific set of registered types is derived
    # (for registration, autoloading, etc.). It is not necessary for all types
    # of the set to be declared within the scope of that module, but doing so
    # will simplify registration and query.
    # 
    # @return [Module] module or base class in common
    def self.registration_module
      raise NotImplementedError
    end

    # @return [Hash] mapping of registered types to classes or empty
    def self.registered_types
      unless types = registration_module.instance_variable_get(:@registered_types)
        types = {}
        registration_module.instance_variable_set(:@registered_types, types)
      end
      types
    end

    # Registers self.
    #
    # @param [Symbol] type to register or nil
    #
    # @return [TrueClass] always true
    def self.register_self(type = nil)
      # automatically determine registered type from self, if necessary.
      unless type
        class_name = self.name
        default_module_name = registration_module.name + '::'
        if class_name.start_with?(default_module_name)
          subname = class_name[default_module_name.length..-1]
          class_name = subname unless subname.index('::')
        end
        type = class_name.
          gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          downcase
      end
      self.register_class(type, self)
      true
    end

    # Registers given class.
    #
    # @param [Symbol|String] type to register
    # @param [Class] clazz to register
    #
    # @return [TrueClass] always true
    def self.register_class(type, clazz)
      raise ::ArgumentError, 'clazz is required' unless clazz
      raise ::ArgumentError, 'type is required' unless type
      registered_types[type.to_s] = clazz
      true
    end

    # Queries the implementation class for a registered type.
    #
    # @param [Symbol|String] type for query
    #
    # @return [RightScraper::Repositories::Base] repository created
    def self.query_registered_type(type)
      raise ::ArgumentError, 'type is required' unless type

      # a quick-out when given a known registerd type. autoloading types makes
      # things more interesting for unknown types.
      type = type.to_s
      unless clazz = registered_types[type]
        # default module implementations may be auto-loading so try default
        # namespace before giving up (assumes snake-case types). types
        # declared in a different namespace can also be autoloaded if fully
        # qualified using forward slashes (require-style).
        class_path = type.split('/').map do |snake_case|
          camel_case = snake_case.split('_').map{ |e| e.capitalize }.join
        end

        # assume no registered types at global scope and insert registration
        # module before any simple name.
        if class_path.size == 1
          class_path = registration_module.name.split('::') + class_path
        end

        # walk class path from global scope because const_get doesn't understand
        # the '::' notation. autoloading is usually setup to support walking
        # from the base module.
        last_item = nil
        begin
          parent_item = ::Object
          class_path.each do |item|
            last_item = parent_item.const_get(item)
            parent_item = last_item
          end
        rescue ::NameError => e
          if e.message =~ /uninitialized constant/
            last_item = nil
          else
            raise
          end
        end
        if last_item
          # type still needs to successfully self-register upon definition.
          unless clazz = registered_types[type]
            raise RegisteredTypeError, "Discovered type did not register itself properly: #{type.inspect} => #{last_item.inspect}"
          end
        else
          raise RegisteredTypeError, "Unknown registered type: #{type.inspect}"
        end
      end
      clazz
    end
  end
end
