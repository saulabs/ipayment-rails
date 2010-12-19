class Subscription

  has_many :payments

  # call this when a charge is due
  def charge_credit_card
    ipayment = Ipayment::Payment.new(@ipayment_config_to_use, {
      :amount => price.to_i.to_s,
      :currency => 'EUR',
      :payment_type => 'cc',
      :invoice_text => "Invoice for Subscription #{self.id}",
      :options => {
        :subscription_id => self.id
      }
    })
    if is_initial_payment?
      ipayment.initial_recurring = true
    else
      ipayment.recurring = true
    end
    ipayment.charge!(:orig_trx_number => self.initial_transaction_number)
  end

end
