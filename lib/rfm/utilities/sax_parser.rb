# From https://github.com/ohler55/ox
#gem 'ox', '1.8.5'
require 'stringio'
require 'ox'
require 'delegate'
require 'yaml'
require 'rfm'

# TODO: Find a way to eliminate the slf._new_element, since it leaves unnecessary baggage.
#       Pass it thru the parameters if you have to. Same with _new_element_attributes & _new_element_name
#       Create an object "new_element" with all these variables that you can use to pass thru the wormholes.


#####  CORE PATCHES  #####

module Saxable
  
  # Default callbacks for Saxable objects.
	def parent;	@parent || self end
  def start_el(name, attributes); self end
  def attribute(name,value); (self[name]=value) rescue nil end
  def end_el(value); true end
  
  def self.included(base) 
    attr_accessor :parent, :_new_element, :_new_element_name, :_new_element_attributes
    
    class << base
      
      attr_reader :_start_el_lambdas
      # This is a class method that allows shortcut config, kinda like 'before_filter'.
      # Helper shortcut method to be used in Saxable method at class level.
      # When this loads, it will define a more elaborate hidden start_el operation.
      # Lambdas needed to allow multiple start_el calls at Saxable object class level.
      def start_el(el, kls)
        @_start_el_lambdas ||= []
        
        # Disable this to use the non-lambda version.       
        @_start_el_lambdas << lambda do |slf|
          name = slf._new_element_name
          if (name.match(el) if el.is_a? Regexp) || name == el
            sub = Object.const_get(kls.to_s).new rescue kls.new
            sub.parent = slf
            sub.merge!(slf._new_element_attributes) rescue nil
            slf._new_element = sub
            yield(slf) if block_given?
            return slf._new_element
          else
            #return slf
            return nil
          end
        end
        
        # This is the actual instance-level start_el method.
        # The lambda version will call multiple lambdas,
        # whereas the single version will only call once.
        define_method :start_el do |name, attributes|
          # This is for the lambda version.
          self._new_element_name = name
          self._new_element_attributes = attributes
        #
        # This is the non-lambda one-shot only version.
        #
        #   if (name.match(el) if el.is_a? Regexp) || name == el
        #     self._new_element = Object.const_get(kls.to_s).new
        #     self._new_element.parent = self
        #     self._new_element_name = name
        #     yield(self) if block_given?
        #     return self._new_element
        #   else
        #     return self
        #     #return nil
        #   end
        #
        # This is the lambda version
        # 
          begin
          result = (self.class.instance_variable_get(:@_start_el_lambdas).compact.each{|e| @sub = e.call(self); break if @sub}; @sub || self)
          #self.class.instance_variable_get(:@_start_el).last.call(self, parent, name) rescue nil || self
          #puts "Successfully processed lambdas"
          result
          rescue
          #puts "Errors processing lambdas: #{$!}"
          self
          end
        #
        end
      end
      
      def end_el(el)
        define_method :end_el do |name|
          if (name.match(el) if el.is_a? Regexp) || name == el
            self._new_element_name = name
            yield(self) if block_given?
            return true
          end
        end
      end
      
      def element(*args)
      	options = args.last.is_a?(Hash) ? args.pop : {}
      	start_el args[0], options[:class] do |slf|
      		if slf.is_a? Hash
      			slf[slf._new_element_name] = slf._new_element
      		elsif slf.is_a? Array
      			slf << slf._new_element
      		end
      	end
      end
      
    end
  end

end # Saxable

class Hash
  include Saxable
end
class Array
  include Saxable
end


module SaxHandler
  
  def self.included(base)
    def base.build(io, initial_object)
  		handler = new(initial_object)
  		handler.run_parser(io)
  		handler.cursor
  	end
  end
  
  def initialize(initial_object)
  	init_element_buffer
    initial_object.parent = set_cursor initial_object
  end
	
	def cursor
		@cursor
	end
	
	def set_cursor(obj)
		@cursor = obj
	end
	
  def init_element_buffer
  	@element_buffer = {:name=>nil, :attr=>{}}
  end
  
  def send_element_buffer
  	if element_buffer?
	  	set_cursor cursor.start_el(@element_buffer[:name], @element_buffer[:attr])
	  	init_element_buffer
	  end
	end
	
	def element_buffer?
		@element_buffer[:name] && !@element_buffer[:name].empty?
	end

  # Add a node to an existing element.
	def _start_element(name, attributes=nil)
		send_element_buffer
		if attributes.nil?
			@element_buffer = {:name=>name, :attr=>{}}
		else
			set_cursor cursor.start_el(name, attributes)
		end
	end
	
	# Add attribute to existing element.
	def _attribute(name, value)
		@element_buffer[:attr].merge!({name=>value})
    #cursor.attribute(name,value)
	end
	
	# Add 'content' attribute to existing element.
	def _text(value)
		if !element_buffer?
			cursor.attribute('content', value)
		else
			@element_buffer[:attr].merge!({'content'=>value})
			send_element_buffer
		end
	end
	
	# Close out an existing element.
	def _end_element(value)
		send_element_buffer
		cursor.end_el(value) and set_cursor cursor.parent
	end
  
end # SaxHandler



#####  XML PARSERS - SAX HANDLERS  #####

class OxFmpSax < ::Ox::Sax

  include SaxHandler

  def run_parser(io)
		#Ox.sax_parse(self, io)
		File.open(io){|f| Ox.sax_parse self, f}
	end
	
  def start_element(name); _start_element(name.to_s.downcase);        end
  def end_element(name);   _end_element(name.to_s.downcase);          end
  def attr(name, value);   _attribute(name.to_s.downcase, value);     end
  def text(value);         _text(value);                              end
  
end # OxFmpSax



#####  USER MODELS  #####

class FmResultset < Hash
	element 'datasource', :class=>:Datasource
	element 'resultset', :class=>:Resultset
	element 'metadata', :class=>:Metadata
end

class Datasource < Hash
	# These both work.
	#element /.*/i, :class=>:Hash
  start_el /.*/i, :Hash
end

class Metadata < Array
	element 'field-definition', :class=>:Hash
end

class Resultset < Array
	element 'record', :class=>:Record
end

class Record < Hash
	start_el 'field', :Hash do |slf|
		slf.merge!(slf._new_element['name'] => slf._new_element['content'])
	end
end


# This gives a generic tree structure.
class Hash
  start_el /.*/i, :Hash do |slf|
    name, sub = slf._new_element_name, slf._new_element
    
    if slf[name].is_a? Array
      slf[name] << sub
    elsif slf.has_key? name
      tmp = slf[name]
      slf[name] = [tmp]
      slf[name] << sub
    else
      slf[name] = sub
    end
  end
  
  end_el /.*/i do |slf|
    parent, name = slf.parent, slf._new_element_name
    #parent[name]=nil if slf.empty?  # Use nil for empty nodes.
    #parent.delete(name) if slf.empty? # Delete empty nodes.
    parent[name] = slf.values[0] unless slf.size > 1 or parent.size > 2 # Reduce unnecessary nodes.
  end
  
end


#####  DATA  #####

FM = 'local_testing/resultset.xml'
FMP = 'local_testing/resultset_with_portals.xml'
XML = 'local_testing/data_fmpxmlresult.xml'
XMP = 'local_testing/data_with_portals_fmpxmlresult.xml'
LAY = 'local_testing/layout.xml'
XMD = 'local_testing/db_fmpxmlresult.xml'
FMB = 'local_testing/resultset_with_bad_data.xml'
SP = 'local_testing/SplashLayout.xml'

S = StringIO.new(%{
<top name="top01">
	<middle name="middle01" />
  <middle name="middle02">
    <bottom name="bottom01">bottom-text</bottom>
  </middle>
  <middle name="middle03">middle03-text</middle>
</top>
})

