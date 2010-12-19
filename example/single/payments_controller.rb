class PaymentController < ApplicationController
  helper Ipayment::Helpers
  include Ipayment::Controller

  before_filter :set_ipayment_config

  def new
    @ipayment = Ipayment::Payment.new(@ipayment_config, {
      :amount => 1000,
      :currency => 'EUR',
      :payment_type => 'cc',
      :invoice_text => 'Payment #1234',
      :options => {
        :payment_id => 1111 # e.g your internal payment handle
      }
    })
  end

  def callback
    # requested from the ipayment servers
    handle_ipayment_callback(@ipayment_config) do |ipayment|
      # ipayment parameter is an Ipayment::Payment instance
      # This is the right place to handle a payment, e.g credit the payment amount to the user.
      # You've access to the options passed to the Ipayment::Payment instance, e.g:
      # ipayment.options['payment_id'] #=> 1111
    end
    head :ok
  end

  def success
    # user gets redirected here if transaction succeeds
    # the options, in this example the payment_id get passed in the params
    # e.g params[:payment_id] #=> 1111
  end

  def error
    # user gets redirected here if transaction fails
    @ipayment = Ipayment::Payment.parse_from_params(@ipayment_config, params)
    if @ipayment && @ipayment.error_code != 0
      @error = @ipayment.error_message
    elsif params[:internal] == 'true'
      @error = "An error occured while processing the transaction"
    end
  end

  protected

    def set_ipayment_config
      @ipayment_config = {
        'accountId' => 99999,
        'trxuserId' =>  99999,
        'trxpassword' => 0,
        'adminactionpassword' => '5cfgRT34xsdedtFLdfHxj7tfwx24fe'
      }
    end
end
