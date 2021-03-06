require 'rexml/parsers/sax2parser'
require 'rexml/sax2listener'
require 'rexml/document'
require 'active_support/core_ext/object/blank'
require 'stringio'

# = XmlMini REXML implementation using the SAX2 parser
module ActiveSupport
  module XmlMini_REXMLSAX
    extend self

    # Class that will build the hash while the XML document
    # is being parsed using streaming events.
    class HashBuilder
    	include REXML::SAX2Listener

      CONTENT_KEY   = '__content__'.freeze
      HASH_SIZE_KEY = '__hash_size__'.freeze

      attr_reader :hash

      def current_hash
        @hash_stack.last
      end

      def start_document
        @hash = {}
        @hash_stack = [@hash]
      end

      def end_document
        raise "Parse stack not empty!" if @hash_stack.size > 1
      end

      def error(error_message)
        raise error_message
      end

      def start_element(uri, name, qname, attrs = [])
      	#puts "START_ELEMENT #{name}"
      	#y attrs
        new_hash = { CONTENT_KEY => '' }.merge(Hash[attrs])
        new_hash[HASH_SIZE_KEY] = new_hash.size + 1

        case current_hash[name]
          when Array then current_hash[name] << new_hash
          when Hash  then current_hash[name] = [current_hash[name], new_hash]
          when nil   then current_hash[name] = new_hash
        end

        @hash_stack.push(new_hash)
      end

      def end_element(uri, name, qname)
        if current_hash.length > current_hash.delete(HASH_SIZE_KEY) && current_hash[CONTENT_KEY].blank? || current_hash[CONTENT_KEY] == ''
          current_hash.delete(CONTENT_KEY)
        end
        @hash_stack.pop
      end

      def characters(string)
      	return unless string and current_hash[CONTENT_KEY]
      	#puts "CHARACTERS #{string}"
        current_hash[CONTENT_KEY] << string
      end

      alias_method :cdata, :characters
    end

    attr_accessor :document_class
    self.document_class = HashBuilder

    def parse(data)
      document = self.document_class.new
      parser = REXML::Parsers::SAX2Parser.new(data)
      parser.listen(document)
      parser.parse
      document.hash
    end
  end
end
