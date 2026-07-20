require "test_helper"

class CpfTest < ActiveSupport::TestCase
  test "normalizes a valid CPF" do
    assert_equal "52998224725", Cpf.normalize("529.982.247-25")
  end

  test "rejects an invalid CPF" do
    assert_raises(Cpf::Invalid) { Cpf.normalize("111.111.111-11") }
  end

  test "formats digits for display" do
    assert_equal "529.982.247-25", Cpf.format("52998224725")
  end
end
