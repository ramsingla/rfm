# This data must load before Rfm.
RFM_CONFIG = {
	:host=>'host1',
	:group1=>{
		:database=>'db1'
	},
	:group2=>{
		:database=>'db2'
	},
	:base_test=>{
		:database=>'testdb1',
		:layout=>'testlay1'
	}
}

# Begin loading Rfm
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'yaml'
require 'rfm'
#require 'rfm/base'  # Use this to test if base.rb breaks anything, or if it's absence breaks anything.
require 'spec'
require 'spec/autorun'

Spec::Runner.configure do |config|
	# 	config.before(:all) do
	# 		Rfm::Server.class_eval{stub!(:connect)}
	# 	end
end

def rescue_from(&block)
  exception = nil
  begin
    yield
  rescue StandardError => e
    exception = e
  end
  exception
end
