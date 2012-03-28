require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Dynamoid::Persistence" do

  let(:document_class) { Class.new.send :include, Dynamoid::Document }

  before do
    Random.stubs(:rand).with(Dynamoid::Config.partition_size).returns(0)
    @address = Address.new
  end

  context 'without AWS keys' do
    unless ENV['ACCESS_KEY'] && ENV['SECRET_KEY']
      before do
        Dynamoid::Adapter.delete_table(Address.table_name) if Dynamoid::Adapter.list_tables.include?(Address.table_name)
      end
    
      it 'creates a table' do
        Address.create_table(Address.table_name)

        Dynamoid::Adapter.list_tables.should include 'dynamoid_tests_addresses'
      end

      it 'checks if a table already exists' do
        Address.create_table(Address.table_name)

        Address.table_exists?(Address.table_name).should be_true
        Address.table_exists?('crazytable').should be_false
      end
    end
  end
  
  it 'assigns itself an id on save' do
    @address.save
    
    Dynamoid::Adapter.read("dynamoid_tests_addresses", @address.id)[:id].should == @address.id
  end
  
  it 'assigns itself an id on save only if it does not have one' do
    @address.id = 'test123'
    @address.save
    
    Dynamoid::Adapter.read("dynamoid_tests_addresses", 'test123').should_not be_empty
  end
  
  it 'has a table name' do
    Address.table_name.should == 'dynamoid_tests_addresses'
  end
    
  it 'saves indexes along with itself' do
    @user = User.new(:name => 'Josh')
    
    @user.expects(:save_indexes).once.returns(true)
    @user.save
  end
  
  it 'deletes an item completely' do
    @user = User.create(:name => 'Josh')
    @user.destroy
    
    Dynamoid::Adapter.read("dynamoid_tests_users", @user.id).should be_nil
  end
  
  it 'keeps string attributes as strings' do
    @user = User.new(:name => 'Josh')
    @user.send(:dump)[:name].should == 'Josh'
  end
  
  it 'dumps datetime attributes' do
    @user = User.create(:name => 'Josh')
    @user.send(:dump)[:name].should == 'Josh'
  end
  
  it 'dumps integer attributes' do
    @subscription = Subscription.create(:length => 10)
    @subscription.send(:dump)[:length].should == 10
  end
  
  it 'dumps set attributes' do
    @subscription = Subscription.create(:length => 10)
    @magazine = @subscription.magazine.create
    
    @subscription.send(:dump)[:magazine_ids].should == Set[@magazine.id]
  end

  it 'handles nil attributes properly' do
    Address.undump(nil).should be_a(Hash)
  end

  it 'dumps and undump a serialized field' do
    @address.options = (hash = {:x => [1, 2], "foobar" => 3.14})
    Address.undump(@address.send(:dump))[:options].should == hash
  end

  it 'loads a hash into a serialized field' do
    hash = {foo: :bar}
    Address.new(options: hash).options.should == hash
  end
  
  it 'loads attributes from a hash' do
    @time = DateTime.now
    @hash = {:name => 'Josh', :created_at => @time.to_f}
    
    User.undump(@hash)[:name].should == 'Josh'
    User.undump(@hash)[:created_at].to_f == @time.to_f
  end

  it 'runs the before_create callback only once' do
    document_class.before_create { doing_before_create }

    document_class.any_instance.expects(:doing_before_create)

    document_class.create
  end

  it 'runs after save callbacks when doing #create' do
    document_class.after_create { doing_after_create }

    document_class.any_instance.expects(:doing_after_create)

    document_class.create
  end

  it 'runs after save callbacks when doing #save' do
    document_class.after_create { doing_after_create }

    document_class.any_instance.expects(:doing_after_create)

    document_class.new.save
  end
  
  it 'tracks previous changes on save or update' do
    @address.city = 'Chicago'
    @address.save
    
    @address.city = 'San Francisco'
    @address.save
    
    @address.city_was.should == 'Chicago'
  end

end
