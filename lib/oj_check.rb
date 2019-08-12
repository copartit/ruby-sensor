begin
  require 'oj'
rescue LoadError => e
  # OJ is not available in JRuby
  class Oj
    def Oj.dump(*args)
      args.first.to_json
    end

    def Oj.load(*args)
      JSON.parse args.first
    end
  end
end