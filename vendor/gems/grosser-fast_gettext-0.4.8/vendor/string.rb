#! /usr/bin/ruby
=begin
  string.rb - Extension for String.

  Copyright (C) 2005,2006 Masao Mutoh

  You may redistribute it and/or modify it under the same
  license terms as Ruby.
=end

# Extension for String class. This feature is included in Ruby 1.9 or later.
begin
  raise unless ("a %{x}" % {:x=>'b'}) == 'a b'
rescue ArgumentError
  class String
    alias :_fast_gettext_old_format_m :% # :nodoc:

    PERCENT_MATCH_RE = Regexp.union(
      /%%/,
      /%\{(\w+)\}/,
      /%<(\w+)>(.*?\d*\.?\d*[bBdiouxXeEfgGcps])/
    )

    # call-seq:
    #  %(hash)
    #
    #  Default: "%s, %s" % ["Masao", "Mutoh"]
    #  Extended:
    #     "%{firstname}, %{lastname}" % {:firstname=>"Masao",:lastname=>"Mutoh"} == "Masao Mutoh"
    #     with field type such as d(decimal), f(float), ...
    #     "%<age>d, %<weight>.1f" % {:age => 10, :weight => 43.4} == "10 43.4"
    # This is the recommanded way for Ruby-GetText
    # because the translators can understand the meanings of the msgids easily.
    def %(args)
      if args.kind_of? Hash
        ret = dup
        ret.gsub!(PERCENT_MATCH_RE) do |match|
          if match == '%%'
            '%'
          elsif $1
            key = $1.to_sym
            args.has_key?(key) ? args[key] : match
          elsif $2
            key = $2.to_sym
            args.has_key?(key) ? sprintf("%#{$3}", args[key]) : match
          end
        end
      else
        ret = gsub(/%([{<])/, '%%\1')
        ret._fast_gettext_old_format_m(args)
      end
    end
  end
end
