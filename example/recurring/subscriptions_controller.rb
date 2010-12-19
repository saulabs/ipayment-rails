class SubscriptionsController
  
  def new
    @ipayment = Ipayment::Payment.new(@ipayment_config_to_use, {
      :amount => 500,
      :currency => 'EUR',
      :payment_type => 'cc',
      :invoice_text => @user.id,
      :options => {
        :user_id => @user.id
      }
    })
  end

  def ipayment_callback
    # this action is not called in the context of the users session
    handle_ipayment_callback(@ipayment_config) do |ipayment|
      if ipayment && ipayment.successful?
        Subscription.create(
          :user_id => ipayment['user_id'],                       # from the options
          :initial_transaction_number => params[:ret_trx_number] # this is the reference used for recurring payments
        )
      else
        # Oops
      end
    end
    head :ok
  end

  def ipayment_success
    session[:subscription_payment_method] = "creditcard"
    session[:initial_transaction_number] = params[:ret_trx_number] 
    if current_user && current_user.credit_card
      redirect_to @@exit_path
    else
      redirect_to payment_data_path
    end
  end

  def ipayment_error
    @ipayment = Ipayment::Payment.parse_from_params(@ipayment_config, params)
    if @ipayment && @ipayment.error_code != 0
      flash[:warning] = @ipayment.error_message
    end
    redirect_to payment_data_path
  end
end
