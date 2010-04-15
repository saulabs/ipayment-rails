require 'spec_helper'

describe Ipayment do
  
  class Rails
    class Env
      def self.development?
        false
      end
    end
    def self.env
      Env
    end
  end
  
  describe 'Connection' do
    it "should initialise a driver when initialized" do
      factory = mock('factory')
      factory.should_receive(:create_rpc_driver).once.and_return(driver = mock('driver'))
      SOAP::WSDLDriverFactory.should_receive(:new).and_return(factory)
      connection = Ipayment::Connection.new
      connection.driver.should == driver
    end
  end

  describe 'Helpers module' do
    class MyViewClass
      include Ipayment::Helpers
    end

    before(:each) do
      @ipayment = mock('ipayment', :generate_session_id => '1234')
      @view = MyViewClass.new
      @view.stub!(:concat).and_return('concatinated')
      @view.stub!(:hidden_field_tag).and_return('hidden_field_tag')
      @view.stub!(:form_tag).and_yield(@view).and_return('form_tag')
    end

    it "should generate session id for the ipayment" do
      @ipayment.should_receive(:generate_session_id).with({
        :success_url => 'success_url', :error_url => 'success_url',
        :transaction_type => 'auth'
      }).and_return('1234')
      @view.form_for_ipayment_auth(@ipayment, { :success_url => 'success_url',
        :error_url => 'success_url' }) {}
    end

    it "should generate a form" do
      @view.should_receive(:form_tag).with(
        "https://ipayment.de/merchant/#{Ipayment::Config.get['accountId']}/processor/2.0/",
        { :class => 'cc-form' })
      @view.form_for_ipayment_auth(@ipayment, { :success_url => 'success_url',
        :error_url => 'success_url', :class => 'cc-form' }) {}
    end

    it "should generate 3 hidden input fields" do
      # FIXME: we should test if the hidden inputs get the right arguments, no idea how to implemtn that with rspec
      @view.should_receive(:hidden_field_tag).exactly(4).times.and_return('hidden_field_tag')
      @view.form_for_ipayment_auth(@ipayment, { :success_url => 'success_url',
        :error_url => 'success_url', :callback_url => 'callback_url',
        :from_datastorage_id => '987', :class => 'cc-form' }) {}
    end
  end

  describe 'Controller module' do
    class MyPaymentsController
      attr_accessor :request
      include Ipayment::Controller
    end

    before(:each) do
      @controller = MyPaymentsController.new
    end

    describe "validate_ipayment_request_source" do
      it "should be valid when request is post and ip is correct" do
        request = mock('request')
        request.should_receive(:env).and_return({ 'REMOTE_ADDR' => '212.227.34.218' })
        request.should_receive(:post?).and_return(true)
        @controller.request = request
        @controller.send(:validate_ipayment_request_source).should be_true
      end

      it "should be invalid when request is not post and ip is correct" do
        request = mock('request')
        request.should_receive(:post?).and_return(false)
        @controller.request = request
        @controller.send(:validate_ipayment_request_source).should be_false
      end

      it "should be invalid when request is post and ip is incorrect" do
        request = mock('request')
        request.should_receive(:env).and_return({ 'REMOTE_ADDR' => '212.227.34.100' })
        request.should_receive(:post?).and_return(true)
        @controller.request = request
        @controller.send(:validate_ipayment_request_source).should be_false
      end
    end

    describe "handle_ipayment_callback" do

      it "should validate request source" do
        @controller.should_receive(:validate_ipayment_request_source).and_return(false)
        @controller.send(:handle_ipayment_callback) { |x| }
      end

      it "should yield nil if request source is not valid" do
        @controller.stub!(:validate_ipayment_request_source).and_return(false)
        @controller.send(:handle_ipayment_callback) do |payment|
          payment.should be_nil
        end
      end

      it "parse Ipayment::Payment form params" do
        @controller.stub!(:validate_ipayment_request_source).and_return(true)
        @controller.should_receive(:params).and_return(params = { :id => 1 })
        Ipayment::Payment.should_receive(:parse_from_params).with(params).and_return(payment = mock('ipayment'))
        @controller.send(:handle_ipayment_callback) do |payment|
          payment.should == payment
        end
      end
    end
  end

  describe 'Service' do
    before(:each) do
      @driver = mock('driver')
      Ipayment::Service.stub!(:driver).and_return(@driver)
      Ipayment::Service.stub!(:account_data).and_return(@account_data = { 'accountId' => '123' })
    end

    describe "create_session" do
      it "should map params correctly for the driver call" do
        @driver.should_receive(:createSession).with(@account_data,
          { 'trxAmount' => '100', 'trxCurrency' => 'EUR', 'invoiceText' => 'Invoice1' },
          'auth', 'cc', {}, { 'redirectUrl' => 'success', 'silentErrorUrl' => 'error' }
        ).and_return(['1234'])
        Ipayment::Service.create_session({
          :amount => '100', :currency => 'EUR', :payment_type => 'cc', :options => {},
          :transaction_type => 'auth', :success_url => 'success', :error_url => 'error',
          :invoice_text => 'Invoice1'
        }).should == '1234'
      end
    end
  end

  describe 'Payment' do

    describe 'initialize' do
      it "should populate attributes on initialize" do
        payment = Ipayment::Payment.new(payment_attributes)
        payment.amount.should == 100
        payment.currency.should == 'EUR'
        payment.payment_type.should == 'cc'
        payment.options.should == { :test => 1 }
      end

      it "should raise error if initialized with unknown attribute" do
        lambda {
          Ipayment::Payment.new({ :fuu => 100 })
        }.should raise_error
      end
    end

    describe 'generate_session_id' do
      it "should create session with own attributes merged into params" do
        Ipayment::Service.should_receive(:create_session, payment_attributes(:fuu => 'bar')).and_return('12334')
        payment = Ipayment::Payment.new(payment_attributes)
        payment.generate_session_id(:fuu => 'bar').should == '12334'
      end
    end

    describe 'parse_from_params' do
      before(:all) do
        @payment = Ipayment::Payment.parse_from_params(params)
      end

      it "should set correct attributes" do
        @payment.amount.should == '2000'
        @payment.currency.should == 'EUR'
        @payment.payment_type.should == 'cc'
        @payment.options.should == params
      end

      describe "on success" do
        it "should set @paid to true if response was success and transaction type auth" do
          @payment.paid?.should be_true
        end

        it "should set @paid to true if resonse was success but transaction type was not auth" do
          @payment = Ipayment::Payment.parse_from_params(params('trx_typ' => 'capture'))
          @payment.paid?.should be_false
        end

        it "should set transaction_number" do
          @payment.transaction_number.should == "1-30546206"
        end

        it "should parse cc data" do
          @payment.cc_data.should == {
            :number       => "XXXXXXXXXXXX1111",
            :card_type    => "VisaCard",
            :name         => "Hans Huber",
            :expiry_month => "01",
            :expiry_year  =>  "10"
          }
        end

        it "should parse error data" do
          @payment.error_code.should be_zero
          @payment.error_message.should be_nil
        end
      end

      describe "on error" do
        before(:all) do
          @payment = Ipayment::Payment.parse_from_params(params_error)
        end

        it "should set @paid to false if resonse was no success" do
          @payment.paid?.should be_false
        end

        it "should parse error data" do
          @payment.error_code.should == 5002
          @payment.error_message.should == 'Die angegebene Kreditkartennummer ist fehlerhaft.'
        end
      end
    end

    def payment_attributes(options = {})
      { :amount => 100, :currency => 'EUR', :invoice_text => 'Invoice123',
        :payment_type => 'cc', :options => { :test => 1 } }.merge(options)
    end

    def params(options = {})
      # typical params from a successful callback request
      {
        "trx_amount"=>"2000", "trx_remoteip_country"=>"NZ", "storage_id"=>"5068698",
        "commit"=>"Abschicken", "trxuser_id"=>"99999", "trx_paymenttyp"=>"cc", "trx_currency"=>"EUR",
        "ret_transtime"=>"07:26:33", "ret_trx_number"=>"1-30546206", "action"=>"ipayment",
        "ret_transdate"=>"27.03.09", "ret_booknr"=>"1-30546206", "trx_paymentmethod"=>"VisaCard",
        "trx_paymentdata_country"=>"US", "id"=>"callback", "addr_name"=>"Hans Huber",
        "ret_errorcode"=>"0", "paydata_cc_number"=>"XXXXXXXXXXXX1111", "paydata_cc_typ"=>"VisaCard",
        "ret_status"=>"SUCCESS", "redirect_needed"=>"0", "paydata_cc_expdate"=>"0110",
        "controller"=>"payments", "trx_typ"=>"auth", "paydata_cc_cardowner"=>"Hans Huber",
        "payment_id"=>"14496", "ret_ip"=>"202.20.7.150", "ret_authcode"=>""
      }.merge(options)
    end

    def params_error(options = {})
      # typical params for a error callback request
      {
        "trx_amount"=>"3000", "commit"=>"Abschicken", "invoice_text"=>"CC4D77E8600",
        "ret_fatalerror"=>"0", "action"=>"error", "trx_currency"=>"EUR", "ret_errorcode"=>"5002",
        "ret_errormsg"=>"Die angegebene Kreditkartennummer ist fehlerhaft.", "ret_status"=>"ERROR",
        "controller"=>"payments/ipayment", "trx_typ"=>"auth",
        "ret_additionalmsg"=>"The Creditcard-Number is invalid (0)", "redirect_needed"=>"0",
        "addr_name"=>"Hans Test", "payment_id"=>"14497", "ret_ip"=>"202.20.7.150",
        "trxuser_id"=>"9491", "trx_paymenttyp"=>"cc"
      }.merge(options)
    end
  end
end

if ENV['LIVE_TESTS'] == '1'
  describe Ipayment, "live" do

    describe "createSession" do

      it "should return a valid session id" do
        Ipayment::Service.create_session({
          :amount => 100,
          :currency => 'EUR',
          :type => 'auth',
          :payment_type => 'cc',
          :redirect_url => 'http://sauspiel.local/success',
          :silent_error_url => 'http://sauspiel.local/fail'
        }).should match(/[a-zA-Z0-9]{32}/)
      end
    end
  end
end

module Ipayment
  class Config
    def self.get
      {
        'accountId' => 99999,
        'trxuserId' =>  99999,
        'trxpassword' => 0,
        'adminactionpassword' => '5cfgRT34xsdedtFLdfHxj7tfwx24fe'
      }
    end
  end
end

