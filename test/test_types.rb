require 'test/unit'
$: << File.join(File.dirname(__FILE__),'../lib')
require 'jsonrpc2/types'

InterfaceTestContainer = Struct.new("InterfaceTestContainer", :types)

class TestTypes < Test::Unit::TestCase
  def setup
    complex = JSONRPC2::JsonObjectType.new('Complex1',[])
    complex.string('field1', 'Field 1')

    container = JSONRPC2::JsonObjectType.new('Container', [])
    container.field('complex', 'Complex', 'Complex field')

    container2 = JSONRPC2::JsonObjectType.new('Container2', [])
    container2.field('complex', 'Array[Complex]', 'Complex fields')
    @interface = InterfaceTestContainer.new('Complex' => complex, 'Container' => container, 'Container2' => container2)
  end
  def test_complex_types
    assert(JSONRPC2::Types.valid?(@interface, 'Complex', {'field1' => "Foo"}))
    assert(! JSONRPC2::Types.valid?(@interface, 'Complex', {'field1' => 3}))

    assert(JSONRPC2::Types.valid?(@interface, 'Container', { 'complex' => { 'field1' => 'Foo' } }))

    assert(JSONRPC2::Types.valid?(@interface, 'Container2', { 'complex' => [{ 'field1' => 'Foo' }] }))
    assert(!JSONRPC2::Types.valid?(@interface, 'Container2', { 'complex' => [{ 'field1' => false }] }))
  end
end
