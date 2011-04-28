$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'test/unit'
require 'mocha'
require 'data_translation'

class TC_DataTranslation < Test::Unit::TestCase
  def test_should_set_options
    dt = DataTranslation.new do |m|
      m.option :strict, true
    end

    assert_equal true, dt.options[:strict]
  end

  def test_should_link_string_key
    dt = DataTranslation.new do |m|
      m.link 'To', 'From'
    end

    assert_equal 'From', dt.mappings['To']
  end

  def test_should_link_to_lambda
    dt = DataTranslation.new do |m|
      m.link 'To', lambda {|source| 'Lambda'}
    end

    assert_equal 'Lambda', dt.mappings['To'].call({})
  end

  def test_should_link_to_block
    dt = DataTranslation.new do |m|
      m.link('To') {|source| 'Block'}
    end

    assert_equal 'Block', dt.mappings['To'].call({})
  end

  def test_should_set_static_value
    dt = DataTranslation.new do |m|
      m.set 'To', 'StaticFrom'
    end

    assert_equal 'StaticFrom', dt.static_values['To']
  end

  def test_should_transform_with_lambda
    dt = DataTranslation.new do |m|
      m.link 'Phone', lambda {|source| "(#{source['Area']}) #{source['PhoneNumber']}"}
    end

    source = {'Area' => 123, 'PhoneNumber' => '456-7890'}

    assert_equal '(123) 456-7890', dt.transform(source)['Phone']
  end

  def test_should_transform_with_block
    dt = DataTranslation.new do |m|
      m.link('Phone') {|source| "(#{source['Area']}) #{source['PhoneNumber']}"}
    end

    source = {'Area' => 123, 'PhoneNumber' => '456-7890'}

    assert_equal '(123) 456-7890', dt.transform(source)['Phone']
  end

  def test_should_transform_hash_source
    source = {'Key1' => 'Value1', 'Key2' => 'Value2'}

    dt = DataTranslation.new do |m|
      m.link 'Dest1', 'Key1'
      m.link 'Dest2', 'Key2'
    end

    results = dt.transform(source)

    assert_equal 'Value1', results['Dest1']
    assert_equal 'Value2', results['Dest2']
  end

  def test_should_transform_object_source
    source = mock('Key1' => 'Value1', 'Key2' => 'Value2')

    dt = DataTranslation.new do |m|
      m.link 'Dest1', 'Key1'
      m.link 'Dest2', 'Key2'
    end

    results = dt.transform(source)

    assert_equal 'Value1', results['Dest1']
    assert_equal 'Value2', results['Dest2']
  end

  # Ran into an issue when mapping US address data from a hash with
  # symbol keys. :zip was specified as a key, but because we checked
  # for object methods first, enumerable#zip was being called instead
  # of hash#[].
  def test_should_check_for_hashlike_object_before_source
    source = {:zip => '99999'}

    dt = DataTranslation.new do |m|
      m.link 'ZipCode', :zip
    end

    source.expects(:zip).never

    results = dt.transform(source)

    assert_equal '99999', results['ZipCode']
  end

  def test_should_call_processor_on_transform
    dt = DataTranslation.new do |m|
      m.link :name, 'Name'

      m.processor do |results|
        "Construct called with #{results[:name]}"
      end
    end

    assert_equal 'Construct called with value', dt.from_source({'Name' => 'value'})
  end

  def test_should_raise_exception_when_strict
    source = {}

    dt = DataTranslation.new {|m| m.link 'Key1', 'Value1'}

    assert_raises(DataTranslation::NonresponsiveSource) do
      dt.transform(source)
    end
  end

  def test_should_transform_with_static_value
    dt = DataTranslation.new {|m| m.set 'To', 'StaticValue'}

    assert_equal({'To' => 'StaticValue'}, dt.transform({}))
  end

  def test_should_not_raise_exception_when_not_strict
    source = {}

    dt = DataTranslation.new {|m| m.link 'Key1', 'Value1'}

    assert_nothing_raised do
      dt.transform(source, :strict => false)
    end
  end

  def test_should_update_dt
    dt = DataTranslation.new {|m| m.option :strict, true}
    assert dt.options[:strict]

    dt.update {|m| m.option :strict, false}
    assert ! dt.options[:strict]
  end
end