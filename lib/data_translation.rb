# Simple class to provide an easy way to map and transform data.
#
# ==Example Usage
#
# agent = DataTranslation.new do |m|
#   m.option :strict, true
#
#   m.set  'source_id', 1
#
#   m.link 'login', 'Username'
#   m.link 'first_name', 'FirstName'
#   m.link 'last_name', 'LastName'
#   m.link 'phone_number', lambda {|source| "(#{source['Area']}) #{source['Phone']}"}
#
#   m.processor do |values|
#     Agent.find_or_create_by_source_id_and_login(values['source_id'], values['login'])
#   end
# end
#
# source = {'Username'  => 'spatterson', 
#           'FirstName' => 'Scott', 
#           'LastName'  => 'Patterson', 
#           'Area'      => '123',
#           'Phone'     => '456-7890'}
#
# results = agent.transform(source)
#
# puts results.inspect  # => {"phone_number" => "(123) 456-7890", 
#                       #     "last_name"    => "Patterson", 
#                       #     "login"        => "spatterson", 
#                       #     "first_name"   => "Scott"
#                       #     "source_id"    => 1}
#
# new_object = agent.from_source(source)

class DataTranslation
  VERSION = '1.0.0'
  
  attr_reader :mappings, :static_values, :options
  
  # Includes DataTranslation::Destination in the specified class (klass). If a name
  # is given, yields and returns a DataTranslation for that name. i.e.
  # DataTranslation.destination(PlainClass, :source_name) {|dtm| dtm.link ...}
  def self.destination(klass, name = nil)
    # No need to include ourself again if we've already extended the class
    klass.class_eval("include(Destination)") unless klass.include?(Destination)
    
    if name
      klass.data_translation_map(name) {|dtm| yield dtm} if block_given?
      klass.data_translation_map(name)
    end
  end
  
  # Constructor, yields self to allow for block-based configuration.
  #   Defaults: strict = true
  def initialize # yields self
    @mappings      = {}
    @static_values = {}
    @options       = {:strict => true}
    @processor     = nil
    
    yield self if block_given?
  end
  
  # Sets the option with name to value.
  # Current options are:
  #   :strict = boolean; true will raise a NonresponsiveSource exception if the source
  #                      object does not respond to a mapping.
  #                      false ignores non-existant fields in the source object.
  def option(name, value)
    @options[name.to_sym] = value
  end

  # Sets a specified to field to value during transformation without regard to the source object. 
  # If you wish to link to source object data or use a lambda/block, use #link instead. 
  # to may be any object that can be stored as a Hash key.
  #
  # set :field_name, 'Static value'
  def set(to, value)
    @static_values[to] = value
  end
  
  # Links a destination field to a source method, element, or lambda.
  # to may be a string, symbol, or any object that can be used as a hash key.
  # If from is a lambda, called with one argument (the source passed to #transform).
  # Alternatively, can be called with a block instead of a lambda or from.
  #
  # link 'field_name', 'FieldName'
  # link :field_name, 'FieldName'
  # link :field_name, lambda {|source| source...}
  # link(:field_name) {|source| source...}
  def link(to, from = nil, &block)
    @mappings[to] = block.nil? ? from : block
  end
  
  # If called without a block, returns the current block. If called with a block,
  # sets the block that will be run with the results from #transform when #from_source
  # is called. The results of the transformation will be passed as the only argument.
  def processor(&block) # |transform_results|
    if block_given?
      @processor = block
    else
      @processor
    end
  end
  
  # Removes the currently defined processor, if any.
  def remove_processor
    @processor = nil
  end
  
  # Given a source object, returns a new hash with elements as determined by the 
  # current mapping. Mapping is set by one or more calls to #link. Options passed
  # to this method override the instance options. See #option for a list of options.
  # #link values will override #set values.
  def transform(source, options = {})
    options = @options.merge(options)
    
    apply_static_values(options).merge(apply_mappings(source, options))
  end
  
  # Given a source object, returns the results of #transform if no processor is defined
  # or the results of calling the processor block as defined by #processor.
  def from_source(source, options = {})
    results = transform(source, options)
    
    @processor.nil? ? results : @processor.call(results)
  end
  
  # Yields the mapping object so that options and links can be applied within a block.
  def update # yields self
    yield self
  end
  
  private
    
    # Given a source object and optional options hash, iterates over the current mappings 
    # (defined by #link) and returns a Hash of results.
    def apply_mappings(source, options = {})
      results = {}
      
      @mappings.each do |to, from|
        if from.respond_to? :call                # Lambda
          results[to] = from.call(source)
        elsif source.respond_to?(from.to_sym)    # Source Object
          results[to] = source.send(from.to_sym)
        elsif source.respond_to?(:[]) &&         # Hash-like Object
              (options[:strict] == false || source.has_key?(from))
          results[to] = source[from]
        else
          raise NonresponsiveSource, 
                "#{to}: #{source.class} does not respond to '#{from}' (#{from.class})"
        end
      end
      
      results
    end
    
    # Returns a hash of static values as defined by the #set method.
    def apply_static_values(options = {})
      @static_values # currently nothing to do to process, so we just pass it along for now.
    end
    
  ## Mixins ##
  
  # Provides helper methods for mapping and creating new objects from source data.
  #
  # In addition to including the mixin DataTranslation::Destination, a class method
  # called initialize_from_data_translation may optionally be provided that takes a hash
  # of translated data. If not present, the from_source will pass a hash of the 
  # transformation results to the new method.
  # 
  # Multiple mappings may be given for a single destination by using different names
  # for them. e.g. :source1 and :source2 as names yield different mappings.
  #
  # ==Example Usage
  #
  # class DestinationObject
  #   include DataTranslation::Destination
  #
  #   def self.initialize_from_data_translation(results)
  #   end
  # end
  #
  # DestinationObject.data_translation_map(:source_name) do |dtm|
  #   dtm.link 'first_key', 'Key1'
  # end
  # 
  # source = {'Key1' => 'Value1'}
  #
  # new_object = DestinationObject.from_source(:source_name, source)
  
  module Destination
    # Provides our class methods when included.
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      # Given the name of a mapping and a source object, transforms the source object
      # based upon the specified mapping and attempts to process the results using one of
      # several methods that are checked in the following order:
      # *  DataTranslation#processor defined block
      # *  Destination class initialize_from_data_translation
      # *  Destination class default constructor 
      # with the resulting hash if that method is not defined.
      # Returns an instance of the class based upon the source data.
      def from_source(name, source)        
        dtm = data_translation_map(name)
                
        if dtm.processor
          dtm.from_source(source)
        elsif respond_to?(:initialize_from_data_translation)
          initialize_from_data_translation(dtm.transform(source))
        else
          new(dtm.transform(source))
        end
      end
      
      # Given the name of a mapping, returns the existing mapping with that name
      # or creates one with that name and yields it if a block is given. 
      # Returns the DataTranslation mapping for the specified name.
      def data_translation_map(name) # yields DataTranslation
        @dt_mappings       ||= {}
        @dt_mappings[name] ||= DataTranslation.new
        
        yield @dt_mappings[name] if block_given?
        
        @dt_mappings[name]
      end
      
      # Returns a string containing a sample DataTranslation mapping for this instance
      # based upon actual column names (assuming this is an ActiveRecord class or
      # another class that provides an array of string column/attribute names via a 
      # column_names class method).
      #
      # Passing the name argument sets it as the translation name in the output.
      def stub_data_translation_from_column_names(name = 'name')
        map = ["DataTranslation.destination(#{self}, :#{name}) do |dtm|"]
        
        column_names.each do |col|
          map << "\tdtm.link :#{col}, :#{col}"
        end
        
        map << "end"
        
        map.join("\n")
      end
    end
  end
  
  
  ## Exceptions ##
  
  # Raised when the source object does not respond to the from link.
  class NonresponsiveSource < Exception
  end 
end