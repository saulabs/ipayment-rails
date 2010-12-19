# ipayment-rails

Ruby on Rails implementation for the european 1&1 iPayment gateway for credit card processing.

* [Project page](http://saulabs.net/projects/ipayment-rails)
* [Repository](http://github.com/saulabs/ipayment-rails)

Technical documentation from iPayment:
[http://www.1und1.info/downloads/ipayment_Technik-Handbuch_2008-08.pdf](http://www.1und1.info/downloads/ipayment_Technik-Handbuch_2008-08.pdf) (German)

This plugin provides a simple way to implement credit card processing by providing wrappers and helpers around the 1&1 iPayment SOAP API. As the credit card data doesn't touch your application's servers, **no PCI certification is needed**.

## Examples

See the _example/_ directory for some example code.

## How it works (single payment)

* *form_for_ipayment_auth* creates a session and stores transaction data into it (amount, currency, etc.).
* The HTML form POSTs the user entered credit card data SSL secured directly to the iPayment servers.
* The iPayment servers will process the transaction and request the *callback_url* provided to *form_for_ipayment_auth* passing the result to it. At this point your application should handle the transaction, e.g. booking the amount to the user account if it is successful.
* iPayment will redirect the user to *success_url* if the transactions succeeds or to *error_url* if it doesn't.
* All this happens transparently to the user – except for a short change in the address field of the browser, he stays on your site.

## How it works (recurring payments)

* *form_for_ipayment_check_save* creates a session and stores transaction data into it (options, etc.).
* The HTML form POSTs the user entered credit card data SSL secured directly to the iPayment servers.
* The iPayment servers check the credit card but don't charge it and request the *callback_url* provided to *form_for_ipayment_check_save* passing the result with an transaction id to it. At this point your application should handle the transaction, e.g. create a subscription for the user, storing the transaction id for the following charges.
* iPayment will redirect the user to *success_url* if the check succeeds or to *error_url* if it doesn't.
* All this happens transparently to the user – except for a short change in the address field of the browser, he stays on your site.
* For the first payment (e.g after a month of trial), create an Ipayment::Payment and set it's *initial_recurring* attribute to true and charge the amount with *charge!(:orig_trx_number => your_initial_transcation_number)*
* For the second and following payments payment, create an Ipayment::Payment and set it's *recurring* attribute to true and charge the amount with *charge!(:orig_trx_number => your_initial_transcation_number)*

## How to get it work

* Get iPayment credentials and put them into the config file. The file goes into *RAILS_ROOT/config/ipayment.yml* (or use a test account, see *ipayment_Technik-Handbuch_2008-08.pdf* page 10).
* Implement a controller to handle callback, success and error (see controller.rb example).
* Add a view using *form_for_ipayment_auth* passing it an Ipayment::Payment with payment data (see controller.rb and new.html.erb).

## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add specs for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but
   bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2009-2010 Dieter Komendera. See LICENSE for details.
