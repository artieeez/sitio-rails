class Cpf
  class Invalid < StandardError; end

  def self.normalize(value)
    return nil if value.blank?

    digits = value.to_s.gsub(/\D/, "")
    raise Invalid, "CPF must have 11 digits" unless digits.length == 11
    raise Invalid, "CPF is invalid" unless valid_digits?(digits)

    digits
  end

  def self.format(digits)
    return nil if digits.blank?

    "#{digits[0, 3]}.#{digits[3, 3]}.#{digits[6, 3]}-#{digits[9, 2]}"
  end

  def self.valid_digits?(digits)
    return false if digits.length != 11
    return false if digits.chars.uniq.length == 1

    check_digit(digits, 9) == digits[9].to_i && check_digit(digits, 10) == digits[10].to_i
  end

  def self.check_digit(digits, length)
    sum = 0
    length.times do |index|
      sum += digits[index].to_i * (length + 1 - index)
    end
    remainder = (sum * 10) % 11
    if remainder == 10
      0
    else
      remainder
    end
  end
  private_class_method :check_digit
end
