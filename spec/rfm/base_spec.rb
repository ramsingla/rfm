require 'active_model_lint'

describe Rfm::Base do

	describe TestModel do
		it_should_behave_like "ActiveModel"
	end
			
	describe 'Test stubbing' do
		it "server has stubbed methods for db connections" do
			m = Memo.new(:memotext=>'test1').save!
		end
	end

	describe '.inherited' do
		it("adds new model class to Rfm::Factory@models"){Rfm::Factory.models.include?(Memo).should be_true}
		it("sets model @config with :parent and other config options") do
			Memo.config[:parent].should == 'parent_layout'
			Memo.get_config[:layout].should == 'testlay1'
		end
	end
	
	describe '.layout' do
		it("retrieves or creates layout object"){Memo.layout.name.should == 'testlay1'}
		it("layout object is a SubLayout"){Memo.layout.is_a?(Rfm::Layout::SubLayout)}
	end
	
	
	# In ruby 1.9, Memo.layout.should_receive attaches the fake #find method to the parent_layout,
	# not to the SubLayout that is attached to the Memo model.
	# Therefore I have to fake this spec by calling the action on the parent_layout.
	#
	# See base.rb and layout.rb for #find methods & debugging code.
	# Food for thought: http://stackoverflow.com/questions/12159536/is-there-a-less-intrusive-alternative-to-rspecs-should-receive
	#
	describe '.find' do
		it("passes parameters & options to Layout object") do
			#puts "Memo.layout-#{Memo.layout.object_id}"
			Memo.layout.should_receive(:find) do |*args|
				args[0].should == {:field_one=>'test'}
				args[1].should == {:max_records=>5}
			end
			case RUBY_VERSION
				when /^1\.8/; Memo.layout.find({:field_one=>'test'}, :max_records=>5)
				when /^1\.9/; Memo.parent_layout.find({:field_one=>'test'}, :max_records=>5)
			end
			#puts "Memo.parent_layout-#{Memo.parent_layout.object_id}"
		end
	end
	
	# describe '.create_from_instance'
	# 
	# describe '#initialize'
	# 
	# describe '#new_record?'
	# 
	# describe '#reload'
	# 
	# describe '#update_attributes'
	# 
	# describe '#update_attributes!'
	# 
	# describe '#save!'
	# 
	# describe '#save'
	# 
	# describe '#destroy'
	# 
	# describe '#save_if_not_modified'
	# 
	# describe '#callback_deadend'
	# 
	# describe '#create'
	# 
	# describe '#update'
	# 
	# describe '#merge_rfm_result'
	

	describe 'Functional Tests -' do
		
		it 'creates a new record with data' do
			subject_test = Memo.new(:memotext=>'test1')
			subject_test.memotext.should == 'test1'
			subject_test.class.should == Memo			
		end
		
		it 'adds more data to the record' do
			subject_test = Memo.new
			subject_test.memosubject = 'test2'
			subject_test.instance_variable_get(:@mods).size.should > 0
		end
		
		it 'saves the record' do
		  subject_test = Memo.new(:memosubject => 'test3')
			subject_test.server.should_receive(:connect) do |*args|
				args[2].should == '-new'
				args[3]['memosubject'].should == 'test3'
			end
			subject_test.save!
			subject_test[:memosubject].should == 'memotest4'	
		end
		
		it 'finds a record by id' do
			@Server.should_receive(:connect) do |*args|
				args[2].should == '-find'
				args[3]['-recid'].should == '12345'
			end
			resultset = Memo.find(12345)
			resultset[0][:memosubject].should == 'memotest4'
		end
		
		it 'uses #update_attributes! to modify data' do
		  subject_test = Memo.new
			subject_test.server.should_receive(:connect) do |*args|
				args[2].should == '-new'
				args[3]['memotext'].should == 'test3'
			end
			subject_test.update_attributes!(:memotext=>'test3')
			subject_test[:memosubject].should == 'memotest4'		
		end
		
		it 'searches for several records and loops thru to find one' do
			@Server.should_receive(:connect) do |*args|
				args[2].should == '-find'
				args[3][:memotext].should == 'test5'
			end
			resultset = Memo.find(:memotext=>'test5')
			resultset.find{|r| r.recordnumber == '399341'}.memotext.should == 'memotest7'
		end
		
		it 'destroys a record' do
			@Server.should_receive(:connect) do |*args|
				args[2].should == '-find'
				args[3]['-recid'].should == '12345'
			end
			resultset = Memo.find(12345)
			@Server.should_receive(:connect) do |*args|
				args[2].should == '-delete'
				args[3]['-recid'].should == '149535'
			end
			rec = resultset[0].destroy
			rec.frozen?().should be_true
			rec.memotext.should == 'memotest3'
		end
	end
  
  
end # Rfm::Base