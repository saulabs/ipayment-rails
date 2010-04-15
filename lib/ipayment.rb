require 'soap/wsdlDriver'

module Ipayment
  class Config
    def self.get
      App.config['creditcard']
    end
  end

  class Connection
    IPAYMENT_WSDL_URL = "https://ipayment.de/v2/ip_service_v3.php?wsdl" unless const_defined?('IPAYMENT_WSDL_URL')
    attr_reader :driver

    def initialize
      @driver = SOAP::WSDLDriverFactory.new(IPAYMENT_WSDL_URL).create_rpc_driver
      @driver.wiredump_file_base = "log/ipayment-log" if Rails.env.development?
    end
  end

  module Helpers
    def form_for_ipayment_auth(ipayment, options = {}, &block)
      ipayment_session = ipayment.generate_session_id({
        :transaction_type => "auth",
        :success_url => options.delete(:success_url),
        :error_url => options.delete(:error_url)
      })

      # extract options we don't want to pass on to the form
      callback_url = options.delete(:callback_url) 
      storage_id   = options.delete(:from_datastorage_id)

      form_tag("https://ipayment.de/merchant/#{Ipayment::Config.get['accountId']}/processor/2.0/", options) do
        concat hidden_field_tag(:ipayment_session_id, ipayment_session)
        concat hidden_field_tag(:silent, 1)
        concat hidden_field_tag(:return_paymentdata_details, 1)
        concat hidden_field_tag(:hidden_trigger_url, callback_url) if callback_url
        concat hidden_field_tag(:from_datastorage_id, storage_id) if storage_id
        yield
      end
    end
  end

  module Controller

    protected
    def handle_ipayment_callback(&block)
      if validate_ipayment_request_source
        ipayment = Ipayment::Payment.send(:parse_from_params, params)
        yield ipayment
      else
        yield nil
      end
    end

    def validate_ipayment_request_source
      # ipayment_Technik-Handbuch_2008-08.pdf page 42
      return request.post? && (request.env['REMOTE_ADDR'] =~ /^212\.227\.34\.2(18|19|20)$/) == 0
    end
  end

  class Payment
    attr_accessor :amount, :currency, :payment_type, :invoice_text, :options
    attr_reader :transaction_number, :cc_data, :storage_id, :error_message, :error_code

    def initialize(attributes = {})
      attributes.each do |key, value|
        self.send("#{key}=", value) rescue raise "Invalid attribute #{key}"
      end
    end

    def generate_session_id(params)
      params = params.merge({
        :amount => amount,
        :currency => currency,
        :payment_type => payment_type,
        :invoice_text => invoice_text,
        :options => options
      })
      Ipayment::Service.create_session(params)
    end

    def paid?
      @paid || false
    end

    def self.parse_from_params(params)
      payment = self.new
      payment.send(:parse_from_params, params)
      payment
    end

    protected

    def parse_from_params(params)
      self.options        = params
      self.amount         = params['trx_amount']
      self.currency       = params['trx_currency']
      self.payment_type   = params['trx_paymenttyp']
      self.invoice_text   = params['invoice_text']
      @transaction_number = params['ret_trx_number']
      @storage_id         = params['storage_id']
      @error_code         = params['ret_errorcode'].to_i
      @error_message      = params['ret_errormsg']
      @paid               = (params['ret_status'] == "SUCCESS" && params['trx_typ'] == "auth")
      @cc_data = {
        :number    => params['paydata_cc_number'],
        :card_type => params['paydata_cc_typ'],
        :name      => params['paydata_cc_cardowner']
      }
      if params['paydata_cc_expdate']
        @cc_data[:expiry_month] = params['paydata_cc_expdate'][0..1]
        @cc_data[:expiry_year]  = params['paydata_cc_expdate'][2..3]
      end
    end

  end

  class Service

    # required params:
    # * :amount
    # * :currency
    # * :transaction_type
    # * :payment_type
    # * :success_url
    # * :error_url
    # optional params:
    # * :options
    # * :invoice_text
    # returns iPayment session id
    def self.create_session(params)
      driver.createSession(
        self.account_data,
        self.transaction_data(params),
        params[:transaction_type],
        params[:payment_type],
        params[:options] || {},
        { 'redirectUrl' => params[:success_url], 'silentErrorUrl' => params[:error_url] }
      )[0]
    end

    def self.expire_datastrorage_id(storage_id)
      # We piggyback the expire command on a base check as there seems no way
      # to explicitly ask to expire a record
      driver.basecheck(
        self.account_data,
        { 'storageData' => { 'expireDatastorage' => true, 'fromDataStorageId' => storage_id } },
        { 'trxAmount' => '500', 'trxCurrency' => 'EUR' } # some arbitrary values
      )
    end

    protected

    def self.driver
      @@connection ||= Ipayment::Connection.new
      @@connection.driver
    end

    def self.account_data
      {
        'accountId' => Config.get['accountId'],
        'trxuserId' => Config.get['trxuserId'],
        'trxpassword' => Config.get['trxpassword'],
        'adminactionpassword' => Config.get['adminactionpassword']
      }
    end

    def self.transaction_data(params)
      transaction_data = { 'trxAmount' => params[:amount], 'trxCurrency' => params[:currency] }
      transaction_data['invoiceText'] = params[:invoice_text] if params[:invoice_text]
      return transaction_data
    end
  end

end
