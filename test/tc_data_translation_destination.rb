$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'test/unit'
require 'mocha'
require 'data_translation'

## Test Objects

class TestObject
  include DataTranslation::Destination

  attr_reader :name, :options

  def self.initialize_from_data_translation(params)
    TestObject.new(params.delete('name'), params)
  end

  def initialize(name, options = {})
    @name    = name
    @options = options
  end

  def self.column_names
    ['id', 'first_name', 'last_name']
  end
end

class PlainObject
  attr_reader :options

  def initialize(options)
    @options = options
  end
end


class TC_DataTranslationDestination < Test::Unit::TestCase
  def setup
    @source = {'Name' => 'test object', 'Key1' => 'Value1', 'Key2' => 'Value2'}
  end

  def test_should_create_map(klass = TestObject)
    klass.data_translation_map(:hash_source) do |m|
      m.option :strict, true

      m.link 'name',       'Name'
      m.link 'first_key',  'Key1'
      m.link 'second_key', 'Key2'

      m.remove_processor
      yield m if block_given?
    end

    assert klass.data_translation_map(:hash_source).options[:strict]
    assert_equal 'Name', klass.data_translation_map(:hash_source).mappings['name']
    assert_equal 'Key1', klass.data_translation_map(:hash_source).mappings['first_key']
    assert_equal 'Key2', klass.data_translation_map(:hash_source).mappings['second_key']
  end

  def test_should_create_new_object_using_custom_constructor
    test_should_create_map

    to = TestObject.from_source(:hash_source, @source)

    assert_equal 'test object', to.name
    assert_equal 'Value1', to.options['first_key']
    assert_equal 'Value2', to.options['second_key']
  end

  def test_should_create_new_object_using_default_constructor
    DataTranslation.destination(PlainObject)
    test_should_create_map(PlainObject)

    to = PlainObject.from_source(:hash_source, @source)

    assert_equal 'test object', to.options['name']
    assert_equal 'Value1', to.options['first_key']
    assert_equal 'Value2', to.options['second_key']
  end

  def test_should_call_processor_if_given
    DataTranslation.destination(PlainObject)
    test_should_create_map(PlainObject) do |m|
      m.processor do |results, source|
        results.values.sort # for consistency we sort our values
      end
    end

    assert_equal ['Value1', 'Value2', 'test object'],
                 PlainObject.from_source(:hash_source, @source)
  end

  def test_should_return_mapping_for_name
    test_should_create_map

    assert TestObject.data_translation_map(:hash_source).kind_of?(DataTranslation)
  end

  def test_should_make_class_destination
    DataTranslation.destination(PlainObject)

    assert PlainObject.include?(DataTranslation::Destination)
  end

  def test_should_make_class_destination_and_yield
    DataTranslation.destination(PlainObject, :hash_source) do |dtm|
      dtm.link 'first_key', 'Key1'
    end

    assert_equal 'Key1', PlainObject.data_translation_map(:hash_source).mappings['first_key']
    assert PlainObject.respond_to?(:from_source)
  end

  def test_should_stub_map_from_column_names
    assert_equal "DataTranslation.destination(TestObject, :my_name) do |dtm|\n\tdtm.link :id, :id\n\tdtm.link :first_name, :first_name\n\tdtm.link :last_name, :last_name\nend",
                 TestObject.stub_data_translation_from_column_names(:my_name)
  end

  def test_should_not_include_destination_multiple_times
    DataTranslation::Destination.expects(:included).never

    DataTranslation.destination(TestObject)
  end
end