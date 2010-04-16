class PaymentController < ApplicationController
  helper Ipayment::Helpers
  include Ipayment::Controller

  def new
    @ipayment = Ipayment::Payment.new({
      :amount => 1000,
      :currency => 'EUR',
      :payment_type => 'cc',
      :invoice_text => 'Payment #1234',
      :options => {
        :payment_id => 1111
      }
    })
  end

  def callback
    # requested from the ipayment servers
    handle_ipayment_callback do |ipayment|
      # ipayment parameter is an Ipayment::Payment instance
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
    @ipayment = Ipayment::Payment.parse_from_params(params)
    if @ipayment && @ipayment.error_code != 0
      @error = @ipayment.error_message
    elsif params[:internal] == 'true'
      @error = "An error occured while processing the transaction"
    end
  end
end
