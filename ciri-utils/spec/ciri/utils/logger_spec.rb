require 'ciri/utils/logger'

RSpec.describe Ciri::Utils::Logger do
  let(:logger) do 
    Class.new do
      include Ciri::Utils::Logger

      def log_info(msg)
        info(msg)
      end
    end 
  end
  it "output null without setup" do
    expect(Ciri::Utils::Logger.global_logger).to be_nil
    expect do
      logger.log_info("hello")
    end
  end
end

