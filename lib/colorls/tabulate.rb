module ColorLS

  class Tabulate
    def initialize(array)
      @given = array
      @widths = @given.map(&:length)
    end

    def layout(max_widths)
      # horizontal

      [@given]
    end
  end
end
