require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "NetSnmp" do
  it "should get single oid" do
    Net::SNMP::Session.open(:peername => "test.net-snmp.org", :community => "demopublic" ) do |sess|
      result = sess.get("sysDescr.0")
      result.varbinds.first.value.should eql("test.net-snmp.org")
    end
  end

  it "should get multiple oids" do
    Net::SNMP::Session.open(:peername => "test.net-snmp.org", :community => 'demopublic' ) do |sess|
      result = sess.get(["sysDescr.0", "sysName.0"])
      result.varbinds[0].value.should eql("test.net-snmp.org")
      result.varbinds[1].value.should eql("test.net-snmp.org")
    end
  end
  
  it "should get multiple requests asynchronously" do
    did_callback = false
    session = Net::SNMP::Session.open(:peername => 'test.net-snmp.org', :community => 'demopublic') do |s|
      s.get(["sysDescr.0", "sysContact.0"]) do |result|
        did_callback = true
        result.varbinds[0].value.should eql("test.net-snmp.org")
        result.varbinds[1].value.should match(/Coders/)
      end
    end
    Net::SNMP.dispatcher(false)
    did_callback.should be(true)
  end


  it "should get an oid asynchronously in a thread" do
    did_callback = false
    session = Net::SNMP::Session.open(:peername => 'test.net-snmp.org', :community => 'demopublic') do |s|
      s.get(["sysDescr.0", "sysContact.0"]) do |result|
        did_callback = true
        result.varbinds[0].value.should eql("test.net-snmp.org")
        result.varbinds[1].value.should match(/Coders/)
      end
    end
    Thread.new do
      while Net::SNMP.dispatcher == 0
        sleep 1
      end
    end.join
    did_callback.should be(true)
  end


  it "invalid oid should return error" do
    Net::SNMP::Session.open(:peername => "test.net-snmp.org", :community => "demopublic" ) do |sess|
      result = sess.get(["XXXsysDescr.0"])  #misspelled
      result.should be_error
    end
  end

  it "should get using snmpv3" do
    Net::SNMP::Session.open(:peername => 'test.net-snmp.org', :version => 3, :username => 'MD5User', :security_level => Net::SNMP::Constants::SNMP_SEC_LEVEL_AUTHNOPRIV, :auth_protocol => :md5, :password => 'The Net-SNMP Demo Password') do |sess|
      result = sess.get("sysDescr.0")
      result.varbinds.first.value.should eql('test.net-snmp.org')
    end
  end

  it "should get async using snmpv3" do
    did_callback = false
    Net::SNMP::Session.open(:peername => 'test.net-snmp.org', :version => 3, :username => 'MD5User',:security_level => Net::SNMP::Constants::SNMP_SEC_LEVEL_AUTHNOPRIV, :auth_protocol => :md5, :password => 'The Net-SNMP Demo Password') do |sess|
        sess.get(["sysDescr.0", "sysName.0"]) do |result|
          did_callback = true
          result.varbinds[0].value.should eql('test.net-snmp.org')
          result.varbinds[1].value.should eql('test.net-snmp.org')
          0
        end
        sleep(1)
        Net::SNMP.dispatcher()
        did_callback.should be(true)
    end
  end
  
  
  # To test sets, you have to have a local snmpd running with write permissions
  it "should set a value" do
    Net::SNMP::Session.open(:peername => '127.0.0.1', :version => 1) do |sess|
      result = sess.set([['sysContact.0', Net::SNMP::Constants::ASN_OCTET_STR, 'yomama']])
      result.varbinds.first.value.should match(/yomama/)
      result.should_not be_error
    end
  end
     
  #it "should set using snmpv3" do
  #  pending
  #  Net::SNMP::Session.open(:peername => '127.0.0.1', :version => 3, :username => 'myuser', :authprotocol => :sha1, :authkey => '0x1234', :privprotocol => :des, :privkey => '0x25252') do |sess|
  #    result = sess.set([["sysDescr.0", Net::SNMP::Constants::ASN_OCTET_STR, 'yomama']])
  #    result.varbinds.first.value.should match(/Darwin/)
  #  end
  #end
  
  it "should get next an array of oids" do
    Net::SNMP::Session.open(:peername => "test.net-snmp.org", :community => "demopublic" ) do |sess|
      result = sess.get_next(["sysUpTimeInstance.0"])
      result.varbinds.first.oid.oid.should eql("1.3.6.1.2.1.1.4.0")
      result.varbinds.first.value.should match(/Net-SNMP Coders/)
    end
  end
  

  it "should get_bulk_request" do
    Net::SNMP::Session.open(:peername => "test.net-snmp.org" , :version => '2c', :community => 'demopublic') do |sess|
      result = sess.get_bulk(["sysContact.0"], :max_repetitions => 10)
      result.varbinds.first.oid.name.should eql("1.3.6.1.2.1.1.5.0")
      result.varbinds.first.value.should eql("test.net-snmp.org")
    end
  end
  
  it "should get a table of values with explicit columns" do
    session = Net::SNMP::Session.open(:peername => "localhost", :version => '2c')
    table = session.get_table("ifTable", :columns => ["ifIndex", "ifDescr", "ifName"])
    table[0]['ifName'].should eql("lo0")
    table[1]['ifName'].should eql("gif0")
  end

  it "should get a table of values" do
    session = Net::SNMP::Session.open(:peername => "localhost", :version => '2c')
    table = session.get_table("ifEntry")
    table[0]['ifIndex'].should eql(1)
    table[1]['ifIndex'].should eql(2)
  end

  it "should get a table of values ipAddrEntry" do
    puts Net::SNMP::Constants::ASN_IPADDRESS
    session = Net::SNMP::Session.open(:peername => "localhost", :version => '2c')
    table = session.get_table("ipAddrEntry")
    puts table.inspect
    table[0]['ipAdEntAddr'].should eql('127.0.0.1')
    table[1]['ipAdEntNetMask'].should eql('255.255.255.0')
  end

  it "should get a table of values ifXEntry" do
    puts Net::SNMP::Constants::ASN_IPADDRESS
    session = Net::SNMP::Session.open(:peername => "localhost", :version => '2c')
    table = session.get_table("ifXEntry")
    puts table.inspect
    table[0]['ifName'].should eql('lo0')
    table[3]['ifHighSpeed'].should eql(1000)
  end

  it "should translate an oid" do

    oid = Net::SNMP::OID.new("ifDescr.1")
    oid.node.label.should eql("ifDescr")
    oid.label.should eql("ifDescr.1")
    oid.index.should eql("1")
  end



  it "should work in event_machine" do
    require 'eventmachine'
    did_callback = false
    EM.run do
      tickloop = EM.tick_loop do
        Net::SNMP.dispatcher
      end

      session = Net::SNMP::Session.open(:peername => 'test.net-snmp.org', :community => 'demopublic') do |s|
        s.get("sysDescr.0") do |result|
          did_callback = true
          result.varbinds[0].value.should eql("test.net-snmp.org")
        end
        
      end

      EM.add_timer(3) do
        did_callback.should be_true
        EM.stop
      end
    end
  end

  it "should work in a fiber" do
    require 'eventmachine'
    did_callback = false
    EM.run do
      tickloop = EM.tick_loop do
        Net::SNMP.dispatcher
      end

      Fiber.new {
        session = Net::SNMP::Session.open(:peername => 'test.net-snmp.org', :community => 'demopublic') do |s|
          s.get("sysDescr.0") do |result|
            did_callback = true
            result.varbinds[0].value.should eql("test.net-snmp.org")
          end

        end

        EM.add_timer(3) do
          did_callback.should eql(true)
          EM.stop
        end
      }.resume
    end
  end



  it "get should work in a fiber with synchronous calling style" do
    require 'eventmachine'
    did_callback = false
    EM.run do
      Fiber.new {

        EM.tick_loop do

          Net::SNMP.dispatcher
        end
        sleep 1
        session = Net::SNMP::Session.open(:peername => 'test.net-snmp.org', :community => 'demopublic')
        result = session.get("sysDescr.0")
        result.varbinds[0].value.should eql("test.net-snmp.org")
      }.resume
      EM.stop
    end
  end


end
