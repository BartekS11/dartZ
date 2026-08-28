module TournamentGroupNaming
  module_function

  def label(index)
    raise ArgumentError, "Group index must be non-negative" if index.negative?

    result = +""
    number = index

    loop do
      result.prepend(("A".ord + (number % 26)).chr)
      number = (number / 26) - 1
      break if number.negative?
    end

    result
  end
end
